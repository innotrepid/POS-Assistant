import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../core/database/app_database.dart';
import 'business_profile_service.dart';

class BackupEntry {
  final String id;
  final String folderPath;
  final DateTime createdAt;
  final String profileId;
  final int schemaVersion;
  final List<String> files;

  const BackupEntry({
    required this.id,
    required this.folderPath,
    required this.createdAt,
    required this.profileId,
    required this.schemaVersion,
    required this.files,
  });

  String get label {
    final d = createdAt;
    final dd =
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final tt =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '$dd $tt · $profileId';
  }

  String get zipFileName => 'mercate_backup_$id.zip';
}

class BackupResult {
  final BackupEntry entry;
  final String message;
  const BackupResult({required this.entry, required this.message});
}

/// Local SQLite backups with zip export, system share (USB/Drive), and Downloads.
class BackupService {
  BackupService({
    AppDatabase? database,
    BusinessProfileService? profiles,
    this.keepCount = 14,
  })  : _database = database ?? AppDatabase.instance,
        _profiles = profiles ?? BusinessProfileService.instance;

  final AppDatabase _database;
  final BusinessProfileService _profiles;
  final int keepCount;

  static const _prefsKeyLastBackup = 'last_local_backup_day';

  Future<Directory> _rootDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'mercate_backups'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> get backupFolderPath async => (await _rootDir()).path;

  Future<List<String>> _dbFileNames() async {
    final databasesPath = await getDatabasesPath();
    final dir = Directory(databasesPath);
    if (!await dir.exists()) return [];
    final names = <String>[];
    await for (final entity in dir.list()) {
      if (entity is File) {
        final name = p.basename(entity.path);
        if (name == 'mercate_meta.db' ||
            (name.startsWith('mercate_') && name.endsWith('.db'))) {
          names.add(name);
        }
      }
    }
    names.sort();
    return names;
  }

  Future<BackupResult> backupNow({String reason = 'manual'}) async {
    final now = DateTime.now();
    final stamp =
        '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final root = await _rootDir();
    final dest = Directory(p.join(root.path, stamp));
    await dest.create(recursive: true);

    final profileId = _database.activeProfileId;
    final databasesPath = await getDatabasesPath();

    await _database.close();

    final copied = <String>[];
    try {
      final names = await _dbFileNames();
      final safeProfile =
          profileId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      final candidates = {
        ...names,
        'mercate_meta.db',
        'mercate_$safeProfile.db',
      };
      for (final name in candidates) {
        final src = File(p.join(databasesPath, name));
        if (!await src.exists()) continue;
        final out = p.join(dest.path, name);
        await src.copy(out);
        copied.add(name);
      }

      final manifest = {
        'id': stamp,
        'createdAt': now.toIso8601String(),
        'profileId': profileId,
        'schemaVersion': AppDatabase.schemaVersion,
        'reason': reason,
        'files': copied,
      };
      await File(p.join(dest.path, 'manifest.json')).writeAsString(
        const JsonEncoder.withIndent('  ').convert(manifest),
      );
    } finally {
      try {
        await _database.useProfile(profileId);
      } catch (e) {
        debugPrint('Backup reopen: $e');
      }
    }

    if (copied.isEmpty) {
      try {
        await dest.delete(recursive: true);
      } catch (_) {}
      throw StateError('No database files found to back up yet.');
    }

    await _markBackupDay(now);
    await _pruneOldBackups();

    final entry = BackupEntry(
      id: stamp,
      folderPath: dest.path,
      createdAt: now,
      profileId: profileId,
      schemaVersion: AppDatabase.schemaVersion,
      files: copied,
    );
    return BackupResult(
      entry: entry,
      message: 'Saved ${copied.length} file(s) · ${entry.label}',
    );
  }

