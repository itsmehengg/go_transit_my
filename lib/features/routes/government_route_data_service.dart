
import 'government_gtfs_cache.dart';
import 'station_catalog.dart';

class GovernmentRouteEdge {
  const GovernmentRouteEdge({
    required this.to,
    required this.mode,
    required this.line,
  });

  final String to;
  final String mode;
  final String line;
}

class GovernmentRouteData {
  const GovernmentRouteData({
    required this.stations,
    required this.graph,
  });

  final List<RouteStation> stations;
  final Map<String, List<GovernmentRouteEdge>> graph;
}

class GovernmentRouteDataService {
  GovernmentRouteDataService._();

  static final GovernmentRouteDataService instance =
      GovernmentRouteDataService._();

  final GovernmentGtfsCache _cache = GovernmentGtfsCache.instance;
  Future<GovernmentRouteData>? _future;

  Future<GovernmentRouteData> load() {
    return _future ??= _build();
  }

  void refresh() {
    _future = null;
  }

  Future<GovernmentRouteData> _build() async {
    final stationModes = <String, Set<String>>{};
    final stationNames = <String, String>{};
    final graph = <String, List<GovernmentRouteEdge>>{};
    final edgeKeys = <String>{};

    await _processFeed(
      agency: 'Rapid Rail KL',
      stationModes: stationModes,
      stationNames: stationNames,
      graph: graph,
      edgeKeys: edgeKeys,
    );

    await _processFeed(
      agency: 'KTMB',
      stationModes: stationModes,
      stationNames: stationNames,
      graph: graph,
      edgeKeys: edgeKeys,
    );

    final stations = stationNames.entries.map((entry) {
      final modes = stationModes[entry.key] ?? const <String>{};
      return RouteStation(
        name: entry.value,
        mode: _stationMode(modes),
      );
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return GovernmentRouteData(
      stations: List.unmodifiable(stations),
      graph: Map.unmodifiable({
        for (final entry in graph.entries)
          entry.key: List.unmodifiable(entry.value),
      }),
    );
  }

  Future<void> _processFeed({
    required String agency,
    required Map<String, Set<String>> stationModes,
    required Map<String, String> stationNames,
    required Map<String, List<GovernmentRouteEdge>> graph,
    required Set<String> edgeKeys,
  }) async {
    final archive = await _cache.archive(agency);
    final stopsFile = _cache.findFile(archive, 'stops.txt');
    final routesFile = _cache.findFile(archive, 'routes.txt');
    final tripsFile = _cache.findFile(archive, 'trips.txt');
    final stopTimesFile = _cache.findFile(archive, 'stop_times.txt');

    if (stopsFile == null ||
        routesFile == null ||
        tripsFile == null ||
        stopTimesFile == null) {
      return;
    }

    final stopNamesById = <String, String>{};

    for (final row in _cache.parseCsv(_cache.text(stopsFile))) {
      final id = (row['stop_id'] ?? '').trim();
      final name = (row['stop_name'] ?? '').trim();
      if (id.isEmpty || name.isEmpty) {
        continue;
      }

      stopNamesById[id] = name;
      stationNames.putIfAbsent(_key(name), () => name);
    }

    final routeInfo = <String, ({String mode, String line})>{};

    for (final row in _cache.parseCsv(_cache.text(routesFile))) {
      final id = (row['route_id'] ?? '').trim();
      if (id.isEmpty) {
        continue;
      }

      final shortName = (row['route_short_name'] ?? '').trim();
      final longName = (row['route_long_name'] ?? '').trim();
      final desc = (row['route_desc'] ?? '').trim();
      final mode = _routeMode(
        agency: agency,
        shortName: shortName,
        longName: longName,
        description: desc,
      );
      final line = longName.isNotEmpty
          ? longName
          : shortName.isNotEmpty
              ? shortName
              : agency;

      routeInfo[id] = (mode: mode, line: line);
    }

    final tripRoutes = <String, String>{};

    for (final row in _cache.parseCsv(_cache.text(tripsFile))) {
      final tripId = (row['trip_id'] ?? '').trim();
      final routeId = (row['route_id'] ?? '').trim();
      if (tripId.isEmpty || routeId.isEmpty) {
        continue;
      }
      tripRoutes[tripId] = routeId;
    }

    final byTrip = <String, List<({int sequence, String stopId})>>{};

    for (final row in _cache.parseCsv(_cache.text(stopTimesFile))) {
      final tripId = (row['trip_id'] ?? '').trim();
      final stopId = (row['stop_id'] ?? '').trim();
      final sequence = int.tryParse((row['stop_sequence'] ?? '').trim());

      if (tripId.isEmpty ||
          stopId.isEmpty ||
          sequence == null ||
          !stopNamesById.containsKey(stopId)) {
        continue;
      }

      byTrip
          .putIfAbsent(tripId, () => <({int sequence, String stopId})>[])
          .add((sequence: sequence, stopId: stopId));
    }

    for (final entry in byTrip.entries) {
      final routeId = tripRoutes[entry.key];
      final info = routeId == null ? null : routeInfo[routeId];
      if (info == null) {
        continue;
      }

      final stops = entry.value
        ..sort((a, b) => a.sequence.compareTo(b.sequence));

      for (var i = 0; i < stops.length - 1; i++) {
        final fromName = stopNamesById[stops[i].stopId];
        final toName = stopNamesById[stops[i + 1].stopId];

        if (fromName == null ||
            toName == null ||
            _key(fromName) == _key(toName)) {
          continue;
        }

        final fromKey = _key(fromName);
        final toKey = _key(toName);

        stationNames.putIfAbsent(fromKey, () => fromName);
        stationNames.putIfAbsent(toKey, () => toName);
        stationModes.putIfAbsent(fromKey, () => <String>{}).add(info.mode);
        stationModes.putIfAbsent(toKey, () => <String>{}).add(info.mode);

        _addEdge(
          graph: graph,
          edgeKeys: edgeKeys,
          from: fromName,
          to: toName,
          mode: info.mode,
          line: info.line,
        );

        _addEdge(
          graph: graph,
          edgeKeys: edgeKeys,
          from: toName,
          to: fromName,
          mode: info.mode,
          line: info.line,
        );
      }
    }

    _connectSameNamedStations(
      graph: graph,
      edgeKeys: edgeKeys,
      stationNames: stationNames,
    );
  }

  void _connectSameNamedStations({
    required Map<String, List<GovernmentRouteEdge>> graph,
    required Set<String> edgeKeys,
    required Map<String, String> stationNames,
  }) {
    final names = stationNames.values.toList();

    for (var i = 0; i < names.length; i++) {
      for (var j = i + 1; j < names.length; j++) {
        if (_key(names[i]) != _key(names[j])) {
          continue;
        }

        _addEdge(
          graph: graph,
          edgeKeys: edgeKeys,
          from: names[i],
          to: names[j],
          mode: 'Walk',
          line: 'GTFS station interchange',
        );

        _addEdge(
          graph: graph,
          edgeKeys: edgeKeys,
          from: names[j],
          to: names[i],
          mode: 'Walk',
          line: 'GTFS station interchange',
        );
      }
    }
  }

  void _addEdge({
    required Map<String, List<GovernmentRouteEdge>> graph,
    required Set<String> edgeKeys,
    required String from,
    required String to,
    required String mode,
    required String line,
  }) {
    final key = '${_key(from)}|${_key(to)}|$mode|$line';
    if (!edgeKeys.add(key)) {
      return;
    }

    graph.putIfAbsent(from, () => <GovernmentRouteEdge>[]).add(
          GovernmentRouteEdge(
            to: to,
            mode: mode,
            line: line,
          ),
        );
  }

  String _routeMode({
    required String agency,
    required String shortName,
    required String longName,
    required String description,
  }) {
    if (agency == 'KTMB') {
      return 'KTM';
    }

    final value =
        '$shortName $longName $description'.toUpperCase();

    if (value.contains('MRT')) {
      return 'MRT';
    }
    if (value.contains('LRT')) {
      return 'LRT';
    }
    if (value.contains('MONORAIL')) {
      return 'Monorail';
    }

    return 'Rapid Rail';
  }

  String _stationMode(Set<String> modes) {
    if (modes.isEmpty) {
      return 'Rail';
    }

    const order = ['MRT', 'LRT', 'Monorail', 'Rapid Rail', 'KTM'];
    final sorted = modes.toList()
      ..sort((a, b) {
        final ai = order.indexOf(a);
        final bi = order.indexOf(b);
        return (ai < 0 ? 99 : ai).compareTo(bi < 0 ? 99 : bi);
      });

    return sorted.join(' / ');
  }

  String _key(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }
}
