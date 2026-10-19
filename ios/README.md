# HOP Employee for iPhone

Native SwiftUI client for the existing HOP system. iOS 17+, Apple SDKs only, no WebView or bundled business records. This is a separate testing client; it does not replace the employee website or manager desktop.

## Version 0.3.0 (build 5)

Native messaging is connected to the same staff-messaging API as employee web and
manager Command. Inbox now has Messages and Alerts: private teammate chats,
role-based team groups, manager announcements, unread/read state, history paging,
mute, block/unblock and explicit single-message reporting. Managers can review
reported messages without access to unrelated private chats. Message a teammate
directly from their published schedule shift.

Drafts are held in memory only and cleared at sign-out. Retrying an unconfirmed
send reuses its client UUID so the server can prevent duplicates. Chat refreshes
are separate from schedule refreshes. Chats refresh while foregrounded, not while
closed. Existing web push is not native APNs; free-account SideStore signing does
not enable native background push. Do not treat local notifications as a push test.

Weekly availability reminders open their intended next Tuesday week. The server
controls recipients and timing; the native client does not schedule duplicate
weekly reminders. Existing day-by-day task checklists, team/week/day schedules,
requests, exports, profile approvals and loyalty workflows are retained.

Warm HOP brand colors in light/dark mode, a published Everyone/My shifts weekly
board with role filters and shift details, Today task/party shortcuts, and real
local iPhone shift reminders with permission checks, quiet hours and sound/privacy
options. Existing requests, availability, tasks, profile/photo/PIN approval and
HOP Club workflows remain connected. No sample staff schedules are bundled.

Local reminders are opt-in, based on published schedules last loaded on the phone,
and stop at employee session expiry. Remote schedule changes cannot update them
until HOP opens and refreshes. Foreground banners are category-filtered; the Inbox
still retains all messages. Real background APNs is not enabled by these settings.
Per-employee broadcast read receipts are an additive, separately deployed backend
update, not a migration installed by this IPA. Pilot verification is required.

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
- Swift Package Manager runs date/schedule/task contracts, mocked API transport, and messaging policy/store tests on the Mac runner without a simulator. No test sends real messages or changes production records.
- Signed-device login, camera, Keychain, accessibility, exports, and live workflow acceptance remain necessary even after compilation succeeds.
