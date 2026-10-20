# HOP Club — native customer iPhone app

Native SwiftUI customer test app using the existing HOP Club V2 customer bearer session. Independent bundle ID: `com.houseofpizza.hopclub.ios`. iOS 17+, portrait iPhone, version 0.3.0 (3). No manager/employee credentials or API routes are bundled into this client.

## Visual ordering studio — 0.3.0

Native Size / Base / Toppings / Review steps; original illustrated pizza and
ingredient tiles; real whole/left/right, style and quantity capabilities from the
catalog; current-label ingredient mapping (legacy IDs may have different names);
bounded selection counts; server-quoted food subtotal; editable bag items; and
a short add-to-bag animation respecting Reduce Motion. Real catalog photos are
retained where present. Illustrations describe selected additions, not the full
recipe, allergen contents or an exact food photograph.

Pickup review explicitly says pay at pickup. The request receipt appears only
after the existing server acknowledges an order; it does not claim payment,
host confirmation or kitchen progress. Apple Pay/Apple Cash capture is NOT
implemented, configured or simulated. Native push remains outside this build.
The website, menu records, kitchen contracts, rewards and production backend are
unchanged. No tests place production orders or redeem rewards.

This is an original HOP interface, not artwork or layouts copied from another
restaurant. Test the compiled IPA on an authorized iPhone; the conversation
preview is a separate no-network prototype, not a live ordering session.

## iOS presentation rebuild — 0.2.0

Rebuilt customer presentation, not a website wrapper or manager-app clone: a membership-led Discover screen, visit stamps, horizontal restaurant offers, photo menu with category chips, large option selections, sticky bag and sheet actions, compact reward cards with readiness filtering, two-tone native membership QR card, and a redesigned account/preferences area. Warm cream/green branding adapts to dark mode. Touch feedback is optional, text uses iOS text styles, and press motion respects Reduce Motion. QR rasterization is cached per payload instead of repeating on each timer update.

Menu choices are shown by name/portion/style in the bag for review; those local descriptions and image references are excluded from order submissions. Server prices, identity checks, durable request keys and staff confirmation remain unchanged. Existing users can install this over the first customer build with the same bundle/signing identity. Physical-device visual and interaction testing remains required.

## Included

Existing-member login; secure Keychain session; live member points/visits; server-generated membership QR rendered natively; menu/categories/images/modifiers; server-quoted pickup requests with explicit confirmation and durable idempotency keys; order history/status; reward eligibility/requests/confirmation QR; points activity; published website offers; system/light/dark appearance; sign-out and app-switcher privacy.

Prices and loyalty balances come from the existing server. Nothing is automatically purchased, redeemed, signed up, or published by the build/tests. Pending writes retain their request key in the device Keychain for deliberate retry after ambiguous network failures. Reviewing/clearing a pending request never cancels a server-side order.

## Deliberate boundaries

- Existing-member testing only. This client does not expose registration; enrollment, account ownership verification and recovery need a separate security review before public release.
- No native APNs background push with this free-account SideStore setup. Activity/status refresh while using the app. Public distribution, signing and push require a separate release path.
- Pickup requests require host phone confirmation; no card-payment capture or delivery checkout is invented.
- Profile/PIN edits and automatic promotional discounts are not implemented through unverified endpoints.
- Photos use HTTPS assets from the HOP site. Unsupported/missing image formats show a neutral placeholder, never a fabricated reward photo.
- QR uses only the existing server-generated SVG module strokes. It does not issue its own member tokens or use a web view.

## Build / verify

`swift test` checks Foundation-only customer policy, cart/modifiers and restricted QR rendering input. `node --test scripts/contracts.test.cjs` checks native target/customer boundary. GitHub Actions on branch `hopclub-ios` archives arm64 with macOS/Xcode and no simulator. Run `bash scripts/build-ipa.sh` on macOS to produce `build/HOPClub-unsigned.ipa`.

An unsigned artifact is not an installed or publicly distributed app. Sign through SideStore for the established personal-device test workflow. Authenticated device behavior, QR staff scanning and actual order/reward transitions still require supervised testing. No production backend deployment is part of this project.
