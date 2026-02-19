import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/features/receive/pages/receive_history_page.dart';
import 'package:localsend_app/features/receive/receive_tab_vm.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/util/ip_helper.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/widget/animations/initial_fade_transition.dart';
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
        ResponsiveListView(
          padding: const EdgeInsets.symmetric(horizontal: _ExpressiveSpacing.lg),
          children: [
            const SizedBox(height: _ExpressiveSpacing.xxl),
            _BeaconIdentity(vm: vm),
            const SizedBox(height: _ExpressiveSpacing.lg),
            _QuickSaveSection(vm: vm),
            const SizedBox(height: _ExpressiveSpacing.xxl),
          ],
        ),
        if (checkPlatform([TargetPlatform.macOS])) SizedBox(height: 50, child: MoveWindow()),
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
    final colorScheme = Theme.of(context).colorScheme;
    final isOnline = vm.serverState != null;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Background expressive pulses
            ...List.generate(3, (index) {
              return Container(
                    width: 140 + (index * 40.0),
                    height: 140 + (index * 40.0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.1 - (index * 0.03)),
                        width: 2,
                      ),
                    ),
                  )
                  .animate(onPlay: (controller) => controller.repeat())
                  .scale(
                    duration: Duration(milliseconds: 2000 + (index * 500)),
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.2, 1.2),
                    curve: Curves.easeInOutCubic,
                  )
                  .fadeOut();
            }),
            // Expressive loading indicator
            InitialFadeTransition(
              duration: const Duration(milliseconds: 800),
              delay: const Duration(milliseconds: 200),
              child: const MorphingLI.extraLarge(
                containment: Containment.contained,
              ),
            ),
          ],
        ),
        // "Discoverable as" label for clarity
        InitialFadeTransition(
          duration: const Duration(milliseconds: 600),
          delay: const Duration(milliseconds: 400),
          child: Text(
            t.receiveTab.infoBox.alias.replaceAll(':', '').toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.primary.withValues(alpha: 0.7),
              fontWeight: FontWeight.w900,
              letterSpacing: 3.0,
            ),
          ),
        ),
        const SizedBox(height: _ExpressiveSpacing.xs),
        // Device alias with expressive typography
        InitialFadeTransition(
          duration: const Duration(milliseconds: 600),
          delay: const Duration(milliseconds: 500),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              vm.serverState?.alias ?? vm.aliasSettings,
              style: GoogleFonts.plusJakartaSans(
                textStyle: Theme.of(context).textTheme.displayMedium,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.5,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ),
        const SizedBox(height: _ExpressiveSpacing.sm),
        // Status/IP with secondary typography
        InitialFadeTransition(
          duration: const Duration(milliseconds: 600),
          delay: const Duration(milliseconds: 700),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: _ExpressiveSpacing.md, vertical: _ExpressiveSpacing.xs),
            decoration: BoxDecoration(
              color: isOnline ? colorScheme.primaryContainer.withValues(alpha: 0.3) : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: ShapeTokens.borderRadiusLarge,
            ),
            child: Text(
              isOnline ? vm.localIps.map((ip) => '#${ip.visualId}').toSet().join(' ') : t.general.offline,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: isOnline ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedSettings01,
                      color: colorScheme.onPrimaryContainer,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: _ExpressiveSpacing.md),
                  Text(
                    t.general.quickSave,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
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
                child: IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.all(12),
                  ),
                  onPressed: () async {
                    await context.push(() => const ReceiveHistoryPage());
                  },
                  icon: HugeIcon(icon: HugeIcons.strokeRoundedClock01, color: Theme.of(context).iconTheme.color, size: 24),
                ),
              ),
            const SizedBox(width: _ExpressiveSpacing.sm),
            IconButton.filledTonal(
              key: const ValueKey('info-btn'),
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.all(12),
              ),
              onPressed: toggleAdvanced,
              icon: HugeIcon(icon: HugeIcons.strokeRoundedInformationCircle, color: Theme.of(context).iconTheme.color, size: 24),
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
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(_ExpressiveSpacing.lg),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedInformationCircle,
                        color: colorScheme.onPrimaryContainer,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: _ExpressiveSpacing.md),
                    Text(
                      t.receiveTab.infoBox.alias.replaceAll(':', ''),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.5,
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
        Container(
          width: 80,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
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
