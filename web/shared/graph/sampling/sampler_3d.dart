import 'dart:math' as math;
import 'dart:typed_data';

import '../model/dataset.dart';
import '../model/dataset_3d.dart';
import '../model/style.dart';

/// Samples a 3D heightfield surface `z = fn(x, y)` on a rectilinear `(nx, ny)` grid.
Surface3DDataset sampleSurface3D({
  required String id,
  required String label,
  required double Function(double x, double y) fn,
  required double xMin,
  required double xMax,
  required double yMin,
  required double yMax,
  int nx = 48,
  int ny = 48,
  Colormap colormap = Colormap.viridis,
  bool wireframe = false,
}) {
  final safeNx = math.max(2, nx);
  final safeNy = math.max(2, ny);
  final xs = Float64List(safeNx);
  final ys = Float64List(safeNy);
  final zs = Float64List(safeNx * safeNy);

  final dx = (xMax - xMin) / (safeNx - 1);
  final dy = (yMax - yMin) / (safeNy - 1);
  for (var i = 0; i < safeNx; i++) {
    xs[i] = i == safeNx - 1 ? xMax : xMin + i * dx;
  }
  for (var j = 0; j < safeNy; j++) {
    ys[j] = j == safeNy - 1 ? yMax : yMin + j * dy;
  }

  var zMin = double.infinity;
  var zMax = double.negativeInfinity;
  for (var j = 0; j < safeNy; j++) {
    final y = ys[j];
    for (var i = 0; i < safeNx; i++) {
      final x = xs[i];
      var z = double.nan;
      try {
        final v = fn(x, y);
        if (v.isFinite) {
          z = v;
          if (v < zMin) zMin = v;
          if (v > zMax) zMax = v;
        }
      } on Object {
        z = double.nan;
      }
      zs[j * safeNx + i] = z;
    }
  }

  return Surface3DDataset(
    id: id,
    label: label,
    nx: safeNx,
    ny: safeNy,
    xs: xs,
    ys: ys,
    zs: zs,
    colormap: colormap,
    wireframe: wireframe,
    minLabel: zMin.isFinite ? formatGraphNumber(zMin) : '',
    maxLabel: zMax.isFinite ? formatGraphNumber(zMax) : '',
  );
}

/// Samples a parametric 3D space curve `(x(t), y(t), z(t))` over `[tMin, tMax]`.
Parametric3DDataset sampleParametric3D({
  required String id,
  required String label,
  required ({double x, double y, double z}) Function(double t) fn,
  required double tMin,
  required double tMax,
  required String color,
  int samples = 300,
  double radius = 1.5,
}) {
  final count = math.max(8, samples);
  final ts = Float64List(count);
  final xs = Float64List(count);
  final ys = Float64List(count);
  final zs = Float64List(count);
  final dt = (tMax - tMin) / (count - 1);

  for (var i = 0; i < count; i++) {
    final t = i == count - 1 ? tMax : tMin + i * dt;
    ts[i] = t;
    try {
      final p = fn(t);
      xs[i] = p.x.isFinite ? p.x : double.nan;
      ys[i] = p.y.isFinite ? p.y : double.nan;
      zs[i] = p.z.isFinite ? p.z : double.nan;
    } on Object {
      xs[i] = double.nan;
      ys[i] = double.nan;
      zs[i] = double.nan;
    }
  }

  return Parametric3DDataset(
    id: id,
    label: label,
    ts: ts,
    xs: xs,
    ys: ys,
    zs: zs,
    color: color,
    radius: radius,
  );
}

/// Samples a 3D vector field `(vx, vy, vz)` on a regular `(nx, ny, nz)` grid.
VectorField3DDataset sampleVectorField3D({
  required String id,
  required String label,
  required ({double vx, double vy, double vz}) Function(
    double x,
    double y,
    double z,
  )
  fn,
  required double xMin,
  required double xMax,
  required double yMin,
  required double yMax,
  required double zMin,
  required double zMax,
  int nx = 6,
  int ny = 6,
  int nz = 6,
  Colormap colormap = Colormap.plasma,
  double scale = 1.0,
}) {
  final safeNx = math.max(2, nx);
  final safeNy = math.max(2, ny);
  final safeNz = math.max(2, nz);
  final samples = <Field3DSample>[];

  for (var k = 0; k < safeNz; k++) {
    final z = zMin + (k / (safeNz - 1)) * (zMax - zMin);
    for (var j = 0; j < safeNy; j++) {
      final y = yMin + (j / (safeNy - 1)) * (yMax - yMin);
      for (var i = 0; i < safeNx; i++) {
        final x = xMin + (i / (safeNx - 1)) * (xMax - xMin);
        try {
          final v = fn(x, y, z);
          if (v.vx.isFinite && v.vy.isFinite && v.vz.isFinite) {
            samples.add(
              Field3DSample(x: x, y: y, z: z, vx: v.vx, vy: v.vy, vz: v.vz),
            );
          }
        } on Object {
          // Skip singular points.
        }
      }
    }
  }

  return VectorField3DDataset(
    id: id,
    label: label,
    samples: samples,
    colormap: colormap,
    scale: scale,
  );
}
