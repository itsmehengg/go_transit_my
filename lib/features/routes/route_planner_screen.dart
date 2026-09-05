import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../profile/personalisation_service.dart';
import '../stations/location_service.dart';
import 'fare_estimation_service.dart';
import 'route_map_service.dart';
import 'route_search_service.dart';
import 'station_catalog.dart';

class RoutePlannerScreen extends StatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen> {
  final _mapController = MapController();
  final _mapService = RouteMapService();
  final _locationService = LocationService();
  final _fareService = FareEstimationService();

  late final PersonalisationService _personalisation;

  List<RouteMapStationPoint> _stations = <RouteMapStationPoint>[];
  RouteMapStationPoint? _to;
  RouteSearchResult? _route;
  RouteJourneyDetails? _journey;
  FareEstimateInfo? _fare;

  LatLng? _currentLocation;
  DateTime _departure = DateTime.now();
  String _transport = 'All';

  bool _loadingStations = true;
  bool _searching = false;
  bool _showResult = false;
  bool _saving = false;
  String? _stationError;

  @override
  void initState() {
    super.initState();
    _personalisation = PersonalisationService.instance;

    final preferred = _personalisation.preferredTransport;
    if (const <String>['All', 'MRT', 'LRT', 'KTM', 'Bus', 'Rail']
        .contains(preferred)) {
      _transport = preferred;
    }

    _loadStations();
    _loadLocation();
  }

  Future<void> _loadStations() async {
    setState(() {
      _loadingStations = true;
      _stationError = null;
    });

    try {
      final stations = await _mapService.loadStationPoints();

      if (!mounted) return;

      setState(() {
        _stations = stations;
        _loadingStations = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loadingStations = false;
        _stationError = _errorText(error);
      });

      _message('GTFS station error: ${_errorText(error)}');
    }
  }

  Future<void> _loadLocation() async {
    try {
      final location = await _locationService.getCurrentLocation();

      if (!mounted) return;

      setState(() {
        _currentLocation = location;
      });

      _mapController.move(location, 11);
    } catch (_) {
      if (!mounted) return;

      const fallback = LatLng(3.1390, 101.6869);

      setState(() {
        _currentLocation = fallback;
      });

      _mapController.move(fallback, 11);
    }
  }

  Future<void> _selectDestination() async {
    final station = await Navigator.of(context).push<RouteMapStationPoint>(
      MaterialPageRoute(
        builder: (_) => _StationPicker(
          title: 'Select destination',
          stations: _filteredStations(),
        ),
      ),
    );

    if (station == null || !mounted) return;

    _setDestination(station);
  }

  void _setDestination(RouteMapStationPoint station) {
    setState(() {
      _to = station;
      _clearResult();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(station.point, 16);
    });
  }

  void _clearResult() {
    _route = null;
    _journey = null;
    _fare = null;
    _showResult = false;
  }

