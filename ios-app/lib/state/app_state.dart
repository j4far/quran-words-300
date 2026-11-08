import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData, Icons, ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';

/// Spaced-repetition record for one word. Stored on device only.
class WordProgress {
  WordProgress({
    this.mastery = 0,
    this.correct = 0,
    this.wrong = 0,
    this.learnedAt,
    this.lastSeen,
    this.due,
    this.inMistakes = false,
  });

  /// 0 = not learned, 1..5 = increasing mastery. 5 = mastered.
  int mastery;
  int correct;
  int wrong;
  DateTime? learnedAt;
  DateTime? lastSeen;
  DateTime? due;
  bool inMistakes;

  bool get learned => learnedAt != null;
  bool get mastered => mastery >= AppState.maxMastery;

  Map<String, dynamic> toJson() => {
        'm': mastery,
        'c': correct,
        'w': wrong,
        if (learnedAt != null) 'l': learnedAt!.toIso8601String(),
        if (lastSeen != null) 's': lastSeen!.toIso8601String(),
        if (due != null) 'd': due!.toIso8601String(),
        if (inMistakes) 'x': true,
      };

  factory WordProgress.fromJson(Map<String, dynamic> j) => WordProgress(
        mastery: (j['m'] as int?) ?? 0,
        correct: (j['c'] as int?) ?? 0,
        wrong: (j['w'] as int?) ?? 0,
        learnedAt: _date(j['l']),
        lastSeen: _date(j['s']),
        due: _date(j['d']),
        inMistakes: (j['x'] as bool?) ?? false,
      );
}

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class Achievement {
  const Achievement(this.id, this.title, this.description, this.icon);
  final String id;
  final String title;
  final String description;
  final IconData icon;
}

const achievements = <Achievement>[
  Achievement('first_lesson', 'First Lesson', 'Complete your first lesson.', Icons.school_rounded),
  Achievement('perfect_lesson', 'Perfect Lesson', 'Complete a lesson without mistakes.', Icons.star_rounded),
  Achievement('streak_7', '7-Day Streak', 'Study for seven days in a row.', Icons.local_fire_department_rounded),
  Achievement('streak_30', '30-Day Streak', 'Study for thirty days in a row.', Icons.whatshot_rounded),
  Achievement('words_50', '50 Words', 'Learn 50 words.', Icons.menu_book_rounded),
  Achievement('words_100', '100 Words', 'Learn 100 words.', Icons.auto_stories_rounded),
  Achievement('words_200', '200 Words', 'Learn 200 words.', Icons.emoji_events_rounded),
  Achievement('words_300', '300 Words', 'Learn all 300 words.', Icons.workspace_premium_rounded),
  Achievement('review_champion', 'Review Champion', 'Review at least 40 cards.', Icons.verified_rounded),
];

class AppSettings {
  ThemeMode themeMode = ThemeMode.system;
  bool highContrast = false;
  bool reducedMotion = false;
  bool dyslexiaMode = false;
  bool haptics = true;
  bool sound = false;
  bool showTransliteration = true;
  int dailyGoal = 10;
  bool hideDuaRequest = false;

  Map<String, dynamic> toJson() => {
        'theme': themeMode.name,
        'hc': highContrast,
        'rm': reducedMotion,
        'dys': dyslexiaMode,
        'hap': haptics,
        'snd': sound,
        'tr': showTransliteration,
        'goal': dailyGoal,
        'hideDua': hideDuaRequest,
      };

  void apply(Map<String, dynamic> j) {
    themeMode = ThemeMode.values.firstWhere((m) => m.name == j['theme'],
        orElse: () => ThemeMode.system);
    highContrast = (j['hc'] as bool?) ?? false;
    reducedMotion = (j['rm'] as bool?) ?? false;
    dyslexiaMode = (j['dys'] as bool?) ?? false;
    haptics = (j['hap'] as bool?) ?? true;
    sound = (j['snd'] as bool?) ?? false;
    showTransliteration = (j['tr'] as bool?) ?? true;
    dailyGoal = (j['goal'] as int?) ?? 10;
    hideDuaRequest = (j['hideDua'] as bool?) ?? false;
  }
}

