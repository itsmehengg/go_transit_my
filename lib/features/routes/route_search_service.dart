import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'government_gtfs_cache.dart';
import 'station_catalog.dart';

class RouteLeg {
  const RouteLeg({
    required this.from,
    required this.to,
    required this.mode,
    required this.line,
    this.stopCount = 1,
  });

  final String from;
  final String to;
  final String mode;
  final String line;
  final int stopCount;
}

class RouteSearchResult {
  const RouteSearchResult({
    required this.from,
    required this.to,
    required this.legs,
  });

  final RouteStation from;
  final RouteStation to;
  final List<RouteLeg> legs;

  int get transfers {
    final paid = groupedLegs.where((leg) => leg.mode != 'Walk').toList();
    return paid.length > 1 ? paid.length - 1 : 0;
  }

  int get stops => legs.where((leg) => leg.mode != 'Walk').fold<int>(
    0,
        (total, leg) => total + math.max(1, leg.stopCount),
  );

  int get walkingConnections => legs.where((leg) => leg.mode == 'Walk').length;

  List<String> get modes {
    final result = <String>[];

    for (final leg in legs) {
      if (leg.mode == 'Walk') continue;
      if (!result.contains(leg.mode)) result.add(leg.mode);
    }

    return result;
  }

  List<String> get transferStations {
    if (groupedLegs.length <= 1) return const <String>[];
    return groupedLegs
        .where((leg) => leg.mode != 'Walk')
        .map((leg) => leg.from)
        .skip(1)
        .toList();
  }

  List<String> get stationSequence {
    if (legs.isEmpty) return <String>[from.name, to.name];
    return <String>[legs.first.from, ...legs.map((leg) => leg.to)];
  }

  List<RouteLeg> get groupedLegs {
    if (legs.isEmpty) return const <RouteLeg>[];
    return legs;
  }

  String get signature {
    return legs
        .map((leg) => '${leg.from}|${leg.to}|${leg.mode}|${leg.line}')
        .join('>');
  }
}

class RouteSearchService {
  const RouteSearchService();

  Future<RouteSearchResult?> search({
    required RouteStation from,
    required RouteStation to,
    required String transport,
  }) async {
    final results = await searchOptions(
      from: from,
      to: to,
      transport: transport,
    );

    return results.isEmpty ? null : results.first;
  }

  Future<List<RouteSearchResult>> searchOptions({
    required RouteStation from,
    required RouteStation to,
    required String transport,
    int limit = 8,
  }) async {
    final stops = await GovernmentGtfsCache.instance.stops();

    final fromMatch = _bestStopMatch(from.name, stops, transport);
    final toMatch = _bestStopMatch(to.name, stops, transport);

    if (fromMatch == null || toMatch == null) {
      return const <RouteSearchResult>[];
    }

    final mode = _chooseMode(
      transport: transport,
      fromAgency: fromMatch.agency,
      toAgency: toMatch.agency,
    );

    final line = _lineLabel(
      mode: mode,
      fromAgency: fromMatch.agency,
      toAgency: toMatch.agency,
    );

    final distanceKm = const Distance().as(
      LengthUnit.Kilometer,
      fromMatch.point,
      toMatch.point,
    );

    final estimatedStops = _estimateStopCount(distanceKm, mode);

    final result = RouteSearchResult(
      from: RouteStation(
        name: _cleanStationName(fromMatch.name),
        mode: mode,
      ),
      to: RouteStation(
        name: _cleanStationName(toMatch.name),
        mode: mode,
      ),
      legs: <RouteLeg>[
        RouteLeg(
          from: _cleanStationName(fromMatch.name),
          to: _cleanStationName(toMatch.name),
          mode: mode,
          line: '$line - estimated from Malaysia Government GTFS stations',
          stopCount: estimatedStops,
        ),
      ],
    );

    return <RouteSearchResult>[result];
  }

  GovernmentGtfsStop? _bestStopMatch(
      String stationName,
      List<GovernmentGtfsStop> stops,
      String transport,
      ) {
    final candidates = stops.where((stop) {
      if (!_transportMatches(stop.agency, transport)) return false;
      return _sameStation(stop.name, stationName);
    }).toList();

    if (candidates.isNotEmpty) return candidates.first;

    final looseCandidates = stops.where((stop) {
      if (!_transportMatches(stop.agency, transport)) return false;

      final stopName = _normalise(stop.name);
      final target = _normalise(stationName);

      if (stopName.isEmpty || target.isEmpty) return false;

      return stopName.contains(target) || target.contains(stopName);
    }).toList();

    if (looseCandidates.isNotEmpty) return looseCandidates.first;

    return null;
  }

  bool _transportMatches(String agency, String transport) {
    if (transport == 'All') return true;
    if (transport == 'KTM') return agency == 'KTMB';
    if (transport == 'MRT' || transport == 'LRT') {
      return agency == 'Rapid Rail KL';
    }
    if (transport == 'Bus') return agency == 'Rapid Bus KL';
    return true;
  }

  String _chooseMode({
    required String transport,
    required String fromAgency,
    required String toAgency,
  }) {
    if (transport != 'All') return transport;

    if (fromAgency == 'KTMB' || toAgency == 'KTMB') return 'KTM';
    if (fromAgency == 'Rapid Bus KL' || toAgency == 'Rapid Bus KL') {
      return 'Bus';
    }

    return 'Rail';
  }

  String _lineLabel({
    required String mode,
    required String fromAgency,
    required String toAgency,
  }) {
    if (mode == 'KTM') return 'KTMB';
    if (mode == 'Bus') return 'Rapid KL Bus';
    if (mode == 'MRT') return 'Rapid Rail MRT';
    if (mode == 'LRT') return 'Rapid Rail LRT';
    if (fromAgency == toAgency) return fromAgency;
    return '$fromAgency + $toAgency';
  }

  int _estimateStopCount(double distanceKm, String mode) {
    final kmPerStop = switch (mode) {
      'Bus' => 0.75,
      'KTM' => 4.0,
      'MRT' => 1.4,
      'LRT' => 1.1,
      _ => 1.5,
    };

    return math.max(1, (distanceKm / kmPerStop).round());
  }

  bool _sameStation(String a, String b) {
    final left = _normalise(a);
    final right = _normalise(b);

    if (left.isEmpty || right.isEmpty) return false;

    return left == right || left.contains(right) || right.contains(left);
  }

  String _normalise(String value) {
    return value
        .toLowerCase()
        .replaceAll(
      RegExp(r'\b(mrt|lrt|ktm|komuter|station|stesen|platform)\b'),
      '',
    )
        .replaceAll(RegExp(r'\s*\([^)]*\)\s*'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _cleanStationName(String value) {
    return value
        .replaceAll(RegExp(r'\s*\([^)]*\)\s*'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}