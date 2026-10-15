# Android profile-mode sign-off

**Status: not executed on a physical Android device in this workspace.** No 60/120 fps result is claimed. Widget tests and asset/kernel compilation cannot establish GPU frame times, TalkBack behavior, Impeller compatibility or APK runtime behavior.

## Reproduce

1. Install a current stable Flutter toolchain, Android SDK and supported JDK. Connect a physical Android device with USB debugging enabled.
2. Run `flutter pub get` and `flutter run --profile -d <device-id>`.
3. Confirm in the engine logs that Impeller is active on the selected device. Do not force a software renderer for performance acceptance.
4. Use Flutter DevTools Performance. Record **after** the initial installation/startup and capture cold first-load separately. Turn on the performance overlay when useful.
5. Sign in to the mock account, acknowledge the hidden-app-data notice, and let repository skeletons finish.

## Interaction pass

- Fling Documents end to end in both list and grid modes. Repeat after returning from another tab and after changing filters/sort.
- Navigate into and back out of a document. Inspect Hero continuity and route fade-through.
- Open/close source sheets, advanced filters, date/range pickers and confirmation dialogs repeatedly.
- Change light/dark/system theme. Check text, native system bars, menus, dialogs and sheets for abrupt tonal jumps.
- Upload a mock file, toggle renewal, validate missing fields, and inspect the progress and success states.
- Edit and immediately Undo; delete and immediately Undo before the mock write completes. Check that data and audit/share state settle consistently.
- Create/revoke a share and inspect the audit trail.
- Trigger the error scenario and retry each list and mutation. Ensure skeletons stop and the preserved form can retry.

## Frame-time acceptance

Record the device model, Android version, refresh rate, Flutter/engine version and renderer. Inspect UI and raster frame times independently.

- On a 60 Hz device, the frame budget is about **16.7 ms**.
- On a 120 Hz device, the frame budget is about **8.3 ms**.
- Sustained scrolling, gestures and transitions should stay within the device's frame budget without repeated missed frames. Investigate outliers rather than treating an average fps as sufficient.
- Export the actual DevTools trace and attach it to your release sign-off. Do not fill in frame-rate numbers from widget-test runtimes.

## Accessibility and layout pass

- Test 320dp width and 1.3× system text scaling. Automated route tests cover these dimensions, but native keyboards/date pickers and device insets still need inspection.
- Enable TalkBack. Inspect labels, traversal order, email-chip deletion, multi-select, snack-bar Undo and the accessible alternative to hold-to-delete.
- Verify 48dp targets with Android Accessibility Scanner. Automated theme tests verify the main semantic text/background pairs at 4.5:1 or higher; scan any platform-generated overlays too.
- Enable Android Remove animations. Verify no skeleton pulse, reveal delay or Hero movement, and immediate theme/bar transitions.
- Test system-theme changes while the app is backgrounded and then resumed.
- Inspect Android startup and navigation/status bars in both system themes.

## Known scope boundaries

The seed contains 40 documents. Larger production datasets require another performance run. The mock preview uses vector icons, not bitmap/PDF decoding. A real preview implementation must size/cache decoding, use `Metrics.thumbnailCache` for raster thumbnails, and be profiled again. No encryption, Drive synchronization or durable audit service is exercised here.
