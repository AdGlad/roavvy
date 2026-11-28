import 'package:flutter/painting.dart' show Rect, Size;

import 'garment/garment_mockup_spec.dart';
import 'production_render.dart';

/// A named place on the t-shirt a design can print — the customer-facing
/// vocabulary of the print layout ("Left chest", "Upper back").
///
/// Each zone is stated twice, from one source:
///  * [inches] — where it is on the fulfiller's 12"×16" print file. This is
///    what production prints ([areaInches]).
///  * [mockupRect] — where it is on the garment photograph, for the preview.
///    The zones that already shipped keep their calibrated photo rects; the
///    newer back zones are derived from [inches] through the back print
///    area's provider-correct WIDTH, so preview and print agree on their shape.
///
/// Sleeves are deliberately absent: the order pipeline prints one file per
/// face (front, back) and has no sleeve placement yet.
enum PrintZone {
  fullFront(
    side: PrintSide.front,
    label: 'Full front',
    inches: Rect.fromLTWH(0, 0, 12, 16),
    minScale: 0.5,
    placement: PrintPlacement.frontFull,
  ),
  leftChest(
    side: PrintSide.front,
    label: 'Left chest',
    // M167: 3.5" logo, 3" down, centred 10" from the canvas left.
    inches: Rect.fromLTWH(8.25, 3, 3.5, 3.5),
    minScale: 0.7,
    placement: PrintPlacement.frontLeftChest,
  ),
  rightChest(
    side: PrintSide.front,
    label: 'Right chest',
    inches: Rect.fromLTWH(0.25, 3, 3.5, 3.5),
    minScale: 0.7,
    placement: PrintPlacement.frontRightChest,
  ),
  fullBack(
    side: PrintSide.back,
    label: 'Full back',
    inches: Rect.fromLTWH(0, 0, 12, 16),
    minScale: 0.5,
    placement: PrintPlacement.backFull,
  ),
  upperBack(
    side: PrintSide.back,
    label: 'Upper back',
    inches: Rect.fromLTWH(1, 0.75, 10, 5),
    minScale: 0.6,
    placement: PrintPlacement.backUpper,
  ),
  backNeck(
    side: PrintSide.back,
    label: 'Back neck',
    inches: Rect.fromLTWH(4.5, 0.75, 3, 3),
    minScale: 0.7,
    placement: PrintPlacement.backNeck,
  );

  const PrintZone({
    required this.side,
    required this.label,
    required this.inches,
    required this.minScale,
    required this.placement,
  });

  final PrintSide side;
  final String label;

  /// The zone at full size, in inches on the 12"×16" print file.
  final Rect inches;

  /// The smallest size a customer may choose, as a fraction of [inches].
  final double minScale;

  /// The production boundary's word for this zone.
  final PrintPlacement placement;

  /// The print file's printable area, in inches (front and back alike).
  static const Size printFileInches = Size(12, 16);

  static List<PrintZone> on(PrintSide side) =>
      [for (final z in values) if (z.side == side) z];

  static PrintZone? byName(Object? name) {
    for (final z in values) {
      if (z.name == name) return z;
    }
    return null;
  }

  /// Clamped to [minScale]…1.
  double clampScale(double s) => s.isNaN ? 1 : s.clamp(minScale, 1.0);

  /// The print area at [scale], in inches: shrunk about its top-centre, so a
  /// smaller print still hangs from the same line below the collar.
  Rect areaInches([double scale = 1]) => _shrinkTop(inches, clampScale(scale));

  /// Where the zone is on the garment photograph, at full size.
  Rect get mockupRect => switch (this) {
    PrintZone.fullFront => BundledGarments.frontCenterArea,
    PrintZone.leftChest => BundledGarments.frontLeftChestArea,
    PrintZone.rightChest => BundledGarments.frontRightChestArea,
    PrintZone.fullBack => BundledGarments.backPrintArea,
    PrintZone.upperBack || PrintZone.backNeck => backInchesToMockup(inches),
  };

  /// [mockupRect] at [scale], shrunk the same way as [areaInches].
  Rect mockupRectAt([double scale = 1]) =>
      _shrinkTop(mockupRect, clampScale(scale));

  /// e.g. `3.5″ × 3.5″`.
  String sizeLabel([double scale = 1]) => labelFor(areaInches(scale));

  /// e.g. `12″ × 14.5″`, to the half inch.
  static String labelFor(Rect r) => '${_in(r.width)}″ × ${_in(r.height)}″';

  /// One back-print inch, vertically, as a fraction of the back photo.
  static double get backPerInchY =>
      BundledGarments.backPrintArea.width /
      printFileInches.width *
      BundledGarments.tintBaseBackSize.width /
      BundledGarments.tintBaseBackSize.height;

