import 'dart:math';

import 'models.dart';

sealed class QuizStep {
  const QuizStep();
  Word? get word => null;
}

/// "Read the meaning first" introduction card.
class LearnStep extends QuizStep {
  const LearnStep(this.w);
  final Word w;
  @override
  Word get word => w;
}

/// Arabic shown, choose the common English meaning.
class MeaningChoiceStep extends QuizStep {
  const MeaningChoiceStep(this.w, this.options);
  final Word w;
  final List<Word> options;
  @override
  Word get word => w;
}

/// English shown, choose the Arabic word.
class ArabicChoiceStep extends QuizStep {
  const ArabicChoiceStep(this.w, this.options);
  final Word w;
  final List<Word> options;
  @override
  Word get word => w;
}

/// Match each Arabic word to its meaning.
class MatchStep extends QuizStep {
  const MatchStep(this.words);
  final List<Word> words;
}

/// Arabic shown, type a common meaning.
class TypeStep extends QuizStep {
  const TypeStep(this.w);
  final Word w;
  @override
  Word get word => w;
}

class QuizBuilder {
  QuizBuilder(this.content, {Random? random}) : _rng = random ?? Random();

  final Content content;
  final Random _rng;

  static const chunkSize = 5;

  /// Builds a full lesson: per chunk of five words, introduction cards,
  /// recognition questions in both directions, a matching round and one
  /// typed answer.
  List<QuizStep> lesson(Lesson lesson) {
    final words = content.wordsFor(lesson);
    final steps = <QuizStep>[];
    for (var i = 0; i < words.length; i += chunkSize) {
      final chunk = words.sublist(i, min(i + chunkSize, words.length));
      steps.addAll(chunk.map(LearnStep.new));
      final shuffled = [...chunk]..shuffle(_rng);
      for (var k = 0; k < shuffled.length; k++) {
        steps.add(k.isEven
            ? meaningChoice(shuffled[k])
            : arabicChoice(shuffled[k]));
      }
      final matchable = distinctMeanings(chunk);
      if (matchable.length >= 3) steps.add(MatchStep(matchable));
      steps.add(TypeStep(_typeable(chunk)));
    }
    return steps;
  }

  /// A review round over up to ten words.
  List<QuizStep> review(List<Word> pool, {int maxWords = 10}) {
    final words = ([...pool]..shuffle(_rng)).take(maxWords).toList();
    if (words.isEmpty) return const [];
    final steps = <QuizStep>[
      for (final w in words)
        _rng.nextBool() ? meaningChoice(w) : arabicChoice(w),
    ];
    final matchable = distinctMeanings(words).take(5).toList();
    if (matchable.length >= 4) {
      steps.insert(steps.length ~/ 2, MatchStep(matchable));
    }
    if (words.length >= 3) steps.add(TypeStep(_typeable(words)));
    return steps;
  }

  /// Quick quiz on one word from its detail page.
  List<QuizStep> single(Word w) => [
        meaningChoice(w),
        arabicChoice(w),
        TypeStep(w),
      ];

  MeaningChoiceStep meaningChoice(Word w) =>
      MeaningChoiceStep(w, _options(w, byMeaning: true));

  ArabicChoiceStep arabicChoice(Word w) =>
      ArabicChoiceStep(w, _options(w, byMeaning: false));

  Word _typeable(List<Word> words) {
    final sorted = [...words]
      ..sort((a, b) => a.meaning.length.compareTo(b.meaning.length));
    return sorted.first;
  }

  /// Four options: the answer plus three distractors with distinct meanings
  /// and Arabic forms, preferring the same part of speech.
  List<Word> _options(Word answer, {required bool byMeaning}) {
    // Words that share a meaning (e.g. two words glossed "this") or an
    // Arabic form would make a question ambiguous, so never offer both.
    final usedMeanings = {answer.meaning.toLowerCase()};
    final usedArabic = {normalizeArabic(answer.arabic)};
    final samePos = content.words
        .where((w) => w.id != answer.id && w.partOfSpeech == answer.partOfSpeech)
        .toList()
      ..shuffle(_rng);
    final others = content.words.where((w) => w.id != answer.id).toList()
      ..shuffle(_rng);
    final picks = <Word>[];
    for (final w in [...samePos, ...others]) {
      if (picks.length == 3) break;
      final m = w.meaning.toLowerCase(), a = normalizeArabic(w.arabic);
      if (usedMeanings.contains(m) || usedArabic.contains(a)) continue;
      usedMeanings.add(m);
      usedArabic.add(a);
      picks.add(w);
    }
    return [answer, ...picks]..shuffle(_rng);
  }
}

/// Keeps only the first word for each meaning so matching rounds never have
/// two identical answers on the right-hand side.
List<Word> distinctMeanings(List<Word> words) {
  final seen = <String>{};
  return [for (final w in words) if (seen.add(w.meaning.toLowerCase())) w];
}

// ------------------------------------------------------------ typed answers

final _articles = RegExp(r'^(to|the|a|an|o)\s+');

String _norm(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'\([^)]*\)'), ' ')
    .replaceAll(RegExp(r"[^a-z0-9\s']"), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim()
    .replaceFirst(_articles, '');

/// All accepted forms of a word's meaning.
Set<String> acceptedAnswers(Word w) {
  final raw = <String>[w.english, w.meaning, ...w.alternativeMeanings];
  final out = <String>{};
  for (final r in raw) {
    out.add(_norm(r));
    for (final part in r.split(RegExp(r'[/,;]| or '))) {
      final n = _norm(part);
      if (n.isNotEmpty) out.add(n);
    }
  }
  out.remove('');
  return out;
}

/// Lenient check: ignores case, punctuation, leading "to/the/a" and allows
/// one typo on longer answers.
bool checkTyped(Word w, String input) {
  final guess = _norm(input);
  if (guess.isEmpty) return false;
  for (final a in acceptedAnswers(w)) {
    if (a == guess) return true;
    if (a.length >= 5 && _distance(a, guess) <= 1) return true;
  }
  return false;
}

int _distance(String a, String b) {
  if ((a.length - b.length).abs() > 1) return 2;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      cur[j] = min(min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
    }
    prev = cur;
  }
  return prev[b.length];
}
