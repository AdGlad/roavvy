import 'dart:typed_data';

/// Magic bytes at the start of every ne_countries.bin file.
const _kMagic = [0x52, 0x4C, 0x4B, 0x50]; // "RLKP"
const _kVersion = 1;

/// A single country polygon extracted from the binary asset.
class CountryPolygon {
  /// ISO 3166-1 alpha-2 country code, e.g. "GB".
  final String isoCode;

  /// Polygon vertices as (lat, lng) pairs in decimal degrees.
  final List<(double, double)> vertices;

  const CountryPolygon({required this.isoCode, required this.vertices});
}

/// Parsed representation of the ne_countries.bin spatial index.
///
/// Binary layout (little-endian throughout):
///
/// Header (16 bytes):
///   [0–3]   magic "RLKP"
///   [4]     version = 1
///   [5]     grid_cell_size (degrees per grid cell, e.g. 1)
///   [6–7]   grid_cols  (360 for 1° cells)
///   [8–9]   grid_rows  (180 for 1° cells)
///   [10–11] polygon_count
///   [12–15] poly_refs_size_bytes
///
/// Grid index (grid_cols × grid_rows × 6 bytes):
///   For each cell in row-major order (row 0 = lat [−90, −89), col 0 = lng [−180, −179)):
///     [0–3] ref_start  — index (not byte offset) into the polygon-refs array
///     [4–5] ref_count  — number of polygon indices in this cell
///
/// Polygon refs (poly_refs_size_bytes bytes):
///   Flat array of uint16 polygon indices referenced by the grid cells.
///
/// Polygon data (remainder of file):
///   For each polygon:
///     [0–1] iso_code    — 2 ASCII bytes (ISO 3166-1 alpha-2)
///     [2–3] vertex_count — uint16
///     Followed by vertex_count × 8 bytes:
///       [0–3] lat as int32 micro-degrees (degrees × 1 000 000)
///       [4–7] lng as int32 micro-degrees (degrees × 1 000 000)
class GeodataIndex {
  final int _gridCellSize;
  final int _gridCols;
  final int _gridRows;
  final List<int> _gridRefStart;
  final List<int> _gridRefCount;
  final List<int> _polyRefs;
  final List<CountryPolygon> _polygons;

  GeodataIndex._({
    required int gridCellSize,
    required int gridCols,
    required int gridRows,
    required List<int> gridRefStart,
    required List<int> gridRefCount,
    required List<int> polyRefs,
    required List<CountryPolygon> polygons,
  })  : _gridCellSize = gridCellSize,
        _gridCols = gridCols,
        _gridRows = gridRows,
        _gridRefStart = gridRefStart,
        _gridRefCount = gridRefCount,
        _polyRefs = polyRefs,
        _polygons = polygons;

  factory GeodataIndex.parse(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    var offset = 0;

    // Validate magic bytes.
    for (var i = 0; i < 4; i++) {
      if (data.getUint8(offset + i) != _kMagic[i]) {
        throw FormatException(
          'Invalid geodata file: bad magic bytes at offset ${offset + i}',
        );
      }
    }
    offset += 4;

    final version = data.getUint8(offset++);
    if (version != _kVersion) {
      throw FormatException(
        'Unsupported geodata version: $version (expected $_kVersion)',
      );
    }

    final gridCellSize = data.getUint8(offset++);
    final gridCols = data.getUint16(offset, Endian.little);
    offset += 2;
    final gridRows = data.getUint16(offset, Endian.little);
    offset += 2;
    final polyCount = data.getUint16(offset, Endian.little);
    offset += 2;
    final polyRefsSize = data.getUint32(offset, Endian.little);
    offset += 4;
    // offset is now 16 — start of grid index.

    // Read grid index.
    final cellCount = gridCols * gridRows;
    final gridRefStart = List<int>.filled(cellCount, 0);
    final gridRefCount = List<int>.filled(cellCount, 0);
    for (var i = 0; i < cellCount; i++) {
      gridRefStart[i] = data.getUint32(offset, Endian.little);
      offset += 4;
      gridRefCount[i] = data.getUint16(offset, Endian.little);
      offset += 2;
    }

    // Read polygon refs (flat uint16 array).
    final refCount = polyRefsSize ~/ 2;
    final polyRefs = List<int>.filled(refCount, 0);
    for (var i = 0; i < refCount; i++) {
      polyRefs[i] = data.getUint16(offset, Endian.little);
      offset += 2;
    }

    // Read polygon data.
    final polygons = <CountryPolygon>[];
    for (var i = 0; i < polyCount; i++) {
      final isoCode = String.fromCharCodes([
        data.getUint8(offset),
        data.getUint8(offset + 1),
      ]);
      offset += 2;

      final vertexCount = data.getUint16(offset, Endian.little);
      offset += 2;

      final vertices = <(double, double)>[];
      for (var v = 0; v < vertexCount; v++) {
        final lat = data.getInt32(offset, Endian.little) / 1000000.0;
        offset += 4;
        final lng = data.getInt32(offset, Endian.little) / 1000000.0;
        offset += 4;
        vertices.add((lat, lng));
      }

      polygons.add(CountryPolygon(isoCode: isoCode, vertices: vertices));
    }

    return GeodataIndex._(
      gridCellSize: gridCellSize,
      gridCols: gridCols,
      gridRows: gridRows,
      gridRefStart: gridRefStart,
      gridRefCount: gridRefCount,
      polyRefs: polyRefs,
      polygons: polygons,
    );
  }

  /// Returns all polygons whose bounding-box grid cells overlap ([lat], [lng]).
  List<CountryPolygon> candidatesAt(double lat, double lng) {
    final col =
        ((lng + 180) ~/ _gridCellSize).clamp(0, _gridCols - 1);
    final row =
        ((lat + 90) ~/ _gridCellSize).clamp(0, _gridRows - 1);
    final cellIndex = row * _gridCols + col;

    final start = _gridRefStart[cellIndex];
    final count = _gridRefCount[cellIndex];

    return [
      for (var i = 0; i < count; i++) _polygons[_polyRefs[start + i]],
    ];
  }
}
