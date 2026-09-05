# HOP Employee for iPhone

Native SwiftUI client for the existing HOP system. iOS 17+, Apple SDKs only, no WebView or bundled business records. This is a separate testing client; it does not replace the employee website or manager desktop.

## Cloud build

The `hop-employee-ios` branch in `redhadjane/ax911` contains this project independently of Sonata. The HOP workflow runs on changes to `ios/` on this branch, tests the Foundation contracts, and compiles an unsigned physical-device IPA on macOS. Simulator tests are optional and off by default.

Open this branch's **HOP Employee iOS build** run in GitHub Actions. After a successful build, download `HOPEmployee-unsigned-ipa`, extract the ZIP, and import `HOPEmployee-unsigned.ipa` into SideStore. The IPA requires re-signing for your Apple account before installation. No Apple credentials or signing keys are needed by this repository.

Build success is not device acceptance. Test with an authorized pilot account before staff distribution. Use real published schedules for read-only comparisons, and only designated test records for writes. Matching backend updates must be reviewed and deployed separately for new integration routes; this repository does not deploy the backend.

## Local Mac build

```bash
cd ios
swift test
bash scripts/build-ipa.sh
```

Full Xcode with the iPhoneOS SDK is required. The build prepares the app icon, archives for arm64 iPhoneOS, validates the Payload ZIP, and prints the IPA SHA-256. Windows cannot compile the Apple target.

## Scope and privacy

- Today, published schedules, requests, availability, notifications, profile, shift tasks, parties, and staff loyalty workflows.
- HTTPS API client; private Keychain sessions; account-scoped, labeled published schedule cache.
- No employee records, customer records, backend configuration, credentials, or internal audit reports in this source distribution.
- Notifications refresh while active. Native background APNs is not implemented or claimed; existing browser push remains separate.
- `Tests/HOPCoreTests.swift` runs through Swift Package Manager. App-hosted API transport tests require the optional Xcode simulator run and use intercepted test traffic.
- Signed-device login, camera, Keychain, accessibility, exports, and live workflow acceptance remain necessary even after compilation succeeds.
