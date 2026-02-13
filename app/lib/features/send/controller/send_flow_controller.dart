import 'package:common/model/device.dart';
import 'package:common/util/sleep.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/features/send/model/prepare_upload_result.dart';
import 'package:localsend_app/features/send/pages/send_page.dart';
import 'package:localsend_app/features/send/provider/send_session_service.dart';
import 'package:localsend_app/features/settings/provider/settings_provider.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/model/send_mode.dart';
import 'package:localsend_app/pages/home_page.dart';
import 'package:localsend_app/pages/progress_page.dart';
import 'package:localsend_app/widget/dialogs/pin_dialog.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

final sendFlowControllerProvider = Provider((ref) => SendFlowController(ref));

class SendFlowController {
  final Ref ref;

  SendFlowController(this.ref);

  Future<void> startSession({
    required Device target,
    required List<CrossFile> files,
    required bool background,
  }) async {
    final service = ref.notifier(sendProvider);
    final sessionId = await service.createSession(
      target: target,
      files: files,
      background: background,
    );

    if (!background) {
      // ignore: use_build_context_synchronously, unawaited_futures
      Routerino.context.push(
        () => SendPage(showAppBar: false, closeSessionOnClose: true, sessionId: sessionId),
        transition: RouterinoTransition.fade(),
      );
    }

    bool invalidPin = false;
    bool pinFirstAttempt = true;
    String? pin;

    PrepareUploadResult? result;

    do {
      invalidPin = false;
      result = await service.submitRequest(sessionId: sessionId, pin: pin);

      bool isPinRequired = false;
      result.maybeWhen(
        pinRequired: () => isPinRequired = true,
        orElse: () {},
      );

      if (isPinRequired) {
        invalidPin = true;
        // wait until animation is finished
        await sleepAsync(500);

        pin = await showDialog<String>(
          context: Routerino.context, // ignore: use_build_context_synchronously
          builder: (_) => PinDialog(
            obscureText: true,
            showInvalidPin: !pinFirstAttempt,
          ),
        );

        pinFirstAttempt = false;

        if (pin == null) {
          service.cancelSessionBySender(sessionId);
          return;
        }
      }
    } while (invalidPin);

    await result.when(
      success: (sessionId, files) async {
        final sessionState = ref.read(sendProvider)[sessionId];
        if (sessionState?.background == false) {
          final background = ref.read(settingsProvider).sendMode == SendMode.multiple;

          // ignore: use_build_context_synchronously, unawaited_futures
          Routerino.context.pushAndRemoveUntil(
            removeUntil: HomePage,
            transition: RouterinoTransition.fade(),
            builder: () => ProgressPage(
              showAppBar: background,
              closeSessionOnClose: !background,
              sessionId: sessionId,
            ),
          );
        }
        await service.startUpload(sessionId: sessionId, fileMap: files);
      },
      pinRequired: () {
        // Handled in loop
      },
      declined: () {},
      recipientBusy: () {},
      tooManyAttempts: () {},
      error: (error) {},
    );
  }
}
