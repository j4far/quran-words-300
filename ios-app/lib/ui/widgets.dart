import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import 'theme.dart';

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

extension AppX on BuildContext {
  AppState get app => AppScope.of(this);
  AppState get appRead => AppScope.read(this);
}

/// Haptic + optional click feedback, respecting settings.
void feedback(BuildContext context, {bool? correct}) {
  final s = context.appRead.settings;
  if (s.haptics) {
    if (correct == false) {
      HapticFeedback.heavyImpact();
    } else if (correct == true) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }
  if (s.sound) SystemSound.play(SystemSoundType.click);
}

Duration motion(BuildContext context, [int ms = 250]) =>
    context.appRead.settings.reducedMotion ? Duration.zero : Duration(milliseconds: ms);

class ArabicText extends StatelessWidget {
  const ArabicText(this.text,
      {super.key, this.size = 40, this.color, this.bold = false, this.align = TextAlign.center});

  final String text;
  final double size;
  final Color? color;
  final bool bold;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final dys = context.app.settings.dyslexiaMode;
    return Text(
      text,
      textDirection: TextDirection.rtl,
      textAlign: align,
      style: TextStyle(
        fontFamily: 'Amiri',
        fontSize: dys ? size * 1.12 : size,
        height: dys ? 1.9 : 1.6,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        color: color ?? context.qw.arabic,
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ),
            ?trailing,
          ],
        ),
      );
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, this.icon});
  final String value;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) Icon(icon, size: 20, color: context.qw.gold),
            if (icon != null) const SizedBox(height: 8),
            Text(value, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: t.bodySmall?.copyWith(color: context.qw.muted)),
          ],
        ),
      ),
    );
  }
}

class MasteryDots extends StatelessWidget {
  const MasteryDots(this.level, {super.key});
  final int level;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Mastery level $level of ${AppState.maxMastery}',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= AppState.maxMastery; i++)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= level
                      ? Theme.of(context).colorScheme.primary
                      : context.qw.line,
                ),
              ),
          ],
        ),
      );
}

class WordTile extends StatelessWidget {
  const WordTile({super.key, required this.word, required this.onTap});
  final Word word;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final p = app.of(word.id);
    final t = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'Open word details',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 34,
                child: Text('${word.frequencyRank}',
                    style: t.labelMedium?.copyWith(color: context.qw.muted)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(word.meaning,
                        style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    if (app.settings.showTransliteration)
                      Text(word.transliteration,
                          style: t.bodySmall?.copyWith(
                              color: context.qw.muted, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
              if (app.isFavourite(word.id))
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(Icons.star_rounded, size: 18, color: context.qw.gold),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ArabicText(word.arabic, size: 26, align: TextAlign.right),
                  if (p.learned) MasteryDots(p.mastery),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: context.qw.muted),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: context.qw.muted)),
          ],
        ),
      );
}

/// The du'a request shown on first launch and from Settings > About.
const duaRequestText =
    "This app has been made available to you for free. All I ask is that you make du'a for me and my family, so that we both benefit from the rewards. Thank you.";

Future<void> showDuaRequest(BuildContext context, {bool firstLaunch = false}) {
  final app = context.appRead;
  var hide = app.settings.hideDuaRequest;
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        icon: Icon(Icons.volunteer_activism_rounded, color: ctx.qw.gold, size: 36),
        title: const Text("Du'a Request"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(duaRequestText, textAlign: TextAlign.center),
            if (firstLaunch) ...[
              const SizedBox(height: 12),
              CheckboxListTile(
                value: hide,
                onChanged: (v) => setState(() => hide = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Do not show this again'),
              ),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              if (firstLaunch && hide != app.settings.hideDuaRequest) {
                app.updateSettings((s) => s.hideDuaRequest = hide);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    ),
  );
}
