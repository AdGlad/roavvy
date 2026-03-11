import 'dart:typed_data';

/// Builds a minimal valid `ne_countries.bin` binary in memory for testing.
///
/// Each polygon is added as a simple rectangle via [addRect]. The builder
/// constructs the full binary format (header + grid index + polygon refs +
/// polygon data) so the real [GeodataIndex] parser is exercised in tests —
/// no mocking of internals.
class TestGeodataBuilder {
  static const _gridCols = 360;
  static const _gridRows = 180;
  static const _gridCellSize = 1; // 1° per cell

  final _polygons = <_RectPolygon>[];

  /// Adds a rectangular country polygon covering [[latMin]..[latMax]] °N
  /// and [[lngMin]..[lngMax]] °E. [iso] must be exactly 2 ASCII characters.
  void addRect(
    String iso,
    double latMin,
    double latMax,
    double lngMin,
    double lngMax,
  ) {
    assert(iso.length == 2, 'ISO code must be 2 characters');
    _polygons.add(
      _RectPolygon(
        iso: iso,
        vertices: [
          (latMin, lngMin),
          (latMax, lngMin),
          (latMax, lngMax),
          (latMin, lngMax),
        ],
      ),
    );
  }

  /// Builds and returns the binary payload.
  Uint8List build() {
    const cellCount = _gridCols * _gridRows;

    // Determine which grid cells each polygon's bounding box overlaps.
    final cellPolys = List<List<int>>.generate(cellCount, (_) => []);
    for (var pi = 0; pi < _polygons.length; pi++) {
      final p = _polygons[pi];
      final latMin = p.vertices.map((v) => v.$1).reduce((a, b) => a < b ? a : b);
      final latMax = p.vertices.map((v) => v.$1).reduce((a, b) => a > b ? a : b);
      final lngMin = p.vertices.map((v) => v.$2).reduce((a, b) => a < b ? a : b);
      final lngMax = p.vertices.map((v) => v.$2).reduce((a, b) => a > b ? a : b);

      final colMin = ((lngMin + 180) ~/ _gridCellSize).clamp(0, _gridCols - 1);
      final colMax = ((lngMax + 180) ~/ _gridCellSize).clamp(0, _gridCols - 1);
      final rowMin = ((latMin + 90) ~/ _gridCellSize).clamp(0, _gridRows - 1);
      final rowMax = ((latMax + 90) ~/ _gridCellSize).clamp(0, _gridRows - 1);

      for (var row = rowMin; row <= rowMax; row++) {
        for (var col = colMin; col <= colMax; col++) {
          cellPolys[row * _gridCols + col].add(pi);
        }
      }
    }

    // Build flat polygon-refs list and per-cell (ref_start, ref_count).
    final gridRefStart = List<int>.filled(cellCount, 0);
    final gridRefCount = List<int>.filled(cellCount, 0);
    final polyRefs = <int>[];
    for (var i = 0; i < cellCount; i++) {
      gridRefStart[i] = polyRefs.length;
      gridRefCount[i] = cellPolys[i].length;
      polyRefs.addAll(cellPolys[i]);
    }

    final polyRefsBytes = polyRefs.length * 2;

    // Calculate polygon data size.
    var polyDataBytes = 0;
    for (final p in _polygons) {
      polyDataBytes += 2 + 2 + p.vertices.length * 8; // iso + count + vertices
    }

    final gridIndexBytes = cellCount * 6;
    final totalBytes = 16 + gridIndexBytes + polyRefsBytes + polyDataBytes;
    final buf = ByteData(totalBytes);
    var off = 0;

    // Header.
    buf.setUint8(off++, 0x52); // R
    buf.setUint8(off++, 0x4C); // L
    buf.setUint8(off++, 0x4B); // K
    buf.setUint8(off++, 0x50); // P
    buf.setUint8(off++, 1); // version
    buf.setUint8(off++, _gridCellSize);
    buf.setUint16(off, _gridCols, Endian.little); off += 2;
    buf.setUint16(off, _gridRows, Endian.little); off += 2;
    buf.setUint16(off, _polygons.length, Endian.little); off += 2;
    buf.setUint32(off, polyRefsBytes, Endian.little); off += 4;

    // Grid index.
    for (var i = 0; i < cellCount; i++) {
      buf.setUint32(off, gridRefStart[i], Endian.little); off += 4;
      buf.setUint16(off, gridRefCount[i], Endian.little); off += 2;
    }

    // Polygon refs.
    for (final ref in polyRefs) {
      buf.setUint16(off, ref, Endian.little); off += 2;
    }

    // Polygon data.
    for (final p in _polygons) {
      buf.setUint8(off++, p.iso.codeUnitAt(0));
      buf.setUint8(off++, p.iso.codeUnitAt(1));
      buf.setUint16(off, p.vertices.length, Endian.little); off += 2;
      for (final (lat, lng) in p.vertices) {
        buf.setInt32(off, (lat * 1000000).round(), Endian.little); off += 4;
        buf.setInt32(off, (lng * 1000000).round(), Endian.little); off += 4;
      }
    }

    return buf.buffer.asUint8List();
  }
}

class _RectPolygon {
  final String iso;
  final List<(double, double)> vertices;
  _RectPolygon({required this.iso, required this.vertices});
}
