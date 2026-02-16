import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

final _logger = Logger('AndroidMulticastLock');

const MethodChannel _channel = MethodChannel('org.localsend.localsend_app/localsend');

/// Service to manage Android MulticastLock for UDP multicast discovery.
///
/// Android requires acquiring a MulticastLock to receive multicast packets.
/// Without this lock, the OS filters out multicast traffic to save battery.
class AndroidMulticastLockService {
  static bool _isAcquired = false;

  /// Acquires the multicast lock.
  /// Returns true if successfully acquired, false otherwise.
  static Future<bool> acquire() async {
    if (!defaultTargetPlatform.supportsMulticastLock) {
      return true; // Not Android, no lock needed
    }

    if (_isAcquired) {
      return true; // Already acquired
    }

    try {
      final result = await _channel.invokeMethod<bool>('acquireMulticastLock');
      _isAcquired = result ?? false;
      if (_isAcquired) {
        _logger.info('MulticastLock acquired successfully');
      } else {
        _logger.warning('Failed to acquire MulticastLock');
      }
      return _isAcquired;
    } catch (e) {
      _logger.warning('Error acquiring MulticastLock: $e');
      return false;
    }
  }

  /// Releases the multicast lock.
  static Future<void> release() async {
    if (!defaultTargetPlatform.supportsMulticastLock) {
      return; // Not Android, no lock needed
    }

    if (!_isAcquired) {
      return; // Not acquired
    }

    try {
      await _channel.invokeMethod('releaseMulticastLock');
      _isAcquired = false;
      _logger.info('MulticastLock released');
    } catch (e) {
      _logger.warning('Error releasing MulticastLock: $e');
    }
  }

  /// Checks if location permission is granted (required for WiFi scanning on Android 10+).
  static Future<bool> checkLocationPermission() async {
    if (!defaultTargetPlatform.supportsMulticastLock) {
      return true; // Not Android
    }

    try {
      final result = await _channel.invokeMethod<bool>('checkLocationPermission');
      return result ?? false;
    } catch (e) {
      _logger.warning('Error checking location permission: $e');
      return false;
    }
  }

  /// Returns true if the lock is currently acquired.
  static bool get isAcquired => _isAcquired;
}

extension on TargetPlatform {
  bool get supportsMulticastLock {
    return this == TargetPlatform.android;
  }
}
