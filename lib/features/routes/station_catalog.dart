import 'government_route_data_service.dart';

class RouteStation {
  const RouteStation({
    required this.name,
    required this.mode,
  });

  final String name;
  final String mode;
}

List<RouteStation> routeStations = <RouteStation>[];

Future<List<RouteStation>> loadGovernmentRouteStations({
  bool refresh = false,
}) async {
  if (refresh) {
    GovernmentRouteDataService.instance.refresh();
  }

  final data = await GovernmentRouteDataService.instance.load();
  routeStations = List<RouteStation>.from(data.stations);
  return routeStations;
}
