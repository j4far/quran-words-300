import 'package:flutter/material.dart';

import 'data/models.dart';
import 'state/app_state.dart';
import 'ui/home_screen.dart';
import 'ui/practice_screen.dart';
import 'ui/progress_screen.dart';
import 'ui/settings_screen.dart';
import 'ui/theme.dart';
import 'ui/widgets.dart';
import 'ui/words_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final content = await Content.load();
  final state = AppState(content);
  await state.load();
  runApp(QuranWordsApp(state: state));
}

class QuranWordsApp extends StatelessWidget {
  const QuranWordsApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final s = state.settings;
          return MaterialApp(
            title: 'Quran Words 300',
            debugShowCheckedModeBanner: false,
            themeMode: s.themeMode,
            theme: buildTheme(Brightness.light, s),
            darkTheme: buildTheme(Brightness.dark, s),
            themeAnimationDuration:
                s.reducedMotion ? Duration.zero : const Duration(milliseconds: 200),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: s.reducedMotion || MediaQuery.of(context).disableAnimations,
              ),
              child: child!,
            ),
            home: const RootShell(),
          );
        },
      ),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _tab = 0;

  static const _pages = [
    HomeScreen(),
    PracticeScreen(),
    WordsScreen(),
    ProgressScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !context.appRead.settings.hideDuaRequest) {
        showDuaRequest(context, firstLaunch: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final due = context.app.dueWords.length;
    return Scaffold(
      body: IndexedStack(index: _tab, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          feedback(context);
          setState(() => _tab = i);
        },
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: due > 0,
              label: Text('$due'),
              child: const Icon(Icons.replay_outlined),
            ),
            selectedIcon: const Icon(Icons.replay_rounded),
            label: 'Practice',
          ),
          const NavigationDestination(
              icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book_rounded), label: 'Words'),
          const NavigationDestination(
              icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights_rounded), label: 'Progress'),
          const NavigationDestination(
              icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }
}
