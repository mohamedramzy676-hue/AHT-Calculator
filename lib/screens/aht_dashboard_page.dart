import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  @override
  State<AhtDashboardPage> createState() => _AhtDashboardPageState();
}

class _AhtDashboardPageState extends State<AhtDashboardPage> {
  static const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  static const monthNames = ['January','February','March','April','May','June','July','August','September','October','November','December'];
  int selectedMonth = DateTime.now().month - 1;
  int target = 430;
  bool loading = true;
  final Map<int, List<CallEntry>> data = {};
  final quickCall = TextEditingController();

  List<CallEntry> get calls => data.putIfAbsent(selectedMonth, () => []);
  int get totalSeconds => calls.fold(0, (s, c) => s + c.total);
  int get aht => calls.isEmpty ? 0 : (totalSeconds / calls.length).round();
  int? get lastChange {
    if (calls.length < 2) return null;
    final oldTotal = calls.take(calls.length - 1).fold<int>(0, (s, c) => s + c.total);
    return aht - (oldTotal / (calls.length - 1)).round();
  }

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { quickCall.dispose(); super.dispose(); }

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

  String mmss(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  int? parseQuick(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    if (t.contains(':')) {
      final p = t.split(':');
      if (p.length != 2) return null;
      final m = int.tryParse(p[0]);
      final s = int.tryParse(p[1]);
      if (m == null || s == null || m < 0 || s < 0 || s > 59) return null;
      return m * 60 + s;
    }
    final sec = int.tryParse(t);
    return sec != null && sec > 0 ? sec : null;
  }

  Future<void> quickAdd() async {
    final sec = parseQuick(quickCall.text);
    if (sec == null || sec <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter call time as 6:30 or total seconds like 390.')));
      return;
    }
    setState(() => calls.add(CallEntry(talk: sec, hold: 0, acw: 0)));
    quickCall.clear();
    await _save();
  }

  Future<List<int>?> _detailsDialog(String title, [CallEntry? entry]) async {
    final values = [entry?.talk ?? 0, entry?.hold ?? 0, entry?.acw ?? 0];
    final ctrls = List.generate(6, (i) {
      final v = values[i ~/ 2];
      return TextEditingController(text: i.isEven ? (v ~/ 60 == 0 ? '' : '${v ~/ 60}') : (v % 60 == 0 ? '' : '${v % 60}'));
    });
    return showDialog<List<int>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 620,
          child: Row(
            children: List.generate(3, (x) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(['Talk Time','Hold / Waiting','After Call Work'][x], style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TextField(controller: ctrls[x*2], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Min', border: OutlineInputBorder()))),
                    const SizedBox(width: 6),
                    Expanded(child: TextField(controller: ctrls[x*2+1], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sec', border: OutlineInputBorder()))),
                  ]),
                ]),
              ),
            )),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            final out = <int>[];
            for (var x = 0; x < 3; x++) {
              final m = int.tryParse(ctrls[x*2].text) ?? 0;
              final s = int.tryParse(ctrls[x*2+1].text) ?? 0;
              if (m < 0 || s < 0 || s > 59) return;
              out.add(m * 60 + s);
            }
            if (out.reduce((a,b) => a+b) > 0) Navigator.pop(context, out);
          }, child: Text(entry == null ? 'Add Call' : 'Save Changes')),
        ],
      ),
    );
  }

  Future<void> addDetailed() async { final r = await _detailsDialog('Add Call Details'); if (r != null) { setState(() => calls.add(CallEntry(talk:r[0],hold:r[1],acw:r[2]))); await _save(); } }
  Future<void> editCall(int i) async { final r = await _detailsDialog('Edit Call', calls[i]); if (r != null) { setState(() => calls[i] = CallEntry(talk:r[0],hold:r[1],acw:r[2])); await _save(); } }
  Future<void> deleteCall(int i) async { setState(() => calls.removeAt(i)); await _save(); }
  Future<void> clearAll() async { setState(calls.clear); await _save(); }
  Future<void> editTarget() async {
    final c = TextEditingController(text: '$target');
    final r = await showDialog<int>(context: context, builder: (context) => AlertDialog(
      title: const Text('AHT Target'),
      content: TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText:'Target in seconds', border:OutlineInputBorder())),
      actions: [TextButton(onPressed:()=>Navigator.pop(context), child:const Text('Cancel')), FilledButton(onPressed:(){final v=int.tryParse(c.text);if(v!=null&&v>0)Navigator.pop(context,v);}, child:const Text('Save'))],
    ));
    if (r != null) { setState(() => target = r); await _save(); }
  }

  Widget stat(String title, String value, String sub, IconData icon, {Color? color}) => Card(
    child: Padding(padding: const EdgeInsets.all(15), child: Row(children: [
      CircleAvatar(child: Icon(icon)), const SizedBox(width:12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title), Text(value, style: TextStyle(fontSize:25,fontWeight:FontWeight.bold,color:color)), Text(sub,maxLines:1,overflow:TextOverflow.ellipsis)])),
    ])),
  );

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final diff = aht - target;
    final change = lastChange;
    return Scaffold(
      backgroundColor: const Color(0xfff5f8fc),
      body: SafeArea(
        child: Column(children: [
          Container(color: const Color(0xff172b42), padding: const EdgeInsets.symmetric(horizontal:24,vertical:12), child: Row(children: [
            const Icon(Icons.bar_chart_rounded,color:Colors.blueAccent,size:32), const SizedBox(width:10), const Text('AHT Pulse',style:TextStyle(color:Colors.white,fontSize:25,fontWeight:FontWeight.bold)), const Spacer(),
            OutlinedButton.icon(onPressed:editTarget,icon:const Icon(Icons.edit,color:Colors.white),label:Text('Target $target sec (${mmss(target)})',style:const TextStyle(color:Colors.white))),
          ])),
          SizedBox(height:58, child: ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.all(7),children:List.generate(12,(i)=>Padding(padding:const EdgeInsets.symmetric(horizontal:3),child:ChoiceChip(label:Text(months[i]),selected:selectedMonth==i,onSelected:(_)=>setState(()=>selectedMonth=i))))))),
          Padding(
            padding: const EdgeInsets.fromLTRB(18,6,18,10),
            child: LayoutBuilder(builder: (context,b) => GridView.count(
              crossAxisCount: b.maxWidth > 900 ? 4 : 2, shrinkWrap:true, physics:const NeverScrollableScrollPhysics(), childAspectRatio:b.maxWidth>900?2.7:1.9, crossAxisSpacing:10, mainAxisSpacing:10,
              children: [
                stat('Current AHT',calls.isEmpty?'--':'$aht sec',calls.isEmpty?'No calls':'${mmss(aht)} • ${diff<=0?'Target met':'${diff.abs()} sec above target'}',Icons.bar_chart,color:calls.isEmpty?null:diff<=0?Colors.green:Colors.red),
                stat('Target','$target sec',mmss(target),Icons.track_changes),
                stat('Last Call Change',change==null?'--':'${change>0?'+':''}$change sec',change==null?'Add more calls':change<=0?'AHT improved':'AHT increased',change!=null&&change<=0?Icons.trending_down:Icons.trending_up,color:change==null?null:change<=0?Colors.green:Colors.red),
                stat('Total Calls','${calls.length}','$totalSeconds total seconds',Icons.phone),
              ],
            )),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18,0,18,24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth:1450),
                  child: Column(children: [
                    Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
                      const Icon(Icons.bolt,color:Colors.amber,size:30), const SizedBox(width:10), const Text('Quick Call Time',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)), const SizedBox(width:16),
                      Expanded(child: TextField(controller:quickCall,autofocus:true,keyboardType:TextInputType.text,inputFormatters:[FilteringTextInputFormatter.allow(RegExp(r'[0-9:]'))],onSubmitted:(_)=>quickAdd(),decoration:const InputDecoration(hintText:'Type 6:30 or 390 seconds',prefixIcon:Icon(Icons.timer_outlined),border:OutlineInputBorder(),isDense:true))),
                      const SizedBox(width:10), FilledButton.icon(onPressed:quickAdd,icon:const Icon(Icons.add),label:const Text('Add')), const SizedBox(width:6), TextButton.icon(onPressed:addDetailed,icon:const Icon(Icons.tune),label:const Text('Add Hold / ACW')),
                    ]))),
                    const SizedBox(height:10),
                    Row(children:[Text('${monthNames[selectedMonth]} ${DateTime.now().year}',style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),const Spacer(),if(calls.isNotEmpty)TextButton.icon(onPressed:clearAll,icon:const Icon(Icons.delete_sweep,color:Colors.red),label:const Text('Clear month',style:TextStyle(color:Colors.red)))]),
                    const SizedBox(height:8),
                    if (calls.isEmpty)
                      Card(child: Padding(padding:const EdgeInsets.all(32),child:Center(child:Text('No calls yet. Type the call time above and press Enter.',style:Theme.of(context).textTheme.titleMedium))))
                    else
                      Card(child: Padding(padding:const EdgeInsets.all(10),child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(
                        columns: const [DataColumn(label:Text('#')),DataColumn(label:Text('Call Time')),DataColumn(label:Text('Hold')),DataColumn(label:Text('ACW')),DataColumn(label:Text('Total (Sec)')),DataColumn(label:Text('AHT MTD')),DataColumn(label:Text('Change')),DataColumn(label:Text('Actions'))],
                        rows: List.generate(calls.length,(i){
                          final c=calls[i]; final upto=calls.take(i+1).fold<int>(0,(s,x)=>s+x.total); final run=(upto/(i+1)).round(); final prev=i==0?null:(calls.take(i).fold<int>(0,(s,x)=>s+x.total)/i).round(); final d=prev==null?null:run-prev;
                          return DataRow(cells:[DataCell(Text('${i+1}')),DataCell(Text(mmss(c.talk),style:const TextStyle(fontWeight:FontWeight.bold))),DataCell(Text(mmss(c.hold))),DataCell(Text(mmss(c.acw))),DataCell(Text('${c.total}',style:const TextStyle(fontWeight:FontWeight.bold))),DataCell(Text('$run sec')),DataCell(Text(d==null?'-':'${d>0?'+':''}$d ${d>0?'↑':d<0?'↓':''}',style:TextStyle(color:d==null?null:d<=0?Colors.green:Colors.red,fontWeight:FontWeight.bold))),DataCell(Row(children:[IconButton(onPressed:()=>editCall(i),icon:const Icon(Icons.edit,color:Colors.blue)),IconButton(onPressed:()=>deleteCall(i),icon:const Icon(Icons.delete_outline,color:Colors.red))]))]);
                        }),
                      )))),
                    const SizedBox(height:12),
                    Card(child:Padding(padding:const EdgeInsets.all(18),child:Row(children:[const Icon(Icons.emoji_events_outlined,size:32),const SizedBox(width:12),Expanded(child:Text('Monthly Summary • ${calls.length} calls • $totalSeconds sec • ${calls.isEmpty?'No AHT yet':'AHT MTD $aht sec (${mmss(aht)})'}',style:const TextStyle(fontSize:17,fontWeight:FontWeight.w600))),if(calls.isNotEmpty)Chip(label:Text(diff<=0?'TARGET MET':'TARGET NOT MET'),backgroundColor:diff<=0?Colors.green.shade100:Colors.red.shade100)]))),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
