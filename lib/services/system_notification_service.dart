import 'package:flutter/foundation.dart';

/// Lightweight system notification facade.
/// (Previously used flutter_local_notifications; kept offline-safe.)
class SystemNotificationService {
  SystemNotificationService._();
  static final SystemNotificationService instance = SystemNotificationService._();

  bool _ready = false;

  Future<void> init() async {
    _ready = true;
  }

  Future<void> show({
    required String title,
    required String body,
    int id = 0,
  }) async {
    if (!_ready) return;
    // In-app notifications are primary; system tray is optional.
    debugPrint('Mercate notify: $title — $body');
  }

  static const channelName = 'Mercate alerts';
  static const channelDescription = 'Mercate business alerts';
}
