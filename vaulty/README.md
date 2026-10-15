# Vaulty

A Flutter Android/Web personal document vault. The device talks directly to Google OAuth and Drive; there is no custom backend, Firebase service or external database. Each account has a separate hidden Drive app-data vault.

**Version 0.3.0+3** adds Home, direct system sharing, Android encrypted caching/offline reads, and single/batch Android share-intent imports. See [the update guide](docs/V0_3_UPDATE.md), [activation instructions](START_HERE.md) and [verification](docs/VERIFICATION.md).

## What works in the real implementation

- Google SDK identity and Drive app-data authorization, including verification that the Drive access token belongs to the signed-in account.
- Account-scoped requests, navigation, optimistic edits and Undo; stale operations cannot overwrite a different account's state.
- Files, gallery and camera input; PDF, JPEG, PNG, WebP, GIF, HEIC/HEIF and DOCX, with content inspection and a 50 MB file limit.
- Direct resumable Drive uploads; title, owner, tags, uploaded/modified dates and optional renewal dates in canonical Drive metadata.
- Home with Google account storage quota, renewal attention and Uploaded/Modified/Browsed recents. No Copies or activity/audit screens.
- One-tap Android system sharing from rows, grid cards, Home recents, search and details. Browser Web Share with download fallback. Exports are copies, not revocable links.
- Android AES-256-GCM cache with Keystore-protected per-account keys, 256 MB LRU file budget, encrypted metadata, version checks and offline reads. Browser cache is session-memory-only, not persistent offline storage.
- Android first-page PDF preview and image previews; full-document viewing via a compatible external app. Cached files can open/share offline.
- Android SEND/SEND_MULTIPLE intake, encrypted temporary staging, per-file review, bulk owner entry, validation, partial-failure retry and explicit import. Maximum 20 pending files / 150 MB.
- Search, tags, saved queries, editable metadata, file replacement, logical Trash/restore, permanent delete, 30-day Trash retention on sync and a 150 MB in-memory ZIP backup export.
- Device-local biometric screen lock and local Android renewal reminders.

## Important boundaries

This is not an offline-write synchronization engine, OCR scanner, end-to-end encrypted Drive vault, collaborative vault, recipient-access audit or backup importer. Android cached files are encrypted at rest; external viewers/share targets receive temporary decrypted copies. Those apps can retain their own copies. Files without a compatible inline renderer need an external viewer.

Browse recents are local to the device. Online version checks detect updates before opening/sharing; an offline device cannot detect remote changes until reconnecting. No new activity events are written. Legacy event records are ignored, not automatically deleted.

Web uses Google's branded SDK button. Register the actual browser origin in Google Cloud. Its cache is memory-only and does not survive a reload; incoming OS share-target registration is implemented for Android, not Web/PWA.

## Configuration and builds

The supplied **public** Web client ID is already in `assets/config/google.json`. A nonempty `GOOGLE_WEB_CLIENT_ID` build define overrides the asset. Neither a client secret nor service-account credentials belong in this app.

```sh
flutter pub get
flutter run
flutter build apk --release --target-platform android-arm64
flutter build web --release --no-web-resources-cdn --base-href /
```

The public source intentionally excludes the private development signing key. Restore your private development signing backup if you need the exact supplied development SHA-1, or register your own signing certificate in an Android OAuth client. `android/key.properties.example` describes production signing. Without production configuration, release-mode APKs are development-signed, not Play-ready production releases.

Use `lib/main.dart` for real Google/Drive. The explicit fixture entry point is `flutter run -t lib/main_demo.dart`; `MOCK_SCENARIO=empty|error` and `SHOW_GALLERY=true` are debug/fixture controls. Mock screenshots are not evidence of a live Google account or native hardware tests.

## Structure

- `app/`: composition, live bootstrap, account-reset routing and navigation.
- `core/theme/`: all palette, typography, spacing, radius, motion and component themes.
- `core/widgets/`: shared cards, buttons, lists, empty/loading/error states and tokens.
- `domain/`: document/settings/storage models and repository capabilities.
- `data/drive/`: token-owner verification, REST operations, metadata codec and real repositories.
- `data/cache/`: encrypted Android cache, memory-only Web cache and versioned file envelopes.
- `data/device/`: file validation, incoming-share bridge, external viewers/sharing, biometrics and reminders.
- `features/home/`, `documents/`, `imports/`, `upload/`, `search/`, `settings/`, `auth/`, `trash/`: screen and provider layers.
- `android/.../MainActivity.kt`: encrypted attachment staging, intent handling and native PDF preview rendering.
- `data/mock/`: explicitly selected fixture repositories. Some legacy share/event domain types remain for fixture compatibility; there are no live sharing-management/audit screens.

## Design and accessibility rules

Visual changes belong in `core/theme`, not raw colors, TextStyle literals, dimensions, radii or motion values inside widgets. Public Sans is bundled. Light mode uses a warm darker canvas, off-white cards and visible outlines; dark mode uses tonal surfaces. Text contrast targets at least 4.5:1, touch targets at least 48 dp, 320 dp width and 1.3x text scaling, reduced-motion support, clear labels, confirmation for destructive operations and Undo where supported.

Prefer const widgets, lazy collection lists/slivers, bounded batch forms, repaint boundaries and cache-sized image decoding. Physical-device frame-rate, TalkBack, biometric, chooser and receiving-intent acceptance remain separate checks; compilation and unit tests do not prove them.

```sh
flutter analyze
flutter test --concurrency=1
python3 tool/check_styling.py
```

## Security notes

Keep development/production signing backups private. Never distribute a client secret, access token, refresh token or account password. A previously supplied screenshot exposed an OAuth client secret; rotate it in Google Cloud if you have not already. Only the public client ID is included here. No legal pages or Cloud settings are published/modified by these source files.
