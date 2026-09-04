class RidershipPoint {
  const RidershipPoint({required this.date, required this.values});
  final DateTime date;
  final Map<String, int> values;
  int get total => values.values.fold(0, (sum, value) => sum + value);
}

class FlowPair {
  const FlowPair({required this.origin, required this.destination, required this.ridership});
  final String origin;
  final String destination;
  final int ridership;
}

class StationRidership {
  const StationRidership({required this.station, required this.departures, required this.arrivals});
  final String station;
  final int departures;
  final int arrivals;
  int get activity => departures + arrivals;
}

class KomuterAnalytics {
  const KomuterAnalytics({required this.latestDate, required this.latestDayTotal, required this.hourlyTotals, required this.topFlows, required this.stationActivity, required this.destinationsByOrigin, required this.weekdayHourTotals});
  final DateTime latestDate;
  final int latestDayTotal;
  final List<int> hourlyTotals;
  final List<FlowPair> topFlows;
  final List<StationRidership> stationActivity;
  final Map<String, List<FlowPair>> destinationsByOrigin;
  final List<List<int>> weekdayHourTotals;
}
