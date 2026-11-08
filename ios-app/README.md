# Quran Words 300 for iOS

The iPhone version of Quran Words 300: learn the 300 most common Qur'anic Arabic words. Free, offline, no ads, no tracking.

Built with Flutter. It uses the same word list (`assets/data/words_en.json`) and 30 lessons (`assets/data/lessons_en.json`) as the Android build v0.5.0+5.

## What's in the app

- **Home**: today's lesson, daily goal, words due for review, word of the day, and a collapsible learning path (6 stages of 5 lessons).
- **Lessons**: you meet each word on a card first, then answer questions both ways (Arabic → meaning, meaning → Arabic), match pairs and type a meaning. Words you get wrong come back once more before the lesson ends.
- **Practice**: due review, mistake review, weak words, favourites, mastered refresher, repeat anytime.
- **Spaced repetition**: 5 mastery levels; reviews come back after 1, 3, 7, 14 and 30 days.
- **Words**: search by Arabic (diacritics ignored), transliteration or English; filter by learned, favourites, mistakes or new. Each word has a detail page with a quiz.
- **Progress**: stats, a daily goal calendar, streaks, XP and 9 achievements.
- **Settings**: theme, dyslexia learning mode, high contrast, reduced motion, haptics, sound, daily goal, manual backup and restore, reset, the du'a request, privacy, terms and disclaimer.
- Everything is stored on the device. The app makes no network requests.

Bundle ID: `com.easyquran.words` · Version 0.5.0 (5) · iOS 15+ · Arabic font: Amiri (SIL OFL, `assets/fonts/OFL.txt`).

## Build

```bash
cd ios-app
flutter pub get
flutter test
open ios/Runner.xcworkspace        # run on a simulator or device from Xcode
flutter build ipa                  # signed App Store build (needs an Apple Developer account)
```

## CI

- **GitHub Actions** (`.github/workflows/ios.yml`): every push that changes `ios-app/` runs analyze and tests, then builds an unsigned release `.ipa` and a Simulator build. Download them from the run's *Artifacts*. An unsigned IPA can't be installed on a phone as it is. It shows the project builds, and you can re-sign it.
- **Codemagic** (`codemagic.yaml`): signed builds uploaded to TestFlight. Setup steps are at the top of that file.

## TestFlight checklist

1. In App Store Connect, create an app with bundle ID `com.easyquran.words`.
2. Add an App Store Connect API key to Codemagic, then run the `ios-testflight` workflow. You can also archive from Xcode instead (Product → Archive → Distribute).
3. App Privacy: choose **Data Not Collected**.
4. Export compliance is already answered in `Info.plist` (`ITSAppUsesNonExemptEncryption = NO`).
