import 'dart:math' as math;

import 'axis.dart';
import 'dataset.dart';
import 'style.dart';

/// Base class for all 3D datasets.
sealed class Dataset3D extends GraphDataset {
  /// Creates a 3D dataset.
  const new({required super.id, required super.label, super.visible = true});

  /// Enclosing 3D data bounds, or `null` if no finite geometry exists.
  Bounds3D? get bounds;
}

/// 3D heightfield surface `z = f(x, y)` on a rectilinear `(nx, ny)` grid.
final class Surface3DDataset extends Dataset3D {
  /// Creates a 3D surface dataset.
  const new({
    required super.id,
    required super.label,
    required this.nx,
    required this.ny,
    required this.xs,
    required this.ys,
    required this.zs,
    this.colormap = Colormap.viridis,
    this.wireframe = false,
    this.minLabel = '',
    this.maxLabel = '',
    super.visible = true,
  });

  /// Grid count along X.
  final int nx;

  /// Grid count along Y.
  final int ny;

  /// X coordinates of length [nx].
  final List<double> xs;

  /// Y coordinates of length [ny].
  final List<double> ys;

  /// Row-major height values (`iy * nx + ix`) of length `nx * ny`.
  final List<double> zs;

  /// Height-based colormap.
  final Colormap colormap;

  /// Whether to overlay wireframe grid lines.
  final bool wireframe;

  /// Optional low-end gradient label.
  final String minLabel;

  /// Optional high-end gradient label.
  final String maxLabel;

  @override
  LegendSwatch get swatch => GradientSwatch(
    colormap: colormap,
    minLabel: minLabel,
    maxLabel: maxLabel,
  );

  @override
  Bounds3D? get bounds {
    if (nx <= 0 || ny <= 0 || xs.length < nx || ys.length < ny) return null;
    var xMin = double.infinity;
    var xMax = double.negativeInfinity;
    var yMin = double.infinity;
    var yMax = double.negativeInfinity;
    var zMin = double.infinity;
    var zMax = double.negativeInfinity;

    for (var i = 0; i < nx; i++) {
      final x = xs[i];
      if (!x.isFinite) continue;
      if (x < xMin) xMin = x;
      if (x > xMax) xMax = x;
    }
    for (var j = 0; j < ny; j++) {
      final y = ys[j];
      if (!y.isFinite) continue;
      if (y < yMin) yMin = y;
      if (y > yMax) yMax = y;
    }
    final count = math.min(nx * ny, zs.length);
    var finiteZ = 0;
    for (var k = 0; k < count; k++) {
      final z = zs[k];
      if (!z.isFinite) continue;
      finiteZ++;
      if (z < zMin) zMin = z;
      if (z > zMax) zMax = z;
    }
    if (finiteZ == 0 || !xMin.isFinite || !yMin.isFinite) return null;
    if (zMin == zMax) {
      zMin -= 0.5;
      zMax += 0.5;
    }
    return Bounds3D(
      xMin: xMin,
      xMax: xMax,
      yMin: yMin,
      yMax: yMax,
      zMin: zMin,
      zMax: zMax,
    );
  }

  @override
  LegendReadout? readout(GraphProbe? probe) {
    if (probe is! Probe3D || nx <= 0 || ny <= 0 || zs.isEmpty) return null;
    final b = bounds;
    if (b == null) return null;
    if (probe.x < b.xMin ||
        probe.x > b.xMax ||
        probe.y < b.yMin ||
        probe.y > b.yMax) {
      return null;
    }
    final ix = (((probe.x - b.xMin) / b.xSpan) * (nx - 1)).round().clamp(
      0,
      nx - 1,
    );
    final iy = (((probe.y - b.yMin) / b.ySpan) * (ny - 1)).round().clamp(
      0,
      ny - 1,
    );
    final idx = iy * nx + ix;
    if (idx < 0 || idx >= zs.length) return null;
    final z = zs[idx];
    if (!z.isFinite) return null;
    return LegendReadout(valueText: 'z = ${formatGraphNumber(z)}');
  }
}

