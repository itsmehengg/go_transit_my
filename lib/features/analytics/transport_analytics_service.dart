import 'dart:convert';
import 'package:http/http.dart' as http;
import 'analytics_models.dart';

class TransportAnalyticsService {
  TransportAnalyticsService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  Future<List<RidershipPoint>>? _headlineFuture;
  Future<KomuterAnalytics>? _komuterFuture;

  static const _headlineUrl = 'https://storage.data.gov.my/transportation/ridership_headline.csv';
  static const _komuterUrl = 'https://storage.data.gov.my/transportation/ktmb/komuter_2026.csv';

  Future<List<RidershipPoint>> loadHeadline() => _headlineFuture ??= _fetchHeadline();
  Future<KomuterAnalytics> loadKomuter() => _komuterFuture ??= _fetchKomuter();
  void refresh() { _headlineFuture = null; _komuterFuture = null; }

  Future<List<RidershipPoint>> _fetchHeadline() async {
    final response = await _client.get(Uri.parse(_headlineUrl));
    if (response.statusCode != 200) throw Exception('Government ridership HTTP ${response.statusCode}');
    final lines = const LineSplitter().convert(utf8.decode(response.bodyBytes));
    final header = _csv(lines.first);
    final fields = <String, String>{
      'Rapid Bus KL':'bus_rkl','LRT Ampang':'rail_lrt_ampang','LRT Kelana Jaya':'rail_lrt_kj','Monorail':'rail_monorail','MRT Kajang':'rail_mrt_kajang','MRT Putrajaya':'rail_mrt_pjy','LRT Shah Alam':'rail_lrt_shah_alam','KTMB ETS':'rail_ets','KTM Intercity':'rail_intercity','KTM Komuter':'rail_komuter','KTM Komuter Utara':'rail_komuter_utara','KTM Shuttle Tebrau':'rail_tebrau'
    };
    final dateIndex = header.indexOf('date');
    final indexes = <String,int>{for (final e in fields.entries) if (header.contains(e.value)) e.key: header.indexOf(e.value)};
    final records = <RidershipPoint>[];
    for (final line in lines.skip(1)) {
      final row = _csv(line); if (row.length <= dateIndex) continue;
      final date = DateTime.tryParse(row[dateIndex]); if (date == null) continue;
      records.add(RidershipPoint(date: date, values: {for (final e in indexes.entries) e.key: e.value < row.length ? int.tryParse(row[e.value]) ?? 0 : 0}));
    }
    records.sort((a,b) => a.date.compareTo(b.date));
    return records.length > 60 ? records.sublist(records.length - 60) : records;
  }

  Future<KomuterAnalytics> _fetchKomuter() async {
    final request = http.Request('GET', Uri.parse(_komuterUrl));
    final response = await _client.send(request);
    if (response.statusCode != 200) throw Exception('Government Komuter HTTP ${response.statusCode}');
    final lines = response.stream.transform(utf8.decoder).transform(const LineSplitter());
    List<String>? header; int di=-1,ti=-1,oi=-1,ddi=-1,ri=-1; DateTime? currentDate;
    final hourly = List<int>.filled(24,0), flow = <String,int>{}, dep = <String,int>{}, arr = <String,int>{};
    final heat = List.generate(7, (_) => List<int>.filled(24,0));
    await for (final line in lines) {
      final row = _csv(line); if (row.isEmpty) continue;
      if (header == null) { header=row; di=header.indexOf('date'); ti=header.indexOf('time'); oi=header.indexOf('origin'); ddi=header.indexOf('destination'); ri=header.indexOf('ridership'); continue; }
      final maxIndex=[di,ti,oi,ddi,ri].reduce((a,b)=>a>b?a:b); if (row.length<=maxIndex) continue;
      final date=DateTime.tryParse(row[di]); final rides=int.tryParse(row[ri])??0; final hour=int.tryParse(row[ti].split(':').first)??-1;
      if (date==null || rides<=0 || hour<0 || hour>23) continue;
      heat[date.weekday-1][hour]+=rides;
      if (currentDate==null || currentDate.year!=date.year || currentDate.month!=date.month || currentDate.day!=date.day) { currentDate=date; for(var i=0;i<24;i++) { hourly[i]=0; } flow.clear(); dep.clear(); arr.clear(); }
      final origin=row[oi].trim(), dest=row[ddi].trim(); if(origin.isEmpty||dest.isEmpty) continue;
      hourly[hour]+=rides; final key='$origin\u0000$dest'; flow[key]=(flow[key]??0)+rides; dep[origin]=(dep[origin]??0)+rides; arr[dest]=(arr[dest]??0)+rides;
    }
    if (currentDate==null) throw Exception('Government Komuter dataset returned no records');
    final flows=flow.entries.map((e){final p=e.key.split('\u0000');return FlowPair(origin:p[0],destination:p[1],ridership:e.value);}).toList()..sort((a,b)=>b.ridership.compareTo(a.ridership));
    final names={...dep.keys,...arr.keys}; final stations=names.map((s)=>StationRidership(station:s,departures:dep[s]??0,arrivals:arr[s]??0)).toList()..sort((a,b)=>b.activity.compareTo(a.activity));
    final byOrigin=<String,List<FlowPair>>{}; for(final f in flows){byOrigin.putIfAbsent(f.origin,()=>[]).add(f);} for(final e in byOrigin.entries){e.value.sort((a,b)=>b.ridership.compareTo(a.ridership)); if(e.value.length>8) byOrigin[e.key]=e.value.sublist(0,8);}
    return KomuterAnalytics(latestDate:currentDate,latestDayTotal:hourly.fold(0,(a,b)=>a+b),hourlyTotals:List.unmodifiable(hourly),topFlows:List.unmodifiable(flows.take(12)),stationActivity:List.unmodifiable(stations),destinationsByOrigin:Map.unmodifiable(byOrigin),weekdayHourTotals:List.unmodifiable(heat.map((e)=>List<int>.unmodifiable(e))));
  }

  List<String> _csv(String line) {
    final values=<String>[], b=StringBuffer(); var quoted=false;
    for(var i=0;i<line.length;i++){final c=line[i]; if(c=='"'){if(quoted&&i+1<line.length&&line[i+1]=='"'){b.write('"');i++;}else{quoted=!quoted;}}else if(c==','&&!quoted){values.add(b.toString());b.clear();}else{b.write(c);}}
    values.add(b.toString()); return values;
  }
}
