# Vaulty 0.3 — Home, sharing and encrypted offline files

## Install this update

Install the new `Vaulty-backend-free.apk` over the existing backend-free APK. Version: **0.3.0+3**, ARM64, development-signed. Package, development signing certificate, Google Cloud project and configured public Web client ID are unchanged. **Do not uninstall the working app first.** Your canonical documents remain in your own Google Drive app-data folder.

Existing PDF/JPEG/DOCX documents are read without a destructive migration. Update other devices/testers before uploading the new image formats: older Vaulty versions do not understand the additional format values.

## Your six requested changes

1. **Direct sharing.** A Share icon on document rows, grid cards, Home recents and search results, plus a Share button on details, prepares the original file and opens Android's system share chooser. No Copies screen or recipient form. The first download may take time; an unchanged cached version avoids another file download. A small metadata request still checks freshness online. Browsers use Web Share when supported and download a copy otherwise.
2. **Relevant recents only.** Home has Uploaded, Modified and Browsed filters. Uploaded/modified dates are in Drive document metadata; browsing recents are device-local and encrypted on Android. No activity/audit UI or new Drive event-log records. Legacy event records are ignored rather than automatically deleted; Delete my data still removes all tagged Vaulty records after confirmation.
3. **Encrypted cache.** Android stores cached originals and metadata with AES-256-GCM. Per-account keys are protected using Android Keystore through secure storage. Records are bound to their account and key by authenticated additional data. Large-file encryption/decryption runs in a worker isolate rather than on the UI thread. A 256 MB file-cache budget evicts least-recently-used entries. Metadata is cached too, allowing the collection to load offline after it has synced once. Browser cache is memory-only, up to 150 MB; it does not survive closing/reloading the page and is not an installed offline PWA.
4. **Home replaces Insights.** Google account storage quota/usage, renewal attention and recent files. Navigation is Home, Documents, Upload and Settings; Copies/Shared routes and screens have been removed.
5. **Layout and contrast.** Equal-width renewal/empty-state cards, consistently spaced form controls, full-width reminder and document action buttons, equal-sized navigation icons, a warmer darker light canvas, off-white cards and visible card outlines. Text contrast and compact layouts are covered by tests.
6. **Share into Vaulty.** Android SEND and SEND_MULTIPLE intents accept attachment URIs in cold and warm starts. Attachments are copied into encrypted staging while URI access is available. A review screen displays the target account and allows selection/removal plus individual title, owner, tags and renewal date. An owner can be applied across the batch. Nothing uploads without tapping Import. Successful items are removed from the queue; retry only processes remaining items.

## Supported files and previews

- PDF, JPEG, PNG, WebP, GIF, HEIC/HEIF and DOCX.
- File contents are inspected, rather than trusting only a name or sending app's MIME type. Arbitrary ZIPs are not accepted as DOCX. Archives are inspected without extracting their contents.
- Images preview in-app when supported by the renderer. Android PDFs have a first-page preview; Open / download opens the full document in a compatible viewer. DOCX and formats the renderer cannot decode use an external compatible app. A viewer may need installing separately.
- File limit: **50 MB**. Incoming batch: **20 pending files / 150 MB**. Mixed batches report unsupported/unreadable files individually.
- Pending encrypted imports expire after 24 hours, with cleanup on the next inbox access. Imported file bytes are processed sequentially, not all retained together in Dart memory.

## Using offline files

1. While connected, open a document's detail screen and wait for its download/preview to finish. Uploads are cached too, subject to the cache budget.
2. Disconnect the network. Previously cached versions can open or share without downloading again.
3. After restarting the Android app offline, choose **Open offline vault** on the login screen if Google cannot reconnect. This opens only the previously verified account's local cache, not a new Google session. Any enabled biometric app lock still applies.
4. Reconnect Drive in Settings and refresh Home to sync again.

Changes, uploads, replacements and deletes still require an online Drive connection; there is **no offline write queue**. When online, opening/sharing checks Drive's file version. Local edits/replacements/trash actions invalidate the old cached version. Deleted files and authorization failures are not silently substituted with cached bytes. When offline, changes made elsewhere cannot be detected; the preview identifies an offline cached copy.

Settings → Clear offline cache removes local cached files, the saved collection/settings snapshot and browsing recents, without touching Drive originals. Signing out clears the current account's encrypted cache, pending imports and app-managed temporary opened/shared files.

## Privacy boundaries

Encryption covers the Android app-managed persistent cache and incoming staging, **not** exported copies or end-to-end encryption of Drive files. An external viewer or receiving app needs a temporary decrypted file and may keep its own copy. Vaulty cleans its temporary open/share files (including the sharing plugin's cache) on sign-out/cache clear; old temporary exports are also pruned after 24 hours on subsequent app start/use. PDF render scratch files are deleted immediately after rendering, with stale-file cleanup for interrupted renders. Cleanup is not a continuously running background service and cannot recall another app's copy.

No new backend, Firebase service, database server, Google permission scope or client secret was introduced. Update your public privacy disclosures to describe local encrypted caching, encrypted pending imports and temporary exports before public distribution.

## Test on your phone before sharing widely

Use disposable sample files for these checks:

- Update install, existing Google sign-in, previous documents and details still present.
- One-tap Share from Documents, Home and details opens Android's app chooser. Open the received file in the destination app.
- Open PDF/image/DOCX online, then repeat open/share in airplane mode. Restart offline and use Open offline vault. Confirm biometric lock if enabled.
- Edit the title or replace the file online, then preview/share again: the updated name/content must be used. Check a change made on a second device after reconnecting.
- Share one PDF into Vaulty from a file manager while Vaulty is closed; then repeat while Vaulty is open.
- Share several images/PDFs/DOCX together; edit owners/titles/renewals, deselect one, import and check each result. Include an unsupported file and confirm it is rejected without blocking valid files.
- Deny attachment access or share an oversized file; verify the message and that no invalid upload is created.
- Interrupt a batch using network loss; retry and confirm completed files are not duplicated.
- Verify sign-out/account-switch isolation and that pending imports/cache do not appear under another account.
- Check Android reminder permission, camera, external viewer, TalkBack, enlarged text, both themes and device performance.

Automated checks are not a substitute for these physical-device checks. See VERIFICATION.md for the exact checks run in the build workspace.
