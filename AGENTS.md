# WizNotePlus Clipper — maintenance instructions

## Current scope

- Latest user request: DO NOT INSTALL or change extension registration; deliver signed packages for manual installation. Keep the currently registered outputs/v0.3.8-release bundle at its existing path during cleanup. Do not infer permission to install from the earlier release request.
- Version1.0.0/build17, formal PERSONAL-use release; not official WizNote distribution or Apple-notarized. Safari share display name: 为知笔记. Host display name: 为知笔记网页剪藏. Keep installed filename WizNotePlus Web Clipper.app and all bundle IDs, signing team and credential service identities unchanged.
- This independent repository owns only the clipper. NEVER rebuild/change/rename the main App14.4.16, its original icon, signature, data paths or user notes. Main icon SHA256 remains367bd83f06671ddb8275f6eb7a6036f8d24990301390b8853a947dfd724ef6c1.
- Keep approved CIRCULAR scissors A art: original raster layers, badge diameter41.4%, center77.5%/77.0%. Never redraw/flip/recolor or add baked effects. Host uses original-layer AppIcon.icon compiled to Assets.car with ICNS fallback; share extension uses only compact16–256px ShareIcon.icns. Brand art stays local-only, not public source/artifacts.

## Preserve behavior and privacy

- Cloud-only HTML/resources/static math, no local pairing/8849, polling, persistent queue or main-app dependency. Login stays in the share window; normal host exits without a startup window. Keep centered 添加到为知笔记 and lower-left https://www.wiz.cn/xapp without credentials. Quiet ready state; retain errors/cancel/uncertain-upload feedback.
- Credential services: io.github.defenceforce1.wiznoteplus.clipper.cloud and .password. Remembering is local Keychain only, WhenUnlockedThisDeviceOnly, synchronizable=false. Do not inspect/log/export secrets, change ACLs or read old official credentials. Preserve current remember behavior; no unrelated auth changes.
- Reuse valid token; only typed API301 on folder GET allows one same-account re-login plus one GET retry with identity validation. Never automatically repeat upload POST, even after301/uncertain result. API acceptance is not proof of final server-side save.
- Selection retains WeakMap to connected original DOM and exact prose endpoints; only formulas are atomic. Preserve math deduplication and source image security/fallback. Code retains exact whitespace, source monospace font/size/leading, stable tab stops and token colors. PRE owns canvas/padding; nested CODE has display:block, no borders/padding. Do not reintroduce repeated inline dashed borders or forced13px/1.5 line height.

## Verification and delivery

- Only synthetic accounts/injected stores and named local fixtures. User narrowed latest https://chaoli.club/index.php/12353/2026/10 testing to its TWO CODE BLOCKS only; no further article/math tests unless requested. Public captures/screenshots remain local-only. Do not login/upload/edit real notes, alter proxies/trust/security or launch/register/replace old official app.
- User reports another Mac's installation and icon work normally. Local Safari previously showed placeholder despite own registration, full appiconset, imageset and exact old official ICNS trials; do not call these successful fixes or claim confirmed cache root cause. No global cache deletion, private API, changed identity or security weakening. Historical evidence is archived, not a production build recipe.
- Production host must be minimal (-Osize); self-tests/UI/capture tools compile separately to output/Tests, never ship them. Retain the extension Objective-C principal-class symbol. Use scripts/build.sh, test.sh and check-release.sh; code replay stays offline. Signing success/tests do not establish real-cloud fidelity, universal multi-Mac loading or future-macOS compatibility.
- Free existing Apple Development signing, unnotarized; do not demand paid membership or passwords/keys. Recheck host/extension processes before installation, never force-quit or replace running app. Preserve full immediate rollback. Register only own installed bundle, verify actual installed path/name/version; do not leave registration pointing at outputs.
- Prefer GitHub connector for sanitized source/process backup. Never publish raw logs, reports, accounts, certs/keys, webpage captures or branded artwork. Generated developer examples and ignored local outputs are not public release packages.
- Cleanup exact validated generated targets recoverably; preserve current+immediate rollback, original art/user edits, source history and unique evidence. Moving to Trash does not itself free disk space; never empty Trash or clear caches as cleanup. Archive historical docs and experiments separately; do not execute old instructions as current.

Current guides: README.md and docs/{USER_GUIDE,DEVELOPMENT,VERIFICATION,ICON,ROADMAP}. Historical details: docs/history/README.md; optional tools: tools/icon-experiments (not runtime/build dependencies).
