import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

enum OsmStationType { bus, rail, mrtLrt, other }

class OsmStation {
  const OsmStation({
    required this.id,
    required this.name,
    required this.type,
    required this.point,
    required this.source,
  });

  final String id;
  final String name;
  final OsmStationType type;
  final LatLng point;
  final String source;

  String get typeLabel {
    return switch (type) {
      OsmStationType.bus => 'Bus',
      OsmStationType.rail => 'KTM',
      OsmStationType.mrtLrt => 'MRT/LRT',
      OsmStationType.other => 'Station',
    };
  }
}

class OsmStationService {
  OsmStationService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<OsmStation>> fetchKlangValleyStations() async {
    const south = 3.02;
    const west = 101.55;
    const north = 3.25;
    const east = 101.82;

    final query =
        '''
[out:json][timeout:20];
(
  node["name"]["railway"~"station|halt|tram_stop|subway_entrance"]($south,$west,$north,$east);
  node["name"]["station"~"subway|light_rail|monorail"]($south,$west,$north,$east);
  node["name"]["amenity"="bus_station"]($south,$west,$north,$east);
  node["name"]["highway"="bus_stop"]($south,$west,$north,$east);
  node["name"]["public_transport"~"station|platform|stop_position"]($south,$west,$north,$east);
  way["name"]["railway"~"station|halt|tram_stop|subway_entrance"]($south,$west,$north,$east);
  way["name"]["station"~"subway|light_rail|monorail"]($south,$west,$north,$east);
  way["name"]["amenity"="bus_station"]($south,$west,$north,$east);
  relation["name"]["public_transport"="station"]($south,$west,$north,$east);
);
out center tags 180;
''';

    final response = await _client
        .post(
          Uri.parse('https://overpass-api.de/api/interpreter'),
          body: {'data': query},
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      throw Exception('OSM station API failed: HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    final elements = decoded['elements'];
    if (elements is! List) {
      throw Exception('OSM station API returned no station elements.');
    }

    final stations = elements
        .whereType<Map<String, dynamic>>()
        .map(_parseStation)
        .whereType<OsmStation>()
        .toList();

    final unique = <String, OsmStation>{};
    for (final station in stations) {
      unique.putIfAbsent(_dedupeKey(station), () => station);
    }

    final sorted = unique.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return sorted;
  }

  OsmStation? _parseStation(Map<String, dynamic> element) {
    final tags = element['tags'];
    if (tags is! Map) return null;

    final name = tags['name']?.toString().trim();
    if (name == null || name.isEmpty) return null;

    final lat =
        (element['lat'] as num?)?.toDouble() ??
        (element['center'] is Map
            ? ((element['center'] as Map)['lat'] as num?)?.toDouble()
            : null);
    final lon =
        (element['lon'] as num?)?.toDouble() ??
        (element['center'] is Map
            ? ((element['center'] as Map)['lon'] as num?)?.toDouble()
            : null);
    if (lat == null || lon == null) return null;

    return OsmStation(
      id: '${element['type']}/${element['id']}',
      name: name,
      type: _classify(tags),
      point: LatLng(lat, lon),
      source: tags['operator']?.toString() ?? 'OpenStreetMap',
    );
  }

  OsmStationType _classify(Map tags) {
    final amenity = tags['amenity']?.toString();
    final highway = tags['highway']?.toString();
    final station = tags['station']?.toString();
    final railway = tags['railway']?.toString();
    final route = tags['route']?.toString();

    if (amenity == 'bus_station' || highway == 'bus_stop' || route == 'bus') {
      return OsmStationType.bus;
    }
    if (station == 'subway' ||
        station == 'light_rail' ||
        station == 'monorail' ||
        railway == 'subway_entrance' ||
        railway == 'tram_stop') {
      return OsmStationType.mrtLrt;
    }
    if (railway == 'station' || railway == 'halt') {
      return OsmStationType.rail;
    }
    return OsmStationType.other;
  }

  String _dedupeKey(OsmStation station) {
    final lat = station.point.latitude.toStringAsFixed(4);
    final lon = station.point.longitude.toStringAsFixed(4);
    return '${station.name.toLowerCase()}-$lat-$lon';
  }
}
