import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../profile/personalisation_service.dart';
import 'ridership_service.dart';
import 'route_search_service.dart';
import 'station_catalog.dart';

class RoutePlannerScreen extends StatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen> {
  final _routeSearchService = const RouteSearchService();
  bool showResults = false;
  bool _isSearching = false;
  RouteStation? fromStation;
  RouteStation? toStation;
  RouteSearchResult? _routeResult;
  DateTime departureTime = DateTime.now();
  String selectedTransport = 'All';
  late final PersonalisationService _personalisation;
  String _lastProfileTransport = 'All';
  bool _transportChangedForJourney = false;

  @override
  void initState() {
    super.initState();
    _personalisation = PersonalisationService.instance;
    _lastProfileTransport = _validTransport(_personalisation.preferredTransport);
    selectedTransport = _lastProfileTransport;
    _personalisation.addListener(_onPersonalisationChanged);
  }

  @override
  void dispose() {
    _personalisation.removeListener(_onPersonalisationChanged);
    super.dispose();
  }

  String _validTransport(String value) {
    return const ['All', 'MRT', 'LRT', 'Bus', 'KTM'].contains(value) ? value : 'All';
  }

  void _onPersonalisationChanged() {
    final preferred = _validTransport(_personalisation.preferredTransport);
    if (preferred == _lastProfileTransport) return;
    _lastProfileTransport = preferred;
    if (!mounted) return;
    setState(() {
      selectedTransport = preferred;
      _transportChangedForJourney = false;
    });
  }

  void _changeTransport(String value) {
    setState(() {
      selectedTransport = value;
      _transportChangedForJourney = value != _lastProfileTransport;
    });
  }

  Future<void> _pickStation(bool isFrom) async {
    final station = await Navigator.of(context).push<RouteStation>(
      MaterialPageRoute(
        builder: (_) => StationSelectionScreen(
          title: isFrom ? 'Select starting station' : 'Select destination',
          excludedStation: isFrom ? toStation : fromStation,
        ),
      ),
    );
    if (station == null || !mounted) return;
    setState(() {
      if (isFrom) {
        fromStation = station;
      } else {
        toStation = station;
      }
      _routeResult = null;
      showResults = false;
    });
  }

  Future<void> _pickDepartureTime() async {
    final now = DateTime.now();
    final initialDate = departureTime.isBefore(now) ? now : departureTime;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(departureTime.isBefore(now) ? now : departureTime),
    );
    if (time == null || !mounted) return;

    final selected = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (selected.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Departure time cannot be in the past.')),
      );
      return;
    }
    setState(() => departureTime = selected);
  }

  void _swapStations() {
    setState(() {
      final oldFrom = fromStation;
      fromStation = toStation;
      toStation = oldFrom;
      _routeResult = null;
      showResults = false;
    });
  }

  Future<void> _findRoute() async {
    if (fromStation == null || toStation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both starting station and destination.')),
      );
      return;
    }
    if (fromStation!.name == toStation!.name) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Starting station and destination must be different.')),
      );
      return;
    }
    if (departureTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a valid departure time.')),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _routeResult = null;
    });

    final result = await _routeSearchService.search(
      from: fromStation!,
      to: toStation!,
      transport: selectedTransport,
    );

    if (!mounted) return;
    setState(() {
      _routeResult = result;
      _isSearching = false;
      showResults = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(showResults ? 'Route Results' : 'Plan Journey')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!showResults) ...[
            _PlannerForm(
              fromStation: fromStation,
              toStation: toStation,
              departureTime: departureTime,
              selectedTransport: selectedTransport,
              profileTransport: _lastProfileTransport,
              transportChangedForJourney: _transportChangedForJourney,
              onPickFrom: () => _pickStation(true),
              onPickTo: () => _pickStation(false),
              onClearFrom: fromStation == null
                  ? null
                  : () => setState(() {
                        fromStation = null;
                        _routeResult = null;
                      }),
              onClearTo: toStation == null
                  ? null
                  : () => setState(() {
                        toStation = null;
                        _routeResult = null;
                      }),
              onSwap: _swapStations,
              onPickDepartureTime: _pickDepartureTime,
              onTransportChanged: _changeTransport,
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _isSearching ? null : _findRoute,
              child: _isSearching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Find Route'),
            ),
            const SizedBox(height: 28),
            FareEstimateCard(fromStation: fromStation, toStation: toStation),
            const SizedBox(height: 28),
            const RidershipInsightsCard(),
          ] else ...[
            Text(
              '${fromStation!.name} → ${toStation!.name}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              '${_formatDeparture(departureTime)} • $selectedTransport',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            if (_routeResult == null)
              _NoRouteCard(transport: selectedTransport)
            else ...[
              RouteSearchResultCard(result: _routeResult!),
              const SizedBox(height: 18),
              RouteDetailsCard(result: _routeResult!),
            ],
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () => setState(() => showResults = false),
              icon: const Icon(Icons.edit_location_alt_outlined),
              label: const Text('Edit Search'),
            ),
            const SizedBox(height: 18),
            const RidershipInsightsCard(),
          ],
        ],
      ),
    );
  }
}

