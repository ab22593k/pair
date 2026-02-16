import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:common/api_route_builder.dart';
import 'package:common/constants.dart';
import 'package:common/isolate.dart';
import 'package:common/model/device.dart';
import 'package:common/model/dto/multicast_dto.dart';
import 'package:common/model/dto/register_dto.dart';
import 'package:common/src/isolate/child/http_provider.dart';
import 'package:common/util/network_interfaces.dart';
import 'package:common/util/sleep.dart';
import 'package:logging/logging.dart';
import 'package:refena/refena.dart';

final _logger = Logger('Multicast');

final multicastDiscoveryProvider = Provider((ref) {
  return MulticastService(ref);
});

class MulticastService {
  MulticastService(this._ref);

  final Ref _ref;
  Completer<void> _cancelCompleter = Completer();
  bool _listening = false;

  /// Binds the UDP port and listen to UDP multicast packages
  /// It will automatically answer announcement messages
  Stream<Device> startListener() async* {
    if (_listening) {
      _logger.info('Already listening to multicast');
      return;
    }

    _listening = true;

    try {
      while (true) {
        final streamController = StreamController<Device>();

        // Use a local variable to capture the latest sync state
        // We will also listen to changes to trigger a restart
        var syncState = _ref.read(syncProvider);

        // Listen for sync state changes to restart the listener if needed
        // (e.g. if the port, multicast group or network whitelist/blacklist changes)
        final syncSubscription = _ref.stream(syncProvider).listen((event) {
          final next = event.next;
          if (next.port != syncState.port ||
              next.multicastGroup != syncState.multicastGroup ||
              !const ListEquality().equals(next.networkWhitelist, syncState.networkWhitelist) ||
              !const ListEquality().equals(next.networkBlacklist, syncState.networkBlacklist)) {
            _logger.info('Restarting multicast listener due to sync state change');
            restartListener();
          } else {
            // Just update the local sync state for serverRunning/alias changes
            syncState = next;
          }
        });

        _logger.info('Start multicast listener...');
        final List<_SocketResult> sockets;
        try {
          sockets = await _getSockets(
            whitelist: syncState.networkWhitelist,
            blacklist: syncState.networkBlacklist,
            multicastGroup: syncState.multicastGroup,
            port: syncState.port,
          );
        } catch (e) {
          _logger.severe('Failed to get sockets for multicast', e);
          await syncSubscription.cancel();
          break;
        }

        if (sockets.isEmpty) {
          _logger.warning('No network interfaces available for multicast');
        }

        for (final socket in sockets) {
          socket.socket.listen(
            (_) {
              final datagram = socket.socket.receive();
              if (datagram == null) {
                return;
              }

              try {
                final dto = MulticastDto.fromJson(jsonDecode(utf8.decode(datagram.data)));
                if (dto.fingerprint == syncState.securityContext.certificateHash) {
                  return;
                }

                final ip = datagram.address.address;
                final peer = dto.toDevice(ip, syncState.port, syncState.protocol == ProtocolType.https);
                streamController.add(peer);

                // We always use the LATEST syncState here
                final currentSyncState = _ref.read(syncProvider);
                if ((dto.announcement == true || dto.announce == true) && currentSyncState.serverRunning) {
                  // only respond when server is running
                  // ignore: discarded_futures
                  _answerAnnouncement(peer);
                }
              } catch (e) {
                _logger.warning('Could not parse multicast message', e);
              }
            },
            onError: (e) {
              _logger.severe('UDP socket error on interface ${socket.interface.name}', e);
            },
          );
          _logger.info(
            'Bind UDP multicast port (ip: ${socket.interface.addresses.map((a) => a.address).toList()}, group: ${syncState.multicastGroup}, port: ${syncState.port})',
          );
        }

        // Tell everyone in the network that I am online
        sendAnnouncement(); // ignore: unawaited_futures

        _cancelCompleter = Completer();

        // ignore: unawaited_futures
        _cancelCompleter.future.then((_) {
          // ignore: discarded_futures
          streamController.close();
          for (final socket in sockets) {
            socket.socket.close();
          }
        });

        yield* streamController.stream;

        await syncSubscription.cancel();
        _logger.info('Multicast listener stopped or restarted');
        // streamController is closed because of cancel
        // wait for resources to be released (it works without on macOS, but who knows)
        await sleepAsync(500);
      }
    } finally {
      _listening = false;
    }
  }

  void restartListener() {
    _cancelCompleter.complete();
  }

  /// Sends an announcement which triggers a response on every LocalSend member of the network.
  Future<void> sendAnnouncement() async {
    final syncState = _ref.read(syncProvider);
    final sockets = await _getSockets(
      whitelist: syncState.networkWhitelist,
      blacklist: syncState.networkBlacklist,
      multicastGroup: syncState.multicastGroup,
    );
    final dto = _getMulticastDto(announcement: true);

    for (final wait in [100, 500, 2000]) {
      await sleepAsync(wait);

      _logger.info('Announce via UDP');
      for (final socket in sockets) {
        try {
          socket.socket.send(dto, InternetAddress(syncState.multicastGroup), syncState.port);
        } catch (e) {
          _logger.warning('Could not send multicast message on interface ${socket.interface.name}', e);
        }
      }
    }

    // Close sockets after all announcements are sent
    for (final socket in sockets) {
      socket.socket.close();
    }
  }

