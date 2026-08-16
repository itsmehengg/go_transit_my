import 'package:shared_preferences/shared_preferences.dart';

class UserPreferences {
  static const _favouriteStopsKey = 'favourite_stop_ids';
  static const _recentSearchesKey = 'recent_searches';
  static const _darkModeKey = 'dark_mode';
  static const _languageKey = 'language';

  Future<Set<String>> getFavouriteStopIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_favouriteStopsKey) ?? const <String>[]).toSet();
  }

  Future<bool> toggleFavouriteStop(String stopId) async {
    final prefs = await SharedPreferences.getInstance();
    final favourites = (prefs.getStringList(_favouriteStopsKey) ?? <String>[]).toSet();
    final nowFavourite = !favourites.remove(stopId);
    if (nowFavourite) favourites.add(stopId);
    await prefs.setStringList(_favouriteStopsKey, favourites.toList());
    return nowFavourite;
  }

  Future<List<String>> getRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentSearchesKey) ?? const <String>[];
  }

  Future<void> addRecentSearch(String value) async {
    final text = value.trim();
    if (text.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_recentSearchesKey) ?? <String>[];
    values.remove(text);
    values.insert(0, text);
    if (values.length > 10) values.removeRange(10, values.length);
    await prefs.setStringList(_recentSearchesKey, values);
  }

  Future<bool> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_darkModeKey) ?? false;
  }

  Future<void> setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, value);
  }

  Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey) ?? 'English';
  }

  Future<void> setLanguage(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, value);
  }
}
