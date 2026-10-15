# Vaulty 0.3 — install, test and share

Vaulty now has a **backend-free Google Drive implementation**. The phone/browser talks directly to Google. You do not need Firebase, a custom API server, a database service, or a service-account key.

**Your public Web client ID is now bundled in the source, test APK and static Web preview.** The Android package/signing registration, Drive API enablement, test-user list and browser origins must still be correct in Google Cloud. I cannot verify those Console settings from a client ID or screenshot. Actual Google sign-in and Drive upload/download have not yet been tested. Start with `docs/CONFIGURED_TEST_BUILD.md`.

## Already using the configured APK?

Install the updated **0.3.0+3** APK over the existing working app; do not uninstall it first. The public Web ID, package and development signing identity are unchanged. No extra Google permission scope is needed. [Read the update guide](docs/V0_3_UPDATE.md) for Home, one-tap sharing, encrypted offline files and incoming batch imports.

## 1. Finish the Google registration once, as the developer

Use the same Google Cloud project for both client registrations.

1. Enable **Google Drive API**.
2. In **Google Auth Platform**, set up Branding and choose **External / Testing** under Audience.
3. Add your Google email under **Test users**. Also add any friends who will test while the app remains in Testing. Developer contact email is not the test-user list.
4. In Data Access, add `https://www.googleapis.com/auth/drive.appdata`. The Google SDK also uses its standard identity scopes. Do not request full-Drive access.
5. Create the Android client:
   - Name: `Vaulty Android Development`
   - Package: `app.vaulty.vaulty`
   - SHA-1 for the prepared development signing key:
     ```text
     23:4F:81:95:D7:A4:9E:C7:4B:2B:16:9C:23:93:69:93:59:56:05:68
     ```
   - Leave “Use this client for an AI-powered agent” unchecked.
6. Create a **Web application OAuth client** named `Vaulty Web`.
   - Its client ID is also the `serverClientId` expected by the proposed Flutter Google Sign-In Android plugin. The name does **not** imply a backend.
   - For Android-only use, JavaScript origins and redirect URIs can remain empty.
   - For browser testing, add `http://localhost` and `http://localhost:7357` as separate Authorized JavaScript origins.
   - For hosted web access, add the exact stable HTTPS origin of your deployed static website, without a path.
   - The implemented browser sign-in uses Google's button and popup/callback flow; no custom callback server has been created, so redirect URIs are empty for this flow.

For private localhost development, leave optional homepage/policy/domain fields blank rather than inventing URLs. For public release, provide accurate policy/branding pages and complete any verification Google requests. These can be static pages; no app backend is required.

## 2. Public Web client ID — already configured in this download

**Signing prerequisite for the source download:** the public source ZIP intentionally excludes private signing keys. To use the SHA-1 above, restore the keystore from your private `Vaulty-development-signing.zip` backup to `android/app/dev-signing/vaulty-debug.keystore`. Otherwise, use your own key and register its actual SHA-1; a different computer's default debug key will not match the fingerprint above.


Your public Web client ID is already set in **`assets/config/google.json`**. The supplied APK is configured; no end user needs to edit a file. For your own source build, use the bundled asset or override it using the method below.

Alternatively, copy `config/google.example.json` to `config/google.json` and supply it through the build commands below. A non-empty `--dart-define` value takes precedence over the bundled asset. Fill in the identifier:

```json
{
  "GOOGLE_WEB_CLIENT_ID": "YOUR_ACTUAL_CLIENT_ID.apps.googleusercontent.com"
}
```

Replace the entire example string with the actual Client ID shown by Google. It is a public identifier, not a password or client secret.

```sh
flutter pub get
flutter run --dart-define-from-file=config/google.json
```

For a locally running browser build:

```sh
flutter run -d chrome --web-hostname localhost --web-port 7357 \
  --dart-define-from-file=config/google.json
```

For an Android APK:

```sh
flutter build apk --release --target-platform android-arm64 \
  --dart-define-from-file=config/google.json
```

**Never put a client secret, access token, refresh token, Google password, or service-account JSON in the Flutter build.** No such secret is needed by this client-only implementation.

The Web client ID has been supplied and configured. Confirm the Android package/SHA-1 registration and Drive API enablement in your Console. No account passwords or tokens are needed. A client secret appeared in the supplied screenshot: reset/rotate it in Google Cloud. It is not used by Vaulty and has not been bundled in any deliverable.

## 3. Test your own vault before distributing it

Use a disposable test document, not sensitive originals, for first acceptance:

1. Sign in with the Google test account and grant Drive access.
2. Confirm that a new account starts with **zero documents**, not the 40 mock documents.
3. Upload a PDF or JPEG, set a title/owner/expiry, and confirm the actual file size and upload progress.
4. Restart the app, reconnect if requested, and verify the same document remains available.
5. Open/download the original file and compare it with the uploaded file.
6. Edit, Undo, move to Trash and restore. Permanently delete only disposable test files.
7. Sign out and sign into a second test account. It should have its **own independent vault** and no first-account rows/searches.
8. Sign back into the first account and verify its data is intact.
9. On Android, enroll biometrics first, enable the app lock, and test background/resume. Allow notifications and test reminders on the actual device.
10. Share a disposable copy. Understand that the recipient's copy is outside the vault and cannot be recalled.

