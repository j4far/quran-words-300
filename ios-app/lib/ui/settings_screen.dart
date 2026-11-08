import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'legal_screen.dart';
import 'theme.dart';
import 'widgets.dart';

const appVersion = '0.5.0';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.settings;

    Widget toggle(String title, String? subtitle, bool value, void Function(bool) set) =>
        SwitchListTile.adaptive(
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          value: value,
          onChanged: (v) {
            feedback(context);
            app.updateSettings((_) => set(v));
          },
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          const SectionTitle('Learning'),
          Card(
            child: Column(children: [
              ListTile(
                title: const Text('Daily goal'),
                subtitle: const Text('Pick a pace that feels easy to return to.'),
                trailing: DropdownButton<int>(
                  value: s.dailyGoal,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final g in const [5, 10, 15, 20, 30])
                      DropdownMenuItem(value: g, child: Text('$g words/day')),
                  ],
                  onChanged: (v) => app.updateSettings((x) => x.dailyGoal = v ?? 10),
                ),
              ),
              const Divider(),
              toggle('Show transliteration', null, s.showTransliteration,
                  (v) => s.showTransliteration = v),
            ]),
          ),
          const SectionTitle('Appearance & accessibility'),
          Card(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(children: [
                  const Expanded(child: Text('Theme', style: TextStyle(fontSize: 16))),
                  SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, label: Text('System')),
                      ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ],
                    selected: {s.themeMode},
                    onSelectionChanged: (v) => app.updateSettings((x) => x.themeMode = v.first),
                  ),
                ]),
              ),
              const Divider(),
              toggle('Dyslexia learning mode',
                  'Warmer reading panels, wider spacing and colour-supported Arabic words.',
                  s.dyslexiaMode, (v) => s.dyslexiaMode = v),
              const Divider(),
              toggle('High contrast', null, s.highContrast, (v) => s.highContrast = v),
              const Divider(),
              toggle('Reduced motion', null, s.reducedMotion, (v) => s.reducedMotion = v),
              const Divider(),
              toggle('Haptics', null, s.haptics, (v) => s.haptics = v),
              const Divider(),
              toggle('Sound', 'Soft click on answers', s.sound, (v) => s.sound = v),
            ]),
          ),
          const SectionTitle('Progress controls'),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.backup_rounded),
                title: const Text('Advanced backup'),
                subtitle: const Text('Optional manual backup for users who do not use cloud sync.'),
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const BackupScreen())),
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.restart_alt_rounded, color: context.qw.error),
                title: Text('Reset progress', style: TextStyle(color: context.qw.error)),
                onTap: () => _confirmReset(context),
              ),
            ]),
          ),
          const SectionTitle('About'),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.volunteer_activism_rounded),
                title: const Text("Du'a Request"),
                subtitle: const Text('View the short request shown on first launch.'),
                onTap: () => showDuaRequest(context),
              ),
              const Divider(),
              for (final (i, page) in LegalPage.values.indexed) ...[
                if (i > 0) const Divider(),
                ListTile(
                  leading: Icon(page.icon),
                  title: Text(page.title),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => LegalScreen(page: page))),
                ),
              ],
              const Divider(),
              const ListTile(
                leading: Icon(Icons.info_outline_rounded),
                title: Text('Version $appVersion'),
                subtitle: Text('No account. No ads. No tracking. Progress stays on this device.'),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final app = context.appRead;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset progress?'),
        content: const Text(
            'This clears local progress, streaks, achievements and settings from this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ctx.qw.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await app.resetProgress();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Progress reset')));
      }
    }
  }
}

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _restore = TextEditingController();
  String? _backup;

  @override
  void dispose() {
    _restore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Advanced backup')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(
            'Most learners will not need this. It exists because the app has no account or server; a user can manually move progress to another phone.',
            style: t.bodyMedium?.copyWith(color: context.qw.muted),
          ),
          const SectionTitle('Backup text'),
          FilledButton.icon(
            icon: const Icon(Icons.content_copy_rounded),
            label: const Text('Create backup text'),
            onPressed: () async {
              final text = context.appRead.createBackup();
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(ClipboardData(text: text));
              setState(() => _backup = text);
              messenger.showSnackBar(const SnackBar(content: Text('Backup copied')));
            },
          ),
          if (_backup != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.qw.panel,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(_backup!,
                  maxLines: 6, style: const TextStyle(fontFamily: 'Courier', fontSize: 11)),
            ),
          ],
          const SectionTitle('Restore from backup text'),
          TextField(
            controller: _restore,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Paste backup text',
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.content_paste_rounded),
                label: const Text('Paste'),
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null) setState(() => _restore.text = data!.text!);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () => _doRestore(context),
                child: const Text('Import'),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Text(
            'This information does not leave your device unless you choose to export a local backup yourself.',
            style: t.bodySmall?.copyWith(color: context.qw.muted),
          ),
        ],
      ),
    );
  }

  Future<void> _doRestore(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final app = context.appRead;
    if (_restore.text.trim().isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Replace progress?'),
        content: const Text('Importing replaces the progress currently on this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Import')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await app.restoreBackup(_restore.text);
      _restore.clear();
      messenger.showSnackBar(const SnackBar(content: Text('Progress imported')));
    } on FormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed. ${e.message}')));
    }
  }
}
