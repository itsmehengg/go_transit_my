import 'package:supabase_flutter/supabase_flutter.dart';

class TransportAlert {
  const TransportAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.mode,
    required this.operatorName,
    required this.status,
    required this.source,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String message;
  final String type;
  final String mode;
  final String operatorName;
  final String status;
  final String source;
  final DateTime? createdAt;
}

class TransportAlertService {
  TransportAlertService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<TransportAlert>> fetchAlerts() async {
    final response = await _client.from('service_alerts').select();
    final rows = (response as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();

    final alerts = rows.map(_parseAlert).toList();
    alerts.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return alerts;
  }

  TransportAlert _parseAlert(Map<String, dynamic> row) {
    return TransportAlert(
      id: _first(row, ['id', 'alert_id', 'service_alert_id'], fallback: ''),
      title: _first(
        row,
        ['title', 'alert_title', 'name'],
        fallback: 'Transport Service Update',
      ),
      message: _first(
        row,
        ['message', 'description', 'details', 'body'],
        fallback: 'No additional information is available.',
      ),
      type: _first(
        row,
        ['type', 'alert_type', 'severity'],
        fallback: 'Service Update',
      ),
      mode: _normaliseMode(
        _first(
          row,
          ['mode', 'transport_mode', 'category', 'line_type'],
          fallback: 'All',
        ),
      ),
      operatorName: _first(
        row,
        ['operator', 'operator_name', 'agency'],
        fallback: 'Public Transport',
      ),
      status: _first(
        row,
        ['status', 'service_status'],
        fallback: 'Active',
      ),
      source: _first(
        row,
        ['source', 'source_url', 'data_source'],
        fallback: 'Service alert database',
      ),
      createdAt: _date(
        row['created_at'] ??
            row['updated_at'] ??
            row['published_at'] ??
            row['date'],
      ),
    );
  }

  String _first(
    Map<String, dynamic> row,
    List<String> keys, {
    required String fallback,
  }) {
    for (final key in keys) {
      final value = row[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return fallback;
  }

  DateTime? _date(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  String _normaliseMode(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('mrt')) return 'MRT';
    if (lower.contains('lrt')) return 'LRT';
    if (lower.contains('bus')) return 'Bus';
    if (lower.contains('ktm') ||
        lower.contains('komuter') ||
        lower.contains('rail')) {
      return 'KTM';
    }
    return 'All';
  }
}