/// Parametric 3D space curve `(x(t), y(t), z(t))`.
final class Parametric3DDataset extends Dataset3D {
  /// Creates a 3D parametric curve dataset.
  const new({
    required super.id,
    required super.label,
    required this.ts,
    required this.xs,
    required this.ys,
    required this.zs,
    required this.color,
    this.radius = 1.5,
    super.visible = true,
  });

  /// Parameter values.
  final List<double> ts;

  /// Sampled X coordinates.
  final List<double> xs;

  /// Sampled Y coordinates.
  final List<double> ys;

  /// Sampled Z coordinates.
  final List<double> zs;

  /// CSS stroke/ribbon color.
  final String color;

  /// Nominal line/ribbon thickness.
  final double radius;

  @override
  LegendSwatch get swatch => LineSwatch(color: color);

  @override
  Bounds3D? get bounds {
    final n = math.min(xs.length, math.min(ys.length, zs.length));
    var xMin = double.infinity;
    var xMax = double.negativeInfinity;
    var yMin = double.infinity;
    var yMax = double.negativeInfinity;
    var zMin = double.infinity;
    var zMax = double.negativeInfinity;
    var count = 0;

    for (var i = 0; i < n; i++) {
      final x = xs[i];
      final y = ys[i];
      final z = zs[i];
      if (!x.isFinite || !y.isFinite || !z.isFinite) continue;
      count++;
      if (x < xMin) xMin = x;
      if (x > xMax) xMax = x;
      if (y < yMin) yMin = y;
      if (y > yMax) yMax = y;
      if (z < zMin) zMin = z;
      if (z > zMax) zMax = z;
    }
    if (count == 0) return null;
    if (xMin == xMax) {
      xMin -= 0.5;
      xMax += 0.5;
    }
    if (yMin == yMax) {
      yMin -= 0.5;
      yMax += 0.5;
    }
    if (zMin == zMax) {
      zMin -= 0.5;
      zMax += 0.5;
    }
    return Bounds3D(
      xMin: xMin,
      xMax: xMax,
      yMin: yMin,
      yMax: yMax,
      zMin: zMin,
      zMax: zMax,
    );
  }

  @override
  LegendReadout? readout(GraphProbe? probe) {
    if (probe is! Probe3D) return null;
    final n = math.min(
      ts.length,
      math.min(xs.length, math.min(ys.length, zs.length)),
    );
    var bestIdx = -1;
    var bestD2 = double.infinity;
    for (var i = 0; i < n; i++) {
      final x = xs[i];
      final y = ys[i];
      final z = zs[i];
      if (!x.isFinite || !y.isFinite || !z.isFinite) continue;
      final dx = x - probe.x;
      final dy = y - probe.y;
      final dz = z - probe.z;
      final d2 = dx * dx + dy * dy + dz * dz;
      if (d2 < bestD2) {
        bestD2 = d2;
        bestIdx = i;
      }
    }
    if (bestIdx < 0) return null;
    return LegendReadout(
      valueText:
          '(${formatGraphNumber(xs[bestIdx])}, ${formatGraphNumber(ys[bestIdx])}, ${formatGraphNumber(zs[bestIdx])})',
      detailText: 't = ${formatGraphNumber(ts[bestIdx])}',
    );
  }
}

/// Single sample in a 3D vector field.
class Field3DSample {
  /// Creates a 3D vector field sample.
  const new({
    required this.x,
    required this.y,
    required this.z,
    required this.vx,
    required this.vy,
    required this.vz,
  });

  /// Origin X coordinate.
  final double x;

  /// Origin Y coordinate.
  final double y;

  /// Origin Z coordinate.
  final double z;

  /// Vector X component.
  final double vx;

  /// Vector Y component.
  final double vy;

  /// Vector Z component.
  final double vz;

