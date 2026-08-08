import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/demo_data.dart';

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

class _Statistics extends StatelessWidget {
  const _Statistics();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const AppCard(
          color: Color(0xFFEFF6FF),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Ridership',
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '12.8M',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text('+12.5% vs last month'),
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
          children: const [
            _StatCard('MRT', '5.2M', Color(0xFFECFDF5)),
            _StatCard('LRT', '3.6M', Color(0xFFFFF7ED)),
            _StatCard('KTM', '2.1M', Color(0xFFF3E8FF)),
            _StatCard('Bus', 'No data available', Color(0xFFE0F2FE)),
          ],
        ),
        const SizedBox(height: 18),
        AppCard(
          child: SizedBox(
            height: 190,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [80, 112, 96, 126, 145]
                  .map(
                    (h) => Container(
                      width: 24,
                      height: h.toDouble(),
                      decoration: BoxDecoration(
                        color: AppColors.primary2,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Dataset: Public transport ridership • Source: data.gov.my / OpenDOSM • Last updated: demo data',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
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
