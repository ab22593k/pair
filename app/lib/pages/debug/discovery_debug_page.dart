import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:localsend_app/provider/device_info_provider.dart';
import 'package:localsend_app/provider/local_ip_provider.dart';
import 'package:localsend_app/provider/logging/discovery_logs_provider.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/util/native/android_multicast_lock.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/widget/copyable_text.dart';
import 'package:localsend_app/widget/custom_basic_appbar.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _dateFormat = DateFormat.Hms();

class DiscoveryDebugPage extends StatefulWidget {
  const DiscoveryDebugPage({super.key});

  @override
  State<DiscoveryDebugPage> createState() => _DiscoveryDebugPageState();
}

class _DiscoveryDebugPageState extends State<DiscoveryDebugPage> {
  bool _multicastLockAcquired = false;
  bool _locationPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _checkAndroidStatus();
  }

  Future<void> _checkAndroidStatus() async {
    if (checkPlatform([TargetPlatform.android])) {
      final lockAcquired = AndroidMulticastLockService.isAcquired;
      final locationGranted = await AndroidMulticastLockService.checkLocationPermission();
      setState(() {
        _multicastLockAcquired = lockAcquired;
        _locationPermissionGranted = locationGranted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final logs = ref.watch(discoveryLoggerProvider);
    final serverState = ref.watch(serverProvider);
    final localIpState = ref.watch(localIpProvider);
    final deviceInfo = ref.watch(deviceInfoProvider);
    final nearbyDevices = ref.watch(nearbyDevicesProvider);

    return Scaffold(
      appBar: basicLocalSendAppbar('Discovery Debugging'),
      body: ResponsiveListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        children: [
          // Status Cards
          _StatusCard(
            title: 'Server Status',
            status: serverState != null ? 'Running (Port: ${serverState.port})' : 'Stopped',
            isGood: serverState != null,
          ),
          const SizedBox(height: 10),
          _StatusCard(
            title: 'Network Interfaces',
            status: localIpState.localIps.isEmpty ? 'No interfaces found' : localIpState.localIps.join(', '),
            isGood: localIpState.localIps.isNotEmpty,
          ),
          const SizedBox(height: 10),
          _StatusCard(
            title: 'Device Info',
            status: '${deviceInfo.deviceModel ?? "Unknown model"} (${deviceInfo.deviceType.name})',
            isGood: true,
          ),
          if (checkPlatform([TargetPlatform.android])) ...[
            const SizedBox(height: 10),
            _StatusCard(
              title: 'Multicast Lock',
              status: _multicastLockAcquired ? 'Acquired ✓' : 'Not Acquired ✗',
              isGood: _multicastLockAcquired,
            ),
            const SizedBox(height: 10),
            _StatusCard(
              title: 'Location Permission',
              status: _locationPermissionGranted ? 'Granted ✓' : 'Not Granted ✗',
              isGood: _locationPermissionGranted,
            ),
          ],
          const SizedBox(height: 10),
          _StatusCard(
            title: 'Nearby Devices',
            status: '${nearbyDevices.devices.length} device(s) found',
            isGood: nearbyDevices.devices.isNotEmpty,
          ),
          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              ElevatedButton(
                onPressed: () {
                  ref.redux(nearbyDevicesProvider).dispatch(StartMulticastScan());
                  _checkAndroidStatus(); // Refresh status
                },
                child: const Text('Announce'),
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: () {
                  ref.notifier(discoveryLoggerProvider).clear();
                  _checkAndroidStatus(); // Refresh status
                },
                child: const Text('Clear'),
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: _checkAndroidStatus,
                child: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Discovery Logs:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),

          // Logs
          if (logs.isEmpty)
            const Text('No logs yet. Tap "Announce" to send discovery packets.', style: TextStyle(color: Colors.grey))
          else
            ...logs.map(
              (log) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CopyableText(
                  prefix: TextSpan(
                    text: '[${_dateFormat.format(log.timestamp)}] ',
                    style: TextStyle(
                      color: log.log.contains('Error') || log.log.contains('Failed') ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  name: log.log,
                  value: log.log,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final String status;
  final bool isGood;

  const _StatusCard({
    required this.title,
    required this.status,
    required this.isGood,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isGood ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isGood ? Colors.green.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isGood ? Icons.check_circle : Icons.warning,
            color: isGood ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