The hidden appData folder is **not visible as a normal folder in My Drive**. This is expected. Each person's original files and Vaulty document metadata are stored in that person's Google account, under this Google Cloud application's appData space. The developer does not receive a copy on a Vaulty server.

## 4. Let other people use the Android app

### Small private test

- Configure OAuth first, then give testers the configured APK.
- Keep the consent app in **Testing** and add each tester's Google account to the Test users list, subject to Google's test-user limits.
- Each tester grants access to **their own Drive**. They do not configure a Cloud project or supply their own client ID.
- The supplied development signing identity is for testing only. If someone builds with a different signing key, register that build's SHA-1 too.

The newly prepared development key differs from the signing key used for the earlier mock APK. You must uninstall that earlier mock APK before installing a build signed with the new key. This deletes that installed demo's local state. Do not indiscriminately uninstall a future real-data version without understanding its data/backups.

### Wider release / Google Play

1. Create and privately retain your own **production/upload signing key**. Do not distribute the development keystore with the app's public source or use the example development key for production.
2. Copy `android/key.properties.example` to `android/key.properties` and configure the production key locally. Both key files and key.properties are Git-ignored.
3. With Google Play App Signing, register the **Play app-signing certificate's SHA-1** in an Android OAuth client. The upload key's fingerprint is not a substitute for the certificate signing installed Play builds. Keep all relevant OAuth clients in the same Cloud project.
4. Build an Android App Bundle:
   ```sh
   flutter build appbundle --release --dart-define-from-file=config/google.json
   ```
5. Test through Play's internal testing track, then complete the applicable Play release requirements.
6. Complete OAuth branding/privacy information and any verification Google requires; move the OAuth app from Testing to **In production** when ready for non-test users. OAuth publication and Google Play publication are separate steps.
7. Review Play's Data safety declarations for sign-in, Drive access and user-initiated exports. “No backend I operate” does not mean the app handles no personal data.

The Gradle configuration uses `android/key.properties` when present. Without it, release builds use a development/debug signing identity and are **not production-signed releases**.

## 5. Let other people use the browser version

Build and deploy **static files**, not a backend:

```sh
flutter build web --release --no-web-resources-cdn --base-href / \
  --dart-define-from-file=config/google.json
```

Host the contents of `build/web/` on a stable HTTPS static host. Register that site's exact origin in the Web OAuth client. Google login should be tested in a standalone browser tab; an embedded preview can be affected by popup, third-party-cookie or identity-permission restrictions. Temporary tunnel URLs change and are not a stable production origin.

Browser Drive authorization can expire and require another user-initiated permission flow. Tokens are not put into application localStorage by this app. Web uses Google's SDK-rendered sign-in button as the approved branding exception.

## What “sharing” means in this version

- **Sharing the app:** other users sign in and receive their own private vault.
- **Sharing a document:** a single Share tap opens Android’s system chooser after preparing the file. Web uses Web Share if supported, otherwise downloads a copy. There is no Copies screen.
- **Not included:** collaborative vault access, recipient permissions inside appData, expiring share links, remote revoke, disabled copying/screenshots, or a tamper-proof recipient-access audit.

Google does not support native Drive permissions or native Drive Trash for appData files. Trash is stored as document metadata, with automatic permanent deletion after 30 days **when the app next syncs**, not by a continuously running server.

## Boundaries to know before real use

- Drive changes/uploads require an internet connection. Android can read previously cached versions offline; this is not an offline-write synchronization engine. Use Open offline vault after an offline restart, then Reconnect Drive when online.
- Supported uploads: PDF, JPEG, PNG, WebP, GIF, HEIC/HEIF and DOCX, up to 50 MB each. Android incoming share batches are limited to 20 pending files / 150 MB. Automatic scan/OCR is not included.
- A ZIP backup exports files and metadata; in-memory backup size is limited to 150 MB. Backup import is not implemented.
- Biometric lock is Android/device-local and protects the app screen. The Android cache and pending share imports are encrypted at rest with Keystore-protected keys. Drive files and exported copies are not end-to-end encrypted.
- Android renewal reminders use inexact OS scheduling and can be delayed by battery restrictions. They are rescheduled when the vault syncs. Web does not schedule native reminders or register as an OS incoming share target. Its cache is memory-only.
- Temporary copies opened by external viewers, downloads and exported backups are outside the protected Drive appData area. Keep them private.
- Activity/audit screens and new event logging are removed. Home shows upload/modification dates and device-local browsing recents. Legacy event records are ignored rather than automatically deleted.
- Concurrent metadata editing has version checks and uses ETag/If-Match when Drive supplies the header. This is not a general offline merge engine; refresh on a conflict.
- Deleting multiple files/account data is a sequence of Drive operations, not a server transaction. A failure may leave a partial result; refresh and retry the remaining items.

See `docs/VERIFICATION.md` for the checks actually run and the live OAuth/device tests still needed.
