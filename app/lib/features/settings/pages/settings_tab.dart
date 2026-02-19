import 'dart:io';
import 'dart:ui';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:common/constants.dart';
import 'package:common/model/device.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/features/settings/pages/network_interfaces_page.dart';
import 'package:localsend_app/features/settings/provider/settings_provider.dart';
import 'package:localsend_app/features/settings/settings_tab_controller.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/pages/about/about_page.dart';
import 'package:localsend_app/pages/changelog_page.dart';
import 'package:localsend_app/pages/donation/donation_page.dart';
import 'package:localsend_app/pages/language_page.dart';
import 'package:localsend_app/provider/version_provider.dart';
import 'package:localsend_app/util/alias_generator.dart';
import 'package:localsend_app/util/device_type_ext.dart';
import 'package:localsend_app/util/native/macos_channel.dart';
import 'package:localsend_app/util/native/pick_directory_path.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/widget/animations/initial_fade_transition.dart';
import 'package:localsend_app/widget/custom_dropdown_button.dart';
import 'package:localsend_app/widget/dialogs/encryption_disabled_notice.dart';
import 'package:localsend_app/widget/dialogs/pin_dialog.dart';
import 'package:localsend_app/widget/dialogs/quick_save_from_favorites_notice.dart';
import 'package:localsend_app/widget/dialogs/quick_save_notice.dart';
import 'package:localsend_app/widget/dialogs/text_field_tv.dart';
import 'package:localsend_app/widget/dialogs/text_field_with_actions.dart';
import 'package:localsend_app/widget/labeled_checkbox.dart';
import 'package:localsend_app/widget/local_send_logo.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:rhizu/rhizu.dart';
import 'package:routerino/routerino.dart';
import 'package:url_launcher/url_launcher.dart';

