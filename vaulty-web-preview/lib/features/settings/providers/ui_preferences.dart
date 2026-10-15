import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UiPreferences {
  const UiPreferences({this.language='system',this.theme,this.onboarded=true});
  final String language;
  final String? theme;
  final bool onboarded;
}
final uiPreferencesProvider=StateNotifierProvider<UiPreferencesController,UiPreferences>((ref)=>UiPreferencesController());
class UiPreferencesController extends StateNotifier<UiPreferences> {
  UiPreferencesController({UiPreferences initial=const UiPreferences(),this.storage}):super(initial);
  final SharedPreferences? storage;
  Future<void> _queue=Future.value();
  static Future<UiPreferencesController> load() async {
    final p=await SharedPreferences.getInstance();
    return UiPreferencesController(storage:p,initial:UiPreferences(language:p.getString('vaulty.ui.language')??'system',theme:p.getString('vaulty.ui.theme'),onboarded:p.getBool('vaulty.ui.onboarded')??false));
  }
  Future<void> save({String? language,String? theme,bool? onboarded}) {
    final next=UiPreferences(language:language??state.language,theme:theme??state.theme,onboarded:onboarded??state.onboarded);
    state=next;
    final job=_queue.then((_) async {
      if(storage==null) return;
      await storage!.setString('vaulty.ui.language',next.language);
      if(next.theme!=null) await storage!.setString('vaulty.ui.theme',next.theme!);
      await storage!.setBool('vaulty.ui.onboarded',next.onboarded);
    });
    _queue=job.catchError((Object _) {});
    return job;
  }
}
final localeProvider=Provider<Locale?>((ref) {
  final code=ref.watch(uiPreferencesProvider).language;
  return code=='system'?null:Locale(code=='hi'?'hi':'en');
});
