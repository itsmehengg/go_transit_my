import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'government_gtfs_cache.dart';
import 'station_catalog.dart';

class RoadRouteOverview {
  const RoadRouteOverview({
    required this.points,
    required this.distanceMetres,
    required this.durationSeconds,
  });

  final List<LatLng> points;
  final double distanceMetres;
  final double durationSeconds;
}

class RouteMapStationPoint {
  const RouteMapStationPoint({
    required this.station,
    required this.point,
  });

  final RouteStation station;
  final LatLng point;
}

class RouteMapService {
  RouteMapService({
    http.Client? client,
  }) : _client = client ?? http.Client();

  final GovernmentGtfsCache _gtfsCache = GovernmentGtfsCache.instance;
  final http.Client _client;

  Future<List<RouteMapStationPoint>> loadStationPoints() async {
    final stops = await _gtfsCache.stops();
    final result = <RouteMapStationPoint>[];

    for (final station in routeStations) {
      final best = _bestGovernmentStop(
        station,
        stops,
      );

      if (best == null) continue;

      result.add(
        RouteMapStationPoint(
          station: station,
          point: best.point,
        ),
      );
    }

    return result;
  }

  Future<LatLng?> findStationPoint(RouteStation station) async {
    final stops = await _gtfsCache.stops();
    final stop = _bestGovernmentStop(
      station,
      stops,
    );
    return stop?.point;
  }

  GovernmentGtfsStop? _bestGovernmentStop(
    RouteStation station,
    List<GovernmentGtfsStop> stops,
  ) {
    GovernmentGtfsStop? best;
    var bestScore = 0.0;

    for (final stop in stops) {
      if (!_agencyMatches(station, stop)) continue;

      final score = _stationMatchScore(
        station.name,
        stop.name,
      );

      if (score > bestScore) {
        best = stop;
        bestScore = score;
      }
    }

    if (bestScore >= 0.52) return best;
    return null;
  }

  bool _agencyMatches(
    RouteStation station,
    GovernmentGtfsStop stop,
  ) {
    if (station.mode == 'KTM') {
      return stop.agency == 'KTMB';
    }

    if (station.mode == 'MRT' ||
        station.mode == 'LRT') {
      return stop.agency == 'Rapid Rail KL';
    }

    return stop.agency == 'Rapid Rail KL' ||
        stop.agency == 'KTMB';
  }

  double _stationMatchScore(
    String stationName,
    String gtfsName,
  ) {
    final left = _normalise(stationName);
    final right = _normalise(gtfsName);

    if (left.isEmpty || right.isEmpty) return 0;
    if (left == right) return 1;
    if (left.contains(right) || right.contains(left)) {
      return 0.96;
    }

    final leftTokens = left.split(' ').toSet();
    final rightTokens = right.split(' ').toSet();

    final intersection =
        leftTokens.intersection(rightTokens).length;
    final union =
        leftTokens.union(rightTokens).length;

    final tokenScore =
        union == 0 ? 0.0 : intersection / union;

    final compactLeft = left.replaceAll(' ', '');
    final compactRight = right.replaceAll(' ', '');
    final editScore = _similarity(
      compactLeft,
      compactRight,
    );

    final firstTokenBonus =
        leftTokens.isNotEmpty &&
                rightTokens.isNotEmpty &&
                leftTokens.first == rightTokens.first
            ? 0.08
            : 0.0;

    final score =
        tokenScore * 0.58 +
        editScore * 0.42 +
        firstTokenBonus;

    return score > 1 ? 1 : score;
  }

  String _normalise(String value) {
    final words = value
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(
          RegExp(
            r'\b(mrt|lrt|ktm|komuter|station|stesen|terminal|platform)\b',
          ),
          ' ',
        )
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where(
          (word) =>
              word.isNotEmpty &&
              !RegExp(r'^(?=.*\d)[a-z0-9]{2,8}$')
                  .hasMatch(word),
        )
        .map(_canonicalWord)
        .toList();

    return words.join(' ');
  }

  String _canonicalWord(String word) {
    const aliases = {
      'tasek': 'tasik',
      'sentral': 'sentral',
      'centre': 'center',
      'central': 'sentral',
      'jamek': 'jamek',
      'caves': 'caves',
    };
    return aliases[word] ?? word;
  }

  double _similarity(String a, String b) {
    if (a == b) return 1;
    if (a.isEmpty || b.isEmpty) return 0;

    final distance = _levenshtein(a, b);
    final longest =
        a.length > b.length ? a.length : b.length;

    return 1 - distance / longest;
  }

  int _levenshtein(String a, String b) {
    var previous =
        List<int>.generate(b.length + 1, (i) => i);

    for (var i = 0; i < a.length; i++) {
      final current =
          List<int>.filled(b.length + 1, 0);
      current[0] = i + 1;

      for (var j = 0; j < b.length; j++) {
        final insert = current[j] + 1;
        final delete = previous[j + 1] + 1;
        final replace =
            previous[j] + (a[i] == b[j] ? 0 : 1);

        var value = insert < delete ? insert : delete;
        if (replace < value) value = replace;
        current[j + 1] = value;
      }

      previous = current;
    }

    return previous[b.length];
  }

  Future<RoadRouteOverview?> fetchRoadRoute({
    required LatLng from,
    required LatLng to,
  }) async {
    final uri = Uri.https(
      'router.project-osrm.org',
      '/route/v1/driving/${from.longitude},${from.latitude};${to.longitude},${to.latitude}',
      {
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'false',
      },
    );

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;

    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty) return null;

    final route = routes.first;
    if (route is! Map<String, dynamic>) return null;

    final geometry = route['geometry'];
    if (geometry is! Map<String, dynamic>) return null;

    final coordinates = geometry['coordinates'];
    if (coordinates is! List) return null;

    final points = <LatLng>[];

    for (final coordinate in coordinates) {
      if (coordinate is! List ||
          coordinate.length < 2) {
        continue;
      }

      final lon =
          (coordinate[0] as num?)?.toDouble();
      final lat =
          (coordinate[1] as num?)?.toDouble();

      if (lat == null || lon == null) continue;
      points.add(LatLng(lat, lon));
    }

    if (points.length < 2) return null;

    return RoadRouteOverview(
      points: points,
      distanceMetres:
          (route['distance'] as num?)?.toDouble() ??
              0,
      durationSeconds:
          (route['duration'] as num?)?.toDouble() ??
              0,
    );
  }
}
