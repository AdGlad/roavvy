import 'dart:math' as math;
import 'dart:ui' as ui;

/// Procedural clip-shape geometry: a registry of `id → ui.Path builder`. Every
/// builder returns a path fitted to the target [ui.Rect]; the [ClipStage] owns
/// placement (scale/aspect/position) and rotation, so builders only describe the
/// shape. Adding a procedural shape = add one entry here + a catalog entry.
typedef ShapePathBuilder = ui.Path Function(ui.Rect r, double cornerRadius);

class ShapeGeometry {
  const ShapeGeometry._();

  static final Map<String, ShapePathBuilder> _builders = {
    // Geometric
    'circle': (r, _) => ui.Path()..addOval(_squareIn(r)),
    'oval': (r, _) => ui.Path()..addOval(r),
    'roundedRect': (r, cr) => ui.Path()
      ..addRRect(ui.RRect.fromRectAndRadius(
          r, ui.Radius.circular(_radius(r, cr, 0.28)))),
    'arch': _arch,
    'diamond': (r, _) => _poly([
          r.topCenter,
          r.centerRight,
          r.bottomCenter,
          r.centerLeft,
        ]),
    'triangle': (r, _) => _poly([
          r.topCenter,
          r.bottomRight,
          r.bottomLeft,
        ]),
    'hexagon': (r, _) => _regularPolygon(r, 6, math.pi / 6),
    'shield': _shield,

    // Symbolic
    'heart': _heart,
    'star': (r, _) => _star(r, 5, 0.42),
    'lightning': _lightning,

    // Outdoor
    'mountain': _mountain,
    'wave': _wave,
    'island': _island,
    'sunset': _sunset,

    // Travel
    'mapPin': _mapPin,
    'compass': (r, _) => _star(r, 4, 0.34),
    'ticket': _ticket,
    'luggageTag': _luggageTag,
    'postageStamp': _postageStamp,
    'passportStamp': _passportStamp,
    'entryStamp': _entryStamp,
  };

  static bool has(String id) => _builders.containsKey(id);

  static ui.Path? build(String id, ui.Rect r, double cornerRadius) =>
      _builders[id]?.call(r, cornerRadius);

  // ── helpers ────────────────────────────────────────────────────────────

  static ui.Rect _squareIn(ui.Rect r) {
    final s = math.min(r.width, r.height);
    return ui.Rect.fromCenter(center: r.center, width: s, height: s);
  }

  static double _radius(ui.Rect r, double cr, double fallback) {
    final c = cr <= 0 ? fallback : cr;
    return math.min(r.width, r.height) * 0.5 * c.clamp(0.0, 1.0);
  }

