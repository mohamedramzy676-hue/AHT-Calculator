import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CallEntry {
  CallEntry({required this.talk, required this.hold, required this.acw});
  int talk, hold, acw;
  int get total => talk + hold + acw;
  Map<String, dynamic> toJson() => {'talk': talk, 'hold': hold, 'acw': acw};
  factory CallEntry.fromJson(Map<String, dynamic> j) => CallEntry(talk: j['talk'] ?? 0, hold: j['hold'] ?? 0, acw: j['acw'] ?? 0);
}

class AhtDashboardPage extends StatefulWidget {
  const AhtDashboardPage({super.key});
  @override State<AhtDashboardPage> createState() => _AhtDashboardPageState();
}

class _AhtDashboardPageState extends State<AhtDashboardPage> {
  static const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  static const monthNames = ['January','February','March','April','May','June','July','August','September','October','November','December'];
  int selectedMonth = DateTime.now().month - 1;
  int target = 430;
  bool loading = true;
  final Map<int, List<CallEntry>> data = {};

  List<CallEntry> get calls => data.putIfAbsent(selectedMonth, () => []);
  int get totalSeconds => calls.fold(0, (s, c) => s + c.total);
  int get aht => calls.isEmpty ? 0 : (totalSeconds / calls.length).round();
  int? get lastChange {
    if (calls.length < 2) return null;
    final before = calls.take(calls.length - 1).fold<int>(0, (s, c) => s + c.total) / (calls.length - 1);
    return aht - before.round();
  }

  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    target = p.getInt('target_seconds') ?? 430;
    for (var m = 0; m < 12; m++) {
      final raw = p.getString('aht_month_$m');
      if (raw != null) data[m] = (jsonDecode(raw) as List).map((e) => CallEntry.fromJson(Map<String,dynamic>.from(e))).toList();
    }
    if (mounted) setState(() => loading = false);
  }
  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('target_seconds', target);
    await p.setString('aht_month_$selectedMonth', jsonEncode(calls.map((e) => e.toJson()).toList()));
  }
  String mmss(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2,'0')}';

  Future<List<int>?> _timeDialog(String title, [CallEntry? entry]) async {
    final values = [entry?.talk ?? 0, entry?.hold ?? 0, entry?.acw ?? 0];
    final ctrls = List.generate(6, (i) => TextEditingController(text: i.isEven && values[i ~/ 2] ~/ 60 > 0 ? '${values[i ~/ 2] ~/ 60}' : i.isOdd && values[i ~/ 2] % 60 > 0 ? '${values[i ~/ 2] % 60}' : ''));
    return showDialog<List<int>>(context: context, builder: (context) => AlertDialog(
      title: Text(title), content: SizedBox(width: 620, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: List.generate(3, (x) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(['Talk Time','Hold / Waiting','After Call Work'][x], style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), Row(children: [Expanded(child: TextField(controller: ctrls[x*2], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText:'Min', border: OutlineInputBorder()))), const SizedBox(width: 6), Expanded(child: TextField(controller: ctrls[x*2+1], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText:'Sec', border: OutlineInputBorder())))] )]))))),
      ])), actions: [TextButton(onPressed:()=>Navigator.pop(context), child:const Text('Cancel')), FilledButton(onPressed:(){
        final out=<int>[]; for(var x=0;x<3;x++){final m=int.tryParse(ctrls[x*2].text)??0; final s=int.tryParse(ctrls[x*2+1].text)??0; if(m<0||s<0||s>59)return; out.add(m*60+s);} if(out.reduce((a,b)=>a+b)>0) Navigator.pop(context,out);
      }, child: Text(entry==null?'Add Call':'Save Changes'))]
    ));
  }

  Future<void> addCall() async { final r=await _timeDialog('Add Call'); if(r!=null){setState(()=>calls.add(CallEntry(talk:r[0],hold:r[1],acw:r[2]))); await _save();} }
  Future<void> editCall(int i) async { final r=await _timeDialog('Edit Call', calls[i]); if(r!=null){setState(()=>calls[i]=CallEntry(talk:r[0],hold:r[1],acw:r[2])); await _save();} }
  Future<void> deleteCall(int i) async { setState(()=>calls.removeAt(i)); await _save(); }
  Future<void> clearAll() async { setState(calls.clear); await _save(); }
  Future<void> editTarget() async { final c=TextEditingController(text:'$target'); final r=await showDialog<int>(context:context,builder:(context)=>AlertDialog(title:const Text('AHT Target'),content:TextField(controller:c,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Target in seconds',border:OutlineInputBorder())),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:(){final v=int.tryParse(c.text);if(v!=null&&v>0)Navigator.pop(context,v);},child:const Text('Save'))])); if(r!=null){setState(()=>target=r);await _save();}}

  Widget stat(String title,String value,String sub,IconData icon,{Color? color}) => Card(child: Padding(padding:const EdgeInsets.all(18),child:Row(children:[CircleAvatar(child:Icon(icon)),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title),Text(value,style:TextStyle(fontSize:28,fontWeight:FontWeight.bold,color:color)),Text(sub)]))])));

  @override Widget build(BuildContext context) {
    if(loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    final diff=aht-target; final change=lastChange;
    return Scaffold(backgroundColor:const Color(0xfff5f8fc),body:SafeArea(child:Column(children:[
      Container(color:const Color(0xff172b42),padding:const EdgeInsets.symmetric(horizontal:24,vertical:16),child:Row(children:[const Icon(Icons.bar_chart_rounded,color:Colors.blueAccent,size:34),const SizedBox(width:12),const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('AHT Pulse',style:TextStyle(color:Colors.white,fontSize:27,fontWeight:FontWeight.bold)),Text('Track. Improve. Achieve.',style:TextStyle(color:Colors.white70))]),const Spacer(),OutlinedButton.icon(onPressed:editTarget,icon:const Icon(Icons.edit,color:Colors.white),label:Text('Target ${mmss(target)} ($target sec)',style:const TextStyle(color:Colors.white))) ])),
      SizedBox(height:64,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.all(8),children:List.generate(12,(i)=>Padding(padding:const EdgeInsets.symmetric(horizontal:3),child:ChoiceChip(label:Text(months[i]),selected:selectedMonth==i,onSelected:(_)=>setState(()=>selectedMonth=i))))),),
      Expanded(child:LayoutBuilder(builder:(context,box)=>SingleChildScrollView(padding:const EdgeInsets.all(18),child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1450),child:Column(children:[
        Row(children:[Text('${monthNames[selectedMonth]} ${DateTime.now().year}',style:const TextStyle(fontSize:24,fontWeight:FontWeight.bold)),const Spacer(),FilledButton.icon(onPressed:addCall,icon:const Icon(Icons.add_call),label:const Text('Add Call'))]),const SizedBox(height:14),
        if(calls.isEmpty) Card(child:Padding(padding:const EdgeInsets.all(36),child:Center(child:Column(children:[const Icon(Icons.call_outlined,size:48),const SizedBox(height:10),Text('No calls in ${monthNames[selectedMonth]} yet.',style:const TextStyle(fontSize:18)),const SizedBox(height:12),FilledButton(onPressed:addCall,child:const Text('Add your first call'))])))) else Card(child:Padding(padding:const EdgeInsets.all(12),child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(columns:const [DataColumn(label:Text('#')),DataColumn(label:Text('Talk')),DataColumn(label:Text('Hold')),DataColumn(label:Text('ACW')),DataColumn(label:Text('Total Time')),DataColumn(label:Text('Total (Sec)')),DataColumn(label:Text('AHT (Sec)')),DataColumn(label:Text('Change')),DataColumn(label:Text('Actions'))],rows:List.generate(calls.length,(i){final c=calls[i];final upto=calls.take(i+1).fold<int>(0,(s,x)=>s+x.total);final run=(upto/(i+1)).round();final prev=i==0?null:(calls.take(i).fold<int>(0,(s,x)=>s+x.total)/i).round();final d=prev==null?null:run-prev;return DataRow(cells:[DataCell(Text('${i+1}')),DataCell(Text(mmss(c.talk))),DataCell(Text(mmss(c.hold))),DataCell(Text(mmss(c.acw))),DataCell(Text(mmss(c.total))),DataCell(Text('${c.total}',style:const TextStyle(fontWeight:FontWeight.bold))),DataCell(Text('$run')),DataCell(Text(d==null?'-':'${d>0?'+':''}$d ${d>0?'↑':d<0?'↓':''}',style:TextStyle(color:d==null?null:d<=0?Colors.green:Colors.red,fontWeight:FontWeight.bold))),DataCell(Row(children:[IconButton(onPressed:()=>editCall(i),icon:const Icon(Icons.edit,color:Colors.blue)),IconButton(onPressed:()=>deleteCall(i),icon:const Icon(Icons.delete_outline,color:Colors.red))]))]);}))))),
        if(calls.isNotEmpty) Align(alignment:Alignment.centerRight,child:TextButton.icon(onPressed:clearAll,icon:const Icon(Icons.delete_sweep,color:Colors.red),label:const Text('Clear month',style:TextStyle(color:Colors.red)))),const SizedBox(height:12),
        GridView.count(crossAxisCount:box.maxWidth>900?4:2,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),childAspectRatio:box.maxWidth>900?2.4:1.8,crossAxisSpacing:10,mainAxisSpacing:10,children:[stat('Current AHT',calls.isEmpty?'--':'$aht sec',calls.isEmpty?'No calls':'${mmss(aht)} • ${diff<=0?'Target met':'${diff.abs()} sec above target'}',Icons.bar_chart,color:calls.isEmpty?null:diff<=0?Colors.green:Colors.red),stat('Target','$target sec',mmss(target),Icons.track_changes),stat('Last Call Change',change==null?'--':'${change>0?'+':''}$change sec',change==null?'Add more calls':change<=0?'AHT improved':'AHT increased',change!=null&&change<=0?Icons.trending_down:Icons.trending_up,color:change==null?null:change<=0?Colors.green:Colors.red),stat('Total Calls','${calls.length}','$totalSeconds total seconds',Icons.phone)]),const SizedBox(height:12),
        Card(child:Padding(padding:const EdgeInsets.all(20),child:Row(children:[const Icon(Icons.emoji_events_outlined,size:34),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Monthly Summary - ${monthNames[selectedMonth]}',style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),const SizedBox(height:8),Text('${calls.length} calls • $totalSeconds handling seconds • ${calls.isEmpty?'No AHT yet':'AHT $aht sec (${mmss(aht)})'}') ])),if(calls.isNotEmpty)Chip(label:Text(diff<=0?'TARGET MET':'TARGET NOT MET'),backgroundColor:diff<=0?Colors.green.shade100:Colors.red.shade100)]))),
      ]))))))
    ])));
  }
}
