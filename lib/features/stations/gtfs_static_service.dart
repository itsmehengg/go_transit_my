import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class StaticGtfsStop {
  const StaticGtfsStop({
    required this.id,
    required this.rawId,
    required this.name,
    required this.agency,
    required this.point,
  });

  final String id;
  final String rawId;
  final String name;
  final String agency;
  final LatLng point;
}

class ScheduledDeparture {
  const ScheduledDeparture({
    required this.time,
    required this.route,
    required this.destination,
  });

  final String time;
  final String route;
  final String destination;
}

class StaticGtfsFeedResult {
  const StaticGtfsFeedResult({
    required this.agency,
    required this.stops,
    required this.routeCount,
    this.error,
  });

  final String agency;
  final List<StaticGtfsStop> stops;
  final int routeCount;
  final Object? error;
}

class StaticGtfsSnapshot {
  const StaticGtfsSnapshot({required this.results});

  final List<StaticGtfsFeedResult> results;

  List<StaticGtfsStop> get stops => [for (final result in results) ...result.stops];
  int get routeCount => results.fold(0, (total, result) => total + result.routeCount);
  int get activeFeedCount => results.where((result) => result.error == null).length;
  int get failedFeedCount => results.where((result) => result.error != null).length;
}

class GtfsStaticService {
  GtfsStaticService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, Archive> _archiveCache = {};

  Future<StaticGtfsSnapshot> fetchAllStatic() async {
    final results = await Future.wait(_feeds.map(_fetchFeed));
    return StaticGtfsSnapshot(results: results);
  }

  Future<List<ScheduledDeparture>> fetchDepartures(
    StaticGtfsStop stop, {
    int limit = 12,
  }) async {
    final feed = _feeds.firstWhere((item) => item.name == stop.agency);
    final archive = await _loadArchive(feed);
    final stopTimesFile = _findFile(archive, 'stop_times.txt');
    final tripsFile = _findFile(archive, 'trips.txt');
    final routesFile = _findFile(archive, 'routes.txt');
    if (stopTimesFile == null || tripsFile == null || routesFile == null) {
      return const [];
    }

    final trips = {
      for (final row in _parseCsv(_text(tripsFile)))
        if ((row['trip_id'] ?? '').isNotEmpty) row['trip_id']!: row,
    };
    final routes = {
      for (final row in _parseCsv(_text(routesFile)))
        if ((row['route_id'] ?? '').isNotEmpty) row['route_id']!: row,
    };

    final now = DateTime.now();
    final nowSeconds = now.hour * 3600 + now.minute * 60 + now.second;
    final departures = <({int seconds, ScheduledDeparture value})>[];

    for (final row in _parseCsv(_text(stopTimesFile))) {
      if ((row['stop_id'] ?? '').trim() != stop.rawId) continue;
      final time = (row['departure_time'] ?? row['arrival_time'] ?? '').trim();
      final seconds = _gtfsSeconds(time);
      if (seconds == null || seconds < nowSeconds) continue;

      final trip = trips[(row['trip_id'] ?? '').trim()];
      final route = routes[(trip?['route_id'] ?? '').trim()];
      final shortName = (route?['route_short_name'] ?? '').trim();
      final longName = (route?['route_long_name'] ?? '').trim();
      final headsign = (trip?['trip_headsign'] ?? '').trim();

      departures.add((
        seconds: seconds,
        value: ScheduledDeparture(
          time: time,
          route: shortName.isNotEmpty
              ? shortName
              : longName.isNotEmpty
                  ? longName
                  : stop.agency,
          destination: headsign.isEmpty ? 'Scheduled service' : headsign,
        ),
      ));
    }

    departures.sort((a, b) => a.seconds.compareTo(b.seconds));
    return departures.take(limit).map((entry) => entry.value).toList();
  }

  Future<StaticGtfsFeedResult> _fetchFeed(_GtfsStaticFeed feed) async {
    try {
      final archive = await _loadArchive(feed);
      final stopsFile = _findFile(archive, 'stops.txt');
      final routesFile = _findFile(archive, 'routes.txt');
      final stops = stopsFile == null ? <StaticGtfsStop>[] : _parseStops(_text(stopsFile), feed.name);
      final routeCount = routesFile == null ? 0 : _parseCsv(_text(routesFile)).length;
      return StaticGtfsFeedResult(agency: feed.name, stops: stops, routeCount: routeCount);
    } catch (error) {
      return StaticGtfsFeedResult(
        agency: feed.name,
        stops: const [],
        routeCount: 0,
        error: error,
      );
    }
  }

  Future<Archive> _loadArchive(_GtfsStaticFeed feed) async {
    final cached = _archiveCache[feed.name];
    if (cached != null) return cached;
    final response = await _client.get(feed.uri).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) throw Exception('${feed.name} GTFS HTTP ${response.statusCode}');
    final archive = ZipDecoder().decodeBytes(response.bodyBytes);
    _archiveCache[feed.name] = archive;
    return archive;
  }

  String _text(ArchiveFile file) => utf8.decode(file.content, allowMalformed: true);

  ArchiveFile? _findFile(Archive archive, String fileName) {
    for (final file in archive.files) {
      if (file.isFile && file.name.toLowerCase().endsWith(fileName)) return file;
    }
    return null;
  }

  List<StaticGtfsStop> _parseStops(String content, String agency) {
    return _parseCsv(content).map((row) {
      final rawId = row['stop_id']?.trim();
      final name = row['stop_name']?.trim();
      final lat = double.tryParse(row['stop_lat']?.trim() ?? '');
      final lon = double.tryParse(row['stop_lon']?.trim() ?? '');
      if (rawId == null || rawId.isEmpty || name == null || name.isEmpty || lat == null || lon == null) {
        return null;
      }
      return StaticGtfsStop(
        id: '$agency-$rawId',
        rawId: rawId,
        name: name,
        agency: agency,
        point: LatLng(lat, lon),
      );
    }).whereType<StaticGtfsStop>().toList();
  }

  int? _gtfsSeconds(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final s = parts.length > 2 ? int.tryParse(parts[2]) : 0;
    if (h == null || m == null || s == null) return null;
    return h * 3600 + m * 60 + s;
  }

  List<Map<String, String>> _parseCsv(String content) {
    final lines = const LineSplitter().convert(content).where((line) => line.trim().isNotEmpty).toList();
    if (lines.isEmpty) return const [];
    final headers = _parseCsvLine(lines.first);
    final rows = <Map<String, String>>[];
    for (final line in lines.skip(1)) {
      final values = _parseCsvLine(line);
      final row = <String, String>{};
      for (var i = 0; i < headers.length; i++) {
        row[headers[i]] = i < values.length ? values[i] : '';
      }
      rows.add(row);
    }
    return rows;
  }

  List<String> _parseCsvLine(String line) {
    final values = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        final escaped = inQuotes && i + 1 < line.length && line[i + 1] == '"';
        if (escaped) {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
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

class _GtfsStaticFeed {
  const _GtfsStaticFeed({required this.name, required this.uri});
  final String name;
  final Uri uri;
}

final _feeds = [
  _GtfsStaticFeed(name: 'KTMB', uri: Uri.parse('https://api.data.gov.my/gtfs-static/ktmb')),
  _GtfsStaticFeed(name: 'Prasarana', uri: Uri.parse('https://api.data.gov.my/gtfs-static/prasarana')),
];
