# HOP Command Center for iPad

Separate iPad app, version 0.1.0 (1), iPadOS 17+. Bundle ID: `com.houseofpizza.commandcenter.ipad`.

This is the current connected manager frontend packaged in an iPad-native WebKit shell, not a SwiftUI rewrite of every module. The employee iPhone app, Windows app, legacy manager website, live server and database are not replaced. Existing manager name/PIN and server authorization apply. No sample employee records or credentials are bundled.

## Build and install

The isolated `hop-command-ipad` branch in `redhadjane/ax911` runs the macOS GitHub Actions workflow. It runs portable tests and compiles the complete physical-device arm64 app, without simulator work. Download `HOPCommand-iPad-unsigned-ipa`, unzip it, and import the IPA into SideStore on your iPad using your existing free Apple account setup. SideStore supplies signing; this unsigned IPA is not an App Store/TestFlight build. Renew it through SideStore as required by your signing profile.

To reproduce on macOS: `swift test`, `node --test scripts/contracts.test.cjs`, then `bash scripts/build-ipa.sh`. Apple account credentials are not needed for this unsigned build.

## Connections and native behavior

- Manager API requests go to the existing HOP HTTPS host through URLSession, with no CORS/server changes. HTTP errors including 401/409 remain errors, and writes are never automatically replayed.
- The real bearer token stays in device-only Keychain; the bundled JavaScript sees only a session marker. Sign out removes the token. Untrusted navigation cannot use the native bridge; redirects cannot forward credentials.
- Portrait invoices/applications and landscape schedules/parties/tasks produce PDF with a native print renderer. Choose AirPrint or Save PDF / Share. PNG/CSV use the iPad share sheet and Save to Files.
- Menu photo inputs use the system file/photo chooser. External website links open separately without manager credentials.
- Touch controls, portrait navigation, safe-area layout and keyboard-height handling are iPad-specific overrides of the existing UI.
- The Windows automatic printer bridge is not available on iPad. It is not paired or started. Native background push is not enabled in this free-account build; existing in-app alerts work while the app is active.
- Connectivity is required for live operations. This app does not silently queue business changes while offline.

## Verification boundaries

A successful Actions run verifies tests and device compilation, not installation, touchscreen behavior, physical AirPrint output, or live business mutations. Test those on your iPad. Start read-only: sign in, compare published schedule to Windows, browse employees/menu/invoices, then export an existing invoice and wallboard. Only then make a deliberate test edit to a safe draft and verify it in Windows. Do not publish a real schedule or send employee notifications merely to test installation.

The `Web/source-manifest.json` records the local desktop source snapshot used. `scripts/snapshot-web.cjs` is only run in the full local workspace to refresh that snapshot. Public publication is restricted to `ipad/` and its workflow; never upload backend `.env`, databases, logs, customer files or audit folders.
