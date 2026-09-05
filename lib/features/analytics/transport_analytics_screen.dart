import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'analytics_models.dart';
import 'transport_analytics_service.dart';

class TransportAnalyticsScreen extends StatefulWidget {
  const TransportAnalyticsScreen({super.key});
  @override State<TransportAnalyticsScreen> createState()=>_TransportAnalyticsScreenState();
}

class _TransportAnalyticsScreenState extends State<TransportAnalyticsScreen> {
  final _service=TransportAnalyticsService(); int _tab=0; String? _station;
  late Future<List<RidershipPoint>> _headline; late Future<KomuterAnalytics> _komuter;
  @override void initState(){super.initState();_load();}
  void _load(){_headline=_service.loadHeadline();_komuter=_service.loadKomuter();}
  Future<void> _refresh() async {_service.refresh();setState(_load);await Future.wait([_headline,_komuter]);}

  @override Widget build(BuildContext context){
    return Scaffold(body:SafeArea(child:RefreshIndicator(onRefresh:_refresh,child:ListView(padding:const EdgeInsets.all(18),children:[
      Row(children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Transport Analytics',style:TextStyle(fontSize:25,fontWeight:FontWeight.w900)),Text('Network demand & passenger flow',style:TextStyle(color:AppColors.muted))])),IconButton.filledTonal(onPressed:_refresh,icon:const Icon(Icons.refresh_rounded))]),
      const SizedBox(height:14),Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:AppColors.primary.withValues(alpha:.08),borderRadius:BorderRadius.circular(15)),child:const Row(children:[Icon(Icons.verified_rounded,color:AppColors.primary),SizedBox(width:10),Expanded(child:Text('Government data from data.gov.my • KTMB • Ministry of Transport',style:TextStyle(fontWeight:FontWeight.w700)))])),
      const SizedBox(height:14),SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:List.generate(4,(i)=>Padding(padding:const EdgeInsets.only(right:8),child:ChoiceChip(selected:_tab==i,label:Text(['Overview','Flow','Station','Peak'][i]),onSelected:(_)=>setState(()=>_tab=i)))))),
      const SizedBox(height:18),FutureBuilder<List<RidershipPoint>>(future:_headline,builder:(context,h){return FutureBuilder<KomuterAnalytics>(future:_komuter,builder:(context,k){if(h.connectionState!=ConnectionState.done||k.connectionState!=ConnectionState.done)return const Padding(padding:EdgeInsets.only(top:100),child:Center(child:Column(children:[CircularProgressIndicator(),SizedBox(height:12),Text('Loading Government ridership data...')])));if(h.hasError||k.hasError)return _ErrorCard('${h.error??k.error}',_refresh);final headline=h.data??[];final komuter=k.data!;return [_overview(headline,komuter),_flow(komuter),_stationView(komuter),_peak(komuter)][_tab];});})
    ]))));
  }

  Widget _overview(List<RidershipPoint> points,KomuterAnalytics k){
    final latest=points.isEmpty?null:points.last;final ranking=latest?.values.entries.toList()??[];ranking.sort((a,b)=>b.value.compareTo(a.value));final trend=points.length>14?points.sublist(points.length-14):points;
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:2,mainAxisSpacing:10,crossAxisSpacing:10,childAspectRatio:1.25,children:[_Metric('All-mode trips',_n(latest?.total??0),Icons.directions_transit),_Metric('Busiest mode',ranking.isEmpty?'Unavailable':ranking.first.key,Icons.emoji_events),_Metric('Komuter trips',_n(k.latestDayTotal),Icons.train),_Metric('Top stations','${k.stationActivity.length}',Icons.location_city)]),
      const _Title('Ridership Trend','Latest published days'),_Bars(values:trend.map((e)=>e.total).toList(),labels:trend.map((e)=>'${e.date.day}').toList()),
      const _Title('Transport Mode Comparison','Latest Government headline data'),...ranking.take(7).map((e)=>_RankRow(e.key,e.value,ranking.isEmpty?1:ranking.first.value)),
      const _Title('Busiest KTM Komuter Stations','Arrivals + departures'),...k.stationActivity.take(7).toList().asMap().entries.map((e)=>ListTile(leading:CircleAvatar(child:Text('${e.key+1}')),title:Text(e.value.station,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${_n(e.value.departures)} departures • ${_n(e.value.arrivals)} arrivals'),trailing:Text(_n(e.value.activity),style:const TextStyle(fontWeight:FontWeight.w900))))
    ]);
  }

  Widget _flow(KomuterAnalytics k){final origins=k.destinationsByOrigin.keys.toList()..sort();_station??=origins.isEmpty?null:origins.first;if(_station!=null&&!origins.contains(_station))_station=origins.isEmpty?null:origins.first;final flows=_station==null?<FlowPair>[]:k.destinationsByOrigin[_station!]??[];return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const _Title('Passenger Flow Explorer','KTM Komuter origin → destination'),DropdownButtonFormField<String>(initialValue:_station,isExpanded:true,decoration:const InputDecoration(labelText:'Origin station',prefixIcon:Icon(Icons.train)),items:origins.map((s)=>DropdownMenuItem(value:s,child:Text(s,overflow:TextOverflow.ellipsis))).toList(),onChanged:(v)=>setState(()=>_station=v)),const SizedBox(height:14),_FlowNetwork(origin:_station??'Station',flows:flows.take(6).toList()),const _Title('Top Origin–Destination Flows','Latest available service day'),...k.topFlows.take(8).map((f)=>Card(elevation:0,child:ListTile(leading:const Icon(Icons.swap_horiz,color:AppColors.primary),title:Text('${f.origin} → ${f.destination}',style:const TextStyle(fontWeight:FontWeight.w800)),trailing:Text(_n(f.ridership),style:const TextStyle(fontWeight:FontWeight.w900)))))]);}

  Widget _stationView(KomuterAnalytics k){final names=k.stationActivity.map((e)=>e.station).toList()..sort();_station??=names.isEmpty?null:names.first;if(_station!=null&&!names.contains(_station))_station=names.isEmpty?null:names.first;StationRidership? s;for(final item in k.stationActivity){if(item.station==_station)s=item;}final flows=_station==null?<FlowPair>[]:k.destinationsByOrigin[_station!]??[];return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const _Title('Station Ridership Analysis','Activity by selected KTM Komuter station'),DropdownButtonFormField<String>(initialValue:_station,isExpanded:true,decoration:const InputDecoration(labelText:'Station',prefixIcon:Icon(Icons.location_on)),items:names.map((x)=>DropdownMenuItem(value:x,child:Text(x,overflow:TextOverflow.ellipsis))).toList(),onChanged:(v)=>setState(()=>_station=v)),if(s!=null)Padding(padding:const EdgeInsets.symmetric(vertical:14),child:Row(children:[Expanded(child:_Metric('Departures',_n(s.departures),Icons.call_made)),const SizedBox(width:10),Expanded(child:_Metric('Arrivals',_n(s.arrivals),Icons.call_received))])),const _Title('Popular Destinations','From selected origin'),...flows.take(8).map((f)=>ListTile(leading:const Icon(Icons.arrow_forward,color:AppColors.primary),title:Text(f.destination,style:const TextStyle(fontWeight:FontWeight.w800)),trailing:Text(_n(f.ridership))))]);}

  Widget _peak(KomuterAnalytics k){var hour=0,value=0;for(var i=0;i<24;i++){if(k.hourlyTotals[i]>value){value=k.hourlyTotals[i];hour=i;}}return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:_Metric('Busiest hour','${hour.toString().padLeft(2,'0')}:00',Icons.schedule)),const SizedBox(width:10),Expanded(child:_Metric('Peak trips',_n(value),Icons.groups))]),const _Title('24-Hour Demand','Latest KTM Komuter service day'),_Bars(values:k.hourlyTotals,labels:List.generate(24,(i)=>i%3==0?'$i':'')),const _Title('Weekly Demand Heatmap','Historical 2026 ridership by weekday and 3-hour block'),_Heatmap(k.weekdayHourTotals)]);}
}

