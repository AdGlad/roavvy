/// Returns true if the point ([lat], [lng]) lies inside the polygon
/// defined by [vertices] (a closed ring of lat/lng pairs).
///
/// Uses the ray-casting algorithm: cast a ray in the +longitude direction
/// and count the number of edge crossings. An odd count means inside.
///
/// Points exactly on a boundary may return either true or false — callers
/// must not rely on a specific result for boundary-exact coordinates.
bool pointInPolygon(
  double lat,
  double lng,
  List<(double lat, double lng)> vertices,
) {
  if (vertices.length < 3) return false;

  var crossings = 0;
  final n = vertices.length;

  for (var i = 0; i < n; i++) {
    final (lat1, lng1) = vertices[i];
    final (lat2, lng2) = vertices[(i + 1) % n];

    // Check whether the horizontal ray from (lat, lng) in the +lng direction
    // crosses this edge. Use half-open interval [lat1, lat2) to avoid
    // double-counting shared vertices at polygon corners.
    final crosses =
        ((lat1 <= lat) && (lat < lat2)) || ((lat2 <= lat) && (lat < lat1));

    if (crosses) {
      final intersectLng =
          lng1 + (lat - lat1) * (lng2 - lng1) / (lat2 - lat1);
      if (lng < intersectLng) {
        crossings++;
      }
    }
  }

  return crossings.isOdd;
}
