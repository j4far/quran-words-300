import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/quiz.dart';
import 'session_screen.dart';
import 'theme.dart';
import 'widgets.dart';
import 'word_detail_screen.dart';

void startLesson(BuildContext context, Lesson lesson) {
  final builder = QuizBuilder(context.appRead.content);
  feedback(context);
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => SessionScreen(
      title: 'Lesson ${lesson.order}: ${lesson.title}',
      steps: builder.lesson(lesson),
      lesson: lesson,
      rebuild: () => builder.lesson(lesson),
    ),
  ));
}

void startReview(BuildContext context, String title, List<Word> pool) {
  if (pool.isEmpty) return;
  final builder = QuizBuilder(context.appRead.content);
  feedback(context);
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => SessionScreen(
      title: title,
      steps: builder.review(pool),
      isReview: true,
      rebuild: () => builder.review(pool),
    ),
  ));
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final t = Theme.of(context).textTheme;
    final next = app.nextLesson;
    final due = app.dueWords;
    final stages = app.content.stages;
    final current = app.currentStageIndex;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset('assets/images/app_logo.png', width: 40, height: 40),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('Quran Words 300',
                        maxLines: 1,
                        style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                ),
                _Pill(icon: Icons.local_fire_department_rounded, text: '${app.currentStreak}', tooltip: 'Current streak'),
                const SizedBox(width: 8),
                _Pill(icon: Icons.bolt_rounded, text: '${app.xp}', tooltip: 'XP total'),
              ],
            ),
            const SizedBox(height: 20),
            _TodayCard(next: next),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _GoalCard()),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniCard(
                    icon: Icons.replay_rounded,
                    title: due.isEmpty ? 'Nothing due' : '${due.length} due',
                    subtitle: due.isEmpty ? 'Reviews will appear here' : 'Due review',
                    onTap: due.isEmpty ? null : () => startReview(context, 'Due review', due),
                  ),
                ),
              ],
            ),
            const SectionTitle('Word of the day'),
            _WordOfDay(word: app.wordOfTheDay),
            SectionTitle(
              'Learning path',
              trailing: TextButton(
                onPressed: () => setState(() => _showAll = !_showAll),
                child: Text(_showAll ? 'Collapse' : 'Show all'),
              ),
            ),
            if (!_showAll)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text(
                  'Showing your current stage. Expand to view all ${stages.length} stages.',
                  style: t.bodySmall?.copyWith(color: context.qw.muted),
                ),
              ),
            for (final s in stages)
              if (_showAll || s.index == current) _StageBlock(stage: s, isCurrent: s.index == current),
            const SizedBox(height: 24),
            Text(
              'This app is an educational vocabulary aid. It is not tafsir, a fatwa, or a full Qur\'an translation. Meanings are simplified learning glosses and may vary depending on grammar and context.',
              style: t.bodySmall?.copyWith(color: context.qw.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, required this.tooltip});
  final IconData icon;
  final String text;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: context.qw.panel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.qw.line),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: context.qw.gold),
            const SizedBox(width: 4),
            Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
        ),
      );
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.next});
  final Lesson? next;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final t = Theme.of(context).textTheme;
    final qw = context.qw;
    final learned = next == null ? 0 : app.lessonLearnedCount(next!);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [qw.hero, Color.lerp(qw.hero, Colors.black, .25)!],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(next == null ? 'Path complete' : "Today's path",
              style: t.labelLarge?.copyWith(color: qw.gold, fontWeight: FontWeight.w800, letterSpacing: .6)),
          const SizedBox(height: 6),
          Text(
            next == null ? 'All 300 words learned' : 'Lesson ${next!.order}',
            style: t.headlineSmall?.copyWith(color: qw.onHero, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            next == null
                ? 'MashaAllah. Keep them fresh with regular reviews.'
                : '${next!.title} · ${next!.wordIds.length - learned} new words',
            style: t.bodyMedium?.copyWith(color: qw.onHero.withValues(alpha: .85)),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: app.learnedCount / app.content.words.length,
              minHeight: 8,
              color: qw.gold,
              backgroundColor: Colors.white.withValues(alpha: .15),
            ),
          ),
          const SizedBox(height: 6),
          Text('${app.learnedCount} / ${app.content.words.length} words learned',
              style: t.bodySmall?.copyWith(color: qw.onHero.withValues(alpha: .85))),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: qw.gold, foregroundColor: const Color(0xFF1E1606)),
              onPressed: next == null
                  ? () => startReview(context, 'Repeat anytime', app.learnedWords.toList())
                  : () => startLesson(context, next!),
              child: Text(next == null
                  ? 'Review words'
                  : (app.completedLessons.isEmpty && learned == 0 ? 'Start learning' : 'Start lesson')),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final goal = app.settings.dailyGoal;
    final done = app.todayCount;
    return Card(
      child: Semantics(
        label: 'Daily goal progress',
        value: '$done of $goal words practised today',
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              SizedBox(
                width: 46,
                height: 46,
                child: Stack(alignment: Alignment.center, children: [
                  CircularProgressIndicator(
                    value: (done / goal).clamp(0, 1).toDouble(),
                    strokeWidth: 5,
                    backgroundColor: context.qw.line,
                    color: app.goalMetToday ? context.qw.success : Theme.of(context).colorScheme.primary,
                  ),
                  Icon(app.goalMetToday ? Icons.check_rounded : Icons.flag_rounded, size: 20),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$done / $goal', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  Text('Daily goal', style: TextStyle(color: context.qw.muted, fontSize: 12.5)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.icon, required this.title, required this.subtitle, this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: context.qw.panel,
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.qw.muted, fontSize: 12.5)),
                ]),
              ),
            ]),
          ),
        ),
      );
}

