import 'package:flutter_test/flutter_test.dart';
import 'package:vaulty/core/l10n/app_strings.dart';
import 'package:vaulty/core/l10n/hi.dart';

void main() {
  group('Hindi Localization Tests', () {
    test('Dictionary contains all core UI navigation and screens', () {
      expect(hi.containsKey('Home'), isTrue);
      expect(hi.containsKey('Documents'), isTrue);
      expect(hi.containsKey('Upload'), isTrue);
      expect(hi.containsKey('Settings'), isTrue);
      expect(hi.containsKey('Trash'), isTrue);
      expect(hi.containsKey('Review imports'), isTrue);
      expect(hi.containsKey('Import selected files'), isTrue);
      expect(hi.containsKey('Discard pending imports'), isTrue);
      expect(hi.containsKey('No pending files'), isTrue);
    });

    test('Translates exact keys accurately', () {
      expect(AppStrings.translate('Home', 'hi'), 'होम');
      expect(AppStrings.translate('Documents', 'hi'), 'दस्तावेज़');
      expect(AppStrings.translate('Upload', 'hi'), 'अपलोड');
      expect(AppStrings.translate('Settings', 'hi'), 'सेटिंग्स');
      expect(AppStrings.translate('Review imports', 'hi'), 'आयात की समीक्षा करें');
      expect(AppStrings.translate('Import selected files', 'hi'), 'चयनित फ़ाइलें आयात करें');
      expect(AppStrings.translate('No pending files', 'hi'), 'कोई लंबित फ़ाइल नहीं है');
    });

    test('Pattern translations replace dynamic parameters correctly', () {
      expect(AppStrings.translate('5 documents', 'hi'), '5 दस्तावेज़');
      expect(AppStrings.translate('3 selected', 'hi'), '3 चयनित');
      expect(AppStrings.translate('Due in 12 days', 'hi'), '12 दिनों में देय');
      expect(AppStrings.translate('Step 2 of 3', 'hi'), 'चरण 2 / 3');
      expect(AppStrings.translate('By newest', 'hi'), 'नवीनतम के अनुसार');
      expect(AppStrings.translate('By title', 'hi'), 'शीर्षक के अनुसार');
      expect(AppStrings.translate('Sort: expiry', 'hi'), 'क्रम: समाप्ति तिथि');
    });

    test('English passes through unchanged when language is en', () {
      expect(AppStrings.translate('Home', 'en'), 'Home');
      expect(AppStrings.translate('Documents', 'en'), 'Documents');
    });
  });
}

