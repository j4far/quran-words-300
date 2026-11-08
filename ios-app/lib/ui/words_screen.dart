import 'package:flutter/material.dart';

import '../data/models.dart';
import 'theme.dart';
import 'widgets.dart';
import 'word_detail_screen.dart';

enum WordFilter { all, learned, favourites, mistakes, notLearned }

extension on WordFilter {
  String get label => switch (this) {
        WordFilter.all => 'All',
        WordFilter.learned => 'Learned',
        WordFilter.favourites => 'Favourites',
        WordFilter.mistakes => 'Mistakes',
        WordFilter.notLearned => 'New',
      };
}

class WordsScreen extends StatefulWidget {
  const WordsScreen({super.key});

  @override
  State<WordsScreen> createState() => _WordsScreenState();
}

class _WordsScreenState extends State<WordsScreen> {
  final _search = TextEditingController();
  WordFilter _filter = WordFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Word> _results(BuildContext context) {
    final app = context.app;
    final q = _search.text.trim();
    final qa = normalizeArabic(q);
    final ql = normalizeLatin(q);
    return app.content.words.where((w) {
      final p = app.of(w.id);
      final passes = switch (_filter) {
        WordFilter.all => true,
        WordFilter.learned => p.learned,
        WordFilter.favourites => app.isFavourite(w.id),
        WordFilter.mistakes => p.inMistakes,
        WordFilter.notLearned => !p.learned,
      };
      if (!passes) return false;
      if (q.isEmpty) return true;
      return normalizeArabic(w.arabic).contains(qa) ||
          normalizeLatin(w.transliteration).contains(ql) ||
          w.english.toLowerCase().contains(q.toLowerCase()) ||
          w.alternativeMeanings.any((m) => m.toLowerCase().contains(q.toLowerCase())) ||
          '${w.frequencyRank}' == q;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _results(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Words')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: 'Arabic, transliteration or English',
                labelText: 'Search words',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => setState(_search.clear),
                      ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final f in WordFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.label),
                      selected: _filter == f,
                      onSelected: (_) {
                        feedback(context);
                        setState(() => _filter = f);
                      },
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${results.length} words',
                  style: TextStyle(color: context.qw.muted, fontSize: 12.5)),
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? const EmptyState(
                    icon: Icons.search_off_rounded,
                    message: 'No words found\nTry a different search or filter.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const Divider(indent: 16, endIndent: 16),
                    itemBuilder: (_, i) => WordTile(
                      word: results[i],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => WordDetailScreen(word: results[i])),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
