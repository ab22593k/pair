import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:localsend_app/features/settings/provider/settings_provider.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/util/native/cmd_helper.dart';
import 'package:localsend_app/util/native/macos_channel.dart' as macos_channel;
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/widget/custom_basic_appbar.dart';
import 'package:localsend_app/widget/dialogs/not_available_on_platform_dialog.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';

class TroubleshootPage extends StatelessWidget {
  const TroubleshootPage();

  @override
  Widget build(BuildContext context) {
    final settings = context.ref.watch(settingsProvider);
    return Scaffold(
      appBar: basicLocalSendAppbar(t.troubleshootPage.title),
      body: ResponsiveListView(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 30),
        children: [
          Text(
            t.troubleshootPage.subTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          _TroubleshootItem(
            icon: HugeIcons.strokeRoundedSecurityCheck,
            symptomText: t.troubleshootPage.firewall.symptom,
            solutionText: t.troubleshootPage.firewall.solution(port: settings.port),
            primaryButton: _FixButton(
              label: t.troubleshootPage.fixButton,
              onTapMap: {
                TargetPlatform.windows: _CommandFixAction(
                  adminPrivileges: true,
                  commands: [
                    'netsh advfirewall firewall add rule name="LocalSend" dir=in action=allow protocol=TCP localport=${settings.port}',
                    'netsh advfirewall firewall add rule name="LocalSend" dir=in action=allow protocol=UDP localport=${settings.port}',
                  ],
                ),
              },
            ),
            secondaryButton: _FixButton(
              label: t.troubleshootPage.firewall.openFirewall,
              isSecondary: true,
              onTapMap: {
                TargetPlatform.windows: _CommandFixAction(
                  adminPrivileges: false,
                  commands: ['wf'],
                ),
                TargetPlatform.macOS: _NativeFixAction(() => macos_channel.openFirewallSettings()),
              },
            ),
          ),
          _TroubleshootItem(
            icon: HugeIcons.strokeRoundedSearch01,
            symptomText: t.troubleshootPage.noDiscovery.symptom,
            solutionText: t.troubleshootPage.noDiscovery.solution,
          ),
          _TroubleshootItem(
            icon: HugeIcons.strokeRoundedWifi01,
            symptomText: t.troubleshootPage.noConnection.symptom,
            solutionText: t.troubleshootPage.noConnection.solution,
          ),
        ],
      ),
    );
  }
}

class _TroubleshootItem extends StatefulWidget {
  final dynamic icon;
  final String symptomText;
  final String solutionText;
  final _FixButton? primaryButton;
  final _FixButton? secondaryButton;

  const _TroubleshootItem({
    required this.icon,
    required this.symptomText,
    required this.solutionText,
    this.primaryButton,
    this.secondaryButton,
  });

  @override
  State<_TroubleshootItem> createState() => _TroubleshootItemState();
}

class _TroubleshootItemState extends State<_TroubleshootItem> {
  bool _showCommands = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        color: colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: HugeIcon(
                      icon: widget.icon,
                      color: colorScheme.onPrimaryContainer,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.symptomText,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.troubleshootPage.solution,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.solutionText,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (widget.primaryButton != null) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    widget.primaryButton!,
                    if (widget.secondaryButton != null) widget.secondaryButton!,
                    if (widget.primaryButton!.onTap?.commands != null)
                      IconButton.filledTonal(
                        onPressed: () {
                          setState(() => _showCommands = !_showCommands);
                        },
                        icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedInformationCircle,
                          size: 20,
                        ),
                        tooltip: 'Show commands',
                      ),
                  ],
                ),
                AnimatedCrossFade(
                  crossFadeState: _showCommands ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                  firstChild: Container(),
                  secondChild: Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(10),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectionArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...?widget.primaryButton?.onTap?.commands?.map((cmd) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                cmd,
                                style: TextStyle(
                                  fontFamily: 'RobotoMono',
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FixButton extends StatelessWidget {
  final String label;
  final Map<TargetPlatform, _FixAction> onTapMap;
  final _FixAction? onTap;
  final bool isSecondary;

  _FixButton({
    required this.label,
    required this.onTapMap,
    this.isSecondary = false,
  }) : onTap = onTapMap[defaultTargetPlatform];

  @override
  Widget build(BuildContext context) {
    if (isSecondary) {
      return OutlinedButton(
        onPressed: () async => _handlePress(context),
        child: Text(label),
      );
    }
    return FilledButton(
      onPressed: () async => _handlePress(context),
      child: Text(label),
    );
  }

  Future<void> _handlePress(BuildContext context) async {
    if (onTap != null) {
      onTap!.runFix();
    } else {
      await showDialog(
        context: context,
        builder: (_) => NotAvailableOnPlatformDialog(platforms: onTapMap.keys.toList()),
      );
    }
  }
}

abstract class _FixAction {
  void runFix();

  List<String>? get commands;
}

class _CommandFixAction extends _FixAction {
  final bool adminPrivileges;

  @override
  final List<String> commands;

  _CommandFixAction({
    required this.adminPrivileges,
    required this.commands,
  });

  @override
  void runFix() async {
    if (adminPrivileges) {
      if (checkPlatform([TargetPlatform.windows])) {
        await runWindowsCommandAsAdmin(commands);
      } else {
        throw 'Admin privileges are only implemented on Windows.';
      }
    } else {
      for (final c in commands) {
        await Process.run(c, [], runInShell: true);
      }
    }
  }
}

class _NativeFixAction extends _FixAction {
  final Future<void> Function() action;

  _NativeFixAction(this.action);

  @override
  List<String>? get commands => null;

  @override
  void runFix() async {
    await action();
  }
}