  static String _in(double v) {
    final r = (v * 2).round() / 2; // to the half inch
    return r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(1);
  }

  static Rect _shrinkTop(Rect r, double s) {
    final w = r.width * s, h = r.height * s;
    return Rect.fromLTWH(r.center.dx - w / 2, r.top, w, h);
  }

  /// Inches on the back print file → the back photograph. One inch is
  /// 1/12 of the back print area's width (the provider-correct dimension),
  /// and the same physical inch vertically on a 487×640 photo.
  static Rect backInchesToMockup(Rect inches) {
    const area = BundledGarments.backPrintArea;
    const photo = BundledGarments.tintBaseBackSize;
    final perInchX = area.width / printFileInches.width;
    final perInchY = perInchX * photo.width / photo.height;
    return Rect.fromLTWH(
      area.left + inches.left * perInchX,
      area.top + inches.top * perInchY,
      inches.width * perInchX,
      inches.height * perInchY,
    );
  }
}

/// One face's print: which [zone], at what [scale] of its full size.
class ZonePrint {
  const ZonePrint(this.zone, {double scale = 1}) : _scale = scale;

  final PrintZone zone;
  final double _scale;

  double get scale => zone.clampScale(_scale);

  ZonePrint withScale(double s) => ZonePrint(zone, scale: s);

  Rect get areaInches => zone.areaInches(scale);
  Rect get mockupRect => zone.mockupRectAt(scale);

  Map<String, Object?> toJson() => {
    'zone': zone.name,
    if (scale != 1) 'scale': double.parse(scale.toStringAsFixed(3)),
  };

  static ZonePrint? fromJson(Object? json, PrintSide side) {
    if (json is! Map) return null;
    final zone = PrintZone.byName(json['zone']);
    if (zone == null || zone.side != side) return null;
    final s = json['scale'];
    return ZonePrint(zone, scale: s is num ? s.toDouble() : 1);
  }

  @override
  bool operator ==(Object other) =>
      other is ZonePrint && other.zone == zone && other.scale == scale;

  @override
  int get hashCode => Object.hash(zone, scale);

  @override
  String toString() => 'ZonePrint(${zone.name}, $scale)';
}

/// One-tap combinations, the way print shops sell them.
enum PrintLayoutPreset {
  back('Back', null, PrintZone.fullBack),
  front('Front', PrintZone.fullFront, null),
  crestAndBack('Crest + back', PrintZone.leftChest, PrintZone.fullBack),
  frontAndBack('Front + back', PrintZone.fullFront, PrintZone.fullBack),
  frontAndNeck('Front + neck', PrintZone.fullFront, PrintZone.backNeck),
  crest('Crest only', PrintZone.leftChest, null);

  const PrintLayoutPreset(this.label, this.frontZone, this.backZone);

  final String label;
  final PrintZone? frontZone;
  final PrintZone? backZone;

  PrintLayout get layout => PrintLayout(
    front: frontZone == null ? null : ZonePrint(frontZone!),
    back: backZone == null ? null : ZonePrint(backZone!),
  );

  /// [layout], keeping the brand-mark choice of [from].
  PrintLayout applyTo(PrintLayout from) =>
      layout.withBrandMark(from.brandMark);
}

/// Where a design prints on a t-shirt: at most one zone per face, at least
/// one face. Garment data, not design data — it never changes a recipe.
///
/// Shared by the Design Lab (which saves a signature's default into its pack)
/// and the app (the traveller's choice, which reaches the print files), so a
/// layout approved in the Lab is the one the app opens with.
class PrintLayout {
  const PrintLayout({this.front, this.back, this.brandMark = true})
    : assert(front != null || back != null, 'a layout must print something');

  /// Whether the small Roavvy mark ([BrandMark]) prints below the back
  /// collar. The traveller's (and the pack's) choice; it actually prints only
  /// when [printsMark].
  final bool brandMark;

  /// The mark's box on the back print file, in inches: centred, just below
  /// the collar line.
  static const Rect markInches = Rect.fromLTWH(4.75, 0.45, 2.5, 0.55);

  /// With the mark, the back design starts at least this far down, so the
  /// two never touch.
  static const double markClearInches = 1.4;

  /// The mark prints only on a shirt whose back is already printed — it never
  /// adds a back print of its own — and not when the back's design IS the
  /// back-neck print.
  bool get printsMark =>
      brandMark && back != null && back!.zone != PrintZone.backNeck;

