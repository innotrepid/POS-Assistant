import 'package:flutter/foundation.dart';

/// System tray notifications (optional). Primary alerts stay in-app.
/// flutter_local_notifications was removed to avoid desugar build issues;
/// this facade keeps the same call sites working offline.
class SystemNotificationService {
  SystemNotificationService._();
  static final SystemNotificationService instance =
      SystemNotificationService._();

  bool _ready = false;

  Future<void> init() async {
    _ready = true;
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String category,
    String priority = 'info',
  }) async {
    try {
      await init();
      if (!_ready) return;
      debugPrint('Mercate [$category/$priority] $title — $body (id=$id)');
    } catch (_) {}
  }
}
