# Verification — Vaulty 0.3.0+3

## Automated checks

- **54 tests passed**, two opt-in screenshot tests skipped in the ordinary suite. The dedicated v3 screenshot test was run separately and passed, generating explicitly mock light/dark Home and Settings images under `docs/screens/v3/`.
- Dart analyzer: **no issues**.
- Theme styling-boundary audit: **pass**.
- Existing coverage includes 320 dp / 1.3x text in both themes, long names/grid layouts, reduced motion, contrast >= 4.5:1, metadata/Trash/Undo flows, token-owner checks, account switches, stale rollbacks and preservation of forms beneath the biometric overlay.
- New tests cover encryption round-trip/recreation with mocked secure storage, ciphertext lacking plaintext, tamper rejection, large-file encryption/decryption through a worker isolate, account isolation, coalesced reads, no repeated media download for an unchanged version, remote/local version invalidation, offline index/file restoration, uncached-file failure, no cache fallback on 401/403/404, binary cache-envelope validation, local browsing recents, content-type detection, arbitrary ZIP rejection, direct share capability invocation and multi-import validation/retry without duplicating successes at 320 dp / 1.3x text.

The Keystore plugin is mocked in encryption unit tests. This tests AES-GCM cache behavior, not physical-device Keystore hardware or biometric resistance. Incoming-share widget tests mock the platform channel; they do not prove that every external Android app grants valid URI permissions.

## Build method

Flutter 3.47.7 / Dart 3.13.5, Java 21, Android SDK/build-tools 36, NDK 28.2, Gradle 9.3.1, AGP 9.1. The sandbox has approximately 2 GB RAM. Android uses staged Flutter AOT assembly followed by Gradle packaging (one worker, 1 GB heap, temporary swap); Kotlin code is compiled by Gradle. Java/resource shrinking is disabled for this low-memory development package, not Dart AOT compilation.

```sh
flutter assemble --no-version-check \
  --output=build/app/intermediates/flutter/release \
  --depfile=build/app/intermediates/flutter/release/flutter_build.d \
  -dTargetFile=lib/main.dart -dTargetPlatform=android -dBuildMode=release \
  -dAndroidArchs=android-arm64 -dMinSdkVersion=24 \
  android_aot_bundle_release_android-arm64
cd android
./gradlew :app:assembleRelease -x :app:compileFlutterBuildRelease \
  -Ptarget-platform=android-arm64 -Ptarget=lib/main.dart \
  -Pkotlin.compiler.execution.strategy=in-process -PvaultyLowMemoryBuild=true \
  --max-workers=1 --no-daemon \
  '-Dorg.gradle.jvmargs=-Xmx1024m -XX:MaxMetaspaceSize=512m -XX:ReservedCodeCacheSize=96m -XX:ActiveProcessorCount=2 -XX:+UseSerialGC'
```

Do not skip the Flutter Gradle task without fresh AOT/assets. On a normal development computer, use `flutter build apk --release --target-platform android-arm64` instead. Source and native integrity/signature checks are recorded in `tool/artifact-v3.log`; the APK is ARM64, release-mode, **development-signed**, with the same prepared certificate and public OAuth client ID. It is not a production-signed Play release.

## Logs

- `tool/test-v3-final.log`, `test-cache-v3.log`, `test-imports-v3.log`, `capture-v3.log`
- `tool/analyze-v3.log`, `styling-v3.log`
- `tool/build-aot-v3-final.log`, `build-android-v3-final.log`, `build-web-v3.log`, `artifact-v3.log`

Earlier version logs are historical, not evidence of a current build. Generated mock screenshots are for visual review, not real Google acceptance.

## Still requires a real phone/account

- Upgrade install, actual Google OAuth, Drive upload/download/replacement and remote-change behavior.
- Android cold/warm SEND and SEND_MULTIPLE from file managers, galleries and other apps, correct filenames/MIME types, transient URI grants and denied/revoked attachments.
- Actual system chooser handoff and recipients reading the file successfully.
- Persistent offline restart, Keystore behavior, biometric gating, encrypted staging cleanup and crash/reboot behavior on the target Android version.
- Native PDF rendering, camera/gallery, external DOCX/HEIC viewers and reminder permission/timing.
- Performance/frame-rate/thermal behavior, TalkBack, native accessibility and browser-specific Google/Web Share restrictions.

Complete the disposable-file checklist in `V0_3_UPDATE.md` before broad distribution. No actual user account or private Drive documents were accessed by the assistant during this update.
