class GtfsStop {
  const GtfsStop({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.code,
    this.locationType,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? code;
  final int? locationType;
}

class LiveVehicle {
  const LiveVehicle({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.routeId,
    this.tripId,
    this.label,
    this.timestamp,
  });

  final String id;
  final double latitude;
  final double longitude;
  final String? routeId;
  final String? tripId;
  final String? label;
  final DateTime? timestamp;
}

enum TransportAgency {
  ktmb,
  prasaranaRail,
  prasaranaBusKl,
  prasaranaMrtFeeder,
  mybasKangar,
  mybasAlorSetar,
  mybasKotaBharu,
  mybasKualaTerengganu,
  mybasIpoh,
  mybasSerembanA,
  mybasSerembanB,
  mybasMelaka,
  mybasJohor,
  mybasKuching,
}

extension TransportAgencyX on TransportAgency {
  String get label => switch (this) {
        TransportAgency.ktmb => 'KTMB',
        TransportAgency.prasaranaRail => 'Rapid Rail KL',
        TransportAgency.prasaranaBusKl => 'Rapid Bus KL',
        TransportAgency.prasaranaMrtFeeder => 'MRT Feeder Bus',
        TransportAgency.mybasKangar => 'BAS.MY Kangar',
        TransportAgency.mybasAlorSetar => 'BAS.MY Alor Setar',
        TransportAgency.mybasKotaBharu => 'BAS.MY Kota Bharu',
        TransportAgency.mybasKualaTerengganu => 'BAS.MY Kuala Terengganu',
        TransportAgency.mybasIpoh => 'BAS.MY Ipoh',
        TransportAgency.mybasSerembanA => 'BAS.MY Seremban A',
        TransportAgency.mybasSerembanB => 'BAS.MY Seremban B',
        TransportAgency.mybasMelaka => 'BAS.MY Melaka',
        TransportAgency.mybasJohor => 'BAS.MY Johor Bahru',
        TransportAgency.mybasKuching => 'BAS.MY Kuching',
      };
}
