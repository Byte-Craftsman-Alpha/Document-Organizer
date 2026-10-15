# Real-account acceptance — owner action required

The SDK/HTTP implementation is built without a Vaulty backend. These tests cannot be truthfully marked complete until the developer supplies a configured Google OAuth client and signs into test accounts.

- [ ] Configure Web client ID, Android package/certificate, Drive API and test-user allowlist.
- [ ] Install the newly signed build (uninstall the older differently signed mock APK first).
- [ ] Verify Google account selection, cancelled sign-in, denied Drive consent and successful consent.
- [ ] New account shows no documents; storage quota matches Google's account report where provided.
- [ ] Upload PDF, JPEG and DOCX. Restart and verify metadata and exact original bytes.
- [ ] Interrupt an upload, then retry; verify no duplicate committed file from the same form submission.
- [ ] Replace a file; verify its size/type and original download after refresh.
- [ ] Edit metadata on two devices; verify conflicts surface and refresh before retrying.
- [ ] Trash/restore, Undo, permanent delete and 30-day-on-sync retention using disposable files.
- [ ] Account A → sign out → account B; verify no A files, searches, notifications or cached previews appear under B.
- [ ] Switch accounts during an in-flight request; old response must be discarded.
- [ ] Revoke app authorization in Google account settings; verify reconnect rather than fake/seed results.
- [ ] Web authorization expires; reconnect through a fresh user gesture.
- [ ] Android camera/gallery permissions, image capture and source cancellation.
- [ ] Biometric enrollment, enable/disable confirmation, lock on background/resume, per-account/device isolation.
- [ ] Notification consent, future reminder, boot rescheduling and cancellation on sign-out. Test OEM battery restrictions.
- [ ] Export ZIP and inspect manifest plus original bytes. Keep exported copies private.
- [ ] Share a copy on Android; download a copy in browser. No revocation or expiry is promised.
- [ ] Delete Vaulty data: other Drive files remain unchanged; retry partial failures safely.
- [ ] Run profile-mode scrolling and accessibility checks on actual devices before public release.

Do not test permanent deletion with valuable originals. A failed or missing activity-history write must not be mistaken for proof that a file action did not occur.
