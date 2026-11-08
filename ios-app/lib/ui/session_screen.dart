import 'dart:math';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/quiz.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets.dart';

/// Runs a lesson or a review round, then shows the summary.
class SessionScreen extends StatefulWidget {
  const SessionScreen({
    super.key,
    required this.title,
    required this.steps,
    this.lesson,
    this.isReview = false,
    this.rebuild,
  });

  final String title;
  final List<QuizStep> steps;
  final Lesson? lesson;
  final bool isReview;

  /// Builds a fresh set of steps for "Repeat".
  final List<QuizStep> Function()? rebuild;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  late final List<QuizStep> _queue = [...widget.steps];
  late final QuizBuilder _builder = QuizBuilder(context.appRead.content);
  final Set<int> _requeued = {};
  final Set<int> _practised = {};
  int _index = 0;
  int _correct = 0;
  int _graded = 0;
  int _xp = 0;

  // Per-step answer state
  bool _answered = false;
  bool _wasCorrect = false;
  Word? _chosen;
  String _typed = '';
  final _typeCtrl = TextEditingController();

  // Match state
  Word? _pickLeft;
  Word? _pickRight;
  final Set<int> _matched = {};
  final Set<int> _matchMissed = {};
  int? _flashWrongLeft;
  int? _flashWrongRight;
  List<Word> _rightOrder = const [];
  String? _matchHint;

  QuizStep get _step => _queue[_index];

  @override
  void initState() {
    super.initState();
    _prepareStep();
  }

  @override
  void dispose() {
    _typeCtrl.dispose();
    super.dispose();
  }

  void _prepareStep() {
    _answered = false;
    _wasCorrect = false;
    _chosen = null;
    _typed = '';
    _typeCtrl.clear();
    _pickLeft = null;
    _pickRight = null;
    _matched.clear();
    _matchMissed.clear();
    _matchHint = null;
    final s = _step;
    if (s is MatchStep) _rightOrder = [...s.words]..shuffle(Random());
    if (s is LearnStep) context.appRead.introduce(s.w.id);
  }

  void _grade(Word w, bool correct) {
    final app = context.appRead;
    _graded++;
    _practised.add(w.id);
    if (correct) _correct++;
    _xp += app.recordAnswer(w.id, correct, isReview: widget.isReview);
    if (!correct && _requeued.add(w.id)) {
      // One gentle retry later in the session.
      _queue.add(Random().nextBool()
          ? _builder.meaningChoice(w)
          : _builder.arabicChoice(w));
    }
  }

  void _choose(Word answer, Word picked) {
    if (_answered) return;
    final ok = picked.id == answer.id;
    feedback(context, correct: ok);
    setState(() {
      _answered = true;
      _wasCorrect = ok;
      _chosen = picked;
      _grade(answer, ok);
    });
  }

  void _checkTyped(Word w) {
    if (_answered || _typeCtrl.text.trim().isEmpty) return;
    final ok = checkTyped(w, _typeCtrl.text);
    feedback(context, correct: ok);
    setState(() {
      _answered = true;
      _wasCorrect = ok;
      _typed = _typeCtrl.text.trim();
      _grade(w, ok);
    });
  }

  void _tapMatch(MatchStep s, Word w, {required bool left}) {
    if (_matched.contains(w.id)) return;
    setState(() {
      if (left) {
        _pickLeft = w;
      } else {
        _pickRight = w;
      }
      _flashWrongLeft = null;
      _flashWrongRight = null;
      final l = _pickLeft, r = _pickRight;
      if (l == null || r == null) {
        feedback(context);
        return;
      }
      if (l.id == r.id) {
        feedback(context, correct: true);
        _matched.add(l.id);
        _matchHint = null;
        if (_matched.length == s.words.length) {
          for (final w in s.words) {
            _grade(w, !_matchMissed.contains(w.id));
          }
          _answered = true;
          _wasCorrect = _matchMissed.isEmpty;
          _matchHint = 'All pairs matched. Tap Next to continue.';
        } else {
          _matchHint = '${s.words.length - _matched.length} left. Keep matching.';
        }
      } else {
        feedback(context, correct: false);
        _matchMissed
          ..add(l.id)
          ..add(r.id);
        _flashWrongLeft = l.id;
        _flashWrongRight = r.id;
        _matchHint = 'Not quite. Try that pair again.';
      }
      _pickLeft = null;
      _pickRight = null;
    });
  }

