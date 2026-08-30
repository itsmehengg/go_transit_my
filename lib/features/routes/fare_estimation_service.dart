import 'package:supabase_flutter/supabase_flutter.dart';

import 'route_search_service.dart';

class FareLookupOption {
  const FareLookupOption({required this.label, required this.url});

  final String label;
  final Uri url;
}

class FareEstimateInfo {
  const FareEstimateInfo({
    required this.title,
    required this.message,
    required this.options,
    this.fare,
    this.sourceLabel,
  });

  final String title;
  final String message;
  final List<FareLookupOption> options;
  final double? fare;
  final String? sourceLabel;

  bool get hasFare => fare != null;

  String get formattedFare => fare == null ? '' : 'RM ${fare!.toStringAsFixed(2)}';
}

class FareEstimationService {
  FareEstimationService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<FareEstimateInfo> getStoredFareInfo(RouteSearchResult result) async {
    final paidLegs = result.groupedLegs.where((leg) => leg.mode != 'Walk').toList();

    if (paidLegs.isEmpty) {
      return const FareEstimateInfo(
        title: 'RM 0.00',
        message: 'Walking connection only. No public transport fare is required for this route.',
        options: [],
        fare: 0,
        sourceLabel: 'Walking route',
      );
    }

    final direct = await _lookupDirect(result);
    if (direct != null) return direct;

    var total = 0.0;
    var foundEveryLeg = true;
    final sources = <String>{};
    final options = <FareLookupOption>[];

    for (final leg in paidLegs) {
      final record = await _lookupFare(
        mode: leg.mode,
        from: leg.from,
        to: leg.to,
      );
      if (record == null) {
        foundEveryLeg = false;
        break;
      }
      total += record.fare;
      sources.add(record.operator);
      final option = _optionForMode(leg.mode);
      if (option != null && !options.any((item) => item.label == option.label)) {
        options.add(option);
      }
    }

    if (foundEveryLeg) {
      return FareEstimateInfo(
        title: 'RM ${total.toStringAsFixed(2)}',
        message: 'Estimated adult cash fare based on stored reference fares for the route sections used.',
        options: options,
        fare: total,
        sourceLabel: sources.join(' + '),
      );
    }

    return getFareInfo(result);
  }

  Future<FareEstimateInfo?> _lookupDirect(RouteSearchResult result) async {
    final modes = result.modes;
    if (modes.length != 1) return null;

    final mode = modes.first;
    final record = await _lookupFare(
      mode: mode,
      from: result.from.name,
      to: result.to.name,
    );
    if (record == null) return null;

    final option = _optionForMode(mode);
    return FareEstimateInfo(
      title: 'RM ${record.fare.toStringAsFixed(2)}',
      message: 'Estimated adult cash fare from the stored fare reference for this journey.',
      options: option == null ? const [] : [option],
      fare: record.fare,
      sourceLabel: record.operator,
    );
  }

  Future<_FareRecord?> _lookupFare({
    required String mode,
    required String from,
    required String to,
  }) async {
    try {
      final data = await _client
          .from('fare_reference')
          .select('operator, adult_fare, source_url')
          .eq('transport_mode', mode)
          .eq('origin_station', from)
          .eq('destination_station', to)
          .eq('fare_type', 'adult_cash')
          .maybeSingle();

      if (data == null) return null;
      final value = data['adult_fare'];
      final fare = value is num ? value.toDouble() : double.tryParse('$value');
      if (fare == null) return null;

      return _FareRecord(
        operator: '${data['operator']}',
        fare: fare,
      );
    } catch (_) {
      return null;
    }
  }

  FareEstimateInfo getFareInfo(RouteSearchResult result) {
    final modes = result.modes.toSet();
    final usesRapidRail = modes.contains('MRT') || modes.contains('LRT');
    final usesKtm = modes.contains('KTM');

    if (modes.isEmpty) {
      return const FareEstimateInfo(
        title: 'RM 0.00',
        message: 'Walking connection only. No public transport fare is required for this route.',
        options: [],
        fare: 0,
        sourceLabel: 'Walking route',
      );
    }

    if (usesRapidRail && usesKtm) {
      return FareEstimateInfo(
        title: 'Fare reference not available',
        message: 'This route combines Rapid KL rail and KTM Komuter. One or more route sections do not have a stored fare record yet.',
        options: [_rapidRail, _ktmKomuter],
      );
    }

    if (usesRapidRail) {
      return FareEstimateInfo(
        title: 'Fare reference not available',
        message: 'A stored fare for this MRT or LRT journey is not available yet. Check the official MyRapid fare source for the current price.',
        options: [_rapidRail],
      );
    }

    if (usesKtm) {
      return FareEstimateInfo(
        title: 'Fare reference not available',
        message: 'A stored fare for this KTM Komuter journey is not available yet. Check the official KTMB fare source for the current price.',
        options: [_ktmKomuter],
      );
    }

    return const FareEstimateInfo(
      title: 'Fare unavailable',
      message: 'A verified fare source is not connected for this route yet.',
      options: [],
    );
  }

  FareLookupOption? _optionForMode(String mode) {
    if (mode == 'MRT' || mode == 'LRT') return _rapidRail;
    if (mode == 'KTM') return _ktmKomuter;
    return null;
  }

  FareLookupOption get _rapidRail => FareLookupOption(
        label: 'Open MyRapid Fare Calculator',
        url: Uri.parse('https://myrapid.com.my/bus-train/rapid-kl/integrated-fare-table/'),
      );

  FareLookupOption get _ktmKomuter => FareLookupOption(
        label: 'Open KTMB Fare Search',
        url: Uri.parse('https://online.ktmb.com.my/'),
      );
}

class _FareRecord {
  const _FareRecord({required this.operator, required this.fare});

  final String operator;
  final double fare;
}
