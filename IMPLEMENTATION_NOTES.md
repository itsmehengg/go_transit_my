# GoTransit MY implementation notes

This branch replaces prototype-only transport data with Malaysia's official open-data services.

## Official transport data

- GTFS Static: `https://api.data.gov.my/gtfs-static/<agency>`
- GTFS Realtime vehicle positions: `https://api.data.gov.my/gtfs-realtime/vehicle-position/<agency>`
- Prasarana static rail: `rapid-rail-kl`
- Prasarana realtime currently supports selected bus categories; stable Rapid Rail realtime is not currently provided by the government endpoint.

## Important current API limitation

As of August 2026, Malaysia's official GTFS Realtime documentation states that the API currently exposes **vehicle positions only**. Trip updates and service alerts are still planned. The app must therefore not label demo delay/arrival data as official GTFS-Realtime data.

## Setup after pulling this branch

1. Run `flutter pub get`.
2. Start an Android emulator or connect an Android phone.
3. Run `flutter run`.
4. When Android asks for location permission, choose **While using the app**.
5. Make sure GPS/location is enabled when testing nearby stations.

No API key is required for the Malaysia `api.data.gov.my` GTFS endpoints.
