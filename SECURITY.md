# Security Policy

At **Vaulty** and **Team Paradox**, security and user privacy are foundational architectural pillars. Vaulty is intentionally engineered with a zero-backend, zero-knowledge architecture where your private personal documents never pass through any intermediate server.

---

## Supported Versions

Only the latest active minor release receives active security patches.

| Version | Supported          |
| ------- | ------------------ |
| 0.3.x   | :white_check_mark: |
| < 0.3.0 | :x:                |

---

## Security Architecture & Threat Model

Vaulty implements strict defense-in-depth principles:

1. **Zero-Backend Architecture**: The mobile application and web client communicate directly and exclusively with official Google OAuth 2.0 and Google Drive v3 REST APIs. No third-party proxy, database, analytics tracker, or storage server ever touches user credentials or document binaries.
2. **Dedicated App-Data Scope (`drive.appdata`)**: Vaulty requests authorization exclusively to access its own hidden Google Drive Application Data folder. It has no permission or technical capability to view, read, or modify any other files in the user's Google Drive.
3. **Android Keystore-Backed Hardware Security**: 
   - Local document caching uses AES-256-GCM authenticated encryption.
   - Symmetric cryptographic keys are generated per-account and securely retained inside the hardware-backed Android KeyStore / Secure Element.
   - Cache envelopes verify integrity through cryptographic authentication tags.
4. **Biometric Screen Lock (`local_auth`)**:
   - Optional local app lock authenticates the user via device biometrics (Fingerprint / Face Unlock / Device PIN).
   - Biometric keys remain strictly local on the device operating system.
5. **Transient Sharing Sandboxing**:
   - Outgoing exports and previews decrypt temporary copies strictly within private app-specific cache space or scoped file providers (`FileProvider`).

---

## Reporting a Vulnerability

If you discover a security vulnerability or potential threat in Vaulty, please do **NOT** open a public GitHub issue. 

Please follow responsible disclosure by emailing the lead maintainer directly:

- **Lead Developer**: Aditya Chaudhari
- **Email**: [aditya@teamparadox.in](mailto:aditya@teamparadox.in)
- **Subject Line**: `[SECURITY VULNERABILITY] Vaulty - <Short Description>`

### Please include in your report:
- A detailed description of the vulnerability.
- Steps to reproduce the issue (proof-of-concept script, reproduction steps, or screen recording).
- Affected platform (Android version, device model, or browser engine).
- Potential impact and suggested mitigations (if known).

### Our Commitment:
- **Initial Acknowledgment**: Within 48 hours of receipt.
- **Triage & Assessment**: Within 5 business days.
- **Fix & Public Advisory**: Coordinated release schedule with credit provided to the researcher.

