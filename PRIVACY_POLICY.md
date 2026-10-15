# Privacy Policy for Vaulty

**Effective Date:** October 15, 2026  
**Last Updated:** October 15, 2026

**Vaulty** is developed by **Aditya Chaudhari** in collaboration with **Team Paradox**. Your privacy is paramount. This Privacy Policy details our commitment to absolute data sovereignty and explains how your information is handled when using Vaulty (the "Application").

---

## 1. Zero-Backend Architecture (True Privacy)

Vaulty operates on a **strictly decentralized, zero-backend architecture**:
- **No Third-Party Servers**: We do not maintain or operate any intermediary application servers, remote databases, telemetry platforms, or logging infrastructure.
- **No Analytics or Trackers**: Vaulty contains no tracking libraries, user profiling code, third-party advertising SDKs, or behavioral monitoring tools.
- **Direct Communication**: All network communications occur directly and securely between your device and Google's official OAuth 2.0 and Google Drive API endpoints over TLS 1.3 encryption.

---

## 2. Information We Process and Where It Lives

### A. Your Personal Documents
- **What**: Files you import or capture (PDFs, images, documents, invoices, identification cards, certificates).
- **Storage Location**: Stored exclusively in your personal **Google Drive Application Data folder** (`drive.appdata`). This folder is private to your Google account and hidden from regular Drive views to prevent accidental deletion or interference.
- **Local Cache**: On Android devices, documents you view are cached locally in an encrypted sandbox using **AES-256-GCM**, with encryption keys stored in your device's hardware-backed **Android KeyStore**.

### B. Document Metadata
- **What**: Document titles, owner tags, custom categories, creation timestamps, and user-specified renewal/expiration dates.
- **Storage Location**: Stored directly in Google Drive file properties and serialized in your hidden Google Drive app-data space.

### C. Google Account Information
- **What**: Account email address and display profile name returned by Google Sign-In.
- **Purpose**: Used strictly on-device to verify identity, manage multi-account isolation, and ensure API requests are scoped to the authenticated user.

### D. Biometric & Authentication Data
- If you enable Vaulty's Biometric Lock, authentication is handled entirely by your device operating system via Android BiometricPrompt / iOS LocalAuthentication. **Vaulty never has access to your raw fingerprint, facial geometry, or device PIN.**

---

## 3. Google API Services User Data Policy Compliance

Vaulty's use and transfer of information received from Google APIs adhere to the [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy), including the **Limited Use** requirements:

1. **Restricted Scope**: Vaulty requests only the minimum necessary scope (`https://www.googleapis.com/auth/drive.appdata`). Vaulty **cannot** view, read, or modify any files outside its designated hidden folder.
2. **No Human Access**: No human, developer, or third-party entity has access to your files or Google user data.
3. **No Commercial Transfer or Sale**: We never sell, lease, transfer, or disclose user data to advertisers, data brokers, or external entities.
4. **No AI Training**: Your documents and metadata are never utilized to train machine learning models or artificial intelligence systems.

---

## 4. Local Reminders & Notifications

Vaulty schedules renewal notifications directly on your Android operating system using the native `AlarmManager` and `NotificationManager`. Notification processing occurs 100% locally on your device without transmitting renewal dates to external servers.

---

## 5. Data Retention, Portability & Deletion

- **You Own Your Data**: You retain 100% ownership and control over all documents uploaded to Vaulty.
- **Backup & Export**: You can export an unencrypted ZIP archive containing all your files and metadata at any time via the Settings screen.
- **Permanent Deletion**:
  - Trashing a document moves it to the logical Trash Bin. After 30 days, or upon explicit purge, the file is permanently deleted from your Google Drive.
  - Using the in-app **"Delete My Data" / "मेरा डेटा हटाएं"** action immediately purges all files, cached envelopes, and metadata from your Google Drive app-data folder.

---

## 6. Children's Privacy

Vaulty is not directed toward individuals under the age of 13. Because Vaulty does not collect or transmit personal information to external servers, we do not knowingly gather data from minors.

---

## 7. Changes to this Privacy Policy

We may update this Privacy Policy periodically to reflect app updates or regulatory requirements. Any modifications will be committed directly to this repository with an updated effective date.

---

## 8. Contact Us

If you have questions, feedback, or concerns regarding your privacy or this policy, please contact:

- **Lead Developer**: Aditya Chaudhari
- **Email**: [aditya@teamparadox.in](mailto:aditya@teamparadox.in)
- **Website**: [aditya.teamparadox.in](https://aditya.teamparadox.in)
- **Organization**: Team Paradox ([teamparadox.in](https://teamparadox.in))

