# Contributing to Vaulty

Thank you for your interest in contributing to **Vaulty**! Vaulty is developed by **Aditya Chaudhari** in collaboration with **Team Paradox**. We welcome contributions from developers, designers, translators, and privacy enthusiasts.

Please take a moment to review this document before submitting your pull requests or filing issues.

---

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md). Please report any violations or concerns to [aditya@teamparadox.in](mailto:aditya@teamparadox.in).

---

## Getting Started

### Prerequisites

- **Flutter SDK**: `^3.27.0` (Dart `^3.6.0`)
- **Android SDK**: API level 35 target, minimum API level 26
- **Java**: OpenJDK 17
- Optional: Physical Android device or Android Emulator with Google Play Services (required for real Google Drive testing)

### Clone & Local Setup

```bash
# Clone the repository
git clone https://github.com/Byte-Craftsman-Alpha/Document-Organizer.git
cd Document-Organizer

# Navigate to Flutter application
cd vaulty

# Fetch dependencies
flutter pub get

# Run test suite
flutter test

# Run static analysis
flutter analyze
```

---

## Development Guidelines

### 1. Architectural Integrity
- Vaulty adheres to a strict **zero-backend architecture**. Do **NOT** introduce any third-party analytics SDKs, telemetry trackers, remote databases (Firebase, Supabase, etc.), or advertising platforms.
- The app talks directly to Google OAuth 2.0 and Google Drive API v3.
- All persistent document storage belongs in the user's hidden Google Drive Application Data folder (`drive.appdata`).

### 2. Design & UI Principles (Google Pixel / Material 3)
- Use **tokens and semantic theming** defined in `lib/core/theme/` (`app_colors.dart`, `app_tokens.dart`, `app_typography.dart`).
- **Never hardcode** raw colors, arbitrary paddings, or raw `TextStyle` literals inside UI components.
- Ensure minimum touch target size of **48 x 48 dp**.
- Maintain high contrast ratios (minimum 4.5:1 for body text) across both Light and Dark themes.
- Support smooth, snappy, bouncing gesture animations and 1.3x text accessibility scaling.

### 3. Internationalization (i18n / l10n)
- Never use raw unlocalized strings for user-facing UI labels. Use `AppText('label')` or `context.tr('label')`.
- User data (file names, tags, owner names, account emails) must **never** be translated and must always be rendered verbatim.
- When adding new UI text, update both `lib/core/l10n/app_strings.dart` and `lib/core/l10n/hi.dart` (Formal Hindi pack). Add accompanying tests in `test/l10n_test.dart`.

---

## Workflow & Pull Requests

### Branch Naming Conventions
- `feature/<feature-name>` (e.g. `feature/ocr-scanning-support`)
- `fix/<bug-description>` (e.g. `fix/import-button-spacing`)
- `docs/<doc-update>` (e.g. `docs/api-architecture`)
- `refactor/<component>` (e.g. `refactor/cache-envelope`)

### Commit Messages
We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <short description>

[optional body]

[optional footer(s)]
```

**Types:**
- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation changes
- `style`: Formatting, missing semi-colons, etc. (no code change)
- `refactor`: Code refactoring without behavior change
- `perf`: Performance optimization
- `test`: Adding or updating tests
- `chore`: Build scripts, workflow updates, package upgrades

### Pull Request Checklist
Before submitting a PR, verify:
- [ ] `flutter analyze` passes with **0 errors and 0 warnings**.
- [ ] `flutter test` executes with **100% test pass rate**.
- [ ] New UI features have been tested in both Light and Dark modes.
- [ ] All new text keys are localized in English and Hindi.
- [ ] Documentation comments and references have been updated.

---

## Questions and Support

For questions or discussions regarding design decisions, reach out to:
- **Lead Maintainer**: Aditya Chaudhari ([aditya@teamparadox.in](mailto:aditya@teamparadox.in))
- **Organization**: Team Paradox ([teamparadox.in](https://teamparadox.in))

