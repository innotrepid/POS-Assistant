import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mercate/core/database/app_database.dart';
import 'package:mercate/core/models/business_profile.dart';
import 'package:mercate/core/models/mercate_license.dart';
import 'package:mercate/services/business_profile_service.dart';
import 'package:mercate/services/license_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('valid signed token activates only its matching business and evaluates grace', () async {
    final database = AppDatabase.memory();
    addTearDown(database.close);
    final profiles = BusinessProfileService(database: database);
    await profiles.completeOnboarding(
      profileId: BusinessProfileId.mamaMboga,
      shopName: 'Signed Test Shop',
    );
    final businessId = await profiles.ensureBusinessId();

    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final payload = utf8.encode(jsonEncode({
      'schemaVersion': 1,
      'product': 'mercate',
      'businessId': businessId,
      'licenseId': 'test-license-1',
      'issuedAt': '2026-11-01T00:00:00Z',
      'expiresAt': '2026-11-08T00:00:00Z',
      'graceDays': 2,
      'maxDevices': 3,
    }));
    final signature = await algorithm.sign(payload, keyPair: keyPair);
    final token = '${base64Url.encode(payload).replaceAll('=', '')}.'
        '${base64Url.encode(signature.bytes).replaceAll('=', '')}';
    final verifier = LicenseService(
      database: database,
      profiles: profiles,
      publicKeyBase64: base64Url.encode(publicKey.bytes).replaceAll('=', ''),
    );

    await verifier.activate(token);
    final evaluation = await verifier.evaluate(now: DateTime.utc(2026, 11, 9));
    expect(evaluation.state, LicenseState.gracePeriod);
    expect(evaluation.license?.maxDevices, 3);
    expect(evaluation.permitsLicensedOperation, isTrue);

    final rollback = await verifier.evaluate(now: DateTime.utc(2026, 11, 8));
    expect(rollback.state, LicenseState.clockRollback);
  });

  test('signed token for another business is rejected', () async {
    final database = AppDatabase.memory();
    addTearDown(database.close);
    final profiles = BusinessProfileService(database: database);
    await profiles.completeOnboarding(
      profileId: BusinessProfileId.mamaMboga,
      shopName: 'Local Shop',
    );

    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final payload = utf8.encode(jsonEncode({
      'schemaVersion': 1,
      'product': 'mercate',
      'businessId': 'not-this-business',
      'licenseId': 'wrong-business',
      'issuedAt': '2026-11-01T00:00:00Z',
      'expiresAt': '2026-11-08T00:00:00Z',
      'graceDays': 0,
      'maxDevices': null,
    }));
    final signature = await algorithm.sign(payload, keyPair: keyPair);
    final token = '${base64Url.encode(payload).replaceAll('=', '')}.'
        '${base64Url.encode(signature.bytes).replaceAll('=', '')}';
    final verifier = LicenseService(
      database: database,
      profiles: profiles,
      publicKeyBase64: base64Url.encode(publicKey.bytes).replaceAll('=', ''),
    );

    await expectLater(verifier.activate(token), throwsStateError);
    expect(await verifier.storedToken(), isNull);
  });

  test('tampered signed token is rejected and never stored', () async {
    final database = AppDatabase.memory();
    addTearDown(database.close);
    final profiles = BusinessProfileService(database: database);
    await profiles.completeOnboarding(
      profileId: BusinessProfileId.mamaMboga,
      shopName: 'Tamper Test Shop',
    );
    final businessId = await profiles.ensureBusinessId();

    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final payload = utf8.encode(jsonEncode({
      'schemaVersion': 1,
      'product': 'mercate',
      'businessId': businessId,
      'licenseId': 'tampered-license',
      'issuedAt': '2026-11-01T00:00:00Z',
      'expiresAt': '2026-12-01T00:00:00Z',
      'graceDays': 0,
    }));
    final signature = await algorithm.sign(payload, keyPair: keyPair);
    final alteredSignature = signature.bytes.toList();
    alteredSignature[0] ^= 0x01;
    final token = '${base64Url.encode(payload).replaceAll('=', '')}.'
        '${base64Url.encode(alteredSignature).replaceAll('=', '')}';
    final verifier = LicenseService(
      database: database,
      profiles: profiles,
      publicKeyBase64: base64Url.encode(publicKey.bytes).replaceAll('=', ''),
    );

    await expectLater(
      verifier.activate(token),
      throwsA(isA<LicenseVerificationException>()),
    );
    expect(await verifier.storedToken(), isNull);
  });

  test('token timestamps without an explicit timezone are rejected', () async {
    final database = AppDatabase.memory();
    addTearDown(database.close);
    final profiles = BusinessProfileService(database: database);
    await profiles.completeOnboarding(
      profileId: BusinessProfileId.mamaMboga,
      shopName: 'Timestamp Test Shop',
    );
    final businessId = await profiles.ensureBusinessId();

    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final payload = utf8.encode(jsonEncode({
      'schemaVersion': 1,
      'product': 'mercate',
      'businessId': businessId,
      'licenseId': 'timezone-license',
      'issuedAt': '2026-11-01T00:00:00',
      'expiresAt': '2026-12-01T00:00:00Z',
      'graceDays': 0,
    }));
    final signature = await algorithm.sign(payload, keyPair: keyPair);
    final token = '${base64Url.encode(payload).replaceAll('=', '')}.'
        '${base64Url.encode(signature.bytes).replaceAll('=', '')}';
    final verifier = LicenseService(
      database: database,
      profiles: profiles,
      publicKeyBase64: base64Url.encode(publicKey.bytes).replaceAll('=', ''),
    );

    await expectLater(
      verifier.activate(token),
      throwsA(isA<LicenseVerificationException>()),
    );
    expect(await verifier.storedToken(), isNull);
  });

}
