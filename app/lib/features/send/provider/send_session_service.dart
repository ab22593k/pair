import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:common/api_route_builder.dart';
import 'package:common/isolate.dart';
import 'package:common/model/device.dart';
import 'package:common/model/dto/file_dto.dart';
import 'package:common/model/dto/info_register_dto.dart';
import 'package:common/model/dto/multicast_dto.dart';
import 'package:common/model/dto/prepare_upload_request_dto.dart';
import 'package:common/model/dto/prepare_upload_response_dto.dart';
import 'package:common/model/file_status.dart';
import 'package:common/model/file_type.dart';
import 'package:common/model/session_status.dart';
import 'package:localsend_app/features/send/model/prepare_upload_result.dart';
import 'package:localsend_app/features/send/model/send_session_state.dart';
import 'package:localsend_app/features/send/model/sending_file.dart';
import 'package:localsend_app/features/send/provider/selected_sending_files_provider.dart';
import 'package:localsend_app/features/settings/provider/settings_provider.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/model/send_mode.dart';
import 'package:localsend_app/provider/device_info_provider.dart';
import 'package:localsend_app/provider/http_provider.dart';
import 'package:localsend_app/provider/progress_provider.dart';
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:rhttp/rhttp.dart';
import 'package:uri_content/uri_content.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();
final _logger = Logger('SendSessionService');

/// This provider manages sending files to other devices.
///
/// In contrast to [serverProvider], this provider does not manage a server.
/// Instead, it only does HTTP requests to other servers.
final sendProvider = NotifierProvider<SendSessionService, Map<String, SendSessionState>>((ref) {
  return SendSessionService();
});

class SendSessionService extends Notifier<Map<String, SendSessionState>> {
  SendSessionService();

  @override
  Map<String, SendSessionState> init() {
    return {};
  }

  /// Creates a session and initializes the state.
  /// Returns the sessionId.
  Future<String> createSession({
    required Device target,
    required List<CrossFile> files,
    required bool background,
  }) async {
    final sessionId = _uuid.v4();

    final requestState = SendSessionState(
      sessionId: sessionId,
      remoteSessionId: null,
      background: background,
      status: SessionStatus.waiting,
      target: target,
      files: Map.fromEntries(
        await Future.wait(
          files.map((file) async {
            final id = _uuid.v4();
            return MapEntry(
              id,
              SendingFile(
                file: FileDto(
                  id: id,
                  fileName: file.name,
                  size: file.size,
                  fileType: file.fileType,
                  hash: null,
                  preview: files.length == 1 && files.first.fileType == FileType.text && files.first.bytes != null
                      ? utf8.decode(files.first.bytes!) // send simple message by embedding it into the preview
                      : null,
                  metadata: file.lastModified != null || file.lastAccessed != null
                      ? FileMetadata(
                          lastModified: file.lastModified,
                          lastAccessed: file.lastAccessed,
                        )
                      : null,
                  legacy: target.version == '1.0',
                ),
                status: FileStatus.queue,
                token: null,
                thumbnail: file.thumbnail,
                asset: file.asset,
                path: file.path,
                bytes: file.bytes,
                errorMessage: null,
              ),
            );
          }),
        ),
      ),
      startTime: null,
      endTime: null,
      sendingTasks: [],
      errorMessage: null,
    );

    state = state.updateSession(
      sessionId: sessionId,
      state: (_) => requestState,
    );

    return sessionId;
  }

