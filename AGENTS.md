# WizNotePlus Clipper — maintenance instructions

## Current release scope

- 1.1.0/build19 completed: actual installed /Applications/WizNotePlus Clipper.app shows correct W+scissors and 为知笔记 in Safari; strict signatures and ZIP/DMG byte comparison passed, all synthetic checks passed. No live login/upload. Current package under outputs/v1.1.0-delivery, original artwork and1.0.0 rollback retained. Main app unchanged; user handles old app deletion.
- User explicitly authorized a new permanent identity for the clipper's final personal-use release on2026-10-16. Version1.1.0/build19, application filename **WizNotePlus Clipper.app** (English as requested); host display name 为知笔记网页剪藏, share name 为知笔记.
- Stable host ID: io.github.defenceforce1.wiznoteplus.webclipper. Stable extension ID: io.github.defenceforce1.wiznoteplus.webclipper.share. Never reuse diagnostic IDs; future upgrades keep these IDs and the signing team fixed.
- New credential services are io.github.defenceforce1.wiznoteplus.webclipper.cloud and .cloud.password, account official-account. No automatic legacy credential migration. User must enable the new extension and log in; no passwords/keys requested in chat.
- User will delete the old app themselves. Do not delete, replace, unregister or force-quit old installed applications. New release may be installed only at its distinct English filename, after checking target/process state; preserve1.0.0 rollback and original art. No unrelated app/data/cache cleanup.
- NEVER build/change/rename the main note app14.4.16, its original icon, signature, data paths or notes. Original main icon SHA256 remains367bd83f06671ddb8275f6eb7a6036f8d24990301390b8853a947dfd724ef6c1.
- This is an independent GPL community clipper, personal-use Apple Development signing, unnotarized; not official WizNote or guaranteed multi-Mac/future-macOS compatibility.

## Preserve behavior and privacy

- Cloud-only HTML/resources/static math; no local pairing,8849,polling,persistent queue or main-app dependency. Login stays in the share window; host exits without a startup window. Keep centered 添加到为知笔记 and lower-left https://www.wiz.cn/xapp. Quiet ready state; retain errors/cancel/uncertain-upload feedback.
- Remembering uses local Keychain, password WhenUnlockedThisDeviceOnly, synchronizable=false. Never inspect/log/export real secrets, change ACLs or access old official credentials. Tests inject storage and transport.
- Reuse valid token. Only typed API301 on folder GET permits one same-account re-login and one GET retry with identity validation. Never repeat upload POST automatically. API acceptance is not proof of final saved note.
- Preserve connected-original-DOM selection tracking and exact prose endpoints; only formulas are atomic. Preserve math deduplication and image security/fallback.
- Code retains exact whitespace/source monospace font,size,leading,tab stops and token colors. PRE owns canvas/padding; nested CODE is block with no borders/padding. Never reintroduce per-line dashed boxes or forced13px/1.5 leading.
- Keep original circular scissorsA artwork: badge diameter41.4%,center77.5%/77.0%; original raster layers, no redraw/flip/recolor/baked effects. Host uses native Assets.car plus high-resolution ICNS fallback; share extension only compact16–256px ShareIcon.icns. Branded artwork remains local-only.

## Build, verify and deliver

- Use scripts/build.sh,test.sh,check-release.sh,package.sh. Build complete signed production packages in hidden assembly first; test tools stay outside the app. Do not register incomplete output bundles or automatically install from build/package scripts.
- Production host uses -Osize and excludes test code; retain Objective-C extension principal-class symbol. Resource allowlist rejects draft art,diagnostic tools,extra runtimes. Keep user guide and license notices.
- Tests use synthetic accounts/injected stores and local fixtures; no real login/upload/editing. The latest public-page replay scope is only the two code blocks of the supplied chaoli page; no repeat article/math captures unless requested.
- Verify native arm64,strict nested signature,matching signing teams,sandbox+outgoing-network only,stable metadata,ZIP/DMG extraction equality. Actual Safari icon/name check is separate; do not select the service or access credentials just to inspect its icon.
- Existing Apple Development identity only; never demand paid membership or passwords/private keys, weaken security or bypass Gatekeeper. Do not replace running applications or force-quit processes.
- Prefer GitHub connector, never browser or Git CLI network for sync. Publish sanitized source/process only: no personal paths/accounts,certs/keys,brand art,webpage captures,raw logs or private evidence. Public CI without local artwork uses a placeholder.
- Cleanup exact validated generated targets only. User authorized removal of obsolete intermediates/icons; preserve original art/user inputs,current+previous formal release and source history. Do not empty Trash,delete protected/user data,bypass access or reset global caches. Keep a local cleanup manifest.

## Icon investigation evidence and limits

Fresh no-accountA/B and complete same-code/resource copies with new IDs showed correct icons while old production remained placeholder. Icon replacement under the same test ID stayed stale, including after user reboot. Ordinary production re-registration,25 obsolete host-record removals,scoped same-version reinstall and own-data clearing did NOT fix old identity; no specific cache cause proven. Old1.0 credentials were deleted only with explicit user approval; its extension container was moved through Finder to Trash, not purged.

All diagnostic identities/apps/intermediates were removed after tests; local evidence/instructions remain under ignored outputs/icon-*. They are not release recipes.1.1.0 is an explicitly authorized stable-identity workaround; validate the actual installed new release, do not assume diagnostic success guarantees it. Future icon changes may remain stale; avoid endless reboot/reinstall or identity churn.

Current docs: README.md and docs/{USER_GUIDE,DEVELOPMENT,VERIFICATION,ICON,ROADMAP,MAINTENANCE,release-1.1.0}. History is in docs/history.
