import 'package:latlong2/latlong.dart';

/// Missing coordinates retain the legacy (0, 0) sentinel, never a guessed pin.
bool validDeliveryCoordinate(LatLng point) =>
    point.latitude.isFinite &&
    point.longitude.isFinite &&
    point.latitude.abs() <= 90 &&
    point.longitude.abs() <= 180 &&
    (point.latitude != 0 || point.longitude != 0);

LatLng readDeliveryCoordinate(dynamic source) {
  if (source is! Map) return const LatLng(0, 0);
  double? number(dynamic value) {
    if (value is bool || value == null || '$value'.trim().isEmpty) return null;
    final parsed = double.tryParse('$value');
    return parsed?.isFinite == true ? parsed : null;
  }

  final coordinates = source['coordinates'];
  final isPoint =
      source['type'] == 'Point' &&
      coordinates is List &&
      coordinates.length >= 2;
  final latitude = number(
    isPoint ? coordinates[1] : source['latitude'] ?? source['lat'],
  );
  final longitude = number(
    isPoint
        ? coordinates[0]
        : source['longitude'] ?? source['lng'] ?? source['lon'],
  );
  if (latitude == null ||
      longitude == null ||
      latitude.abs() > 90 ||
      longitude.abs() > 180) {
    return const LatLng(0, 0);
  }
  return LatLng(latitude, longitude);
}
