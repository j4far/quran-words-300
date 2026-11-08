import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_words_300/data/models.dart';
import 'package:quran_words_300/data/quiz.dart';
import 'package:quran_words_300/main.dart';
import 'package:quran_words_300/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Content content;

  setUpAll(() async {
    content = await Content.load();
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('content', () {
    test('has 300 words in 30 lessons covering every word once', () {
      expect(content.words.length, 300);
      expect(content.lessons.length, 30);
      final ids = content.lessons.expand((l) => l.wordIds).toList();
      expect(ids.toSet().length, 300);
      expect(content.stages.length, 6);
    });

    test('grammar hints are removed from learner labels', () {
      expect(cleanLabel('houses (broken plural)'), 'houses');
      expect(cleanLabel('days (for broken plural)'), 'days');
      for (final w in content.words) {
        expect(w.meaning.contains('broken plural'), isFalse, reason: w.english);
      }
    });

    test('arabic search ignores diacritics', () {
      expect(normalizeArabic('كِتَاب'), 'كتاب');
      expect(normalizeLatin('ṣalaḥa'), 'salaha');
    });
  });

  group('quiz', () {
    test('lesson steps include every word and all question types', () {
      final b = QuizBuilder(content, random: Random(1));
      final steps = b.lesson(content.lessons.first);
      final learn = steps.whereType<LearnStep>().map((s) => s.w.id).toSet();
      expect(learn, content.lessons.first.wordIds.toSet());
      expect(steps.whereType<MeaningChoiceStep>(), isNotEmpty);
      expect(steps.whereType<ArabicChoiceStep>(), isNotEmpty);
      expect(steps.whereType<MatchStep>().length, 2);
      for (final m in steps.whereType<MatchStep>()) {
        expect(m.words.map((w) => w.meaning.toLowerCase()).toSet().length, m.words.length);
      }
      expect(steps.whereType<TypeStep>().length, 2);
    });

    test('options always contain the answer and four distinct choices', () {
      final b = QuizBuilder(content, random: Random(7));
      for (final w in content.words) {
        final m = b.meaningChoice(w);
        expect(m.options.length, 4);
        expect(m.options.map((o) => o.id), contains(w.id));
        expect(m.options.map((o) => o.meaning.toLowerCase()).toSet().length, 4);
        final a = b.arabicChoice(w);
        expect(a.options.map((o) => normalizeArabic(o.arabic)).toSet().length, 4);
        expect(a.options.map((o) => o.meaning.toLowerCase()).toSet().length, 4,
            reason: 'two Arabic options share the meaning of ${w.meaning}');
      }
    });

    test('typed answers are lenient but not loose', () {
      final w = content.words.firstWhere((w) => w.english == 'this');
      expect(checkTyped(w, 'This'), isTrue);
      expect(checkTyped(w, ' this. '), isTrue);
      expect(checkTyped(w, 'that'), isFalse);
      final verb = content.words.firstWhere((w) => w.english.startsWith('to '));
      expect(checkTyped(verb, verb.english.substring(3)), isTrue);
      expect(checkTyped(verb, ''), isFalse);
    });
  });

  group('progress', () {
    test('spaced repetition schedules and demotes', () {
      var now = DateTime(2026, 11, 9, 9);
      final s = AppState(content, clock: () => now);
      s.recordAnswer(1, true, isReview: false);
      expect(s.of(1).learned, isTrue);
      expect(s.of(1).mastery, 1);
      expect(s.of(1).due, now.add(const Duration(days: 1)));
      s.recordAnswer(1, true, isReview: true);
      expect(s.of(1).mastery, 2);
      s.recordAnswer(1, false, isReview: true);
      expect(s.of(1).mastery, 1);
      expect(s.of(1).inMistakes, isTrue);
      expect(s.dueWords.map((w) => w.id), contains(1));
    });

    test('lesson completion unlocks next lesson, awards XP and achievement', () {
      final now = DateTime(2026, 11, 9, 9);
      final s = AppState(content, clock: () => now);
      final l1 = content.lessons[0], l2 = content.lessons[1];
      expect(s.isLessonUnlocked(l2), isFalse);
      final r = s.finishSession(correct: 10, total: 10, xpEarned: 100, wordsPractised: 10, lesson: l1);
      expect(s.isLessonUnlocked(l2), isTrue);
      expect(s.learnedCount, 10);
      expect(r.xp, 130);
      expect(r.newAchievements.map((a) => a.id), containsAll(['first_lesson', 'perfect_lesson']));
      expect(s.nextLesson, l2);
      expect(s.goalMetToday, isTrue);
    });

    test('streak counts consecutive study days', () {
      var now = DateTime(2026, 11, 1, 20);
      final s = AppState(content, clock: () => now);
      for (var i = 0; i < 7; i++) {
        s.addPractised(5);
        now = now.add(const Duration(days: 1));
      }
      now = now.subtract(const Duration(days: 1));
      expect(s.currentStreak, 7);
      expect(s.longestStreak, 7);
    });

    test('backup round-trips and rejects junk', () async {
      final s = AppState(content);
      await s.load();
      s.recordAnswer(5, true, isReview: false);
      s.toggleFavourite(5);
      final text = s.createBackup();
      final t = AppState(content);
      await t.load();
      await t.restoreBackup(text);
      expect(t.of(5).learned, isTrue);
      expect(t.isFavourite(5), isTrue);
      expect(() => t.restoreBackup('not a backup'), throwsFormatException);
    });
  });

  testWidgets('app starts, shows du\'a request and home', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 860));
    final state = AppState(content);
    await state.load();
    await tester.pumpWidget(QuranWordsApp(state: state));
    await tester.pumpAndSettle();
    expect(find.text("Du'a Request"), findsOneWidget);
    await tester.tap(find.text('Do not show this again'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(state.settings.hideDuaRequest, isTrue);
    expect(find.text('Lesson 1'), findsOneWidget);
    expect(find.text('Start learning'), findsOneWidget);

    // Open the first lesson and read the first card.
    await tester.tap(find.text('Start learning'));
    await tester.pumpAndSettle();
    expect(find.text('Learn this word'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Learn this word'), findsOneWidget);
  });
}
