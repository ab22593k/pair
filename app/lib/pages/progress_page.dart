import 'dart:async';
import 'dart:typed_data';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:common/model/dto/file_dto.dart';
import 'package:common/model/file_status.dart';
import 'package:common/model/session_status.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/state/server/receive_session_state.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/progress_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/file_size_helper.dart';
import 'package:localsend_app/util/file_speed_helper.dart';
import 'package:localsend_app/util/native/open_file.dart';
import 'package:localsend_app/util/native/open_folder.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/util/native/taskbar_helper.dart';
import 'package:localsend_app/util/ui/nav_bar_padding.dart';
import 'package:localsend_app/widget/custom_basic_appbar.dart';
import 'package:localsend_app/widget/dialogs/cancel_session_dialog.dart';
import 'package:localsend_app/widget/dialogs/error_dialog.dart';
import 'package:localsend_app/widget/file_thumbnail.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

class ProgressPage extends StatefulWidget {
  final bool showAppBar;
  final bool closeSessionOnClose;
  final String sessionId;

  const ProgressPage({
    required this.showAppBar,
    required this.closeSessionOnClose,
    required this.sessionId,
  });

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> with Refena {
  int _totalBytes = double.maxFinite.toInt();
  int _lastRemainingTimeUpdate = 0; // millis since epoch
  String? _remainingTime;
  List<FileDto> _files = []; // also contains declined files (files without token)
  Set<String> _selectedFiles = {};
  SessionStatus? _lastStatus;

  // If [autoFinish] is enabled, we wait a few seconds before automatically closing the session.
  int _finishCounter = 3;
  Timer? _finishTimer;
  Timer? _wakelockPlusTimer;

  bool _advanced = false;

  @override
  void initState() {
    super.initState();

    // init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        unawaited(WakelockPlus.enable());
      } catch (_) {}

      // Periodically call WakelockPlus.enable() to keep the screen awake
      _wakelockPlusTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        final finished =
            ref.read(serverProvider)?.session?.files.values.map((e) => e.status).isFinishedOrSkipped ??
            ref.read(sendProvider)[widget.sessionId]?.files.values.map((e) => e.status).isFinishedOrSkipped ??
            true;
        if (finished) {
          timer.cancel();
          try {
            unawaited(WakelockPlus.disable());
          } catch (_) {}
        } else {
          try {
            unawaited(WakelockPlus.enable());
          } catch (_) {}
        }
      });

      if (ref.read(settingsProvider).autoFinish) {
        _finishTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          final finished =
              ref.read(serverProvider)?.session?.files.values.map((e) => e.status).isFinishedOrSkipped ??
              ref.read(sendProvider)[widget.sessionId]?.files.values.map((e) => e.status).isFinishedOrSkipped ??
              true;
          if (finished) {
            if (_finishCounter == 1) {
              timer.cancel();
              _exit(closeSession: true);
            } else {
              setState(() {
                _finishCounter--;
              });
            }
          }
        });
      }

      setState(() {
        final receiveSession = ref.read(serverProvider)?.session;
        if (receiveSession != null) {
          _files = receiveSession.files.values.map((f) => f.file).toList();

          // We previously used f.token != null here, but this may not work on very fast networks.
          _selectedFiles = receiveSession.files.values.where((f) => f.status != FileStatus.skipped).map((f) => f.file.id).toSet();
        } else {
          final sendSession = ref.read(sendProvider)[widget.sessionId];
          if (sendSession != null) {
            _files = sendSession.files.values.map((f) => f.file).toList();
            _selectedFiles = sendSession.files.values.where((f) => f.status != FileStatus.skipped).map((f) => f.file.id).toSet();
          }
        }

        _totalBytes = _files.where((f) => _selectedFiles.contains(f.id)).fold(0, (prev, curr) => prev + curr.size);
      });
    });
  }

  void _exit({required bool closeSession}) async {
    final receiveSession = ref.read(serverProvider.select((s) => s?.session));
    final sendSession = ref.read(sendProvider)[widget.sessionId];
    final SessionStatus? status = receiveSession?.status ?? sendSession?.status;
    final keepSession = !closeSession && (status == SessionStatus.sending || status == SessionStatus.finishedWithErrors);
    final result = status == null || keepSession || await _askCancelConfirmation(status);

    if (result && mounted) {
      // ignore: unawaited_futures
      context.popUntilRoot();
    }
  }

  Future<bool> _askCancelConfirmation(SessionStatus status) async {
    final bool result = switch (status == SessionStatus.sending) {
      true => (await context.pushBottomSheet(() => const CancelSessionDialog())) == true,
      false => true,
    };
    if (result) {
      final receiveSession = ref.read(serverProvider)?.session;
      final sendState = ref.read(sendProvider)[widget.sessionId];

      if (receiveSession != null) {
        if (receiveSession.status == SessionStatus.sending) {
          ref.notifier(serverProvider).cancelSession();
        } else {
          ref.notifier(serverProvider).closeSession();
        }
      } else if (sendState != null) {
        if (sendState.status == SessionStatus.sending) {
          ref.notifier(sendProvider).cancelSession(widget.sessionId);
        } else {
          ref.notifier(sendProvider).closeSession(widget.sessionId);
        }
      }
    }
    return result;
  }

  @override
  void dispose() {
    super.dispose();
    _finishTimer?.cancel();
    _wakelockPlusTimer?.cancel();
    TaskbarHelper.clearProgressBar(); // ignore: discarded_futures
    try {
      WakelockPlus.disable(); // ignore: discarded_futures
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final progressNotifier = ref.watch(progressProvider);
    final currBytes = _files.fold<int>(
      0,
      (prev, curr) => prev + ((progressNotifier.getProgress(sessionId: widget.sessionId, fileId: curr.id) * curr.size).round()),
    );

    final receiveSession = ref.watch(serverProvider.select((s) => s?.session));
    final sendSession = ref.watch(sendProvider)[widget.sessionId];

    final SessionState? commonSessionState = receiveSession ?? sendSession;

    if (commonSessionState == null) {
      return Scaffold(
        body: Container(),
      );
    }

    final status = commonSessionState.status;

    if (status == SessionStatus.sending) {
      // ignore: discarded_futures
      TaskbarHelper.setProgressBar(currBytes, _totalBytes);
    } else if (status != _lastStatus) {
      _lastStatus = status;
      // ignore: discarded_futures
      TaskbarHelper.visualizeStatus(status);
    }

    final title = receiveSession != null ? t.progressPage.titleReceiving : t.progressPage.titleSending;
    final startTime = commonSessionState.startTime;
    final endTime = commonSessionState.endTime;
    final int? speedInBytes;
    if (startTime != null && currBytes >= 500 * 1024) {
      speedInBytes = getFileSpeed(start: startTime, end: endTime ?? DateTime.now().millisecondsSinceEpoch, bytes: currBytes);

      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastRemainingTimeUpdate >= 1000) {
        _remainingTime = getRemainingTime(bytesPerSeconds: speedInBytes, remainingBytes: _totalBytes - currBytes);
        _lastRemainingTimeUpdate = now;
      }
    } else {
      speedInBytes = null;
    }

    final fileStatusMap = receiveSession?.files.map((k, f) => MapEntry(k, f.status)) ?? sendSession!.files.map((k, f) => MapEntry(k, f.status));
    final finishedCount = fileStatusMap.values.where((s) => s == FileStatus.finished).length;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // Already popped.
          // Because the user cannot pop this page, we can safely assume that all sessions are closed if they should be.
          return;
        }
        _exit(closeSession: widget.closeSessionOnClose);
      },
      canPop: false,
      child: Scaffold(
        appBar: widget.showAppBar ? basicLocalSendAppbar(title) : null,
        body: Stack(
          children: [
            ListView.builder(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 20,
                bottom: 200 + getNavBarPadding(context), // Increased bottom padding for the floating card
                left: 15,
                right: 15,
              ),
              itemCount: _files.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  // title
                  if (widget.showAppBar) {
                    return Container();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20, left: 5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (checkPlatformWithFileSystem() && receiveSession != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${t.settingsTab.receive.destination}: ',
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  ),
                                  TextSpan(
                                    text: receiveSession.destinationDirectory,
                                    style: TextStyle(
                                      color: checkPlatform([TargetPlatform.iOS])
                                          ? Theme.of(context).colorScheme.onSurface
                                          : Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    recognizer: checkPlatform([TargetPlatform.iOS])
                                        ? null
                                        : (TapGestureRecognizer()
                                            ..onTap = () async {
                                              await openFolder(folderPath: receiveSession.destinationDirectory);
                                            }),
                                  ),
                                ],
                              ),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                      ],
                    ),
                  );
                }

                if (index == 1) {
                  // error card
                  final errorMessage = sendSession?.errorMessage;
                  if (errorMessage == null) {
                    return Container();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(
                          errorMessage,
                          style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                        ),
                      ),
                    ),
                  );
                }

                final file = _files[index - 2];
                final String fileName = receiveSession?.files[file.id]?.desiredName ?? file.fileName;

                final fileStatus = fileStatusMap[file.id]!;
                final savedToGallery = receiveSession?.files[file.id]?.savedToGallery ?? false;

                final String? filePath;
                if (receiveSession != null && fileStatus == FileStatus.finished && !savedToGallery) {
                  filePath = receiveSession.files[file.id]!.path;
                } else if (sendSession != null) {
                  filePath = sendSession.files[file.id]!.path;
                } else {
                  filePath = null;
                }

                final String? errorMessage;
                if (receiveSession != null) {
                  errorMessage = receiveSession.files[file.id]!.errorMessage;
                } else if (sendSession != null) {
                  errorMessage = sendSession.files[file.id]!.errorMessage;
                } else {
                  errorMessage = null;
                }

                final Uint8List? thumbnail;
                final AssetEntity? asset;
                if (sendSession != null) {
                  thumbnail = sendSession.files[file.id]!.thumbnail;
                  asset = sendSession.files[file.id]!.asset;
                } else {
                  thumbnail = null;
                  asset = null;
                }

                return _FileListItem(
                  file: file,
                  fileName: fileName,
                  fileStatus: fileStatus,
                  savedToGallery: savedToGallery,
                  filePath: filePath,
                  errorMessage: errorMessage,
                  thumbnail: thumbnail,
                  asset: asset,
                  progress: progressNotifier.getProgress(sessionId: widget.sessionId, fileId: file.id),
                  onRetry: sendSession != null && fileStatus == FileStatus.failed
                      ? () async {
                          await ref
                              .notifier(sendProvider)
                              .sendFile(
                                sessionId: widget.sessionId,
                                isolateIndex: 0,
                                file: sendSession.files[file.id]!,
                                isRetry: true,
                              );
                        }
                      : null,
                );
              },
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: _BottomProgressCard(
                    status: status,
                    currBytes: currBytes,
                    totalBytes: _totalBytes,
                    remainingTime: _remainingTime,
                    finishedCount: finishedCount,
                    totalCount: _selectedFiles.length,
                    speedInBytes: speedInBytes,
                    advanced: _advanced,
                    onToggleAdvanced: () => setState(() => _advanced = !_advanced),
                    onExit: () => _exit(closeSession: true),
                    finishTimer: _finishTimer,
                    finishCounter: _finishCounter,
                  ),
                ),
              ),
            ),
            if (checkPlatform([TargetPlatform.macOS]))
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 40,
                child: MoveWindow(),
              ),
          ],
        ),
      ),
    );
  }
}

