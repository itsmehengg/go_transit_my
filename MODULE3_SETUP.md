# Module 3 – Station & Live Transport Tracking

## Implemented functions

- Official Malaysia GTFS Static station loading from `api.data.gov.my` for Prasarana and KTMB
- Search stations by station/operator name
- Filter Prasarana / KTMB
- Android GPS permission and current-location detection
- Nearby-station ordering and distance calculation
- OpenStreetMap station map
- Official Malaysia GTFS Realtime vehicle-position loading
- Live bus/train/rail markers with feed/route information
- Station details with operator, stop ID, coordinates and distance
- Favourite station toggle integrated with Module 1 personalisation storage
- Scheduled GTFS timetable for the selected stop
- Loading, refresh, empty and error states

## Important data wording

The Malaysia GTFS Realtime integration in this module is used for **vehicle positions**. The timetable shown in Station Details comes from **GTFS Static scheduled stop times**. The UI intentionally does not claim that scheduled times are realtime arrival predictions.

## Android test steps

```bash
git fetch origin
git checkout feature/module3-complete
git pull origin feature/module3-complete
flutter clean
flutter pub get
flutter run
```

On first opening **Stations**, Android should request location permission. Choose **While using the app**. Ensure Location/GPS and Internet are enabled.

Test these flows:

1. Open Stations and allow location permission.
2. Confirm official stations load and nearest stations show a distance.
3. Search `KL Sentral`, `Bukit Bintang`, or another known station.
4. Switch between All / Prasarana / KTMB filters.
5. Open a station and toggle Favourite.
6. Return to Profile > Favourite Stations and confirm it is saved.
7. Open a station and wait for Scheduled Timetable to load.
8. Tap Live Map and confirm current GTFS Realtime vehicle markers appear when feeds are available.
9. Pull to refresh and verify the page reloads without crashing.

If an emulator does not have a GPS location configured, the app remains runnable and shows stations alphabetically with a clear GPS warning instead of crashing.
