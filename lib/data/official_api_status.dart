class OfficialApiStatus {
  const OfficialApiStatus._();

  static const bool gtfsStaticAvailable = true;
  static const bool realtimeVehiclePositionsAvailable = true;
  static const bool realtimeTripUpdatesAvailable = false;
  static const bool realtimeServiceAlertsAvailable = false;

  static const String realtimeNotice =
      'Malaysia official GTFS Realtime currently provides vehicle positions. '
      'Trip updates and service alerts are not yet available from the official feed.';
}
