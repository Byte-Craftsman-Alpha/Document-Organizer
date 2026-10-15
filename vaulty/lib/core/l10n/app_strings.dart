import 'package:flutter/material.dart';
import 'hi.dart';

/// UI-only translations. Document titles, owners and tags stay verbatim.
abstract final class AppStrings {
  static String language='en';
  static final _patterns=hi.entries.where((e)=>e.key.contains('{')).map((e) {
    final slots=RegExp(r'\{(\w+)\}').allMatches(e.key).map((m)=>m.group(1)!).toList();
    var pattern=RegExp.escape(e.key);
    for(final slot in slots) {pattern=pattern.replaceFirst(RegExp.escape('{$slot}'),slot=='n'?r'([0-9]+)':r'([\s\S]+?)');}
    return (RegExp('^$pattern\$'),e.value,slots);
  }).toList();
  static String translate(String text,String code) {
    if(code!='hi') return text;
    if(hi.containsKey(text)) return hi[text]!;
    for(final entry in _patterns) {
      final match=entry.$1.firstMatch(text);if(match==null) continue;
      var result=entry.$2;
      for(var i=0;i<entry.$3.length;i++) {result=result.replaceAll('{${entry.$3[i]}}',match.group(i+1)!);}
      return result;
    }
    return text;
  }
}
extension AppTranslation on BuildContext {
  String tr(String text)=>AppStrings.translate(text,Localizations.localeOf(this).languageCode);
}
class AppText extends StatelessWidget {
  const AppText(this.data,{super.key,this.style,this.textAlign,this.maxLines,this.overflow,this.softWrap,this.semanticsLabel});
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final String? semanticsLabel;
  @override
  Widget build(BuildContext context)=>Text(context.tr(data),style:style,textAlign:textAlign,maxLines:maxLines,overflow:overflow,softWrap:softWrap,semanticsLabel:semanticsLabel==null?null:context.tr(semanticsLabel!));
}
