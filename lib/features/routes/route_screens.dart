import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/demo_data.dart';
import 'ridership_service.dart';

class RoutePlannerScreen extends StatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen> {
  bool showResults = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(showResults ? 'Route Results' : 'Plan Journey'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!showResults) ...[
            const _PlannerForm(),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () => setState(() => showResults = true),
              child: const Text('Find Route'),
            ),
            const SizedBox(height: 28),
            const FareEstimateCard(),
            const SizedBox(height: 28),
            const RidershipInsightsCard(),
          ] else ...[
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
            const RouteDetailsCard(),
            const SizedBox(height: 18),
            const RidershipInsightsCard(),
          ],
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
    setState(() {
      _snapshotFuture = _ridershipService.fetchLatestSnapshot();
    });
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
            color: const Color(0xFFFFF1F2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Ridership Insights'),
                const SizedBox(height: 10),
                const Text(
                  'Unable to load government ridership data.',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w800,
                  ),
                ),
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
          color: const Color(0xFFF8FAFC),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: SectionTitle('Ridership Insights')),
                  IconButton(
                    tooltip: 'Refresh data',
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _RidershipHero(snapshot: data),
              const SizedBox(height: 14),
              _ModeStatWrap(snapshot: data),
              const SizedBox(height: 18),
              _RidershipChart(values: data.recentTotals),
              const SizedBox(height: 10),
              Text(
                'Latest official data: ${_formatDate(data.date)} • Source: data.gov.my ridership_headline',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RidershipHero extends StatelessWidget {
  const _RidershipHero({required this.snapshot});

  final RidershipSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const TransportIcon(
            icon: Icons.insights_rounded,
            color: Colors.white,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily network trips',
                  style: TextStyle(
                    color: Color(0xFFD8E7FF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _formatTrips(snapshot.total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeStatWrap extends StatelessWidget {
  const _ModeStatWrap({required this.snapshot});

  final RidershipSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = constraints.maxWidth >= 720
            ? (constraints.maxWidth - 36) / 4
            : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ModeStatTile(
              width: tileWidth,
              label: 'MRT',
              value: _formatTrips(snapshot.mrt),
              color: const Color(0xFF10A66B),
            ),
            _ModeStatTile(
              width: tileWidth,
              label: 'LRT',
              value: _formatTrips(snapshot.lrt),
              color: const Color(0xFFEF4444),
            ),
            _ModeStatTile(
              width: tileWidth,
              label: 'KTM',
              value: _formatTrips(snapshot.ktm),
              color: const Color(0xFF7C3AED),
            ),
            _ModeStatTile(
              width: tileWidth,
              label: 'Bus',
              value: _formatTrips(snapshot.bus),
              color: const Color(0xFF0EA5E9),
            ),
          ],
        );
      },
    );
  }
}

class _ModeStatTile extends StatelessWidget {
  const _ModeStatTile({
    required this.width,
    required this.label,
    required this.value,
    required this.color,
  });

  final double width;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _RidershipChart extends StatelessWidget {
  const _RidershipChart({required this.values});

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.isEmpty
        ? 1
        : values.reduce((a, b) => a > b ? a : b);

    return Container(
      height: 170,
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: values.map((value) {
          final height = 28 + (value / maxValue * 112);
          return Expanded(
            child: Tooltip(
              message: _formatTrips(value),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: 12,
                  height: height,
                  decoration: BoxDecoration(
                    color: AppColors.primary2,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

String _formatTrips(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  return value.toString();
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _PlannerForm extends StatelessWidget {
  const _PlannerForm();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const TextField(
            decoration: InputDecoration(
              labelText: 'From',
              hintText: 'Current Location',
              prefixIcon: Icon(Icons.my_location_rounded),
            ),
          ),
          const SizedBox(height: 16),
          const TextField(
            decoration: InputDecoration(
              labelText: 'To',
              hintText: 'KL Sentral',
              prefixIcon: Icon(Icons.location_on_rounded),
            ),
          ),
          const SizedBox(height: 16),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Departure Time',
              hintText: 'Today, 10:30 AM',
              prefixIcon: Icon(Icons.schedule_rounded),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            children: ['All', 'MRT', 'LRT', 'Bus', 'KTM']
                .map((e) => ChoiceChip(label: Text(e), selected: e == 'All'))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _SortTabs extends StatelessWidget {
  const _SortTabs();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
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
                    Text(
                      option.duration,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      option.fare,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  option.time,
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    StatusChip(option.mode.name, color: option.mode.color),
                    const SizedBox(width: 8),
                    StatusChip(
                      option.status,
                      color: live ? AppColors.success : AppColors.muted,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${option.transfers} • 450 m walking',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FareEstimateCard extends StatelessWidget {
  const FareEstimateCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: const Color(0xFFEFF6FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Fare Estimation'),
          const SizedBox(height: 14),
          const Text(
            'RM 2.70',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text('Estimated fare from Bukit Bintang to KL Sentral'),
          const SizedBox(height: 12),
          Text(
            'Exact fare may vary depending on operator data availability.',
            style: TextStyle(
              color: Colors.orange.shade900,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class RouteDetailsCard extends StatelessWidget {
  const RouteDetailsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final steps = [
      'Walk to Bukit Bintang',
      'MRT Kajang Line',
      'Transfer at Pasar Seni',
      'Arrive KL Sentral',
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Route Details'),
          const SizedBox(height: 14),
          for (var i = 0; i < steps.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: i == 1 ? AppColors.success : AppColors.primary,
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                steps[i],
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                i == 1 ? '10:30 AM - 10:48 AM • Live' : 'Scheduled',
              ),
            ),
          ElevatedButton(onPressed: () {}, child: const Text('View on Map')),
        ],
      ),
    );
  }
}
