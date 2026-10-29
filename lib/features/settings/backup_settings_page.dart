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
      final last = await _backup.lastBackupDay();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _folderPath = path;
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
        SnackBar(
          content: Text('Backup saved (${result.entry.files.length} files)'),
        ),
      );
      await _load();
    });
  }

  Future<void> _share(BackupEntry entry) async {
    await _run(() async {
      await _backup.shareBackup(entry);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Share sheet opened — pick Drive, Bluetooth, USB, or Files',
          ),
        ),
      );
    });
  }

  Future<void> _exportDownloads(BackupEntry entry) async {
    await _run(() async {
      final path = await _backup.exportToDownloads(entry);
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: path));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved to Downloads (path copied):\n$path'),
          duration: const Duration(seconds: 5),
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
          'This replaces data on this phone with:\n\n${entry.label}\n\n'
          'Make a fresh backup first if you are unsure.',
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
        const SnackBar(
          content: Text('Restored. Restart the app if anything looks off.'),
        ),
      );
      await _load();
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
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
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
      appBar: AppBar(
        title: const Text('Data backup'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _busy ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Text(
                  'Everyday local backup',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Copies shop databases onto this phone daily. '
                  'Share a zip to Drive, Bluetooth, or a USB stick, '
                  'or save a copy under Downloads.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  color: scheme.primaryContainer.withOpacity(0.35),
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
                            'On-phone folder:\n$_folderPath',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
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
                  Text(_error!, style: TextStyle(color: scheme.error)),
                ],
                const SizedBox(height: 20),
                Text(
                  'Saved backups',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Share → pick USB / Drive / Bluetooth. '
                  'Downloads → Files app → Download folder.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                if (_entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No backups yet. Tap Backup now after you have used the shop.',
                    ),
                  )
                else
                  ..._entries.map((e) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.folder_zip_outlined),
                              title: Text(
                                e.label,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '${e.files.length} files · schema ${e.schemaVersion}',
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) async {
                                  if (v == 'share') await _share(e);
                                  if (v == 'downloads') {
                                    await _exportDownloads(e);
                                  }
                                  if (v == 'restore') await _restore(e);
                                  if (v == 'delete') await _delete(e);
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'share',
                                    child: Text('Share (USB / Drive / Bluetooth)'),
                                  ),
                                  PopupMenuItem(
                                    value: 'downloads',
                                    child: Text('Save to Downloads'),
                                  ),
                                  PopupMenuItem(
                                    value: 'restore',
                                    child: Text('Restore'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _busy ? null : () => _share(e),
                                      icon: const Icon(
                                        Icons.share_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('Share'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _busy
                                          ? null
                                          : () => _exportDownloads(e),
                                      icon: const Icon(
                                        Icons.download_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('Downloads'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
