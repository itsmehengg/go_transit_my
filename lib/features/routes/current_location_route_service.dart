import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../stations/gtfs_static_service.dart';
import '../stations/location_service.dart';
import 'station_catalog.dart';

class AccessStep {
  const AccessStep({
    required this.mode,
    required this.from,
    required this.to,
    required this.durationMinutes,
    this.line,
    this.departure,
    this.arrival,
    this.distanceMetres,
  });

  final String mode;
  final String from;
  final String to;
  final int durationMinutes;
  final String? line;
  final DateTime? departure;
  final DateTime? arrival;
  final double? distanceMetres;
}

class BoardingAccessPlan {
  const BoardingAccessPlan({
    required this.station,
    required this.steps,
    required this.readyAt,
    required this.scoreMinutes,
  });

  final RouteStation station;
  final List<AccessStep> steps;
  final DateTime readyAt;
  final double scoreMinutes;
}

class CurrentLocationAccessResult {
  const CurrentLocationAccessResult({
    required this.currentLocation,
    required this.plans,
  });

  final LatLng currentLocation;
  final List<BoardingAccessPlan> plans;
}

class CurrentLocationRouteService {
  CurrentLocationRouteService({
    LocationService? locationService,
    GtfsStaticService? gtfsService,
    http.Client? client,
  })  : _locationService = locationService ?? LocationService(),
        _gtfsService = gtfsService ?? GtfsStaticService(),
        _client = client ?? http.Client();

  final LocationService _locationService;
  final GtfsStaticService _gtfsService;
  final http.Client _client;

  Archive? _busArchive;

  Future<CurrentLocationAccessResult> findAccessPlans({
    required String transport,
    required DateTime departure,
    int limit = 14,
  }) async {
    final current = await _locationService.getCurrentLocation();
    final snapshot = await _gtfsService.fetchAllStatic();

    final railStops = snapshot.stops.where((stop) {
      if (transport == 'KTM') return stop.agency == 'KTMB';
      if (transport == 'MRT' || transport == 'LRT') {
        return stop.agency == 'Rapid Rail KL';
      }
      return stop.agency == 'Rapid Rail KL' || stop.agency == 'KTMB';
    }).toList();

    final directPlans = _directWalkPlans(
      current: current,
      railStops: railStops,
      departure: departure,
    );

    final busPlans = transport == 'KTM'
        ? <BoardingAccessPlan>[]
        : await _busAccessPlans(
            current: current,
            railStops: railStops,
            departure: departure,
          );

    final plans = [...directPlans, ...busPlans]
      ..sort((a, b) => a.scoreMinutes.compareTo(b.scoreMinutes));

    final unique = <String, BoardingAccessPlan>{};
    for (final plan in plans) {
      final key = '${plan.station.name}|${plan.steps.map((e) => e.mode).join('-')}';
      unique.putIfAbsent(key, () => plan);
    }

    if (unique.isEmpty) {
      throw Exception(
        'No nearby public transport access could be matched from your current location.',
      );
    }

    return CurrentLocationAccessResult(
      currentLocation: current,
      plans: unique.values.take(limit).toList(),
    );
  }

  List<BoardingAccessPlan> _directWalkPlans({
    required LatLng current,
    required List<StaticGtfsStop> railStops,
    required DateTime departure,
  }) {
    final plans = <BoardingAccessPlan>[];

    for (final station in routeStations) {
      double? bestDistance;

      for (final stop in railStops) {
        if (!_sameStation(stop.name, station.name)) continue;
        final distance = _locationService.distanceMetres(current, stop.point);
        if (bestDistance == null || distance < bestDistance) {
          bestDistance = distance;
        }
      }

      if (bestDistance == null) continue;

      final walkingMinutes = _walkingMinutes(bestDistance);
      if (walkingMinutes > 30) continue;

      plans.add(
        BoardingAccessPlan(
          station: station,
          steps: [
            AccessStep(
              mode: 'Walk',
              from: 'Current Location',
              to: station.name,
              durationMinutes: walkingMinutes,
              departure: departure,
              arrival: departure.add(Duration(minutes: walkingMinutes)),
              distanceMetres: bestDistance,
            ),
          ],
          readyAt: departure.add(Duration(minutes: walkingMinutes)),
          scoreMinutes: walkingMinutes.toDouble(),
        ),
      );
    }

    return plans;
  }

