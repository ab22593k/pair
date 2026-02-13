import 'package:collection/collection.dart';
import 'package:common/util/network_interfaces.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:local_hero/local_hero.dart';
import 'package:localsend_app/features/settings/provider/settings_provider.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/widget/custom_basic_appbar.dart';
import 'package:localsend_app/widget/dialogs/text_field_tv.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:moform/moform.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:rhizu/rhizu.dart';

class NetworkInterfacesPage extends StatefulWidget {
  const NetworkInterfacesPage();

  @override
  State<NetworkInterfacesPage> createState() => _NetworkInterfacesPageState();
}

class _NetworkInterfacesPageState extends State<NetworkInterfacesPage> {
  List<(String, List<String>)> rawInterfaces = [];

  @override
  void initState() {
    super.initState();

    // ignore: discarded_futures
    getNetworkInterfaces(whitelist: null, blacklist: null).then((value) {
      if (mounted) {
        setState(() {
          rawInterfaces = value.map((e) => (e.name, e.addresses.map((a) => a.address).toList())).toList();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch(settingsProvider);
    final currList = settings.networkWhitelist ?? settings.networkBlacklist ?? [];
    final Future<void> Function(List<String>?) updateFunction = settings.networkWhitelist != null
        ? context.notifier(settingsProvider).setNetworkWhitelist
        : context.notifier(settingsProvider).setNetworkBlacklist;

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: basicLocalSendAppbar(t.networkInterfacesPage.title),
      body: LocalHeroScope(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: ResponsiveListView(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
          children: [
            Text(
              t.networkInterfacesPage.info,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                t.networkInterfacesPage.preview,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: ScrollConfiguration(
                behavior: const MaterialScrollBehavior().copyWith(
                  dragDevices: {
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.touch,
                    PointerDeviceKind.stylus,
                    PointerDeviceKind.trackpad,
                    PointerDeviceKind.unknown,
                  },
                ),
                child: SingleChildScrollView(
                  physics: SmoothScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: rawInterfaces.mapIndexed((i, e) {
                      final ignored = isNetworkIgnoredRaw(
                        networkWhitelist: settings.networkWhitelist,
                        networkBlacklist: settings.networkBlacklist,
                        interface: e.$2,
                      );

                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Card(
                          elevation: 0,
                          color: ignored ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5) : colorScheme.surfaceContainer,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: ignored ? Colors.transparent : colorScheme.outlineVariant,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: ignored ? colorScheme.secondaryContainer.withValues(alpha: 0.5) : colorScheme.secondaryContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '#${i + 1}',
                                        style: textTheme.labelSmall?.copyWith(
                                          color: colorScheme.onSecondaryContainer,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      e.$1,
                                      style: textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        decoration: ignored ? TextDecoration.lineThrough : null,
                                        color: ignored ? colorScheme.onSurface.withValues(alpha: 0.5) : colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...e.$2.map(
                                  (ip) => Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      ip,
                                      style: textTheme.bodySmall?.copyWith(
                                        fontFamily: 'RobotoMono',
                                        decoration: ignored ? TextDecoration.lineThrough : null,
                                        color: ignored ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5) : colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: SegmentedButton<int>(
                segments: [
                  ButtonSegment(
                    value: 0,
                    label: Text(t.networkInterfacesPage.whitelist),
                    icon: const HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01, size: 18, color: null),
                  ),
                  ButtonSegment(
                    value: 1,
                    label: Text(t.networkInterfacesPage.blacklist),
                    icon: const HugeIcon(icon: HugeIcons.strokeRoundedCancel01, size: 18, color: null),
                  ),
                ],
                selected: {
                  if (settings.networkWhitelist != null) 0 else if (settings.networkBlacklist != null) 1 else -1,
                },
                onSelectionChanged: (newSelection) async {
                  final selection = newSelection.first;
                  if (selection == 0) {
                    // Switch to Whitelist
                    await context.notifier(settingsProvider).setNetworkWhitelist(switch (currList) {
                      [] => [''],
                      _ => [...currList],
                    });
                    if (context.mounted) {
                      await context.notifier(settingsProvider).setNetworkBlacklist(null);
                    }
                  } else {
                    // Switch to Blacklist
                    await context.notifier(settingsProvider).setNetworkBlacklist(switch (currList) {
                      [] => [''],
                      _ => [...currList],
                    });
                    if (context.mounted) {
                      await context.notifier(settingsProvider).setNetworkWhitelist(null);
                    }
                  }
                },
                emptySelectionAllowed: true, // Allow turning both off
              ),
            ),
            const SizedBox(height: 24),
            if (settings.networkWhitelist != null || settings.networkBlacklist != null) ...[
              ...currList.mapIndexed((i, e) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: StringField(
                    value: e,
                    onChanged: (value) async {
                      await updateFunction([
                        ...currList.sublist(0, i),
                        value,
                        ...currList.sublist(i + 1),
                      ]);
                    },
                    builder: (context, controller) {
                      return TextFieldTv(
                        name: t.networkInterfacesPage.whitelist,
                        controller: controller,
                        onDelete: () async {
                          if (currList.length == 1) {
                            await updateFunction(null);
                            return;
                          }
                          await updateFunction([
                            ...currList.sublist(0, i),
                            ...currList.sublist(i + 1),
                          ]);
                        },
                      );
                    },
                  ),
                );
              }),
              LocalHero(
                tag: 'network_interfaces_bottom',
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${t.general.example}:',
                                  style: textTheme.labelMedium?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text('123.123.123.123', style: textTheme.bodySmall?.copyWith(fontFamily: 'RobotoMono')),
                                Text('123.123.123.*', style: textTheme.bodySmall?.copyWith(fontFamily: 'RobotoMono')),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () async {
                              await updateFunction([
                                ...currList,
                                '',
                              ]);
                            },
                            icon: const HugeIcon(icon: HugeIcons.strokeRoundedAdd01, size: 18, color: null),
                            label: Text(t.general.add),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
