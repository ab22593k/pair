import 'package:common/model/device.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:localsend_app/util/device_type_ext.dart';
import 'package:localsend_app/widget/custom_progress_bar.dart';
import 'package:localsend_app/widget/device_bage.dart';
import 'package:localsend_app/widget/list_tile/custom_list_tile.dart';

class DeviceListTile extends StatelessWidget {
  final Device device;
  final bool isFavorite;

  final String? nameOverride;

  final String? info;
  final double? progress;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;

  const DeviceListTile({
    required this.device,
    this.isFavorite = false,
    this.nameOverride,
    this.info,
    this.progress,
    this.onTap,
    this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    return CustomListTile(
      icon: device.deviceType.icon(context),
      title: Text(nameOverride ?? device.alias, style: const TextStyle(fontSize: 20)),
      trailing: onFavoriteTap != null
          ? IconButton(
              icon: isFavorite
                  ? HugeIcon(icon: HugeIcons.strokeRoundedFavourite, color: Theme.of(context).iconTheme.color)
                  : HugeIcon(icon: HugeIcons.strokeRoundedFavourite, color: Colors.grey),
              onPressed: onFavoriteTap,
            )
          : null,
      subTitle: Wrap(
        runSpacing: 8,
        spacing: 8,
        children: [
          if (info != null)
            Text(info!, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))
          else if (progress != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: CustomProgressBar(progress: progress!),
            )
          else ...[
            if (device.ip != null)
              DeviceBadge(
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                label: 'LAN • HTTP',
              )
            else
              DeviceBadge(
                backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                foregroundColor: Theme.of(context).colorScheme.onTertiaryContainer,
                label: 'WebRTC',
              ),
            if (device.deviceModel != null)
              DeviceBadge(
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                label: device.deviceModel!,
              ),
          ],
        ],
      ),
      onTap: onTap,
    );
  }
}
