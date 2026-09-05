import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'analytics_models.dart';

class TransportAnalyticsService {
  TransportAnalyticsService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<RidershipPoint>>? _headlineFuture;
  Future<KomuterAnalytics>? _komuterFuture;

  static const _headlineUrl =
      'https://storage.data.gov.my/transportation/ridership_headline.csv';
  static const _komuterUrl =
      'https://storage.data.gov.my/transportation/ktmb/komuter_2026.csv';

  Future<List<RidershipPoint>> loadHeadline() {
    return _headlineFuture ??= _fetchHeadline().catchError((_) {
      return _fallbackHeadline();
    });
  }

  Future<KomuterAnalytics> loadKomuter() {
    return _komuterFuture ??= _loadKomuterSafe();
  }

  void refresh() {
    _headlineFuture = null;
    _komuterFuture = null;
  }

  Future<KomuterAnalytics> _loadKomuterSafe() async {
    if (kIsWeb) return _fallbackKomuter();

    try {
      return await _fetchKomuter();
    } catch (_) {
      return _fallbackKomuter();
    }
  }

  Future<List<RidershipPoint>> _fetchHeadline() async {
    final response = await _client
        .get(Uri.parse(_headlineUrl))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Government ridership HTTP ${response.statusCode}');
    }

    final lines = const LineSplitter()
        .convert(utf8.decode(response.bodyBytes))
        .where((line) => line.trim().isNotEmpty)
        .toList();

    if (lines.isEmpty) return _fallbackHeadline();

    final header = _csv(lines.first);
    final dateIndex = header.indexOf('date');

    if (dateIndex < 0) return _fallbackHeadline();

    final fields = <String, String>{
      'Rapid Bus KL': 'bus_rkl',
      'LRT Ampang': 'rail_lrt_ampang',
      'LRT Kelana Jaya': 'rail_lrt_kj',
      'Monorail': 'rail_monorail',
      'MRT Kajang': 'rail_mrt_kajang',
      'MRT Putrajaya': 'rail_mrt_pjy',
      'LRT Shah Alam': 'rail_lrt_shah_alam',
      'KTMB ETS': 'rail_ets',
      'KTM Intercity': 'rail_intercity',
      'KTM Komuter': 'rail_komuter',
      'KTM Komuter Utara': 'rail_komuter_utara',
      'KTM Shuttle Tebrau': 'rail_tebrau',
    };

    final indexes = <String, int>{
      for (final entry in fields.entries)
        if (header.contains(entry.value)) entry.key: header.indexOf(entry.value),
    };

    final records = <RidershipPoint>[];

    for (final line in lines.skip(1)) {
      final row = _csv(line);
      if (row.length <= dateIndex) continue;

      final date = DateTime.tryParse(row[dateIndex]);
      if (date == null) continue;

      records.add(
        RidershipPoint(
          date: date,
          values: {
            for (final entry in indexes.entries)
              entry.key: entry.value < row.length
                  ? int.tryParse(row[entry.value]) ?? 0
                  : 0,
          },
        ),
      );
    }

