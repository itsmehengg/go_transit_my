import 'dart:convert';

import 'package:archive/archive.dart';
import 'government_gtfs_cache.dart';

class RouteTimingInfo {
  const RouteTimingInfo({
    required this.departure,
    required this.arrival,
    required this.durationMinutes,
    required this.source,
    required this.usesCalendarFallback,
  });

  final DateTime departure;
  final DateTime arrival;
  final int durationMinutes;
  final String source;
  final bool usesCalendarFallback;
}

class RouteTimingService {
  RouteTimingService();

  final GovernmentGtfsCache _gtfsCache = GovernmentGtfsCache.instance;

  Future<RouteTimingInfo?> findTiming({
    required String mode,
    required String from,
    required String to,
    required DateTime requestedDeparture,
  }) async {
    if (mode == 'MRT' || mode == 'LRT') {
      return _findInArchive(
        archive: await _rapidRail(),
        from: from,
        to: to,
        requestedDeparture: requestedDeparture,
        source: 'Malaysia Government GTFS Static - Rapid Rail KL',
      );
    }
    if (mode == 'KTM') {
      return _findInArchive(
        archive: await _ktmb(),
        from: from,
        to: to,
        requestedDeparture: requestedDeparture,
        source: 'Malaysia Government GTFS Static - KTMB',
      );
    }
    return null;
  }

  Future<Archive> _rapidRail() {
    return _gtfsCache.archive('Rapid Rail KL');
  }

