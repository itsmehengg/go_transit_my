import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../profile/personalisation_service.dart';
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
  late final PersonalisationService _personalisation;

  RouteStation? _from;
  RouteStation? _to;
  RouteSearchResult? _route;
  RouteJourneyDetails? _journey;
  FareEstimateInfo? _fare;
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
    if (const ['All', 'MRT', 'LRT', 'Bus', 'KTM'].contains(preferred)) {
      _transport = preferred;
    }
  }

  Future<void> _selectStation(bool origin) async {
    final station = await Navigator.of(context).push<RouteStation>(
      MaterialPageRoute(
        builder: (_) => _StationPicker(
          title: origin ? 'Select starting station' : 'Select destination',
          excluded: origin ? _to : _from,
        ),
      ),
    );
    if (station == null || !mounted) return;
    setState(() {
      if (origin) {
        _from = station;
      } else {
        _to = station;
      }
      _clearResult();
    });
  }

  void _clearResult() {
    _route = null;
    _journey = null;
    _fare = null;
    _showResult = false;
  }

  void _swap() {
    setState(() {
      final value = _from;
      _from = _to;
      _to = value;
      _clearResult();
    });
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
      _departure = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _clearResult();
    });
  }

  Future<void> _findRoute() async {
    if (_from == null || _to == null) {
      _message('Please select a starting station and destination.');
      return;
    }
    if (_from!.name == _to!.name) {
      _message('Starting station and destination must be different.');
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
      final route = await _routeSearch.search(
        from: _from!,
        to: _to!,
        transport: _transport,
      );
      if (route == null) {
        if (!mounted) return;
        setState(() {
          _route = null;
          _journey = null;
          _fare = null;
          _searching = false;
          _showResult = true;
        });
        return;
      }

      final timing = await _buildJourney(route);
      final fare = await _fareService.getStoredFareInfo(route);
      await _personalisation.addRecentSearch('${_from!.name} → ${_to!.name} • $_transport');

      if (!mounted) return;
      setState(() {
        _route = route;
        _journey = timing;
        _fare = fare;
        _searching = false;
        _showResult = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _showResult = true;
      });
      _message('Unable to load the route data. Please try again.');
    }
  }

  Future<RouteJourneyDetails> _buildJourney(RouteSearchResult route) async {
    final details = <JourneyLegDetails>[];
    var nextDeparture = _departure;
    for (final leg in route.groupedLegs) {
      if (leg.mode == 'Walk') {
        const minutes = 8;
        final arrival = nextDeparture.add(const Duration(minutes: minutes));
        details.add(
          JourneyLegDetails(
            leg: leg,
            departure: nextDeparture,
            arrival: arrival,
            durationMinutes: minutes,
            timingSource: 'Estimated walking connection',
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
        details.add(JourneyLegDetails(leg: leg));
        continue;
      }
      details.add(
        JourneyLegDetails(
          leg: leg,
          departure: timing.departure,
          arrival: timing.arrival,
          durationMinutes: timing.durationMinutes,
          timingSource: timing.source,
        ),
      );
      nextDeparture = timing.arrival;
    }

    final timed = details.where((item) => item.arrival != null).toList();
    final arrival = timed.isEmpty ? null : timed.last.arrival;
    return RouteJourneyDetails(legs: details, arrival: arrival);
  }

  Future<void> _save() async {
    final route = _route;
    if (route == null) return;
    final mode = route.modes.isEmpty ? 'Walk' : route.modes.join(' + ');
    final value = '${route.from.name} → ${route.to.name} • $mode';
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_showResult ? 'Best Route' : 'Plan Journey')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: _showResult ? _resultContent() : _searchContent(),
      ),
    );
  }

  List<Widget> _searchContent() {
    return [
      AppCard(
        child: Column(
          children: [
            _StationInput(
              label: 'From',
              station: _from,
              hint: 'Select starting station',
              icon: Icons.trip_origin_rounded,
              onTap: () => _selectStation(true),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(onPressed: _swap, icon: const Icon(Icons.swap_vert_rounded)),
            ),
            _StationInput(
              label: 'To',
              station: _to,
              hint: 'Select destination',
              icon: Icons.location_on_rounded,
              onTap: () => _selectStation(false),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDeparture,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Leave at',
                  prefixIcon: Icon(Icons.schedule_rounded),
                ),
                child: Text(_formatDateTime(_departure), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Transport', style: Theme.of(context).textTheme.titleSmall),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['All', 'MRT', 'LRT', 'KTM']
                  .map(
                    (value) => ChoiceChip(
                      label: Text(value),
                      selected: _transport == value,
                      onSelected: (_) => setState(() {
                        _transport = value;
                        _clearResult();
                      }),
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
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.route_rounded),
        label: Text(_searching ? 'Finding best route...' : 'Find Best Route'),
      ),
      const SizedBox(height: 14),
      Text(
        'Public transport timing is read from Malaysia Government GTFS Static data. Fare values are shown only when a stored official fare reference is available.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ];
  }

  List<Widget> _resultContent() {
    if (_route == null) {
      return [
        const AppCard(
          child: Column(
            children: [
              Icon(Icons.route_outlined, size: 48, color: AppColors.muted),
              SizedBox(height: 12),
              Text('No route found', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        OutlinedButton(onPressed: () => setState(() => _showResult = false), child: const Text('Edit Search')),
      ];
    }

    final route = _route!;
    final fare = _fare;
    final journey = _journey;
    return [
      Text('${route.from.name} → ${route.to.name}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      Text(_formatDateTime(_departure), style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 16),
      AppCard(
        color: const Color(0xFFEFF6FF),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.recommend_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                const Expanded(child: Text('Best Route', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
                StatusChip(route.transfers == 0 ? 'Direct' : '${route.transfers} transfer${route.transfers == 1 ? '' : 's'}', color: AppColors.primary),
              ],
            ),
            const SizedBox(height: 12),
            Text(route.modes.join(' + '), style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (journey?.arrival != null)
              Text('Estimated arrival: ${_formatTime(journey!.arrival!)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            if (journey?.arrival != null)
              Text('Journey from selected departure: ${journey!.arrival!.difference(_departure).inMinutes} min'),
            const SizedBox(height: 8),
            Text(fare?.hasFare == true ? 'Estimated fare: ${fare!.formattedFare}' : 'Fare: official value unavailable for this journey'),
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
        onPressed: _saving ? null : _save,
        icon: const Icon(Icons.favorite_border_rounded),
        label: const Text('Save Route'),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () => setState(() => _showResult = false),
        icon: const Icon(Icons.edit_location_alt_outlined),
        label: const Text('Edit Search'),
      ),
    ];
  }

  List<Widget> _detailCards(RouteSearchResult route, RouteJourneyDetails? journey) {
    final items = journey?.legs ?? route.groupedLegs.map((leg) => JourneyLegDetails(leg: leg)).toList();
    final widgets = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final leg = item.leg;
      widgets.add(
        AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                child: Icon(leg.mode == 'Walk' ? Icons.directions_walk_rounded : Icons.train_rounded, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(leg.mode == 'Walk' ? 'Walk connection' : leg.line, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('${leg.from} → ${leg.to}'),
                    if (item.departure != null && item.arrival != null) ...[
                      const SizedBox(height: 7),
                      Text('${_formatTime(item.departure!)} → ${_formatTime(item.arrival!)} • ${item.durationMinutes} min'),
                    ],
                    if (item.timingSource != null) ...[
                      const SizedBox(height: 5),
                      Text(item.timingSource!, style: Theme.of(context).textTheme.bodySmall),
                    ],
                    if (item.departure == null && leg.mode != 'Walk') ...[
                      const SizedBox(height: 5),
                      Text('No matching scheduled trip found in the Government GTFS feed for the selected time.', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      if (i < items.length - 1) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Row(
              children: [
                const Icon(Icons.sync_alt_rounded, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Change at ${leg.to}',
                    style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.warning),
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

  Widget _fareCard(FareEstimateInfo? fare) {
    if (fare == null) return const SizedBox.shrink();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Official Fare Estimation'),
          const SizedBox(height: 12),
          Text(fare.hasFare ? fare.formattedFare : 'Fare unavailable', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          Text(fare.message),
          if (fare.sourceLabel != null) ...[
            const SizedBox(height: 7),
            Text('Source: ${fare.sourceLabel}', style: Theme.of(context).textTheme.bodySmall),
          ],
          if (fare.options.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final option in fare.options)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: OutlinedButton.icon(
                  onPressed: () => _openFareSource(option),
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
    final opened = await launchUrl(option.url, mode: LaunchMode.externalApplication);
    if (!opened) _message('Unable to open the official fare page.');
  }
}

class RouteJourneyDetails {
  const RouteJourneyDetails({required this.legs, required this.arrival});

  final List<JourneyLegDetails> legs;
  final DateTime? arrival;
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

class _StationPicker extends StatefulWidget {
  const _StationPicker({required this.title, this.excluded});

  final String title;
  final RouteStation? excluded;

  @override
  State<_StationPicker> createState() => _StationPickerState();
}

class _StationPickerState extends State<_StationPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final stations = routeStations.where((station) {
      if (station.name == widget.excluded?.name) return false;
      return query.isEmpty || station.name.toLowerCase().contains(query) || station.mode.toLowerCase().contains(query);
    }).toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search station'),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: stations.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final station = stations[index];
                return ListTile(
                  leading: const Icon(Icons.train_rounded),
                  title: Text(station.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(station.mode),
                  onTap: () => Navigator.pop(context, station),
                );
              },
            ),
          ),
        ],
      ),
    );
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
  final RouteStation? station;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded)),
        child: Text(station?.name ?? hint, style: TextStyle(fontWeight: station == null ? FontWeight.normal : FontWeight.w700)),
      ),
    );
  }
}

String _formatTime(DateTime value) {
  final hour = value.hour == 0 ? 12 : value.hour > 12 ? value.hour - 12 : value.hour;
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
}

String _formatDateTime(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} • ${_formatTime(value)}';
}