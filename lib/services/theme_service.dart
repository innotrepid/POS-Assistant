import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../core/database/app_database.dart';

/// Persists appearance preference: system / light / dark.
class ThemeService {
  ThemeService({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  static const _key = 'ui_theme_mode';

  Future<ThemeMode> getThemeMode() async {
    final raw = await _get(_key);
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _set(_key, value);
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

/// App-wide theme notifier.
class ThemeController extends ChangeNotifier {
  ThemeController({ThemeService? service})
      : _service = service ?? ThemeService();

  final ThemeService _service;
  ThemeMode _mode = ThemeMode.system;
  bool _ready = false;

  ThemeMode get mode => _mode;
  bool get ready => _ready;

  Future<void> load() async {
    try {
      _mode = await _service.getThemeMode();
    } catch (_) {
      _mode = ThemeMode.system;
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    try {
      await _service.setThemeMode(mode);
    } catch (_) {}
  }
}
