# Sonata Diagnostic — IPA v0.3 source

This is the native iPhone implementation of the Sonata Diagnostic Premium reference build.

## What is real in v0.3
- Native SwiftUI iPhone app; the reference web page is not embedded in a WebView
- Native CoreBluetooth BLE connection to **OBDLink CX**
- OBDLink CX UART service support: FFF0 / FFF1 / FFF2
- Standard OBD-II initialization
- Reads VIN (Mode 09), active engine DTCs (Mode 03), RPM, speed, coolant temperature, engine load, throttle, intake-air temperature, STFT, LTFT, fuel level and adapter voltage when the vehicle supports them
- Sends those actual values into the premium UI
- If actual P200A or P0562 is returned, the app selects the matching plain-English diagnostic explanation
- In live/real mode, Hyundai coding/settings stay disabled until their exact module commands are verified

## What remains demo/research
- Hyundai enhanced BCM / Smart Key / ABS / SRS scanning
- intake-runner commanded/reported enhanced PIDs
- comfort-setting writes
- code clearing
- CarPlay

Those are intentionally not guessed.

## Free IPA build without owning a modern Mac
The included GitHub Actions workflow builds an **unsigned physical-device IPA** on a GitHub macOS runner. It is intended to be re-signed/sideloaded with the user's own free Apple development identity using a tool such as SideStore.

1. Put this project in a GitHub repository.
2. Open **Actions → Build unsigned Sonata Diagnostic IPA → Run workflow**.
3. Download the `SonataDiagnostic-unsigned-ipa` artifact.
4. Extract the artifact ZIP to get `SonataDiagnostic-unsigned.ipa`.
5. Sideload/re-sign it with your own Apple ID workflow.

The app requests Bluetooth permission the first time it scans for the OBDLink CX.

## Safety model
Version 0.3 is read-only. It does not transmit Hyundai module configuration writes, immobilizer commands, SRS/ABS coding, or engine calibration commands.

## v0.2 presentation rebuild
- Compact custom Home / Live / Diagnostics / Settings / Vehicle navigation that respects the safe area
- Premium Sonata hero and top-down vehicle artwork
- Dynamic Real Mode screens that render only returned OBD values and never substitute demo data
- Three-level fault detail: Explain to Me, Readings, and Mechanic Details
- Context-aware expected ranges, explicit unavailable states, saved local reports, and locked Hyundai settings
- v0.2.1 increases type, touch targets, cards, navigation, and vehicle artwork for the 390-point iPhone 13 baseline and larger iPhones
- v0.2.2 adds a real launch storyboard and full-window root sizing to prevent legacy letterboxing on modern iPhones
- v0.3.0 ports the supplied Premium Reference Build into the native app: standalone connect screen, exact supplied Sonata/OBD artwork, compact connected header, four-tab navigation, full menu drawer, scan sheet, scenario-aware demo, 3D Vehicle, Reports, Maintenance, Data Logging, Vehicle Profile, and About