class _FileListItem extends StatelessWidget {
  final FileDto file;
  final String fileName;
  final FileStatus fileStatus;
  final bool savedToGallery;
  final String? filePath;
  final String? errorMessage;
  final Uint8List? thumbnail;
  final AssetEntity? asset;
  final double progress;
  final VoidCallback? onRetry;

  const _FileListItem({
    required this.file,
    required this.fileName,
    required this.fileStatus,
    required this.savedToGallery,
    required this.filePath,
    required this.errorMessage,
    required this.thumbnail,
    required this.asset,
    required this.progress,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: filePath != null ? () async => openFile(context, file.fileType, filePath!) : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SmartFileThumbnail(
                  bytes: thumbnail,
                  asset: asset,
                  path: filePath,
                  fileType: file.fileType,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              fileName,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            file.size.asReadableFileSize,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (fileStatus == FileStatus.sending)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                savedToGallery ? t.progressPage.savedToGallery : fileStatus.label,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: fileStatus.getColor(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (errorMessage != null) ...[
                              const SizedBox(width: 5),
                              InkWell(
                                onTap: () async {
                                  await showDialog(
                                    context: context,
                                    builder: (_) => ErrorDialog(error: errorMessage!),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 5),
                                  child: HugeIcon(
                                    icon: HugeIcons.strokeRoundedInformationCircle,
                                    color: Theme.of(context).colorScheme.error,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
                if (onRetry != null)
                  IconButton(
                    icon: HugeIcon(icon: HugeIcons.strokeRoundedRefresh, color: Theme.of(context).colorScheme.primary),
                    onPressed: onRetry,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomProgressCard extends StatelessWidget {
  final SessionStatus status;
  final int currBytes;
  final int totalBytes;
  final String? remainingTime;
  final int finishedCount;
  final int totalCount;
  final int? speedInBytes;
  final bool advanced;
  final VoidCallback onToggleAdvanced;
  final VoidCallback onExit;
  final Timer? finishTimer;
  final int finishCounter;

  const _BottomProgressCard({
    required this.status,
    required this.currBytes,
    required this.totalBytes,
    required this.remainingTime,
    required this.finishedCount,
    required this.totalCount,
    required this.speedInBytes,
    required this.advanced,
    required this.onToggleAdvanced,
    required this.onExit,
    required this.finishTimer,
    required this.finishCounter,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainer,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    status.getLabel(remainingTime: remainingTime ?? '-'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (status == SessionStatus.sending)
                  Tooltip(
                    message: t.general.cancel,
                    child: IconButton.filledTonal(
                      onPressed: onExit,
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedCancel01,
                        size: 20,
                      ),
                    ),
                  )
                else
                  FilledButton.icon(
                    onPressed: onExit,
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                      size: 20,
                    ),
                    label: Text(
                      finishTimer != null ? '${t.general.done} ($finishCounter)' : t.general.done,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: totalBytes == 0 ? 0 : currBytes / totalBytes),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 12,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                );
              },
            ),
            AnimatedCrossFade(
              crossFadeState: advanced ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topLeft,
              firstChild: Container(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Column(
                  children: [
                    _InfoRow(
                      label: t.progressPage.total.count(
                        curr: finishedCount,
                        n: totalCount,
                      ),
                      icon: HugeIcons.strokeRoundedFile01,
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: t.progressPage.total.size(
                        curr: currBytes.asReadableFileSize,
                        n: totalBytes == double.maxFinite.toInt() ? '-' : totalBytes.asReadableFileSize,
                      ),
                      icon: HugeIcons.strokeRoundedDatabase01,
                    ),
                    if (speedInBytes != null) ...[
                      const SizedBox(height: 8),
                      _InfoRow(
                        label: t.progressPage.total.speed(
                          speed: speedInBytes!.asReadableFileSize,
                        ),
                        icon: HugeIcons.strokeRoundedRocket,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onPressed: onToggleAdvanced,
                icon: HugeIcon(
                  icon: advanced ? HugeIcons.strokeRoundedArrowUp01 : HugeIcons.strokeRoundedArrowDown01,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                label: Text(advanced ? t.general.hide : t.general.advanced),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final dynamic icon;

  const _InfoRow({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        HugeIcon(
          icon: icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

extension on FileStatus {
  String get label {
    switch (this) {
      case FileStatus.queue:
        return t.general.queue;
      case FileStatus.skipped:
        return t.general.skipped;
      case FileStatus.sending:
        return ''; // progress bar will be showed here
      case FileStatus.failed:
        return t.general.error;
      case FileStatus.finished:
        return t.general.done;
    }
  }

  Color getColor(BuildContext context) {
    switch (this) {
      case FileStatus.queue:
        return Theme.of(context).colorScheme.primary;
      case FileStatus.skipped:
        return Theme.of(context).colorScheme.onSurfaceVariant;
      case FileStatus.sending:
        return Theme.of(context).colorScheme.primary;
      case FileStatus.failed:
        return Theme.of(context).colorScheme.error;
      case FileStatus.finished:
        return Theme.of(context).colorScheme.primary;
    }
  }
}

extension on SessionStatus {
  String getLabel({required String remainingTime}) {
    switch (this) {
      case SessionStatus.sending:
        return t.progressPage.total.title.sending(
          time: remainingTime,
        );
      case SessionStatus.finished:
        return t.general.finished;
      case SessionStatus.finishedWithErrors:
        return t.progressPage.total.title.finishedError;
      case SessionStatus.canceledBySender:
        return t.progressPage.total.title.canceledSender;
      case SessionStatus.canceledByReceiver:
        return t.progressPage.total.title.canceledReceiver;
      default:
        return '';
    }
  }
}
