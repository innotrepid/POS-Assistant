import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mercate/core/database/app_database.dart';
import 'package:mercate/core/models/business_profile.dart';
import 'package:mercate/core/models/mercate_license.dart';
import 'package:mercate/services/business_profile_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('legacy onboarded business receives one stable ID without data loss', () async {
    final database = AppDatabase.memory();
    addTearDown(database.close);
    final meta = await database.metaDatabase;
    await meta.insert('settings', {'key': 'onboarding_done', 'value': '1'});
    await meta.insert('settings', {'key': 'business_profile', 'value': 'mamaMboga'});
    await meta.insert('settings', {'key': 'business_name', 'value': 'Amina Shop'});
    final businessDb = await database.database;
    await businessDb.insert('customers', {
      'id': 'existing-customer-1',
      'name': 'Existing customer',
      'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
      'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
    });

    final profiles = BusinessProfileService(database: database);
    final first = await profiles.ensureBusinessId();
    final second = await profiles.ensureBusinessId();

    expect(first, isNotEmpty);
    expect(first, second);
    final customers = await businessDb.query('customers');
    expect(customers, hasLength(1));
    expect(customers.single['id'], 'existing-customer-1');
    expect(await profiles.getBusinessName(), 'Amina Shop');
  });

  test('new onboarding creates identity that survives ordinary settings changes', () async {
    final database = AppDatabase.memory();
    addTearDown(database.close);
    final profiles = BusinessProfileService(database: database);

    await profiles.completeOnboarding(
      profileId: BusinessProfileId.mamaMboga,
      shopName: 'Test Shop',
    );
    final originalId = await profiles.ensureBusinessId();

    await profiles.setBusinessName('Test Shop Updated');
    expect(await profiles.ensureBusinessId(), originalId);
  });

  test('licence claims accept custom device and grace policies', () {
    final license = MercateLicense.fromJson({
      'schemaVersion': 1,
      'product': 'mercate',
      'businessId': 'business-uuid',
      'licenseId': 'license-001',
      'issuedAt': '2026-11-01T00:00:00Z',
      'expiresAt': '2026-11-08T00:00:00Z',
      'graceDays': 2,
      'maxDevices': 4,
    });

    expect(license.businessId, 'business-uuid');
    expect(license.graceDays, 2);
    expect(license.maxDevices, 4);
  });

  test('licence claims reject unsupported product and invalid device limits', () {
    expect(
      () => MercateLicense.fromJson({
        'schemaVersion': 1,
        'product': 'other-app',
        'businessId': 'business-uuid',
        'licenseId': 'license-001',
        'issuedAt': '2026-11-01T00:00:00Z',
        'expiresAt': '2026-11-08T00:00:00Z',
        'graceDays': 0,
        'maxDevices': 0,
      }),
      throwsFormatException,
    );
  });
}