  Future<List<BoardingAccessPlan>> _busAccessPlans({
    required LatLng current,
    required List<StaticGtfsStop> railStops,
    required DateTime departure,
  }) async {
    final archive = await _rapidBusArchive();
    final stopsFile = _findFile(archive, 'stops.txt');
    final stopTimesFile = _findFile(archive, 'stop_times.txt');
    final tripsFile = _findFile(archive, 'trips.txt');
    final routesFile = _findFile(archive, 'routes.txt');

    if (stopsFile == null ||
        stopTimesFile == null ||
        tripsFile == null ||
        routesFile == null) {
      return const [];
    }

    final busStops = _parseCsv(_text(stopsFile));
    final nearby = <_BusStopDistance>[];

    for (final row in busStops) {
      final lat = double.tryParse((row['stop_lat'] ?? '').trim());
      final lon = double.tryParse((row['stop_lon'] ?? '').trim());
      final id = (row['stop_id'] ?? '').trim();
      final name = (row['stop_name'] ?? '').trim();

      if (lat == null || lon == null || id.isEmpty || name.isEmpty) continue;

      final distance = _locationService.distanceMetres(
        current,
        LatLng(lat, lon),
      );

      if (distance <= 1200) {
        nearby.add(
          _BusStopDistance(
            id: id,
            name: name,
            point: LatLng(lat, lon),
            distanceMetres: distance,
          ),
        );
      }
    }

    nearby.sort((a, b) => a.distanceMetres.compareTo(b.distanceMetres));
    final originStops = nearby.take(10).toList();
    if (originStops.isEmpty) return const [];

    final railTargets = <_RailTarget>[];
    for (final station in routeStations) {
      for (final stop in railStops) {
        if (!_sameStation(stop.name, station.name)) continue;
        railTargets.add(
          _RailTarget(
            station: station,
            point: stop.point,
          ),
        );
      }
    }

    final destinationBusStops = <String, _BusRailLink>{};

    for (final row in busStops) {
      final lat = double.tryParse((row['stop_lat'] ?? '').trim());
      final lon = double.tryParse((row['stop_lon'] ?? '').trim());
      final id = (row['stop_id'] ?? '').trim();
      final name = (row['stop_name'] ?? '').trim();

      if (lat == null || lon == null || id.isEmpty || name.isEmpty) continue;

      final point = LatLng(lat, lon);
      _BusRailLink? nearest;

      for (final target in railTargets) {
        final distance = _locationService.distanceMetres(point, target.point);
        if (distance > 700) continue;

        if (nearest == null || distance < nearest.distanceMetres) {
          nearest = _BusRailLink(
            station: target.station,
            stopName: name,
            distanceMetres: distance,
          );
        }
      }

      if (nearest != null) {
        destinationBusStops[id] = nearest;
      }
    }

    if (destinationBusStops.isEmpty) return const [];

    final tripRows = _parseCsv(_text(tripsFile));
    final routeRows = _parseCsv(_text(routesFile));

    final tripToRoute = <String, String>{};
    for (final row in tripRows) {
      final tripId = (row['trip_id'] ?? '').trim();
      final routeId = (row['route_id'] ?? '').trim();
      if (tripId.isNotEmpty) tripToRoute[tripId] = routeId;
    }

    final routeNames = <String, String>{};
    for (final row in routeRows) {
      final routeId = (row['route_id'] ?? '').trim();
      final shortName = (row['route_short_name'] ?? '').trim();
      final longName = (row['route_long_name'] ?? '').trim();
      if (routeId.isNotEmpty) {
        routeNames[routeId] = shortName.isNotEmpty
            ? shortName
            : longName.isNotEmpty
                ? longName
                : 'Rapid KL Bus';
      }
    }

    final originIds = originStops.map((e) => e.id).toSet();
    final destinationIds = destinationBusStops.keys.toSet();

    final byTrip = <String, List<Map<String, String>>>{};

    for (final row in _parseCsv(_text(stopTimesFile))) {
      final stopId = (row['stop_id'] ?? '').trim();
      if (!originIds.contains(stopId) && !destinationIds.contains(stopId)) {
        continue;
      }

      final tripId = (row['trip_id'] ?? '').trim();
      if (tripId.isEmpty) continue;
      byTrip.putIfAbsent(tripId, () => []).add(row);
    }

    final requestedSeconds = departure.hour * 3600 +
        departure.minute * 60 +
        departure.second;

    final plans = <BoardingAccessPlan>[];

    for (final entry in byTrip.entries) {
      Map<String, String>? origin;
      Map<String, String>? destinationRow;

      for (final row in entry.value) {
        final stopId = (row['stop_id'] ?? '').trim();
        final sequence = int.tryParse((row['stop_sequence'] ?? '').trim()) ?? -1;

        if (originIds.contains(stopId)) {
          final old = int.tryParse(origin?['stop_sequence'] ?? '') ?? 999999;
          if (origin == null || sequence < old) origin = row;
        }

        if (destinationIds.contains(stopId)) {
          final old = int.tryParse(destinationRow?['stop_sequence'] ?? '') ?? -1;
          if (destinationRow == null || sequence > old) destinationRow = row;
        }
      }

      if (origin == null || destinationRow == null) continue;

      final originSequence = int.tryParse((origin['stop_sequence'] ?? '').trim()) ?? -1;
      final destinationSequence =
          int.tryParse((destinationRow['stop_sequence'] ?? '').trim()) ?? -1;

      if (destinationSequence <= originSequence) continue;

      final originStop = originStops.firstWhere(
        (item) => item.id == (origin!['stop_id'] ?? '').trim(),
      );

      final walkToBusMinutes = _walkingMinutes(originStop.distanceMetres);
      final readyForBus =
          departure.add(Duration(minutes: walkToBusMinutes));
      final readySeconds =
          readyForBus.hour * 3600 + readyForBus.minute * 60 + readyForBus.second;

      final busDeparture = _seconds(
        origin['departure_time'] ?? origin['arrival_time'] ?? '',
      );
      final busArrival = _seconds(
        destinationRow['arrival_time'] ??
            destinationRow['departure_time'] ??
            '',
      );

      if (busDeparture == null ||
          busArrival == null ||
          busArrival <= busDeparture ||
          busDeparture < requestedSeconds ||
          busDeparture < readySeconds) {
        continue;
      }

      final destinationStopId =
          (destinationRow['stop_id'] ?? '').trim();
      final railLink = destinationBusStops[destinationStopId];
      if (railLink == null) continue;

      final walkToRailMinutes = _walkingMinutes(railLink.distanceMetres);
      final busDepartureDate = _dateWithSeconds(departure, busDeparture);
      final busArrivalDate = _dateWithSeconds(departure, busArrival);
      final railReady =
          busArrivalDate.add(Duration(minutes: walkToRailMinutes));

      final routeId = tripToRoute[entry.key];
      final routeName = routeNames[routeId] ?? 'Rapid KL Bus';

      final busMinutes =
          ((busArrival - busDeparture) / 60).ceil();

      final totalMinutes = railReady.difference(departure).inMinutes;

      plans.add(
        BoardingAccessPlan(
          station: railLink.station,
          readyAt: railReady,
          scoreMinutes: totalMinutes.toDouble(),
          steps: [
            AccessStep(
              mode: 'Walk',
              from: 'Current Location',
              to: originStop.name,
              durationMinutes: walkToBusMinutes,
              departure: departure,
              arrival: readyForBus,
              distanceMetres: originStop.distanceMetres,
            ),
            AccessStep(
              mode: 'Bus',
              from: originStop.name,
              to: railLink.stopName,
              durationMinutes: busMinutes,
              departure: busDepartureDate,
              arrival: busArrivalDate,
              line: routeName,
            ),
            AccessStep(
              mode: 'Walk',
              from: railLink.stopName,
              to: railLink.station.name,
              durationMinutes: walkToRailMinutes,
              departure: busArrivalDate,
              arrival: railReady,
              distanceMetres: railLink.distanceMetres,
            ),
          ],
        ),
      );
    }

    plans.sort((a, b) => a.scoreMinutes.compareTo(b.scoreMinutes));
    return plans.take(18).toList();
  }