/// Outcome of finishing a lesson or review session.
class SessionResult {
  SessionResult({
    required this.correct,
    required this.total,
    required this.xp,
    required this.newAchievements,
    this.lesson,
  });
  final int correct;
  final int total;
  final int xp;
  final List<Achievement> newAchievements;
  final Lesson? lesson;

  int get accuracy => total == 0 ? 100 : (correct * 100 / total).round();
  bool get perfect => correct == total;
}

/// Single source of truth for progress and settings. Everything is stored
/// locally with SharedPreferences; nothing leaves the device.
class AppState extends ChangeNotifier {
  AppState(this.content, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  static const maxMastery = 5;
  static const backupVersion = 1;
  static const _storageKey = 'qw300.state.v1';

  /// Days until next review, indexed by mastery level after a correct answer.
  static const intervals = [0, 1, 3, 7, 14, 30];

  final Content content;
  final DateTime Function() _clock;
  SharedPreferences? _prefs;

  final Map<int, WordProgress> progress = {};
  final Set<int> favourites = {};
  final Set<String> completedLessons = {};
  final Set<String> unlockedAchievements = {};
  final Map<String, int> dailyCounts = {}; // yyyy-mm-dd -> words practised
  final AppSettings settings = AppSettings();
  int xp = 0;
  int reviewsDone = 0;
  int answersCorrect = 0;
  int answersTotal = 0;
  int longestStreak = 0;
  int? stageExpanded; // UI hint only, not persisted

  DateTime get now => _clock();

  // ---------------------------------------------------------------- loading

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_storageKey);
    if (raw != null) {
      try {
        _fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('Could not read saved progress: $e');
      }
    }
    notifyListeners();
  }

  Future<void> _save() async {
    await _prefs?.setString(_storageKey, jsonEncode(_toJson()));
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  Map<String, dynamic> _toJson() => {
        'v': backupVersion,
        'progress': {
          for (final e in progress.entries) '${e.key}': e.value.toJson()
        },
        'fav': favourites.toList()..sort(),
        'lessons': completedLessons.toList()..sort(),
        'ach': unlockedAchievements.toList()..sort(),
        'daily': dailyCounts,
        'settings': settings.toJson(),
        'xp': xp,
        'reviews': reviewsDone,
        'ok': answersCorrect,
        'all': answersTotal,
        'longest': longestStreak,
      };

  void _fromJson(Map<String, dynamic> j) {
    _clear();
    final p = (j['progress'] as Map?) ?? const {};
    for (final e in p.entries) {
      final id = int.tryParse('${e.key}');
      if (id != null && content.wordById.containsKey(id)) {
        progress[id] = WordProgress.fromJson(
            (e.value as Map).cast<String, dynamic>());
      }
    }
    favourites.addAll(((j['fav'] as List?) ?? const []).cast<int>());
    completedLessons.addAll(((j['lessons'] as List?) ?? const []).cast<String>());
    unlockedAchievements.addAll(((j['ach'] as List?) ?? const []).cast<String>());
    ((j['daily'] as Map?) ?? const {}).forEach((k, v) {
      if (v is int) dailyCounts['$k'] = v;
    });
    settings.apply(((j['settings'] as Map?) ?? const {}).cast<String, dynamic>());
    xp = (j['xp'] as int?) ?? 0;
    reviewsDone = (j['reviews'] as int?) ?? 0;
    answersCorrect = (j['ok'] as int?) ?? 0;
    answersTotal = (j['all'] as int?) ?? 0;
    longestStreak = (j['longest'] as int?) ?? 0;
  }

  void _clear() {
    progress.clear();
    favourites.clear();
    completedLessons.clear();
    unlockedAchievements.clear();
    dailyCounts.clear();
    xp = 0;
    reviewsDone = 0;
    answersCorrect = 0;
    answersTotal = 0;
    longestStreak = 0;
  }

  // ---------------------------------------------------------------- backup

  String createBackup() =>
      base64.encode(utf8.encode(jsonEncode({'app': 'quran-words-300', ..._toJson()})));

  /// Throws [FormatException] on unreadable or unsupported text.
  Future<void> restoreBackup(String text) async {
    final cleaned = text.replaceAll(RegExp(r'\s'), '');
    Map<String, dynamic> j;
    try {
      j = jsonDecode(utf8.decode(base64.decode(cleaned))) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('This does not look like backup text.');
    }
    if (j['v'] != backupVersion) {
      throw const FormatException('Unsupported backup version.');
    }
    _fromJson(j);
    _changed();
  }

  Future<void> resetProgress() async {
    final hideDua = settings.hideDuaRequest;
    _clear();
    final fresh = AppSettings()..hideDuaRequest = hideDua;
    settings.apply(fresh.toJson());
    _changed();
  }

  void updateSettings(void Function(AppSettings s) change) {
    change(settings);
    _changed();
  }

  // ---------------------------------------------------------------- queries

  WordProgress of(int id) => progress[id] ?? WordProgress();

  bool isFavourite(int id) => favourites.contains(id);

  void toggleFavourite(int id) {
    if (!favourites.remove(id)) favourites.add(id);
    _changed();
  }

  Iterable<Word> get learnedWords =>
      content.words.where((w) => of(w.id).learned);

  int get learnedCount => progress.values.where((p) => p.learned).length;
  int get masteredCount => progress.values.where((p) => p.mastered).length;

  List<Word> get dueWords {
    final t = now;
    final list = learnedWords
        .where((w) => !(of(w.id).due ?? t).isAfter(t))
        .toList()
      ..sort((a, b) => (of(a.id).due ?? t).compareTo(of(b.id).due ?? t));
    return list;
  }

  List<Word> get mistakeWords =>
      content.words.where((w) => of(w.id).inMistakes).toList();

  List<Word> get weakWords {
    final list = learnedWords.where((w) => !of(w.id).mastered).toList()
      ..sort((a, b) {
        final pa = of(a.id), pb = of(b.id);
        final c = pa.mastery.compareTo(pb.mastery);
        return c != 0 ? c : (pb.wrong - pa.wrong);
      });
    return list;
  }

  List<Word> get masteredWords =>
      learnedWords.where((w) => of(w.id).mastered).toList();

  List<Word> get favouriteWords =>
      content.words.where((w) => favourites.contains(w.id)).toList();

  bool isLessonComplete(Lesson l) => completedLessons.contains(l.id);

  bool isLessonUnlocked(Lesson l) {
    final i = content.lessons.indexOf(l);
    return i <= 0 || isLessonComplete(content.lessons[i - 1]);
  }

  /// The first lesson not yet completed, or null when all 30 are done.
  Lesson? get nextLesson {
    for (final l in content.lessons) {
      if (!isLessonComplete(l)) return l;
    }
    return null;
  }

  int get currentStageIndex {
    final next = nextLesson;
    if (next == null) return content.stages.length - 1;
    return content.lessons.indexOf(next) ~/ Content.lessonsPerStage;
  }

  int lessonLearnedCount(Lesson l) =>
      l.wordIds.where((id) => of(id).learned).length;

  /// Deterministic word of the day across all 300 words.
  Word get wordOfTheDay {
    final t = now;
    final dayNumber = DateTime.utc(t.year, t.month, t.day)
            .difference(DateTime.utc(2024, 1, 1))
            .inDays;
    return content.words[dayNumber % content.words.length];
  }

  int get todayCount => dailyCounts[dayKey(now)] ?? 0;
  bool get goalMetToday => todayCount >= settings.dailyGoal;

  bool goalMetOn(DateTime d) => (dailyCounts[dayKey(d)] ?? 0) >= settings.dailyGoal;
  bool studiedOn(DateTime d) => (dailyCounts[dayKey(d)] ?? 0) > 0;

  /// Consecutive days with any study, ending today (or yesterday if today
  /// has no study yet, so the streak isn't shown as broken mid-day).
  int get currentStreak {
    var d = DateTime(now.year, now.month, now.day);
    if (!studiedOn(d)) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (studiedOn(d)) {
      n++;
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return n;
  }

  int get accuracy =>
      answersTotal == 0 ? 0 : (answersCorrect * 100 / answersTotal).round();

  // ---------------------------------------------------------------- recording

  /// Marks a word as seen on its introduction card.
  void introduce(int id) {
    final p = progress.putIfAbsent(id, WordProgress.new);
    p.lastSeen = now;
  }

  /// Records an answer; returns XP earned. Does not notify; call
  /// [finishSession] at the end.
  int recordAnswer(int id, bool correct, {required bool isReview}) {
    final p = progress.putIfAbsent(id, WordProgress.new);
    final t = now;
    answersTotal++;
    p.lastSeen = t;
    if (correct) {
      answersCorrect++;
      p.correct++;
      if (!p.learned) {
        p.learnedAt = t;
        p.mastery = max(p.mastery, 1);
      } else {
        p.mastery = min(maxMastery, p.mastery + 1);
      }
      if (p.mastery >= 2) p.inMistakes = false;
      p.due = t.add(Duration(days: intervals[p.mastery]));
      if (isReview) reviewsDone++;
      return isReview ? 5 : 10;
    } else {
      p.wrong++;
      p.inMistakes = true;
      if (p.learned) p.mastery = max(1, p.mastery - 2);
      p.due = t; // due again now
      if (isReview) reviewsDone++;
      return 0;
    }
  }

  void addPractised(int words) {
    final k = dayKey(now);
    dailyCounts[k] = (dailyCounts[k] ?? 0) + words;
    longestStreak = max(longestStreak, currentStreak);
  }

  /// Saves answers from a session the learner left early.
  void finishPartial(int wordsPractised, int xpEarned) {
    xp += xpEarned;
    if (wordsPractised > 0) addPractised(wordsPractised);
    _checkAchievements();
    _changed();
  }

  SessionResult finishSession({
    required int correct,
    required int total,
    required int xpEarned,
    required int wordsPractised,
    Lesson? lesson,
  }) {
    var bonus = 0;
    if (lesson != null) {
      // A lesson completes once all of its words have been learned.
      for (final id in lesson.wordIds) {
        final p = progress.putIfAbsent(id, WordProgress.new);
        if (!p.learned) {
          p.learnedAt = now;
          p.mastery = 1;
          p.due = now.add(const Duration(days: 1));
        }
      }
      if (!completedLessons.contains(lesson.id)) bonus += 20;
      completedLessons.add(lesson.id);
      if (correct == total) bonus += 10;
    }
    xp += xpEarned + bonus;
    addPractised(wordsPractised);
    final unlocked = _checkAchievements(
        perfectLesson: lesson != null && correct == total);
    _changed();
    return SessionResult(
      correct: correct,
      total: total,
      xp: xpEarned + bonus,
      newAchievements: unlocked,
      lesson: lesson,
    );
  }

  List<Achievement> _checkAchievements({bool perfectLesson = false}) {
    final learned = learnedCount;
    final streak = currentStreak;
    final earned = <String>{
      if (completedLessons.isNotEmpty) 'first_lesson',
      if (perfectLesson) 'perfect_lesson',
      if (streak >= 7) 'streak_7',
      if (streak >= 30) 'streak_30',
      if (learned >= 50) 'words_50',
      if (learned >= 100) 'words_100',
      if (learned >= 200) 'words_200',
      if (learned >= 300) 'words_300',
      if (reviewsDone >= 40) 'review_champion',
    };
    final fresh = earned.difference(unlockedAchievements);
    unlockedAchievements.addAll(fresh);
    return achievements.where((a) => fresh.contains(a.id)).toList();
  }
}
