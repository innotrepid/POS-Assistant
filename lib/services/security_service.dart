import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import 'package:sqflite/sqflite.dart';

import '../core/database/app_database.dart';

/// App lock: optional PIN + biometric (fingerprint / face).
class SecurityService {
  SecurityService({
    AppDatabase? database,
    LocalAuthentication? localAuth,
  })  : _database = database ?? AppDatabase.instance,
        _localAuth = localAuth ?? LocalAuthentication();

  final AppDatabase _database;
  final LocalAuthentication _localAuth;

  static const _kPinHash = 'security_pin_hash';
  static const _kLockEnabled = 'security_lock_enabled';
  static const _kBiometricPreferred = 'security_biometric_preferred';

  Future<bool> isLockEnabled() async {
    return (await _get(_kLockEnabled)) == '1';
  }

  Future<bool> hasPin() async {
    final h = await _get(_kPinHash);
    return h != null && h.isNotEmpty;
  }

  Future<bool> isBiometricPreferred() async {
    return (await _get(_kBiometricPreferred)) != '0';
  }

  Future<void> setBiometricPreferred(bool value) async {
    await _set(_kBiometricPreferred, value ? '1' : '0');
  }

  Future<void> setLockEnabled(bool enabled) async {
    if (enabled && !(await hasPin())) {
      throw StateError('Set a PIN before enabling app lock.');
    }
    await _set(_kLockEnabled, enabled ? '1' : '0');
  }

  Future<void> setPin(String pin) async {
    final cleaned = pin.trim();
    if (cleaned.length < 4) {
      throw ArgumentError('PIN must be at least 4 digits.');
    }
    if (!RegExp(r'^\d+$').hasMatch(cleaned)) {
      throw ArgumentError('PIN must contain digits only.');
    }
    await _set(_kPinHash, _hash(cleaned));
  }

  Future<void> clearPinAndLock() async {
    await _set(_kPinHash, '');
    await _set(_kLockEnabled, '0');
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await _get(_kPinHash);
    if (stored == null || stored.isEmpty) return false;
    return stored == _hash(pin.trim());
  }

  Future<bool> canCheckBiometrics() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!supported) return false;
      final can = await _localAuth.canCheckBiometrics;
      if (!can) return false;
      final types = await _localAuth.getAvailableBiometrics();
      return types.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateBiometric({
    String reason = 'Unlock POS Assistant',
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// Unlock via biometric (if preferred & available) or returns false to use PIN UI.
  Future<bool> tryBiometricUnlock() async {
    if (!(await isLockEnabled())) return true;
    if (!(await isBiometricPreferred())) return false;
    if (!(await canCheckBiometrics())) return false;
    return authenticateBiometric();
  }

  /// Full unlock: biometric then PIN fallback handled by UI.
  Future<bool> unlockWithPin(String pin) async {
    if (!(await isLockEnabled())) return true;
    return verifyPin(pin);
  }

  /// Gate sensitive actions (day close, profile, future refunds).
  Future<bool> requireUnlock({
    required Future<bool> Function() promptPin,
    String biometricReason = 'Confirm it is you',
  }) async {
    if (!(await isLockEnabled())) return true;

    if (await isBiometricPreferred() && await canCheckBiometrics()) {
      final ok = await authenticateBiometric(reason: biometricReason);
      if (ok) return true;
    }
    return promptPin();
  }

  String _hash(String pin) {
    final bytes = utf8.encode('pos_assistant_v1|$pin');
    return sha256.convert(bytes).toString();
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
