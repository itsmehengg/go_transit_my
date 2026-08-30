import 'dart:collection';

import 'station_catalog.dart';

class RouteLeg {
  const RouteLeg({
    required this.from,
    required this.to,
    required this.mode,
    required this.line,
  });

  final String from;
  final String to;
  final String mode;
  final String line;
}

class RouteSearchResult {
  const RouteSearchResult({
    required this.from,
    required this.to,
    required this.legs,
  });

  final RouteStation from;
  final RouteStation to;
  final List<RouteLeg> legs;

  int get transfers {
    if (legs.isEmpty) return 0;
    var changes = 0;
    for (var i = 1; i < legs.length; i++) {
      if (legs[i - 1].line != legs[i].line) changes++;
    }
    return changes;
  }

  List<String> get modes {
    final result = <String>[];
    for (final leg in legs) {
      if (leg.mode == 'Walk') continue;
      if (!result.contains(leg.mode)) result.add(leg.mode);
    }
    return result;
  }

  List<RouteLeg> get groupedLegs {
    if (legs.isEmpty) return const [];
    final grouped = <RouteLeg>[];
    var current = legs.first;
    for (var i = 1; i < legs.length; i++) {
      final next = legs[i];
      if (next.line == current.line && next.mode == current.mode) {
        current = RouteLeg(
          from: current.from,
          to: next.to,
          mode: current.mode,
          line: current.line,
        );
      } else {
        grouped.add(current);
        current = next;
      }
    }
    grouped.add(current);
    return grouped;
  }
}

class RouteSearchService {
  const RouteSearchService();

  Future<RouteSearchResult?> search({
    required RouteStation from,
    required RouteStation to,
    required String transport,
  }) async {
    final graph = _buildGraph(transport);
    final queue = Queue<_SearchState>();
    final visited = <String>{from.name};
    queue.add(_SearchState(station: from.name, legs: const []));

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (current.station == to.name) {
        return RouteSearchResult(from: from, to: to, legs: current.legs);
      }
      for (final edge in graph[current.station] ?? const <_RouteEdge>[]) {
        if (!visited.add(edge.to)) continue;
        queue.add(
          _SearchState(
            station: edge.to,
            legs: [
              ...current.legs,
              RouteLeg(
                from: current.station,
                to: edge.to,
                mode: edge.mode,
                line: edge.line,
              ),
            ],
          ),
        );
      }
    }
    return null;
  }

  Map<String, List<_RouteEdge>> _buildGraph(String transport) {
    final graph = <String, List<_RouteEdge>>{};
    for (final line in _lines) {
      if (transport != 'All' && line.mode != transport) continue;
      for (var i = 0; i < line.stations.length - 1; i++) {
        final a = line.stations[i];
        final b = line.stations[i + 1];
        _addEdge(graph, a, b, line.mode, line.name);
        _addEdge(graph, b, a, line.mode, line.name);
      }
    }

    if (transport == 'All' || transport == 'MRT') {
      _addEdge(graph, 'KL Sentral', 'Muzium Negara', 'Walk', 'KL Sentral–Muzium Negara Link');
      _addEdge(graph, 'Muzium Negara', 'KL Sentral', 'Walk', 'KL Sentral–Muzium Negara Link');
    }
    return graph;
  }

  void _addEdge(
    Map<String, List<_RouteEdge>> graph,
    String from,
    String to,
    String mode,
    String line,
  ) {
    graph.putIfAbsent(from, () => <_RouteEdge>[]).add(
          _RouteEdge(to: to, mode: mode, line: line),
        );
  }
}

class _RouteEdge {
  const _RouteEdge({required this.to, required this.mode, required this.line});

  final String to;
  final String mode;
  final String line;
}

class _SearchState {
  const _SearchState({required this.station, required this.legs});

  final String station;
  final List<RouteLeg> legs;
}

class _TransitLine {
  const _TransitLine({required this.name, required this.mode, required this.stations});

  final String name;
  final String mode;
  final List<String> stations;
}

const _lines = <_TransitLine>[
  _TransitLine(
    name: 'MRT Kajang Line',
    mode: 'MRT',
    stations: [
      'Muzium Negara',
      'Pasar Seni',
      'Merdeka',
      'Bukit Bintang',
      'Cochrane',
      'Maluri',
      'Taman Midah',
      'Kajang',
    ],
  ),
  _TransitLine(
    name: 'LRT Kelana Jaya Line',
    mode: 'LRT',
    stations: [
      'KLCC',
      'Ampang Park',
      'Dang Wangi',
      'Masjid Jamek',
      'Pasar Seni',
      'KL Sentral',
      'Bangsar',
      'Abdullah Hukum',
      'Universiti',
      'Taman Jaya',
      'Subang Jaya',
    ],
  ),
  _TransitLine(
    name: 'KTM Seremban Line',
    mode: 'KTM',
    stations: [
      'KL Sentral',
      'Mid Valley',
      'Bandar Tasik Selatan',
      'Serdang',
      'Kajang',
    ],
  ),
  _TransitLine(
    name: 'KTM Port Klang Line',
    mode: 'KTM',
    stations: ['KL Sentral', 'Subang Jaya'],
  ),
  _TransitLine(
    name: 'KTM Batu Caves Line',
    mode: 'KTM',
    stations: ['KL Sentral', 'Batu Caves'],
  ),
];
