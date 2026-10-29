import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import 'package:sqflite/sqflite.dart';

import '../core/database/app_database.dart';

/// App lock: optional PIN + biometric. Stored in shared meta DB (all profiles).
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
  static const _kFailedAttempts = 'security_failed_attempts';
  static const _kLockoutUntil = 'security_lockout_until';

  static const maxFailedAttempts = 5;
  static const lockoutDuration = Duration(minutes: 2);

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

  /// Set or change PIN. If a PIN already exists, [currentPin] must match.
  Future<void> setPin(String pin, {String? currentPin}) async {
    final cleaned = pin.trim();
    if (cleaned.length < 4 || cleaned.length > 12) {
      throw ArgumentError('PIN must be 4–12 digits.');
    }
    if (!RegExp(r'^\d+$').hasMatch(cleaned)) {
      throw ArgumentError('PIN must contain digits only.');
    }
    if (await hasPin()) {
      if (currentPin == null || currentPin.trim().isEmpty) {
        throw ArgumentError('Enter your current PIN to change it.');
      }
      final ok = await verifyPin(currentPin, countFailures: false);
      if (!ok) {
        throw ArgumentError('Current PIN is incorrect.');
      }
    }
    await _set(_kPinHash, _hash(cleaned));
    await _clearFailures();
  }

  Future<void> clearPinAndLock({String? currentPin}) async {
    if (await hasPin()) {
      if (currentPin == null ||
          !(await verifyPin(currentPin, countFailures: false))) {
        throw ArgumentError('Current PIN is required to remove lock.');
      }
    }
    await _set(_kPinHash, '');
    await _set(_kLockEnabled, '0');
    await _clearFailures();
  }

  Future<int> lockoutSecondsRemaining() async {
    final untilRaw = await _get(_kLockoutUntil);
    if (untilRaw == null || untilRaw.isEmpty) return 0;
    final until = DateTime.tryParse(untilRaw);
    if (until == null) return 0;
    final left = until.difference(DateTime.now()).inSeconds;
    return left > 0 ? left : 0;
  }

  Future<bool> isLockedOut() async {
    return (await lockoutSecondsRemaining()) > 0;
  }

  Future<bool> verifyPin(
    String pin, {
    bool countFailures = true,
  }) async {
    if (await isLockedOut()) {
      final sec = await lockoutSecondsRemaining();
      throw StateError('Too many wrong attempts. Try again in ${sec}s.');
    }
    final stored = await _get(_kPinHash);
    if (stored == null || stored.isEmpty) return false;
    final ok = stored == _hash(pin.trim());
    if (ok) {
      await _clearFailures();
      return true;
    }
    if (countFailures) {
      await _registerFailure();
    }
    return false;
  }

  Future<void> _registerFailure() async {
    final raw = await _get(_kFailedAttempts);
    final n = (int.tryParse(raw ?? '0') ?? 0) + 1;
    await _set(_kFailedAttempts, '$n');
    if (n >= maxFailedAttempts) {
      final until = DateTime.now().add(lockoutDuration);
      await _set(_kLockoutUntil, until.toIso8601String());
      await _set(_kFailedAttempts, '0');
    }
  }

  Future<void> _clearFailures() async {
    await _set(_kFailedAttempts, '0');
    await _set(_kLockoutUntil, '');
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
    String reason = 'Unlock Mercate',
  }) async {
    try {
      if (!await canCheckBiometrics()) return false;
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> tryBiometricUnlock() async {
    if (!(await isLockEnabled())) return true;
    if (!(await isBiometricPreferred())) return false;
    if (!(await canCheckBiometrics())) return false;
    return authenticateBiometric();
  }

  Future<bool> unlockWithPin(String pin) async {
    if (!(await isLockEnabled())) return true;
    return verifyPin(pin);
  }

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
    final bytes = utf8.encode('mercate_v1|$pin');
    return sha256.convert(bytes).toString();
  }

  Future<String?> _get(String key) async {
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

  Future<void> _set(String key, String value) async {
    final db = await _database.metaDatabase;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
