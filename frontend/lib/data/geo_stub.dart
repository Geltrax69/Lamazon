/// Off the web there is no browser geolocation. Native platforms would use a
/// plugin; until one exists, callers get "no fix" and type their address.
class Geo {
  Geo._();
  static final Geo instance = Geo._();

  bool get supported => false;
  Future<GeoFix?> locate() async => null;
}

/// Where the device thinks it is, and how far that is from campus.
class GeoFix {
  final double latitude;
  final double longitude;
  final double accuracyMetres;
  final double metresFromCampus;

  const GeoFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyMetres,
    required this.metresFromCampus,
  });

  /// Campus is about a kilometre across, so anything inside two is "here".
  bool get onCampus => metresFromCampus <= 2000;

  String get distanceLabel => metresFromCampus < 1000
      ? '${metresFromCampus.round()} m away'
      : '${(metresFromCampus / 1000).toStringAsFixed(1)} km away';
}
