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
        message: 'Walking connection only. No public transport fare is required.',
        options: [],
        fare: 0,
        sourceLabel: 'Walking route',
      );
    }

    if (paidLegs.length == 1) {
      final leg = paidLegs.first;
      final record = await _lookupFare(
        mode: leg.mode,
        from: leg.from,
        to: leg.to,
      );
      if (record != null) return _fareInfoForRecord(record, leg.mode);
    }

    final direct = await _lookupDirect(result);
    if (direct != null) return direct;

    var total = 0.0;
    final sources = <String>{};
    final options = <FareLookupOption>[];

    for (final leg in paidLegs) {
      final record = await _lookupFare(
        mode: leg.mode,
        from: leg.from,
        to: leg.to,
      );
      if (record == null) return getFareInfo(result);
      total += record.fare;
      sources.add(record.sourceLabel);
      final option = _optionForMode(leg.mode);
      if (option != null && !options.any((item) => item.label == option.label)) {
        options.add(option);
      }
    }

    return FareEstimateInfo(
      title: 'RM ${total.toStringAsFixed(2)}',
      message: 'Estimated adult cash fare from stored static fare references for the route sections used.',
      options: options,
      fare: total,
      sourceLabel: sources.join(' + '),
    );
  }

  FareEstimateInfo _fareInfoForRecord(_FareRecord record, String mode) {
    final option = _optionForMode(mode);
    return FareEstimateInfo(
      title: 'RM ${record.fare.toStringAsFixed(2)}',
      message: record.isStatic
          ? 'Adult cash fare from the project static fare reference sourced from the published operator fare table.'
          : 'Adult cash fare from the stored fare reference for this journey.',
      options: option == null ? const [] : [option],
      fare: record.fare,
      sourceLabel: record.sourceLabel,
    );
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
    return _fareInfoForRecord(record, mode);
  }

  Future<_FareRecord?> _lookupFare({
    required String mode,
    required String from,
    required String to,
  }) async {
    try {
      final data = await _client
          .from('fare_reference')
          .select('operator, adult_fare, source_url, source_date')
          .eq('transport_mode', mode)
          .eq('origin_station', from)
          .eq('destination_station', to)
          .eq('fare_type', 'adult_cash')
          .maybeSingle();

      if (data != null) {
        final value = data['adult_fare'];
        final fare = value is num ? value.toDouble() : double.tryParse('$value');
        if (fare != null) {
          final operator = '${data['operator']}';
          final sourceDate = data['source_date'];
          return _FareRecord(
            fare: fare,
            sourceLabel: sourceDate == null
                ? '$operator stored fare reference'
                : '$operator fare table • $sourceDate',
          );
        }
      }
    } catch (_) {}

    return _staticFares['$mode|$from|$to'];
  }

  FareEstimateInfo getFareInfo(RouteSearchResult result) {
    final modes = result.modes.toSet();
    final usesRapidRail = modes.contains('MRT') || modes.contains('LRT');
    final usesKtm = modes.contains('KTM');

    if (modes.isEmpty) {
      return const FareEstimateInfo(
        title: 'RM 0.00',
        message: 'Walking connection only. No public transport fare is required.',
        options: [],
        fare: 0,
        sourceLabel: 'Walking route',
      );
    }

    if (usesRapidRail && usesKtm) {
      return FareEstimateInfo(
        title: 'Fare not covered',
        message: 'The current static fare references do not cover every Rapid KL and KTM section in this mixed journey.',
        options: [_rapidRail, _ktmKomuter],
      );
    }

    if (usesRapidRail) {
      return FareEstimateInfo(
        title: 'Fare not covered',
        message: 'This MRT or LRT station pair is not yet included in the project static fare reference.',
        options: [_rapidRail],
      );
    }

    if (usesKtm) {
      return FareEstimateInfo(
        title: 'Fare not covered',
        message: 'This KTM station pair is not yet included in the project static fare reference.',
        options: [_ktmKomuter],
      );
    }

    return const FareEstimateInfo(
      title: 'Fare not covered',
      message: 'A verified fare reference is not connected for this journey.',
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
  const _FareRecord({
    required this.fare,
    required this.sourceLabel,
    this.isStatic = false,
  });

  final double fare;
  final String sourceLabel;
  final bool isStatic;
}

const _rapidStaticSource = 'Rapid KL static fare table • 2021-05-06';
const _ktmStaticSource = 'KTMB static fare reference';

const _staticFares = <String, _FareRecord>{
  'MRT|Muzium Negara|Bukit Bintang': _FareRecord(fare: 1.80, sourceLabel: _rapidStaticSource, isStatic: true),
  'MRT|Bukit Bintang|Muzium Negara': _FareRecord(fare: 1.80, sourceLabel: _rapidStaticSource, isStatic: true),
  'MRT|Pasar Seni|Bukit Bintang': _FareRecord(fare: 1.40, sourceLabel: _rapidStaticSource, isStatic: true),
  'MRT|Bukit Bintang|Pasar Seni': _FareRecord(fare: 1.40, sourceLabel: _rapidStaticSource, isStatic: true),
  'MRT|Pasar Seni|Kajang': _FareRecord(fare: 3.60, sourceLabel: _rapidStaticSource, isStatic: true),
  'MRT|Kajang|Pasar Seni': _FareRecord(fare: 3.60, sourceLabel: _rapidStaticSource, isStatic: true),
  'MRT|Bukit Bintang|Kajang': _FareRecord(fare: 3.20, sourceLabel: _rapidStaticSource, isStatic: true),
  'MRT|Kajang|Bukit Bintang': _FareRecord(fare: 3.20, sourceLabel: _rapidStaticSource, isStatic: true),
  'LRT|KL Sentral|Pasar Seni': _FareRecord(fare: 1.30, sourceLabel: _rapidStaticSource, isStatic: true),
  'LRT|Pasar Seni|KL Sentral': _FareRecord(fare: 1.30, sourceLabel: _rapidStaticSource, isStatic: true),
  'LRT|KL Sentral|Masjid Jamek': _FareRecord(fare: 1.60, sourceLabel: _rapidStaticSource, isStatic: true),
  'LRT|Masjid Jamek|KL Sentral': _FareRecord(fare: 1.60, sourceLabel: _rapidStaticSource, isStatic: true),
  'LRT|KL Sentral|Dang Wangi': _FareRecord(fare: 2.00, sourceLabel: _rapidStaticSource, isStatic: true),
  'LRT|Dang Wangi|KL Sentral': _FareRecord(fare: 2.00, sourceLabel: _rapidStaticSource, isStatic: true),
  'LRT|KL Sentral|KLCC': _FareRecord(fare: 2.40, sourceLabel: _rapidStaticSource, isStatic: true),
  'LRT|KLCC|KL Sentral': _FareRecord(fare: 2.40, sourceLabel: _rapidStaticSource, isStatic: true),
  'LRT|KL Sentral|Ampang Park': _FareRecord(fare: 2.60, sourceLabel: _rapidStaticSource, isStatic: true),
  'LRT|Ampang Park|KL Sentral': _FareRecord(fare: 2.60, sourceLabel: _rapidStaticSource, isStatic: true),
  'LRT|KL Sentral|Bangsar': _FareRecord(fare: 1.20, sourceLabel: _rapidStaticSource, isStatic: true),
  'LRT|Bangsar|KL Sentral': _FareRecord(fare: 1.20, sourceLabel: _rapidStaticSource, isStatic: true),
  'LRT|KL Sentral|Abdullah Hukum': _FareRecord(fare: 1.50, sourceLabel: _rapidStaticSource, isStatic: true),
  'LRT|Abdullah Hukum|KL Sentral': _FareRecord(fare: 1.50, sourceLabel: _rapidStaticSource, isStatic: true),
  'LRT|KL Sentral|Universiti': _FareRecord(fare: 2.00, sourceLabel: _rapidStaticSource, isStatic: true),
  'LRT|Universiti|KL Sentral': _FareRecord(fare: 2.00, sourceLabel: _rapidStaticSource, isStatic: true),
  'LRT|KL Sentral|Taman Jaya': _FareRecord(fare: 2.20, sourceLabel: _rapidStaticSource, isStatic: true),
  'LRT|Taman Jaya|KL Sentral': _FareRecord(fare: 2.20, sourceLabel: _rapidStaticSource, isStatic: true),
  'LRT|KL Sentral|Subang Jaya': _FareRecord(fare: 3.60, sourceLabel: _rapidStaticSource, isStatic: true),
  'LRT|Subang Jaya|KL Sentral': _FareRecord(fare: 3.60, sourceLabel: _rapidStaticSource, isStatic: true),
  'KTM|KL Sentral|Mid Valley': _FareRecord(fare: 1.60, sourceLabel: _ktmStaticSource, isStatic: true),
  'KTM|Mid Valley|KL Sentral': _FareRecord(fare: 1.60, sourceLabel: _ktmStaticSource, isStatic: true),
  'KTM|KL Sentral|Bandar Tasik Selatan': _FareRecord(fare: 2.40, sourceLabel: _ktmStaticSource, isStatic: true),
  'KTM|Bandar Tasik Selatan|KL Sentral': _FareRecord(fare: 2.40, sourceLabel: _ktmStaticSource, isStatic: true),
  'KTM|KL Sentral|Serdang': _FareRecord(fare: 2.90, sourceLabel: _ktmStaticSource, isStatic: true),
  'KTM|Serdang|KL Sentral': _FareRecord(fare: 2.90, sourceLabel: _ktmStaticSource, isStatic: true),
  'KTM|KL Sentral|Kajang': _FareRecord(fare: 4.20, sourceLabel: _ktmStaticSource, isStatic: true),
  'KTM|Kajang|KL Sentral': _FareRecord(fare: 4.20, sourceLabel: _ktmStaticSource, isStatic: true),
  'KTM|KL Sentral|Batu Caves': _FareRecord(fare: 2.60, sourceLabel: _ktmStaticSource, isStatic: true),
  'KTM|Batu Caves|KL Sentral': _FareRecord(fare: 2.60, sourceLabel: _ktmStaticSource, isStatic: true),
};