  Future<Archive> _rapidBusArchive() async {
    if (_busArchive != null) return _busArchive!;

    final response = await _client
        .get(
          Uri.parse(
            'https://api.data.gov.my/gtfs-static/prasarana?category=rapid-bus-kl',
          ),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Rapid Bus GTFS HTTP ${response.statusCode}');
    }

    _busArchive = ZipDecoder().decodeBytes(response.bodyBytes);
    return _busArchive!;
  }

  int _walkingMinutes(double metres) {
    if (metres <= 80) return 1;
    return (metres / 80).ceil();
  }

  bool _sameStation(String gtfsName, String appName) {
    final gtfs = _normalise(gtfsName);
    final app = _normalise(appName);
    if (gtfs.isEmpty || app.isEmpty) return false;
    return gtfs == app || gtfs.contains(app) || app.contains(gtfs);
  }

  String _normalise(String value) {
    return value
        .toLowerCase()
        .replaceAll(
          RegExp(r'\b(mrt|lrt|ktm|komuter|station|stesen|platform)\b'),
          '',
        )
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  DateTime _dateWithSeconds(DateTime date, int seconds) {
    final dayOffset = seconds ~/ 86400;
    final remainder = seconds % 86400;
    return DateTime(date.year, date.month, date.day).add(
      Duration(days: dayOffset, seconds: remainder),
    );
  }

  int? _seconds(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final s = parts.length > 2 ? int.tryParse(parts[2]) : 0;
    if (h == null || m == null || s == null) return null;
    return h * 3600 + m * 60 + s;
  }

  String _text(ArchiveFile file) {
    return utf8.decode(file.content, allowMalformed: true);
  }

  ArchiveFile? _findFile(Archive archive, String name) {
    for (final file in archive.files) {
      if (file.isFile && file.name.toLowerCase().endsWith(name)) {
        return file;
      }
    }
    return null;
  }

  List<Map<String, String>> _parseCsv(String content) {
    final lines = const LineSplitter()
        .convert(content)
        .where((line) => line.trim().isNotEmpty)
        .toList();

    if (lines.isEmpty) return const [];

    final headers = _parseCsvLine(lines.first);
    final rows = <Map<String, String>>[];

    for (final line in lines.skip(1)) {
      final values = _parseCsvLine(line);
      rows.add({
        for (var i = 0; i < headers.length; i++)
          headers[i]: i < values.length ? values[i] : '',
      });
    }

    return rows;
  }

  List<String> _parseCsvLine(String line) {
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

class _BusStopDistance {
  const _BusStopDistance({
    required this.id,
    required this.name,
    required this.point,
    required this.distanceMetres,
  });

  final String id;
  final String name;
  final LatLng point;
  final double distanceMetres;
}

class _RailTarget {
  const _RailTarget({
    required this.station,
    required this.point,
  });

  final RouteStation station;
  final LatLng point;
}

class _BusRailLink {
  const _BusRailLink({
    required this.station,
    required this.stopName,
    required this.distanceMetres,
  });

  final RouteStation station;
  final String stopName;
  final double distanceMetres;
}
