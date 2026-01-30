import 'package:common/model/device.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

extension DeviceTypeExt on DeviceType {
  Widget icon(BuildContext context) {
    return switch (this) {
      DeviceType.mobile => HugeIcon(icon: HugeIcons.strokeRoundedSmartPhone01, color: Theme.of(context).iconTheme.color),
      DeviceType.desktop => HugeIcon(icon: HugeIcons.strokeRoundedComputer, color: Theme.of(context).iconTheme.color),
      DeviceType.web => HugeIcon(icon: HugeIcons.strokeRoundedGlobe, color: Theme.of(context).iconTheme.color),
      DeviceType.headless => HugeIcon(icon: HugeIcons.strokeRoundedCode, color: Theme.of(context).iconTheme.color),
      DeviceType.server => HugeIcon(icon: HugeIcons.strokeRoundedServerStack01, color: Theme.of(context).iconTheme.color),
    };
  }
}
