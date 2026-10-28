import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Android/iOS system tray notifications for important alerts.
class SystemNotificationService {
  SystemNotificationService._();
  static final SystemNotificationService instance =
      SystemNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionGranted = false;

  bool get isReady => _initialized && _permissionGranted;

  Future<bool> init({bool requestPermission = true}) async {
    try {
      if (!_initialized) {
        const android = AndroidInitializationSettings('@mipmap/ic_launcher');
        const ios = DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );
        const settings = InitializationSettings(android: android, iOS: ios);

        await _plugin.initialize(settings);

        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

        await androidPlugin?.createNotificationChannel(
          const AndroidNotificationChannel(
            'mercate_inventory',
            'Inventory',
            description: 'Low and out-of-stock alerts',
            importance: Importance.high,
          ),
        );
        await androidPlugin?.createNotificationChannel(
          const AndroidNotificationChannel(
            'mercate_debt',
            'Debt (deni)',
            description: 'Customer debt and overdue alerts',
            importance: Importance.high,
          ),
        );
        await androidPlugin?.createNotificationChannel(
          const AndroidNotificationChannel(
            'mercate_business',
            'Business',
            description: 'General business alerts',
            importance: Importance.defaultImportance,
          ),
        );

        _initialized = true;
      }

      if (requestPermission) {
        await requestOsPermission();
      }

      return isReady;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestOsPermission() async {
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        final enabled = await androidPlugin.areNotificationsEnabled();
        if (enabled == true) {
          _permissionGranted = true;
          return true;
        }
        final granted = await androidPlugin.requestNotificationsPermission();
        _permissionGranted = granted == true;
        return _permissionGranted;
      }

      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        final granted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        _permissionGranted = granted == true;
        return _permissionGranted;
      }

      _permissionGranted = true;
      return true;
    } catch (_) {
      _permissionGranted = false;
      return false;
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
      await init(requestPermission: false);
      if (!_initialized || !_permissionGranted) return;

      final channelId = switch (category) {
        'inventory' => 'mercate_inventory',
        'debt' => 'mercate_debt',
        _ => 'mercate_business',
      };
      final channelName = switch (category) {
        'inventory' => 'Inventory',
        'debt' => 'Debt (deni)',
        _ => 'Business',
      };

      final importance = priority == 'critical' || priority == 'warning'
          ? Importance.high
          : Importance.defaultImportance;

      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'Mercate alerts',
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
