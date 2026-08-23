import 'package:gtfs_realtime_bindings/gtfs_realtime_bindings.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

enum LiveVehicleType { train, bus, rail }

class LiveVehicle {
  const LiveVehicle({
    required this.id,
    required this.feedName,
    required this.type,
    required this.point,
    this.routeId,
    this.tripId,
    this.bearing,
    this.speed,
    this.timestamp,
  });

  final String id;
  final String feedName;
  final LiveVehicleType type;
  final LatLng point;
  final String? routeId;
  final String? tripId;
  final double? bearing;
  final double? speed;
  final DateTime? timestamp;
}

class VehicleFeedResult {
  const VehicleFeedResult({
    required this.name,
    required this.vehicles,
    this.error,
  });

  final String name;
  final List<LiveVehicle> vehicles;
  final Object? error;
}

class LiveVehicleSnapshot {
  const LiveVehicleSnapshot({required this.results});

  final List<VehicleFeedResult> results;

  List<LiveVehicle> get vehicles {
    return [for (final result in results) ...result.vehicles];
  }

  int get activeFeedCount {
    return results.where((result) => result.error == null).length;
  }

  int get failedFeedCount {
    return results.where((result) => result.error != null).length;
  }
}

class GtfsVehicleService {
  GtfsVehicleService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<LiveVehicleSnapshot> fetchAllVehicles() async {
    final results = await Future.wait(_feeds.map(_fetchFeed));
    return LiveVehicleSnapshot(results: results);
  }

  Future<VehicleFeedResult> _fetchFeed(_GtfsFeed feed) async {
    try {
      final response = await _client
          .get(feed.uri)
          .timeout(const Duration(seconds: 18));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final message = FeedMessage.fromBuffer(response.bodyBytes);
      final vehicles = message.entity
          .where((entity) => entity.hasVehicle())
          .map((entity) => _parseVehicle(entity, feed))
          .whereType<LiveVehicle>()
          .toList();

      return VehicleFeedResult(name: feed.name, vehicles: vehicles);
    } catch (error) {
      return VehicleFeedResult(
        name: feed.name,
        vehicles: const [],
        error: error,
      );
    }
  }

  LiveVehicle? _parseVehicle(FeedEntity entity, _GtfsFeed feed) {
    final vehicle = entity.vehicle;
    if (!vehicle.hasPosition()) return null;

    final position = vehicle.position;
    final lat = position.latitude;
    final lon = position.longitude;
    if (lat == 0 || lon == 0) return null;

    return LiveVehicle(
      id: entity.id.isNotEmpty
          ? entity.id
          : '${feed.name}-${vehicle.vehicle.id}',
      feedName: feed.name,
      type: feed.type,
      point: LatLng(lat, lon),
      routeId: vehicle.trip.routeId.isEmpty ? null : vehicle.trip.routeId,
      tripId: vehicle.trip.tripId.isEmpty ? null : vehicle.trip.tripId,
      bearing: position.hasBearing() ? position.bearing : null,
      speed: position.hasSpeed() ? position.speed : null,
      timestamp: vehicle.hasTimestamp()
          ? DateTime.fromMillisecondsSinceEpoch(
              vehicle.timestamp.toInt() * 1000,
            )
          : null,
    );
  }
}

class _GtfsFeed {
  const _GtfsFeed({required this.name, required this.uri, required this.type});

  final String name;
  final Uri uri;
  final LiveVehicleType type;
}

final _feeds = [
  _GtfsFeed(
    name: 'KTMB',
    uri: Uri.parse(
      'https://api.data.gov.my/gtfs-realtime/vehicle-position/ktmb',
    ),
    type: LiveVehicleType.rail,
  ),
  _GtfsFeed(
    name: 'Rapid Rail KL',
    uri: Uri.parse(
      'https://api.data.gov.my/gtfs-realtime/vehicle-position/prasarana?category=rapid-rail-kl',
    ),
    type: LiveVehicleType.train,
  ),
  _GtfsFeed(
    name: 'Rapid Bus KL',
    uri: Uri.parse(
      'https://api.data.gov.my/gtfs-realtime/vehicle-position/prasarana?category=rapid-bus-kl',
    ),
    type: LiveVehicleType.bus,
  ),
  _GtfsFeed(
    name: 'MRT Feeder Bus',
    uri: Uri.parse(
      'https://api.data.gov.my/gtfs-realtime/vehicle-position/prasarana?category=rapid-bus-mrtfeeder',
    ),
    type: LiveVehicleType.bus,
  ),
  _GtfsFeed(
    name: 'Rapid Bus Penang',
    uri: Uri.parse(
      'https://api.data.gov.my/gtfs-realtime/vehicle-position/prasarana?category=rapid-bus-penang',
    ),
    type: LiveVehicleType.bus,
  ),
  _GtfsFeed(
    name: 'Rapid Bus Kuantan',
    uri: Uri.parse(
      'https://api.data.gov.my/gtfs-realtime/vehicle-position/prasarana?category=rapid-bus-kuantan',
    ),
    type: LiveVehicleType.bus,
  ),
];
