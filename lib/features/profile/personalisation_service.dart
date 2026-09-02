import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../alerts/background_alert_service.dart';

class PersonalisationService extends ChangeNotifier {
  PersonalisationService._();

  static final PersonalisationService instance = PersonalisationService._();

  static const _darkModeKey = 'module1_dark_mode';
  static const _notificationsKey = 'module1_notifications';
  static const _languageKey = 'module1_language';
  static const _preferredTransportKey = 'module1_preferred_transport';
  static const _favouriteStationsKey = 'module1_favourite_stations';
  static const _favouriteRoutesKey = 'module1_favourite_routes';
  static const _recentSearchesKey = 'module1_recent_searches';

  late SharedPreferences _preferences;
  bool _initialised = false;
  bool _darkMode = false;
  bool _notificationsEnabled = true;
  String _language = 'English';
  String _preferredTransport = 'All';
  List<String> _favouriteStations = <String>[];
  List<String> _favouriteRoutes = <String>[];
  List<String> _recentSearches = <String>[];

  bool get darkMode => _darkMode;
  bool get notificationsEnabled => _notificationsEnabled;
  String get language => _language;
  String get preferredTransport => _preferredTransport;
  List<String> get favouriteStations => List.unmodifiable(_favouriteStations);
  List<String> get favouriteRoutes => List.unmodifiable(_favouriteRoutes);
  List<String> get recentSearches => List.unmodifiable(_recentSearches);

  Future<void> initialise() async {
    if (_initialised) return;
    _preferences = await SharedPreferences.getInstance();
    _darkMode = _preferences.getBool(_darkModeKey) ?? false;
    _notificationsEnabled = _preferences.getBool(_notificationsKey) ?? true;
    _language = _preferences.getString(_languageKey) ?? 'English';
    _preferredTransport =
        _preferences.getString(_preferredTransportKey) ?? 'All';
    _favouriteStations =
        _preferences.getStringList(_favouriteStationsKey) ?? <String>[];
    _favouriteRoutes =
        _preferences.getStringList(_favouriteRoutesKey) ?? <String>[];
    _recentSearches =
        _preferences.getStringList(_recentSearchesKey) ?? <String>[];
    _initialised = true;
  }

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    notifyListeners();
    await _preferences.setBool(_darkModeKey, value);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    notifyListeners();
    await _preferences.setBool(_notificationsKey, value);
    await BackgroundAlertService.instance.setEnabled(value);
  }

  Future<void> setLanguage(String value) async {
    _language = value;
    notifyListeners();
    await _preferences.setString(_languageKey, value);
  }

  Future<void> setPreferredTransport(String value) async {
    _preferredTransport = value;
    notifyListeners();
    await _preferences.setString(_preferredTransportKey, value);
  }

  bool isFavouriteStation(String stationName) =>
      _favouriteStations.contains(stationName);

  Future<void> toggleFavouriteStation(String stationName) async {
    if (_favouriteStations.contains(stationName)) {
      _favouriteStations.remove(stationName);
    } else {
      _favouriteStations.insert(0, stationName);
    }
    notifyListeners();
    await _preferences.setStringList(
      _favouriteStationsKey,
      _favouriteStations,
    );
  }

  Future<void> addFavouriteStation(String stationName) async {
    final clean = stationName.trim();
    if (clean.isEmpty || _favouriteStations.contains(clean)) return;
    _favouriteStations.insert(0, clean);
    notifyListeners();
    await _preferences.setStringList(
      _favouriteStationsKey,
      _favouriteStations,
    );
  }

  Future<void> removeFavouriteStation(String stationName) async {
    _favouriteStations.remove(stationName);
    notifyListeners();
    await _preferences.setStringList(
      _favouriteStationsKey,
      _favouriteStations,
    );
  }

  Future<void> addFavouriteRoute(String route) async {
    final clean = route.trim();
    if (clean.isEmpty) return;
    _favouriteRoutes.remove(clean);
    _favouriteRoutes.insert(0, clean);
    notifyListeners();
    await _preferences.setStringList(
      _favouriteRoutesKey,
      _favouriteRoutes,
    );
  }

  Future<void> removeFavouriteRoute(String route) async {
    _favouriteRoutes.remove(route);
    notifyListeners();
    await _preferences.setStringList(
      _favouriteRoutesKey,
      _favouriteRoutes,
    );
  }

  Future<void> addRecentSearch(String search) async {
    final clean = search.trim();
    if (clean.isEmpty) return;
    _recentSearches.remove(clean);
    _recentSearches.insert(0, clean);
    if (_recentSearches.length > 10) {
      _recentSearches = _recentSearches.take(10).toList();
    }
    notifyListeners();
    await _preferences.setStringList(
      _recentSearchesKey,
      _recentSearches,
    );
  }

  Future<void> clearRecentSearches() async {
    _recentSearches.clear();
    notifyListeners();
    await _preferences.remove(_recentSearchesKey);
  }
}