class _WordOfDay extends StatelessWidget {
  const _WordOfDay({required this.word});
  final Word word;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => WordDetailScreen(word: word))),
        child: Container(
          color: context.qw.panel,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(word.meaning, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  if (context.app.settings.showTransliteration)
                    Text(word.transliteration,
                        style: t.bodyMedium?.copyWith(color: context.qw.muted, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 4),
                  Text('${word.partOfSpeech} · rank ${word.frequencyRank}',
                      style: t.bodySmall?.copyWith(color: context.qw.muted)),
                ]),
              ),
              ArabicText(word.arabic, size: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageBlock extends StatelessWidget {
  const _StageBlock({required this.stage, required this.isCurrent});
  final Stage stage;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final t = Theme.of(context).textTheme;
    final done = stage.lessons.where(app.isLessonComplete).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              color: isCurrent ? Theme.of(context).colorScheme.primary.withValues(alpha: .08) : null,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(stage.title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    Text(stage.subtitle, style: t.bodySmall?.copyWith(color: context.qw.muted)),
                  ]),
                ),
                Text('$done/${stage.lessons.length}',
                    style: t.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: context.qw.muted)),
              ]),
            ),
            const Divider(),
            for (final l in stage.lessons) _LessonRow(lesson: l),
          ],
        ),
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({required this.lesson});
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final cs = Theme.of(context).colorScheme;
    final complete = app.isLessonComplete(lesson);
    final unlocked = app.isLessonUnlocked(lesson);
    final isNext = app.nextLesson == lesson;
    final words = app.content.wordsFor(lesson);
    return ListTile(
      enabled: unlocked,
      onTap: unlocked ? () => startLesson(context, lesson) : null,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: complete
            ? context.qw.success
            : isNext
                ? cs.primary
                : context.qw.panel,
        foregroundColor: complete || isNext ? Colors.white : context.qw.muted,
        child: complete
            ? const Icon(Icons.check_rounded, size: 20)
            : unlocked
                ? Text('${lesson.order}', style: const TextStyle(fontWeight: FontWeight.w800))
                : const Icon(Icons.lock_rounded, size: 16),
      ),
      title: Text(lesson.title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        words.take(3).map((w) => w.meaning).join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: complete
          ? Text('Repeat', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600))
          : isNext
              ? Icon(Icons.play_circle_fill_rounded, color: cs.primary, size: 30)
              : null,
    );
  }
}
