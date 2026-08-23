import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class StaticGtfsStop {
  const StaticGtfsStop({
    required this.id,
    required this.name,
    required this.agency,
    required this.point,
  });

  final String id;
  final String name;
  final String agency;
  final LatLng point;
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

  List<StaticGtfsStop> get stops {
    return [for (final result in results) ...result.stops];
  }

  int get routeCount {
    return results.fold(0, (total, result) => total + result.routeCount);
  }

  int get activeFeedCount {
    return results.where((result) => result.error == null).length;
  }

  int get failedFeedCount {
    return results.where((result) => result.error != null).length;
  }
}

class GtfsStaticService {
  GtfsStaticService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<StaticGtfsSnapshot> fetchAllStatic() async {
    final results = await Future.wait(_feeds.map(_fetchFeed));
    return StaticGtfsSnapshot(results: results);
  }

  Future<StaticGtfsFeedResult> _fetchFeed(_GtfsStaticFeed feed) async {
    try {
      final response = await _client
          .get(feed.uri)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final archive = ZipDecoder().decodeBytes(response.bodyBytes);
      final stopsFile = _findFile(archive, 'stops.txt');
      final routesFile = _findFile(archive, 'routes.txt');

      final stops = stopsFile == null
          ? <StaticGtfsStop>[]
          : _parseStops(
              utf8.decode(stopsFile.content, allowMalformed: true),
              feed.name,
            );
      final routeCount = routesFile == null
          ? 0
          : _parseRouteCount(
              utf8.decode(routesFile.content, allowMalformed: true),
            );

      return StaticGtfsFeedResult(
        agency: feed.name,
        stops: stops,
        routeCount: routeCount,
      );
    } catch (error) {
      return StaticGtfsFeedResult(
        agency: feed.name,
        stops: const [],
        routeCount: 0,
        error: error,
      );
    }
  }

  ArchiveFile? _findFile(Archive archive, String fileName) {
    for (final file in archive.files) {
      if (file.isFile && file.name.toLowerCase().endsWith(fileName)) {
        return file;
      }
    }
    return null;
  }

  List<StaticGtfsStop> _parseStops(String content, String agency) {
    final rows = _parseCsv(content);
    return rows
        .map((row) {
          final id = row['stop_id']?.trim();
          final name = row['stop_name']?.trim();
          final lat = double.tryParse(row['stop_lat']?.trim() ?? '');
          final lon = double.tryParse(row['stop_lon']?.trim() ?? '');
          if (id == null ||
              id.isEmpty ||
              name == null ||
              name.isEmpty ||
              lat == null ||
              lon == null ||
              lat == 0 ||
              lon == 0) {
            return null;
          }

          return StaticGtfsStop(
            id: '$agency-$id',
            name: name,
            agency: agency,
            point: LatLng(lat, lon),
          );
        })
        .whereType<StaticGtfsStop>()
        .toList();
  }

  int _parseRouteCount(String content) {
    return _parseCsv(content).length;
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
        final isEscapedQuote =
            inQuotes && i + 1 < line.length && line[i + 1] == '"';
        if (isEscapedQuote) {
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
  _GtfsStaticFeed(
    name: 'KTMB',
    uri: Uri.parse('https://api.data.gov.my/gtfs-static/ktmb'),
  ),
  _GtfsStaticFeed(
    name: 'Prasarana',
    uri: Uri.parse('https://api.data.gov.my/gtfs-static/prasarana'),
  ),
];
