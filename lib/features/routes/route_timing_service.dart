import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;

class RouteTimingInfo {
  const RouteTimingInfo({
    required this.departure,
    required this.arrival,
    required this.durationMinutes,
    required this.source,
  });

  final DateTime departure;
  final DateTime arrival;
  final int durationMinutes;
  final String source;
}

class RouteTimingService {
  RouteTimingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  Archive? _rapidRailArchive;
  Archive? _ktmbArchive;

  Future<RouteTimingInfo?> findTiming({
    required String mode,
    required String from,
    required String to,
    required DateTime requestedDeparture,
  }) async {
    if (mode == 'MRT' || mode == 'LRT') {
      final archive = await _rapidRail();
      return _findInArchive(
        archive: archive,
        from: from,
        to: to,
        requestedDeparture: requestedDeparture,
        source: 'Malaysia Government GTFS Static - Rapid Rail KL',
      );
    }
    if (mode == 'KTM') {
      final archive = await _ktmb();
      return _findInArchive(
        archive: archive,
        from: from,
        to: to,
        requestedDeparture: requestedDeparture,
        source: 'Malaysia Government GTFS Static - KTMB',
      );
    }
    return null;
  }

  Future<Archive> _rapidRail() async {
    if (_rapidRailArchive != null) return _rapidRailArchive!;
    _rapidRailArchive = await _download(
      Uri.parse('https://api.data.gov.my/gtfs-static/prasarana?category=rapid-rail-kl'),
    );
    return _rapidRailArchive!;
  }

  Future<Archive> _ktmb() async {
    if (_ktmbArchive != null) return _ktmbArchive!;
    _ktmbArchive = await _download(Uri.parse('https://api.data.gov.my/gtfs-static/ktmb'));
    return _ktmbArchive!;
  }

