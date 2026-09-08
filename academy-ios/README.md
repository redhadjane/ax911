# HOP Academy for iPhone and iPad

A native SwiftUI study companion for personal ISTQB CTFL preparation. Requires iOS/iPadOS 17 or later. It bundles the HOP Academy question library and saves progress on the device, so studying works without a server or internet connection.

## Study flow

- Start with the 64-question diagnostic, one question per learning objective, or a five-question practice session.
- Answer using your HOP experience, choose Guess / Unsure / Confident, then see a concise explanation and the formal terminology.
- Wrong or uncertain answers trigger another scenario for that concept. Spaced review brings weaker concepts back sooner.
- Vocabulary practice tracks terminology separately from scenario understanding.
- Timed mocks contain 40 original questions: 8 / 6 / 4 / 11 / 9 / 2 by chapter and 8 / 24 / 8 at K1 / K2 / K3. The official passing threshold is 26/40. The Academy readiness target is two unseen mocks at 34/40 or better plus objective and chapter coverage.
- Mocks allow flags, navigation and changing answers. Answers remain hidden until submission. A saved wall-clock deadline continues through screen lock, backgrounding and relaunch; use 60 minutes or the applicable 75-minute extension.

All 168 questions and 64 concept cards are available offline. Official-source links open online when selected. This is an independent, original practice bank, not real examination questions or an accredited course. A finite bank can run out of unseen questions for an exam group; mixed practice remains available and is excluded from unseen readiness.

## Comfort and devices

Native iPhone tabs and an iPad sidebar; layouts adapt to available width. Dark, light and system appearance; Dynamic Type; optional answer haptics; Reduce Motion support. Hardware keyboard: 1–4 selects, Return checks/continues, R flags. Scroll longer scenarios naturally; the main action stays at the bottom.

## Data and backups

No HOP login or server connection is required. Progress is stored in Application Support/HOPAcademy/progress-v1.json, written atomically with iOS file protection. The previous save is retained for recovery. Unreadable progress is preserved and requires a compatible import if no valid backup exists. Free-text reasoning is saved for personal review and is not graded by AI.

Settings → Export progress backup saves JSON to Files or the share destinations offered by iOS. Move the file to your other device and choose Import a progress backup. Import requires confirmation, validates catalog/version/references/answers, and replaces that device's history rather than merging it. No automatic iCloud or HOP-web synchronization is implemented. Export before uninstalling or changing signing identity.

## Build

The deterministic Xcode project is committed. On macOS with Xcode:

```sh
node scripts/check-source.cjs
swift test
bash scripts/build-unsigned-ipa.sh
```

The output is build/HOP-Academy-iPhone-iPad-1.0.0.ipa. The app bundle is com.houseofpizza.academy.ios, version 1.0.0 (1), arm64, device families 1 and 2. The IPA is unsigned and must be signed by your sideloading tool, or built with your Apple development team in Xcode. It is not an App Store/TestFlight release.

The HOP Academy workflow in .github/workflows/hop-academy-ios.yml builds on macOS, exercises the Foundation learning engine, archives the device app, captures iPhone/iPad simulator views, verifies saved-exam relaunch, and runs native interaction tests on iPhone. `scripts/verify-ipa.py` validates the downloaded IPA contents. `node scripts/configure-project.cjs` regenerates the project after deliberate source-list changes.

## Content attribution

Targets CTFL 4.0, syllabus 4.0.1, as researched on 2026-09-07. Source titles, URLs, versions and objective references are bundled in Resources/catalog.json and visible in Sources. Syllabus learning-objective excerpts are acknowledged to ISTQB and the syllabus authors for personal, non-commercial study. Original Academy questions and explanations are separate from official sample examinations. Full official PDFs are not repackaged.

The native app is isolated in academy-ios. Existing scheduling, employee, customer, manager, database and operational API code is not needed by this target.
