import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../profile/personalisation_service.dart';
import 'gtfs_static_service.dart';
import 'gtfs_vehicle_service.dart';
import 'location_service.dart';

class NearbyStationsScreen extends StatefulWidget {
  const NearbyStationsScreen({super.key});

  @override
  State<NearbyStationsScreen> createState() => _NearbyStationsScreenState();
}

class _NearbyStationsScreenState extends State<NearbyStationsScreen> {
  final _staticService = GtfsStaticService();
  final _vehicleService = GtfsVehicleService();
  final _locationService = LocationService();
  final _searchController = TextEditingController();

  late Future<_StationBundle> _future;
  StaticGtfsStop? _selectedStation;
  int _view = 0;
  String _query = '';
  String _agency = 'All';

  @override
  void initState() {
    super.initState();
    _future = _loadData();
    _searchController.addListener(() {
      if (mounted) setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_StationBundle> _loadData() async {
    final results = await Future.wait([
      _staticService.fetchAllStatic(),
      _vehicleService.fetchAllVehicles(),
    ]);
    final staticSnapshot = results[0] as StaticGtfsSnapshot;
    final vehicleSnapshot = results[1] as LiveVehicleSnapshot;

    LatLng? userLocation;
    Object? locationError;
    try {
      userLocation = await _locationService.getCurrentLocation();
    } catch (error) {
      locationError = error;
    }

    final stops = [...staticSnapshot.stops];
    if (userLocation != null) {
      stops.sort((a, b) {
        final da = _locationService.distanceMetres(userLocation!, a.point);
        final db = _locationService.distanceMetres(userLocation!, b.point);
        return da.compareTo(db);
      });
    } else {
      stops.sort((a, b) => a.name.compareTo(b.name));
    }

    return _StationBundle(
      staticSnapshot: staticSnapshot,
      vehicleSnapshot: vehicleSnapshot,
      stops: stops,
      userLocation: userLocation,
      locationError: locationError,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _loadData());
    await _future;
  }

  void _openStation(StaticGtfsStop station) {
    setState(() {
      _selectedStation = station;
      _view = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_view) {
      1 => _selectedStation?.name ?? 'Station Details',
      2 => 'Live Vehicle Map',
      _ => 'Nearby Stations',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        leading: _view == 0
            ? null
            : BackButton(onPressed: () => setState(() => _view = _view == 2 && _selectedStation != null ? 1 : 0)),
        actions: [
          if (_view == 0)
            IconButton(
              tooltip: 'Refresh official data',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: FutureBuilder<_StationBundle>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(error: snapshot.error, onRetry: _refresh);
          }
          final data = snapshot.requireData;
          if (_view == 1 && _selectedStation != null) {
            return _StationDetails(
              station: _selectedStation!,
              data: data,
              staticService: _staticService,
              locationService: _locationService,
              onOpenMap: () => setState(() => _view = 2),
            );
          }
          if (_view == 2) {
            return _LiveVehicleMap(data: data, station: _selectedStation);
          }
          return _StationList(
            data: data,
            query: _query,
            agency: _agency,
            searchController: _searchController,
            locationService: _locationService,
            onAgencyChanged: (value) => setState(() => _agency = value),
            onOpenStation: _openStation,
            onOpenLiveMap: () => setState(() {
              _selectedStation = null;
              _view = 2;
            }),
            onRefresh: _refresh,
          );
        },
      ),
    );
  }
}

class _StationList extends StatelessWidget {
  const _StationList({
    required this.data,
    required this.query,
    required this.agency,
    required this.searchController,
    required this.locationService,
    required this.onAgencyChanged,
    required this.onOpenStation,
    required this.onOpenLiveMap,
    required this.onRefresh,
  });

  final _StationBundle data;
  final String query;
  final String agency;
  final TextEditingController searchController;
  final LocationService locationService;
  final ValueChanged<String> onAgencyChanged;
  final ValueChanged<StaticGtfsStop> onOpenStation;
  final VoidCallback onOpenLiveMap;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final filtered = data.stops.where((stop) {
      final queryMatch = query.isEmpty ||
          stop.name.toLowerCase().contains(query) ||
          stop.agency.toLowerCase().contains(query);
      final agencyMatch = agency == 'All' || stop.agency == agency;
      return queryMatch && agencyMatch;
    }).toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _StationMap(
            stops: filtered.take(100).toList(),
            vehicles: data.vehicleSnapshot.vehicles.take(180).toList(),
            userLocation: data.userLocation,
          ),
          const SizedBox(height: 12),
          AppCard(
            color: const Color(0xFFEFF6FF),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusChip('${data.staticSnapshot.stops.length} official stops', color: AppColors.primary2),
                StatusChip('${data.staticSnapshot.routeCount} routes', color: AppColors.primary),
                StatusChip('${data.vehicleSnapshot.vehicles.length} live vehicles', color: AppColors.success),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (data.locationError != null)
            AppCard(
              color: const Color(0xFFFFF7ED),
              child: Row(
                children: [
                  const Icon(Icons.location_off_rounded, color: AppColors.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'GPS unavailable: ${data.locationError}. Stations are shown alphabetically.',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
          if (data.locationError != null) const SizedBox(height: 12),
          TextField(
            controller: searchController,
            decoration: const InputDecoration(
              hintText: 'Search official Malaysian stations',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: ['All', 'Prasarana', 'KTMB']
                .map((item) => ChoiceChip(
                      label: Text(item),
                      selected: item == agency,
                      onSelected: (_) => onAgencyChanged(item),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: SectionTitle(data.userLocation == null ? 'Stations' : 'Nearest Stations')),
              TextButton.icon(
                onPressed: onOpenLiveMap,
                icon: const Icon(Icons.directions_bus_filled_rounded),
                label: const Text('Live Map'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: Text('No stations match your search.')),
            ),
          ...filtered.take(60).map((stop) {
            final distance = data.userLocation == null
                ? null
                : locationService.distanceMetres(data.userLocation!, stop.point);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (stop.agency == 'KTMB' ? const Color(0xFF7C3AED) : AppColors.success)
                        .withValues(alpha: .12),
                    child: Icon(
                      Icons.train_rounded,
                      color: stop.agency == 'KTMB' ? const Color(0xFF7C3AED) : AppColors.success,
                    ),
                  ),
                  title: Text(stop.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                    '${stop.agency}${distance == null ? '' : ' • ${_formatDistance(distance)}'}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => onOpenStation(stop),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          const Text(
            'Station, route and scheduled timetable data: official Malaysia GTFS Static (api.data.gov.my). Live markers: official GTFS Realtime vehicle-position feeds. Map tiles: OpenStreetMap.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _StationDetails extends StatelessWidget {
  const _StationDetails({
    required this.station,
    required this.data,
    required this.staticService,
    required this.locationService,
    required this.onOpenMap,
  });

  final StaticGtfsStop station;
  final _StationBundle data;
  final GtfsStaticService staticService;
  final LocationService locationService;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final personalisation = PersonalisationService.instance;
    final distance = data.userLocation == null
        ? null
        : locationService.distanceMetres(data.userLocation!, station.point);
    final nearbyVehicles = [...data.vehicleSnapshot.vehicles]
      ..sort((a, b) {
        final da = locationService.distanceMetres(station.point, a.point);
        final db = locationService.distanceMetres(station.point, b.point);
        return da.compareTo(db);
      });

    return AnimatedBuilder(
      animation: personalisation,
      builder: (context, _) {
        final favourite = personalisation.isFavouriteStation(station.name);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AppCard(
              color: const Color(0xFFE6F4FF),
              child: Row(
                children: [
                  const TransportIcon(icon: Icons.train_rounded, color: AppColors.primary2, size: 64),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(station.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text('${station.agency} • Stop ${station.rawId}', style: const TextStyle(color: AppColors.muted)),
                        if (distance != null) Text('${_formatDistance(distance)} from your location'),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: favourite ? 'Remove favourite' : 'Add favourite',
                    onPressed: () => personalisation.toggleFavouriteStation(station.name),
                    icon: Icon(favourite ? Icons.favorite : Icons.favorite_border, color: AppColors.danger),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('Station Information'),
                  const SizedBox(height: 10),
                  Text('Latitude: ${station.point.latitude.toStringAsFixed(6)}'),
                  Text('Longitude: ${station.point.longitude.toStringAsFixed(6)}'),
                  Text('Operator feed: ${station.agency}'),
                  const SizedBox(height: 6),
                  const Text('Source: Malaysia Government GTFS Static', style: TextStyle(color: AppColors.muted)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(child: SectionTitle('Nearest Live Vehicles')),
                      TextButton(onPressed: onOpenMap, child: const Text('Open Map')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (nearbyVehicles.isEmpty)
                    const Text('No realtime vehicle positions are available right now.'),
                  ...nearbyVehicles.take(4).map((vehicle) {
                    final metres = locationService.distanceMetres(station.point, vehicle.point);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        vehicle.type == LiveVehicleType.bus ? Icons.directions_bus_rounded : Icons.train_rounded,
                        color: AppColors.success,
                      ),
                      title: Text(vehicle.feedName, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${vehicle.routeId ?? 'Route unavailable'} • ${_formatDistance(metres)} from station'),
                      trailing: Text(vehicle.timestamp == null ? 'Live' : _timeAgo(vehicle.timestamp!)),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _TimetableCard(station: station, service: staticService),
          ],
        );
      },
    );
  }
}

class _TimetableCard extends StatefulWidget {
  const _TimetableCard({required this.station, required this.service});
  final StaticGtfsStop station;
  final GtfsStaticService service;

  @override
  State<_TimetableCard> createState() => _TimetableCardState();
}

class _TimetableCardState extends State<_TimetableCard> {
  late Future<List<ScheduledDeparture>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.service.fetchDepartures(widget.station);
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Scheduled Timetable'),
          const SizedBox(height: 10),
          FutureBuilder<List<ScheduledDeparture>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Text('Unable to load timetable: ${snapshot.error}', style: const TextStyle(color: AppColors.danger));
              }
              final departures = snapshot.data ?? const <ScheduledDeparture>[];
              if (departures.isEmpty) {
                return const Text('No upcoming scheduled times were found in the current GTFS feed.');
              }
              return Column(
                children: departures
                    .map((departure) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.schedule_rounded, color: AppColors.primary),
                          title: Text('${departure.time} • ${departure.route}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(departure.destination),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 6),
          const Text(
            'Times are scheduled GTFS data, not a realtime arrival prediction. Realtime data in this app is used only for vehicle positions where available.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _LiveVehicleMap extends StatelessWidget {
  const _LiveVehicleMap({required this.data, this.station});
  final _StationBundle data;
  final StaticGtfsStop? station;

  @override
  Widget build(BuildContext context) {
    final center = station?.point ?? data.userLocation ?? const LatLng(3.1390, 101.6869);
    return Column(
      children: [
        Expanded(
          child: FlutterMap(
            options: MapOptions(initialCenter: center, initialZoom: station == null ? 11 : 14),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.go_transit_my',
              ),
              MarkerLayer(
                markers: [
                  if (data.userLocation != null)
                    Marker(
                      point: data.userLocation!,
                      width: 46,
                      height: 46,
                      child: const Tooltip(
                        message: 'Your location',
                        child: Icon(Icons.my_location_rounded, color: AppColors.primary, size: 32),
                      ),
                    ),
                  if (station != null)
                    Marker(
                      point: station!.point,
                      width: 50,
                      height: 50,
                      child: Tooltip(
                        message: station!.name,
                        child: const Icon(Icons.location_on_rounded, color: AppColors.danger, size: 38),
                      ),
                    ),
                  ...data.vehicleSnapshot.vehicles.map((vehicle) => Marker(
                        point: vehicle.point,
                        width: 42,
                        height: 42,
                        child: Tooltip(
                          message: '${vehicle.feedName}${vehicle.routeId == null ? '' : ' • ${vehicle.routeId}'}',
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _vehicleColor(vehicle.type),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Icon(
                              vehicle.type == LiveVehicleType.bus ? Icons.directions_bus_filled_rounded : Icons.train_rounded,
                              color: Colors.white,
                              size: 21,
                            ),
                          ),
                        ),
                      )),
                ],
              ),
              const RichAttributionWidget(
                attributions: [TextSourceAttribution('OpenStreetMap contributors')],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: AppCard(
            color: const Color(0xFFEFF6FF),
            child: Row(
              children: [
                const Icon(Icons.sensors_rounded, color: AppColors.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${data.vehicleSnapshot.vehicles.length} current vehicle positions • ${data.vehicleSnapshot.activeFeedCount} feeds active',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StationMap extends StatelessWidget {
  const _StationMap({required this.stops, required this.vehicles, required this.userLocation});
  final List<StaticGtfsStop> stops;
  final List<LiveVehicle> vehicles;
  final LatLng? userLocation;

  @override
  Widget build(BuildContext context) {
    final center = userLocation ?? (stops.isNotEmpty ? stops.first.point : const LatLng(3.1390, 101.6869));
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 270,
        child: FlutterMap(
          options: MapOptions(initialCenter: center, initialZoom: userLocation == null ? 10.5 : 13),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.go_transit_my',
            ),
            MarkerLayer(
              markers: [
                if (userLocation != null)
                  Marker(
                    point: userLocation!,
                    width: 44,
                    height: 44,
                    child: const Icon(Icons.my_location_rounded, color: AppColors.primary, size: 30),
                  ),
                ...stops.map((stop) => Marker(
                      point: stop.point,
                      width: 34,
                      height: 34,
                      child: Tooltip(
                        message: stop.name,
                        child: Icon(Icons.train_rounded, color: stop.agency == 'KTMB' ? const Color(0xFF7C3AED) : AppColors.success, size: 24),
                      ),
                    )),
                ...vehicles.map((vehicle) => Marker(
                      point: vehicle.point,
                      width: 34,
                      height: 34,
                      child: Icon(
                        vehicle.type == LiveVehicleType.bus ? Icons.directions_bus_filled_rounded : Icons.train_rounded,
                        color: _vehicleColor(vehicle.type),
                        size: 22,
                      ),
                    )),
              ],
            ),
            const RichAttributionWidget(
              attributions: [TextSourceAttribution('OpenStreetMap contributors')],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AppCard(
          color: const Color(0xFFFFF1F2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.danger),
              const SizedBox(height: 12),
              const Text('Unable to load transport data', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 8),
              Text('$error', textAlign: TextAlign.center),
              const SizedBox(height: 14),
              ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

class _StationBundle {
  const _StationBundle({
    required this.staticSnapshot,
    required this.vehicleSnapshot,
    required this.stops,
    required this.userLocation,
    required this.locationError,
  });

  final StaticGtfsSnapshot staticSnapshot;
  final LiveVehicleSnapshot vehicleSnapshot;
  final List<StaticGtfsStop> stops;
  final LatLng? userLocation;
  final Object? locationError;
}

Color _vehicleColor(LiveVehicleType type) {
  return switch (type) {
    LiveVehicleType.bus => const Color(0xFF0EA5E9),
    LiveVehicleType.train => AppColors.success,
    LiveVehicleType.rail => const Color(0xFF7C3AED),
  };
}

String _formatDistance(double metres) {
  if (metres < 1000) return '${metres.round()} m';
  return '${(metres / 1000).toStringAsFixed(1)} km';
}

String _timeAgo(DateTime time) {
  final difference = DateTime.now().difference(time);
  if (difference.isNegative || difference.inSeconds < 60) return 'Now';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
  if (difference.inHours < 24) return '${difference.inHours} hr ago';
  return '${time.day}/${time.month}';
}
