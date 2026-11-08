import 'package:flutter/material.dart';

import 'theme.dart';

enum LegalPage {
  privacy('Privacy Policy', Icons.lock_outline_rounded, [
    'Quran Words 300 is designed to work without collecting personal data.',
    'We do not collect, sell, share, transmit or store personal data on external servers.',
    '• No account is required.\n• No login is required.\n• No advertising SDKs are used.\n• No analytics SDKs are used.\n• No tracking SDKs are used.\n• No personal data is sold or shared.\n• No internet connection is required for learning.',
    'Progress is stored locally on your iPhone. The app does not require location, contacts, camera or microphone access, and does not request internet access.',
    'This information does not leave your device unless you choose to export a local backup yourself.',
    'You can delete local learning data at any time by using Reset Progress in Settings or uninstalling the app.',
  ]),
  terms('Terms of Use', Icons.description_outlined, [
    'Quran Words 300 is provided as a free educational vocabulary aid.',
    'There is no guarantee of religious or linguistic completeness. Users should consult qualified teachers, scholars and reliable translations for deeper Qur\'anic understanding.',
    'The app may contain errors, may be updated, and the user testing version may contain bugs. The app owner is not liable for errors, omissions or decisions made from simplified learning glosses.',
  ]),
  disclaimer('Content Disclaimer', Icons.menu_book_outlined, [
    'Quran Words 300 is a free educational app designed to help users learn common Qur\'anic Arabic words.',
    'The app is intended to help learners recognise common Qur\'anic Arabic words, transliterations and simplified common English meanings.',
    'This app is an educational vocabulary aid. It is not tafsir, a fatwa, a religious ruling, or an authoritative translation of the Qur\'an. Arabic words can have different meanings depending on grammar and context.',
    'The app owner aims to keep the content useful and respectful, but does not guarantee religious, linguistic or educational completeness. Content may contain mistakes or omissions and may be updated.',
  ]);

  const LegalPage(this.title, this.icon, this.paragraphs);
  final String title;
  final IconData icon;
  final List<String> paragraphs;
}

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.page});
  final LegalPage page;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(page.title)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            for (final p in page.paragraphs)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(p, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5)),
              ),
            const SizedBox(height: 8),
            Text('Version 0.5.0',
                style: TextStyle(color: context.qw.muted, fontSize: 12.5)),
          ],
        ),
      );
}
