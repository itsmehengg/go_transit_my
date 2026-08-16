import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/transport_models.dart';
import '../../data/transport_repository.dart';
import '../../data/user_preferences.dart';

class NearbyStationsScreen extends StatefulWidget {
  const NearbyStationsScreen({super.key});

  @override
  State<NearbyStationsScreen> createState() => _NearbyStationsScreenState();
}

class _NearbyStationsScreenState extends State<NearbyStationsScreen> {
  final TransportRepository _repository = TransportRepository();
  int _page = 0;
  GtfsStop? _selectedStop;
  double? _selectedDistance;

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  void _openStop(NearbyStop item) {
    setState(() {
      _selectedStop = item.stop;
      _selectedDistance = item.distanceMeters;
      _page = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      'Nearby Stations',
      _selectedStop?.name ?? 'Station Details',
      'Live Vehicle Map',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_page]),
        leading: _page == 0
            ? null
            : BackButton(onPressed: () => setState(() => _page = 0)),
      ),
      body: switch (_page) {
        0 => _NearbyList(repository: _repository, onOpenDetails: _openStop),
        1 => _StationDetails(
            stop: _selectedStop!,
            distanceMeters: _selectedDistance,
            onTrackVehicles: () => setState(() => _page = 2),
          ),
        _ => _VehicleMap(repository: _repository),
      },
    );
  }
}

class _NearbyList extends StatefulWidget {
  const _NearbyList({required this.repository, required this.onOpenDetails});

  final TransportRepository repository;
  final ValueChanged<NearbyStop> onOpenDetails;

  @override
  State<_NearbyList> createState() => _NearbyListState();
}