  /// Responds to an announcement.
  Future<void> _answerAnnouncement(Device peer) async {
    try {
      // Answer with TCP
      await _ref.read(httpProvider).discovery.post(
            uri: ApiRoute.register.target(peer),
            json: _getRegisterDto().toJson(),
          );
      _logger.info('Respond to announcement of ${peer.alias} (${peer.ip}, model: ${peer.deviceModel}) via TCP');
    } catch (e) {
      // Fallback: Answer with UDP
      final syncState = _ref.read(syncProvider);
      final sockets = await _getSockets(
        whitelist: syncState.networkWhitelist,
        blacklist: syncState.networkBlacklist,
        multicastGroup: syncState.multicastGroup,
      );
      final dto = _getMulticastDto(announcement: false);
      for (final socket in sockets) {
        try {
          socket.socket.send(dto, InternetAddress(syncState.multicastGroup), syncState.port);
        } catch (e) {
          _logger.warning('Could not send multicast message on interface ${socket.interface.name}', e);
        } finally {
          socket.socket.close();
        }
      }
      _logger.info('Respond to announcement of ${peer.alias} (${peer.ip}, model: ${peer.deviceModel}) with UDP because TCP failed');
    }
  }

  /// Returns the MulticastDto of this device in bytes.
  List<int> _getMulticastDto({required bool announcement}) {
    final syncState = _ref.read(syncProvider);
    final dto = MulticastDto(
      alias: syncState.alias,
      version: protocolVersion,
      deviceModel: syncState.deviceInfo.deviceModel,
      deviceType: syncState.deviceInfo.deviceType,
      fingerprint: syncState.securityContext.certificateHash,
      port: syncState.port,
      protocol: syncState.protocol,
      download: syncState.download,
      announcement: announcement,
      announce: announcement,
    );
    return utf8.encode(jsonEncode(dto.toJson()));
  }

  RegisterDto _getRegisterDto() {
    final syncState = _ref.read(syncProvider);
    return RegisterDto(
      alias: syncState.alias,
      version: protocolVersion,
      deviceModel: syncState.deviceInfo.deviceModel,
      deviceType: syncState.deviceInfo.deviceType,
      fingerprint: syncState.securityContext.certificateHash,
      port: syncState.port,
      protocol: syncState.protocol,
      download: syncState.download,
    );
  }
}

class _SocketResult {
  final NetworkInterface interface;
  final RawDatagramSocket socket;

  _SocketResult(this.interface, this.socket);
}

Future<List<_SocketResult>> _getSockets({
  required List<String>? whitelist,
  required List<String>? blacklist,
  required String multicastGroup,
  int? port,
}) async {
  final interfaces = await getNetworkInterfaces(
    whitelist: whitelist,
    blacklist: blacklist,
  );
  final sockets = <_SocketResult>[];

  // 1. Create a dedicated receiver socket bound to 0.0.0.0 (anyIPv4)
  // On Android, this is REQUIRED to receive multicast packets.
  // We only do this if a port is provided (i.e., we are in "listen" mode).
  if (port != null) {
    try {
      final receiverSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port, reuseAddress: true);
      receiverSocket.multicastLoopback = false;

      for (final interface in interfaces) {
        try {
          receiverSocket.joinMulticast(InternetAddress(multicastGroup), interface);
        } catch (e) {
          _logger.warning('Could not join multicast group $multicastGroup on ${interface.name}', e);
        }
      }

      // We associate the receiver socket with the first interface (it doesn't matter much for receiving)
      if (interfaces.isNotEmpty) {
        sockets.add(_SocketResult(interfaces.first, receiverSocket));
      }
    } catch (e) {
      _logger.severe('Could not bind UDP receiver socket on port $port', e);
    }
  }

  // 2. Create dedicated sender sockets for each interface
  // Binding to specific interface IPs is the most reliable way to SEND multicast
  // packets through a specific interface on Android and Linux.
  for (final interface in interfaces) {
    try {
      final ip = interface.addresses.firstWhereOrNull((a) => a.type == InternetAddressType.IPv4)?.address;
      if (ip == null) {
        continue;
      }

      // Bind to a random port (0) for sending
      // If we are NOT listening (port == null), we use this for the announcement
      final senderSocket = await RawDatagramSocket.bind(ip, 0, reuseAddress: true);
      senderSocket.multicastLoopback = false;

      // association for sending
      sockets.add(_SocketResult(interface, senderSocket));
    } catch (e) {
      _logger.warning('Could not bind UDP sender socket on ${interface.name}', e);
    }
  }

  return sockets;
}
