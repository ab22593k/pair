import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:collection/collection.dart';
import 'package:common/model/device.dart';
import 'package:common/model/session_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:localsend_app/features/send/pages/selected_files_page.dart';
import 'package:localsend_app/features/send/provider/selected_sending_files_provider.dart';
import 'package:localsend_app/features/send/provider/send_provider.dart';
import 'package:localsend_app/features/send/send_tab_vm.dart';
import 'package:localsend_app/features/settings/provider/settings_provider.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/send_mode.dart';
import 'package:localsend_app/pages/troubleshoot_page.dart';
import 'package:localsend_app/provider/animation_provider.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/provider/network/scan_facade.dart';
import 'package:localsend_app/provider/progress_provider.dart';
import 'package:localsend_app/util/favorites.dart';
import 'package:localsend_app/util/file_size_helper.dart';
import 'package:localsend_app/util/native/file_picker.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/widget/animations/initial_fade_transition.dart';
import 'package:localsend_app/widget/custom_icon_button.dart';
import 'package:localsend_app/widget/dialogs/add_file_dialog.dart';
import 'package:localsend_app/widget/dialogs/send_mode_help_dialog.dart';
import 'package:localsend_app/widget/file_thumbnail.dart';
import 'package:localsend_app/widget/list_tile/device_list_tile.dart';
import 'package:localsend_app/widget/opacity_slideshow.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:localsend_app/widget/rotating_widget.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:rhizu/rhizu.dart';
import 'package:routerino/routerino.dart';

final _options = FilePickerOption.getOptionsForPlatform();

