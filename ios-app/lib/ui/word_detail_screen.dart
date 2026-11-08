import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/quiz.dart';
import 'session_screen.dart';
import 'theme.dart';
import 'widgets.dart';

class WordDetailScreen extends StatelessWidget {
  const WordDetailScreen({super.key, required this.word});
  final Word word;

  String _nextReview(DateTime? due, DateTime now) {
    if (due == null) return 'Not scheduled';
    if (!due.isAfter(now)) return 'Due now';
    final days = DateTime(due.year, due.month, due.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    if (days <= 0) return 'Later today';
    if (days == 1) return 'Tomorrow';
    return 'In $days days';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final p = app.of(word.id);
    final t = Theme.of(context).textTheme;
    final fav = app.isFavourite(word.id);
    final lesson = app.content.lessons.firstWhere((l) => l.wordIds.contains(word.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Word detail'),
        actions: [
          IconButton(
            tooltip: fav ? 'Remove favourite' : 'Add favourite',
            icon: Icon(fav ? Icons.star_rounded : Icons.star_outline_rounded,
                color: fav ? context.qw.gold : null),
            onPressed: () {
              feedback(context);
              app.toggleFavourite(word.id);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            decoration: BoxDecoration(
              color: context.qw.panel,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: context.qw.line),
            ),
            child: Column(children: [
              ArabicText(word.arabic, size: 60),
              Text(word.transliteration,
                  style: t.titleMedium?.copyWith(color: context.qw.muted, fontStyle: FontStyle.italic)),
              const SizedBox(height: 12),
              Text(word.meaning,
                  textAlign: TextAlign.center,
                  style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              if (word.alsoMeanings.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Also: ${word.alsoMeanings.join(', ')}',
                      textAlign: TextAlign.center,
                      style: t.bodyMedium?.copyWith(color: context.qw.muted)),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(children: [
              _row(context, 'Part of speech', word.partOfSpeech),
              const Divider(),
              _row(context, 'Frequency rank', '#${word.frequencyRank} of 300'),
              const Divider(),
              _row(context, 'Lesson', 'Lesson ${lesson.order} · ${lesson.title}'),
              const Divider(),
              _row(context, 'Difficulty', '${'●' * word.difficulty}${'○' * (3 - word.difficulty)}'),
              if (word.root != null) ...[
                const Divider(),
                _row(context, 'Root', word.root!),
              ],
              const Divider(),
              ListTile(
                title: const Text('Mastery level'),
                trailing: p.learned ? MasteryDots(p.mastery) : const Text('Not learned yet'),
              ),
              const Divider(),
              _row(context, 'Next review', p.learned ? _nextReview(p.due, app.now) : 'Not scheduled'),
              if (p.correct + p.wrong > 0) ...[
                const Divider(),
                _row(context, 'Answers', '${p.correct} correct · ${p.wrong} missed'),
              ],
            ]),
          ),
          const SectionTitle('Learning note'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(word.notes, style: t.bodyMedium),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.quiz_rounded),
            label: const Text('Quiz me on this word'),
            onPressed: () {
              feedback(context);
              final b = QuizBuilder(app.content);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SessionScreen(
                    title: word.meaning,
                    steps: b.single(word),
                    isReview: p.learned,
                    rebuild: () => b.single(word),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) => ListTile(
        title: Text(label),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      );
}
