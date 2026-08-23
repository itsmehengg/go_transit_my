import 'dart:convert';

import 'package:http/http.dart' as http;

class RidershipSnapshot {
  const RidershipSnapshot({
    required this.date,
    required this.total,
    required this.mrt,
    required this.lrt,
    required this.ktm,
    required this.bus,
    required this.recentTotals,
  });

  final DateTime date;
  final int total;
  final int mrt;
  final int lrt;
  final int ktm;
  final int bus;
  final List<int> recentTotals;
}

class RidershipService {
  RidershipService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<RidershipSnapshot> fetchLatestSnapshot() async {
    final uri = Uri.https('api.data.gov.my', '/data-catalogue', {
      'id': 'ridership_headline',
      'sort': '-date',
      'limit': '14',
      'include': [
        'date',
        'bus_rkl',
        'bus_rkn',
        'bus_rpn',
        'rail_lrt_ampang',
        'rail_lrt_kj',
        'rail_lrt_shah_alam',
        'rail_monorail',
        'rail_mrt_kajang',
        'rail_mrt_pjy',
        'rail_ets',
        'rail_intercity',
        'rail_komuter',
        'rail_komuter_utara',
        'rail_tebrau',
      ].join(','),
    });

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Ridership API failed: HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List || decoded.isEmpty) {
      throw Exception('Ridership API returned no data.');
    }

    final rows = decoded.cast<Map<String, dynamic>>();
    final latest = rows.first;

    return RidershipSnapshot(
      date: DateTime.parse(latest['date'] as String),
      total: _totalTrips(latest),
      mrt: _sum(latest, const ['rail_mrt_kajang', 'rail_mrt_pjy']),
      lrt: _sum(latest, const [
        'rail_lrt_ampang',
        'rail_lrt_kj',
        'rail_lrt_shah_alam',
        'rail_monorail',
      ]),
      ktm: _sum(latest, const [
        'rail_ets',
        'rail_intercity',
        'rail_komuter',
        'rail_komuter_utara',
        'rail_tebrau',
      ]),
      bus: _sum(latest, const ['bus_rkl', 'bus_rkn', 'bus_rpn']),
      recentTotals: rows.map(_totalTrips).toList().reversed.toList(),
    );
  }

  int _totalTrips(Map<String, dynamic> row) {
    return row.entries
        .where((entry) => entry.key != 'date')
        .fold<int>(0, (total, entry) => total + _asInt(entry.value));
  }

  int _sum(Map<String, dynamic> row, List<String> keys) {
    return keys.fold<int>(0, (total, key) => total + _asInt(row[key]));
  }

  int _asInt(Object? value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString()) ?? 0;
  }
}
