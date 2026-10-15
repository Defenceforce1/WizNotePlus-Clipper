# Independent WizNotePlus Clipper — current instructions

## Current scope (2026-10-15, 0.3.5/build 9)

- The user selected CIRCULAR scissors A and approved NATIVE layered rendering for new macOS, with an ICNS fallback for older systems. Badge diameter41.4%, center77.5%/77.0% from top-left. Reuse original raster background and user-supplied circle/scissors; never redraw, flip, recolor or substitute rejected SVG/bare-scissors artwork.
- Resources/AppIcon.icon contains original independent PNG layers. Compile Assets.car with Apple's actool; select CFBundleIconName=AppIcon in BOTH host and extension. Resources/AppIcon-final.icns is only the approved legacy fallback. Native catalog MUST take priority; never feed a glass-rendered PNG into the native layers or add the previous manually baked outer shadow again.
- All brand artwork and derivatives remain ignored/local-only; no public upload or public CI artifact containing them without clarified redistribution rights. Public source CI without local art uses a generic placeholder. See docs/ICON.md and docs/release-0.3.5.md; older process in docs/icon-rework-plan.md is historical.
- Main App14.4.16 MUST remain unchanged, including original icon, name, signature, data paths and runtime. Its source/installed ICNS hash is367bd83f06671ddb8275f6eb7a6036f8d24990301390b8853a947dfd724ef6c1. No new main features or rebuild; only future actual bug/compatibility maintenance if requested.
- This repository alone owns clipper runtime/resources/build/tests. Never rebuild Qt/main app for clipper changes. Keep independent GitHub repository/history.

## Preserve production behavior

- Keep bundle IDs, signing team and credential service identities stable. Token service io.github.defenceforce1.wiznoteplus.clipper.cloud; separate password service with .password suffix. No migration, shared-keychain ACL changes or host credential access.
- Password remembering is opt-in, local Keychain only, WhenUnlockedThisDeviceOnly, synchronizable=false. Never inspect/log/export real secrets or read old official clipper credentials. Synthetic checks use injected stores/transports.
- Reuse valid token. Only typed API301 on folder GET permits one same-account re-login and one GET retry, with identity validation. Never automatically repeat upload POST, including301/uncertain receipts.
- Cloud-only independent login/upload, HTML+resources/static math; no local-client pairing,8849, polling or persistent-task blockage. API acceptance is not confirmed server-side save. Keep cancel/error/uncertainty feedback.
- Login stays in share window. No startup window/resident host; normal entry exits immediately. Containing signed app remains necessary for extension. Keep centered 添加到为知笔记, quiet ready state, visible errors and lower-left exact https://www.wiz.cn/xapp without credentials.
- Preserve title commits, selection boundaries/no inherited selection tint, Wikipedia article/sidebar/footer cleanup, math deduplication and existing image fallback semantics. User specifically requested Wikipedia only; no further Chaoli testing.

## Verification and delivery safety

- Only synthetic notes/accounts and named local fixtures; no real login, password reads, uploads or note modification for validation. Do not modify system proxies/security/trust. Do not launch or replace the old official Intel app/clipper.
- scripts/build.sh runs standalone arm64 compilation, icon packaging, signature and mock checks; scripts/test.sh runs synthetic share UI and network-blocked capture. Optional fixed-Wikipedia replay remains local-only. Do not equate these with live Safari menu, cloud fidelity, another-Mac or future-OS verification.
- Host and extension icon declarations/resources/catalogs must match. An actual native IconImageStack with independent groups is required, not just a nonempty CAR or renamed flattened screenshot.
- Free/self-use development signing, unnotarized: no promise of universal cross-Mac extension loading; do not request paid membership or keys/passwords as default.
- Recheck actual app/extension processes before installation; never force-quit or replace a running clipper. Preserve the full previous installed bundle and avoid broad xattr/cache removal. Only own exact generated test registrations may be removed, never old official clipper registrations.
- Cleanup uses exact validated generated targets and recoverable Trash; preserve current and immediate rollback apps, original art, user-edited source, unique source archives, logs/screenshots and all private stores. Historical output paths may now be in Trash. Do not claim moving to Trash frees disk space.
- Do not publish raw logs, reports, account data, certificates/private keys, captured webpages or artwork. Sanitize source/process backups only. Optional artwork generators are developer tools, not runtime dependencies.
