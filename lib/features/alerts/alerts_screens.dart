import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../profile/personalisation_service.dart';
import '../routes/ridership_service.dart';
import 'transport_alert_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final _alertService = TransportAlertService();
  final _ridershipService = RidershipService();
  late Future<List<TransportAlert>> _alertsFuture;
  late Future<RidershipSnapshot> _analysisFuture;
  int _section = 0;
  String _filter = 'All';
  TransportAlert? _selectedAlert;

  @override
  void initState() {
    super.initState();
    _alertsFuture = _alertService.fetchAlerts();
    _analysisFuture = _ridershipService.fetchLatestSnapshot();
  }

  Future<void> _refreshAlerts() async {
    setState(() => _alertsFuture = _alertService.fetchAlerts());
    await _alertsFuture;
  }

  Future<void> _refreshAnalysis() async {
    setState(() => _analysisFuture = _ridershipService.fetchLatestSnapshot());
    await _analysisFuture;
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedAlert != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Alert Details'),
          leading: BackButton(onPressed: () => setState(() => _selectedAlert = null)),
        ),
        body: _AlertDetails(alert: _selectedAlert!),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transport Updates'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _section == 0 ? _refreshAlerts : _refreshAnalysis,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('Alerts'),
                  icon: Icon(Icons.notifications_active_outlined),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('Analysis'),
                  icon: Icon(Icons.insights_rounded),
                ),
              ],
              selected: {_section},
              onSelectionChanged: (value) => setState(() => _section = value.first),
            ),
          ),
          Expanded(
            child: _section == 0
                ? _AlertsView(
                    future: _alertsFuture,
                    filter: _filter,
                    onFilterChanged: (value) => setState(() => _filter = value),
                    onOpenAlert: (alert) => setState(() => _selectedAlert = alert),
                    onRefresh: _refreshAlerts,
                  )
                : _TransportAnalysisView(
                    future: _analysisFuture,
                    onRefresh: _refreshAnalysis,
                  ),
          ),
        ],
      ),
    );
  }
}

class _AlertsView extends StatelessWidget {
  const _AlertsView({
    required this.future,
    required this.filter,
    required this.onFilterChanged,
    required this.onOpenAlert,
    required this.onRefresh,
  });

