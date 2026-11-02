import 'package:flutter/foundation.dart';
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
  bool get permissionGranted => _permissionGranted;

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

        const high = Importance.high;
        await androidPlugin?.createNotificationChannel(
          const AndroidNotificationChannel(
            'mercate_inventory',
            'Inventory',
            description: 'Low and out-of-stock alerts',
            importance: high,
            playSound: true,
            enableVibration: true,
          ),
        );
        await androidPlugin?.createNotificationChannel(
          const AndroidNotificationChannel(
            'mercate_debt',
            'Debt (deni)',
            description: 'Customer debt, overdue, and promise alerts',
            importance: high,
            playSound: true,
            enableVibration: true,
          ),
        );
        await androidPlugin?.createNotificationChannel(
          const AndroidNotificationChannel(
            'mercate_business',
            'Business',
            description: 'Day close and general business alerts',
            importance: high,
            playSound: true,
            enableVibration: true,
          ),
        );

        _initialized = true;
      }

      if (requestPermission) {
        await requestOsPermission();
      } else {
        await _refreshPermissionFlag();
      }

      return isReady;
    } catch (e) {
      debugPrint('SystemNotification init: $e');
      return false;
    }
  }

  Future<void> _refreshPermissionFlag() async {
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final enabled = await androidPlugin.areNotificationsEnabled();
        _permissionGranted = enabled == true;
        return;
      }
      _permissionGranted = true;
    } catch (_) {}
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
        final after = await androidPlugin.areNotificationsEnabled();
        _permissionGranted = granted == true || after == true;
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
    } catch (e) {
      debugPrint('requestOsPermission: $e');
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
      if (!_initialized) return;

      await _refreshPermissionFlag();
      if (!_permissionGranted) {
        await requestOsPermission();
        if (!_permissionGranted) {
          debugPrint('SystemNotification skipped (no OS permission): $title');
          return;
        }
      }

      final channelId = switch (category) {
        'inventory' => 'mercate_inventory',
        'debt' => 'mercate_debt',
        'promise' => 'mercate_debt',
        'day' => 'mercate_business',
        _ => 'mercate_business',
      };
      final channelName = switch (category) {
        'inventory' => 'Inventory',
        'debt' || 'promise' => 'Debt (deni)',
        _ => 'Business',
      };

      final isUrgent = priority == 'critical' ||
          priority == 'warning' ||
          category == 'debt' ||
          category == 'promise' ||
          category == 'day';

      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'Mercate alerts',
        importance: isUrgent ? Importance.high : Importance.defaultImportance,
        priority: isUrgent ? Priority.high : Priority.defaultPriority,
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
      );

      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint('SystemNotification show: $e');
    }
  }
}
