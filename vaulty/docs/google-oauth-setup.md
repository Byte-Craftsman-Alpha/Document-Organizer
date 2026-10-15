# Vaulty — Google OAuth form values

Use the SAME Google Cloud project for both OAuth clients below. These values configure development/testing, not a production release. The current source now implements direct Google Sign-In and Drive access. It still requires your public Web client ID and correct Console registration before activation. See START_HERE.md. The earlier mock APK is obsolete.

## Screenshot 1 — Branding / App domain

For localhost development with the app in Testing, leave the optional website fields empty rather than supplying a made-up website:

| Field | Enter now |
|---|---|
| App name (higher on the form) | `Vaulty` |
| User support email | Your monitored email address |
| Application home page | Leave blank for now |
| Application privacy policy link | Leave blank for now |
| Application terms of service link | Leave blank for now |
| Authorized domains | Leave empty for localhost-only development |
| Developer contact information | Keep your existing email address |

Do not enter `localhost`, `google.com`, or a domain you do not control into the **Authorized domains** list. That list is different from **Authorized JavaScript origins** in the Web client.

For a hosted/public version, first deploy real app and policy pages on a stable domain you control and complete any domain/brand verification Google requests. The old temporary preview addresses are not production app domains. If Google requires website fields for your chosen verification flow, provide real hosted pages; do not invent links.

Separately set **Audience → External → Testing**, then **Test users → Add users** and add the Google account you will sign in with. A developer contact email is not a substitute for the Test users list.

## Screenshot 2 — Android OAuth client

| Field | Enter |
|---|---|
| Application type | `Android` |
| Name | `Vaulty Android Development` |
| Package name | `app.vaulty.vaulty` |
| SHA-1 certificate fingerprint | `23:4F:81:95:D7:A4:9E:C7:4B:2B:16:9C:23:93:69:93:59:56:05:68` |
| Verify app ownership (optional) | Skip for this development client |
| Use this client for an AI-powered agent | Leave unchecked |

Click **Create** and copy the **Client ID**.

### Which signing key does this fingerprint identify?

This is the actual SHA-1 of a NEW, reusable development signing key prepared for the next Android builds. The earlier temporary build key was not retained. This is NOT the signing fingerprint of the already-delivered mock `Vaulty-debug.apk`.

The working Android project's debug signing configuration now points to:

```
android/app/dev-signing/vaulty-debug.keystore
```

- Alias: `androiddebugkey`
- Store/key password: the conventional development-only password `android`
- Keystore type: JKS
- Purpose: development builds ONLY

The key is ignored by the project's existing `**/*.keystore` Git rule. Keep a private backup. Do not publish it, put it in a public web directory, or use it to sign a production app. The separate private signing backup includes this key. The current source already detects it at the documented path.

Restore only `android/app/dev-signing/vaulty-debug.keystore` from the private signing backup into the CURRENT source project. Do not overwrite current Gradle files with an older setup archive. The private backup is not an APK and must not be published.

Installing a future APK signed with this new key over the old mock APK will require uninstalling the old mock APK first. This removes that installed demo's local state. Do not uninstall a future real-data version without checking its data/backups.

Production/Play Store builds need an OAuth Android client for their actual app-signing certificate. If Play App Signing is used, register the Play app-signing certificate—not merely the upload certificate.

Verify this development key on your own machine with:

```sh
keytool -list -v \
  -keystore android/app/dev-signing/vaulty-debug.keystore \
  -alias androiddebugkey -storepass android
```

The certificate's public details are also recorded in `development-signing-certificate.txt`.

## Screenshot 3 — Web OAuth client

| Field | Enter |
|---|---|
| Application type | `Web application` |
| Name | `Vaulty Web Development` |
| Authorized JavaScript origins — first entry | `http://localhost` |
| Authorized JavaScript origins — second entry | `http://localhost:7357` |
| Authorized redirect URIs | Leave blank for the planned Google Identity Services popup/JavaScript-callback flow |
| Use this client for an AI-powered agent | Leave unchecked |

Add the two origins as TWO separate entries, not one comma-separated value. Origins must not contain `/app/`, `/#/login`, or another path.

Click **Create** and copy the **Web client ID** ending in `.apps.googleusercontent.com`. The Flutter Android Google Sign-In plugin can use this same Web client ID as `serverClientId` when both clients belong to the same project and the Android package/certificate are registered correctly.

**These localhost origins only authorize an app running on your computer at those origins. They do not authorize the hosted preview in this chat.** Before enabling hosted login, choose a stable HTTPS address and add its exact origin as an additional Authorized JavaScript origin. Do not treat an expired temporary tunnel address as a stable deployment.

A future backend authorization-code flow would require its own exact redirect URI. No callback server has been deployed, so no redirect address is being invented here.

## Drive access

Enable **Google Drive API** under **APIs & Services → Library**. Under **Google Auth Platform → Data Access**, add:

```
https://www.googleapis.com/auth/drive.appdata
```

Use the SDK's normal identity scopes for sign-in; do not request full-Drive access just to make private-vault storage work. Do not add extra sharing scopes until the separate sharing design is approved.

Private originals will remain in appData. Native Drive sharing and Drive Trash are not supported for appData files. A logical Trash and a separately implemented sharing/access-control layer are still needed.

## What to send back

Only these public configuration identifiers:

```
Google Cloud project ID:
Web OAuth client ID:
Android OAuth client ID:
```

Do NOT send a client secret, Google password, access token, refresh token, downloaded OAuth secret JSON, or your own production keystore. Configuring the Console alone does not change the running mock UI; the next step is supplying the Web client ID, rebuilding the implemented integration, and completing the real-account acceptance checklist.

## References

- [Google Identity Services client setup](https://developers.google.com/identity/gsi/web/guides/get-google-api-clientid)
- [Google OAuth consent setup](https://developers.google.com/workspace/guides/configure-oauth-consent)
- [Flutter Google Sign-In Android integration](https://pub.dev/packages/google_sign_in_android)
- [Flutter Google Sign-In Web integration](https://pub.dev/packages/google_sign_in_web)