  Future<Archive> _download(Uri uri) async {
    final response = await _client.get(uri).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('Government GTFS HTTP ${response.statusCode}');
    }
    return ZipDecoder().decodeBytes(response.bodyBytes);
  }

  RouteTimingInfo? _findInArchive({
    required Archive archive,
    required String from,
    required String to,
    required DateTime requestedDeparture,
    required String source,
  }) {
    final stopsFile = _findFile(archive, 'stops.txt');
    final stopTimesFile = _findFile(archive, 'stop_times.txt');
    final tripsFile = _findFile(archive, 'trips.txt');
    if (stopsFile == null || stopTimesFile == null || tripsFile == null) return null;

    final stopRows = _parseCsv(_text(stopsFile));
    final fromIds = <String>{};
    final toIds = <String>{};
    for (final row in stopRows) {
      final id = (row['stop_id'] ?? '').trim();
      final name = _normalise(row['stop_name'] ?? '');
      if (id.isEmpty) continue;
      if (_stationMatches(name, from)) fromIds.add(id);
      if (_stationMatches(name, to)) toIds.add(id);
    }
    if (fromIds.isEmpty || toIds.isEmpty) return null;

    final validTrips = _validTripIds(
      archive: archive,
      tripsFile: tripsFile,
      date: requestedDeparture,
    );
    final byTrip = <String, List<Map<String, String>>>{};
    for (final row in _parseCsv(_text(stopTimesFile))) {
      final stopId = (row['stop_id'] ?? '').trim();
      if (!fromIds.contains(stopId) && !toIds.contains(stopId)) continue;
      final tripId = (row['trip_id'] ?? '').trim();
      if (tripId.isEmpty || (validTrips != null && !validTrips.contains(tripId))) continue;
      byTrip.putIfAbsent(tripId, () => []).add(row);
    }

    final requestedSeconds = requestedDeparture.hour * 3600 + requestedDeparture.minute * 60;
    ({int departure, int arrival})? best;

    for (final rows in byTrip.values) {
      Map<String, String>? origin;
      Map<String, String>? destination;
      for (final row in rows) {
        final stopId = (row['stop_id'] ?? '').trim();
        final sequence = int.tryParse((row['stop_sequence'] ?? '').trim()) ?? -1;
        if (fromIds.contains(stopId)) {
          if (origin == null || sequence < (int.tryParse(origin['stop_sequence'] ?? '') ?? 999999)) {
            origin = row;
          }
        }
        if (toIds.contains(stopId)) {
          if (destination == null || sequence > (int.tryParse(destination['stop_sequence'] ?? '') ?? -1)) {
            destination = row;
          }
        }
      }
      if (origin == null || destination == null) continue;
      final originSequence = int.tryParse(origin['stop_sequence'] ?? '') ?? -1;
      final destinationSequence = int.tryParse(destination['stop_sequence'] ?? '') ?? -1;
      if (destinationSequence <= originSequence) continue;
      final departure = _seconds(origin['departure_time'] ?? origin['arrival_time'] ?? '');
      final arrival = _seconds(destination['arrival_time'] ?? destination['departure_time'] ?? '');
      if (departure == null || arrival == null || arrival <= departure) continue;
      if (departure < requestedSeconds) continue;
      if (best == null || departure < best.departure) {
        best = (departure: departure, arrival: arrival);
      }
    }

    if (best == null) return null;
    final departure = _dateWithSeconds(requestedDeparture, best.departure);
    final arrival = _dateWithSeconds(requestedDeparture, best.arrival);
    return RouteTimingInfo(
      departure: departure,
      arrival: arrival,
      durationMinutes: ((best.arrival - best.departure) / 60).ceil(),
      source: source,
    );
  }

  Set<String>? _validTripIds({
    required Archive archive,
    required ArchiveFile tripsFile,
    required DateTime date,
  }) {
    final calendarFile = _findFile(archive, 'calendar.txt');
    final calendarDatesFile = _findFile(archive, 'calendar_dates.txt');
    if (calendarFile == null && calendarDatesFile == null) return null;

    final activeServices = <String>{};
    if (calendarFile != null) {
      final weekday = const [
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
        'sunday',
      ][date.weekday - 1];
      final target = _dateKey(date);
      for (final row in _parseCsv(_text(calendarFile))) {
        final start = row['start_date'] ?? '';
        final end = row['end_date'] ?? '';
        if ((row[weekday] ?? '0') == '1' && target.compareTo(start) >= 0 && target.compareTo(end) <= 0) {
          activeServices.add((row['service_id'] ?? '').trim());
        }
      }
    }

    if (calendarDatesFile != null) {
      final target = _dateKey(date);
      for (final row in _parseCsv(_text(calendarDatesFile))) {
        if ((row['date'] ?? '').trim() != target) continue;
        final serviceId = (row['service_id'] ?? '').trim();
        if ((row['exception_type'] ?? '').trim() == '1') activeServices.add(serviceId);
        if ((row['exception_type'] ?? '').trim() == '2') activeServices.remove(serviceId);
      }
    }

    if (activeServices.isEmpty) return <String>{};
    final result = <String>{};
    for (final row in _parseCsv(_text(tripsFile))) {
      if (activeServices.contains((row['service_id'] ?? '').trim())) {
        result.add((row['trip_id'] ?? '').trim());
      }
    }
    return result;
  }

  bool _stationMatches(String normalisedGtfsName, String appName) {
    final target = _normalise(appName);
    return normalisedGtfsName == target ||
        normalisedGtfsName.contains(target) ||
        target.contains(normalisedGtfsName);
  }

  String _normalise(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'\b(mrt|lrt|ktm|komuter|station|stesen)\b'), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
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

  DateTime _dateWithSeconds(DateTime date, int seconds) {
    final dayOffset = seconds ~/ 86400;
    final remainder = seconds % 86400;
    return DateTime(date.year, date.month, date.day)
        .add(Duration(days: dayOffset, seconds: remainder));
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  String _text(ArchiveFile file) => utf8.decode(file.content, allowMalformed: true);

  ArchiveFile? _findFile(Archive archive, String name) {
    for (final file in archive.files) {
      if (file.isFile && file.name.toLowerCase().endsWith(name)) return file;
    }
    return null;
  }

  List<Map<String, String>> _parseCsv(String content) {
    final lines = const LineSplitter().convert(content).where((line) => line.trim().isNotEmpty).toList();
    if (lines.isEmpty) return const [];
    final headers = _parseCsvLine(lines.first);
    final rows = <Map<String, String>>[];
    for (final line in lines.skip(1)) {
      final values = _parseCsvLine(line);
      rows.add({for (var i = 0; i < headers.length; i++) headers[i]: i < values.length ? values[i] : ''});
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