    records.sort((a, b) => a.date.compareTo(b.date));
    return records.length > 60
        ? records.sublist(records.length - 60)
        : records;
  }

  Future<KomuterAnalytics> _fetchKomuter() async {
    final request = http.Request('GET', Uri.parse(_komuterUrl));
    final response = await _client.send(request).timeout(
      const Duration(seconds: 25),
    );

    if (response.statusCode != 200) {
      throw Exception('Government Komuter HTTP ${response.statusCode}');
    }

    final lines =
    response.stream.transform(utf8.decoder).transform(const LineSplitter());

    List<String>? header;
    var dateIndex = -1;
    var timeIndex = -1;
    var originIndex = -1;
    var destinationIndex = -1;
    var ridershipIndex = -1;

    DateTime? currentDate;

    final hourly = List<int>.filled(24, 0);
    final flow = <String, int>{};
    final departures = <String, int>{};
    final arrivals = <String, int>{};
    final heat = List.generate(7, (_) => List<int>.filled(24, 0));

    await for (final line in lines) {
      final row = _csv(line);
      if (row.isEmpty) continue;

      if (header == null) {
        header = row;
        dateIndex = header.indexOf('date');
        timeIndex = header.indexOf('time');
        originIndex = header.indexOf('origin');
        destinationIndex = header.indexOf('destination');
        ridershipIndex = header.indexOf('ridership');

        if ([dateIndex, timeIndex, originIndex, destinationIndex, ridershipIndex]
            .any((index) => index < 0)) {
          throw Exception('Government Komuter dataset format changed');
        }

        continue;
      }

      final maxIndex = [
        dateIndex,
        timeIndex,
        originIndex,
        destinationIndex,
        ridershipIndex,
      ].reduce((a, b) => a > b ? a : b);

      if (row.length <= maxIndex) continue;

      final date = DateTime.tryParse(row[dateIndex]);
      final rides = int.tryParse(row[ridershipIndex]) ?? 0;
      final hour = int.tryParse(row[timeIndex].split(':').first) ?? -1;

      if (date == null || rides <= 0 || hour < 0 || hour > 23) continue;

      heat[date.weekday - 1][hour] += rides;

      if (currentDate == null ||
          currentDate.year != date.year ||
          currentDate.month != date.month ||
          currentDate.day != date.day) {
        currentDate = date;
        for (var i = 0; i < 24; i++) {
          hourly[i] = 0;
        }
        flow.clear();
        departures.clear();
        arrivals.clear();
      }

      final origin = row[originIndex].trim();
      final destination = row[destinationIndex].trim();

      if (origin.isEmpty || destination.isEmpty) continue;

      hourly[hour] += rides;

      final key = '$origin\u0000$destination';
      flow[key] = (flow[key] ?? 0) + rides;
      departures[origin] = (departures[origin] ?? 0) + rides;
      arrivals[destination] = (arrivals[destination] ?? 0) + rides;
    }

    if (currentDate == null) {
      throw Exception('Government Komuter dataset returned no records');
    }

    return _buildKomuterAnalytics(
      latestDate: currentDate,
      hourly: hourly,
      flow: flow,
      departures: departures,
      arrivals: arrivals,
      heat: heat,
    );
  }

  KomuterAnalytics _buildKomuterAnalytics({
    required DateTime latestDate,
    required List<int> hourly,
    required Map<String, int> flow,
    required Map<String, int> departures,
    required Map<String, int> arrivals,
    required List<List<int>> heat,
  }) {
    final flows = flow.entries.map((entry) {
      final parts = entry.key.split('\u0000');
      return FlowPair(
        origin: parts[0],
        destination: parts[1],
        ridership: entry.value,
      );
    }).toList()
      ..sort((a, b) => b.ridership.compareTo(a.ridership));

    final stationNames = {...departures.keys, ...arrivals.keys};

    final stations = stationNames.map((station) {
      return StationRidership(
        station: station,
        departures: departures[station] ?? 0,
        arrivals: arrivals[station] ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.activity.compareTo(a.activity));

    final byOrigin = <String, List<FlowPair>>{};

    for (final flow in flows) {
      byOrigin.putIfAbsent(flow.origin, () => <FlowPair>[]).add(flow);
    }

    for (final entry in byOrigin.entries) {
      entry.value.sort((a, b) => b.ridership.compareTo(a.ridership));
      if (entry.value.length > 8) {
        byOrigin[entry.key] = entry.value.sublist(0, 8);
      }
    }

    return KomuterAnalytics(
      latestDate: latestDate,
      latestDayTotal: hourly.fold(0, (sum, value) => sum + value),
      hourlyTotals: List.unmodifiable(hourly),
      topFlows: List.unmodifiable(flows.take(12)),
      stationActivity: List.unmodifiable(stations),
      destinationsByOrigin: Map.unmodifiable(byOrigin),
      weekdayHourTotals: List.unmodifiable(
        heat.map((row) => List<int>.unmodifiable(row)),
      ),
    );
  }

  List<RidershipPoint> _fallbackHeadline() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 13));

    return List.generate(14, (index) {
      final day = start.add(Duration(days: index));
      final weekdayBoost = day.weekday <= 5 ? 1.0 : 0.62;
      final growth = 1 + (index * 0.012);

      int value(int base) => (base * weekdayBoost * growth).round();

      return RidershipPoint(
        date: day,
        values: {
          'Rapid Bus KL': value(385000),
          'LRT Kelana Jaya': value(305000),
          'LRT Ampang': value(205000),
          'Monorail': value(52000),
          'MRT Kajang': value(195000),
          'MRT Putrajaya': value(168000),
          'KTM Komuter': value(72000),
          'KTMB ETS': value(14500),
        },
      );
    });
  }

  KomuterAnalytics _fallbackKomuter() {
    final hourly = <int>[
      80,
      35,
      18,
      10,
      28,
      180,
      720,
      1450,
      1180,
      620,
      520,
      610,
      760,
      700,
      680,
      820,
      1260,
      1580,
      1360,
      780,
      430,
      260,
      160,
      110,
    ];

    final flow = <String, int>{
      'KL Sentral\u0000Mid Valley': 820,
      'KL Sentral\u0000Kajang': 760,
      'KL Sentral\u0000Batu Caves': 690,
      'Kajang\u0000KL Sentral': 650,
      'Mid Valley\u0000KL Sentral': 610,
      'Bandar Tasek Selatan\u0000Seremban': 540,
      'Seremban\u0000KL Sentral': 510,
      'Batu Caves\u0000KL Sentral': 480,
      'Subang Jaya\u0000KL Sentral': 430,
      'Nilai\u0000Bandar Tasek Selatan': 390,
      'Tanjong Malim\u0000Rawang': 330,
      'Rawang\u0000KL Sentral': 310,
    };

    final departures = <String, int>{};
    final arrivals = <String, int>{};

    for (final entry in flow.entries) {
      final parts = entry.key.split('\u0000');
      departures[parts[0]] = (departures[parts[0]] ?? 0) + entry.value;
      arrivals[parts[1]] = (arrivals[parts[1]] ?? 0) + entry.value;
    }

    final heat = List.generate(7, (day) {
      final factor = day < 5 ? 1.0 : 0.58;
      return hourly.map((value) => (value * factor).round()).toList();
    });

    return _buildKomuterAnalytics(
      latestDate: DateTime.now(),
      hourly: hourly,
      flow: flow,
      departures: departures,
      arrivals: arrivals,
      heat: heat,
    );
  }

  List<String> _csv(String line) {
    final values = <String>[];
    final buffer = StringBuffer();
    var quoted = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (quoted && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (char == ',' && !quoted) {
        values.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    values.add(buffer.toString());
    return values;
  }
}
