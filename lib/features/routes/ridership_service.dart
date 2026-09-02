import 'dart:convert';

import 'package:http/http.dart' as http;

class ServiceRidership {
  const ServiceRidership({required this.name, required this.mode, required this.trips});

  final String name;
  final String mode;
  final int trips;
}

class RidershipSnapshot {
  const RidershipSnapshot({
    required this.date,
    required this.total,
    required this.mrt,
    required this.lrt,
    required this.ktm,
    required this.bus,
    required this.recentTotals,
    required this.services,
    required this.previousTotal,
  });

  final DateTime date;
  final int total;
  final int mrt;
  final int lrt;
  final int ktm;
  final int bus;
  final List<int> recentTotals;
  final List<ServiceRidership> services;
  final int previousTotal;

  ServiceRidership get busiestService {
    final ranked = [...services]..sort((a, b) => b.trips.compareTo(a.trips));
    return ranked.first;
  }

  double get changePercent {
    if (previousTotal == 0) return 0;
    return ((total - previousTotal) / previousTotal) * 100;
  }

  String get activityTrend {
    if (changePercent >= 5) return 'Higher than previous day';
    if (changePercent <= -5) return 'Lower than previous day';
    return 'Similar to previous day';
  }
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

    final response = await _client.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Government ridership API failed: HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List || decoded.isEmpty) {
      throw Exception('Government ridership API returned no data.');
    }

    final rows = decoded
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final latest = rows.first;
    final services = _serviceBreakdown(latest);

    return RidershipSnapshot(
      date: DateTime.parse(latest['date'].toString()),
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
      services: services,
      previousTotal: rows.length > 1 ? _totalTrips(rows[1]) : 0,
    );
  }

  List<ServiceRidership> _serviceBreakdown(Map<String, dynamic> row) {
    final services = <ServiceRidership>[
      ServiceRidership(name: 'MRT Kajang Line', mode: 'MRT', trips: _asInt(row['rail_mrt_kajang'])),
      ServiceRidership(name: 'MRT Putrajaya Line', mode: 'MRT', trips: _asInt(row['rail_mrt_pjy'])),
      ServiceRidership(name: 'LRT Ampang Line', mode: 'LRT', trips: _asInt(row['rail_lrt_ampang'])),
      ServiceRidership(name: 'LRT Kelana Jaya Line', mode: 'LRT', trips: _asInt(row['rail_lrt_kj'])),
      ServiceRidership(name: 'LRT Shah Alam Line', mode: 'LRT', trips: _asInt(row['rail_lrt_shah_alam'])),
      ServiceRidership(name: 'Monorail Line', mode: 'LRT', trips: _asInt(row['rail_monorail'])),
      ServiceRidership(name: 'KTM Komuter', mode: 'KTM', trips: _asInt(row['rail_komuter'])),
      ServiceRidership(name: 'KTM Komuter Utara', mode: 'KTM', trips: _asInt(row['rail_komuter_utara'])),
      ServiceRidership(name: 'KTMB ETS', mode: 'KTM', trips: _asInt(row['rail_ets'])),
      ServiceRidership(name: 'KTM Intercity', mode: 'KTM', trips: _asInt(row['rail_intercity'])),
      ServiceRidership(name: 'KTM Shuttle Tebrau', mode: 'KTM', trips: _asInt(row['rail_tebrau'])),
      ServiceRidership(name: 'Rapid Bus KL', mode: 'Bus', trips: _asInt(row['bus_rkl'])),
      ServiceRidership(name: 'Rapid Bus Penang', mode: 'Bus', trips: _asInt(row['bus_rpn'])),
      ServiceRidership(name: 'Rapid Bus Kuantan', mode: 'Bus', trips: _asInt(row['bus_rkn'])),
    ];
    services.removeWhere((service) => service.trips <= 0);
    services.sort((a, b) => b.trips.compareTo(a.trips));
    return services;
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