  /// Submits the HTTP request to the target device.
  Future<PrepareUploadResult> submitRequest({
    required String sessionId,
    String? pin,
  }) async {
    final sessionState = state[sessionId];
    if (sessionState == null) {
      return const PrepareUploadResult.error(error: 'Session not found');
    }

    final target = sessionState.target;
    final client = ref.read(httpProvider).longLiving;
    final cancelToken = CancelToken();

    final originDevice = ref.read(deviceFullInfoProvider);
    final requestDto = PrepareUploadRequestDto(
      info: InfoRegisterDto(
        alias: originDevice.alias,
        version: originDevice.version,
        deviceModel: originDevice.deviceModel,
        deviceType: originDevice.deviceType,
        fingerprint: originDevice.fingerprint,
        port: originDevice.port,
        protocol: originDevice.https ? ProtocolType.https : ProtocolType.http,
        download: originDevice.download,
      ),
      files: {
        for (final entry in sessionState.files.entries) entry.key: entry.value.file,
      },
    );

    try {
      final response = await client.post(
        ApiRoute.prepareUpload.target(target),
        // ignore: use_null_aware_elements
        query: {
          'pin': ?pin,
        },
        body: HttpBody.json(requestDto.toJson()),
        cancelToken: cancelToken,
      );

      if (target.version == '1.0') {
        final fileMap = (response.bodyToJson as Map).cast<String, String>();
        return PrepareUploadResult.success(sessionId: '', files: fileMap);
      }

      if (response.statusCode == 204) {
        return const PrepareUploadResult.success(sessionId: '', files: {});
      }

      final responseDto = PrepareUploadResponseDto.fromJson(response.bodyToJson);
      state = state.updateSession(
        sessionId: sessionId,
        state: (s) => s?.copyWith(
          remoteSessionId: responseDto.sessionId,
        ),
      );
      return PrepareUploadResult.success(sessionId: responseDto.sessionId, files: responseDto.files);
    } on RhttpStatusCodeException catch (e) {
      switch (e.statusCode) {
        case 401:
          return const PrepareUploadResult.pinRequired();
        case 403:
          state = state.updateSession(
            sessionId: sessionId,
            state: (s) => s?.copyWith(
              status: SessionStatus.declined,
            ),
          );
          return const PrepareUploadResult.declined();
        case 409:
          state = state.updateSession(
            sessionId: sessionId,
            state: (s) => s?.copyWith(
              status: SessionStatus.recipientBusy,
            ),
          );
          return const PrepareUploadResult.recipientBusy();
        case 429:
          state = state.updateSession(
            sessionId: sessionId,
            state: (s) => s?.copyWith(
              status: SessionStatus.tooManyAttempts,
            ),
          );
          return const PrepareUploadResult.tooManyAttempts();
        default:
          state = state.updateSession(
            sessionId: sessionId,
            state: (s) => s?.copyWith(
              status: SessionStatus.finishedWithErrors,
              errorMessage: e.humanErrorMessage,
            ),
          );
          return PrepareUploadResult.error(error: e.humanErrorMessage);
      }
    } catch (e) {
      state = state.updateSession(
        sessionId: sessionId,
        state: (s) => s?.copyWith(
          status: SessionStatus.finishedWithErrors,
          errorMessage: e.humanErrorMessage,
        ),
      );
      return PrepareUploadResult.error(error: e.humanErrorMessage);
    }
  }

  /// Cancels the session explicitly by the sender (e.g. invalid PIN).
  void cancelSessionBySender(String sessionId) {
    state = state.updateSession(
      sessionId: sessionId,
      state: (s) => s?.copyWith(
        status: SessionStatus.canceledBySender,
      ),
    );
  }

  /// Initializes the upload process after a successful handshake.
  Future<void> startUpload({
    required String sessionId,
    required Map<String, String> fileMap,
  }) async {
    final sessionState = state[sessionId];
    if (sessionState == null) return;

    if (fileMap.isEmpty) {
      // receiver has nothing selected
      state = state.updateSession(
        sessionId: sessionId,
        state: (s) => s?.copyWith(
          status: SessionStatus.finished,
        ),
      );
      closeSession(sessionId);
      return;
    }

    final sendingFiles = {
      for (final file in sessionState.files.values)
        file.file.id: fileMap.containsKey(file.file.id) ? file.copyWith(token: fileMap[file.file.id]) : file.copyWith(status: FileStatus.skipped),
    };

    state = state.updateSession(
      sessionId: sessionId,
      state: (s) => s?.copyWith(
        status: SessionStatus.sending,
        files: sendingFiles,
      ),
    );

    await _sendLoop(sessionId, sessionState.target, sendingFiles);
  }

