import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'location_service.dart';
import 'malaysia_transport_api.dart';
import 'transport_models.dart';

class NearbyStop {
  const NearbyStop({required this.stop, required this.distanceMeters});

  final GtfsStop stop;
  final double distanceMeters;
}

class TransportRepository {
  TransportRepository({
    MalaysiaTransportApi? api,
    LocationService? locationService,
  })  : _api = api ?? MalaysiaTransportApi(),
        _locationService = locationService ?? LocationService();

  final MalaysiaTransportApi _api;
  final LocationService _locationService;
  final Map<TransportAgency, List<GtfsStop>> _stopCache = {};

  Future<Position> currentPosition() => _locationService.getCurrentPosition();

  Future<List<GtfsStop>> stopsFor(
    TransportAgency agency, {
    bool refresh = false,
  }) async {
    if (!refresh && _stopCache.containsKey(agency)) {
      return _stopCache[agency]!;
    }
    final stops = await _api.fetchStops(agency);
    _stopCache[agency] = stops;
    return stops;
  }

  Future<List<NearbyStop>> nearbyStops({
    TransportAgency agency = TransportAgency.prasaranaRail,
    double radiusMeters = 5000,
    int limit = 30,
    Position? position,
  }) async {
    final currentPosition = position ?? await _locationService.getCurrentPosition();
    final stops = await stopsFor(agency);
    final distance = const Distance();
    final current = LatLng(currentPosition.latitude, currentPosition.longitude);

    final nearby = <NearbyStop>[];
    for (final stop in stops) {
      final meters = distance(current, LatLng(stop.latitude, stop.longitude));
      if (meters <= radiusMeters) {
        nearby.add(NearbyStop(stop: stop, distanceMeters: meters));
      }
    }
    nearby.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return nearby.take(limit).toList();
  }

  Future<List<LiveVehicle>> liveVehicles(
    TransportAgency agency, {
    double? nearLatitude,
    double? nearLongitude,
    double radiusMeters = 10000,
  }) async {
    final vehicles = await _api.fetchVehiclePositions(agency);
    if (nearLatitude == null || nearLongitude == null) return vehicles;

    final distance = const Distance();
    final center = LatLng(nearLatitude, nearLongitude);
    return vehicles.where((vehicle) {
      final meters = distance(
        center,
        LatLng(vehicle.latitude, vehicle.longitude),
      );
      return meters <= radiusMeters;
    }).toList();
  }

  void dispose() => _api.dispose();
}