  final Future<List<TransportAlert>> future;
  final String filter;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<TransportAlert> onOpenAlert;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final personalisation = PersonalisationService.instance;
    return AnimatedBuilder(
      animation: personalisation,
      builder: (context, _) {
        return FutureBuilder<List<TransportAlert>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorState(
                title: 'Unable to load service alerts',
                error: snapshot.error,
                onRetry: onRefresh,
              );
            }
            final alerts = snapshot.data ?? const <TransportAlert>[];
            final filtered = alerts.where((alert) {
              return filter == 'All' || alert.mode == filter || alert.mode == 'All';
            }).toList();
            return RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (!personalisation.notificationsEnabled)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 14),
                      child: AppCard(
                        color: Color(0xFFFFF7ED),
                        child: Row(
                          children: [
                            Icon(Icons.notifications_off_outlined, color: AppColors.warning),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text('Notifications are disabled in your profile settings.'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['All', 'MRT', 'LRT', 'Bus', 'KTM']
                        .map(
                          (item) => ChoiceChip(
                            label: Text(item),
                            selected: item == filter,
                            onSelected: (_) => onFilterChanged(item),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(child: SectionTitle('Service Alerts')),
                      StatusChip('${filtered.length} shown', color: AppColors.primary),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (filtered.isEmpty)
                    const AppCard(
                      child: Text('No service alerts match this filter.', textAlign: TextAlign.center),
                    )
                  else
                    ...filtered.map(
                      (alert) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppCard(
                          padding: EdgeInsets.zero,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: _alertColor(alert.type).withValues(alpha: .12),
                              child: Icon(_alertIcon(alert.type), color: _alertColor(alert.type)),
                            ),
                            title: Text(alert.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                            subtitle: Text('${alert.mode} • ${alert.operatorName}\n${_displayTime(alert.createdAt)}'),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => onOpenAlert(alert),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TransportAnalysisView extends StatelessWidget {
  const _TransportAnalysisView({required this.future, required this.onRefresh});

  final Future<RidershipSnapshot> future;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RidershipSnapshot>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorState(
            title: 'Unable to analyse government transport data',
            error: snapshot.error,
            onRetry: onRefresh,
          );
        }
        final data = snapshot.requireData;
        final busiest = data.busiestService;
        final topServices = data.services.take(5).toList();
        final maxTrips = topServices.isEmpty ? 1 : topServices.first.trips;
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SectionTitle('Government API Analysis'),
              const SizedBox(height: 10),
              AppCard(
                color: const Color(0xFFEFF6FF),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Highest Ridership Service', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(busiest.name, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text('${_formatNumber(busiest.trips)} trips on ${_date(data.date)}'),
                    const SizedBox(height: 10),
                    StatusChip(busiest.mode, color: AppColors.primary),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Row(
                  children: [
                    const Icon(Icons.compare_arrows_rounded, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Daily Activity Change', style: TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text(data.activityTrend),
                          Text(
                            '${data.changePercent >= 0 ? '+' : ''}${data.changePercent.toStringAsFixed(1)}% compared with the previous API record',
                            style: const TextStyle(color: AppColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const SectionTitle('Busiest Services'),
              const SizedBox(height: 10),
              AppCard(
                child: Column(
                  children: topServices
                      .map(
                        (service) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _ServiceActivityBar(service: service, maximum: maxTrips),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 18),
              AppCard(
                color: const Color(0xFFFFFBEB),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.warning),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This API provides daily ridership, not hourly passenger counts. The app does not invent peak-hour values. Route and timetable features use Government GTFS data separately.',
                        style: TextStyle(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Source: Malaysia Government OpenAPI, data.gov.my ridership_headline. Analysis is calculated from API responses inside GoTransit MY.',
                style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ServiceActivityBar extends StatelessWidget {
  const _ServiceActivityBar({required this.service, required this.maximum});

  final ServiceRidership service;
  final int maximum;

  @override
  Widget build(BuildContext context) {
    final fraction = (service.trips / maximum).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(service.name, style: const TextStyle(fontWeight: FontWeight.w800))),
            Text(_formatNumber(service.trips)),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            minHeight: 10,
            value: fraction,
            backgroundColor: AppColors.primary.withValues(alpha: .12),
          ),
        ),
      ],
    );
  }
}

class _AlertDetails extends StatelessWidget {
  const _AlertDetails({required this.alert});

  final TransportAlert alert;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: StatusChip(alert.type, color: _alertColor(alert.type)),
        ),
        const SizedBox(height: 16),
        Text(alert.title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(_displayTime(alert.createdAt), style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 20),
        AppCard(child: Text(alert.message, style: const TextStyle(height: 1.5))),
        const SizedBox(height: 14),
        AppCard(
          color: const Color(0xFFF8FAFC),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailLine(label: 'Transport', value: alert.mode),
              _DetailLine(label: 'Operator', value: alert.operatorName),
              _DetailLine(label: 'Status', value: alert.status),
              _DetailLine(label: 'Source', value: alert.source),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w800))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.title, required this.error, required this.onRetry});

  final String title;
  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        AppCard(
          color: const Color(0xFFFFF1F2),
          child: Column(
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.danger),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18), textAlign: TextAlign.center),
              const SizedBox(height: 7),
              Text('$error', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Color _alertColor(String type) {
  final value = type.toLowerCase();
  if (value.contains('delay') || value.contains('cancel') || value.contains('disrupt')) {
    return AppColors.danger;
  }
  if (value.contains('maintenance') || value.contains('warning') || value.contains('change')) {
    return AppColors.warning;
  }
  return AppColors.primary;
}

IconData _alertIcon(String type) {
  final value = type.toLowerCase();
  if (value.contains('maintenance')) return Icons.build_outlined;
  if (value.contains('delay') || value.contains('disrupt')) return Icons.warning_amber_rounded;
  return Icons.info_outline_rounded;
}

String _displayTime(DateTime? value) {
  if (value == null) return 'Time unavailable';
  final now = DateTime.now();
  final difference = now.difference(value);
  if (!difference.isNegative && difference.inMinutes < 1) return 'Just now';
  if (!difference.isNegative && difference.inMinutes < 60) return '${difference.inMinutes} min ago';
  if (!difference.isNegative && difference.inHours < 24) return '${difference.inHours} hr ago';
  return '${value.day}/${value.month}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

String _formatNumber(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final remaining = text.length - i;
    buffer.write(text[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}

String _date(DateTime value) => '${value.day}/${value.month}/${value.year}';
