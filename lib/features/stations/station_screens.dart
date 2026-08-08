import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/demo_data.dart';

class NearbyStationsScreen extends StatefulWidget {
  const NearbyStationsScreen({super.key});

  @override
  State<NearbyStationsScreen> createState() => _NearbyStationsScreenState();
}

class _NearbyStationsScreenState extends State<NearbyStationsScreen> {
  int selected = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _NearbyList(onOpenDetails: () => setState(() => selected = 1)),
      _StationDetails(onLive: () => setState(() => selected = 2)),
      _LiveArrivals(onMap: () => setState(() => selected = 3)),
      _VehicleMap(onBack: () => setState(() => selected = 0)),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          [
            'Nearby Stations',
            'KL Sentral',
            'Live Arrival',
            'Vehicle Map',
          ][selected],
        ),
        leading: selected == 0
            ? null
            : BackButton(onPressed: () => setState(() => selected = 0)),
      ),
      body: pages[selected],
    );
  }
}

class _NearbyList extends StatelessWidget {
  const _NearbyList({required this.onOpenDetails});
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const MockMap(),
        const SizedBox(height: 20),
        TextField(
          decoration: InputDecoration(
            hintText: 'Search stations',
            prefixIcon: const Icon(Icons.search_rounded),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: ['All', 'MRT', 'LRT', 'Bus', 'KTM']
              .map((e) => ChoiceChip(label: Text(e), selected: e == 'All'))
              .toList(),
        ),
        const SizedBox(height: 18),
        ...stations.map(
          (s) => Card(
            child: ListTile(
              leading: const Icon(
                Icons.train_rounded,
                color: AppColors.primary,
              ),
              title: Text(
                s.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(s.location),
              trailing: Text(s.distance),
              onTap: onOpenDetails,
            ),
          ),
        ),
      ],
    );
  }
}

class _StationDetails extends StatelessWidget {
  const _StationDetails({required this.onLive});
  final VoidCallback onLive;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        AppCard(
          color: const Color(0xFFE6F4FF),
          child: SizedBox(
            height: 140,
            child: Stack(
              children: [
                const Align(
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.train_rounded,
                    size: 120,
                    color: AppColors.primary2,
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: IconButton.filledTonal(
                    onPressed: () {},
                    icon: const Icon(Icons.favorite, color: AppColors.danger),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'KL Sentral',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const Text(
          'KLS • Kuala Lumpur • 300 m away',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 18),
        const AppCard(
          color: Color(0xFFECFDF5),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: TransportIcon(
              icon: Icons.check_rounded,
              color: AppColors.success,
            ),
            title: Text(
              'Operational',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text('Open • 5:30 AM - 12:00 AM'),
          ),
        ),
        const SizedBox(height: 18),
        const SectionTitle('Facilities'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              [
                    'Parking',
                    'Restroom',
                    'Lift',
                    'Escalator',
                    'Surau',
                    'Wheelchair',
                  ]
                  .map(
                    (e) => Chip(
                      label: Text(e),
                      avatar: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 16,
                      ),
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: onLive,
          icon: const Icon(Icons.schedule_rounded),
          label: const Text('View Live Arrival'),
        ),
      ],
    );
  }
}

class _LiveArrivals extends StatelessWidget {
  const _LiveArrivals({required this.onMap});
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    final arrivals = [
      (
        'MRT Kajang Line',
        'Platform 1',
        '2 mins',
        '10:42 AM',
        AppColors.success,
        'Live',
      ),
      (
        'MRT Putrajaya Line',
        'Platform 2',
        '6 mins',
        '10:46 AM',
        AppColors.warning,
        'Scheduled',
      ),
      (
        'KTM Komuter',
        'Platform 3',
        '12 mins',
        '10:52 AM',
        AppColors.primary2,
        'Realtime unavailable',
      ),
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Wrap(
          spacing: 8,
          children: ['All', 'MRT', 'KTM', 'LRT']
              .map((e) => ChoiceChip(label: Text(e), selected: e == 'All'))
              .toList(),
        ),
        const SizedBox(height: 18),
        for (final a in arrivals)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: AppCard(
              color: a.$5.withValues(alpha: .08),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 64,
                    decoration: BoxDecoration(
                      color: a.$5,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.$1,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          a.$2,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 8),
                        StatusChip(a.$6, color: a.$5),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        a.$3,
                        style: TextStyle(
                          color: a.$5,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        a.$4,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const Text(
          'Last updated: 10:40 AM',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: onMap,
          icon: const Icon(Icons.map_rounded),
          label: const Text('Track Vehicles'),
        ),
      ],
    );
  }
}

class _VehicleMap extends StatelessWidget {
  const _VehicleMap({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: MockMap()),
        Positioned(
          left: 20,
          right: 20,
          bottom: 28,
          child: AppCard(
            child: Row(
              children: [
                const TransportIcon(
                  icon: Icons.train_rounded,
                  color: AppColors.success,
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'MRT Kajang Line',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text('Vehicle positions supported where available'),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
