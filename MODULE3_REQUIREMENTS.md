# Module 3 Requirement Coverage

Module: **Station & Live Transport Tracking**

| Required function | Implementation |
| --- | --- |
| Detect nearby public transport stations | Android GPS via `geolocator`, distance calculation, nearest-first sorting |
| Search stations by name | Search field filters official GTFS stops |
| Display station locations on a map | `flutter_map` + OpenStreetMap markers |
| Show distance from user | GPS distance shown beside station and in station details |
| View station details | Dynamic GTFS station name, operator/feed, stop ID and coordinates |
| Favourite station | Connected to Module 1 persistent personalisation storage |
| Scheduled arrival/timetable information | Official GTFS Static `stop_times.txt`, `trips.txt` and `routes.txt` |
| Live vehicle positions | Official Malaysia GTFS Realtime vehicle-position feeds |
| Refresh transport data | App-bar refresh and pull-to-refresh |
| Error/loading/empty handling | Implemented for API, GPS, search and timetable states |

## Data-source compliance

This module uses Malaysia Government Open API data from `api.data.gov.my` for GTFS Static and GTFS Realtime. The realtime feed is used only for vehicle positions, matching the current official API capability. Scheduled timetable data is labelled Scheduled and is not presented as a realtime arrival prediction.
