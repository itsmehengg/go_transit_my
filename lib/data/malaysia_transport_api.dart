import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:gtfs_realtime_bindings/gtfs_realtime_bindings.dart';
import 'package:http/http.dart' as http;

import 'transport_models.dart';

class MalaysiaTransportApi {
  MalaysiaTransportApi({http.Client? client}) : _client = client ?? http.Client();

  static const _baseUrl = 'https://api.data.gov.my';
  final http.Client _client;

  Future<List<GtfsStop>> fetchStops(TransportAgency agency) async {
    final uri = _staticUri(agency);
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw TransportApiException(
        'Unable to download ${agency.label} GTFS data',
        response.statusCode,
      );
    }

    final archive = ZipDecoder().decodeBytes(response.bodyBytes);
    final stopsFile = archive.files.where((file) => file.name.endsWith('stops.txt')).firstOrNull;
    if (stopsFile == null) {
      throw const TransportApiException('stops.txt was not found in the GTFS feed');
    }

    final content = utf8.decode(List<int>.from(stopsFile.content as List));
    final rows = csv.decode(content);
    if (rows.isEmpty) return const [];

    final headers = rows.first.map((value) => value.toString()).toList();
    final idIndex = headers.indexOf('stop_id');
    final nameIndex = headers.indexOf('stop_name');
    final latIndex = headers.indexOf('stop_lat');
    final lonIndex = headers.indexOf('stop_lon');
    final codeIndex = headers.indexOf('stop_code');
    final typeIndex = headers.indexOf('location_type');

    if ([idIndex, nameIndex, latIndex, lonIndex].any((index) => index < 0)) {
      throw const TransportApiException('GTFS stops.txt is missing required columns');
    }

