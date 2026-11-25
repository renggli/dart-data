import 'dart:math' as math;
import 'dart:typed_data';

import 'axis.dart';
import 'dataset.dart';
import 'style.dart';

/// Rendering style for 1D-over-X curves and discrete series.
enum CurveRenderMode { continuous, step, stem, histogram, scatter }

/// Area fill configuration under or toward a baseline for a 2D curve.
class AreaFill {
  /// Creates an area fill specification.
  const new({this.baseline = 0.0, required this.color, this.opacity = 0.2});

  /// Horizontal baseline Y value.
  final double baseline;

  /// CSS fill color.
  final String color;

  /// Fill opacity in `[0, 1]`.
  final double opacity;
}

/// Annotated point marker rendered on top of a 2D plot.
class PointMarker {
  /// Creates a point marker.
  const new({
    required this.x,
    required this.y,
    this.label,
    this.color,
    this.radius = 4.0,
  });

  /// X coordinate in data space.
  final double x;

  /// Y coordinate in data space.
  final double y;

  /// Optional short label rendered beside the marker.
  final String? label;

  /// Optional override CSS color.
  final String? color;

  /// Marker radius in CSS pixels.
  final double radius;
}

/// Horizontal or vertical reference rule rendered across a 2D plot.
class ReferenceLine {
  /// Creates a reference line.
  const new({
    required this.value,
    this.isVertical = false,
    this.label,
    this.color = '#94a3b8',
    this.dashed = true,
  });

  /// Coordinate value along X (when [isVertical]) or Y.
  final double value;

  /// Whether the line is vertical (`x = value`) instead of horizontal.
  final bool isVertical;

  /// Optional text label.
  final String? label;

  /// CSS stroke color.
  final String color;

  /// Whether the rule is dashed.
  final bool dashed;
}

/// Base class for all 2D datasets.
sealed class Dataset2D extends GraphDataset {
  /// Creates a 2D dataset.
  const new({
    required super.id,
    required super.label,
    super.visible = true,
    this.yAxis = YAxisSide.left,
  });

  /// Vertical axis this dataset is bound to.
  final YAxisSide yAxis;

  /// Enclosing data bounds, or `null` if no finite points exist.
  Bounds2D? get bounds;
}

/// Explicit `y = f(x)` or discrete `(x_i, y_i)` 2D dataset.
final class Function2DDataset extends Dataset2D {
  /// Creates a 2D function/series dataset.
  const new({
    required super.id,
    required super.label,
    required this.xs,
    required this.ys,
    required this.color,
    super.visible = true,
    super.yAxis = YAxisSide.left,
    this.width = 2.0,
    this.dashed = false,
    this.mode = CurveRenderMode.continuous,
    this.fill,
    this.markers = const <PointMarker>[],
    this.references = const <ReferenceLine>[],
    this.evaluator,
    this.markerSampler,
    this.referenceSampler,
  });

  /// Sampled X coordinates.
  final List<double> xs;

  /// Sampled Y coordinates (`NaN` breaks continuous segments).
  final List<double> ys;

  /// CSS stroke/marker color.
  final String color;

  /// Stroke width in CSS pixels.
  final double width;

  /// Whether the stroke is dashed.
  final bool dashed;

  /// Curve rendering mode.
  final CurveRenderMode mode;

  /// Optional area fill.
  final AreaFill? fill;

  /// Optional annotated point markers.
  final List<PointMarker> markers;

  /// Optional reference lines associated with this dataset.
  final List<ReferenceLine> references;

  /// Optional evaluator used to resample when the viewport bounds change.
  final double Function(double x)? evaluator;

  /// Optional callback used to recompute markers (such as roots and extrema)
  /// whenever the visible X range changes via pan or zoom.
  final List<PointMarker> Function(double xMin, double xMax)? markerSampler;

  /// Optional callback used to recompute reference lines (such as vertical
  /// asymptotes) whenever the visible X range changes via pan or zoom.
  final List<ReferenceLine> Function(double xMin, double xMax)?
  referenceSampler;

