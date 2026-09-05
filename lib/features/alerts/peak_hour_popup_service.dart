import 'package:shared_preferences/shared_preferences.dart';

class CrowdedStationPrediction {
  const CrowdedStationPrediction({
    required this.station,
    required this.crowdPercent,
    required this.reason,
  });

  final String station;
  final int crowdPercent;
  final String reason;
}

class PeakHourPopupAlert {
  const PeakHourPopupAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.peakWindow,
    required this.sourceLabel,
    required this.stations,
    required this.advice,
  });

  final String id;
  final String title;
  final String message;
  final String peakWindow;
  final String sourceLabel;
  final List<CrowdedStationPrediction> stations;
  final String advice;

  int get highestCrowdPercent {
    if (stations.isEmpty) return 0;
    return stations
        .map((station) => station.crowdPercent)
        .reduce((a, b) => a > b ? a : b);
  }
}

class PeakHourPopupService {
  PeakHourPopupService._();

  static final PeakHourPopupService instance = PeakHourPopupService._();

  static const _shownKeyPrefix = 'peak_hour_popup_shown';

  Future<PeakHourPopupAlert?> alertToShowNow() async {
    final now = DateTime.now();
    final alert = _matchCurrentTime(now);

    if (alert == null) return null;

    final preferences = await SharedPreferences.getInstance();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final storageKey = '$_shownKeyPrefix.$todayKey.${alert.id}';

    final alreadyShown = preferences.getBool(storageKey) ?? false;
    if (alreadyShown) return null;

    await preferences.setBool(storageKey, true);
    return alert;
  }

  PeakHourPopupAlert demoAlert() {
    return _rules.first.toAlert();
  }

  Future<void> resetTodayForTesting() async {
    final now = DateTime.now();
    final preferences = await SharedPreferences.getInstance();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    for (final rule in _rules) {
      await preferences.remove('$_shownKeyPrefix.$todayKey.${rule.id}');
    }
  }

  PeakHourPopupAlert? _matchCurrentTime(DateTime now) {
    final minutes = now.hour * 60 + now.minute;

    for (final rule in _rules) {
      final start = rule.alertStartHour * 60;
      final end = rule.alertEndHour * 60;

      if (minutes >= start && minutes < end) {
        return rule.toAlert();
      }
    }

    return null;
  }
}

class _PeakHourRule {
  const _PeakHourRule({
    required this.id,
    required this.alertStartHour,
    required this.alertEndHour,
    required this.title,
    required this.message,
    required this.peakWindow,
    required this.sourceLabel,
    required this.stations,
    required this.advice,
  });

  final String id;
  final int alertStartHour;
  final int alertEndHour;
  final String title;
  final String message;
  final String peakWindow;
  final String sourceLabel;
  final List<CrowdedStationPrediction> stations;
  final String advice;

  PeakHourPopupAlert toAlert() {
    return PeakHourPopupAlert(
      id: id,
      title: title,
      message: message,
      peakWindow: peakWindow,
      sourceLabel: sourceLabel,
      stations: stations,
      advice: advice,
    );
  }
}

const _rules = <_PeakHourRule>[
  _PeakHourRule(
    id: 'midday_peak_12_2',
    alertStartHour: 11,
    alertEndHour: 14,
    title: 'Midday peak hour expected',
    peakWindow: '12:00 PM - 2:00 PM',
    sourceLabel: 'Historical ridership and station demand estimate',
    message:
        'Passenger demand is expected to increase soon. The 12:00 PM to 2:00 PM window is marked as a high-crowd period in the app analytics model.',
    advice:
        'Start earlier, allow extra waiting time, or avoid transfers at the busiest stations if possible.',
    stations: <CrowdedStationPrediction>[
      CrowdedStationPrediction(
        station: 'KL Sentral',
        crowdPercent: 92,
        reason: 'Major interchange for KTM, LRT, MRT connection and airport rail.',
      ),
      CrowdedStationPrediction(
        station: 'Pasar Seni',
        crowdPercent: 86,
        reason: 'Common transfer point between MRT, LRT and city bus routes.',
      ),
      CrowdedStationPrediction(
        station: 'Bukit Bintang',
        crowdPercent: 81,
        reason: 'High shopping and city-centre passenger flow during midday.',
      ),
    ],
  ),
  _PeakHourRule(
    id: 'morning_peak_8_9',
    alertStartHour: 7,
    alertEndHour: 9,
    title: 'Morning peak hour expected',
    peakWindow: '8:00 AM - 9:00 AM',
    sourceLabel: 'Historical morning commute pattern estimate',
    message:
        'Morning commuter demand is expected to be higher soon, especially around interchange stations.',
    advice:
        'Plan extra time before work or class and check nearby station options.',
    stations: <CrowdedStationPrediction>[
      CrowdedStationPrediction(
        station: 'KL Sentral',
        crowdPercent: 90,
        reason: 'Morning interchange and central business district access.',
      ),
      CrowdedStationPrediction(
        station: 'Masjid Jamek',
        crowdPercent: 83,
        reason: 'LRT interchange station with high commuter transfer demand.',
      ),
      CrowdedStationPrediction(
        station: 'Bandar Tasik Selatan',
        crowdPercent: 78,
        reason: 'Integrated terminal and KTM/LRT interchange movement.',
      ),
    ],
  ),
  _PeakHourRule(
    id: 'evening_peak_5_7',
    alertStartHour: 16,
    alertEndHour: 19,
    title: 'Evening peak hour expected',
    peakWindow: '5:00 PM - 7:00 PM',
    sourceLabel: 'Historical evening commute pattern estimate',
    message:
        'Evening transport demand is expected to rise as commuters return from work and school.',
    advice:
        'Leave slightly earlier or choose a less crowded interchange where possible.',
    stations: <CrowdedStationPrediction>[
      CrowdedStationPrediction(
        station: 'KL Sentral',
        crowdPercent: 94,
        reason: 'Evening transfer demand across rail and bus services.',
      ),
      CrowdedStationPrediction(
        station: 'Ampang Park',
        crowdPercent: 82,
        reason: 'City-centre work trip demand near offices.',
      ),
      CrowdedStationPrediction(
        station: 'Kajang',
        crowdPercent: 76,
        reason: 'Outbound commuter flow after office hours.',
      ),
    ],
  ),
];
