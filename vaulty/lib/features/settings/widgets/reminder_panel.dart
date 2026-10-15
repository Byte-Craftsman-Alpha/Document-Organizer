import 'package:flutter/material.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/utils/format.dart';
import '../../../data/device/renewal_bridge.dart';
class ReminderPanel extends StatefulWidget {
  const ReminderPanel({super.key});
  @override
  State<ReminderPanel> createState()=>_ReminderPanelState();
}
class _ReminderPanelState extends State<ReminderPanel> with WidgetsBindingObserver {
  Map<String,dynamic>? status;bool busy=false;
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);refresh();}
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.resumed)refresh();}
  Future<void> refresh()async {try{final value=await RenewalBridge.instance.status();if(mounted)setState(()=>status=value);}catch(_){}}
  Future<void> run(bool test)async {if(busy)return;setState(()=>busy=true);try{if(test){await RenewalBridge.instance.test();}else{await RenewalBridge.instance.check();}await refresh();if(mounted)notice(context,test?'Test notification sent':'Renewal check finished');}catch(_){if(mounted)notice(context,'Couldn’t run notifications. Check Android notification settings.');}finally{if(mounted)setState(()=>busy=false);}}
  @override Widget build(BuildContext context) {
    if(!RenewalBridge.instance.supported)return const AppText('Renewal notifications are available in the Android app.');
    final checked=status?['lastCheck'] as int? ??0;
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      if(status!=null)AppText(status!['allowed']==true?'Android notifications allowed':'Android notifications blocked',style:context.mutedCaption),
      if(checked>0)AppText('Last checked: ${eventTime(DateTime.fromMillisecondsSinceEpoch(checked))}',style:context.mutedCaption),
      const SizedBox(height:Space.sm),
      Wrap(spacing:Space.xs,runSpacing:Space.xs,children:[AppButton(label:'Test notification',secondary:true,onPressed:busy?null:()=>run(true)),AppButton(label:'Check renewals now',secondary:true,onPressed:busy?null:()=>run(false))]),
      const SizedBox(height:Space.sm),
      const AppText('Reminders use your last synced renewal dates. Checks run about every 6 hours and after reboots, with one daily reminder while renewal is due. Open Vaulty to fetch changes from other devices. Android battery limits may delay delivery; reopen Vaulty after force-stop.'),
    ]);
  }
}