  void _next() {
    feedback(context);
    if (_index + 1 >= _queue.length) {
      _finish();
      return;
    }
    setState(() {
      _index++;
      _prepareStep();
    });
  }

  void _finish() {
    final app = context.appRead;
    final result = app.finishSession(
      correct: _correct,
      total: _graded,
      xpEarned: _xp,
      wordsPractised: _practised.length,
      lesson: widget.lesson,
    );
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => SessionSummary(
        result: result,
        title: widget.title,
        onRepeat: widget.rebuild == null
            ? null
            : () => SessionScreen(
                  title: widget.title,
                  steps: widget.rebuild!(),
                  lesson: widget.lesson,
                  isReview: widget.isReview,
                  rebuild: widget.rebuild,
                ),
      ),
    ));
  }

  Future<bool> _confirmExit() async {
    if (_index == 0 && !_answered) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave this session?'),
        content: const Text('Answers so far are saved, but this session will not be completed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep going')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
        ],
      ),
    );
    if (leave == true && mounted) {
      // Persist answers given so far.
      context.appRead.finishPartial(_practised.length, _xp);
    }
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_index + (_answered ? 1 : 0)) / _queue.length;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmExit()) nav.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              final nav = Navigator.of(context);
              if (await _confirmExit()) nav.pop();
            },
          ),
          title: Semantics(
            label: 'Lesson progress',
            value: '${(progress * 100).round()}%',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: progress),
                duration: motion(context, 300),
                builder: (_, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 10,
                  backgroundColor: context.qw.line,
                ),
              ),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(children: [
                Icon(Icons.bolt_rounded, color: context.qw.gold, size: 20),
                Text('$_xp', style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ),
          ],
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: motion(context, 220),
            child: KeyedSubtree(
              key: ValueKey(_index),
              child: _buildStep(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) => switch (_step) {
        LearnStep(:final w) => _learn(context, w),
        MeaningChoiceStep(:final w, :final options) => _choice(
            context,
            w,
            options,
            prompt: 'Choose the common meaning',
            question: _bigArabic(context, w),
            label: (o) => Text(o.meaning, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            describe: (o) => o.meaning,
          ),
        ArabicChoiceStep(:final w, :final options) => _choice(
            context,
            w,
            options,
            prompt: 'Choose the Arabic word',
            question: Text(w.meaning,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            label: (o) => ArabicText(o.arabic, size: 30),
            describe: (o) => o.arabic,
          ),
        MatchStep() => _match(context, _step as MatchStep),
        TypeStep(:final w) => _type(context, w),
      };

  Widget _bigArabic(BuildContext context, Word w) => Column(
        children: [
          ArabicText(w.arabic, size: 56),
          if (context.app.settings.showTransliteration)
            Text(w.transliteration,
                style: TextStyle(
                    color: context.qw.muted, fontStyle: FontStyle.italic, fontSize: 16)),
        ],
      );

  Widget _scaffoldStep(BuildContext context,
      {required String prompt, required List<Widget> children, required Widget bottom}) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            children: [
              Text(prompt,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: context.qw.muted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
        bottom,
      ],
    );
  }

  Widget _learn(BuildContext context, Word w) {
    final t = Theme.of(context).textTheme;
    return _scaffoldStep(
      context,
      prompt: 'Learn this word',
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          decoration: BoxDecoration(
            color: context.qw.panel,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.qw.line),
          ),
          child: Column(
            children: [
              _bigArabic(context, w),
              const SizedBox(height: 18),
              Text(w.meaning,
                  textAlign: TextAlign.center,
                  style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              if (w.alsoMeanings.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Also: ${w.alsoMeanings.join(', ')}',
                    textAlign: TextAlign.center,
                    style: t.bodyMedium?.copyWith(color: context.qw.muted)),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  Chip(label: Text(w.partOfSpeech), visualDensity: VisualDensity.compact),
                  Chip(label: Text('Rank ${w.frequencyRank}'), visualDensity: VisualDensity.compact),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Read the meaning first. The next cards will check whether you recognise it.',
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(color: context.qw.muted)),
      ],
      bottom: _bottomBar(context, child: FilledButton(onPressed: _next, child: const Text('Continue'))),
    );
  }

  Widget _choice(
    BuildContext context,
    Word answer,
    List<Word> options, {
    required String prompt,
    required Widget question,
    required Widget Function(Word) label,
    required String Function(Word) describe,
  }) {
    return _scaffoldStep(
      context,
      prompt: prompt,
      children: [
        const SizedBox(height: 8),
        question,
        const SizedBox(height: 28),
        for (final o in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _OptionButton(
              state: !_answered
                  ? _OptState.idle
                  : o.id == answer.id
                      ? _OptState.correct
                      : o.id == _chosen?.id
                          ? _OptState.wrong
                          : _OptState.dim,
              onTap: () => _choose(answer, o),
              semantics: describe(o),
              child: label(o),
            ),
          ),
      ],
      bottom: _answered
          ? _feedbackBar(context, answer,
              chosenText: _chosen == null || _wasCorrect ? null : describe(_chosen!))
          : const SizedBox.shrink(),
    );
  }

  Widget _match(BuildContext context, MatchStep s) {
    Widget cell(Word w, {required bool left}) {
      final matched = _matched.contains(w.id);
      final picked = left ? _pickLeft?.id == w.id : _pickRight?.id == w.id;
      final wrong = left ? _flashWrongLeft == w.id : _flashWrongRight == w.id;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _OptionButton(
          state: matched
              ? _OptState.correct
              : wrong
                  ? _OptState.wrong
                  : picked
                      ? _OptState.selected
                      : _OptState.idle,
          onTap: matched ? null : () => _tapMatch(s, w, left: left),
          semantics: left ? w.arabic : w.meaning,
          compact: true,
          child: left
              ? ArabicText(w.arabic, size: 26)
              : Text(w.meaning,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      );
    }

    return _scaffoldStep(
      context,
      prompt: 'Match each Arabic word to its meaning',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Column(children: [for (final w in s.words) cell(w, left: true)])),
            const SizedBox(width: 12),
            Expanded(child: Column(children: [for (final w in _rightOrder) cell(w, left: false)])),
          ],
        ),
        if (_matchHint != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_matchHint!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: _matchHint!.startsWith('Not') ? context.qw.error : context.qw.muted,
                    fontWeight: FontWeight.w600)),
          ),
      ],
      bottom: _answered
          ? _bottomBar(context, child: FilledButton(onPressed: _next, child: const Text('Next')))
          : const SizedBox.shrink(),
    );
  }

  Widget _type(BuildContext context, Word w) {
    return _scaffoldStep(
      context,
      prompt: 'Type a common meaning',
      children: [
        const SizedBox(height: 8),
        _bigArabic(context, w),
        const SizedBox(height: 28),
        TextField(
          controller: _typeCtrl,
          enabled: !_answered,
          autofocus: false,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _checkTyped(w),
          decoration: InputDecoration(
            hintText: 'English meaning',
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ],
      bottom: _answered
          ? _feedbackBar(context, w, chosenText: _wasCorrect ? null : _typed)
          : _bottomBar(context,
              child: FilledButton(
                onPressed: _typeCtrl.text.trim().isEmpty ? null : () => _checkTyped(w),
                child: const Text('Check answer'),
              )),
    );
  }

  Widget _bottomBar(BuildContext context, {required Widget child, Color? color}) => Container(
        width: double.infinity,
        color: color,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: child,
      );

  Widget _feedbackBar(BuildContext context, Word answer, {String? chosenText}) {
    final ok = _wasCorrect;
    final c = ok ? context.qw.success : context.qw.error;
    final t = Theme.of(context).textTheme;
    return _bottomBar(
      context,
      color: c.withValues(alpha: .10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(ok ? Icons.check_circle_rounded : Icons.info_rounded, color: c),
            const SizedBox(width: 8),
            Text(ok ? 'Correct' : 'Not quite.',
                style: t.titleMedium?.copyWith(color: c, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          if (!ok && chosenText != null)
            Text('You chose "$chosenText".', style: t.bodyMedium),
          if (!ok)
            Text.rich(TextSpan(children: [
              const TextSpan(text: 'Correct: '),
              TextSpan(
                  text: '${answer.arabic}  ${answer.transliteration} - ${answer.meaning}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ])),
          if (ok)
            Text('Good recognition. This word will return later for review.',
                style: t.bodyMedium),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: c, foregroundColor: Colors.white),
              onPressed: _next,
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}

enum _OptState { idle, selected, correct, wrong, dim }

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.state,
    required this.onTap,
    required this.child,
    required this.semantics,
    this.compact = false,
  });

  final _OptState state;
  final VoidCallback? onTap;
  final Widget child;
  final String semantics;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final qw = context.qw;
    final (border, fill) = switch (state) {
      _OptState.idle => (qw.line, cs.surface),
      _OptState.selected => (cs.primary, cs.primary.withValues(alpha: .10)),
      _OptState.correct => (qw.success, qw.success.withValues(alpha: .12)),
      _OptState.wrong => (qw.error, qw.error.withValues(alpha: .10)),
      _OptState.dim => (qw.line, cs.surface.withValues(alpha: .5)),
    };
    return Semantics(
      button: true,
      label: semantics,
      child: AnimatedContainer(
        duration: motion(context, 160),
        constraints: BoxConstraints(minHeight: compact ? 64 : 60),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: state == _OptState.idle ? 1.5 : 2),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Opacity(
              opacity: state == _OptState.dim ? .55 : 1,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 6 : 10),
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SessionSummary extends StatelessWidget {
  const SessionSummary({super.key, required this.result, required this.title, this.onRepeat});

  final SessionResult result;
  final String title;
  final Widget Function()? onRepeat;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isLesson = result.lesson != null;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          children: [
            Icon(result.perfect ? Icons.workspace_premium_rounded : Icons.celebration_rounded,
                size: 72, color: context.qw.gold),
            const SizedBox(height: 16),
            Text(isLesson ? 'Lesson complete' : 'Review complete',
                textAlign: TextAlign.center,
                style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(title,
                textAlign: TextAlign.center,
                style: t.bodyLarge?.copyWith(color: context.qw.muted)),
            const SizedBox(height: 28),
            Row(children: [
              Expanded(child: StatTile(value: '+${result.xp}', label: 'XP earned', icon: Icons.bolt_rounded)),
              const SizedBox(width: 12),
              Expanded(child: StatTile(value: '${result.accuracy}%', label: 'Accuracy', icon: Icons.track_changes_rounded)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: StatTile(value: '${result.correct}/${result.total}', label: 'Correct answers', icon: Icons.check_rounded)),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  value: '${context.app.currentStreak}',
                  label: 'Day streak',
                  icon: Icons.local_fire_department_rounded,
                ),
              ),
            ]),
            if (result.newAchievements.isNotEmpty) ...[
              const SectionTitle('Unlocked achievement'),
              for (final a in result.newAchievements)
                Card(
                  child: ListTile(
                    leading: Icon(a.icon, color: context.qw.gold),
                    title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(a.description),
                  ),
                ),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isLesson ? 'Back to path' : 'Done'),
            ),
            if (onRepeat != null) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.pushReplacement(
                    context, MaterialPageRoute(builder: (_) => onRepeat!())),
                child: Text(isLesson ? 'Repeat lesson' : 'Repeat anytime'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
