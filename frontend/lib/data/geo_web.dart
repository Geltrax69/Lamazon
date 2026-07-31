import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;

export 'geo_stub.dart' show GeoFix;

import 'geo_stub.dart' show GeoFix;

/// The campus we deliver to. ponytail: one pair of coordinates and a distance
/// check, instead of a geocoding service and an API key — the only question
/// this app asks of a location is "is this person on campus?".
const _campusLat = 31.2550;
const _campusLng = 75.7050;

@JS('navigator.geolocation')
external JSObject? get _geolocation;

class Geo {
  Geo._();
  static final Geo instance = Geo._();

  bool get supported {
    try {
      return _geolocation != null;
    } catch (_) {
      return false;
    }
  }

  /// Asks the browser where we are. Null when the user says no, when the
  /// browser cannot tell, or when it takes too long — all of which mean the
  /// same thing to the caller: fall back to typing an address.
  Future<GeoFix?> locate() async {
    if (!supported) return null;
    final done = Completer<GeoFix?>();

    void finish(GeoFix? fix) {
      if (!done.isCompleted) done.complete(fix);
    }

    try {
      _geolocation!.callMethod<JSAny?>(
        'getCurrentPosition'.toJS,
        ((JSObject position) {
          final coords = position.getProperty<JSObject>('coords'.toJS);
          final lat = (coords.getProperty<JSNumber>('latitude'.toJS)).toDartDouble;
          final lng = (coords.getProperty<JSNumber>('longitude'.toJS)).toDartDouble;
          final acc = coords.getProperty<JSNumber?>('accuracy'.toJS)?.toDartDouble ?? 0;
          finish(GeoFix(
            latitude: lat,
            longitude: lng,
            accuracyMetres: acc,
            metresFromCampus: _metresBetween(lat, lng, _campusLat, _campusLng),
          ));
        }).toJS,
        ((JSObject _) => finish(null)).toJS,
        {'enableHighAccuracy': true, 'timeout': 15000, 'maximumAge': 60000}.jsify(),
      );
    } catch (_) {
      finish(null);
    }
    // A browser that never calls either callback would hang the UI forever.
    return done.future.timeout(const Duration(seconds: 20), onTimeout: () => null);
  }
}

/// Haversine. Good to a few metres over campus distances, and it needs no
/// dependency.
double _metresBetween(double lat1, double lng1, double lat2, double lng2) {
  const earthRadius = 6371000.0;
  double radians(double deg) => deg * math.pi / 180;
  final dLat = radians(lat2 - lat1);
  final dLng = radians(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(radians(lat1)) * math.cos(radians(lat2)) *
          math.sin(dLng / 2) * math.sin(dLng / 2);
  return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}
