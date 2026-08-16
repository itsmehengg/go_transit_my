import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<Position> getCurrentPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw const LocationServiceException(
        'Location services are disabled. Please turn on GPS and try again.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationServiceException('Location permission was denied.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationServiceException(
        'Location permission is permanently denied. Enable it in Android settings.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }
}

class LocationServiceException implements Exception {
  const LocationServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}
