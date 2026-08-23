import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import 'gtfs_static_service.dart';
import 'gtfs_vehicle_service.dart';
import 'osm_station_service.dart';

class NearbyStationsScreen extends StatefulWidget {
  const NearbyStationsScreen({super.key});

  @override
  State<NearbyStationsScreen> createState() => _NearbyStationsScreenState();
}

class _NearbyStationsScreenState extends State<NearbyStationsScreen> {
  int selected = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _NearbyList(onOpenDetails: () => setState(() => selected = 1)),
      _StationDetails(onLive: () => setState(() => selected = 2)),
      _LiveArrivals(onMap: () => setState(() => selected = 3)),
      _VehicleMap(onBack: () => setState(() => selected = 0)),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          [
            'Nearby Stations',
            'KL Sentral',
            'Live Arrival',
            'Vehicle Map',
          ][selected],
        ),
        leading: selected == 0
            ? null
            : BackButton(onPressed: () => setState(() => selected = 0)),
      ),
      body: pages[selected],
    );
  }
}

class _NearbyList extends StatefulWidget {
  const _NearbyList({required this.onOpenDetails});
  final VoidCallback onOpenDetails;

  @override
  State<_NearbyList> createState() => _NearbyListState();
}

class _NearbyListState extends State<_NearbyList> {
  final _stationService = OsmStationService();
  final _vehicleService = GtfsVehicleService();
  final _searchController = TextEditingController();
  late Future<List<OsmStation>> _stationsFuture;
  late Future<LiveVehicleSnapshot> _vehiclesFuture;
  String _filter = 'All';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _stationsFuture = _stationService.fetchKlangValleyStations();
    _vehiclesFuture = _vehicleService.fetchAllVehicles();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _stationsFuture = _stationService.fetchKlangValleyStations();
      _vehiclesFuture = _vehicleService.fetchAllVehicles();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Object>>(
      future: Future.wait([_stationsFuture, _vehiclesFuture]),
      builder: (context, snapshot) {
        final stationData = snapshot.data?.firstOrNull;
        final vehicleData = snapshot.data?.elementAtOrNull(1);
        final sourceStations = stationData is List<OsmStation>
            ? stationData
            : _fallbackStations;
        final vehicleSnapshot = vehicleData is LiveVehicleSnapshot
            ? vehicleData
            : const LiveVehicleSnapshot(results: []);
        final filteredStations = _filterStations(sourceStations);

        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _OsmStationMap(
                stations: filteredStations,
                vehicles: vehicleSnapshot.vehicles,
              ),
              const SizedBox(height: 12),
              _LiveMapSummary(
                stationCount: filteredStations.length,
                vehicleSnapshot: vehicleSnapshot,
                isLoading: snapshot.connectionState == ConnectionState.waiting,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search OSM stations',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon:
                      snapshot.connectionState == ConnectionState.waiting
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          tooltip: 'Refresh stations',
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['All', 'MRT/LRT', 'Bus', 'KTM']
                    .map(
                      (filter) => ChoiceChip(
                        label: Text(filter),
                        selected: filter == _filter,
                        onSelected: (_) => setState(() => _filter = filter),
                      ),
                    )
                    .toList(),
              ),
              if (snapshot.hasError) ...[
                const SizedBox(height: 14),
                AppCard(
                  color: const Color(0xFFFFF7ED),
                  child: Text(
                    'OSM live station loading failed. Showing local fallback stations.\n${snapshot.error}',
                    style: TextStyle(color: Colors.orange.shade900),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SectionTitle(
                'OSM Stations',
                trailing: '${filteredStations.length} found',
              ),
              const SizedBox(height: 10),
              ...filteredStations
                  .take(40)
                  .map(
                    (station) => _OsmStationTile(
                      station: station,
                      onTap: widget.onOpenDetails,
                    ),
                  ),
              if (filteredStations.length > 40)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Showing first 40 stations. Use search or filters to narrow results.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<OsmStation> _filterStations(List<OsmStation> allStations) {
    return allStations.where((station) {
      final matchesQuery =
          _query.isEmpty ||
          station.name.toLowerCase().contains(_query) ||
          station.typeLabel.toLowerCase().contains(_query);
      final matchesFilter =
          _filter == 'All' ||
          station.typeLabel == _filter ||
          (_filter == 'KTM' && station.type == OsmStationType.rail);
      return matchesQuery && matchesFilter;
    }).toList();
  }
}

class _OsmStationMap extends StatelessWidget {
  const _OsmStationMap({required this.stations, required this.vehicles});

  static const _klSentral = LatLng(3.1342, 101.6861);
  final List<OsmStation> stations;
  final List<LiveVehicle> vehicles;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 280,
        child: FlutterMap(
          options: const MapOptions(
            initialCenter: _klSentral,
            initialZoom: 12,
            minZoom: 10,
            maxZoom: 18,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.go_transit_my',
            ),
            MarkerLayer(
              markers: [
                ...stations.take(80).map((station) {
                  final color = _stationColor(station.type);
                  return Marker(
                    point: station.point,
                    width: 42,
                    height: 42,
                    child: Tooltip(
                      message: station.name,
                      child: Icon(
                        station.type == OsmStationType.bus
                            ? Icons.directions_bus_rounded
                            : Icons.train_rounded,
                        color: color,
                        size: 30,
                      ),
                    ),
                  );
                }),
                ...vehicles.take(160).map((vehicle) {
                  final color = _vehicleColor(vehicle.type);
                  return Marker(
                    point: vehicle.point,
                    width: 44,
                    height: 44,
                    child: Tooltip(
                      message:
                          '${vehicle.feedName}${vehicle.routeId == null ? '' : ' • ${vehicle.routeId}'}',
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: .28),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Icon(
                          vehicle.type == LiveVehicleType.bus
                              ? Icons.directions_bus_filled_rounded
                              : Icons.train_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OsmStationTile extends StatelessWidget {
  const _OsmStationTile({required this.station, required this.onTap});

  final OsmStation station;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _stationColor(station.type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: .12),
            child: Icon(
              station.type == OsmStationType.bus
                  ? Icons.directions_bus_rounded
                  : Icons.train_rounded,
              color: color,
            ),
          ),
          title: Text(
            station.name,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text('${station.typeLabel} • ${station.source}'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _LiveMapSummary extends StatelessWidget {
  const _LiveMapSummary({
    required this.stationCount,
    required this.vehicleSnapshot,
    required this.isLoading,
  });

  final int stationCount;
  final LiveVehicleSnapshot vehicleSnapshot;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      color: const Color(0xFFEFF6FF),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          StatusChip('$stationCount OSM stations', color: AppColors.primary2),
          StatusChip(
            isLoading
                ? 'Loading live vehicles'
                : '${vehicleSnapshot.vehicles.length} live vehicles',
            color: AppColors.success,
          ),
          StatusChip(
            '${vehicleSnapshot.activeFeedCount}/6 feeds active',
            color: vehicleSnapshot.failedFeedCount == 0
                ? AppColors.success
                : AppColors.warning,
          ),
        ],
      ),
    );
  }
}

Color _stationColor(OsmStationType type) {
  return switch (type) {
    OsmStationType.bus => const Color(0xFF0EA5E9),
    OsmStationType.mrtLrt => AppColors.success,
    OsmStationType.rail => const Color(0xFF7C3AED),
    OsmStationType.other => AppColors.primary2,
  };
}

Color _vehicleColor(LiveVehicleType type) {
  return switch (type) {
    LiveVehicleType.bus => const Color(0xFF0EA5E9),
    LiveVehicleType.train => const Color(0xFF10A66B),
    LiveVehicleType.rail => const Color(0xFF7C3AED),
  };
}

DateTime? _latestTimestamp(List<LiveVehicle> vehicles) {
  DateTime? latest;
  for (final vehicle in vehicles) {
    final timestamp = vehicle.timestamp;
    if (timestamp == null) continue;
    if (latest == null || timestamp.isAfter(latest)) {
      latest = timestamp;
    }
  }
  return latest;
}

String _formatTime(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

String _timeAgo(DateTime time) {
  final difference = DateTime.now().difference(time);
  if (difference.isNegative || difference.inSeconds < 60) return 'Now';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
  if (difference.inHours < 24) return '${difference.inHours} hr ago';
  return _formatTime(time);
}

final _fallbackStations = [
  const OsmStation(
    id: 'fallback/kls',
    name: 'KL Sentral',
    type: OsmStationType.rail,
    point: LatLng(3.1342, 101.6861),
    source: 'Local fallback',
  ),
  const OsmStation(
    id: 'fallback/muzium',
    name: 'Muzium Negara',
    type: OsmStationType.mrtLrt,
    point: LatLng(3.1385, 101.6871),
    source: 'Local fallback',
  ),
  const OsmStation(
    id: 'fallback/pasar',
    name: 'Pasar Seni',
    type: OsmStationType.mrtLrt,
    point: LatLng(3.1428, 101.6953),
    source: 'Local fallback',
  ),
  const OsmStation(
    id: 'fallback/klcc',
    name: 'KLCC',
    type: OsmStationType.mrtLrt,
    point: LatLng(3.1597, 101.7131),
    source: 'Local fallback',
  ),
  const OsmStation(
    id: 'fallback/bus',
    name: 'Pudu Sentral Bus Terminal',
    type: OsmStationType.bus,
    point: LatLng(3.1452, 101.7005),
    source: 'Local fallback',
  ),
];

class _StationDetails extends StatelessWidget {
  const _StationDetails({required this.onLive});
  final VoidCallback onLive;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        AppCard(
          color: const Color(0xFFE6F4FF),
          child: SizedBox(
            height: 140,
            child: Stack(
              children: [
                const Align(
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.train_rounded,
                    size: 120,
                    color: AppColors.primary2,
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: IconButton.filledTonal(
                    onPressed: () {},
                    icon: const Icon(Icons.favorite, color: AppColors.danger),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'KL Sentral',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const Text(
          'KLS • Kuala Lumpur • 300 m away',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 18),
        const AppCard(
          color: Color(0xFFECFDF5),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: TransportIcon(
              icon: Icons.check_rounded,
              color: AppColors.success,
            ),
            title: Text(
              'Operational',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text('Open • 5:30 AM - 12:00 AM'),
          ),
        ),
        const SizedBox(height: 18),
        const SectionTitle('Facilities'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              [
                    'Parking',
                    'Restroom',
                    'Lift',
                    'Escalator',
                    'Surau',
                    'Wheelchair',
                  ]
                  .map(
                    (e) => Chip(
                      label: Text(e),
                      avatar: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 16,
                      ),
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: onLive,
          icon: const Icon(Icons.schedule_rounded),
          label: const Text('View Live Arrival'),
        ),
      ],
    );
  }
}

class _LiveArrivals extends StatefulWidget {
  const _LiveArrivals({required this.onMap});
  final VoidCallback onMap;

  @override
  State<_LiveArrivals> createState() => _LiveArrivalsState();
}

class _LiveArrivalsState extends State<_LiveArrivals> {
  final _vehicleService = GtfsVehicleService();
  late Future<LiveVehicleSnapshot> _vehiclesFuture;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _vehiclesFuture = _vehicleService.fetchAllVehicles();
  }

  void _refresh() {
    setState(() {
      _vehiclesFuture = _vehicleService.fetchAllVehicles();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['All', 'MRT/LRT', 'KTM', 'Bus']
              .map(
                (label) => ChoiceChip(
                  label: Text(label),
                  selected: label == _filter,
                  onSelected: (_) => setState(() => _filter = label),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 18),
        FutureBuilder<LiveVehicleSnapshot>(
          future: _vehiclesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return _LiveArrivalError(onRetry: _refresh);
            }

            final data = snapshot.data;
            final vehicles = _filteredVehicles(data?.vehicles ?? const []);
            final latestTimestamp = _latestTimestamp(
              data?.vehicles ?? const [],
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LiveArrivalSummary(
                  vehicleCount: data?.vehicles.length ?? 0,
                  activeFeedCount: data?.activeFeedCount ?? 0,
                  failedFeedCount: data?.failedFeedCount ?? 0,
                  updatedAt: latestTimestamp,
                  onRefresh: _refresh,
                ),
                const SizedBox(height: 16),
                if (vehicles.isEmpty)
                  _NoLiveVehicles(filter: _filter, onRetry: _refresh)
                else
                  for (final vehicle in vehicles.take(14))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _LiveVehicleArrivalCard(vehicle: vehicle),
                    ),
                Text(
                  'Last updated: ${_formatTime(latestTimestamp ?? DateTime.now())}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: widget.onMap,
          icon: const Icon(Icons.map_rounded),
          label: const Text('Track Vehicles'),
        ),
      ],
    );
  }

  List<LiveVehicle> _filteredVehicles(List<LiveVehicle> vehicles) {
    final filtered = vehicles.where((vehicle) {
      return switch (_filter) {
        'MRT/LRT' =>
          vehicle.type == LiveVehicleType.train ||
              vehicle.feedName.toLowerCase().contains('rail'),
        'KTM' =>
          vehicle.type == LiveVehicleType.rail ||
              vehicle.feedName.toLowerCase().contains('ktmb'),
        'Bus' => vehicle.type == LiveVehicleType.bus,
        _ => true,
      };
    }).toList();

    filtered.sort((a, b) {
      final aTime = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return filtered;
  }
}

class _LiveArrivalSummary extends StatelessWidget {
  const _LiveArrivalSummary({
    required this.vehicleCount,
    required this.activeFeedCount,
    required this.failedFeedCount,
    required this.updatedAt,
    required this.onRefresh,
  });

  final int vehicleCount;
  final int activeFeedCount;
  final int failedFeedCount;
  final DateTime? updatedAt;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.primary.withValues(alpha: .07),
      child: Row(
        children: [
          const TransportIcon(icon: Icons.sensors_rounded, size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Live vehicle positions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '$vehicleCount vehicles from $activeFeedCount active feeds',
                  style: const TextStyle(color: AppColors.muted),
                ),
                if (failedFeedCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '$failedFeedCount feed${failedFeedCount == 1 ? '' : 's'} unavailable',
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: onRefresh,
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded),
              ),
              Text(
                updatedAt == null ? 'Now' : _timeAgo(updatedAt!),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveVehicleArrivalCard extends StatelessWidget {
  const _LiveVehicleArrivalCard({required this.vehicle});

  final LiveVehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final color = _vehicleColor(vehicle.type);
    final route = vehicle.routeId?.trim();
    final trip = vehicle.tripId?.trim();
    final speed = vehicle.speed == null
        ? null
        : '${(vehicle.speed! * 3.6).round()} km/h';

    return AppCard(
      color: color.withValues(alpha: .08),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 76,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle.feedName,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  route == null || route.isEmpty
                      ? 'Route information unavailable'
                      : 'Route $route',
                  style: const TextStyle(color: AppColors.muted),
                ),
                if (trip != null && trip.isNotEmpty)
                  Text(
                    'Trip $trip',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    StatusChip('Live GPS', color: color),
                    const StatusChip('Position only', color: AppColors.warning),
                    if (speed != null) StatusChip(speed, color: color),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                vehicle.timestamp == null
                    ? 'Live'
                    : _timeAgo(vehicle.timestamp!),
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                vehicle.timestamp == null
                    ? 'Awaiting timestamp'
                    : _formatTime(vehicle.timestamp!),
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 6),
              const Text(
                'ETA unavailable',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveArrivalError extends StatelessWidget {
  const _LiveArrivalError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.warning.withValues(alpha: .08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live arrival feed unavailable',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Unable to load the government GTFS realtime feeds right now.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _NoLiveVehicles extends StatelessWidget {
  const _NoLiveVehicles({required this.filter, required this.onRetry});
  final String filter;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const Icon(Icons.train_rounded, size: 36, color: AppColors.primary),
          const SizedBox(height: 10),
          Text(
            'No $filter vehicles found',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try another filter or refresh the live feeds.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}

class _VehicleMap extends StatefulWidget {
  const _VehicleMap({required this.onBack});
  final VoidCallback onBack;

  @override
  State<_VehicleMap> createState() => _VehicleMapState();
}

class _VehicleMapState extends State<_VehicleMap> {
  final _vehicleService = GtfsVehicleService();
  final _staticService = GtfsStaticService();
  late Future<_VehicleMapData> _mapFuture;

  @override
  void initState() {
    super.initState();
    _mapFuture = _loadMapData();
  }

  Future<_VehicleMapData> _loadMapData() async {
    final results = await Future.wait<Object>([
      _vehicleService.fetchAllVehicles(),
      _staticService.fetchAllStatic(),
    ]);
    return _VehicleMapData(
      vehicles: results[0] as LiveVehicleSnapshot,
      staticGtfs: results[1] as StaticGtfsSnapshot,
    );
  }

  void _refresh() {
    setState(() {
      _mapFuture = _loadMapData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: FutureBuilder<_VehicleMapData>(
            future: _mapFuture,
            builder: (context, snapshot) {
              final data = snapshot.data;
              final vehicles = data?.vehicles.vehicles ?? const <LiveVehicle>[];
              final stops = data?.staticGtfs.stops ?? const <StaticGtfsStop>[];

              return FlutterMap(
                options: const MapOptions(
                  initialCenter: LatLng(3.139, 101.6869),
                  initialZoom: 11,
                  minZoom: 5,
                  maxZoom: 18,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.go_transit_my',
                  ),
                  if (stops.isNotEmpty)
                    MarkerLayer(
                      markers: stops
                          .take(350)
                          .map(_buildStaticStopMarker)
                          .toList(),
                    ),
                  if (vehicles.isNotEmpty)
                    MarkerLayer(
                      markers: vehicles
                          .take(250)
                          .map(_buildVehicleMarker)
                          .toList(),
                    ),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Align(
                      alignment: Alignment.topCenter,
                      child: LinearProgressIndicator(minHeight: 3),
                    ),
                ],
              );
            },
          ),
        ),
        Positioned(
          top: 14,
          right: 14,
          child: FloatingActionButton.small(
            heroTag: 'refresh-vehicle-map',
            onPressed: _refresh,
            tooltip: 'Refresh live map',
            child: const Icon(Icons.refresh_rounded),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 28,
          child: FutureBuilder<_VehicleMapData>(
            future: _mapFuture,
            builder: (context, snapshot) {
              final data = snapshot.data;
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting;
              final staticGtfs = data?.staticGtfs;
              final vehicles = data?.vehicles;
              final latest = _latestTimestamp(vehicles?.vehicles ?? const []);

              return AppCard(
                child: Row(
                  children: [
                    const TransportIcon(
                      icon: Icons.directions_transit_rounded,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'GTFS Vehicle Map',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isLoading
                                ? 'Loading vehicle-position and static GTFS feeds...'
                                : '${vehicles?.vehicles.length ?? 0} live vehicles • '
                                      '${staticGtfs?.stops.length ?? 0} static stops • '
                                      '${staticGtfs?.routeCount ?? 0} routes',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              StatusChip(
                                '${vehicles?.activeFeedCount ?? 0}/6 live feeds',
                                color: (vehicles?.failedFeedCount ?? 0) == 0
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                              StatusChip(
                                '${staticGtfs?.activeFeedCount ?? 0}/2 static feeds',
                                color: (staticGtfs?.failedFeedCount ?? 0) == 0
                                    ? AppColors.primary2
                                    : AppColors.warning,
                              ),
                              StatusChip(
                                latest == null
                                    ? 'Updated now'
                                    : _timeAgo(latest),
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onBack,
                      tooltip: 'Close map',
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Marker _buildStaticStopMarker(StaticGtfsStop stop) {
    return Marker(
      point: stop.point,
      width: 32,
      height: 32,
      child: Tooltip(
        message: '${stop.name}\n${stop.agency} static GTFS stop',
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x260B1220), blurRadius: 8),
            ],
          ),
          child: const Icon(
            Icons.place_rounded,
            color: AppColors.primary,
            size: 18,
          ),
        ),
      ),
    );
  }

  Marker _buildVehicleMarker(LiveVehicle vehicle) {
    final color = _vehicleColor(vehicle.type);
    return Marker(
      point: vehicle.point,
      width: 42,
      height: 42,
      rotate: true,
      child: Tooltip(
        message:
            '${vehicle.feedName}\n${vehicle.routeId == null ? 'Route unavailable' : 'Route ${vehicle.routeId}'}',
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0x330B1220), blurRadius: 10),
            ],
          ),
          child: Icon(
            vehicle.type == LiveVehicleType.bus
                ? Icons.directions_bus_rounded
                : Icons.train_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _VehicleMapData {
  const _VehicleMapData({required this.vehicles, required this.staticGtfs});

  final LiveVehicleSnapshot vehicles;
  final StaticGtfsSnapshot staticGtfs;
}
