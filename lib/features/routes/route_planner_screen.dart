import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../profile/personalisation_service.dart';
import 'current_location_route_service.dart';
import 'fare_estimation_service.dart';
import 'route_search_service.dart';
import 'route_timing_service.dart';
import 'station_catalog.dart';

class RoutePlannerScreen extends StatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen> {
  final _routeSearch = const RouteSearchService();
  final _timingService = RouteTimingService();
  final _fareService = FareEstimationService();
  final _accessService = CurrentLocationRouteService();

  late final PersonalisationService _personalisation;

  RouteStation? _to;
  RouteSearchResult? _route;
  RouteJourneyDetails? _journey;
  FareEstimateInfo? _fare;
  BoardingAccessPlan? _accessPlan;

  DateTime _departure = DateTime.now();
  String _transport = 'All';

  bool _searching = false;
  bool _showResult = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _personalisation = PersonalisationService.instance;

    final preferred = _personalisation.preferredTransport;
    if (const ['All', 'MRT', 'LRT', 'KTM'].contains(preferred)) {
      _transport = preferred;
    }
  }

  Future<void> _selectDestination() async {
    final station = await Navigator.of(context).push<RouteStation>(
      MaterialPageRoute(
        builder: (_) => const _StationPicker(
          title: 'Select destination',
        ),
      ),
    );

    if (station == null || !mounted) return;

    setState(() {
      _to = station;
      _clearResult();
    });
  }

  void _clearResult() {
    _route = null;
    _journey = null;
    _fare = null;
    _accessPlan = null;
    _showResult = false;
  }

  Future<void> _pickDeparture() async {
    final now = DateTime.now();
    final initial =
        _departure.isBefore(now) ? now : _departure;

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
    if (_to == null) {
      _message('Please select a destination.');
      return;
    }

    if (_departure.isBefore(DateTime.now())) {
      _message(
        'Please choose a departure time that is not in the past.',
      );
      return;
    }

    setState(() {
      _searching = true;
      _showResult = false;
    });

    try {
      final access = await _accessService.findAccessPlans(
        transport: _transport,
        departure: _departure,
      );

      _RouteCandidate? best;

      for (final plan in access.plans) {
        final route = plan.station.name == _to!.name
            ? RouteSearchResult(
                from: plan.station,
                to: _to!,
                legs: const [],
              )
            : await _routeSearch.search(
                from: plan.station,
                to: _to!,
                transport: _transport,
              );

        if (route == null) continue;

        final journey = await _buildJourney(
          route,
          accessPlan: plan,
        );

        final candidate = _RouteCandidate(
          route: route,
          journey: journey,
          accessPlan: plan,
          score: _candidateScore(
            route: route,
            journey: journey,
            plan: plan,
          ),
        );

        if (best == null ||
            candidate.score < best.score) {
          best = candidate;
        }
      }

      if (best == null) {
        if (!mounted) return;

        setState(() {
          _route = null;
          _journey = null;
          _fare = null;
          _accessPlan = null;
          _searching = false;
          _showResult = true;
        });
        return;
      }

      final fare =
          await _fareService.getStoredFareInfo(best.route);

      await _personalisation.addRecentSearch(
        'Current Location → ${_to!.name} • $_transport',
      );

      if (!mounted) return;

      setState(() {
        _route = best!.route;
        _journey = best.journey;
        _accessPlan = best.accessPlan;
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

  double _candidateScore({
    required RouteSearchResult route,
    required RouteJourneyDetails journey,
    required BoardingAccessPlan plan,
  }) {
    if (journey.arrival != null) {
      final totalMinutes = journey.arrival!
              .difference(_departure)
              .inSeconds /
          60;

      final longWalkPenalty = plan.steps
          .where((step) => step.mode == 'Walk')
          .fold<double>(
            0,
            (value, step) =>
                value +
                (step.durationMinutes > 15
                    ? (step.durationMinutes - 15) * 2
                    : 0),
          );

      return totalMinutes +
          route.transfers * 3 +
          longWalkPenalty;
    }

    return 10000 +
        plan.scoreMinutes +
        route.stops * 5 +
        route.transfers * 8;
  }

  Future<RouteJourneyDetails> _buildJourney(
    RouteSearchResult route, {
    required BoardingAccessPlan accessPlan,
  }) async {
    final details = <JourneyLegDetails>[];
    var nextDeparture = _departure;
    var complete = true;

    for (final accessStep in accessPlan.steps) {
      final leg = RouteLeg(
        from: accessStep.from,
        to: accessStep.to,
        mode: accessStep.mode,
        line: accessStep.line ??
            (accessStep.mode == 'Walk'
                ? 'Walking connection'
                : accessStep.mode),
        stopCount: 0,
      );

      details.add(
        JourneyLegDetails(
          leg: leg,
          departure: accessStep.departure,
          arrival: accessStep.arrival,
          durationMinutes:
              accessStep.durationMinutes,
          timingSource: accessStep.mode == 'Bus'
              ? 'Malaysia Government Rapid Bus GTFS Static'
              : accessStep.distanceMetres == null
                  ? 'Estimated walking time'
                  : '${_formatDistance(accessStep.distanceMetres!)} • estimated walking time',
          isEstimate: accessStep.mode == 'Walk',
        ),
      );

      if (accessStep.arrival != null) {
        nextDeparture = accessStep.arrival!;
      }
    }

    for (final leg in route.groupedLegs) {
      if (leg.mode == 'Walk') {
        const minutes = 8;

        final arrival = nextDeparture.add(
          const Duration(minutes: minutes),
        );

        details.add(
          JourneyLegDetails(
            leg: leg,
            departure: nextDeparture,
            arrival: arrival,
            durationMinutes: minutes,
            timingSource:
                'Estimated interchange walking time',
            isEstimate: true,
          ),
        );

        nextDeparture = arrival;
        continue;
      }

      final timing = await _timingService.findTiming(
        mode: leg.mode,
        from: leg.from,
        to: leg.to,
        requestedDeparture: nextDeparture,
      );

      if (timing == null) {
        complete = false;
        details.add(
          JourneyLegDetails(leg: leg),
        );
        continue;
      }

      details.add(
        JourneyLegDetails(
          leg: leg,
          departure: timing.departure,
          arrival: timing.arrival,
          durationMinutes:
              timing.durationMinutes,
          timingSource: timing.usesCalendarFallback
              ? 'Malaysia Government GTFS timetable reference'
              : 'Malaysia Government GTFS scheduled service',
          isEstimate:
              timing.usesCalendarFallback,
        ),
      );

      nextDeparture = timing.arrival;
    }

    final arrival = complete && details.isNotEmpty
        ? details.last.arrival
        : null;

    return RouteJourneyDetails(
      legs: details,
      arrival: arrival,
      complete: complete,
    );
  }

  Future<void> _save() async {
    final route = _route;
    if (route == null || _to == null) return;

    final modes = <String>[];

    for (final item in _journey?.legs ??
        const <JourneyLegDetails>[]) {
      if (item.leg.mode == 'Walk') continue;
      if (!modes.contains(item.leg.mode)) {
        modes.add(item.leg.mode);
      }
    }

    final modeText =
        modes.isEmpty ? 'Walk' : modes.join(' + ');

    final value =
        'Current Location → ${_to!.name} • $modeText';

    if (_personalisation.favouriteRoutes
        .contains(value)) {
      _message('This route is already saved.');
      return;
    }

    setState(() => _saving = true);

    await _personalisation.addFavouriteRoute(value);

    if (!mounted) return;

    setState(() => _saving = false);

    _message(
      'Route saved to Favourite Routes.',
    );
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
      return value.substring(
        'Exception: '.length,
      );
    }

    return 'Unable to build a route from your current location.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _showResult
              ? 'Best Route'
              : 'Plan Journey',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: _showResult
            ? _resultContent()
            : _searchContent(),
      ),
    );
  }

  List<Widget> _searchContent() {
    return [
      AppCard(
        child: Column(
          children: [
            const InputDecorator(
              decoration: InputDecoration(
                labelText: 'From',
                prefixIcon:
                    Icon(Icons.my_location_rounded),
              ),
              child: Text(
                'Current Location',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _StationInput(
              label: 'Destination',
              station: _to,
              hint:
                  'Select destination station',
              icon: Icons.location_on_rounded,
              onTap: _selectDestination,
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDeparture,
              child: InputDecorator(
                decoration:
                    const InputDecoration(
                  labelText: 'Leave at',
                  prefixIcon: Icon(
                    Icons.schedule_rounded,
                  ),
                ),
                child: Text(
                  _formatDateTime(_departure),
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment:
                  Alignment.centerLeft,
              child: Text(
                'Main rail preference',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  ['All', 'MRT', 'LRT', 'KTM']
                      .map(
                        (value) =>
                            ChoiceChip(
                          label: Text(value),
                          selected:
                              _transport ==
                                  value,
                          onSelected: (_) {
                            setState(() {
                              _transport =
                                  value;
                              _clearResult();
                            });
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
        onPressed:
            _searching ? null : _findRoute,
        icon: _searching
            ? const SizedBox(
                width: 18,
                height: 18,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            : const Icon(
                Icons.route_rounded,
              ),
        label: Text(
          _searching
              ? 'Checking bus and rail options...'
              : 'Find Best Route',
        ),
      ),
      const SizedBox(height: 14),
      Text(
        'The app can walk to a nearby rail station or use a nearby Rapid KL bus first, then continue by MRT, LRT or KTM when that gives a better journey.',
        style:
            Theme.of(context).textTheme.bodySmall,
      ),
    ];
  }

  List<Widget> _resultContent() {
    if (_route == null ||
        _to == null ||
        _accessPlan == null) {
      return [
        const AppCard(
          child: Column(
            children: [
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
                  fontWeight:
                      FontWeight.w900,
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
            setState(
              () => _showResult = false,
            );
          },
          child: const Text('Edit Search'),
        ),
      ];
    }

    final route = _route!;
    final journey = _journey;
    final fare = _fare;
    final plan = _accessPlan!;

    final duration = journey?.arrival
        ?.difference(_departure)
        .inMinutes;

    final usedModes = <String>[];

    for (final detail
        in journey?.legs ??
            const <JourneyLegDetails>[]) {
      if (detail.leg.mode == 'Walk') continue;
      if (!usedModes.contains(
        detail.leg.mode,
      )) {
        usedModes.add(detail.leg.mode);
      }
    }

    return [
      Text(
        'Current Location → ${_to!.name}',
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        _formatDateTime(_departure),
        style:
            Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 16),
      AppCard(
        color: const Color(0xFFEFF6FF),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.route_rounded,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Best Route',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),
                StatusChip(
                  route.transfers == 0
                      ? 'Direct rail'
                      : '${route.transfers} rail transfer${route.transfers == 1 ? '' : 's'}',
                  color: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Board rail at ${plan.station.name}',
              style: const TextStyle(
                fontWeight:
                    FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              usedModes.isEmpty
                  ? 'Walking'
                  : usedModes.join(' + '),
              style: const TextStyle(
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            if (journey?.arrival != null) ...[
              Text(
                'Estimated arrival: ${_formatTime(journey!.arrival!)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
              Text(
                'Total journey: $duration min',
              ),
            ] else
              const Text(
                'Complete arrival time is unavailable because one transport leg did not match timetable data.',
              ),
            const SizedBox(height: 8),
            Text(
              fare?.hasFare == true
                  ? 'Estimated rail fare: ${fare!.formattedFare}'
                  : 'Rail fare is not covered by the current verified reference set.',
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      const SectionTitle('Route Details'),
      const SizedBox(height: 10),
      ..._detailCards(route, journey),
      const SizedBox(height: 18),
      _fareCard(fare),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed:
            _saving ? null : _save,
        icon: const Icon(
          Icons.favorite_border_rounded,
        ),
        label: const Text('Save Route'),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () {
          setState(
            () => _showResult = false,
          );
        },
        icon: const Icon(
          Icons.edit_location_alt_outlined,
        ),
        label: const Text('Edit Search'),
      ),
    ];
  }

  List<Widget> _detailCards(
    RouteSearchResult route,
    RouteJourneyDetails? journey,
  ) {
    final items = journey?.legs ??
        route.groupedLegs
            .map(
              (leg) =>
                  JourneyLegDetails(leg: leg),
            )
            .toList();

    final widgets = <Widget>[];

    for (var i = 0;
        i < items.length;
        i++) {
      final item = items[i];
      final leg = item.leg;

      widgets.add(
        AppCard(
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                child: Icon(
                  _legIcon(leg.mode),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      _legTitle(leg),
                      style: const TextStyle(
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${leg.from} → ${leg.to}',
                    ),
                    if (item.departure !=
                            null &&
                        item.arrival !=
                            null) ...[
                      const SizedBox(height: 7),
                      Text(
                        '${_formatTime(item.departure!)} → ${_formatTime(item.arrival!)} • ${item.durationMinutes} min',
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ],
                    if (item.timingSource !=
                        null) ...[
                      const SizedBox(height: 5),
                      Text(
                        item.timingSource!,
                        style:
                            Theme.of(context)
                                .textTheme
                                .bodySmall,
                      ),
                    ],
                    if (item.departure ==
                            null &&
                        leg.mode !=
                            'Walk') ...[
                      const SizedBox(height: 5),
                      Text(
                        'Timetable match unavailable for this transport leg.',
                        style:
                            Theme.of(context)
                                .textTheme
                                .bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      if (i < items.length - 1) {
        final next = items[i + 1];

        widgets.add(
          Padding(
            padding:
                const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 8,
            ),
            child: Row(
              children: [
                Icon(
                  _connectorIcon(
                    item,
                    next,
                  ),
                  color:
                      AppColors.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _connectorText(
                      item,
                      next,
                    ),
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w900,
                      color:
                          AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return widgets;
  }

  String _legTitle(RouteLeg leg) {
    if (leg.mode == 'Walk') {
      return leg.from == 'Current Location'
          ? 'Walk to public transport'
          : 'Walk connection';
    }

    if (leg.mode == 'Bus') {
      return 'Rapid KL Bus ${leg.line}';
    }

    return leg.line;
  }

  String _connectorText(
    JourneyLegDetails current,
    JourneyLegDetails next,
  ) {
    final station = current.leg.to;

    if (current.leg.mode == 'Walk' &&
        next.leg.mode == 'Bus') {
      final wait = _waitMinutes(
        current.arrival,
        next.departure,
      );

      return wait == null || wait <= 0
          ? 'Board bus at $station'
          : 'Board bus at $station • wait about $wait min';
    }

    if (current.leg.mode == 'Bus' &&
        next.leg.mode == 'Walk') {
      return 'Get off bus at $station and walk to rail';
    }

    if (current.leg.mode == 'Walk' &&
        next.leg.mode != 'Walk') {
      final wait = _waitMinutes(
        current.arrival,
        next.departure,
      );

      return wait == null || wait <= 0
          ? 'Enter ${next.leg.mode} at $station'
          : 'Enter ${next.leg.mode} at $station • wait about $wait min';
    }

    if (current.leg.mode != 'Walk' &&
        next.leg.mode == 'Walk') {
      return 'Exit ${current.leg.mode} at $station and continue on foot';
    }

    if (current.leg.mode != 'Walk' &&
        next.leg.mode != 'Walk') {
      final wait = _waitMinutes(
        current.arrival,
        next.departure,
      );

      final sameService =
          current.leg.line ==
                  next.leg.line &&
              current.leg.mode ==
                  next.leg.mode;

      final text = sameService
          ? 'Continue ${next.leg.mode} at $station'
          : 'Change to ${next.leg.mode} at $station';

      return wait == null || wait <= 0
          ? text
          : '$text • wait about $wait min';
    }

    return 'Continue at $station';
  }

  int? _waitMinutes(
    DateTime? arrival,
    DateTime? departure,
  ) {
    if (arrival == null ||
        departure == null) {
      return null;
    }

    final value = departure
        .difference(arrival)
        .inMinutes;

    return value < 0 ? null : value;
  }

  IconData _connectorIcon(
    JourneyLegDetails current,
    JourneyLegDetails next,
  ) {
    if (next.leg.mode == 'Bus') {
      return Icons.directions_bus_rounded;
    }

    if (current.leg.mode == 'Bus' &&
        next.leg.mode == 'Walk') {
      return Icons.directions_walk_rounded;
    }

    if (current.leg.mode == 'Walk' &&
        next.leg.mode != 'Walk') {
      return Icons.login_rounded;
    }

    if (current.leg.mode != 'Walk' &&
        next.leg.mode == 'Walk') {
      return Icons.logout_rounded;
    }

    return Icons.sync_alt_rounded;
  }

  IconData _legIcon(String mode) {
    if (mode == 'Walk') {
      return Icons.directions_walk_rounded;
    }

    if (mode == 'Bus') {
      return Icons.directions_bus_rounded;
    }

    if (mode == 'KTM') {
      return Icons.train_rounded;
    }

    return Icons.subway_rounded;
  }

  Widget _fareCard(
    FareEstimateInfo? fare,
  ) {
    if (fare == null) {
      return const SizedBox.shrink();
    }

    return AppCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            'Rail Fare Estimate',
          ),
          const SizedBox(height: 12),
          Text(
            fare.hasFare
                ? fare.formattedFare
                : fare.title,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(fare.message),
          if (fare.sourceLabel != null) ...[
            const SizedBox(height: 7),
            Text(
              'Source: ${fare.sourceLabel}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall,
            ),
          ],
          if (fare.options.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final option
                in fare.options)
              Padding(
                padding:
                    const EdgeInsets.only(
                  bottom: 7,
                ),
                child:
                    OutlinedButton.icon(
                  onPressed: () {
                    _openFareSource(
                      option,
                    );
                  },
                  icon: const Icon(
                    Icons
                        .open_in_new_rounded,
                  ),
                  label:
                      Text(option.label),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _openFareSource(
    FareLookupOption option,
  ) async {
    final opened = await launchUrl(
          option.url,
          mode: LaunchMode.externalApplication,
        ) ||
        await launchUrl(option.url);

    if (!opened) {
      _message(
        'Unable to open the fare source.',
      );
    }
  }
}

class _RouteCandidate {
  const _RouteCandidate({
    required this.route,
    required this.journey,
    required this.accessPlan,
    required this.score,
  });

  final RouteSearchResult route;
  final RouteJourneyDetails journey;
  final BoardingAccessPlan accessPlan;
  final double score;
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
}

class JourneyLegDetails {
  const JourneyLegDetails({
    required this.leg,
    this.departure,
    this.arrival,
    this.durationMinutes,
    this.timingSource,
    this.isEstimate = false,
  });

  final RouteLeg leg;
  final DateTime? departure;
  final DateTime? arrival;
  final int? durationMinutes;
  final String? timingSource;
  final bool isEstimate;
}

class _StationPicker
    extends StatefulWidget {
  const _StationPicker({
    required this.title,
  });

  final String title;

  @override
  State<_StationPicker> createState() =>
      _StationPickerState();
}

class _StationPickerState
    extends State<_StationPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query =
        _query.trim().toLowerCase();

    final stations =
        routeStations.where((station) {
      return query.isEmpty ||
          station.name
              .toLowerCase()
              .contains(query) ||
          station.mode
              .toLowerCase()
              .contains(query);
    }).toList();

    return Scaffold(
      appBar:
          AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              onChanged: (value) {
                setState(
                  () => _query = value,
                );
              },
              decoration:
                  const InputDecoration(
                prefixIcon: Icon(
                  Icons.search_rounded,
                ),
                hintText:
                    'Search destination station',
              ),
            ),
          ),
          Expanded(
            child: stations.isEmpty
                ? const Center(
                    child: Text(
                      'No station found',
                    ),
                  )
                : ListView.separated(
                    itemCount:
                        stations.length,
                    separatorBuilder:
                        (_, _) =>
                            const Divider(
                      height: 1,
                    ),
                    itemBuilder:
                        (context, index) {
                      final station =
                          stations[index];

                      return ListTile(
                        leading:
                            const Icon(
                          Icons
                              .train_rounded,
                        ),
                        title: Text(
                          station.name,
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight
                                    .w800,
                          ),
                        ),
                        subtitle: Text(
                          station.mode,
                        ),
                        trailing:
                            const Icon(
                          Icons
                              .chevron_right_rounded,
                        ),
                        onTap: () {
                          Navigator.pop(
                            context,
                            station,
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StationInput
    extends StatelessWidget {
  const _StationInput({
    required this.label,
    required this.station,
    required this.hint,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final RouteStation? station;
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
          suffixIcon: const Icon(
            Icons
                .keyboard_arrow_down_rounded,
          ),
        ),
        child: Text(
          station?.name ?? hint,
          style: TextStyle(
            fontWeight: station == null
                ? FontWeight.normal
                : FontWeight.w700,
          ),
        ),
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

  final minute =
      value.minute.toString().padLeft(2, '0');

  return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
}

String _formatDateTime(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year} • ${_formatTime(value)}';
}

String _formatDistance(double metres) {
  if (metres < 1000) {
    return '${metres.round()} m';
  }

  return '${(metres / 1000).toStringAsFixed(1)} km';
}
