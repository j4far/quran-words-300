import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// A single vocabulary item from assets/data/words_en.json.
class Word {
  const Word({
    required this.id,
    required this.arabic,
    required this.transliteration,
    required this.english,
    required this.alternativeMeanings,
    required this.partOfSpeech,
    required this.frequencyRank,
    required this.lessonGroup,
    required this.difficulty,
    required this.notes,
    this.root,
  });

  final int id;
  final String arabic;
  final String transliteration;
  final String english;
  final List<String> alternativeMeanings;
  final String? root;
  final String partOfSpeech;
  final int frequencyRank;
  final String lessonGroup;
  final int difficulty;
  final String notes;

  factory Word.fromJson(Map<String, dynamic> j) => Word(
        id: j['id'] as int,
        arabic: j['arabic'] as String,
        transliteration: j['transliteration'] as String,
        english: j['english'] as String,
        alternativeMeanings:
            ((j['alternativeMeanings'] as List?) ?? const []).cast<String>(),
        root: j['root'] as String?,
        partOfSpeech: (j['partOfSpeech'] as String?) ?? 'word',
        frequencyRank: (j['frequencyRank'] as int?) ?? j['id'] as int,
        lessonGroup: (j['lessonGroup'] as String?) ?? '',
        difficulty: (j['difficulty'] as int?) ?? 1,
        notes: (j['notes'] as String?) ?? '',
      );

  /// Learner-facing meaning with grammar hints such as "(for broken plural)"
  /// removed, matching the Android build.
  String get meaning => cleanLabel(english);

  List<String> get alsoMeanings =>
      alternativeMeanings.map(cleanLabel).where((m) => m.isNotEmpty).toList();
}

final _grammarHint = RegExp(r'\s*\((?:for\s+)?broken plural\)\s*',
    caseSensitive: false);

String cleanLabel(String s) => s.replaceAll(_grammarHint, ' ').trim();

/// A lesson (unit) from assets/data/lessons_en.json.
class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.unitTitle,
    required this.description,
    required this.wordIds,
    required this.difficulty,
    required this.order,
  });

  final String id;
  final String title;
  final String unitTitle;
  final String description;
  final List<int> wordIds;
  final int difficulty;
  final int order;

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
        id: j['id'] as String,
        title: j['title'] as String,
        unitTitle: (j['unitTitle'] as String?) ?? '',
        description: (j['description'] as String?) ?? '',
        wordIds: (j['wordIds'] as List).cast<int>(),
        difficulty: (j['difficulty'] as int?) ?? 1,
        order: (j['order'] as int?) ?? 0,
      );
}

/// Lessons are grouped into stages of five for the collapsible learning path.
class Stage {
  const Stage(this.index, this.lessons);
  final int index;
  final List<Lesson> lessons;

  String get title => 'Stage ${index + 1}';
  String get subtitle {
    final first = lessons.first.wordIds.first;
    final last = lessons.last.wordIds.last;
    return 'Words $first-$last';
  }
}

class Content {
  Content(this.words, this.lessons)
      : wordById = {for (final w in words) w.id: w};

  final List<Word> words;
  final List<Lesson> lessons;
  final Map<int, Word> wordById;

  static const lessonsPerStage = 5;

  List<Stage> get stages {
    final out = <Stage>[];
    for (var i = 0; i < lessons.length; i += lessonsPerStage) {
      out.add(Stage(
        out.length,
        lessons.sublist(i, (i + lessonsPerStage).clamp(0, lessons.length)),
      ));
    }
    return out;
  }

  List<Word> wordsFor(Lesson l) => [for (final id in l.wordIds) wordById[id]!];

  static Future<Content> load() async {
    final wordsJson =
        jsonDecode(await rootBundle.loadString('assets/data/words_en.json'))
            as List;
    final lessonsJson =
        jsonDecode(await rootBundle.loadString('assets/data/lessons_en.json'))
            as List;
    final words = wordsJson
        .map((e) => Word.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final lessons = lessonsJson
        .map((e) => Lesson.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return Content(words, lessons);
  }
}

/// Strips Arabic diacritics (harakat, tatweel, superscript alef) for search.
String normalizeArabic(String s) => s
    .replaceAll(RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ]'), '')
    .replaceAll(RegExp('[آأإٱ]'), 'ا');

/// Lower-cases and strips Latin transliteration marks for search/typing.
String normalizeLatin(String s) {
  const map = {
    'ā': 'a', 'á': 'a', 'à': 'a', 'â': 'a',
    'ī': 'i', 'í': 'i', 'ì': 'i',
    'ū': 'u', 'ú': 'u', 'ù': 'u',
    'ḥ': 'h', 'ḍ': 'd', 'ṣ': 's', 'ṭ': 't', 'ẓ': 'z', 'ḏ': 'dh', 'ṯ': 'th',
    'ʾ': '', 'ʿ': '', '\'': '', '’': '', '‘': '', 'ʼ': '',
  };
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    b.write(map[ch] ?? ch);
  }
  return b.toString();
}
