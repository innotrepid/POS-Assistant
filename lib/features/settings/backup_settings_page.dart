import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/backup_service.dart';

/// Everyday local backups + share / export to Downloads or USB (via share sheet).
class BackupSettingsPage extends StatefulWidget {
  const BackupSettingsPage({super.key});

  @override
  State<BackupSettingsPage> createState() => _BackupSettingsPageState();
}

class _BackupSettingsPageState extends State<BackupSettingsPage> {
  final _backup = BackupService();
  List<BackupEntry> _entries = [];
  String? _folderPath;
  String? _friendlyPath;
  bool _isPublic = false;
  String? _lastDay;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await _backup.listBackups();
      final path = await _backup.backupFolderPath;
      final friendly = await _backup.backupFolderFriendlyPath;
      final last = await _backup.lastBackupDay();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _folderPath = path;
        _friendlyPath = friendly;
        _isPublic = _backup.isLikelyPublicPath(path);
        _lastDay = last;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _backupNow() async {
    await _run(() async {
      final result = await _backup.backupNow(reason: 'manual');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      await _load();
    });
  }

  Future<void> _share(BackupEntry entry) async {
    await _run(() async {
      await _backup.shareBackup(entry);
    });
  }

  Future<void> _exportDownloads(BackupEntry entry) async {
    await _run(() async {
      final path = await _backup.exportToDownloads(entry);
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: path));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved to Downloads (path copied):\n$path'),
        ),
      );
    });
  }

  Future<void> _restore(BackupEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: Text(
          'This replaces current shop data with:\n${entry.label}\n\n'
          'Close and reopen Mercate after restore if anything looks odd.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      await _backup.restore(entry);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restore finished')),
      );
    });
  }

  Future<void> _delete(BackupEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete backup?'),
        content: Text(entry.label),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      await _backup.deleteBackup(entry);
      await _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Backup')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Text(
                  'Daily backups keep a copy of your shop databases. '
                  'Mercate tries to save under Documents → Mercate → backups '
                  'so you can open them in the Files app or copy to USB.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  color: scheme.primaryContainer.withValues(alpha: 0.35),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _lastDay == null
                              ? 'No automatic backup day recorded yet'
                              : 'Last backup day: $_lastDay',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (_folderPath != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _isPublic
                                ? 'Saved under phone Documents (easy to find):'
                                : 'Backup folder (may be under app storage — use Share or Downloads):',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _friendlyPath ?? _folderPath!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (_friendlyPath != null &&
                              _friendlyPath != _folderPath) ...[
                            const SizedBox(height: 4),
                            Text(
                              _folderPath!,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                          TextButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: _folderPath!),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Folder path copied'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 18),
                            label: const Text('Copy folder path'),
                          ),
                        ],
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _busy ? null : _backupNow,
                          icon: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.backup_outlined),
                          label: Text(_busy ? 'Working…' : 'Backup now'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: scheme.error),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Recent backups',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Share works with USB OTG, Drive, Bluetooth, and Files. '
                  'Downloads → Files app → Download folder.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                if (_entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No backups yet. Tap Backup now.'),
                  )
                else
                  ...[
                    for (final e in _entries)
                      Card(
                        child: ExpansionTile(
                          leading: const Icon(Icons.folder_zip_outlined),
                          title: Text(e.label),
                          subtitle: Text(
                            '${e.files.length} files · schema ${e.schemaVersion}',
                          ),
                          children: [
                            ListTile(
                              title: const Text('Share (USB / Drive / Bluetooth)'),
                              leading: const Icon(Icons.share_outlined),
                              onTap: _busy ? null : () => _share(e),
                            ),
                            ListTile(
                              title: const Text('Save to Downloads'),
                              leading: const Icon(Icons.download_outlined),
                              onTap:
                                  _busy ? null : () => _exportDownloads(e),
                            ),
                            ListTile(
                              title: const Text('Restore'),
                              leading: const Icon(Icons.restore),
                              onTap: _busy ? null : () => _restore(e),
                            ),
                            ListTile(
                              title: const Text('Delete'),
                              leading: Icon(Icons.delete_outline,
                                  color: scheme.error),
                              onTap: _busy ? null : () => _delete(e),
                            ),
                            OverflowBar(
                              children: [
                                TextButton.icon(
                                  onPressed: _busy ? null : () => _share(e),
                                  icon: const Icon(Icons.share, size: 18),
                                  label: const Text('Share'),
                                ),
                                TextButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => _exportDownloads(e),
                                  icon: const Icon(Icons.download, size: 18),
                                  label: const Text('Downloads'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
              ],
            ),
    );
  }
}