  Future<void> _sendLoop(String sessionId, Device target, Map<String, SendingFile> files) async {
    state = state.updateSession(
      sessionId: sessionId,
      state: (s) => s?.copyWith(startTime: DateTime.now().millisecondsSinceEpoch),
    );

    final queue = Queue<SendingFile>()..addAll(files.values);
    final concurrency = ref.read(parentIsolateProvider).uploadIsolateCount;
    _logger.info('Sending files using $concurrency concurrent isolates');

    final futures = List.generate(concurrency, (index) async {
      while (true) {
        final file = switch (queue.isEmpty) {
          true => null,
          false => queue.removeFirst(),
        };

        if (file == null) {
          break;
        }

        await sendFile(
          sessionId: sessionId,
          isolateIndex: index,
          file: file,
          isRetry: false,
        );
      }
    });

    await Future.wait(futures);

    _finish(sessionId: sessionId);
  }

  void _finish({required String sessionId}) {
    final sessionState = state[sessionId];
    if (sessionState == null) {
      return;
    }

    if (state[sessionId]!.status != SessionStatus.sending) {
      _logger.info('Transfer was canceled.');
    } else {
      final hasError = sessionState.files.values.any((file) => file.status == FileStatus.failed);
      if (!hasError && sessionState.background == true) {
        // close session because everything is fine and it is in background
        closeSession(sessionId);
        _logger.info('Transfer finished and session removed.');
      } else {
        // keep session alive when there are errors or currently in foreground
        state = state.updateSession(
          sessionId: sessionId,
          state: (s) => s?.copyWith(
            status: hasError ? SessionStatus.finishedWithErrors : SessionStatus.finished,
            endTime: DateTime.now().millisecondsSinceEpoch,
          ),
        );

        if (hasError) {
          _logger.info('Transfer finished with errors.');
        } else {
          _logger.info('Transfer finished successfully.');
        }
      }
    }
  }

  final uriContent = UriContent();

  /// Sends a file.
  /// Returns true, if the next file should be sent.
  Future<bool> sendFile({
    required String sessionId,
    required int isolateIndex,
    required SendingFile file,
    required bool isRetry,
  }) async {
    final token = file.token;
    if (token == null) {
      return true;
    }

    final status = state[sessionId]?.status;
    const allowedStates = {SessionStatus.sending, SessionStatus.finishedWithErrors};
    if (status == null || !allowedStates.contains(status)) {
      return false;
    }

    final remoteSessionId = state[sessionId]!.remoteSessionId;
    final target = state[sessionId]!.target;

    if (isRetry) {
      _logger.info('Retrying ${file.file.fileName}');

      state = state.updateSession(
        sessionId: sessionId,
        state: (s) => s?.copyWith(
          status: SessionStatus.sending,
          files: s.files.map((key, value) {
            if (key == file.file.id) {
              return MapEntry(key, value.copyWith(status: FileStatus.queue, errorMessage: null));
            }
            return MapEntry(key, value);
          }),
        ),
      );
    } else {
      _logger.info('Sending ${file.file.fileName}');
    }

    state = state.updateSession(
      sessionId: sessionId,
      state: (s) => s?.withFileStatus(file.file.id, FileStatus.sending, null),
    );

    final taskResult = ref
        .redux(parentIsolateProvider)
        .dispatchTakeResult(
          IsolateHttpUploadAction(
            isolateIndex: isolateIndex,
            remoteSessionId: remoteSessionId,
            remoteFileToken: token,
            fileId: file.file.id,
            filePath: file.path,
            fileBytes: file.bytes,
            mime: file.file.lookupMime(),
            fileSize: file.file.size,
            device: target,
          ),
        );

    String? fileError;
    try {
      state = state.updateSession(
        sessionId: sessionId,
        state: (s) => s?.copyWith(
          sendingTasks: [
            ...?s.sendingTasks,
            SendingTask(
              isolateIndex: isolateIndex,
              taskId: taskResult.taskId,
            ),
          ],
        ),
      );

      await for (final progress in taskResult.progress) {
        ref
            .notifier(progressProvider)
            .setProgress(
              sessionId: sessionId,
              fileId: file.file.id,
              progress: progress,
            );
      }

      // set progress to 100% when successfully finished
      ref
          .notifier(progressProvider)
          .setProgress(
            sessionId: sessionId,
            fileId: file.file.id,
            progress: 1,
          );
    } catch (e, st) {
      fileError = e.humanErrorMessage;
      _logger.warning('Error while sending file ${file.file.fileName}', e, st);
    } finally {
      state = state.updateSession(
        sessionId: sessionId,
        state: (s) => s?.copyWith(
          sendingTasks: s.sendingTasks?.where((task) => !(task.isolateIndex == isolateIndex && task.taskId == taskResult.taskId)).toList(),
        ),
      );
    }

    state = state.updateSession(
      sessionId: sessionId,
      state: (s) => s?.withFileStatus(file.file.id, fileError != null ? FileStatus.failed : FileStatus.finished, fileError),
    );

    if (isRetry) {
      final state = this.state[sessionId];
      if (state != null && state.files.values.map((e) => e.status).isFinishedOrError) {
        _finish(sessionId: sessionId);
        return false;
      }
    }

    return true;
  }

