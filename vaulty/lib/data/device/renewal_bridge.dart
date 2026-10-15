import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../core/l10n/app_strings.dart';

class RenewalBridge {
  static final instance = RenewalBridge();
  static const channel = MethodChannel('app.vaulty/renewals');
  final requests = ValueNotifier(0);
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  void initialize() {
    if (supported) {
      channel.setMethodCallHandler((call) async {
        if (call.method == 'openHome') {
          requests.value++;
        }
      });
    }
  }

  Future<bool> takeOpen() async => supported
      ? (await channel.invokeMethod<bool>('takeOpen') ?? false)
      : false;
  Future<Map<String, dynamic>> status() async => supported
      ? Map<String, dynamic>.from(
          await channel.invokeMethod<Map>('status') ?? {},
        )
      : {};
  Future<void> test() async {
    if (supported) {
      await channel.invokeMethod<void>('test', {
        'language': AppStrings.language,
      });
    }
  }

  Future<void> check() async {
    if (supported) {
      await channel.invokeMethod<void>('check');
    }
  }

  Future<void> language(String code) async {
    if (supported) {
      await channel.invokeMethod<void>('language', {'language': code});
    }
  }
}
