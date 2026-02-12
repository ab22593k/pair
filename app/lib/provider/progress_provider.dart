import 'dart:async';

import 'package:refena_flutter/refena_flutter.dart';

/// Minimum time between progress notifications to throttle UI updates.
const _progressThrottleMs = 100; // ~10 FPS for progress updates

/// A provider holding the progress of the send process.
/// It is implemented as [ChangeNotifier] for performance reasons.
///
/// Features:
/// - Throttled progress updates to reduce UI rebuilds
/// - Batched notifications for high-frequency updates
final progressProvider = ChangeNotifierProvider((ref) => ProgressNotifier());

class ProgressNotifier extends ChangeNotifier {
  final _progressMap = <String, Map<String, double>>{}; // session id -> (file id -> 0..1)
  Timer? _throttleTimer;
  bool _pendingNotification = false;

  /// Set progress with throttling to avoid excessive UI rebuilds.
  /// Progress updates are batched and notified at most every 100ms.
  void setProgress({required String sessionId, required String fileId, required double progress}) {
    Map<String, double>? progressMap = _progressMap[sessionId];
    if (progressMap == null) {
      progressMap = {};
      _progressMap[sessionId] = progressMap;
    }
    progressMap[fileId] = progress;

    // Throttle notifications to reduce UI rebuilds
    if (_throttleTimer?.isActive != true) {
      _pendingNotification = false;
      notifyListeners();
      _throttleTimer = Timer(const Duration(milliseconds: _progressThrottleMs), () {
        if (_pendingNotification) {
          _pendingNotification = false;
          notifyListeners();
        }
      });
    } else {
      _pendingNotification = true;
    }
  }

  /// Set progress immediately without throttling.
  /// Use sparingly for critical updates that need immediate UI feedback.
  void setProgressImmediate({required String sessionId, required String fileId, required double progress}) {
    Map<String, double>? progressMap = _progressMap[sessionId];
    if (progressMap == null) {
      progressMap = {};
      _progressMap[sessionId] = progressMap;
    }
    progressMap[fileId] = progress;
    _pendingNotification = false;
    notifyListeners();
  }

  double getProgress({required String sessionId, required String fileId}) {
    return _progressMap[sessionId]?[fileId] ?? 0.0;
  }

  void removeSession(String sessionId) {
    _progressMap.remove(sessionId);
    notifyListeners();
  }

  void removeAllSessions() {
    _progressMap.clear();
    notifyListeners();
  }

  /// Only for debug purposes
  Map<String, Map<String, double>> getData() {
    return _progressMap;
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    super.dispose();
  }
}