class _NearbyListState extends State<_NearbyList> {
  final TextEditingController _searchController = TextEditingController();
  List<NearbyStop> _stops = const [];
  bool _loading = true;
  String? _error;
  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final position = await widget.repository.currentPosition();
      if (refresh) {
        await widget.repository.stopsFor(
          TransportAgency.prasaranaRail,
          refresh: true,
        );
      }
      final nearby = await widget.repository.nearbyStops(
        agency: TransportAgency.prasaranaRail,
        radiusMeters: 30000,
        limit: 50,
        position: position,
      );
      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _stops = nearby;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }

    final query = _searchController.text.trim().toLowerCase();
    final visibleStops = query.isEmpty
        ? _stops
        : _stops
            .where((item) => item.stop.name.toLowerCase().contains(query))
            .toList();

    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SizedBox(
            height: 230,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: _currentLocation ?? const LatLng(3.1390, 101.6869),
                  initialZoom: 13,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.go_transit_my',
                  ),
                  MarkerLayer(
                    markers: [
                      if (_currentLocation != null)
                        Marker(
                          point: _currentLocation!,
                          width: 44,
                          height: 44,
                          child: const Icon(
                            Icons.my_location_rounded,
                            color: AppColors.primary,
                            size: 34,
                          ),
                        ),
                      ..._stops.take(20).map(
                            (item) => Marker(
                              point: LatLng(
                                item.stop.latitude,
                                item.stop.longitude,
                              ),
                              width: 38,
                              height: 38,
                              child: const Icon(
                                Icons.train_rounded,
                                color: AppColors.success,
                                size: 30,
                              ),
                            ),
                          ),
                    ],
                  ),
                  const Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: EdgeInsets.all(6),
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Colors.white70),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          child: Text(
                            '© OpenStreetMap contributors',
                            style: TextStyle(fontSize: 9),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search nearby rail stations',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Official source: data.gov.my • Prasarana GTFS Static (rapid-rail-kl)',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          if (visibleStops.isEmpty)
            const AppCard(
              child: Text(
                'No Prasarana rail stations were found within 30 km of your current location.',
              ),
            )
          else
            ...visibleStops.map(
              (item) => Card(
                child: ListTile(
                  leading: const TransportIcon(
                    icon: Icons.train_rounded,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    item.stop.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    item.stop.code == null
                        ? 'Prasarana rail'
                        : 'Code: ${item.stop.code}',
                  ),
                  trailing: Text(_formatDistance(item.distanceMeters)),
                  onTap: () => widget.onOpenDetails(item),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StationDetails extends StatefulWidget {
  const _StationDetails({
    required this.stop,
    required this.onTrackVehicles,
    this.distanceMeters,
  });

  final GtfsStop stop;
  final double? distanceMeters;
  final VoidCallback onTrackVehicles;

  @override
  State<_StationDetails> createState() => _StationDetailsState();
}

class _StationDetailsState extends State<_StationDetails> {
  final UserPreferences _preferences = UserPreferences();
  bool _favourite = false;

  @override
  void initState() {
    super.initState();
    _loadFavourite();
  }

  Future<void> _loadFavourite() async {
    final ids = await _preferences.getFavouriteStopIds();
    if (mounted) setState(() => _favourite = ids.contains(widget.stop.id));
  }

  Future<void> _toggleFavourite() async {
    final value = await _preferences.toggleFavouriteStop(widget.stop.id);
    if (mounted) setState(() => _favourite = value);
  }

  @override
  Widget build(BuildContext context) {
    final stop = widget.stop;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SizedBox(
          height: 220,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(stop.latitude, stop.longitude),
                initialZoom: 16,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.go_transit_my',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(stop.latitude, stop.longitude),
                      width: 52,
                      height: 52,
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: AppColors.danger,
                        size: 46,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stop.name,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (stop.code != null) 'Code ${stop.code}',
                      if (widget.distanceMeters != null)
                        _formatDistance(widget.distanceMeters!),
                    ].join(' • '),
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              onPressed: _toggleFavourite,
              icon: Icon(
                _favourite ? Icons.favorite : Icons.favorite_border,
                color: _favourite ? AppColors.danger : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        AppCard(
          color: const Color(0xFFEFF6FF),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Official GTFS station information',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Text('Stop ID: ${stop.id}'),
              Text('Latitude: ${stop.latitude.toStringAsFixed(6)}'),
              Text('Longitude: ${stop.longitude.toStringAsFixed(6)}'),
              const SizedBox(height: 8),
              const Text(
                'Facilities are not included in the GTFS feed, so this app does not invent facility information.',
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const AppCard(
          color: Color(0xFFFFF7ED),
          child: Text(
            'Malaysia\'s official GTFS Realtime currently provides vehicle positions only. Stable Rapid Rail realtime vehicle positions are not currently provided, so live tracking below uses supported Rapid Bus KL vehicle-position data.',
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: widget.onTrackVehicles,
          icon: const Icon(Icons.directions_bus_rounded),
          label: const Text('View Live Rapid Bus Vehicles'),
        ),
      ],
    );
  }
}

class _VehicleMap extends StatefulWidget {
  const _VehicleMap({required this.repository});

  final TransportRepository repository;

  @override
  State<_VehicleMap> createState() => _VehicleMapState();
}

class _VehicleMapState extends State<_VehicleMap> {
  List<LiveVehicle> _vehicles = const [];
  bool _loading = true;
  String? _error;
  DateTime? _updatedAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final vehicles = await widget.repository.liveVehicles(
        TransportAgency.prasaranaBusKl,
      );
      if (!mounted) return;
      setState(() {
        _vehicles = vehicles;
        _updatedAt = DateTime.now();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorState(message: _error!, onRetry: _load);

    const fallbackCenter = LatLng(3.1390, 101.6869);
    final center = _vehicles.isEmpty
        ? fallbackCenter
        : LatLng(_vehicles.first.latitude, _vehicles.first.longitude);

    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            options: MapOptions(initialCenter: center, initialZoom: 11),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.go_transit_my',
              ),
              MarkerLayer(
                markers: _vehicles
                    .map(
                      (vehicle) => Marker(
                        point: LatLng(vehicle.latitude, vehicle.longitude),
                        width: 42,
                        height: 42,
                        child: Tooltip(
                          message: vehicle.label ?? vehicle.routeId ?? vehicle.id,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.directions_bus_rounded,
                              color: Colors.white,
                              size: 25,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 20,
          child: AppCard(
            child: Row(
              children: [
                const TransportIcon(
                  icon: Icons.directions_bus_rounded,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_vehicles.length} live Rapid Bus KL vehicles',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        _updatedAt == null
                            ? 'Official GTFS Realtime vehicle-position feed'
                            : 'Refreshed ${_timeLabel(_updatedAt!)} • data.gov.my',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.warning),
            const SizedBox(height: 14),
            const Text(
              'Unable to load transport data',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

String _timeLabel(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
