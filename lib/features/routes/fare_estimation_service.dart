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
  });

  final String title;
  final String message;
  final List<FareLookupOption> options;
}

class FareEstimationService {
  const FareEstimationService();

  FareEstimateInfo getFareInfo(RouteSearchResult result) {
    final modes = result.modes.toSet();
    final usesRapidRail = modes.contains('MRT') || modes.contains('LRT');
    final usesKtm = modes.contains('KTM');

    if (usesRapidRail && usesKtm) {
      return FareEstimateInfo(
        title: 'Check fares by operator',
        message: 'This route combines Rapid KL rail and KTM Komuter. Check each operator fare before travelling because the total depends on the selected ticket or payment method.',
        options: [_rapidRail, _ktmKomuter],
      );
    }

    if (usesRapidRail) {
      return FareEstimateInfo(
        title: 'Rapid KL rail fare',
        message: 'Use the official MyRapid Rail Fare Calculator for MRT and LRT fares. It supports cash or token, Touch n Go and concession fare checks.',
        options: [_rapidRail],
      );
    }

    if (usesKtm) {
      return FareEstimateInfo(
        title: 'KTM Komuter fare',
        message: 'Use the official KTMB ticketing system to check the current Komuter fare for the selected origin and destination.',
        options: [_ktmKomuter],
      );
    }

    return const FareEstimateInfo(
      title: 'Fare unavailable',
      message: 'A verified fare source is not connected for this route yet.',
      options: [],
    );
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
