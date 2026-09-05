import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../stations/location_service.dart';
import 'route_map_service.dart';
import 'station_catalog.dart';

class RouteStationSelectionMap extends StatefulWidget {
  const RouteStationSelectionMap({
    super.key,
    required this.selected,
    required this.onStationSelected,
  });

  final RouteStation? selected;
  final ValueChanged<RouteStation> onStationSelected;

  @override
  State<RouteStationSelectionMap> createState() =>
      _RouteStationSelectionMapState();
}

class _RouteStationSelectionMapState extends State<RouteStationSelectionMap> {
  final _mapService = RouteMapService();
  final _locationService = LocationService();

  LatLng? _current;
  List<RouteMapStationPoint> _stations = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final current = await _locationService.getCurrentLocation();
      final stations = await _mapService.loadStationPoints();

      if (!mounted) return;

      setState(() {
        _current = current;
        _stations = stations;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _message(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_current == null) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: const Color(0xFFF8FAFC),
        ),
        child: Text(
          _error ?? 'Map is unavailable.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 320,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: _current!,
                initialZoom: 11.5,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'go_transit_my',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _current!,
                      width: 52,
                      height: 52,
                      child: const _CurrentLocationMarker(),
                    ),
                    for (final item in _stations)
                      Marker(
                        point: item.point,
                        width: 46,
                        height: 46,
                        child: GestureDetector(
                          onTap: () =>
                              widget.onStationSelected(item.station),
                          child: _StationMarker(
                            mode: item.station.mode,
                            selected: widget.selected?.name ==
                                item.station.name,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 12,
                      color: Color(0x22000000),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.touch_app_rounded,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.selected == null
                            ? 'Tap a station marker to choose your destination'
                            : 'Destination: ${widget.selected!.name}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _message(Object error) {
    final text = error.toString();
    if (text.startsWith('Exception: ')) {
      return text.substring('Exception: '.length);
    }
    return 'Unable to load your current location on the map.';
  }
}

class RouteJourneyMapCard extends StatefulWidget {
  const RouteJourneyMapCard({
    super.key,
    required this.currentLocation,
    required this.destination,
    required this.estimatedArrival,
    required this.totalJourneyMinutes,
  });

  final LatLng currentLocation;
  final RouteStation destination;
  final DateTime? estimatedArrival;
  final int? totalJourneyMinutes;

  @override
  State<RouteJourneyMapCard> createState() => _RouteJourneyMapCardState();
}

class _RouteJourneyMapCardState extends State<RouteJourneyMapCard> {
  final _mapService = RouteMapService();

  LatLng? _destinationPoint;
  RoadRouteOverview? _road;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant RouteJourneyMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.destination.name != widget.destination.name ||
        oldWidget.currentLocation != widget.currentLocation) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final destination =
        await _mapService.findStationPoint(widget.destination);

    RoadRouteOverview? road;
    if (destination != null) {
      try {
        road = await _mapService.fetchRoadRoute(
          from: widget.currentLocation,
          to: destination,
        );
      } catch (_) {
        road = null;
      }
    }

    if (!mounted) return;

    setState(() {
      _destinationPoint = destination;
      _road = road;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final destination = _destinationPoint;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            blurRadius: 16,
            color: Color(0x16000000),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 330,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : destination == null
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Destination coordinates are unavailable for this station.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : FlutterMap(
                        options: MapOptions(
                          initialCenter: _centre(
                            widget.currentLocation,
                            destination,
                          ),
                          initialZoom: _zoom(
                            widget.currentLocation,
                            destination,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'go_transit_my',
                          ),
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _road?.points ??
                                    [
                                      widget.currentLocation,
                                      destination,
                                    ],
                                strokeWidth: 6,
                                color: const Color(0xFF2563EB),
                              ),
                            ],
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: widget.currentLocation,
                                width: 52,
                                height: 52,
                                child: const _CurrentLocationMarker(),
                              ),
                              Marker(
                                point: destination,
                                width: 56,
                                height: 56,
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  size: 48,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.navigation_rounded,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Location → ${widget.destination.name}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 5),
                      if (widget.estimatedArrival != null)
                        Text(
                          'Estimated arrival ${_formatTime(widget.estimatedArrival!)}${widget.totalJourneyMinutes == null ? '' : ' • ${widget.totalJourneyMinutes} min'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      if (_road != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${_formatDistance(_road!.distanceMetres)} road overview',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'Blue line follows the road network to the selected station. Public transport timing and transfers are shown in Route Details below.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  LatLng _centre(LatLng a, LatLng b) {
    return LatLng(
      (a.latitude + b.latitude) / 2,
      (a.longitude + b.longitude) / 2,
    );
  }

  double _zoom(LatLng a, LatLng b) {
    final lat = (a.latitude - b.latitude).abs();
    final lon = (a.longitude - b.longitude).abs();
    final spread = lat > lon ? lat : lon;

    if (spread < 0.01) return 14.5;
    if (spread < 0.03) return 13.2;
    if (spread < 0.07) return 12.0;
    if (spread < 0.15) return 10.8;
    return 9.5;
  }
}

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            blurRadius: 8,
            color: Color(0x33000000),
          ),
        ],
        border: Border.all(
          width: 3,
          color: const Color(0xFF2563EB),
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: const DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF2563EB),
        ),
      ),
    );
  }
}

class _StationMarker extends StatelessWidget {
  const _StationMarker({
    required this.mode,
    required this.selected,
  });

  final String mode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? const Color(0xFF2563EB) : Colors.white,
        border: Border.all(
          color: selected ? Colors.white : const Color(0xFF2563EB),
          width: 3,
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 8,
            color: Color(0x33000000),
          ),
        ],
      ),
      child: Icon(
        mode == 'KTM' ? Icons.train_rounded : Icons.subway_rounded,
        size: 23,
        color: selected ? Colors.white : const Color(0xFF2563EB),
      ),
    );
  }
}

String _formatTime(DateTime value) {
  final hour = value.hour == 0
      ? 12
      : value.hour > 12
          ? value.hour - 12
          : value.hour;
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
}

String _formatDistance(double metres) {
  if (metres < 1000) return '${metres.round()} m';
  return '${(metres / 1000).toStringAsFixed(1)} km';
}