  Future<List<BackupEntry>> listBackups() async {
    final root = await _rootDir();
    final entries = <BackupEntry>[];
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final manifestFile = File(p.join(entity.path, 'manifest.json'));
      if (await manifestFile.exists()) {
        try {
          final map = jsonDecode(await manifestFile.readAsString())
              as Map<String, dynamic>;
          entries.add(
            BackupEntry(
              id: map['id'] as String? ?? p.basename(entity.path),
              folderPath: entity.path,
              createdAt:
                  DateTime.tryParse(map['createdAt'] as String? ?? '') ??
                      DateTime.fromMillisecondsSinceEpoch(0),
              profileId: map['profileId'] as String? ?? '',
              schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 0,
              files: (map['files'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  const [],
            ),
          );
          continue;
        } catch (_) {}
      }
      final id = p.basename(entity.path);
      entries.add(
        BackupEntry(
          id: id,
          folderPath: entity.path,
          createdAt: DateTime.tryParse(id.split('_').first) ??
              DateTime.fromMillisecondsSinceEpoch(0),
          profileId: '',
          schemaVersion: 0,
          files: const [],
        ),
      );
    }
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  /// Zip a backup folder to a temp file (for share / Downloads).
  Future<File> zipBackup(BackupEntry entry) async {
    final dir = Directory(entry.folderPath);
    if (!await dir.exists()) {
      throw StateError('Backup folder missing.');
    }
    final tmp = await getTemporaryDirectory();
    final zipPath = p.join(tmp.path, entry.zipFileName);
    final zipFile = File(zipPath);
    if (await zipFile.exists()) {
      await zipFile.delete();
    }

    final encoder = ZipFileEncoder();
    encoder.create(zipPath);
    await for (final entity in dir.list(recursive: false)) {
      if (entity is File) {
        encoder.addFile(entity);
      }
    }
    encoder.close();
    return File(zipPath);
  }

  /// System share sheet — Drive, Bluetooth, USB OTG, Files, WhatsApp, etc.
  Future<void> shareBackup(BackupEntry entry) async {
    final zip = await zipBackup(entry);
    await Share.shareXFiles(
      [XFile(zip.path, mimeType: 'application/zip', name: entry.zipFileName)],
      subject: 'Mercate backup ${entry.label}',
      text: 'Mercate shop backup · ${entry.label}',
    );
  }

  /// Copy zip into public Downloads when possible; falls back to app folder.
  Future<String> exportToDownloads(BackupEntry entry) async {
    final zip = await zipBackup(entry);
    final destDir = await _resolveDownloadsDir();
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }
    final destPath = p.join(destDir.path, entry.zipFileName);
    final dest = await zip.copy(destPath);
    return dest.path;
  }

  Future<Directory> _resolveDownloadsDir() async {
    try {
      final d = await getDownloadsDirectory();
      if (d != null) return d;
    } catch (_) {}

    final publicDownload = Directory('/storage/emulated/0/Download');
    if (await publicDownload.exists()) {
      try {
        final probe =
            File(p.join(publicDownload.path, '.mercate_write_test'));
        await probe.writeAsString('ok');
        await probe.delete();
        return publicDownload;
      } catch (_) {}
    }

    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        final dir = Directory(p.join(ext.path, 'Downloads'));
        if (!await dir.exists()) await dir.create(recursive: true);
        return dir;
      }
    } catch (_) {}

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'exports'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> restore(BackupEntry entry) async {
    final databasesPath = await getDatabasesPath();
    final profileId = _database.activeProfileId;

    await _database.close();

    try {
      final dir = Directory(entry.folderPath);
      if (!await dir.exists()) {
        throw StateError('Backup folder missing.');
      }
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (!name.endsWith('.db')) continue;
        final dest = File(p.join(databasesPath, name));
        if (await dest.exists()) {
          await dest.delete();
        }
        await entity.copy(dest.path);
      }
    } finally {
      try {
        await _database.useProfile(profileId);
      } catch (_) {
        try {
          final id = entry.profileId.isNotEmpty ? entry.profileId : 'duka';
          await _database.useProfile(id);
        } catch (e) {
          debugPrint('Restore reopen: $e');
        }
      }
    }
  }

  Future<void> deleteBackup(BackupEntry entry) async {
    final dir = Directory(entry.folderPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<void> _pruneOldBackups() async {
    final list = await listBackups();
    if (list.length <= keepCount) return;
    for (final old in list.skip(keepCount)) {
      try {
        await deleteBackup(old);
      } catch (_) {}
    }
  }

  Future<void> _markBackupDay(DateTime day) async {
    final meta = await _database.metaDatabase;
    final value =
        '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    await meta.insert(
      'settings',
      {'key': _prefsKeyLastBackup, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> lastBackupDay() async {
    try {
      final meta = await _database.metaDatabase;
      final rows = await meta.query(
        'settings',
        where: 'key = ?',
        whereArgs: [_prefsKeyLastBackup],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return rows.first['value'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<bool> needsDailyBackup() async {
    final last = await lastBackupDay();
    if (last == null) return true;
    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return last != today;
  }

  Future<BackupResult?> runDailyIfNeeded() async {
    try {
      if (!await needsDailyBackup()) return null;
      return await backupNow(reason: 'daily');
    } catch (e) {
      debugPrint('Daily backup skipped: $e');
      return null;
    }
  }
}
