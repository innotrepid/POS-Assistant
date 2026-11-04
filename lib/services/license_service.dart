import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:sqflite/sqflite.dart';

import '../core/database/app_database.dart';
import '../core/models/mercate_license.dart';
import 'business_profile_service.dart';

const _licenseTokenKey = 'license_signed_token';
const _lastTrustedTimeKey = 'license_last_trusted_utc';

/// Offline licence storage and Ed25519 verification. Only the public key
/// belongs in Mercate; the private signing key stays in the Key Manager.
class LicenseService {
  LicenseService({
    AppDatabase? database,
    BusinessProfileService? profiles,
    String? publicKeyBase64,
  })  : _database = database ?? AppDatabase.instance,
        _profiles = profiles ?? BusinessProfileService.instance,
        _publicKeyBase64 = publicKeyBase64 ??
            const String.fromEnvironment('MERCATE_LICENSE_PUBLIC_KEY');

  final AppDatabase _database;
  final BusinessProfileService _profiles;
  final String _publicKeyBase64;
  final Ed25519 _ed25519 = Ed25519();

  static final LicenseService instance = LicenseService();

  Future<MercateLicense> activate(String token) async {
    final businessId = await _profiles.ensureBusinessId();
    final license = await _verifyToken(token);
    if (license.businessId != businessId) {
      throw StateError('This licence belongs to a different business.');
    }
    final meta = await _database.metaDatabase;
    await meta.insert(
      'settings',
      {'key': _licenseTokenKey, 'value': token.trim()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return license;
  }

  Future<void> clearStoredLicense() async {
    final meta = await _database.metaDatabase;
    await meta.delete('settings', where: 'key = ?', whereArgs: [_licenseTokenKey]);
  }

  Future<String?> storedToken() async {
    final meta = await _database.metaDatabase;
    final rows = await meta.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_licenseTokenKey],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<LicenseEvaluation> evaluate({DateTime? now}) async {
    final token = await storedToken();
    if (token == null || token.trim().isEmpty) {
      return const LicenseEvaluation(
        state: LicenseState.unactivated,
        message: 'This business has not been activated.',
      );
    }

    late final MercateLicense license;
    try {
      license = await _verifyToken(token);
    } catch (error) {
      return LicenseEvaluation(state: LicenseState.invalid, message: error.toString());
    }

    final businessId = await _profiles.ensureBusinessId();
    if (license.businessId != businessId) {
      return const LicenseEvaluation(
        state: LicenseState.invalid,
        message: 'This licence belongs to a different business.',
      );
    }

    final current = (now ?? DateTime.now()).toUtc();
    final meta = await _database.metaDatabase;
    final rows = await meta.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_lastTrustedTimeKey],
      limit: 1,
    );
    final lastRaw = rows.isEmpty ? null : rows.first['value'] as String?;
    final lastTrusted = lastRaw == null ? null : DateTime.tryParse(lastRaw);

    if (lastTrusted != null &&
        current.isBefore(lastTrusted.toUtc().subtract(const Duration(minutes: 5)))) {
      return LicenseEvaluation(
        state: LicenseState.clockRollback,
        license: license,
        message: 'The device clock appears to have moved backwards.',
      );
    }

    if (lastTrusted == null || current.isAfter(lastTrusted.toUtc())) {
      await meta.insert(
        'settings',
        {'key': _lastTrustedTimeKey, 'value': current.toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    if (!current.isAfter(license.expiresAt)) {
      return LicenseEvaluation(state: LicenseState.active, license: license);
    }
    final graceEnds = license.expiresAt.add(Duration(days: license.graceDays));
    if (license.graceDays > 0 && !current.isAfter(graceEnds)) {
      return LicenseEvaluation(state: LicenseState.gracePeriod, license: license);
    }
    return LicenseEvaluation(state: LicenseState.expired, license: license);
  }

  Future<MercateLicense> _verifyToken(String token) async {
    if (_publicKeyBase64.isEmpty) {
      throw StateError('Licence verification key is not configured in this build.');
    }
    final parts = token.trim().split('.');
    if (parts.length != 2) throw const FormatException('Malformed licence token.');

    final payloadBytes = _decodeBase64Url(parts[0]);
    final signatureBytes = _decodeBase64Url(parts[1]);
    final publicKeyBytes = _decodeBase64Url(_publicKeyBase64);
    if (publicKeyBytes.length != 32 || signatureBytes.length != 64) {
      throw const FormatException('Invalid Ed25519 key or signature length.');
    }

    final publicKey = SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519);
    final signature = Signature(signatureBytes, publicKey: publicKey);
    final valid = await _ed25519.verify(payloadBytes, signature: signature);
    if (!valid) throw const FormatException('Licence signature is invalid.');
    return MercateLicense.decodePayload(payloadBytes);
  }

  List<int> _decodeBase64Url(String value) =>
      base64Url.decode(base64Url.normalize(value));
}