class StationSelectionScreen extends StatefulWidget {
  const StationSelectionScreen({required this.title, this.excludedStation, super.key});

  final String title;
  final RouteStation? excludedStation;

  @override
  State<StationSelectionScreen> createState() => _StationSelectionScreenState();
}

class _StationSelectionScreenState extends State<StationSelectionScreen> {
  final searchController = TextEditingController();
  String query = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stations = routeStations.where((station) {
      if (station.name == widget.excludedStation?.name) return false;
      final text = query.trim().toLowerCase();
      return text.isEmpty ||
          station.name.toLowerCase().contains(text) ||
          station.mode.toLowerCase().contains(text);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: searchController,
              autofocus: true,
              onChanged: (value) => setState(() => query = value),
              decoration: InputDecoration(
                hintText: 'Search station',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          searchController.clear();
                          setState(() => query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          Expanded(
            child: stations.isEmpty
                ? const Center(child: Text('No station found'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: stations.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final station = stations[index];
                      return ListTile(
                        leading: const Icon(Icons.train_rounded),
                        title: Text(
                          station.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(station.mode),
                        trailing: const Icon(Icons.chevron_right_rounded),
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

class _PlannerForm extends StatelessWidget {
  const _PlannerForm({
    required this.fromStation,
    required this.toStation,
    required this.departureTime,
    required this.selectedTransport,
    required this.profileTransport,
    required this.transportChangedForJourney,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onClearFrom,
    required this.onClearTo,
    required this.onSwap,
    required this.onPickDepartureTime,
    required this.onTransportChanged,
  });

  final RouteStation? fromStation;
  final RouteStation? toStation;
  final DateTime departureTime;
  final String selectedTransport;
  final String profileTransport;
  final bool transportChangedForJourney;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback? onClearFrom;
  final VoidCallback? onClearTo;
  final VoidCallback onSwap;
  final VoidCallback onPickDepartureTime;
  final ValueChanged<String> onTransportChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StationField(
            label: 'From',
            hint: 'Select starting station',
            station: fromStation,
            icon: Icons.trip_origin_rounded,
            onTap: onPickFrom,
            onClear: onClearFrom,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Swap stations',
                onPressed: onSwap,
                icon: const Icon(Icons.swap_vert_rounded),
              ),
            ),
          ),
          _StationField(
            label: 'To',
            hint: 'Select destination',
            station: toStation,
            icon: Icons.location_on_rounded,
            onTap: onPickTo,
            onClear: onClearTo,
          ),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPickDepartureTime,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Departure Time',
                prefixIcon: Icon(Icons.schedule_rounded),
                suffixIcon: Icon(Icons.edit_calendar_rounded),
              ),
              child: Text(
                _formatDeparture(departureTime),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('Transport', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['All', 'MRT', 'LRT', 'Bus', 'KTM']
                .map(
                  (transport) => ChoiceChip(
                    label: Text(transport),
                    selected: selectedTransport == transport,
                    onSelected: (_) => onTransportChanged(transport),
                  ),
                )
                .toList(),
          ),
          if (profileTransport != 'All') ...[
            const SizedBox(height: 10),
            Text(
              transportChangedForJourney
                  ? 'Profile preference: $profileTransport • This journey: $selectedTransport'
                  : 'Using preferred transport from Profile: $profileTransport',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _StationField extends StatelessWidget {
  const _StationField({
    required this.label,
    required this.hint,
    required this.station,
    required this.icon,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final String hint;
  final RouteStation? station;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: station == null
              ? const Icon(Icons.keyboard_arrow_down_rounded)
              : IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
        child: Text(
          station?.name ?? hint,
          style: TextStyle(
            color: station == null ? Theme.of(context).hintColor : null,
            fontWeight: station == null ? FontWeight.normal : FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class RouteSearchResultCard extends StatelessWidget {
  const RouteSearchResultCard({required this.result, super.key});

  final RouteSearchResult result;

  @override
  Widget build(BuildContext context) {
    final transferText = result.transfers == 0
        ? 'Direct journey'
        : result.transfers == 1
            ? '1 transfer'
            : '${result.transfers} transfers';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.route_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Route found',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
              StatusChip(transferText, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            result.modes.isEmpty ? 'Walking connection' : result.modes.join(' + '),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Journey time and fare are not shown yet because they will be connected to verified transport data in the next stage.',
          ),
        ],
      ),
    );
  }
}

class _NoRouteCard extends StatelessWidget {
  const _NoRouteCard({required this.transport});

  final String transport;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const Icon(Icons.route_outlined, size: 54, color: AppColors.muted),
          const SizedBox(height: 12),
          const Text(
            'No route found',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            transport == 'Bus'
                ? 'Bus route data is not connected yet. Try All, MRT, LRT, or KTM.'
                : 'Try another transport type or choose different stations.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class FareEstimateCard extends StatelessWidget {
  const FareEstimateCard({this.fromStation, this.toStation, super.key});

  final RouteStation? fromStation;
  final RouteStation? toStation;

  @override
  Widget build(BuildContext context) {
    final ready = fromStation != null && toStation != null;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Fare Estimation'),
          const SizedBox(height: 14),
          Text(
            ready ? 'Not calculated yet' : 'Select your journey first',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            ready
                ? '${fromStation!.name} to ${toStation!.name}'
                : 'Choose a starting station and destination.',
          ),
          if (ready) ...[
            const SizedBox(height: 8),
            const Text('Only verified fare data will be displayed here.'),
          ],
        ],
      ),
    );
  }
}

class RouteDetailsCard extends StatelessWidget {
  const RouteDetailsCard({required this.result, super.key});

  final RouteSearchResult result;

  @override
  Widget build(BuildContext context) {
    final legs = result.groupedLegs;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Route Details'),
          const SizedBox(height: 14),
          for (var i = 0; i < legs.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                child: Icon(
                  legs[i].mode == 'Walk'
                      ? Icons.directions_walk_rounded
                      : legs[i].mode == 'Bus'
                          ? Icons.directions_bus_rounded
                          : Icons.train_rounded,
                  size: 20,
                ),
              ),
              title: Text(
                legs[i].line,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('${legs[i].from} → ${legs[i].to}'),
            ),
          const SizedBox(height: 6),
          Text(
            'Schedule timing will be added when the official route data source is connected.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class RidershipInsightsCard extends StatefulWidget {
  const RidershipInsightsCard({super.key});

  @override
  State<RidershipInsightsCard> createState() => _RidershipInsightsCardState();
}

class _RidershipInsightsCardState extends State<RidershipInsightsCard> {
  final _ridershipService = RidershipService();
  late Future<RidershipSnapshot> _snapshotFuture;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _ridershipService.fetchLatestSnapshot();
  }

  void _refresh() {
    setState(() => _snapshotFuture = _ridershipService.fetchLatestSnapshot());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RidershipSnapshot>(
      future: _snapshotFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppCard(
            child: SizedBox(
              height: 150,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasError) {
          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Ridership Insights'),
                const SizedBox(height: 10),
                const Text('Unable to load government ridership data.'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        final data = snapshot.requireData;
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: SectionTitle('Ridership Insights')),
                  IconButton(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _formatTrips(data.total),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
              ),
              const Text('Daily network trips'),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ModeStatTile(label: 'MRT', value: _formatTrips(data.mrt)),
                  _ModeStatTile(label: 'LRT', value: _formatTrips(data.lrt)),
                  _ModeStatTile(label: 'KTM', value: _formatTrips(data.ktm)),
                  _ModeStatTile(label: 'Bus', value: _formatTrips(data.bus)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Latest official data: ${_formatDate(data.date)}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModeStatTile extends StatelessWidget {
  const _ModeStatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

String _formatTrips(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toString();
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _formatDeparture(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final selectedDay = DateTime(date.year, date.month, date.day);
  String day;
  if (selectedDay == today) {
    day = 'Today';
  } else if (selectedDay == today.add(const Duration(days: 1))) {
    day = 'Tomorrow';
  } else {
    day = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
  final hour = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  return '$day, $hour:$minute $period';
}