  static ui.Path _poly(List<ui.Offset> pts) {
    final p = ui.Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      p.lineTo(pts[i].dx, pts[i].dy);
    }
    return p..close();
  }

  static ui.Path _regularPolygon(ui.Rect r, int sides, double rotation) {
    final cx = r.center.dx, cy = r.center.dy;
    final rx = r.width / 2, ry = r.height / 2;
    final p = ui.Path();
    for (var i = 0; i < sides; i++) {
      final a = rotation + i * 2 * math.pi / sides - math.pi / 2;
      final x = cx + rx * math.cos(a);
      final y = cy + ry * math.sin(a);
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    return p..close();
  }

  static ui.Path _star(ui.Rect r, int points, double innerRatio) {
    final cx = r.center.dx, cy = r.center.dy;
    final rx = r.width / 2, ry = r.height / 2;
    final p = ui.Path();
    for (var i = 0; i < points * 2; i++) {
      final rad = i.isEven ? 1.0 : innerRatio;
      final a = i * math.pi / points - math.pi / 2;
      final x = cx + rx * rad * math.cos(a);
      final y = cy + ry * rad * math.sin(a);
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    return p..close();
  }

  static ui.Path _arch(ui.Rect r, double cr) {
    // Rectangle with a semicircular top.
    final p = ui.Path();
    final radius = r.width / 2;
    p.moveTo(r.left, r.bottom);
    p.lineTo(r.left, r.top + radius);
    p.arcToPoint(ui.Offset(r.right, r.top + radius),
        radius: ui.Radius.circular(radius), clockwise: true);
    p.lineTo(r.right, r.bottom);
    p.close();
    return p;
  }

  static ui.Path _shield(ui.Rect r, double cr) {
    final p = ui.Path();
    final topR = r.width * 0.18;
    p.moveTo(r.left + topR, r.top);
    p.lineTo(r.right - topR, r.top);
    p.quadraticBezierTo(r.right, r.top, r.right, r.top + topR);
    p.lineTo(r.right, r.top + r.height * 0.45);
    // Curve down to a point at the bottom centre.
    p.cubicTo(
      r.right, r.top + r.height * 0.78,
      r.center.dx + r.width * 0.28, r.bottom - r.height * 0.02,
      r.center.dx, r.bottom,
    );
    p.cubicTo(
      r.center.dx - r.width * 0.28, r.bottom - r.height * 0.02,
      r.left, r.top + r.height * 0.78,
      r.left, r.top + r.height * 0.45,
    );
    p.lineTo(r.left, r.top + topR);
    p.quadraticBezierTo(r.left, r.top, r.left + topR, r.top);
    return p..close();
  }

  static ui.Path _heart(ui.Rect r, double cr) {
    const steps = 200;
    final pts = <ui.Offset>[];
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (var i = 0; i <= steps; i++) {
      final t = (i / steps) * 2 * math.pi;
      final x = 16 * math.pow(math.sin(t), 3).toDouble();
      final y = 13 * math.cos(t) -
          5 * math.cos(2 * t) -
          2 * math.cos(3 * t) -
          math.cos(4 * t);
      pts.add(ui.Offset(x, -y));
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, -y);
      maxY = math.max(maxY, -y);
    }
    final bw = maxX - minX, bh = maxY - minY;
    final s = math.min(r.width / bw, r.height / bh);
    final cx = r.center.dx - (minX + bw / 2) * s;
    final cy = r.center.dy - (minY + bh / 2) * s;
    final p = ui.Path();
    for (var i = 0; i < pts.length; i++) {
      final x = pts[i].dx * s + cx, y = pts[i].dy * s + cy;
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    return p..close();
  }

  static ui.Path _lightning(ui.Rect r, double cr) {
    double x(double f) => r.left + r.width * f;
    double y(double f) => r.top + r.height * f;
    return _poly([
      ui.Offset(x(0.62), y(0.0)),
      ui.Offset(x(0.20), y(0.55)),
      ui.Offset(x(0.48), y(0.55)),
      ui.Offset(x(0.36), y(1.0)),
      ui.Offset(x(0.82), y(0.40)),
      ui.Offset(x(0.52), y(0.40)),
    ]);
  }

  static ui.Path _mountain(ui.Rect r, double cr) {
    double x(double f) => r.left + r.width * f;
    double y(double f) => r.top + r.height * f;
    return _poly([
      ui.Offset(x(0.0), y(1.0)),
      ui.Offset(x(0.28), y(0.34)),
      ui.Offset(x(0.44), y(0.58)),
      ui.Offset(x(0.62), y(0.10)),
      ui.Offset(x(0.82), y(0.48)),
      ui.Offset(x(1.0), y(1.0)),
    ]);
  }

  static ui.Path _wave(ui.Rect r, double cr) {
    // A band whose top edge is a sine wave (fills below it).
    final p = ui.Path()..moveTo(r.left, r.bottom);
    const n = 48;
    for (var i = 0; i <= n; i++) {
      final t = i / n;
      final x = r.left + r.width * t;
      final y = r.top + r.height * (0.35 + 0.22 * math.sin(t * 2 * math.pi * 1.5));
      p.lineTo(x, y);
    }
    p.lineTo(r.right, r.bottom);
    return p..close();
  }

  static ui.Path _island(ui.Rect r, double cr) {
    // A rounded landmass: elliptical blob sitting slightly low.
    final cx = r.center.dx;
    final top = r.top + r.height * 0.22;
    final p = ui.Path()..moveTo(r.left + r.width * 0.06, r.top + r.height * 0.72);
    p.cubicTo(r.left, top, cx - r.width * 0.1, r.top, cx, r.top + r.height * 0.06);
    p.cubicTo(cx + r.width * 0.18, r.top, r.right, top,
        r.right - r.width * 0.05, r.top + r.height * 0.7);
    p.cubicTo(r.right - r.width * 0.05, r.bottom, r.left + r.width * 0.05,
        r.bottom, r.left + r.width * 0.06, r.top + r.height * 0.72);
    return p..close();
  }

  static ui.Path _sunset(ui.Rect r, double cr) {
    // Half-disc (sun on the horizon).
    final radius = r.width / 2;
    final cy = r.bottom;
    final p = ui.Path()..moveTo(r.left, cy);
    p.arcToPoint(ui.Offset(r.right, cy),
        radius: ui.Radius.circular(radius), clockwise: true);
    return p..close();
  }

  static ui.Path _mapPin(ui.Rect r, double cr) {
    // Teardrop: circle head with a point at the bottom.
    final cx = r.center.dx;
    final headR = r.width * 0.5;
    final headCy = r.top + headR;
    final p = ui.Path()..moveTo(cx, r.bottom);
    // left side up to the circle
    p.cubicTo(cx - headR * 0.55, r.top + r.height * 0.62, r.left,
        headCy + headR * 0.5, r.left, headCy);
    p.arcToPoint(ui.Offset(r.right, headCy),
        radius: ui.Radius.circular(headR), clockwise: true);
    p.cubicTo(r.right, headCy + headR * 0.5, cx + headR * 0.55,
        r.top + r.height * 0.62, cx, r.bottom);
    return p..close();
  }

  static ui.Path _ticket(ui.Rect r, double cr) {
    final radius = _radius(r, cr, 0.16);
    final notch = math.min(r.width, r.height) * 0.14;
    final p = ui.Path()
      ..addRRect(ui.RRect.fromRectAndRadius(r, ui.Radius.circular(radius)));
    // Punch two semicircle notches on the left and right mid-edges.
    final left = ui.Path()
      ..addOval(ui.Rect.fromCircle(
          center: ui.Offset(r.left, r.center.dy), radius: notch));
    final right = ui.Path()
      ..addOval(ui.Rect.fromCircle(
          center: ui.Offset(r.right, r.center.dy), radius: notch));
    return ui.Path.combine(ui.PathOperation.difference,
        ui.Path.combine(ui.PathOperation.difference, p, left), right);
  }

  static ui.Path _luggageTag(ui.Rect r, double cr) {
    final radius = _radius(r, cr, 0.22);
    final cut = r.width * 0.3;
    // Body with an angled top-left corner.
    final body = ui.Path()
      ..moveTo(r.left + cut, r.top)
      ..lineTo(r.right - radius, r.top)
      ..quadraticBezierTo(r.right, r.top, r.right, r.top + radius)
      ..lineTo(r.right, r.bottom - radius)
      ..quadraticBezierTo(r.right, r.bottom, r.right - radius, r.bottom)
      ..lineTo(r.left + radius, r.bottom)
      ..quadraticBezierTo(r.left, r.bottom, r.left, r.bottom - radius)
      ..lineTo(r.left, r.top + cut * 0.7)
      ..close();
    // Punch the string hole.
    final hole = ui.Path()
      ..addOval(ui.Rect.fromCircle(
          center: ui.Offset(r.left + cut * 0.55, r.top + cut * 0.55),
          radius: r.width * 0.06));
    return ui.Path.combine(ui.PathOperation.difference, body, hole);
  }

  static ui.Path _postageStamp(ui.Rect r, double cr) {
    // Rectangle with a scalloped (perforated) edge all around.
    final teeth = 11;
    final rr = math.min(r.width, r.height) / (teeth * 2.2);
    var body = ui.Path()..addRect(r);
    ui.Path punch = ui.Path();
    void addAlong(double x0, double y0, double dx, double dy, int count) {
      for (var i = 0; i <= count; i++) {
        final c = ui.Offset(x0 + dx * i, y0 + dy * i);
        punch.addOval(ui.Rect.fromCircle(center: c, radius: rr));
      }
    }

    final nx = (r.width / (rr * 2.2)).round();
    final ny = (r.height / (rr * 2.2)).round();
    addAlong(r.left, r.top, r.width / nx, 0, nx);
    addAlong(r.left, r.bottom, r.width / nx, 0, nx);
    addAlong(r.left, r.top, 0, r.height / ny, ny);
    addAlong(r.right, r.top, 0, r.height / ny, ny);
    return ui.Path.combine(ui.PathOperation.difference, body, punch);
  }

  static ui.Path _entryStamp(ui.Rect r, double cr) {
    // A passport arrival/departure stamp: a landscape rounded-rectangle block
    // with chamfered (cut) corners and a serrated top & bottom edge — reads as
    // an official border stamp, distinct from the round seal (passportStamp)
    // and the perforated square (postageStamp).
    final chamfer = math.min(r.width, r.height) * 0.16;
    final body = ui.Path()
      ..moveTo(r.left + chamfer, r.top)
      ..lineTo(r.right - chamfer, r.top)
      ..lineTo(r.right, r.top + chamfer)
      ..lineTo(r.right, r.bottom - chamfer)
      ..lineTo(r.right - chamfer, r.bottom)
      ..lineTo(r.left + chamfer, r.bottom)
      ..lineTo(r.left, r.bottom - chamfer)
      ..lineTo(r.left, r.top + chamfer)
      ..close();
    // Serrate the long edges with small notches for a rubber-stamp bite.
    final tooth = r.width / 22;
    final punch = ui.Path();
    for (var x = r.left + chamfer; x <= r.right - chamfer; x += tooth * 2) {
      punch.addOval(ui.Rect.fromCircle(
          center: ui.Offset(x, r.top), radius: tooth * 0.5));
      punch.addOval(ui.Rect.fromCircle(
          center: ui.Offset(x, r.bottom), radius: tooth * 0.5));
    }
    return ui.Path.combine(ui.PathOperation.difference, body, punch);
  }

  static ui.Path _passportStamp(ui.Rect r, double cr) {
    // Scalloped circle (a rubber-stamp seal).
    final cx = r.center.dx, cy = r.center.dy;
    final radius = math.min(r.width, r.height) / 2;
    const bumps = 26;
    final p = ui.Path();
    for (var i = 0; i <= bumps; i++) {
      final a = i * 2 * math.pi / bumps;
      final rad = radius * (i.isEven ? 1.0 : 0.9);
      final x = cx + rad * math.cos(a), y = cy + rad * math.sin(a);
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    return p..close();
  }
}