    final result = <GtfsStop>[];
    for (final row in rows.skip(1)) {
      if (row.length <= lonIndex) continue;
      final latitude = double.tryParse(row[latIndex].toString());
      final longitude = double.tryParse(row[lonIndex].toString());
      if (latitude == null || longitude == null) continue;

      result.add(
        GtfsStop(
          id: row[idIndex].toString(),
          name: row[nameIndex].toString(),
          latitude: latitude,
          longitude: longitude,
          code: codeIndex >= 0 && row.length > codeIndex
              ? _nullableString(row[codeIndex])
              : null,
          locationType: typeIndex >= 0 && row.length > typeIndex
              ? int.tryParse(row[typeIndex].toString())
              : null,
        ),
      );
    }
    return result;
  }

  Future<List<LiveVehicle>> fetchVehiclePositions(TransportAgency agency) async {
    final uri = _realtimeUri(agency);
    if (uri == null) {
      throw TransportApiException(
        '${agency.label} does not currently have a supported vehicle-position feed',
      );
    }

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw TransportApiException(
        'Unable to download ${agency.label} realtime vehicle positions',
        response.statusCode,
      );
    }

    final feed = FeedMessage.fromBuffer(response.bodyBytes);
    final vehicles = <LiveVehicle>[];

    for (final entity in feed.entity) {
      if (!entity.hasVehicle() || !entity.vehicle.hasPosition()) continue;
      final vehicle = entity.vehicle;
      final position = vehicle.position;
      final timestampSeconds = vehicle.hasTimestamp() ? vehicle.timestamp.toInt() : null;

      vehicles.add(
        LiveVehicle(
          id: entity.id,
          latitude: position.latitude,
          longitude: position.longitude,
          routeId: vehicle.hasTrip() && vehicle.trip.hasRouteId()
              ? vehicle.trip.routeId
              : null,
          tripId: vehicle.hasTrip() && vehicle.trip.hasTripId()
              ? vehicle.trip.tripId
              : null,
          label: vehicle.hasVehicle() && vehicle.vehicle.hasLabel()
              ? vehicle.vehicle.label
              : null,
          timestamp: timestampSeconds == null || timestampSeconds == 0
              ? null
              : DateTime.fromMillisecondsSinceEpoch(
                  timestampSeconds * 1000,
                  isUtc: true,
                ).toLocal(),
        ),
      );
    }

    return vehicles;
  }

  Uri _staticUri(TransportAgency agency) {
    return switch (agency) {
      TransportAgency.ktmb => Uri.parse('$_baseUrl/gtfs-static/ktmb'),
      TransportAgency.prasaranaRail => Uri.parse(
          '$_baseUrl/gtfs-static/prasarana?category=rapid-rail-kl',
        ),
      TransportAgency.prasaranaBusKl => Uri.parse(
          '$_baseUrl/gtfs-static/prasarana?category=rapid-bus-kl',
        ),
      TransportAgency.prasaranaMrtFeeder => Uri.parse(
          '$_baseUrl/gtfs-static/prasarana?category=rapid-bus-mrtfeeder',
        ),
      TransportAgency.mybasKangar => Uri.parse('$_baseUrl/gtfs-static/mybas-kangar'),
      TransportAgency.mybasAlorSetar => Uri.parse('$_baseUrl/gtfs-static/mybas-alor-setar'),
      TransportAgency.mybasKotaBharu => Uri.parse('$_baseUrl/gtfs-static/mybas-kota-bharu'),
      TransportAgency.mybasKualaTerengganu => Uri.parse('$_baseUrl/gtfs-static/mybas-kuala-terengganu'),
      TransportAgency.mybasIpoh => Uri.parse('$_baseUrl/gtfs-static/mybas-ipoh'),
      TransportAgency.mybasSerembanA => Uri.parse('$_baseUrl/gtfs-static/mybas-seremban-a'),
      TransportAgency.mybasSerembanB => Uri.parse('$_baseUrl/gtfs-static/mybas-seremban-b'),
      TransportAgency.mybasMelaka => Uri.parse('$_baseUrl/gtfs-static/mybas-melaka'),
      TransportAgency.mybasJohor => Uri.parse('$_baseUrl/gtfs-static/mybas-johor'),
      TransportAgency.mybasKuching => Uri.parse('$_baseUrl/gtfs-static/mybas-kuching'),
    };
  }

  Uri? _realtimeUri(TransportAgency agency) {
    return switch (agency) {
      TransportAgency.ktmb => Uri.parse(
          '$_baseUrl/gtfs-realtime/vehicle-position/ktmb',
        ),
      TransportAgency.prasaranaRail => null,
      TransportAgency.prasaranaBusKl => Uri.parse(
          '$_baseUrl/gtfs-realtime/vehicle-position/prasarana?category=rapid-bus-kl',
        ),
      TransportAgency.prasaranaMrtFeeder => Uri.parse(
          '$_baseUrl/gtfs-realtime/vehicle-position/prasarana?category=rapid-bus-mrtfeeder',
        ),
      TransportAgency.mybasKangar => Uri.parse('$_baseUrl/gtfs-realtime/vehicle-position/mybas-kangar'),
      TransportAgency.mybasAlorSetar => Uri.parse('$_baseUrl/gtfs-realtime/vehicle-position/mybas-alor-setar'),
      TransportAgency.mybasKotaBharu => Uri.parse('$_baseUrl/gtfs-realtime/vehicle-position/mybas-kota-bharu'),
      TransportAgency.mybasKualaTerengganu => Uri.parse('$_baseUrl/gtfs-realtime/vehicle-position/mybas-kuala-terengganu'),
      TransportAgency.mybasIpoh => Uri.parse('$_baseUrl/gtfs-realtime/vehicle-position/mybas-ipoh'),
      TransportAgency.mybasSerembanA => Uri.parse('$_baseUrl/gtfs-realtime/vehicle-position/mybas-seremban-a'),
      TransportAgency.mybasSerembanB => Uri.parse('$_baseUrl/gtfs-realtime/vehicle-position/mybas-seremban-b'),
      TransportAgency.mybasMelaka => Uri.parse('$_baseUrl/gtfs-realtime/vehicle-position/mybas-melaka'),
      TransportAgency.mybasJohor => Uri.parse('$_baseUrl/gtfs-realtime/vehicle-position/mybas-johor'),
      TransportAgency.mybasKuching => Uri.parse('$_baseUrl/gtfs-realtime/vehicle-position/mybas-kuching'),
    };
  }

  String? _nullableString(dynamic value) {
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  void dispose() => _client.close();
}

class TransportApiException implements Exception {
  const TransportApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => statusCode == null ? message : '$message (HTTP $statusCode)';
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