  Future<Archive> _ktmb() {
    return _gtfsCache.archive('KTMB');
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
    if (stopsFile == null || stopTimesFile == null || tripsFile == null) {
      return null;
    }

    final fromIds = <String>{};
    final toIds = <String>{};
    for (final row in _parseCsv(_text(stopsFile))) {
      final id = (row['stop_id'] ?? '').trim();
      final name = _normalise(row['stop_name'] ?? '');
      if (id.isEmpty) continue;
      if (_stationMatches(name, from)) fromIds.add(id);
      if (_stationMatches(name, to)) toIds.add(id);
    }
    if (fromIds.isEmpty || toIds.isEmpty) return null;

    final activeTripIds = _activeTripIds(
      archive: archive,
      tripsFile: tripsFile,
      date: requestedDeparture,
    );
    final useCalendarFallback = activeTripIds != null && activeTripIds.isEmpty;

    final byTrip = <String, List<Map<String, String>>>{};
    for (final row in _parseCsv(_text(stopTimesFile))) {
      final tripId = (row['trip_id'] ?? '').trim();
      if (tripId.isEmpty) continue;
      if (!useCalendarFallback &&
          activeTripIds != null &&
          !activeTripIds.contains(tripId)) {
        continue;
      }
      byTrip.putIfAbsent(tripId, () => []).add(row);
    }

    final frequencies = <String, List<Map<String, String>>>{};
    final frequenciesFile = _findFile(archive, 'frequencies.txt');
    if (frequenciesFile != null) {
      for (final row in _parseCsv(_text(frequenciesFile))) {
        final tripId = (row['trip_id'] ?? '').trim();
        if (tripId.isEmpty) continue;
        frequencies.putIfAbsent(tripId, () => []).add(row);
      }
    }

    final requestedSeconds = requestedDeparture.hour * 3600 +
        requestedDeparture.minute * 60 +
        requestedDeparture.second;
    ({int departure, int arrival})? best;

    for (final entry in byTrip.entries) {
      final rows = [...entry.value]
        ..sort((a, b) {
          final aSequence = int.tryParse((a['stop_sequence'] ?? '').trim()) ?? 0;
          final bSequence = int.tryParse((b['stop_sequence'] ?? '').trim()) ?? 0;
          return aSequence.compareTo(bSequence);
        });

      Map<String, String>? origin;
      Map<String, String>? destination;

      for (final row in rows) {
        final stopId = (row['stop_id'] ?? '').trim();
        final sequence = int.tryParse((row['stop_sequence'] ?? '').trim()) ?? -1;

        if (fromIds.contains(stopId)) {
          final oldSequence = int.tryParse(origin?['stop_sequence'] ?? '') ?? 999999;
          if (origin == null || sequence < oldSequence) origin = row;
        }

        if (toIds.contains(stopId)) {
          final oldSequence = int.tryParse(destination?['stop_sequence'] ?? '') ?? -1;
          if (destination == null || sequence > oldSequence) destination = row;
        }
      }

      if (origin == null || destination == null || rows.isEmpty) continue;
      final originSequence = int.tryParse(origin['stop_sequence'] ?? '') ?? -1;
      final destinationSequence = int.tryParse(destination['stop_sequence'] ?? '') ?? -1;
      if (destinationSequence <= originSequence) continue;

      final templateStart = _seconds(
        rows.first['departure_time'] ?? rows.first['arrival_time'] ?? '',
      );
      final templateOrigin = _seconds(
        origin['departure_time'] ?? origin['arrival_time'] ?? '',
      );
      final templateDestination = _seconds(
        destination['arrival_time'] ?? destination['departure_time'] ?? '',
      );
      if (templateStart == null ||
          templateOrigin == null ||
          templateDestination == null ||
          templateDestination <= templateOrigin) {
        continue;
      }

      final tripFrequencies = frequencies[entry.key];
      if (tripFrequencies != null && tripFrequencies.isNotEmpty) {
        final originOffset = templateOrigin - templateStart;
        final destinationOffset = templateDestination - templateStart;

        for (final frequency in tripFrequencies) {
          final start = _seconds((frequency['start_time'] ?? '').trim());
          final end = _seconds((frequency['end_time'] ?? '').trim());
          final headway = int.tryParse((frequency['headway_secs'] ?? '').trim());
          if (start == null || end == null || headway == null || headway <= 0) {
            continue;
          }

          final firstOrigin = start + originOffset;
          var index = 0;
          if (requestedSeconds > firstOrigin) {
            index = ((requestedSeconds - firstOrigin) / headway).ceil();
          }

          final candidateTripStart = start + index * headway;
          if (candidateTripStart >= end) continue;

          final candidateDeparture = candidateTripStart + originOffset;
          final candidateArrival = candidateTripStart + destinationOffset;
          if (candidateDeparture < requestedSeconds ||
              candidateArrival <= candidateDeparture) {
            continue;
          }

          if (best == null || candidateDeparture < best.departure) {
            best = (
              departure: candidateDeparture,
              arrival: candidateArrival,
            );
          }
        }
      } else {
        if (templateOrigin < requestedSeconds) continue;
        if (best == null || templateOrigin < best.departure) {
          best = (
            departure: templateOrigin,
            arrival: templateDestination,
          );
        }
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
      usesCalendarFallback: useCalendarFallback,
    );
  }

  Set<String>? _activeTripIds({
    required Archive archive,
    required ArchiveFile tripsFile,
    required DateTime date,
  }) {
    final calendarFile = _findFile(archive, 'calendar.txt');
    final calendarDatesFile = _findFile(archive, 'calendar_dates.txt');
    if (calendarFile == null && calendarDatesFile == null) return null;

    final activeServices = <String>{};
    final target = _dateKey(date);

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

      for (final row in _parseCsv(_text(calendarFile))) {
        final start = (row['start_date'] ?? '').trim();
        final end = (row['end_date'] ?? '').trim();
        if ((row[weekday] ?? '0').trim() == '1' &&
            target.compareTo(start) >= 0 &&
            target.compareTo(end) <= 0) {
          final serviceId = (row['service_id'] ?? '').trim();
          if (serviceId.isNotEmpty) activeServices.add(serviceId);
        }
      }
    }

    if (calendarDatesFile != null) {
      for (final row in _parseCsv(_text(calendarDatesFile))) {
        if ((row['date'] ?? '').trim() != target) continue;
        final serviceId = (row['service_id'] ?? '').trim();
        final type = (row['exception_type'] ?? '').trim();
        if (type == '1' && serviceId.isNotEmpty) activeServices.add(serviceId);
        if (type == '2') activeServices.remove(serviceId);
      }
    }

    final result = <String>{};
    for (final row in _parseCsv(_text(tripsFile))) {
      if (activeServices.contains((row['service_id'] ?? '').trim())) {
        final tripId = (row['trip_id'] ?? '').trim();
        if (tripId.isNotEmpty) result.add(tripId);
      }
    }
    return result;
  }

  bool _stationMatches(String normalisedGtfsName, String appName) {
    final target = _normalise(appName);
    if (target.isEmpty) return false;
    return normalisedGtfsName == target ||
        normalisedGtfsName.contains(target) ||
        target.contains(normalisedGtfsName);
  }

  String _normalise(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'\b(mrt|lrt|ktm|komuter|station|stesen|platform)\b'), '')
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
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
    return DateTime(date.year, date.month, date.day).add(
      Duration(days: dayOffset, seconds: remainder),
    );
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _text(ArchiveFile file) {
    return utf8.decode(file.content, allowMalformed: true);
  }

  ArchiveFile? _findFile(Archive archive, String name) {
    for (final file in archive.files) {
      if (file.isFile && file.name.toLowerCase().endsWith(name)) return file;
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
