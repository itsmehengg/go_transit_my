import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/demo_data.dart';
import '../profile/personalisation_service.dart';
import 'ridership_service.dart';
import 'station_catalog.dart';

class RoutePlannerScreen extends StatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen> {
  bool showResults = false;
  RouteStation? fromStation;
  RouteStation? toStation;
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
    });
  }

  void _findRoute() {
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
    setState(() => showResults = true);
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
              onClearFrom: fromStation == null ? null : () => setState(() => fromStation = null),
              onClearTo: toStation == null ? null : () => setState(() => toStation = null),
              onSwap: _swapStations,
              onPickDepartureTime: _pickDepartureTime,
              onTransportChanged: _changeTransport,
            ),
            const SizedBox(height: 28),
            ElevatedButton(onPressed: _findRoute, child: const Text('Find Route')),
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
              style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
            ),
            const SizedBox(height: 16),
            const _SortTabs(),
            const SizedBox(height: 16),
            ...journeyOptions.map(
              (option) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: RouteResultCard(option: option),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => setState(() => showResults = false),
              icon: const Icon(Icons.edit_location_alt_outlined),
              label: const Text('Edit Search'),
            ),
            const SizedBox(height: 18),
            RouteDetailsCard(fromStation: fromStation!, toStation: toStation!),
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
      return text.isEmpty || station.name.toLowerCase().contains(text) || station.mode.toLowerCase().contains(text);
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
                        title: Text(station.name, style: const TextStyle(fontWeight: FontWeight.w800)),
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
              : IconButton(onPressed: onClear, icon: const Icon(Icons.close_rounded)),
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
          return const AppCard(child: SizedBox(height: 150, child: Center(child: CircularProgressIndicator())));
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
                OutlinedButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
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
                  IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
                ],
              ),
              const SizedBox(height: 12),
              Text(_formatTrips(data.total), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
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
              Text('Latest official data: ${_formatDate(data.date)}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
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
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
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

class _SortTabs extends StatelessWidget {
  const _SortTabs();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ['Fastest', 'Cheapest', 'Least Walking', 'Fewest Transfers']
          .map((e) => ChoiceChip(label: Text(e), selected: e == 'Fastest'))
          .toList(),
    );
  }
}

class RouteResultCard extends StatelessWidget {
  const RouteResultCard({required this.option, super.key});
  final JourneyOption option;

  @override
  Widget build(BuildContext context) {
    final live = option.status == 'Live';
    return AppCard(
      child: Row(
        children: [
          TransportIcon(icon: option.mode.icon, color: option.mode.color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(option.duration, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const Spacer(),
                    Text(option.fare, style: const TextStyle(fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(option.time, style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    StatusChip(option.mode.name, color: option.mode.color),
                    const SizedBox(width: 8),
                    StatusChip(option.status, color: live ? AppColors.success : AppColors.muted),
                  ],
                ),
                const SizedBox(height: 6),
                Text('${option.transfers} • 450 m walking', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
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
          Text(ready ? 'Available after route search' : 'Select your journey first', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(ready ? '${fromStation!.name} to ${toStation!.name}' : 'Choose a starting station and destination.'),
        ],
      ),
    );
  }
}

class RouteDetailsCard extends StatelessWidget {
  const RouteDetailsCard({required this.fromStation, required this.toStation, super.key});
  final RouteStation fromStation;
  final RouteStation toStation;

  @override
  Widget build(BuildContext context) {
    final steps = ['Start at ${fromStation.name}', 'Follow selected public transport route', 'Arrive at ${toStation.name}'];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Route Details'),
          const SizedBox(height: 14),
          for (var i = 0; i < steps.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text(steps[i], style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Route details will be calculated in the next part.'),
            ),
          ElevatedButton(onPressed: null, child: const Text('View on Map')),
        ],
      ),
    );
  }
}
