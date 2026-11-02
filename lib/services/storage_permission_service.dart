import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Result of asking for broad storage access (Documents / USB-friendly paths).
class StorageAccessResult {
  final bool granted;
  final bool needsSettings;
  final String message;

  const StorageAccessResult({
    required this.granted,
    this.needsSettings = false,
    this.message = '',
  });
}

/// Android storage permission helper for public Documents backups.
class StoragePermissionService {
  /// True when manage-all-files or legacy storage is granted (Android).
  Future<bool> hasWideAccess() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      if (await Permission.manageExternalStorage.isGranted) return true;
      if (await Permission.storage.isGranted) return true;
    } catch (e) {
      debugPrint('hasWideAccess: $e');
    }
    return false;
  }

  /// Request storage / all-files access. May require opening system Settings.
  Future<StorageAccessResult> requestWideAccess() async {
    if (kIsWeb || !Platform.isAndroid) {
      return const StorageAccessResult(
        granted: true,
        message: 'Not required on this device',
      );
    }

    try {
      var storage = await Permission.storage.status;
      if (!storage.isGranted) {
        storage = await Permission.storage.request();
      }
      if (storage.isGranted) {
        return const StorageAccessResult(
          granted: true,
          message: 'Storage access granted',
        );
      }

      var manage = await Permission.manageExternalStorage.status;
      if (manage.isGranted) {
        return const StorageAccessResult(
          granted: true,
          message: 'All files access granted',
        );
      }
      manage = await Permission.manageExternalStorage.request();
      if (manage.isGranted) {
        return const StorageAccessResult(
          granted: true,
          message: 'All files access granted',
        );
      }

      if (manage.isPermanentlyDenied ||
          storage.isPermanentlyDenied ||
          manage.isDenied) {
        return const StorageAccessResult(
          granted: false,
          needsSettings: true,
          message:
              'Allow "All files access" or Storage in system settings so '
              'Mercate can save backups under Documents/Mercate.',
        );
      }

      return const StorageAccessResult(
        granted: false,
        needsSettings: true,
        message:
            'Storage permission was not granted. You can still use Share '
            'or Save to Downloads.',
      );
    } catch (e) {
      debugPrint('requestWideAccess: $e');
      return StorageAccessResult(
        granted: false,
        needsSettings: true,
        message: 'Could not request permission: $e',
      );
    }
  }

  Future<bool> openSystemSettings() => openAppSettings();
}
