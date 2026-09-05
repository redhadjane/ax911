# HOP Command Center for iPad

Native SwiftUI iPad app, version 0.2.0 (2), iPadOS 17+. Bundle ID: `com.houseofpizza.commandcenter.ipad`.

The app now uses a SwiftUI sidebar, native lists/forms, selectable schedule cells and PDFKit document previews. The target does not compile WebKit or bundle the web manager UI. Version 0.1.0 remains the previous wrapper fallback in Git history. The employee iPhone app, Windows app, legacy manager website, live server and database are unchanged. Existing manager name/PIN and server authorization apply. No sample employee records or credentials are bundled.

## Build and install

The isolated `hop-command-ipad` branch in `redhadjane/ax911` runs the macOS GitHub Actions workflow. It runs portable tests and compiles the complete physical-device arm64 app, without simulator work. Download `HOPCommand-iPad-unsigned-ipa`, unzip it, and import the IPA into SideStore on your iPad using your existing free Apple account setup. SideStore supplies signing; this unsigned IPA is not an App Store/TestFlight build. Renew it through SideStore as required by your signing profile.

To reproduce on macOS: `swift test`, `node --test scripts/native-contracts.test.cjs`, then `bash scripts/build-ipa.sh`. Apple account credentials are not needed for this unsigned build. `scripts/configure-native-project.cjs` regenerates the explicit source/resource project.

## Connections and native behavior

- Manager API requests go to the existing HOP HTTPS host through URLSession, with no CORS/server changes. HTTP errors including 401/409 remain errors, and writes are never automatically replayed.
- The real bearer token stays in device-only Keychain. Sign out removes it. Redirects cannot forward credentials. No JavaScript/native bridge is used by this target.
- Portrait invoices/applications and landscape schedules/parties/tasks use UIGraphicsPDFRenderer. Preview, AirPrint and Share use the same PDF bytes. This native release exports PDF, not PNG/CSV.
- Native invoice line editing supports regular/catering catalogs and custom items, dollar/percentage discounts, tax, delivery, gratuity and card totals. Complete invoice details are fetched before editing/exporting.
- Published schedules are read-only. Draft edits, publish conflict review, role matching, availability, recurring shift tasks and manager-approved exceptions use the existing API.
- Employee profiles include approved roles, per-role pay, new PIN reveal/hide and server-provided existing PIN metadata. A hashed PIN cannot be reconstructed.
- Menu/reward photos use the connected picture library and PhotosPicker upload. External website links open separately without manager credentials.
- All 16 modules have native screens. This first native release is not full web feature parity: website editing covers identity/home hero, reports focus on scheduled labor/invoices, and advanced order/loyalty workflows remain in the established web/Windows tools. Task definitions are recurring by role/shift, as on the server.
- The Windows automatic printer bridge is not available on iPad. It is not paired or started. Native background push is not enabled in this free-account build; existing in-app alerts work while the app is active.
- Connectivity is required for live operations. This app does not silently queue business changes while offline.

## Verification boundaries

A successful Actions run verifies tests and device compilation, not installation, touchscreen behavior, physical AirPrint output, or live business mutations. Test those on your iPad. Start read-only: sign in, compare published schedule to Windows, browse employees/menu/invoices, then export an existing invoice and wallboard. Only then make a deliberate test edit to a safe draft and verify it in Windows. Do not publish a real schedule or send employee notifications merely to test installation.

The old `Web/` and `Bridge/` files are retained only as source-history fallback and are excluded from the native target. Public publication is restricted to `ipad/` and its workflow; never upload backend `.env`, databases, logs, customer files or audit folders.
