import 'dart:async';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class GovernmentGtfsStop {
  const GovernmentGtfsStop({
    required this.id,
    required this.name,
    required this.agency,
    required this.point,
    this.parentStation,
    this.locationType,
  });

  final String id;
  final String name;
  final String agency;
  final LatLng point;
  final String? parentStation;
  final String? locationType;
}

class GovernmentGtfsCache {
  GovernmentGtfsCache._();

  static final GovernmentGtfsCache instance = GovernmentGtfsCache._();

  final http.Client _client = http.Client();
  final Map<String, Archive> _archives = {};
  final Map<String, Future<Archive>> _pending = {};
  List<GovernmentGtfsStop>? _stops;
  Future<List<GovernmentGtfsStop>>? _stopsPending;

  static final Map<String, Uri> _feeds = {
    'KTMB': Uri.parse('https://api.data.gov.my/gtfs-static/ktmb'),
    'Rapid Rail KL': Uri.parse(
      'https://api.data.gov.my/gtfs-static/prasarana?category=rapid-rail-kl',
    ),
    'Rapid Bus KL': Uri.parse(
      'https://api.data.gov.my/gtfs-static/prasarana?category=rapid-bus-kl',
    ),
  };

  Future<Archive> archive(String agency) {
    final cached = _archives[agency];
    if (cached != null) return Future.value(cached);

    final existing = _pending[agency];
    if (existing != null) return existing;

    final uri = _feeds[agency];
    if (uri == null) {
      return Future.error(Exception('Unknown Government GTFS feed: $agency'));
    }

    final future = _downloadWithRetry(agency, uri);
    _pending[agency] = future;

    return future.whenComplete(() {
      _pending.remove(agency);
    });
  }

  Future<List<GovernmentGtfsStop>> stops() {
    final cached = _stops;
    if (cached != null) return Future.value(cached);

    final existing = _stopsPending;
    if (existing != null) return existing;

    final future = _loadStops();
    _stopsPending = future;

    return future.whenComplete(() {
      _stopsPending = null;
    });
  }

  Future<List<GovernmentGtfsStop>> _loadStops() async {
    final result = <GovernmentGtfsStop>[];

    for (final agency in _feeds.keys) {
      final archiveFile = await archive(agency);
      final file = findFile(archiveFile, 'stops.txt');
      if (file == null) continue;

      for (final row in parseCsv(text(file))) {
        final id = (row['stop_id'] ?? '').trim();
        final name = (row['stop_name'] ?? '').trim();
        final lat = double.tryParse((row['stop_lat'] ?? '').trim());
        final lon = double.tryParse((row['stop_lon'] ?? '').trim());

        if (id.isEmpty ||
            name.isEmpty ||
            lat == null ||
            lon == null ||
            lat == 0 ||
            lon == 0) {
          continue;
        }

        result.add(
          GovernmentGtfsStop(
            id: id,
            name: name,
            agency: agency,
            point: LatLng(lat, lon),
            parentStation: (row['parent_station'] ?? '').trim().isEmpty
                ? null
                : (row['parent_station'] ?? '').trim(),
            locationType: (row['location_type'] ?? '').trim().isEmpty
                ? null
                : (row['location_type'] ?? '').trim(),
          ),
        );
      }
    }

    _stops = List.unmodifiable(result);
    return _stops!;
  }

  Future<Archive> _downloadWithRetry(String agency, Uri uri) async {
    Object? lastError;

    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        final response = await _client
            .get(uri)
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final archiveFile = ZipDecoder().decodeBytes(response.bodyBytes);
          _archives[agency] = archiveFile;
          return archiveFile;
        }

        if (response.statusCode == 429) {
          lastError = Exception('$agency Government GTFS HTTP 429');
          await Future.delayed(
            Duration(seconds: 2 << attempt),
          );
          continue;
        }

        throw Exception(
          '$agency Government GTFS HTTP ${response.statusCode}',
        );
      } catch (error) {
        lastError = error;
        if (attempt < 3) {
          await Future.delayed(Duration(seconds: 2 << attempt));
        }
      }
    }

    throw lastError ?? Exception('$agency Government GTFS unavailable');
  }

  ArchiveFile? findFile(Archive archiveFile, String fileName) {
    final target = fileName.toLowerCase();
    for (final file in archiveFile.files) {
      if (file.isFile && file.name.toLowerCase().endsWith(target)) {
        return file;
      }
    }
    return null;
  }

  String text(ArchiveFile file) {
    return utf8.decode(file.content, allowMalformed: true);
  }

  List<Map<String, String>> parseCsv(String content) {
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
        final escaped =
            inQuotes && i + 1 < line.length && line[i + 1] == '"';

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
