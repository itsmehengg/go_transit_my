import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/demo_data.dart';

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
          ],
        ],
      ),
    );
  }
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
