import '../core/database/app_database.dart';
import '../core/models/business_profile.dart';

const String kSettingBusinessProfile = 'business_profile';
const String kSettingBusinessName = 'business_name';

class BusinessProfileService {
  BusinessProfileService({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<BusinessProfile> getProfile() async {
    final raw = await _get(kSettingBusinessProfile);
    return BusinessProfile.tryParse(raw) ??
        BusinessProfile.byId(BusinessProfileId.duka);
  }

  Future<void> setProfile(BusinessProfileId id) async {
    final profile = BusinessProfile.byId(id);
    if (!profile.enabled) {
      throw StateError('${profile.label} is not available yet.');
    }
    await _set(kSettingBusinessProfile, id.name);
  }

  Future<String> getBusinessName() async {
    final name = await _get(kSettingBusinessName);
    if (name == null || name.trim().isEmpty) return 'My shop';
    return name.trim();
  }

  Future<void> setBusinessName(String name) async {
    await _set(kSettingBusinessName, name.trim());
  }

  Future<String?> _get(String key) async {
    final db = await _database.database;
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> _set(String key, String value) async {
    final db = await _database.database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

// Re-export for callers that need ConflictAlgorithm without importing sqflite
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
