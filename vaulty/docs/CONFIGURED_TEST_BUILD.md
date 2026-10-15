# Vaulty — configured Android test APK

Updated 15 October 2026. The public Web OAuth client ID is now bundled in the Android APK, source and static Web preview:

```text
975496398940-67nf7ttnueibmng11hitb4qf9k2lvmaq.apps.googleusercontent.com
```

Project: `vaulty-511123`. No client secret is needed by Vaulty.

## First: rotate the exposed secret

The supplied screenshot displayed a Web OAuth client secret. In Google Auth Platform → Clients → this Web client, reset/rotate the secret (or add a replacement and disable/delete the exposed secret, according to the available Console controls). Keep the OAuth client and its client ID; do not delete the entire client merely to rotate a secret. Do not put any secret in Vaulty or send it in chat. The screenshot and its secret are not included in the APK, source ZIP or Web ZIP.

## Confirm these settings in Google Cloud

These cannot be checked from a client ID alone.

1. Enable Google Drive API in project `vaulty-511123`:
   https://console.cloud.google.com/apis/library/drive.googleapis.com?project=vaulty-511123
2. Google Auth Platform → Audience: use External / Testing and explicitly add your sign-in email under Test users. Add every friend's email before giving them a test APK. Setting a support or developer-contact email does not automatically add a test user.
3. Data Access: include `https://www.googleapis.com/auth/drive.appdata`. The SDK also requests standard identity permissions. Full-Drive access is not required.
4. Confirm the Android OAuth client is in the same project with:
   - Package: `app.vaulty.vaulty`
   - SHA-1: `23:4F:81:95:D7:A4:9E:C7:4B:2B:16:9C:23:93:69:93:59:56:05:68`
5. Confirm the supplied client ID is of type **Web application**, not Desktop or Android. Its screenshot alone shows enabled status, not all underlying registration settings.

Client settings: https://console.cloud.google.com/auth/clients?project=vaulty-511123

## Install and test Android first

1. Download the updated `Vaulty-backend-free.apk`. This is ARM64, Android 7.0/API 24 or newer, release-mode but development-signed.
2. Install it on your phone, allowing installation from that download source if Android asks. The configured APK uses version 0.3.0+3 and the same signing identity as the preceding backend-free APK; it includes the new Home, sharing, cache and incoming-import implementation.
3. Open Vaulty and sign in using the allowlisted test account. Grant its requested Drive app-data access.
4. Confirm the new vault is empty, then upload a disposable PDF or JPEG.
5. Close/reopen Vaulty and confirm the document remains available. Open/download it and verify its contents.
6. If sign-in fails, capture the error message without exposing credentials. Check API enablement, test users, Android package/SHA-1 and client type/project before changing code.

Do not uninstall a real-data installation as a first troubleshooting step. The original mock APK used a different signing identity; only that obsolete mock may require uninstalling before installing the newer signed app. Uninstalling clears device-local state.

## Browser version

The bundled public ID is also set in `Vaulty-web-preview.zip`. This does not automatically register a website origin.

- The ZIP contains a wrapper at `/` and the app at `/app/`; host its contents without changing this layout.
- Register the exact scheme + host + port of your static site in the Web client's Authorized JavaScript origins. Do not include `/app/` or any other path.
- For the provided Python preview server on your own computer, register `http://localhost:8080` and open `http://localhost:8080/app/`.
- For Flutter source development on port 7357, register `http://localhost:7357`.
- Public hosting should use a stable HTTPS origin that you control.
- Test Google sign-in in a standalone browser tab rather than an embedded preview. Clear stale browser/hosting caches after replacing static assets.
- Our popup/callback flow does not need a custom redirect server or a client secret.

## Current update

The public ID remains configured in **Vaulty 0.3.0+3**. Unlike the earlier 0.2 configuration-only package update, this release changes Dart/native code and is compiled again. See [V0_3_UPDATE.md](V0_3_UPDATE.md) and [VERIFICATION.md](VERIFICATION.md) for features and build/test evidence.

Each user has a separate vault in their own hidden Google Drive app-data folder. Other users do not need Cloud projects. Keep the private development signing backup private; give testers only the APK. Public production distribution still requires accurate policy/branding pages and applicable Google OAuth/Play requirements.
