import 'dart:convert';

import 'package:http/http.dart' as http;

class PeakHourRecord {
  const PeakHourRecord({
    required this.hour,
    required this.ridership,
  });

  final String hour;
  final int ridership;
}

class PeakHourAnalysis {
  const PeakHourAnalysis({
    required this.origin,
    required this.destination,
    required this.busiestHour,
    required this.quietestHour,
    required this.averageRidership,
    required this.totalRidership,
    required this.hourlyRecords,
  });

  final String origin;
  final String destination;
  final PeakHourRecord busiestHour;
  final PeakHourRecord quietestHour;
  final double averageRidership;
  final int totalRidership;
  final List<PeakHourRecord> hourlyRecords;

  String get activityLevel {
    if (busiestHour.ridership >= averageRidership * 1.5) return 'High';
    if (busiestHour.ridership >= averageRidership * 1.15) return 'Moderate';
    return 'Normal';
  }
}

class PeakHourAnalysisService {
  static const _url =
      'https://storage.data.gov.my/transportation/ktmb/komuter_2026.csv';

  List<Map<String, String>>? _rows;

  Future<List<String>> fetchStations() async {
    final rows = await _loadRows();
    final stations = <String>{};
    for (final row in rows) {
      final origin = row['origin']?.trim();
      final destination = row['destination']?.trim();
      if (origin != null && origin.isNotEmpty) stations.add(origin);
      if (destination != null && destination.isNotEmpty) stations.add(destination);
    }
    final result = stations.toList()..sort();
    return result;
  }

  Future<PeakHourAnalysis?> analyse({
    required String origin,
    required String destination,
  }) async {
    final rows = await _loadRows();
    final byHour = <String, int>{};

    for (final row in rows) {
      if (row['origin']?.trim() != origin ||
          row['destination']?.trim() != destination) {
        continue;
      }
      final hour = row['time']?.trim();
      final ridership = int.tryParse(row['ridership']?.trim() ?? '') ?? 0;
      if (hour == null || hour.isEmpty) continue;
      byHour.update(hour, (value) => value + ridership, ifAbsent: () => ridership);
    }

    if (byHour.isEmpty) return null;

    final records = byHour.entries
        .map((entry) => PeakHourRecord(hour: entry.key, ridership: entry.value))
        .toList()
      ..sort((a, b) => a.hour.compareTo(b.hour));

    final ranked = [...records]
      ..sort((a, b) => b.ridership.compareTo(a.ridership));
    final total = records.fold<int>(0, (sum, item) => sum + item.ridership);

    return PeakHourAnalysis(
      origin: origin,
      destination: destination,
      busiestHour: ranked.first,
      quietestHour: ranked.last,
      averageRidership: total / records.length,
      totalRidership: total,
      hourlyRecords: records,
    );
  }

  Future<List<Map<String, String>>> _loadRows() async {
    if (_rows != null) return _rows!;
    final response = await http.get(Uri.parse(_url));
    if (response.statusCode != 200) {
      throw Exception('Unable to load Malaysia Government Komuter data.');
    }
    _rows = _parseCsv(utf8.decode(response.bodyBytes));
    return _rows!;
  }

  List<Map<String, String>> _parseCsv(String text) {
    final lines = const LineSplitter().convert(text);
    if (lines.isEmpty) return [];
    final headers = _splitLine(lines.first);
    final rows = <Map<String, String>>[];
    for (final line in lines.skip(1)) {
      if (line.trim().isEmpty) continue;
      final values = _splitLine(line);
      if (values.length < headers.length) continue;
      rows.add({
        for (var i = 0; i < headers.length; i++) headers[i]: values[i],
      });
    }
    return rows;
  }

  List<String> _splitLine(String line) {
    final values = <String>[];
    final current = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (quoted && i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (char == ',' && !quoted) {
        values.add(current.toString());
        current.clear();
      } else {
        current.write(char);
      }
    }
    values.add(current.toString());
    return values;
  }
}