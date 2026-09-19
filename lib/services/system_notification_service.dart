import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Android system tray notifications for important alerts.
class SystemNotificationService {
  SystemNotificationService._();
  static final SystemNotificationService instance =
      SystemNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();
      const settings = InitializationSettings(android: android, iOS: ios);

      await _plugin.initialize(settings);

      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      try {
        await androidPlugin?.requestNotificationsPermission();
      } catch (_) {}

      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'pos_inventory',
          'Inventory',
          description: 'Low and out-of-stock alerts',
          importance: Importance.high,
        ),
      );
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'pos_debt',
          'Debt',
          description: 'Customer debt and overdue alerts',
          importance: Importance.high,
        ),
      );
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'pos_business',
          'Business',
          description: 'General business alerts',
          importance: Importance.defaultImportance,
        ),
      );

      _ready = true;
    } catch (_) {
      _ready = false;
    }
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

      final channelId = switch (category) {
        'inventory' => 'pos_inventory',
        'debt' => 'pos_debt',
        _ => 'pos_business',
      };
      final channelName = switch (category) {
        'inventory' => 'Inventory',
        'debt' => 'Debt',
        _ => 'Business',
      };

      final importance = priority == 'critical' || priority == 'warning'
          ? Importance.high
          : Importance.defaultImportance;

      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'POS Assistant alerts',
        importance: importance,
        priority: priority == 'critical'
            ? Priority.high
            : Priority.defaultPriority,
      );

      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(android: androidDetails),
      );
    } catch (_) {}
  }
}