/// Expressive spacing tokens for consistent layout
class _ExpressiveSpacing {
  static const double xs = 4;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class SettingsTab extends StatelessWidget {
  const SettingsTab();

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder(
      provider: (ref) => settingsTabControllerProvider,
      builder: (context, vm) {
        final ref = context.ref;
        final colorScheme = Theme.of(context).colorScheme;
        return Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(
                right: MediaQuery.of(context).padding.right,
              ), // So camera or 3-button navigation doesn't interfere on the right, rest is handled
              child: ResponsiveListView(
                padding: const EdgeInsets.symmetric(horizontal: _ExpressiveSpacing.lg, vertical: _ExpressiveSpacing.xxl),
                children: [
                  SizedBox(height: _ExpressiveSpacing.xxl + MediaQuery.of(context).padding.top),
                  InitialFadeTransition(
                    duration: const Duration(milliseconds: 400),
                    delay: const Duration(milliseconds: 100),
                    child: _SettingsSection(
                      title: t.settingsTab.general.title,
                      sectionIcon: HugeIcons.strokeRoundedSettings01,
                      children: [
                        _SettingsEntry(
                          label: t.settingsTab.general.brightness,
                          child: CustomDropdownButton<ThemeMode>(
                            value: vm.settings.theme,
                            items: vm.themeModes.map((theme) {
                              return DropdownMenuItem(
                                value: theme,
                                alignment: Alignment.center,
                                child: Text(theme.humanName),
                              );
                            }).toList(),
                            onChanged: (theme) => vm.onChangeTheme(context, theme),
                          ),
                        ),
                        _SettingsEntry(
                          label: t.settingsTab.general.color,
                          child: CustomDropdownButton<ColorMode>(
                            value: vm.settings.colorMode,
                            items: vm.colorModes.map((colorMode) {
                              return DropdownMenuItem(
                                value: colorMode,
                                alignment: Alignment.center,
                                child: Text(colorMode.humanName),
                              );
                            }).toList(),
                            onChanged: vm.onChangeColorMode,
                          ),
                        ),
                        _ButtonEntry(
                          label: t.settingsTab.general.language,
                          buttonLabel: vm.settings.locale?.humanName ?? t.settingsTab.general.languageOptions.system,
                          onTap: () => vm.onTapLanguage(context),
                        ),
                        if (checkPlatformIsDesktop()) ...[
                          /// Wayland does window position handling, so there's no need for it. See [https://github.com/localsend/localsend/issues/544]
                          if (vm.advanced && checkPlatformIsNotWaylandDesktop())
                            _BooleanEntry(
                              label: defaultTargetPlatform == TargetPlatform.windows
                                  ? t.settingsTab.general.saveWindowPlacementWindows
                                  : t.settingsTab.general.saveWindowPlacement,
                              value: vm.settings.saveWindowPlacement,
                              onChanged: (b) async {
                                await ref.notifier(settingsProvider).setSaveWindowPlacement(b);
                              },
                            ),
                          if (checkPlatformHasTray()) ...[
                            _BooleanEntry(
                              label: t.settingsTab.general.minimizeToTray,
                              value: vm.settings.minimizeToTray,
                              onChanged: (b) async {
                                await ref.notifier(settingsProvider).setMinimizeToTray(b);
                              },
                            ),
                          ],
                          if (checkPlatformIsDesktop()) ...[
                            _BooleanEntry(
                              label: t.settingsTab.general.launchAtStartup,
                              value: vm.autoStart,
                              onChanged: (_) => vm.onToggleAutoStart(context),
                            ),
                            Visibility(
                              visible: vm.autoStart,
                              maintainAnimation: true,
                              maintainState: true,
                              child: AnimatedOpacity(
                                opacity: vm.autoStart ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 500),
                                child: _BooleanEntry(
                                  label: t.settingsTab.general.launchMinimized,
                                  value: vm.autoStartLaunchHidden,
                                  onChanged: (_) => vm.onToggleAutoStartLaunchHidden(context),
                                ),
                              ),
                            ),
                          ],
                          if (vm.advanced && checkPlatform([TargetPlatform.windows])) ...[
                            _BooleanEntry(
                              label: t.settingsTab.general.showInContextMenu,
                              value: vm.showInContextMenu,
                              onChanged: (_) => vm.onToggleShowInContextMenu(context),
                            ),
                          ],
                        ],
                        _BooleanEntry(
                          label: t.settingsTab.general.animations,
                          value: vm.settings.enableAnimations,
                          onChanged: (b) async {
                            await ref.notifier(settingsProvider).setEnableAnimations(b);
                          },
                        ),
                      ],
                    ),
                  ),
                  InitialFadeTransition(
                    duration: const Duration(milliseconds: 400),
                    delay: const Duration(milliseconds: 200),
                    child: _SettingsSection(
                      title: t.settingsTab.receive.title,
                      sectionIcon: HugeIcons.strokeRoundedDownload01,
                      children: [
                        _BooleanEntry(
                          label: t.settingsTab.receive.quickSave,
                          value: vm.settings.quickSave,
                          onChanged: (b) async {
                            final old = vm.settings.quickSave;
                            await ref.notifier(settingsProvider).setQuickSave(b);
                            if (!old && b && context.mounted) {
                              await QuickSaveNotice.open(context);
                            }
                          },
                        ),
                        _BooleanEntry(
                          label: t.settingsTab.receive.quickSaveFromFavorites,
                          value: vm.settings.quickSaveFromFavorites,
                          onChanged: (b) async {
                            final old = vm.settings.quickSaveFromFavorites;
                            await ref.notifier(settingsProvider).setQuickSaveFromFavorites(b);
                            if (!old && b && context.mounted) {
                              await QuickSaveFromFavoritesNotice.open(context);
                            }
                          },
                        ),
                        _BooleanEntry(
                          label: t.settingsTab.receive.requirePin,
                          value: vm.settings.receivePin != null,
                          onChanged: (b) async {
                            final currentPIN = vm.settings.receivePin;
                            if (currentPIN != null) {
                              await ref.notifier(settingsProvider).setReceivePin(null);
                            } else {
                              final String? newPin = await showDialog<String>(
                                context: context,
                                builder: (_) => const PinDialog(
                                  obscureText: false,
                                  generateRandom: false,
                                ),
                              );

                              if (newPin != null && newPin.isNotEmpty) {
                                await ref.notifier(settingsProvider).setReceivePin(newPin);
                              }
                            }
                          },
                        ),
                        if (checkPlatformWithFileSystem())
                          _SettingsEntry(
                            label: t.settingsTab.receive.destination,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: Theme.of(context).inputDecorationTheme.fillColor,
                                shape: RoundedRectangleBorder(borderRadius: Theme.of(context).inputDecorationTheme.borderRadius),
                                foregroundColor: Theme.of(context).colorScheme.onSurface,
                              ),
                              onPressed: () async {
                                if (vm.settings.destination != null) {
                                  await ref.notifier(settingsProvider).setDestination(null);
                                  if (defaultTargetPlatform == TargetPlatform.macOS) {
                                    await removeExistingDestinationAccess();
                                  }
                                  return;
                                }

                                final directory = await pickDirectoryPath();
                                if (directory != null) {
                                  if (defaultTargetPlatform == TargetPlatform.macOS) {
                                    await persistDestinationFolderAccess(directory);
                                  }
                                  await ref.notifier(settingsProvider).setDestination(directory);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                child: Text(
                                  vm.settings.destination ?? t.settingsTab.receive.downloads,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                            ),
                          ),
                        if (checkPlatformWithGallery())
                          _BooleanEntry(
                            label: t.settingsTab.receive.saveToGallery,
                            value: vm.settings.saveToGallery,
                            onChanged: (b) async {
                              await ref.notifier(settingsProvider).setSaveToGallery(b);
                            },
                          ),
                        _BooleanEntry(
                          label: t.settingsTab.receive.autoFinish,
                          value: vm.settings.autoFinish,
                          onChanged: (b) async {
                            await ref.notifier(settingsProvider).setAutoFinish(b);
                          },
                        ),
                        _BooleanEntry(
                          label: t.settingsTab.receive.saveToHistory,
                          value: vm.settings.saveToHistory,
                          onChanged: (b) async {
                            await ref.notifier(settingsProvider).setSaveToHistory(b);
                          },
                        ),
                      ],
                    ),
                  ),
                  if (vm.advanced)
                    InitialFadeTransition(
                      duration: const Duration(milliseconds: 400),
                      delay: const Duration(milliseconds: 300),
                      child: _SettingsSection(
                        title: t.settingsTab.send.title,
                        sectionIcon: HugeIcons.strokeRoundedUpload01,
                        children: [
                          _BooleanEntry(
                            label: t.settingsTab.send.shareViaLinkAutoAccept,
                            value: vm.settings.shareViaLinkAutoAccept,
                            onChanged: (b) async {
                              await ref.notifier(settingsProvider).setShareViaLinkAutoAccept(b);
                            },
                          ),
                        ],
                      ),
                    ),
                  InitialFadeTransition(
                    duration: const Duration(milliseconds: 400),
                    delay: const Duration(milliseconds: 400),
                    child: _SettingsSection(
                      title: t.settingsTab.network.title,
                      sectionIcon: HugeIcons.strokeRoundedWifi01,
                      children: [
                        AnimatedCrossFade(
                          crossFadeState:
                              vm.serverState != null &&
                                  (vm.serverState!.alias != vm.settings.alias ||
                                      vm.serverState!.port != vm.settings.port ||
                                      vm.serverState!.https != vm.settings.https)
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 200),
                          alignment: Alignment.topLeft,
                          firstChild: Container(),
                          secondChild: Padding(
                            padding: const EdgeInsets.only(bottom: 15),
                            child: Text(t.settingsTab.network.needRestart, style: TextStyle(color: Theme.of(context).colorScheme.warning)),
                          ),
                        ),
                        _SettingsEntry(
                          label: '${t.settingsTab.network.server}${vm.serverState == null ? ' (${t.general.offline})' : ''}',
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Theme.of(context).inputDecorationTheme.fillColor,
                              borderRadius: Theme.of(context).inputDecorationTheme.borderRadius,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Tooltip(
                                  message: vm.serverState == null ? t.general.start : t.general.stop,
                                  child: GestureDetector(
                                    onTap: vm.serverState == null ? () => vm.onTapStartServer(context) : vm.onTapStopServer,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: HugeIcon(
                                        icon: HugeIcons.strokeRoundedServerStack02,
                                        color: vm.serverState == null ? Theme.of(context).colorScheme.error : Theme.of(context).iconTheme.color,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _SettingsEntry(
                          label: t.settingsTab.network.alias,
                          child: TextFieldWithActions(
                            name: t.settingsTab.network.alias,
                            controller: vm.aliasController,
                            onChanged: (s) async {
                              await ref.notifier(settingsProvider).setAlias(s);
                            },
                            actions: [
                              Tooltip(
                                message: t.settingsTab.network.generateRandomAlias,
                                child: IconButton(
                                  onPressed: () async {
                                    // Generates random alias
                                    final newAlias = generateRandomAlias();

                                    // Update the TextField with the new alias
                                    vm.aliasController.text = newAlias;

                                    // Persist the new alias using the settingsProvider
                                    await ref.notifier(settingsProvider).setAlias(newAlias);
                                  },
                                  icon: HugeIcon(icon: HugeIcons.strokeRoundedDice, color: Theme.of(context).iconTheme.color),
                                ),
                              ),
                              Tooltip(
                                message: t.settingsTab.network.useSystemName,
                                child: IconButton(
                                  onPressed: () async {
                                    final String newAlias;
                                    if (Platform.isMacOS) {
                                      final result = await Process.run('scutil', ['--get', 'ComputerName']);
                                      newAlias = result.stdout.toString().trim();
                                    } else {
                                      newAlias = Platform.localHostname;
                                    }

                                    vm.aliasController.text = newAlias;
                                    await ref.notifier(settingsProvider).setAlias(newAlias);
                                  },
                                  icon: HugeIcon(icon: HugeIcons.strokeRoundedComputer, color: Theme.of(context).iconTheme.color),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (vm.advanced)
                          _SettingsEntry(
                            label: t.settingsTab.network.deviceType,
                            child: CustomDropdownButton<DeviceType>(
                              value: vm.deviceInfo.deviceType,
                              items: DeviceType.values.map((type) {
                                return DropdownMenuItem(
                                  value: type,
                                  alignment: Alignment.center,
                                  child: Builder(
                                    builder: (context) => type.icon(context),
                                  ),
                                );
                              }).toList(),
                              onChanged: (type) async {
                                await ref.notifier(settingsProvider).setDeviceType(type);
                              },
                            ),
                          ),
                        if (vm.advanced)
                          _SettingsEntry(
                            label: t.settingsTab.network.deviceModel,
                            child: TextFieldTv(
                              name: t.settingsTab.network.deviceModel,
                              controller: vm.deviceModelController,
                              onChanged: (s) async {
                                await ref.notifier(settingsProvider).setDeviceModel(s);
                              },
                            ),
                          ),
                        if (vm.advanced)
                          _SettingsEntry(
                            label: t.settingsTab.network.port,
                            child: TextFieldTv(
                              name: t.settingsTab.network.port,
                              controller: vm.portController,
                              onChanged: (s) async {
                                final port = int.tryParse(s);
                                if (port != null) {
                                  await ref.notifier(settingsProvider).setPort(port);
                                }
                              },
                            ),
                          ),
                        if (vm.advanced)
                          _ButtonEntry(
                            label: t.settingsTab.network.network,
                            buttonLabel: switch (vm.settings.networkWhitelist != null || vm.settings.networkBlacklist != null) {
                              true => t.settingsTab.network.networkOptions.filtered,
                              false => t.settingsTab.network.networkOptions.all,
                            },
                            onTap: () async {
                              await context.push(() => const NetworkInterfacesPage());
                            },
                          ),
                        if (vm.advanced)
                          _SettingsEntry(
                            label: t.settingsTab.network.discoveryTimeout,
                            child: TextFieldTv(
                              name: t.settingsTab.network.discoveryTimeout,
                              controller: vm.timeoutController,
                              onChanged: (s) async {
                                final timeout = int.tryParse(s);
                                if (timeout != null) {
                                  await ref.notifier(settingsProvider).setDiscoveryTimeout(timeout);
                                }
                              },
                            ),
                          ),
                        if (vm.advanced)
                          _BooleanEntry(
                            label: t.settingsTab.network.encryption,
                            value: vm.settings.https,
                            onChanged: (b) async {
                              final old = vm.settings.https;
                              await ref.notifier(settingsProvider).setHttps(b);
                              if (old && !b && context.mounted) {
                                await EncryptionDisabledNotice.open(context);
                              }
                            },
                          ),
                        if (vm.advanced)
                          _SettingsEntry(
                            label: t.settingsTab.network.multicastGroup,
                            child: TextFieldTv(
                              name: t.settingsTab.network.multicastGroup,
                              controller: vm.multicastController,
                              onChanged: (s) async {
                                await ref.notifier(settingsProvider).setMulticastGroup(s);
                              },
                            ),
                          ),
                        AnimatedCrossFade(
                          crossFadeState: vm.settings.port != defaultPort ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 200),
                          alignment: Alignment.topLeft,
                          firstChild: Container(),
                          secondChild: Padding(
                            padding: const EdgeInsets.only(bottom: 15),
                            child: Text(
                              t.settingsTab.network.portWarning(defaultPort: defaultPort),
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                        AnimatedCrossFade(
                          crossFadeState: vm.settings.multicastGroup != defaultMulticastGroup ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 200),
                          alignment: Alignment.topLeft,
                          firstChild: Container(),
                          secondChild: Padding(
                            padding: const EdgeInsets.only(bottom: 15),
                            child: Text(
                              t.settingsTab.network.multicastGroupWarning(defaultMulticast: defaultMulticastGroup),
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  InitialFadeTransition(
                    duration: const Duration(milliseconds: 400),
                    delay: const Duration(milliseconds: 500),
                    child: _SettingsSection(
                      title: t.settingsTab.other.title,
                      sectionIcon: HugeIcons.strokeRoundedInformationCircle,
                      padding: const EdgeInsets.only(bottom: 0),
                      children: [
                        _ButtonEntry(
                          label: t.aboutPage.title,
                          buttonLabel: t.general.open,
                          onTap: () async {
                            await context.push(() => const AboutPage());
                          },
                        ),
                        _ButtonEntry(
                          label: t.settingsTab.other.support,
                          buttonLabel: t.settingsTab.other.donate,
                          onTap: () async {
                            await context.push(() => const DonationPage());
                          },
                        ),
                        _ButtonEntry(
                          label: t.settingsTab.other.privacyPolicy,
                          buttonLabel: t.general.open,
                          onTap: () async {
                            await launchUrl(
                              Uri.parse('https://localsend.org/privacy'),
                              mode: LaunchMode.externalApplication,
                            );
                          },
                        ),
                        if (checkPlatform([TargetPlatform.iOS, TargetPlatform.macOS]))
                          _ButtonEntry(
                            label: t.settingsTab.other.termsOfUse,
                            buttonLabel: t.general.open,
                            onTap: () async {
                              await launchUrl(
                                Uri.parse('https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'),
                                mode: LaunchMode.externalApplication,
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: _ExpressiveSpacing.md),
                  InitialFadeTransition(
                    duration: const Duration(milliseconds: 400),
                    delay: const Duration(milliseconds: 600),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        LabeledCheckbox(
                          label: t.settingsTab.advancedSettings,
                          value: vm.advanced,
                          labelFirst: true,
                          onChanged: (b) async {
                            vm.onTapAdvanced(b == true);
                            await ref.notifier(settingsProvider).setAdvancedSettingsEnabled(b == true);
                          },
                        ),
                        const SizedBox(width: _ExpressiveSpacing.md),
                      ],
                    ),
                  ),
                  const SizedBox(height: _ExpressiveSpacing.xl),
                  const LocalSendLogo(withText: true),
                  const SizedBox(height: _ExpressiveSpacing.xs),
                  ref
                      .watch(versionProvider)
                      .maybeWhen(
                        data: (version) => Text(
                          'Version: $version',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                  Text(
                    '© ${DateTime.now().year} Tien Do Nam',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: _ExpressiveSpacing.sm),
                  Center(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.primary,
                      ),
                      onPressed: () async {
                        await context.push(() => const ChangelogPage());
                      },
                      icon: const HugeIcon(icon: HugeIcons.strokeRoundedClock01, size: 16),
                      label: Text(t.changelogPage.title),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
            // a pseudo appbar that is draggable for the settings page
            SizedBox(
              height: 80 + MediaQuery.of(context).padding.top,
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 30.0,
                    sigmaY: 30.0,
                  ),
                  child: MoveWindow(
                    child: SafeArea(
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.only(top: 16),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            t.settingsTab.title,
                            style: GoogleFonts.plusJakartaSans(
                              textStyle: Theme.of(context).textTheme.headlineSmall,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SettingsEntry extends StatelessWidget {
  final String label;
  final Widget child;

  const _SettingsEntry({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _ExpressiveSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: _ExpressiveSpacing.md),
          SizedBox(
            width: 160,
            child: Align(
              alignment: Alignment.centerRight,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// A specialized version of [_SettingsEntry].
class _BooleanEntry extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _BooleanEntry({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SettingsEntry(
      label: label,
      child: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: theme.colorScheme.primary,
        activeThumbColor: theme.colorScheme.onPrimary,
        inactiveThumbColor: theme.colorScheme.outline,
        inactiveTrackColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
    );
  }
}

/// A specialized version of [_SettingsEntry].
class _ButtonEntry extends StatelessWidget {
  final String label;
  final String buttonLabel;
  final void Function() onTap;

  const _ButtonEntry({
    required this.label,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsEntry(
      label: label,
      child: FilledButton.tonal(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: _ExpressiveSpacing.md, vertical: 12),
        ),
        onPressed: onTap,
        child: Text(
          buttonLabel,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<List<dynamic>> sectionIcon;
  final List<Widget> children;
  final EdgeInsets padding;

  const _SettingsSection({
    required this.title,
    required this.sectionIcon,
    required this.children,
    this.padding = const EdgeInsets.only(bottom: _ExpressiveSpacing.xl),
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(_ExpressiveSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: HugeIcon(
                      icon: sectionIcon,
                      color: colorScheme.onPrimaryContainer,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: _ExpressiveSpacing.md),
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      textStyle: Theme.of(context).textTheme.titleLarge,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: _ExpressiveSpacing.xl),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

extension on ThemeMode {
  String get humanName {
    switch (this) {
      case ThemeMode.system:
        return t.settingsTab.general.brightnessOptions.system;
      case ThemeMode.light:
        return t.settingsTab.general.brightnessOptions.light;
      case ThemeMode.dark:
        return t.settingsTab.general.brightnessOptions.dark;
    }
  }
}

extension on ColorMode {
  String get humanName {
    return switch (this) {
      ColorMode.system => t.settingsTab.general.colorOptions.system,
      ColorMode.localsend => t.appName,
      ColorMode.oled => t.settingsTab.general.colorOptions.oled,
      ColorMode.yaru => 'Yaru',
    };
  }
}