  /// Closes the send-session and sends a cancel event to the receiver.
  void cancelSession(String sessionId) {
    final sessionState = state[sessionId];
    if (sessionState == null) {
      return;
    }
    final remoteSessionId = sessionState.remoteSessionId;

    _cancelRunningRequests(sessionState);

    // notify the receiver
    try {
      ref
          .read(httpProvider)
          .discovery
          // ignore: discarded_futures
          .post(ApiRoute.cancel.target(sessionState.target, query: remoteSessionId != null ? {'sessionId': remoteSessionId} : null));
    } catch (e) {
      _logger.warning('Error while canceling session', e);
    }

    // finally, close session locally
    closeSession(sessionId);
  }

  void cancelSessionByReceiver(String sessionId) {
    final sessionState = state[sessionId];
    if (sessionState == null) {
      return;
    }
    _cancelRunningRequests(sessionState);

    state = state.updateSession(
      sessionId: sessionId,
      state: (s) => s?.copyWith(
        status: SessionStatus.canceledByReceiver,
        endTime: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  void _cancelRunningRequests(SendSessionState state) {
    for (final task in state.sendingTasks ?? <SendingTask>[]) {
      ref
          .redux(parentIsolateProvider)
          .dispatch(
            IsolateHttpUploadCancelAction(
              isolateIndex: task.isolateIndex,
              taskId: task.taskId,
            ),
          );
    }
  }

  /// Closes the session
  void closeSession(String sessionId) {
    final sessionState = state[sessionId];
    if (sessionState == null) {
      return;
    }
    state = state.removeSession(ref, sessionId);
    if (sessionState.status == SessionStatus.finished && ref.read(settingsProvider).sendMode == SendMode.single) {
      // clear selected files
      ref.redux(selectedSendingFilesProvider).dispatch(ClearSelectionAction());
    }
  }

  void clearAllSessions() {
    state = {};
    ref.notifier(progressProvider).removeAllSessions();
  }

  void setBackground(String sessionId, bool background) {
    state = state.updateSession(
      sessionId: sessionId,
      state: (s) => s?.copyWith(background: background),
    );
  }
}

extension on Map<String, SendSessionState> {
  Map<String, SendSessionState> updateSession({
    required String sessionId,
    required SendSessionState? Function(SendSessionState? old) state,
  }) {
    final newState = state(this[sessionId]);
    if (newState == null) {
      // no change
      return this;
    }
    return {
      ...this,
      sessionId: newState,
    };
  }

  Map<String, SendSessionState> removeSession(Ref ref, String sessionId) {
    ref.notifier(progressProvider).removeSession(sessionId);
    return {...this}..remove(sessionId);
  }
}

extension on SendSessionState {
  SendSessionState withFileStatus(String fileId, FileStatus status, String? errorMessage) {
    return copyWith(
      files: {...files}
        ..update(
          fileId,
          (file) => file.copyWith(
            status: status,
            errorMessage: errorMessage,
          ),
        ),
    );
  }
}

extension on Object {
  String get humanErrorMessage {
    final e = this;
    final (statusCode, message) = switch (this) {
      RhttpStatusCodeException(:final statusCode, :final body) => (statusCode, _parseErrorMessage(body)),
      _ => (null, e.toString()),
    };

    if (statusCode != null && message != null) {
      return '[$statusCode] $message';
    }

    return e.toString();
  }
}

String? _parseErrorMessage(Object? body) {
  if (body is! String) {
    return null;
  }

  try {
    return (jsonDecode(body) as Map)['message'];
  } catch (_) {
    return null;
  }
}
