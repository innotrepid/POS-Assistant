import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../core/database/app_database.dart';
import '../core/models/business_profile.dart';

const String kSettingBusinessProfile = 'business_profile';
const String kSettingBusinessName = 'business_name';
const String kSettingOnboardingDone = 'onboarding_done';

/// Global profile + shop settings live in the shared meta DB.
/// Business data lives in a per-profile database (isolated).
class BusinessProfileService extends ChangeNotifier {
  BusinessProfileService({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  static final BusinessProfileService instance = BusinessProfileService();

  Future<bool> hasCompletedOnboarding() async {
    final raw = await _getMeta(kSettingOnboardingDone);
    return raw == '1' || raw == 'true';
  }

  Future<void> completeOnboarding({
    required BusinessProfileId profileId,
    required String shopName,
  }) async {
    final profile = BusinessProfile.byId(profileId);
    if (!profile.enabled) {
      throw StateError('${profile.label} is not available yet.');
    }
    await _setMeta(kSettingBusinessProfile, profileId.name);
    await _setMeta(kSettingBusinessName, shopName.trim().isEmpty ? 'My shop' : shopName.trim());
    await _setMeta(kSettingOnboardingDone, '1');
    await AppDatabase.instance.useProfile(profileId.name);
    notifyListeners();
  }

  Future<BusinessProfile> getProfile() async {
    final raw = await _getMeta(kSettingBusinessProfile);
    return BusinessProfile.tryParse(raw) ??
        BusinessProfile.byId(BusinessProfileId.duka);
  }

  Future<String> getProfileId() async {
    final p = await getProfile();
    return p.id.name;
  }

  Future<void> setProfile(BusinessProfileId id) async {
    final profile = BusinessProfile.byId(id);
    if (!profile.enabled) {
      throw StateError('${profile.label} is not available yet.');
    }
    await _setMeta(kSettingBusinessProfile, id.name);
    await AppDatabase.instance.useProfile(id.name);
    notifyListeners();
  }

  Future<String> getBusinessName() async {
    final name = await _getMeta(kSettingBusinessName);
    if (name == null || name.trim().isEmpty) return 'My shop';
    return name.trim();
  }

  Future<void> setBusinessName(String name) async {
    await _setMeta(kSettingBusinessName, name.trim());
    notifyListeners();
  }

  Future<String?> _getMeta(String key) async {
    final db = await _database.metaDatabase;
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> _setMeta(String key, String value) async {
    final db = await _database.metaDatabase;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