  /// Euclidean vector magnitude.
  double get magnitude => math.sqrt(vx * vx + vy * vy + vz * vz);
}

/// 3D vector field rendered as instanced arrows colored by magnitude.
final class VectorField3DDataset extends Dataset3D {
  /// Creates a 3D vector field dataset.
  const new({
    required super.id,
    required super.label,
    required this.samples,
    this.colormap = Colormap.plasma,
    this.scale = 1.0,
    super.visible = true,
  });

  /// Vector field samples.
  final List<Field3DSample> samples;

  /// Colormap mapped to vector magnitude.
  final Colormap colormap;

  /// Arrow length scale multiplier.
  final double scale;

  @override
  LegendSwatch get swatch => GradientSwatch(colormap: colormap);

  @override
  Bounds3D? get bounds {
    var xMin = double.infinity;
    var xMax = double.negativeInfinity;
    var yMin = double.infinity;
    var yMax = double.negativeInfinity;
    var zMin = double.infinity;
    var zMax = double.negativeInfinity;
    var count = 0;

    for (final s in samples) {
      if (!s.x.isFinite || !s.y.isFinite || !s.z.isFinite) continue;
      count++;
      if (s.x < xMin) xMin = s.x;
      if (s.x > xMax) xMax = s.x;
      if (s.y < yMin) yMin = s.y;
      if (s.y > yMax) yMax = s.y;
      if (s.z < zMin) zMin = s.z;
      if (s.z > zMax) zMax = s.z;
    }
    if (count == 0) return null;
    if (xMin == xMax) {
      xMin -= 0.5;
      xMax += 0.5;
    }
    if (yMin == yMax) {
      yMin -= 0.5;
      yMax += 0.5;
    }
    if (zMin == zMax) {
      zMin -= 0.5;
      zMax += 0.5;
    }
    return Bounds3D(
      xMin: xMin,
      xMax: xMax,
      yMin: yMin,
      yMax: yMax,
      zMin: zMin,
      zMax: zMax,
    );
  }

  @override
  LegendReadout? readout(GraphProbe? probe) {
    if (probe is! Probe3D || samples.isEmpty) return null;
    Field3DSample? best;
    var bestD2 = double.infinity;
    for (final s in samples) {
      final dx = s.x - probe.x;
      final dy = s.y - probe.y;
      final dz = s.z - probe.z;
      final d2 = dx * dx + dy * dy + dz * dz;
      if (d2 < bestD2) {
        bestD2 = d2;
        best = s;
      }
    }
    if (best == null) return null;
    return LegendReadout(
      valueText:
          '(${formatGraphNumber(best.vx)}, ${formatGraphNumber(best.vy)}, ${formatGraphNumber(best.vz)})',
      detailText: '|v| = ${formatGraphNumber(best.magnitude)}',
    );
  }
}

/// Complete 3D scene specification passed to `Renderer3D` and `GraphWidget`.
class Scene3D {
  /// Creates a 3D scene.
  const new({
    required this.datasets,
    this.xAxis = const AxisConfig(label: 'x'),
    this.yAxis = const AxisConfig(label: 'y'),
    this.zAxis = const AxisConfig(label: 'z'),
    this.initialBounds,
  });

  /// Ordered 3D datasets to display.
  final List<Dataset3D> datasets;

  /// X axis configuration.
  final AxisConfig xAxis;

  /// Y axis configuration.
  final AxisConfig yAxis;

  /// Z axis configuration.
  final AxisConfig zAxis;

  /// Optional explicit initial bounding box.
  final Bounds3D? initialBounds;

  /// Computes effective 3D bounds from [initialBounds] and visible datasets.
  Bounds3D? computeBounds() {
    if (initialBounds != null && initialBounds!.isValid) {
      return initialBounds;
    }
    return Bounds3D.union(
      datasets.where((d) => d.visible).map((d) => d.bounds),
    );
  }
}
