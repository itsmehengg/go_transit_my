import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/demo_data.dart';
import 'ridership_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  int view = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(['Service Alerts', 'Alert Details', 'Statistics'][view]),
        leading: view == 0
            ? null
            : BackButton(onPressed: () => setState(() => view = 0)),
        actions: [
          IconButton(
            onPressed: () => setState(() => view = 2),
            icon: const Icon(Icons.bar_chart_rounded),
          ),
        ],
      ),
      body: view == 0
          ? _AlertList(onTap: () => setState(() => view = 1))
          : view == 1
          ? const _AlertDetails()
          : const _Statistics(),
    );
  }
}

class _AlertList extends StatelessWidget {
  const _AlertList({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Wrap(
          spacing: 8,
          children: ['All', 'MRT', 'LRT', 'Bus', 'KTM']
              .map((e) => ChoiceChip(label: Text(e), selected: e == 'All'))
              .toList(),
        ),
        const SizedBox(height: 18),
        for (final alert in alerts)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: AppCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: alert.color.withValues(alpha: .15),
                  child: Icon(Icons.warning_amber_rounded, color: alert.color),
                ),
                title: Text(
                  alert.type,
                  style: TextStyle(
                    color: alert.color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                subtitle: Text(alert.title),
                trailing: Text(
                  alert.time,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                onTap: onTap,
              ),
            ),
          ),
        const SizedBox(height: 12),
        const SectionTitle('Notifications'),
        const SizedBox(height: 10),
        ...['Train Delay', 'Route Saved', 'New Promotion'].map(
          (e) => ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: Text(e, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('Today'),
          ),
        ),
      ],
    );
  }
}

class _AlertDetails extends StatelessWidget {
  const _AlertDetails();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        StatusChip('Delay', color: AppColors.danger),
        SizedBox(height: 16),
        Text(
          'MRT Kajang Line Delay',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        SizedBox(height: 8),
        Text(
          '5 mins ago • 21 May 2025, 10:25 AM',
          style: TextStyle(color: AppColors.muted),
        ),
        SizedBox(height: 24),
        AppCard(
          child: Text(
            'MRT Kajang Line is delayed by 10 minutes due to signalling maintenance. We apologize for any inconvenience caused. Recommended alternative: use LRT Kelana Jaya Line via Pasar Seni where possible.',
            style: TextStyle(height: 1.5),
          ),
        ),
        SizedBox(height: 20),
        AppCard(
          color: Color(0xFFF8FAFC),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Affected operator: Rapid KL',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              Text('Affected line: MRT Kajang Line'),
              Text('Status: Delayed'),
              Text('Source: GTFS Realtime Service Alerts'),
              Text('Last updated: 10:40 AM'),
            ],
          ),
        ),
      ],
    );
  }
}

class _Statistics extends StatefulWidget {
  const _Statistics();

  @override
  State<_Statistics> createState() => _StatisticsState();
}

class _StatisticsState extends State<_Statistics> {
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
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              AppCard(
                color: const Color(0xFFFFF1F2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Unable to load ridership data',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        final data = snapshot.requireData;

        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              AppCard(
                color: const Color(0xFFEFF6FF),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Ridership',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatTrips(data.total),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text('Latest official data: ${_formatDate(data.date)}'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _StatCard(
                    'MRT',
                    _formatTrips(data.mrt),
                    const Color(0xFFECFDF5),
                  ),
                  _StatCard(
                    'LRT',
                    _formatTrips(data.lrt),
                    const Color(0xFFFFF7ED),
                  ),
                  _StatCard(
                    'KTM',
                    _formatTrips(data.ktm),
                    const Color(0xFFF3E8FF),
                  ),
                  _StatCard(
                    'Bus',
                    _formatTrips(data.bus),
                    const Color(0xFFE0F2FE),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _RidershipChart(values: data.recentTotals),
              const SizedBox(height: 12),
              const Text(
                'Dataset: Daily Public Transport Ridership • Source: data.gov.my / Ministry of Transport • API: ridership_headline',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
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
}

class _RidershipChart extends StatelessWidget {
  const _RidershipChart({required this.values});

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.isEmpty
        ? 1
        : values.reduce((a, b) => a > b ? a : b);

    return AppCard(
      child: SizedBox(
        height: 190,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: values.map((value) {
            final height = 34 + (value / maxValue * 130);
            return Tooltip(
              message: value.toString(),
              child: Container(
                width: 18,
                height: height,
                decoration: BoxDecoration(
                  color: AppColors.primary2,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