  Future<void> _pickDeparture() async {
    final now = DateTime.now();
    final initial = _departure.isBefore(now) ? now : _departure;

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 30)),
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );

    if (time == null || !mounted) return;

    setState(() {
      _departure = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _clearResult();
    });
  }

  Future<void> _findRoute() async {
    final destination = _to;

    if (destination == null) {
      _message('Please select a destination station.');
      return;
    }

    if (_departure.isBefore(DateTime.now())) {
      _message('Please choose a departure time that is not in the past.');
      return;
    }

    setState(() {
      _searching = true;
      _showResult = false;
    });

    try {
      var current = _currentLocation;

      if (current == null) {
        current = await _locationService.getCurrentLocation();
      }

      final journey = _buildDetailedJourney(
        current: current,
        destination: destination,
      );

      final route = RouteSearchResult(
        from: const RouteStation(
          name: 'Current Location',
          mode: 'Walk',
        ),
        to: RouteStation(
          name: destination.station.name,
          mode: _modeForStation(destination),
        ),
        legs: journey.legs.map((item) => item.leg).toList(),
      );

      final fare = await _fareService.getStoredFareInfo(route);

      await _personalisation.addRecentSearch(
        'Current Location -> ${destination.station.name} - ${route.to.mode}',
      );

      if (!mounted) return;

      setState(() {
        _currentLocation = current;
        _route = route;
        _journey = journey;
        _fare = fare;
        _searching = false;
        _showResult = true;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _searching = false;
        _showResult = false;
      });

      _message(_errorText(error));
    }
  }

  RouteJourneyDetails _buildDetailedJourney({
    required LatLng current,
    required RouteMapStationPoint destination,
  }) {
    final legs = <JourneyLegDetails>[];
    var cursor = _departure;

    final destinationMode = _modeForStation(destination);
    final destinationDistance = const Distance().as(
      LengthUnit.Meter,
      current,
      destination.point,
    );

    if (destinationDistance <= 850) {
      final minutes = _walkingMinutes(destinationDistance);
      final arrival = cursor.add(Duration(minutes: minutes));

      legs.add(
        JourneyLegDetails(
          leg: RouteLeg(
            from: 'Current Location',
            to: destination.station.name,
            mode: 'Walk',
            line: 'Walking connection',
            stopCount: 0,
          ),
          departure: cursor,
          arrival: arrival,
          durationMinutes: minutes,
          fare: 0,
          instruction:
          'Walk from your current location to ${destination.station.name}.',
          timingSource:
          '${_formatDistance(destinationDistance)} based on government GTFS station coordinate.',
          isEstimate: true,
        ),
      );

      return RouteJourneyDetails(
        legs: legs,
        arrival: arrival,
        complete: true,
      );
    }

    if (destinationMode == 'Bus') {
      final nearestBus = _nearestStation(
        from: current,
        modes: const <String>['Bus'],
      );

      if (nearestBus != null) {
        cursor = _addWalkLeg(
          legs: legs,
          from: 'Current Location',
          to: nearestBus.station.name,
          fromPoint: current,
          toPoint: nearestBus.point,
          start: cursor,
          instruction:
          'Walk to the nearest Rapid Bus KL stop, ${nearestBus.station.name}.',
        );
      }

      final fromName = nearestBus?.station.name ?? 'Current Location';
      final minutes = _busMinutes(
        const Distance().as(
          LengthUnit.Meter,
          nearestBus?.point ?? current,
          destination.point,
        ),
      );
      final arrival = cursor.add(Duration(minutes: minutes));
      final fare = _estimateFare(
        mode: 'Bus',
        distanceMetres: const Distance().as(
          LengthUnit.Meter,
          nearestBus?.point ?? current,
          destination.point,
        ),
      );

      legs.add(
        JourneyLegDetails(
          leg: RouteLeg(
            from: fromName,
            to: destination.station.name,
            mode: 'Bus',
            line: 'Rapid Bus KL estimated connection',
            stopCount: _estimateStopCount(destinationDistance / 1000, 'Bus'),
          ),
          departure: cursor,
          arrival: arrival,
          durationMinutes: minutes,
          fare: fare,
          instruction:
          'Take Rapid Bus KL from $fromName towards ${destination.station.name}.',
          timingSource:
          'Estimated from station distance because live bus routing is not connected.',
          isEstimate: true,
        ),
      );

      return RouteJourneyDetails(
        legs: legs,
        arrival: arrival,
        complete: true,
      );
    }

    final boarding = _nearestStation(
      from: current,
      modes: _railCandidateModes(),
      exclude: destination,
    );

    if (boarding == null) {
      final minutes = _transitMinutes(destinationDistance, destinationMode);
      final arrival = cursor.add(Duration(minutes: minutes));

      legs.add(
        JourneyLegDetails(
          leg: RouteLeg(
            from: 'Current Location',
            to: destination.station.name,
            mode: destinationMode,
            line: '${destination.agency} GTFS static station estimate',
            stopCount: _estimateStopCount(destinationDistance / 1000, destinationMode),
          ),
          departure: cursor,
          arrival: arrival,
          durationMinutes: minutes,
          fare: _estimateFare(
            mode: destinationMode,
            distanceMetres: destinationDistance,
          ),
          instruction:
          'Travel towards ${destination.station.name}. No nearby boarding station could be matched, so this section is estimated directly.',
          timingSource:
          '${_formatDistance(destinationDistance)} from current location to official GTFS station coordinate.',
          isEstimate: true,
        ),
      );

      return RouteJourneyDetails(
        legs: legs,
        arrival: arrival,
        complete: true,
      );
    }

    final walkToBoardingDistance = const Distance().as(
      LengthUnit.Meter,
      current,
      boarding.point,
    );

    if (walkToBoardingDistance <= 1000) {
      cursor = _addWalkLeg(
        legs: legs,
        from: 'Current Location',
        to: boarding.station.name,
        fromPoint: current,
        toPoint: boarding.point,
        start: cursor,
        instruction:
        'Walk from your current location to ${boarding.station.name}.',
      );
    } else {
      final nearestBus = _nearestStation(
        from: current,
        modes: const <String>['Bus'],
      );

      if (nearestBus != null) {
        cursor = _addWalkLeg(
          legs: legs,
          from: 'Current Location',
          to: nearestBus.station.name,
          fromPoint: current,
          toPoint: nearestBus.point,
          start: cursor,
          instruction:
          'Walk to the nearest Rapid Bus KL stop, ${nearestBus.station.name}.',
        );

        final busDistance = const Distance().as(
          LengthUnit.Meter,
          nearestBus.point,
          boarding.point,
        );
        final busMinutes = _busMinutes(busDistance);
        final busArrival = cursor.add(Duration(minutes: busMinutes));

        legs.add(
          JourneyLegDetails(
            leg: RouteLeg(
              from: nearestBus.station.name,
              to: boarding.station.name,
              mode: 'Bus',
              line: 'Rapid Bus KL feeder estimate',
              stopCount: _estimateStopCount(busDistance / 1000, 'Bus'),
            ),
            departure: cursor,
            arrival: busArrival,
            durationMinutes: busMinutes,
            fare: _estimateFare(mode: 'Bus', distanceMetres: busDistance),
            instruction:
            'Take Rapid Bus KL from ${nearestBus.station.name} to the area near ${boarding.station.name}.',
            timingSource:
            'Estimated feeder bus section from government GTFS bus stop and rail station coordinates.',
            isEstimate: true,
          ),
        );

        cursor = busArrival;

        cursor = _addWalkLeg(
          legs: legs,
          from: 'Nearby bus stop',
          to: boarding.station.name,
          fromPoint: boarding.point,
          toPoint: boarding.point,
          start: cursor,
          fixedMinutes: 3,
          instruction:
          'Walk into ${boarding.station.name} and prepare to board rail service.',
        );
      } else {
        cursor = _addWalkLeg(
          legs: legs,
          from: 'Current Location',
          to: boarding.station.name,
          fromPoint: current,
          toPoint: boarding.point,
          start: cursor,
          instruction:
          'Walk or use local access transport to ${boarding.station.name}.',
        );
      }
    }

    final boardingMode = _modeForStation(boarding);
    final transfer = _transferStationFor(
      from: boarding,
      to: destination,
    );

    if (transfer != null &&
        !_sameStation(transfer.station.name, boarding.station.name) &&
        !_sameStation(transfer.station.name, destination.station.name)) {
      final firstRailDistance = const Distance().as(
        LengthUnit.Meter,
        boarding.point,
        transfer.point,
      );
      final firstRailMinutes = _transitMinutes(firstRailDistance, boardingMode);
      final firstRailArrival = cursor.add(Duration(minutes: firstRailMinutes));

      legs.add(
        JourneyLegDetails(
          leg: RouteLeg(
            from: boarding.station.name,
            to: transfer.station.name,
            mode: boardingMode,
            line: '${boarding.agency} estimated rail section',
            stopCount: _estimateStopCount(firstRailDistance / 1000, boardingMode),
          ),
          departure: cursor,
          arrival: firstRailArrival,
          durationMinutes: firstRailMinutes,
          fare: _estimateFare(
            mode: boardingMode,
            distanceMetres: firstRailDistance,
          ),
          instruction:
          'Board $boardingMode at ${boarding.station.name} and ride to ${transfer.station.name}.',
          timingSource:
          'Estimated from government GTFS station coordinates.',
          isEstimate: true,
        ),
      );

      cursor = firstRailArrival;

      final transferArrival = cursor.add(const Duration(minutes: 5));
      legs.add(
        JourneyLegDetails(
          leg: RouteLeg(
            from: transfer.station.name,
            to: transfer.station.name,
            mode: 'Walk',
            line: 'Transfer connection',
            stopCount: 0,
          ),
          departure: cursor,
          arrival: transferArrival,
          durationMinutes: 5,
          fare: 0,
          instruction:
          'Transfer at ${transfer.station.name} and follow signs to the ${destinationMode == 'Rail' ? 'next rail' : destinationMode} platform.',
          timingSource: 'Estimated 5 min station transfer time.',
          isEstimate: true,
        ),
      );

      cursor = transferArrival;

      final secondRailDistance = const Distance().as(
        LengthUnit.Meter,
        transfer.point,
        destination.point,
      );
      final secondRailMinutes = _transitMinutes(secondRailDistance, destinationMode);
      final secondRailArrival = cursor.add(Duration(minutes: secondRailMinutes));

      legs.add(
        JourneyLegDetails(
          leg: RouteLeg(
            from: transfer.station.name,
            to: destination.station.name,
            mode: destinationMode,
            line: '${destination.agency} estimated rail section',
            stopCount:
            _estimateStopCount(secondRailDistance / 1000, destinationMode),
          ),
          departure: cursor,
          arrival: secondRailArrival,
          durationMinutes: secondRailMinutes,
          fare: _estimateFare(
            mode: destinationMode,
            distanceMetres: secondRailDistance,
          ),
          instruction:
          'Take $destinationMode from ${transfer.station.name} to ${destination.station.name}.',
          timingSource:
          'Estimated from government GTFS station coordinates.',
          isEstimate: true,
        ),
      );

      cursor = secondRailArrival;
    } else {
      final railDistance = const Distance().as(
        LengthUnit.Meter,
        boarding.point,
        destination.point,
      );
      final railMinutes = _transitMinutes(railDistance, destinationMode);
      final railArrival = cursor.add(Duration(minutes: railMinutes));

      legs.add(
        JourneyLegDetails(
          leg: RouteLeg(
            from: boarding.station.name,
            to: destination.station.name,
            mode: destinationMode,
            line: '${destination.agency} estimated rail section',
            stopCount: _estimateStopCount(railDistance / 1000, destinationMode),
          ),
          departure: cursor,
          arrival: railArrival,
          durationMinutes: railMinutes,
          fare: _estimateFare(
            mode: destinationMode,
            distanceMetres: railDistance,
          ),
          instruction:
          'Take $destinationMode from ${boarding.station.name} to ${destination.station.name}.',
          timingSource:
          'Estimated from government GTFS station coordinates.',
          isEstimate: true,
        ),
      );

      cursor = railArrival;
    }

    legs.add(
      JourneyLegDetails(
        leg: RouteLeg(
          from: destination.station.name,
          to: 'Destination area',
          mode: 'Walk',
          line: 'Arrival',
          stopCount: 0,
        ),
        departure: cursor,
        arrival: cursor.add(const Duration(minutes: 2)),
        durationMinutes: 2,
        fare: 0,
        instruction:
        'Arrive at ${destination.station.name} and exit towards your destination.',
        timingSource: 'Estimated final station exit time.',
        isEstimate: true,
      ),
    );

    final arrival = legs.last.arrival;

    return RouteJourneyDetails(
      legs: legs,
      arrival: arrival,
      complete: true,
    );
  }

  DateTime _addWalkLeg({
    required List<JourneyLegDetails> legs,
    required String from,
    required String to,
    required LatLng fromPoint,
    required LatLng toPoint,
    required DateTime start,
    required String instruction,
    int? fixedMinutes,
  }) {
    final distanceMetres = const Distance().as(
      LengthUnit.Meter,
      fromPoint,
      toPoint,
    );
    final minutes = fixedMinutes ?? _walkingMinutes(distanceMetres);
    final arrival = start.add(Duration(minutes: minutes));

    legs.add(
      JourneyLegDetails(
        leg: RouteLeg(
          from: from,
          to: to,
          mode: 'Walk',
          line: 'Walking connection',
          stopCount: 0,
        ),
        departure: start,
        arrival: arrival,
        durationMinutes: minutes,
        fare: 0,
        instruction: instruction,
        timingSource: fixedMinutes == null
            ? '${_formatDistance(distanceMetres)} walking estimate.'
            : 'Estimated station access time.',
        isEstimate: true,
      ),
    );

    return arrival;
  }

  RouteMapStationPoint? _nearestStation({
    required LatLng from,
    required List<String> modes,
    RouteMapStationPoint? exclude,
  }) {
    RouteMapStationPoint? best;
    double? bestDistance;

    for (final station in _stations) {
      if (exclude != null &&
          station.stopId == exclude.stopId &&
          station.agency == exclude.agency) {
        continue;
      }

      final mode = _modeForStation(station);
      if (!modes.contains(mode) && !(modes.contains('Rail') && mode != 'Bus')) {
        continue;
      }

      final distance = const Distance().as(
        LengthUnit.Meter,
        from,
        station.point,
      );

      if (bestDistance == null || distance < bestDistance) {
        best = station;
        bestDistance = distance;
      }
    }

    return best;
  }

  RouteMapStationPoint? _transferStationFor({
    required RouteMapStationPoint from,
    required RouteMapStationPoint to,
  }) {
    final fromMode = _modeForStation(from);
    final toMode = _modeForStation(to);

    if (fromMode == toMode && from.agency == to.agency) return null;

    final preferredNames = <String>[
      if (toMode == 'MRT') 'Pasar Seni',
      if (toMode == 'LRT') 'Masjid Jamek',
      if (toMode == 'KTM') 'KL Sentral',
      if (fromMode == 'KTM' || toMode == 'KTM') 'KL Sentral',
      'Pasar Seni',
      'Masjid Jamek',
      'KL Sentral',
    ];

    for (final name in preferredNames) {
      final matches = _stations.where((station) {
        return _sameStation(station.station.name, name) &&
            _modeForStation(station) != 'Bus';
      }).toList();

      if (matches.isNotEmpty) {
        matches.sort((a, b) {
          final da = const Distance().as(LengthUnit.Meter, from.point, a.point) +
              const Distance().as(LengthUnit.Meter, a.point, to.point);
          final db = const Distance().as(LengthUnit.Meter, from.point, b.point) +
              const Distance().as(LengthUnit.Meter, b.point, to.point);
          return da.compareTo(db);
        });
        return matches.first;
      }
    }

    return null;
  }

  List<String> _railCandidateModes() {
    if (_transport == 'MRT' || _transport == 'LRT' || _transport == 'KTM') {
      return <String>[_transport];
    }

    return const <String>['MRT', 'LRT', 'KTM', 'Rail'];
  }

  int _walkingMinutes(double metres) {
    if (metres <= 80) return 1;
    return math.max(2, (metres / 75).ceil());
  }

  int _busMinutes(double metres) {
    final moving = (metres / 1000 / 20 * 60).ceil();
    return math.max(8, moving + 6);
  }

  int _transitMinutes(double metres, String mode) {
    final speedKmh = switch (mode) {
      'KTM' => 45.0,
      'MRT' => 38.0,
      'LRT' => 32.0,
      'Bus' => 22.0,
      _ => 34.0,
    };

    final moving = (metres / 1000 / speedKmh * 60).ceil();
    return math.max(4, moving + 5);
  }

  int _estimateStopCount(double distanceKm, String mode) {
    final kmPerStop = switch (mode) {
      'Bus' => 0.75,
      'KTM' => 4.0,
      'MRT' => 1.4,
      'LRT' => 1.1,
      _ => 1.5,
    };

    return math.max(1, (distanceKm / kmPerStop).round());
  }

  double _estimateFare({
    required String mode,
    required double distanceMetres,
  }) {
    final distanceKm = distanceMetres / 1000;

    if (mode == 'Walk') return 0;

    if (mode == 'Bus') {
      if (distanceKm <= 5) return 1.00;
      if (distanceKm <= 10) return 1.50;
      if (distanceKm <= 20) return 2.00;
      return 3.00;
    }

    if (mode == 'KTM') {
      return (1.60 + distanceKm * 0.18).clamp(1.60, 8.00);
    }

    if (mode == 'MRT' || mode == 'LRT' || mode == 'Rail') {
      return (1.20 + distanceKm * 0.22).clamp(1.20, 6.00);
    }

    return 0;
  }

  String _modeForStation(RouteMapStationPoint station) {
    if (station.agency == 'KTMB') return 'KTM';
    if (station.agency == 'Rapid Bus KL') return 'Bus';

    final id = station.stopId.toUpperCase();
    final name = station.station.name.toUpperCase();

    if (id.startsWith('MR') ||
        id.startsWith('SBK') ||
        id.startsWith('KG') ||
        id.startsWith('PY')) {
      return 'MRT';
    }

    if (id.startsWith('KJ') ||
        id.startsWith('AG') ||
        id.startsWith('SP') ||
        name.contains('LRT')) {
      return 'LRT';
    }

    return station.station.mode == 'Rail' ? 'MRT' : station.station.mode;
  }

  List<RouteMapStationPoint> _filteredStations() {
    if (_transport == 'All') return _stations;

    return _stations.where((station) {
      final mode = _modeForStation(station);

      if (_transport == 'MRT' || _transport == 'LRT') {
        return station.agency == 'Rapid Rail KL';
      }

      return mode == _transport;
    }).toList();
  }

  bool _isSelectedStation(RouteMapStationPoint station) {
    final selected = _to;
    if (selected == null) return false;

    if (selected.stopId == station.stopId && selected.agency == station.agency) {
      return true;
    }

    return _normalise(selected.station.name) == _normalise(station.station.name);
  }

  List<RouteMapStationPoint> _visibleMapStations() {
    final filtered = _filteredStations();
    final selected = _to;

    final visible = <RouteMapStationPoint>[
      ...filtered.take(700),
    ];

    if (selected != null) {
      final alreadyIncluded = visible.any((station) {
        return station.stopId == selected.stopId &&
            station.agency == selected.agency;
      });

      if (!alreadyIncluded) {
        visible.add(selected);
      }
    }

    return visible;
  }

  Future<void> _save() async {
    final destination = _to;
    final route = _route;

    if (destination == null || route == null) return;

    final value =
        'Current Location -> ${destination.station.name} - ${route.to.mode}';

    if (_personalisation.favouriteRoutes.contains(value)) {
      _message('This route is already saved.');
      return;
    }

    setState(() => _saving = true);

    await _personalisation.addFavouriteRoute(value);

    if (!mounted) return;

    setState(() => _saving = false);

    _message('Route saved to Favourite Routes.');
  }

  void _message(String value) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value)),
    );
  }

  String _errorText(Object error) {
    final value = error.toString();

    if (value.startsWith('Exception: ')) {
      return value.substring('Exception: '.length);
    }

    return value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showResult ? 'Route Details' : 'Plan Journey'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: _showResult ? _resultContent() : _searchContent(),
      ),
    );
  }

  List<Widget> _searchContent() {
    return <Widget>[
      Text(
        'Live Station Map',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 12),
      _stationMap(),
      const SizedBox(height: 18),
      AppCard(
        child: Column(
          children: <Widget>[
            const InputDecorator(
              decoration: InputDecoration(
                labelText: 'From',
                prefixIcon: Icon(Icons.my_location_rounded),
              ),
              child: Text(
                'Current Location',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 16),
            _StationInput(
              label: 'Destination',
              station: _to,
              hint: 'Select destination station',
              icon: Icons.location_on_rounded,
              onTap: _selectDestination,
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDeparture,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Leave at',
                  prefixIcon: Icon(Icons.schedule_rounded),
                ),
                child: Text(
                  _formatDateTime(_departure),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Main rail preference',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <String>['All', 'MRT', 'LRT', 'KTM']
                  .map(
                    (value) => ChoiceChip(
                  label: Text(value),
                  selected: _transport == value,
                  onSelected: (_) {
                    setState(() {
                      _transport = value;
                      _clearResult();
                    });

                    final selected = _to;
                    if (selected != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _mapController.move(selected.point, 16);
                      });
                    }
                  },
                ),
              )
                  .toList(),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      ElevatedButton.icon(
        onPressed: _searching ? null : _findRoute,
        icon: _searching
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : const Icon(Icons.route_rounded),
        label: Text(
          _searching ? 'Estimating route...' : 'Find Best Route',
        ),
      ),
      const SizedBox(height: 14),
      Text(
        'Route module uses Malaysia Government GTFS static station coordinates. Journey details are estimated from station location, distance, selected transport mode, and available fare reference data.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ];
  }

  Widget _stationMap() {
    final current = _currentLocation ?? const LatLng(3.1390, 101.6869);
    final stations = _visibleMapStations();

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 320,
        child: Stack(
          children: <Widget>[
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: current,
                initialZoom: 11,
              ),
              children: <Widget>[
                TileLayer(
                  urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.go_transit_my',
                ),
                MarkerLayer(
                  markers: <Marker>[
                    Marker(
                      point: current,
                      width: 54,
                      height: 54,
                      child: const _CurrentLocationMarker(),
                    ),
                    ...stations.map(
                          (station) {
                        final selected = _isSelectedStation(station);

                        return Marker(
                          point: station.point,
                          width: selected ? 58 : 44,
                          height: selected ? 58 : 44,
                          child: GestureDetector(
                            onTap: () => _setDestination(station),
                            child: _StationMarker(
                              selected: selected,
                              mode: _modeForStation(station),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              left: 14,
              right: 14,
              top: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.touch_app_rounded,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _loadingStations
                            ? 'Loading government GTFS station coordinates...'
                            : 'Tap a station marker or use search to choose your destination',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_loadingStations)
              const Center(
                child: CircularProgressIndicator(),
              ),
            if (_stationError != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.black87,
                  child: Text(
                    _stationError!,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            Positioned(
              right: 14,
              bottom: 14,
              child: _MapZoomControls(
                onZoomIn: () {
                  final camera = _mapController.camera;
                  _mapController.move(
                    camera.center,
                    (camera.zoom + 1).clamp(3, 18).toDouble(),
                  );
                },
                onZoomOut: () {
                  final camera = _mapController.camera;
                  _mapController.move(
                    camera.center,
                    (camera.zoom - 1).clamp(3, 18).toDouble(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _resultContent() {
    final route = _route;
    final journey = _journey;
    final fare = _fare;
    final destination = _to;

    if (route == null || journey == null || destination == null) {
      return <Widget>[
        const AppCard(
          child: Column(
            children: <Widget>[
              Icon(
                Icons.route_outlined,
                size: 48,
                color: AppColors.muted,
              ),
              SizedBox(height: 12),
              Text(
                'No suitable route found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Try another destination or rail preference.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        OutlinedButton(
          onPressed: () {
            setState(() => _showResult = false);
          },
          child: const Text('Edit Search'),
        ),
      ];
    }

    final totalMinutes = journey.totalDurationMinutes;
    final totalFare = journey.totalFare;
    final paidModes = route.modes.join(' + ');

    return <Widget>[
      Text(
        'Current Location -> ${destination.station.name}',
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        _formatDateTime(_departure),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 16),
      AppCard(
        color: const Color(0xFFEFF6FF),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.route_rounded,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Recommended Journey',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                StatusChip(
                  paidModes.isEmpty ? 'Walk' : paidModes,
                  color: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SummaryRow(
              icon: Icons.schedule_rounded,
              label: 'Estimated arrival',
              value: journey.arrival == null ? '-' : _formatTime(journey.arrival!),
            ),
            const SizedBox(height: 8),
            _SummaryRow(
              icon: Icons.timer_rounded,
              label: 'Total time',
              value: '$totalMinutes min',
            ),
            const SizedBox(height: 8),
            _SummaryRow(
              icon: Icons.payments_rounded,
              label: 'Estimated fare',
              value: totalFare <= 0 ? 'Free' : 'RM ${totalFare.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 8),
            _SummaryRow(
              icon: Icons.sync_alt_rounded,
              label: 'Transfers',
              value: '${route.transfers}',
            ),
            const SizedBox(height: 12),
            Text(
              'This route is estimated from Malaysia Government GTFS static station coordinates. Fare is an estimate unless a stored fare reference is available.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      const SectionTitle('Route Details'),
      const SizedBox(height: 10),
      ..._detailCards(journey),
      const SizedBox(height: 18),
      _fareCard(fare, journey),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: _saving ? null : _save,
        icon: const Icon(Icons.favorite_border_rounded),
        label: const Text('Save Route'),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () {
          setState(() => _showResult = false);
          final selected = _to;
          if (selected != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _mapController.move(selected.point, 16);
            });
          }
        },
        icon: const Icon(Icons.edit_location_alt_outlined),
        label: const Text('Edit Search'),
      ),
    ];
  }

  List<Widget> _detailCards(RouteJourneyDetails journey) {
    return journey.legs.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final item = entry.value;
      final leg = item.leg;

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CircleAvatar(
                child: Icon(
                  _legIcon(leg.mode),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Step $index - ${_legTitle(leg)}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.instruction ?? '${leg.from} -> ${leg.to}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 5),
                    Text('${leg.from} -> ${leg.to}'),
                    if (item.departure != null && item.arrival != null) ...[
                      const SizedBox(height: 7),
                      Text(
                        '${_formatTime(item.departure!)} -> ${_formatTime(item.arrival!)} - ${item.durationMinutes} min',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      item.fare <= 0
                          ? 'Cost: Free'
                          : 'Estimated cost: RM ${item.fare.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (item.timingSource != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        item.timingSource!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  String _legTitle(RouteLeg leg) {
    if (leg.mode == 'Walk') return 'Walk';
    if (leg.mode == 'Bus') return 'Rapid Bus KL';
    if (leg.mode == 'KTM') return 'KTM Komuter';
    if (leg.mode == 'MRT') return 'MRT';
    if (leg.mode == 'LRT') return 'LRT';
    return 'Transit';
  }

  IconData _legIcon(String mode) {
    if (mode == 'Walk') return Icons.directions_walk_rounded;
    if (mode == 'Bus') return Icons.directions_bus_rounded;
    if (mode == 'KTM') return Icons.train_rounded;
    return Icons.subway_rounded;
  }

  Widget _fareCard(FareEstimateInfo? fare, RouteJourneyDetails journey) {
    final estimatedFare = journey.totalFare;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionTitle('Fare Estimate'),
          const SizedBox(height: 12),
          Text(
            fare?.hasFare == true
                ? fare!.formattedFare
                : estimatedFare <= 0
                ? 'RM 0.00'
                : 'RM ${estimatedFare.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            fare?.hasFare == true
                ? fare!.message
                : 'Estimated from selected transport sections. Exact fare may differ because complete live fare calculation is not connected.',
          ),
          if (fare?.sourceLabel != null) ...<Widget>[
            const SizedBox(height: 7),
            Text(
              'Source: ${fare!.sourceLabel}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (fare != null && fare.options.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            for (final option in fare.options)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: OutlinedButton.icon(
                  onPressed: () {
                    _openFareSource(option);
                  },
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(option.label),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _openFareSource(FareLookupOption option) async {
    final opened = await launchUrl(
      option.url,
      mode: LaunchMode.externalApplication,
    ) ||
        await launchUrl(option.url);

    if (!opened) {
      _message('Unable to open the fare source.');
    }
  }

  bool _sameStation(String a, String b) {
    final left = _normalise(a);
    final right = _normalise(b);

    if (left.isEmpty || right.isEmpty) return false;

    return left == right || left.contains(right) || right.contains(left);
  }

  String _normalise(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'\b(mrt|lrt|ktm|komuter|station|stesen)\b'), ' ')
        .replaceAll(RegExp(r'\s*\([^)]*\)\s*'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class RouteJourneyDetails {
  const RouteJourneyDetails({
    required this.legs,
    required this.arrival,
    required this.complete,
  });

  final List<JourneyLegDetails> legs;
  final DateTime? arrival;
  final bool complete;

  int get totalDurationMinutes {
    return legs.fold<int>(
      0,
          (total, leg) => total + (leg.durationMinutes ?? 0),
    );
  }

  double get totalFare {
    return legs.fold<double>(
      0,
          (total, leg) => total + leg.fare,
    );
  }
}

class JourneyLegDetails {
  const JourneyLegDetails({
    required this.leg,
    this.departure,
    this.arrival,
    this.durationMinutes,
    this.timingSource,
    this.instruction,
    this.fare = 0,
    this.isEstimate = false,
  });

  final RouteLeg leg;
  final DateTime? departure;
  final DateTime? arrival;
  final int? durationMinutes;
  final String? timingSource;
  final String? instruction;
  final double fare;
  final bool isEstimate;
}

class _StationPicker extends StatefulWidget {
  const _StationPicker({
    required this.title,
    required this.stations,
  });

  final String title;
  final List<RouteMapStationPoint> stations;

  @override
  State<_StationPicker> createState() => _StationPickerState();
}

class _StationPickerState extends State<_StationPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _normalise(_query);

    final stations = widget.stations.where((station) {
      final name = _normalise(station.station.name);
      final mode = _normalise(station.station.mode);
      final agency = _normalise(station.agency);
      final stopId = _normalise(station.stopId);

      return query.isEmpty ||
          name.contains(query) ||
          query.contains(name) ||
          mode.contains(query) ||
          agency.contains(query) ||
          stopId.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              onChanged: (value) {
                setState(() => _query = value);
              },
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search government station',
              ),
            ),
          ),
          Expanded(
            child: stations.isEmpty
                ? const Center(
              child: Text('No station found'),
            )
                : ListView.separated(
              itemCount: stations.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final station = stations[index];

                return ListTile(
                  leading: Icon(_modeIcon(station.station.mode)),
                  title: Text(
                    station.station.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${station.station.mode} - ${station.agency}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(context, station);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _modeIcon(String mode) {
    if (mode == 'Bus') return Icons.directions_bus_rounded;
    if (mode == 'KTM') return Icons.train_rounded;
    return Icons.subway_rounded;
  }

  String _normalise(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'\b(mrt|lrt|ktm|komuter|station|stesen)\b'), ' ')
        .replaceAll(RegExp(r'\s*\([^)]*\)\s*'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _StationInput extends StatelessWidget {
  const _StationInput({
    required this.label,
    required this.station,
    required this.hint,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final RouteMapStationPoint? station;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
        child: Text(
          station?.station.name ?? hint,
          style: TextStyle(
            fontWeight: station == null ? FontWeight.normal : FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _StationMarker extends StatelessWidget {
  const _StationMarker({
    required this.selected,
    required this.mode,
  });

  final bool selected;
  final String mode;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.32 : 1,
      duration: const Duration(milliseconds: 150),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? AppColors.warning : AppColors.primary,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: selected ? 4 : 3,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          mode == 'Bus'
              ? Icons.directions_bus_rounded
              : mode == 'KTM'
              ? Icons.train_rounded
              : Icons.subway_rounded,
          color: Colors.white,
          size: selected ? 24 : 20,
        ),
      ),
    );
  }
}

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.18),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
          ),
        ),
      ),
    );
  }
}

class _MapZoomControls extends StatelessWidget {
  const _MapZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.94),
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: 'Zoom in',
            onPressed: onZoomIn,
            icon: const Icon(Icons.add_rounded),
          ),
          Container(
            width: 28,
            height: 1,
            color: AppColors.line,
          ),
          IconButton(
            tooltip: 'Zoom out',
            onPressed: onZoomOut,
            icon: const Icon(Icons.remove_rounded),
          ),
        ],
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

String _formatDateTime(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year} - ${_formatTime(value)}';
}

String _formatDistance(double metres) {
  if (metres < 1000) return '${metres.round()} m';
  return '${(metres / 1000).toStringAsFixed(1)} km';
}
