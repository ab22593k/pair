import 'dart:async';

import 'package:common/model/device.dart';
import 'package:common/model/session_status.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/features/send/provider/send_session_service.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/provider/device_info_provider.dart';
import 'package:localsend_app/provider/favorites_provider.dart';
import 'package:localsend_app/util/device_type_ext.dart';
import 'package:localsend_app/util/favorites.dart';
import 'package:localsend_app/util/native/taskbar_helper.dart';
import 'package:localsend_app/widget/animations/initial_fade_transition.dart';
import 'package:localsend_app/widget/animations/initial_slide_transition.dart';
import 'package:localsend_app/widget/animations/shimmer.dart';
import 'package:localsend_app/widget/custom_basic_appbar.dart';
import 'package:localsend_app/widget/dialogs/error_dialog.dart';

import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:rhizu/rhizu.dart';
import 'package:routerino/routerino.dart';

class SendPage extends StatefulWidget {
  final bool showAppBar;
  final bool closeSessionOnClose;
  final String sessionId;

  const SendPage({
    required this.showAppBar,
    required this.closeSessionOnClose,
    required this.sessionId,
  });

  @override
  State<SendPage> createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> with Refena {
  Device? _myDevice;
  Device? _targetDevice;

  @override
  void dispose() {
    super.dispose();
    unawaited(TaskbarHelper.clearProgressBar());
  }

  void _cancel() {
    // the state will be lost so we store them temporarily (only for UI)
    final myDevice = ref.read(deviceFullInfoProvider);
    final sendState = ref.read(sendProvider)[widget.sessionId];
    if (sendState == null) {
      return;
    }

    setState(() {
      _myDevice = myDevice;
      _targetDevice = sendState.target;
    });
    ref.notifier(sendProvider).cancelSession(widget.sessionId);
  }

  @override
  Widget build(BuildContext context) {
    final sendState = ref.watch(
      sendProvider.select((state) => state[widget.sessionId]),
      listener: (prev, next) {
        final prevStatus = prev[widget.sessionId]?.status;
        final nextStatus = next[widget.sessionId]?.status;
        if (prevStatus != nextStatus) {
          // ignore: discarded_futures
          TaskbarHelper.visualizeStatus(nextStatus);
        }
      },
    );
    if (sendState == null && _myDevice == null && _targetDevice == null) {
      return Scaffold(
        body: Container(),
      );
    }
    final myDevice = ref.watch(deviceFullInfoProvider);
    final targetDevice = sendState?.target ?? _targetDevice!;
    final targetFavoriteEntry = ref.watch(favoritesProvider.select((state) => state.findDevice(targetDevice)));
    final waiting = sendState?.status == SessionStatus.waiting;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && widget.closeSessionOnClose) {
          _cancel();
        }
      },
      canPop: true,
      child: Scaffold(
        appBar: widget.showAppBar ? basicLocalSendAppbar('') : null,
        body: Stack(
          children: [
            // Decorative background elements
            Positioned(
              top: -100,
              right: -100,
              child: _DecorativeCircle(
                size: 300,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -50,
              child: _DecorativeCircle(
                size: 200,
                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.05),
              ),
            ),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: ResponsiveListView.defaultMaxWidth),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 30),
                    child: Column(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              InitialSlideTransition(
                                origin: const Offset(0, -1),
                                duration: const Duration(milliseconds: 400),
                                child: _DeviceVisual(
                                  device: myDevice,
                                  label: t.sendPage.waiting,
                                  shimmer: waiting,
                                ),
                              ),
                              const SizedBox(height: 30),
                              InitialFadeTransition(
                                duration: const Duration(milliseconds: 300),
                                delay: const Duration(milliseconds: 400),
                                child: const MorphingLI.large(containment: Containment.contained),
                              ),
                              const SizedBox(height: 30),
                              Hero(
                                tag: 'device-${targetDevice.ip}',
                                child: InitialSlideTransition(
                                  origin: const Offset(0, 1),
                                  duration: const Duration(milliseconds: 400),
                                  delay: const Duration(milliseconds: 200),
                                  child: _DeviceVisual(
                                    device: targetDevice,
                                    nameOverride: targetFavoriteEntry?.alias,
                                    shimmer: waiting,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (sendState != null)
                          InitialFadeTransition(
                            duration: const Duration(milliseconds: 300),
                            delay: const Duration(milliseconds: 400),
                            child: Column(
                              children: [
                                switch (sendState.status) {
                                  SessionStatus.waiting => Padding(
                                    padding: const EdgeInsets.only(bottom: 20),
                                    child: Text(t.sendPage.waiting, textAlign: TextAlign.center),
                                  ),
                                  SessionStatus.declined => Padding(
                                    padding: const EdgeInsets.only(bottom: 20),
                                    child: Text(
                                      t.sendPage.rejected,
                                      style: TextStyle(color: Theme.of(context).colorScheme.warning),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  SessionStatus.tooManyAttempts => Padding(
                                    padding: const EdgeInsets.only(bottom: 20),
                                    child: Text(
                                      t.sendPage.tooManyAttempts,
                                      style: TextStyle(color: Theme.of(context).colorScheme.warning),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  SessionStatus.recipientBusy => Padding(
                                    padding: const EdgeInsets.only(bottom: 20),
                                    child: Text(
                                      t.sendPage.busy,
                                      style: TextStyle(color: Theme.of(context).colorScheme.warning),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  SessionStatus.finishedWithErrors => Padding(
                                    padding: const EdgeInsets.only(bottom: 20),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(t.general.error, style: TextStyle(color: Theme.of(context).colorScheme.warning)),
                                        if (sendState.errorMessage != null)
                                          TextButton(
                                            style: TextButton.styleFrom(
                                              foregroundColor: Theme.of(context).colorScheme.warning,
                                            ),
                                            onPressed: () async => showDialog(
                                              context: context,
                                              builder: (_) => ErrorDialog(error: sendState.errorMessage!),
                                            ),
                                            child: HugeIcon(icon: HugeIcons.strokeRoundedInformationCircle, color: Theme.of(context).iconTheme.color),
                                          ),
                                      ],
                                    ),
                                  ),
                                  _ => const SizedBox(),
                                },
                                Center(
                                  child: FilledButton.icon(
                                    onPressed: () {
                                      _cancel();
                                      context.pop();
                                    },
                                    icon: waiting
                                        ? HugeIcon(icon: HugeIcons.strokeRoundedCancel01, color: Theme.of(context).iconTheme.color)
                                        : HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01, color: Theme.of(context).iconTheme.color),
                                    label: Text(waiting ? t.general.cancel : t.general.close),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceVisual extends StatelessWidget {
  final Device device;
  final String? label;
  final String? nameOverride;
  final bool shimmer;

  const _DeviceVisual({
    required this.device,
    this.label,
    this.nameOverride,
    this.shimmer = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Shimmer(
      enabled: shimmer,
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: ExpressiveRadius.large,
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: SizedBox(
                width: 32,
                height: 32,
                child: device.deviceType.icon(context),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              nameOverride ?? device.alias,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (label != null) ...[
              const SizedBox(height: 4),
              Text(
                label!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ] else ...[
              const SizedBox(height: 4),
              Text(
                device.deviceModel ?? '',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _DecorativeCircle({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
