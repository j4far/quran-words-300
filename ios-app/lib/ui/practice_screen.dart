import 'package:flutter/material.dart';

import '../data/models.dart';
import 'home_screen.dart';
import 'theme.dart';
import 'widgets.dart';
import 'word_detail_screen.dart';

class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final t = Theme.of(context).textTheme;
    final learned = app.learnedWords.toList();
    final weak = app.weakWords;

    final modes = <_Mode>[
      _Mode('Due review', Icons.schedule_rounded, app.dueWords,
          'No due words yet. New and scheduled words will appear here.'),
      _Mode('Mistake review', Icons.healing_rounded, app.mistakeWords,
          'Mistakes will collect here for gentle review.'),
      _Mode('Weak words', Icons.trending_up_rounded, weak.take(10).toList(),
          'Lower mastery words will appear here as you practise.'),
      _Mode('Favourite review', Icons.star_rounded, app.favouriteWords,
          'Bookmark words from their detail page to keep them close.'),
      _Mode('Mastered refresher', Icons.workspace_premium_rounded, app.masteredWords,
          'Mastered words will appear here for occasional refreshers.'),
      _Mode('Repeat anytime', Icons.all_inclusive_rounded, learned,
          'Words move here after you have practised them.'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Practice')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text('Practice due and mistake words',
              style: t.bodyMedium?.copyWith(color: context.qw.muted)),
          const SizedBox(height: 12),
          if (learned.isEmpty)
            const Card(
              child: EmptyState(
                icon: Icons.school_rounded,
                message: 'Try a lesson first, then practice cards will appear here.',
              ),
            ),
          for (final m in modes)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: CircleAvatar(
                    backgroundColor: context.qw.panel,
                    child: Icon(m.icon, color: Theme.of(context).colorScheme.primary),
                  ),
                  title: Text(m.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(m.words.isEmpty
                      ? m.empty
                      : '${m.words.length} word${m.words.length == 1 ? '' : 's'}'),
                  trailing: m.words.isEmpty
                      ? null
                      : Icon(Icons.play_circle_fill_rounded,
                          color: Theme.of(context).colorScheme.primary, size: 32),
                  onTap: m.words.isEmpty ? null : () => startReview(context, m.title, m.words),
                ),
              ),
            ),
          const SectionTitle('Weakest words'),
          if (weak.isEmpty)
            const Card(
              child: EmptyState(
                icon: Icons.insights_rounded,
                message: 'Practise a few lessons and weaker words will appear here.',
              ),
            )
          else
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                for (final (i, w) in weak.take(5).indexed) ...[
                  if (i > 0) const Divider(),
                  WordTile(word: w, onTap: () => _open(context, w)),
                ],
              ]),
            ),
        ],
      ),
    );
  }

  void _open(BuildContext context, Word w) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => WordDetailScreen(word: w)));
}

class _Mode {
  const _Mode(this.title, this.icon, this.words, this.empty);
  final String title;
  final IconData icon;
  final List<Word> words;
  final String empty;
}
