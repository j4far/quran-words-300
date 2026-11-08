import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'theme.dart';
import 'widgets.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final stats = [
      ('${app.learnedCount}', 'Words learned', Icons.menu_book_rounded),
      ('${app.masteredCount}', 'Words mastered', Icons.workspace_premium_rounded),
      ('${app.completedLessons.length}/${app.content.lessons.length}', 'Lessons completed', Icons.school_rounded),
      ('${app.xp}', 'XP total', Icons.bolt_rounded),
      ('${app.currentStreak}', 'Current streak', Icons.local_fire_department_rounded),
      ('${app.longestStreak}', 'Longest streak', Icons.emoji_events_rounded),
      ('${app.accuracy}%', 'Accuracy', Icons.track_changes_rounded),
      ('${app.reviewsDone}', 'Review cards', Icons.replay_rounded),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${app.learnedCount} / 300 words learned',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: app.learnedCount / 300,
                    minHeight: 10,
                    backgroundColor: context.qw.line,
                  ),
                ),
                const SizedBox(height: 8),
                Text('About 80% of word occurrences in the Qur\'an come from these 300 words.',
                    style: TextStyle(color: context.qw.muted, fontSize: 12.5)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: [
              for (final (v, l, i) in stats) StatTile(value: v, label: l, icon: i),
            ],
          ),
          const SectionTitle('Daily goal calendar'),
          const _GoalCalendar(),
          const SectionTitle('Achievements'),
          for (final a in achievements) _AchievementTile(a, unlocked: app.unlockedAchievements.contains(a.id)),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile(this.a, {required this.unlocked});
  final Achievement a;
  final bool unlocked;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Semantics(
          label: unlocked ? 'Unlocked achievement' : 'Locked achievement',
          child: Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: unlocked ? context.qw.gold.withValues(alpha: .18) : context.qw.panel,
                child: Icon(unlocked ? a.icon : Icons.lock_rounded,
                    color: unlocked ? context.qw.gold : context.qw.muted),
              ),
              title: Text(a.title,
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: unlocked ? null : context.qw.muted)),
              subtitle: Text(a.description),
              trailing: unlocked ? Icon(Icons.check_circle_rounded, color: context.qw.success) : null,
            ),
          ),
        ),
      );
}

class _GoalCalendar extends StatefulWidget {
  const _GoalCalendar();

  @override
  State<_GoalCalendar> createState() => _GoalCalendarState();
}

class _GoalCalendarState extends State<_GoalCalendar> {
  late DateTime _month;
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    final n = context.appRead.now;
    _month = DateTime(n.year, n.month);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final now = app.now;
    final first = DateTime(_month.year, _month.month);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = first.weekday % 7; // Sunday-first grid
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
        child: Column(children: [
          Row(children: [
            IconButton(
              tooltip: 'Previous month',
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
            ),
            Expanded(
              child: Text('${_months[_month.month - 1]} ${_month.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            IconButton(
              tooltip: 'Next month',
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
            ),
          ]),
          Row(children: [
            for (final d in ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
              Expanded(
                child: Center(
                  child: Text(d, style: TextStyle(color: context.qw.muted, fontWeight: FontWeight.w700)),
                ),
              ),
          ]),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            children: [
              for (var i = 0; i < lead; i++) const SizedBox.shrink(),
              for (var day = 1; day <= daysInMonth; day++)
                Builder(builder: (context) {
                  final d = DateTime(_month.year, _month.month, day);
                  final met = app.goalMetOn(d);
                  final studied = app.studiedOn(d);
                  final today = d.year == now.year && d.month == now.month && d.day == now.day;
                  return Semantics(
                    label: '$day ${_months[_month.month - 1]}, ${met ? 'goal met' : studied ? 'studied' : 'missed'}',
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: met
                            ? cs.primary
                            : studied
                                ? cs.primary.withValues(alpha: .22)
                                : null,
                        border: today ? Border.all(color: context.qw.gold, width: 2) : null,
                      ),
                      alignment: Alignment.center,
                      child: Text('$day',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: met || today ? FontWeight.w800 : FontWeight.w500,
                            color: met ? cs.onPrimary : null,
                          )),
                    ),
                  );
                }),
            ],
          ),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _legend(context, cs.primary, 'Goal met'),
            const SizedBox(width: 16),
            _legend(context, cs.primary.withValues(alpha: .22), 'Studied'),
          ]),
        ]),
      ),
    );
  }

  Widget _legend(BuildContext context, Color c, String label) => Row(children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: context.qw.muted, fontSize: 12.5)),
      ]);
}
