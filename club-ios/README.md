# HOP Club — native customer iPhone app

Native SwiftUI customer test app using the existing HOP Club V2 customer bearer session. Independent bundle ID: `com.houseofpizza.hopclub.ios`. iOS 17+, portrait iPhone, version 0.1.0 (1). No manager/employee credentials or API routes are bundled into this client.

## Included

Existing-member login; secure Keychain session; live member points/visits; server-generated membership QR rendered natively; menu/categories/images/modifiers; server-quoted pickup requests with explicit confirmation and durable idempotency keys; order history/status; reward eligibility/requests/confirmation QR; points activity; published website offers; system/light/dark appearance; sign-out and app-switcher privacy.

Prices and loyalty balances come from the existing server. Nothing is automatically purchased, redeemed, signed up, or published by the build/tests. Pending writes retain their request key in the device Keychain for deliberate retry after ambiguous network failures. Reviewing/clearing a pending request never cancels a server-side order.

## Deliberate boundaries

- Existing-member testing only. The current backend signup upsert can overwrite credentials for an existing phone. This native client intentionally does not call or expose that route; secure enrollment and account recovery must be addressed before a public release.
- No native APNs background push with this free-account SideStore setup. Activity/status refresh while using the app. Public distribution, signing and push require a separate release path.
- Pickup requests require host phone confirmation; no card-payment capture or delivery checkout is invented.
- Profile/PIN edits and automatic promotional discounts are not implemented through unverified endpoints.
- Photos use HTTPS assets from the HOP site. Unsupported/missing image formats show a neutral placeholder, never a fabricated reward photo.
- QR uses only the existing server-generated SVG module strokes. It does not issue its own member tokens or use a web view.

## Build / verify

`swift test` checks Foundation-only customer policy, cart/modifiers and restricted QR rendering input. `node --test scripts/contracts.test.cjs` checks native target/customer boundary. GitHub Actions on branch `hopclub-ios` archives arm64 with macOS/Xcode and no simulator. Run `bash scripts/build-ipa.sh` on macOS to produce `build/HOPClub-unsigned.ipa`.

An unsigned artifact is not an installed or publicly distributed app. Sign through SideStore for the established personal-device test workflow. Authenticated device behavior, QR staff scanning and actual order/reward transitions still require supervised testing. No production backend deployment is part of this project.
