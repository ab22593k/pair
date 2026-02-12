import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/pages/receive_history_page.dart';
import 'package:localsend_app/pages/tabs/receive_tab_vm.dart';
import 'package:localsend_app/util/ip_helper.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/widget/animations/initial_fade_transition.dart';
import 'package:localsend_app/widget/column_list_view.dart';
import 'package:localsend_app/widget/custom_icon_button.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:rhizu/rhizu.dart';
import 'package:routerino/routerino.dart';

/// Expressive spacing tokens for consistent layout
class _ExpressiveSpacing {
  static const double xs = 4;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

enum _QuickSaveMode {
  off,
  favorites,
  on,
}

class ReceiveTab extends StatelessWidget {
  const ReceiveTab();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch(receiveTabVmProvider);

    return Stack(
      children: [
        checkPlatform([TargetPlatform.macOS]) ? SizedBox(height: 50, child: MoveWindow()) : const SizedBox.shrink(),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: ResponsiveListView.defaultMaxWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _ExpressiveSpacing.lg),
              child: ColumnListView(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: _ExpressiveSpacing.xxl),
                  Expanded(
                    child: _BeaconIdentity(vm: vm),
                  ),
                  const SizedBox(height: _ExpressiveSpacing.lg),
                  _QuickSaveSection(vm: vm),
                  const SizedBox(height: _ExpressiveSpacing.xl),
                ],
              ),
            ),
          ),
        ),
        _InfoBox(vm),
        _CornerButtons(
          showAdvanced: vm.showAdvanced,
          showHistoryButton: vm.showHistoryButton,
          toggleAdvanced: vm.toggleAdvanced,
        ),
      ],
    );
  }
}

class _BeaconIdentity extends StatelessWidget {
  final ReceiveTabVm vm;

