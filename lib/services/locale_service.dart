import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../core/database/app_database.dart';
import '../core/l10n/app_strings.dart';

/// App language preference — stored in shared meta DB (not per-shop).
class LocaleService {
  LocaleService({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  static const _key = 'ui_language';

  /// 'en' or 'sw'
  Future<String> getLanguageCode() async {
    final raw = await _get(_key);
    if (raw == 'sw' || raw == 'sw_KE') return 'sw';
    return 'en';
  }

  Future<void> setLanguageCode(String code) async {
    final value = code.startsWith('sw') ? 'sw' : 'en';
    await _set(_key, value);
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

class LocaleController extends ChangeNotifier {
  LocaleController({LocaleService? service})
      : _service = service ?? LocaleService();

  final LocaleService _service;
  String _code = 'en';
  bool _ready = false;

  String get code => _code;
  bool get ready => _ready;
  bool get isSwahili => _code == 'sw';
  Locale get locale => _code == 'sw' ? const Locale('sw') : const Locale('en');
  AppStrings get s => AppStrings(_code);

  Future<void> load() async {
    try {
      _code = await _service.getLanguageCode();
    } catch (_) {
      _code = 'en';
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> setLanguageCode(String code) async {
    _code = code.startsWith('sw') ? 'sw' : 'en';
    notifyListeners();
    try {
      await _service.setLanguageCode(_code);
    } catch (_) {}
  }
}