  @override
  LegendSwatch get swatch =>
      mode == CurveRenderMode.scatter || mode == CurveRenderMode.stem
      ? MarkerSwatch(color: color)
      : LineSwatch(color: color, dashed: dashed, width: width);

  @override
  Bounds2D? get bounds {
    final n = math.min(xs.length, ys.length);
    var xMin = double.infinity;
    var xMax = double.negativeInfinity;
    var yMin = double.infinity;
    var yMax = double.negativeInfinity;
    var count = 0;

    for (var i = 0; i < n; i++) {
      final x = xs[i];
      final y = ys[i];
      if (!x.isFinite || !y.isFinite) continue;
      count++;
      if (x < xMin) xMin = x;
      if (x > xMax) xMax = x;
      if (y < yMin) yMin = y;
      if (y > yMax) yMax = y;
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
    if (yAxis == YAxisSide.right) {
      return Bounds2D(
        xMin: xMin,
        xMax: xMax,
        yMin: 0.0,
        yMax: 1.0,
        y2Min: yMin,
        y2Max: yMax,
      );
    }
    return Bounds2D(xMin: xMin, xMax: xMax, yMin: yMin, yMax: yMax);
  }

  @override
  LegendReadout? readout(GraphProbe? probe) {
    if (probe is! Probe2D) return null;
    final y = evaluateAt(probe.x);
    if (y == null || !y.isFinite) return null;
    return LegendReadout(valueText: formatGraphNumber(y));
  }

  /// Evaluates or interpolates the series at [x], or returns `null` if out of range.
  double? evaluateAt(double x) {
    if (!x.isFinite) return null;
    if (evaluator != null) {
      try {
        final y = evaluator!(x);
        return y.isFinite ? y : null;
      } catch (_) {
        return null;
      }
    }
    final n = math.min(xs.length, ys.length);
    if (n == 0) return null;

    if (mode == CurveRenderMode.scatter || mode == CurveRenderMode.stem) {
      var bestIdx = -1;
      var bestDist = double.infinity;
      for (var i = 0; i < n; i++) {
        if (!xs[i].isFinite || !ys[i].isFinite) continue;
        final d = (xs[i] - x).abs();
        if (d < bestDist) {
          bestDist = d;
          bestIdx = i;
        }
      }
      return bestIdx >= 0 ? ys[bestIdx] : null;
    }

    // Binary search assuming monotonic X; fall back to linear scan if needed.
    if (n >= 2 && xs.first <= xs.last) {
      if (x < xs.first || x > xs.last) return null;
      var lo = 0;
      var hi = n - 1;
      while (hi - lo > 1) {
        final mid = (lo + hi) >> 1;
        if (xs[mid] <= x) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      final x0 = xs[lo];
      final x1 = xs[hi];
      final y0 = ys[lo];
      final y1 = ys[hi];
      if (!y0.isFinite || !y1.isFinite) {
        if ((x - x0).abs() <= (x1 - x).abs() && y0.isFinite) return y0;
        return y1.isFinite ? y1 : null;
      }
      if (mode == CurveRenderMode.step || mode == CurveRenderMode.histogram) {
        return y0;
      }
      final dx = x1 - x0;
      if (dx == 0) return y0;
      return y0 + (y1 - y0) * ((x - x0) / dx);
    }

    return null;
  }
}

/// Parametric 2D curve `(x(t), y(t))`.
final class Parametric2DDataset extends Dataset2D {
  /// Creates a parametric 2D curve dataset.
  const new({
    required super.id,
    required super.label,
    required this.ts,
    required this.xs,
    required this.ys,
    required this.color,
    super.visible = true,
    super.yAxis = YAxisSide.left,
    this.width = 2.0,
    this.dashed = false,
  });

  /// Parameter values.
  final List<double> ts;

  /// Sampled X coordinates.
  final List<double> xs;

  /// Sampled Y coordinates.
  final List<double> ys;

  /// CSS stroke color.
  final String color;

  /// Stroke width in CSS pixels.
  final double width;

  /// Whether the stroke is dashed.
  final bool dashed;

  @override
  LegendSwatch get swatch =>
      LineSwatch(color: color, dashed: dashed, width: width);

  @override
  Bounds2D? get bounds {
    final n = math.min(xs.length, ys.length);
    var xMin = double.infinity;
    var xMax = double.negativeInfinity;
    var yMin = double.infinity;
    var yMax = double.negativeInfinity;
    var count = 0;

    for (var i = 0; i < n; i++) {
      final x = xs[i];
      final y = ys[i];
      if (!x.isFinite || !y.isFinite) continue;
      count++;
      if (x < xMin) xMin = x;
      if (x > xMax) xMax = x;
      if (y < yMin) yMin = y;
      if (y > yMax) yMax = y;
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
    return Bounds2D(xMin: xMin, xMax: xMax, yMin: yMin, yMax: yMax);
  }

  @override
  LegendReadout? readout(GraphProbe? probe) {
    if (probe is! Probe2D) return null;
    final n = math.min(ts.length, math.min(xs.length, ys.length));
    var bestIdx = -1;
    var bestD2 = double.infinity;
    for (var i = 0; i < n; i++) {
      final x = xs[i];
      final y = ys[i];
      if (!x.isFinite || !y.isFinite) continue;
      final dx = x - probe.x;
      final dy = y - probe.y;
      final d2 = dx * dx + dy * dy;
      if (d2 < bestD2) {
        bestD2 = d2;
        bestIdx = i;
      }
    }
    if (bestIdx < 0) return null;
    return LegendReadout(
      valueText:
          '(${formatGraphNumber(xs[bestIdx])}, ${formatGraphNumber(ys[bestIdx])})',
      detailText: 't = ${formatGraphNumber(ts[bestIdx])}',
    );
  }
}

/// Single sample of a 2D scalar or vector field.
class Field2DSample {
  /// Creates a 2D field sample.
  const new({
    required this.x,
    required this.y,
    this.u = 0.0,
    this.v = 0.0,
    this.scalar = 0.0,
  });

  /// Sample X coordinate.
  final double x;

  /// Sample Y coordinate.
  final double y;

  /// Horizontal vector component.
  final double u;

  /// Vertical vector component.
  final double v;

  /// Scalar magnitude or field value.
  final double scalar;
}

/// 2D raster/heatmap, vector field, or complex domain-coloring dataset.
final class Field2DDataset extends Dataset2D {
  /// Creates a 2D field dataset.
  const new({
    required super.id,
    required super.label,
    required this.cols,
    required this.rows,
    required this.domain,
    this.samples = const <Field2DSample>[],
    this.colormap = Colormap.viridis,
    this.showVectors = false,
    this.showRaster = true,
    this.rgbaPixels,
    this.minLabel = '',
    this.maxLabel = '',
    this.resampler,
    this.evaluator,
    super.visible = true,
    super.yAxis = YAxisSide.left,
  });

  /// Grid width in columns.
  final int cols;

  /// Grid height in rows.
  final int rows;

  /// Spatial domain of the field.
  final Bounds2D domain;

  /// Grid samples (length `cols * rows` when populated).
  final List<Field2DSample> samples;

  /// Colormap for scalar fields or phase coloring.
  final Colormap colormap;

  /// Whether to render vector arrows.
  final bool showVectors;

  /// Whether to render the RGBA raster underlay.
  final bool showRaster;

  /// Optional precomputed RGBA pixel buffer (`4 * cols * rows` bytes).
  final Uint8List? rgbaPixels;

  /// Low-end label for gradient swatch.
  final String minLabel;

  /// High-end label for gradient swatch.
  final String maxLabel;

  /// Optional callback to resample this field when viewport bounds or size change.
  final Field2DDataset Function(Bounds2D domain, {int? cols, int? rows})?
  resampler;

  /// Optional exact evaluator for hover readouts without storing all grid samples.
  final Field2DSample Function(double x, double y)? evaluator;

  @override
  LegendSwatch get swatch => colormap == Colormap.oklchPhase
      ? const PhaseSwatch()
      : GradientSwatch(
          colormap: colormap,
          minLabel: minLabel,
          maxLabel: maxLabel,
        );

  @override
  Bounds2D? get bounds => domain.isValid ? domain : null;

  @override
  LegendReadout? readout(GraphProbe? probe) {
    if (probe is! Probe2D) return null;
    if (probe.x < domain.xMin ||
        probe.x > domain.xMax ||
        probe.y < domain.yMin ||
        probe.y > domain.yMax) {
      return null;
    }
    final Field2DSample s;
    if (evaluator != null) {
      s = evaluator!(probe.x, probe.y);
    } else {
      if (cols <= 0 || rows <= 0 || samples.isEmpty) return null;
      final fx = (probe.x - domain.xMin) / domain.xSpan;
      final fy = (probe.y - domain.yMin) / domain.ySpan;
      final col = (fx * (cols - 1)).round().clamp(0, cols - 1);
      final row = (fy * (rows - 1)).round().clamp(0, rows - 1);
      final idx = row * cols + col;
      if (idx < 0 || idx >= samples.length) return null;
      s = samples[idx];
    }
    if (showVectors || colormap == Colormap.oklchPhase) {
      return LegendReadout(
        valueText: '(${formatGraphNumber(s.u)}, ${formatGraphNumber(s.v)})',
        detailText: '|v| = ${formatGraphNumber(s.scalar)}',
      );
    }
    return LegendReadout(valueText: formatGraphNumber(s.scalar));
  }
}

/// Complete 2D scene specification passed to `Renderer2D` and `GraphWidget`.
class Scene2D {
  /// Creates a 2D scene.
  const new({
    required this.datasets,
    this.xAxis = const AxisConfig(),
    this.yAxis = const AxisConfig(),
    this.y2Axis,
    this.initialBounds,
    this.equalAspect = false,
    this.references = const <ReferenceLine>[],
  });

  /// Ordered datasets to display.
  final List<Dataset2D> datasets;

  /// Horizontal axis configuration.
  final AxisConfig xAxis;

  /// Primary vertical axis configuration.
  final AxisConfig yAxis;

  /// Optional secondary vertical axis configuration.
  final AxisConfig? y2Axis;

  /// Optional explicit initial viewport bounds.
  final Bounds2D? initialBounds;

  /// Whether X and Y scales should preserve 1:1 aspect ratio.
  final bool equalAspect;

  /// Scene-level reference lines.
  final List<ReferenceLine> references;

  /// Computes effective data bounds from [initialBounds] and visible datasets.
  Bounds2D? computeBounds() {
    if (initialBounds != null && initialBounds!.isValid) {
      return initialBounds;
    }
    final visible = datasets.where((d) => d.visible).toList(growable: false);
    if (visible.isEmpty) return null;

    final leftBounds = Bounds2D.union(
      visible.where((d) => d.yAxis == YAxisSide.left).map((d) => d.bounds),
    );
    final rightBounds = Bounds2D.union(
      visible.where((d) => d.yAxis == YAxisSide.right).map((d) => d.bounds),
    );

    final xMin =
        xAxis.min ?? leftBounds?.xMin ?? rightBounds?.xMin ?? double.nan;
    final xMax =
        xAxis.max ?? leftBounds?.xMax ?? rightBounds?.xMax ?? double.nan;
    final yMin = yAxis.min ?? leftBounds?.yMin ?? 0.0;
    final yMax = yAxis.max ?? leftBounds?.yMax ?? 1.0;

    if (!xMin.isFinite || !xMax.isFinite || !yMin.isFinite || !yMax.isFinite) {
      return null;
    }

    return Bounds2D(
      xMin: xMin,
      xMax: xMax,
      yMin: yMin,
      yMax: yMax,
      y2Min: y2Axis?.min ?? rightBounds?.y2Min,
      y2Max: y2Axis?.max ?? rightBounds?.y2Max,
    );
  }
}