  const _BeaconIdentity({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Expressive loading indicator with large contained style
        InitialFadeTransition(
          duration: const Duration(milliseconds: 600),
          delay: const Duration(milliseconds: 200),
          child: const MorphingLI.extraLarge(
            containment: Containment.contained,
          ),
        ),
        const SizedBox(height: _ExpressiveSpacing.xl),
        // "Discoverable as" label for clarity
        InitialFadeTransition(
          duration: const Duration(milliseconds: 600),
          delay: const Duration(milliseconds: 300),
          child: Text(
            t.receiveTab.infoBox.alias.replaceAll(':', ''),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: _ExpressiveSpacing.xs),
        // Device alias with expressive typography
        InitialFadeTransition(
          duration: const Duration(milliseconds: 600),
          delay: const Duration(milliseconds: 400),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              vm.serverState?.alias ?? vm.aliasSettings,
              style: GoogleFonts.plusJakartaSans(
                textStyle: Theme.of(context).textTheme.displaySmall,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.0,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
        const SizedBox(height: _ExpressiveSpacing.sm),
        // Status/IP with secondary typography
        InitialFadeTransition(
          duration: const Duration(milliseconds: 600),
          delay: const Duration(milliseconds: 600),
          child: Text(
            vm.serverState == null ? t.general.offline : vm.localIps.map((ip) => '#${ip.visualId}').toSet().join(' '),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _QuickSaveSection extends StatelessWidget {
  final ReceiveTabVm vm;

  const _QuickSaveSection({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        shape: const RoundedRectangleBorder(
          borderRadius: ShapeTokens.borderRadiusExtraLarge,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _ExpressiveSpacing.lg,
            vertical: _ExpressiveSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedSettings01,
                    color: Theme.of(context).colorScheme.primary,
                    size: 16,
                  ),
                  const SizedBox(width: _ExpressiveSpacing.sm),
                  Text(
                    t.general.quickSave,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: _ExpressiveSpacing.md),
              SegmentedButton<_QuickSaveMode>(
                multiSelectionEnabled: false,
                emptySelectionAllowed: false,
                showSelectedIcon: false,
                onSelectionChanged: (selection) async {
                  if (selection.contains(_QuickSaveMode.off)) {
                    await vm.onSetQuickSave(context, false);
                    if (context.mounted) {
                      await vm.onSetQuickSaveFromFavorites(context, false);
                    }
                  } else if (selection.contains(_QuickSaveMode.favorites)) {
                    await vm.onSetQuickSave(context, false);
                    if (context.mounted) {
                      await vm.onSetQuickSaveFromFavorites(context, true);
                    }
                  } else if (selection.contains(_QuickSaveMode.on)) {
                    await vm.onSetQuickSaveFromFavorites(context, false);
                    if (context.mounted) {
                      await vm.onSetQuickSave(context, true);
                    }
                  }
                },
                selected: {
                  if (!vm.quickSaveSettings && !vm.quickSaveFromFavoritesSettings) _QuickSaveMode.off,
                  if (vm.quickSaveFromFavoritesSettings) _QuickSaveMode.favorites,
                  if (vm.quickSaveSettings) _QuickSaveMode.on,
                },
                segments: [
                  ButtonSegment(
                    value: _QuickSaveMode.off,
                    label: Text(t.receiveTab.quickSave.off),
                  ),
                  ButtonSegment(
                    value: _QuickSaveMode.favorites,
                    label: Text(t.receiveTab.quickSave.favorites),
                  ),
                  ButtonSegment(
                    value: _QuickSaveMode.on,
                    label: Text(t.receiveTab.quickSave.on),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CornerButtons extends StatelessWidget {
  final bool showAdvanced;
  final bool showHistoryButton;
  final Future<void> Function() toggleAdvanced;

  const _CornerButtons({
    required this.showAdvanced,
    required this.showHistoryButton,
    required this.toggleAdvanced,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (!showAdvanced)
              AnimatedOpacity(
                opacity: showHistoryButton ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: CustomIconButton(
                  onPressed: () async {
                    await context.push(() => const ReceiveHistoryPage());
                  },
                  child: HugeIcon(icon: HugeIcons.strokeRoundedClock01, color: Theme.of(context).iconTheme.color),
                ),
              ),
            CustomIconButton(
              key: const ValueKey('info-btn'),
              onPressed: toggleAdvanced,
              child: HugeIcon(icon: HugeIcons.strokeRoundedInformationCircle, color: Theme.of(context).iconTheme.color),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final ReceiveTabVm vm;

  const _InfoBox(this.vm);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedCrossFade(
      crossFadeState: vm.showAdvanced ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 250),
      firstChild: Container(),
      secondChild: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(_ExpressiveSpacing.lg),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: ExpressiveRadius.large,
            ),
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(_ExpressiveSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with icon
                  Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedInformationCircle,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: _ExpressiveSpacing.sm),
                      Text(
                        t.receiveTab.infoBox.alias.replaceAll(':', ''),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: _ExpressiveSpacing.md),
                  Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: _ExpressiveSpacing.md),
                  // Info rows with expressive layout
                  _InfoRow(
                    label: t.receiveTab.infoBox.alias,
                    value: vm.serverState?.alias ?? '-',
                  ),
                  const SizedBox(height: _ExpressiveSpacing.sm),
                  _InfoRow(
                    label: t.receiveTab.infoBox.ip,
                    value: vm.localIps.isEmpty ? t.general.unknown : vm.localIps.join('\n'),
                    isMultiline: vm.localIps.length > 1,
                  ),
                  const SizedBox(height: _ExpressiveSpacing.sm),
                  _InfoRow(
                    label: t.receiveTab.infoBox.port,
                    value: vm.serverState?.port.toString() ?? '-',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Individual info row with expressive styling
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isMultiline;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isMultiline = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        // Label with primary color for visual hierarchy
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: _ExpressiveSpacing.md),
        // Value with secondary styling
        Expanded(
          child: isMultiline
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: value.split('\n').map((line) {
                    return SelectableText(
                      line,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    );
                  }).toList(),
                )
              : SelectableText(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
        ),
      ],
    );
  }
}