class _Title extends StatelessWidget{const _Title(this.a,this.b);final String a,b;@override Widget build(BuildContext c)=>Padding(padding:const EdgeInsets.only(top:22,bottom:10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(a,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),Text(b,style:const TextStyle(color:AppColors.muted,fontSize:12))]));}
class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 108),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(height: 18),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}class _RankRow extends StatelessWidget{const _RankRow(this.name,this.value,this.max);final String name;final int value,max;@override Widget build(BuildContext c)=>Card(elevation:0,child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[Row(children:[Expanded(child:Text(name,style:const TextStyle(fontWeight:FontWeight.w700))),Text(_n(value),style:const TextStyle(fontWeight:FontWeight.w900))]),const SizedBox(height:6),LinearProgressIndicator(value:max==0?0:value/max,minHeight:7,borderRadius:BorderRadius.circular(9))])));}
class _Bars extends StatelessWidget{const _Bars({required this.values,required this.labels});final List<int> values;final List<String> labels;@override Widget build(BuildContext c){final max=values.fold<int>(1,(a,b)=>a>b?a:b);return Card(elevation:0,child:Padding(padding:const EdgeInsets.fromLTRB(10,16,10,10),child:SizedBox(height:180,child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:List.generate(values.length,(i)=>Expanded(child:Padding(padding:const EdgeInsets.symmetric(horizontal:1.5),child:Column(mainAxisAlignment:MainAxisAlignment.end,children:[Expanded(child:Align(alignment:Alignment.bottomCenter,child:FractionallySizedBox(heightFactor:math.max(.03,values[i]/max),child:Container(decoration:BoxDecoration(color:AppColors.primary,borderRadius:const BorderRadius.vertical(top:Radius.circular(4))))))),const SizedBox(height:4),Text(labels[i],style:const TextStyle(fontSize:8,color:AppColors.muted))]))))))));}}
class _FlowNetwork extends StatelessWidget{const _FlowNetwork({required this.origin,required this.flows});final String origin;final List<FlowPair> flows;@override Widget build(BuildContext c)=>Card(elevation:0,child:SizedBox(height:300,child:flows.isEmpty?const Center(child:Text('No flow data available')):Stack(children:[Center(child:Container(width:120,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:AppColors.primary,borderRadius:BorderRadius.circular(18)),child:Text(origin,textAlign:TextAlign.center,maxLines:3,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900)))),...List.generate(flows.length,(i){final a=-math.pi/2+2*math.pi*i/flows.length;return Align(alignment:Alignment(math.cos(a)*.85,math.sin(a)*.8),child:Container(width:92,padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:Theme.of(c).colorScheme.surface,border:Border.all(color:AppColors.primary.withValues(alpha:.35)),borderRadius:BorderRadius.circular(14)),child:Text('${flows[i].destination}\n${_n(flows[i].ridership)}',textAlign:TextAlign.center,maxLines:3,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w800))));})])));}
class _Heatmap extends StatelessWidget{const _Heatmap(this.v);final List<List<int>> v;@override Widget build(BuildContext c){final max=v.expand((e)=>e).fold<int>(1,(a,b)=>a>b?a:b);const d=['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];return Card(elevation:0,child:Padding(padding:const EdgeInsets.all(12),child:Column(children:List.generate(7,(day)=>Row(children:[SizedBox(width:34,child:Text(d[day],style:const TextStyle(fontSize:10,fontWeight:FontWeight.w700))),...List.generate(8,(g){final t=v[day].skip(g*3).take(3).fold<int>(0,(a,b)=>a+b);return Expanded(child:Container(height:28,margin:const EdgeInsets.all(1),decoration:BoxDecoration(color:AppColors.primary.withValues(alpha:.08+math.min(.86,t/(max*3))),borderRadius:BorderRadius.circular(4))));})])))));}}
class _ErrorCard extends StatelessWidget{const _ErrorCard(this.msg,this.retry);final String msg;final Future<void> Function() retry;@override Widget build(BuildContext c)=>Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(children:[const Icon(Icons.cloud_off,size:42),const SizedBox(height:10),Text(msg,textAlign:TextAlign.center),const SizedBox(height:12),FilledButton(onPressed:retry,child:const Text('Try again'))])));}
String _n(int v)=>v>=1000000?'${(v/1000000).toStringAsFixed(1)}M':v>=1000?'${(v/1000).toStringAsFixed(v>=100000?0:1)}K':'$v';