  /// Why [brandMark] is on but nothing prints; null when it prints (or is off).
  String? get markBlockedReason {
    if (!brandMark || printsMark) return null;
    if (back == null) return 'Prints only with a back design';
    return 'The design is using the back neck';
  }

  PrintLayout withBrandMark(bool on) =>
      PrintLayout(front: front, back: back, brandMark: on);

  /// Where [side]'s design prints, in inches on its print file: its zone at
  /// its size — on the back, pushed below the mark when the mark prints
  /// (the bottom edge stays put, so a full back loses 1.4" of height).
  Rect? areaInches(PrintSide side) {
    final z = on(side);
    if (z == null) return null;
    final r = z.areaInches;
    if (side == PrintSide.front || !printsMark || r.top >= markClearInches) {
      return r;
    }
    return Rect.fromLTRB(r.left, markClearInches, r.right, r.bottom);
  }

  /// [areaInches], on the garment photograph.
  Rect? mockupRect(PrintSide side) {
    final z = on(side);
    if (z == null) return null;
    final m = z.mockupRect;
    final a = areaInches(side)!, r = z.areaInches;
    if (a == r) return m;
    final k = PrintZone.backPerInchY;
    return Rect.fromLTRB(
      m.left,
      m.top + (a.top - r.top) * k,
      m.right,
      m.bottom + (a.bottom - r.bottom) * k,
    );
  }

  /// The size [side] actually prints at (after the mark's clearance).
  String? sizeLabel(PrintSide side) {
    final a = areaInches(side);
    return a == null ? null : PrintZone.labelFor(a);
  }

  /// The mark's box on the back photograph.
  static Rect get markMockupRect => PrintZone.backInchesToMockup(markInches);

  /// The default: the design across the whole back.
  static const PrintLayout standard = PrintLayout(
    back: ZonePrint(PrintZone.fullBack),
  );

  final ZonePrint? front;
  final ZonePrint? back;

  ZonePrint? on(PrintSide side) => side == PrintSide.front ? front : back;

  bool prints(PrintSide side) => on(side) != null;

  /// The faces that print, back first (the primary design).
  List<ZonePrint> get faces => [
    if (back != null) back!,
    if (front != null) front!,
  ];

  /// [side] set to [zone] (null clears it). Refused — returns this — when it
  /// would leave nothing printing.
  PrintLayout withZone(PrintSide side, PrintZone? zone) {
    assert(zone == null || zone.side == side);
    final current = on(side);
    final next =
        zone == null
            ? null
            : ZonePrint(zone, scale: current?.zone == zone ? current!.scale : 1);
    final f = side == PrintSide.front ? next : front;
    final b = side == PrintSide.back ? next : back;
    if (f == null && b == null) return this;
    return PrintLayout(front: f, back: b, brandMark: brandMark);
  }

  PrintLayout withScale(PrintSide side, double scale) {
    final z = on(side);
    if (z == null) return this;
    return side == PrintSide.front
        ? PrintLayout(front: z.withScale(scale), back: back, brandMark: brandMark)
        : PrintLayout(front: front, back: z.withScale(scale), brandMark: brandMark);
  }

  /// The preset this layout's zones match, sizes aside; null is "custom".
  PrintLayoutPreset? get preset {
    for (final p in PrintLayoutPreset.values) {
      if (p.frontZone == front?.zone && p.backZone == back?.zone) return p;
    }
    return null;
  }

  /// A short description, e.g. `Left chest + Full back`.
  String get summary => [
    if (front != null) front!.zone.label,
    if (back != null) back!.zone.label,
  ].join(' + ');

  Map<String, Object?> toJson() => {
    if (front != null) 'front': front!.toJson(),
    if (back != null) 'back': back!.toJson(),
    if (!brandMark) 'mark': false,
  };

  /// Reads [toJson]. Anything unreadable (an empty map, a zone this build
  /// doesn't know, a zone on the wrong face) falls back to [standard] rather
  /// than failing — a layout is a default, never a reason not to sell a tee.
  static PrintLayout fromJson(Object? json) {
    if (json is! Map) return standard;
    final mark = json['mark'] != false;
    final f = ZonePrint.fromJson(json['front'], PrintSide.front);
    final b = ZonePrint.fromJson(json['back'], PrintSide.back);
    if (f == null && b == null) return standard.withBrandMark(mark);
    return PrintLayout(front: f, back: b, brandMark: mark);
  }

  @override
  bool operator ==(Object other) =>
      other is PrintLayout &&
      other.front == front &&
      other.back == back &&
      other.brandMark == brandMark;

  @override
  int get hashCode => Object.hash(front, back, brandMark);

  @override
  String toString() => 'PrintLayout($summary)';
}