/// Expressive spacing tokens for consistent layout
class _ExpressiveSpacing {
  static const double xs = 4;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class SendTab extends StatelessWidget {
  const SendTab();

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder(
      provider: (ref) => sendTabVmProvider,
      init: (context) async => context.global.dispatchAsync(SendTabInitAction(context)), // ignore: discarded_futures
      builder: (context, vm) {
        final ref = context.ref;
        final colorScheme = Theme.of(context).colorScheme;

        return Stack(
          children: [
            ResponsiveListView(
              padding: EdgeInsets.zero,
              children: [
                if (vm.selectedFiles.isEmpty) ...[
                  const SizedBox(height: _ExpressiveSpacing.sm),
                ] else ...[
                  InitialFadeTransition(
                    duration: const Duration(milliseconds: 400),
                    child: Card(
                      margin: const EdgeInsets.symmetric(horizontal: _ExpressiveSpacing.lg),
                      elevation: 0,
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      shape: const RoundedRectangleBorder(
                        borderRadius: ShapeTokens.borderRadiusExtraLarge,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(_ExpressiveSpacing.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                HugeIcon(
                                  icon: HugeIcons.strokeRoundedFiles02,
                                  color: colorScheme.primary,
                                  size: 20,
                                ),
                                Text(
                                  t.sendTab.selection.title,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: colorScheme.onSurface,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const Spacer(),
                                CustomIconButton(
                                  onPressed: () => ref.redux(selectedSendingFilesProvider).dispatch(ClearSelectionAction()),
                                  child: HugeIcon(icon: HugeIcons.strokeRoundedCancel01, color: colorScheme.secondary),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.sendTab.selection.files(files: vm.selectedFiles.length),
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      Text(
                                        vm.selectedFiles.fold(0, (prev, curr) => prev + curr.size).asReadableFileSize,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(
                              height: defaultThumbnailSize + 16,
                              child: ListView.builder(
                                physics: SmoothScrollPhysics(
                                  parent: AlwaysScrollableScrollPhysics(),
                                ),
                                scrollDirection: Axis.horizontal,
                                itemCount: vm.selectedFiles.length,
                                itemBuilder: (context, index) {
                                  final file = vm.selectedFiles[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(right: _ExpressiveSpacing.sm),
                                    child: SmartFileThumbnail.fromCrossFile(file),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: _ExpressiveSpacing.md),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: colorScheme.onSurface,
                                    shape: const StadiumBorder(),
                                  ),
                                  onPressed: () async {
                                    await context.push(() => const SelectedFilesPage());
                                  },
                                  child: Text(t.general.edit, style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colorScheme.primary,
                                    foregroundColor: colorScheme.onPrimary,
                                    elevation: 0,
                                    shape: const StadiumBorder(),
                                    padding: const EdgeInsets.symmetric(horizontal: _ExpressiveSpacing.lg),
                                  ),
                                  onPressed: () async {
                                    if (_options.length == 1) {
                                      // open directly
                                      await ref.global.dispatchAsync(
                                        PickFileAction(
                                          option: _options.first,
                                          context: context,
                                        ),
                                      );
                                      return;
                                    }
                                    await AddFileDialog.open(
                                      context: context,
                                      options: _options,
                                    );
                                  },
                                  icon: HugeIcon(icon: HugeIcons.strokeRoundedAdd01, color: colorScheme.onPrimary),
                                  label: Text(t.general.add, style: const TextStyle(fontWeight: FontWeight.w900)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _ExpressiveSpacing.lg),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.sendTab.nearbyDevices,
                          style: GoogleFonts.plusJakartaSans(
                            textStyle: Theme.of(context).textTheme.titleLarge,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      _ScanButton(ips: vm.localIps),
                      const SizedBox(width: _ExpressiveSpacing.xs),
                      _ActionGroup(vm: vm),
                    ],
                  ),
                ),
                if (vm.nearbyDevices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _ExpressiveSpacing.lg),
                    child: InitialFadeTransition(
                      duration: const Duration(milliseconds: 600),
                      delay: const Duration(milliseconds: 200),
                      child: Center(
                        child: Column(
                          children: [
                            const SizedBox(height: _ExpressiveSpacing.xl),
                            const MorphingLI.large(
                              containment: Containment.simple,
                            ),
                            const SizedBox(height: _ExpressiveSpacing.lg),
                            Opacity(
                              opacity: 0.5,
                              child: Text(
                                t.sendTab.nearbyDevices,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: _ExpressiveSpacing.xxl),
                          ],
                        ),
                      ),
                    ),
                  ),
                ...vm.nearbyDevices.indexed.map((record) {
                  final (index, device) = record;
                  final favoriteEntry = vm.favoriteDevices.findDevice(device);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: _ExpressiveSpacing.sm, left: _ExpressiveSpacing.lg, right: _ExpressiveSpacing.lg),
                    child: InitialFadeTransition(
                      duration: const Duration(milliseconds: 400),
                      delay: Duration(milliseconds: 100 * (index + 1)),
                      child: Hero(
                        tag: 'device-${device.ip}',
                        child: vm.sendMode == SendMode.multiple
                            ? _MultiSendDeviceListTile(
                                device: device,
                                isFavorite: favoriteEntry != null,
                                nameOverride: favoriteEntry?.alias,
                                vm: vm,
                              )
                            : DeviceListTile(
                                device: device,
                                isFavorite: favoriteEntry != null,
                                nameOverride: favoriteEntry?.alias,
                                onFavoriteTap: () async => await vm.onToggleFavorite(context, device),
                                onTap: () async => await vm.onTapDevice(context, device),
                              ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: _ExpressiveSpacing.lg),
                Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      await context.push(() => const TroubleshootPage());
                    },
                    icon: const HugeIcon(icon: HugeIcons.strokeRoundedSettings01, size: 16),
                    label: Text(t.troubleshootPage.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.onSurfaceVariant,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: _ExpressiveSpacing.xl),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _ExpressiveSpacing.lg),
                  child: Consumer(
                    builder: (context, ref) {
                      final animations = ref.watch(animationProvider);
                      return OpacitySlideshow(
                        durationMillis: 6000,
                        running: animations,
                        children: [
                          Text(
                            t.sendTab.help,
                            style: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                          if (checkPlatformCanReceiveShareIntent())
                            Text(
                              t.sendTab.shareIntentInfo,
                              style: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
                              textAlign: TextAlign.center,
                            ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: _ExpressiveSpacing.xxl),
              ],
            ),
            // make the top draggable on Desktop
            if (checkPlatform([TargetPlatform.macOS])) SizedBox(height: 50, child: MoveWindow()) else const SizedBox.shrink(),
            // Expressive FAB Menu for file selection
            if (vm.selectedFiles.isEmpty)
              Positioned(
                right: 24,
                bottom: 24,
                child: FabMenu(
                  children: _options.map((option) {
                    return FabMenuItem(
                      label: option.label,
                      icon: option.icon(context),
                      onPressed: () async {
                        await ref.global.dispatchAsync(
                          PickFileAction(
                            option: option,
                            context: context,
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Grouped actions for cleaner UI
class _ActionGroup extends StatelessWidget {
  final SendTabVm vm;

  const _ActionGroup({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: t.sendTab.manualSending,
          child: CustomIconButton(
            onPressed: () async => vm.onTapAddress(context),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedCursorAddSelection01,
              color: Theme.of(context).colorScheme.primary,
              size: 19,
              strokeWidth: 2.0,
            ),
          ),
        ),
        Tooltip(
          message: t.dialogs.favoriteDialog.title,
          child: CustomIconButton(
            onPressed: () async => await vm.onTapFavorite(context),
            child: SvgPicture.asset(
              'assets/icons/device-mobile-star.svg',
              semanticsLabel: 'Favorite Device',
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(Theme.of(context).colorScheme.primary, BlendMode.srcIn),
            ),
          ),
        ),
        _SendModeButton(
          onSelect: (mode) async => vm.onTapSendMode(context, mode),
        ),
      ],
    );
  }
}

/// A button that opens a popup menu to select [T].
/// This is used for the scan button and the send mode button.
class _CircularPopupButton<T> extends StatelessWidget {
  final String tooltip;
  final PopupMenuItemBuilder<T> itemBuilder;
  final PopupMenuItemSelected<T>? onSelected;
  final Widget child;

  const _CircularPopupButton({
    required this.tooltip,
    required this.onSelected,
    required this.itemBuilder,
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: ExpressiveRadius.full,
      child: Material(
        type: MaterialType.transparency,
        child: DividerTheme(
          data: DividerThemeData(
            color: Theme.of(context).brightness == Brightness.light ? Colors.teal.shade100 : Colors.grey.shade700,
          ),
          child: PopupMenuButton(
            offset: const Offset(0, 40),
            onSelected: onSelected,
            tooltip: tooltip,
            itemBuilder: itemBuilder,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The scan button that uses [_CircularPopupButton].
class _ScanButton extends StatelessWidget {
  final List<String> ips;

  const _ScanButton({
    required this.ips,
  });

  @override
  Widget build(BuildContext context) {
    final (scanningFavorites, scanningIps) = context.ref.watch(nearbyDevicesProvider.select((s) => (s.runningFavoriteScan, s.runningIps)));
    final animations = context.ref.watch(animationProvider);

    final spinning = (scanningFavorites || scanningIps.isNotEmpty) && animations;

    if (ips.length <= StartSmartScan.maxInterfaces) {
      return Tooltip(
        message: t.sendTab.scan,
        child: RotatingWidget(
          duration: const Duration(seconds: 2),
          spinning: spinning,
          reverse: true,
          child: CustomIconButton(
            onPressed: () async {
              context.redux(nearbyDevicesProvider).dispatch(ClearFoundDevicesAction());
              await context.global.dispatchAsync(StartSmartScan(forceLegacy: true));
            },
            child: SvgPicture.asset(
              'assets/icons/Refresh03.svg',
              semanticsLabel: 'Refresh 03',
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(Theme.of(context).colorScheme.primary, BlendMode.srcIn),
            ),
          ),
        ),
      );
    }

    return _CircularPopupButton(
      tooltip: t.sendTab.scan,
      onSelected: (ip) async {
        context.redux(nearbyDevicesProvider).dispatch(ClearFoundDevicesAction());
        await context.global.dispatchAsync(StartLegacySubnetScan(subnets: [ip]));
      },
      itemBuilder: (_) {
        return [
          ...ips.map(
            (ip) => PopupMenuItem(
              value: ip,
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RotatingSyncIcon(ip),
                  const SizedBox(width: 10),
                  Text(ip),
                ],
              ),
            ),
          ),
        ];
      },
      child: RotatingWidget(
        duration: const Duration(seconds: 2),
        spinning: spinning,
        reverse: true,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: SvgPicture.asset(
            'assets/icons/Refresh03.svg',
            semanticsLabel: 'Refresh 03',
            width: 22,
            height: 22,
            colorFilter: ColorFilter.mode(Theme.of(context).colorScheme.primary, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}

/// A separate widget, so it gets the latest data from provider.
class _RotatingSyncIcon extends StatelessWidget {
  final String ip;

  const _RotatingSyncIcon(this.ip);

  @override
  Widget build(BuildContext context) {
    final scanningIps = context.ref.watch(nearbyDevicesProvider.select((s) => s.runningIps));
    return RotatingWidget(
      duration: const Duration(seconds: 2),
      spinning: scanningIps.contains(ip),
      reverse: true,
      child: HugeIcon(icon: HugeIcons.strokeRoundedRefresh, color: Theme.of(context).iconTheme.color),
    );
  }
}

class _SendModeButton extends StatelessWidget {
  final void Function(SendMode mode) onSelect;

  const _SendModeButton({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return _CircularPopupButton<int>(
      tooltip: t.sendTab.sendMode,
      onSelected: (mode) async {
        switch (mode) {
          case 0:
            onSelect(SendMode.single);
            break;
          case 1:
            onSelect(SendMode.multiple);
            break;
          case 2:
            onSelect(SendMode.link);
            break;
          case -1:
            await showDialog(context: context, builder: (_) => const SendModeHelpDialog());
            break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Consumer(
                builder: (context, ref) {
                  final sendMode = ref.watch(settingsProvider.select((s) => s.sendMode));
                  return Visibility(
                    visible: sendMode == SendMode.single,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01, color: Theme.of(context).iconTheme.color),
                  );
                },
              ),
              const SizedBox(width: 10),
              Text(t.sendTab.sendModes.single),
            ],
          ),
        ),
        PopupMenuItem(
          value: 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Consumer(
                builder: (context, ref) {
                  final sendMode = ref.watch(settingsProvider.select((s) => s.sendMode));
                  return Visibility(
                    visible: sendMode == SendMode.multiple,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01, color: Theme.of(context).iconTheme.color),
                  );
                },
              ),
              const SizedBox(width: 10),
              Text(t.sendTab.sendModes.multiple),
            ],
          ),
        ),
        PopupMenuItem(
          value: 2,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Visibility(
                visible: false,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01, color: Theme.of(context).iconTheme.color),
              ),
              const SizedBox(width: 10),
              Text(t.sendTab.sendModes.link),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: -1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: HugeIcon(icon: HugeIcons.strokeRoundedHelpCircle, color: Theme.of(context).iconTheme.color),
              ),
              const SizedBox(width: 10),
              Text(t.sendTab.sendModeHelp),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedMoreHorizontalCircle02,
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
      ),
    );
  }
}

/// An advanced list tile which shows the progress of the file transfer.
class _MultiSendDeviceListTile extends StatelessWidget {
  final Device device;
  final bool isFavorite;
  final String? nameOverride;
  final SendTabVm vm;

  const _MultiSendDeviceListTile({
    required this.device,
    required this.isFavorite,
    required this.nameOverride,
    required this.vm,
  });

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final session = ref.watch(sendProvider).values.firstWhereOrNull((s) => s.target.ip == device.ip);
    final double? progress;
    if (session != null) {
      final files = session.files.values.where((f) => f.token != null);
      final progressNotifier = ref.watch(progressProvider);
      final currBytes = files.fold<int>(
        0,
        (prev, curr) => prev + ((progressNotifier.getProgress(sessionId: session.sessionId, fileId: curr.file.id) * curr.file.size).round()),
      );
      final totalBytes = files.fold<int>(0, (prev, curr) => prev + curr.file.size);
      progress = totalBytes == 0 ? 0 : currBytes / totalBytes;
    } else {
      progress = null;
    }
    return DeviceListTile(
      device: device,
      info: session?.status.humanString,
      progress: progress,
      isFavorite: isFavorite,
      nameOverride: nameOverride,
      onFavoriteTap: device.ip == null ? null : () async => await vm.onToggleFavorite(context, device),
      onTap: () async => await vm.onTapDeviceMultiSend(context, device),
    );
  }
}

extension on SessionStatus {
  String? get humanString {
    switch (this) {
      case SessionStatus.waiting:
        return t.sendPage.waiting;
      case SessionStatus.recipientBusy:
        return t.sendPage.busy;
      case SessionStatus.declined:
        return t.sendPage.rejected;
      case SessionStatus.tooManyAttempts:
        return t.sendPage.tooManyAttempts;
      case SessionStatus.sending:
        return null;
      case SessionStatus.finished:
        return t.general.finished;
      case SessionStatus.finishedWithErrors:
        return t.progressPage.total.title.finishedError;
      case SessionStatus.canceledBySender:
        return t.progressPage.total.title.canceledSender;
      case SessionStatus.canceledByReceiver:
        return t.progressPage.total.title.canceledReceiver;
    }
  }
}
