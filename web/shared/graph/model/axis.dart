/// Which vertical axis a 2D dataset is plotted against.
enum YAxisSide { left, right }

/// Coordinate scaling applied to an axis.
enum AxisScale { linear, log10 }

/// Configuration for a single coordinate axis.
class AxisConfig {
  /// Creates an axis configuration.
  const new({
    this.label = '',
    this.scale = AxisScale.linear,
    this.min,
    this.max,
    this.isInteger = false,
  });

  /// Human-readable axis label.
  final String label;

  /// Linear or base-10 logarithmic scaling.
  final AxisScale scale;

  /// Optional explicit lower bound.
  final double? min;

  /// Optional explicit upper bound.
  final double? max;

  /// Whether ticks should snap to integer values.
  final bool isInteger;
}

/// Rectangular 2D data bounds with optional secondary Y axis bounds.
class Bounds2D {
  /// Creates 2D bounds.
  const new({
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
    this.y2Min,
    this.y2Max,
  });

  /// Combines multiple bounds into their minimal enclosing bounding box.
  static Bounds2D? union(Iterable<Bounds2D?> bounds) {
    var hasAny = false;
    var xMin = double.infinity;
    var xMax = double.negativeInfinity;
    var yMin = double.infinity;
    var yMax = double.negativeInfinity;
    var hasY2 = false;
    var y2Min = double.infinity;
    var y2Max = double.negativeInfinity;

    for (final b in bounds) {
      if (b == null || !b.isValid) continue;
      hasAny = true;
      if (b.xMin < xMin) xMin = b.xMin;
      if (b.xMax > xMax) xMax = b.xMax;
      if (b.yMin < yMin) yMin = b.yMin;
      if (b.yMax > yMax) yMax = b.yMax;
      final b2Min = b.y2Min;
      final b2Max = b.y2Max;
      if (b2Min != null && b2Max != null && b2Min.isFinite && b2Max.isFinite) {
        hasY2 = true;
        if (b2Min < y2Min) y2Min = b2Min;
        if (b2Max > y2Max) y2Max = b2Max;
      }
    }

    if (!hasAny) return null;
    return Bounds2D(
      xMin: xMin,
      xMax: xMax,
      yMin: yMin,
      yMax: yMax,
      y2Min: hasY2 ? y2Min : null,
      y2Max: hasY2 ? y2Max : null,
    );
  }

  /// Minimum X coordinate.
  final double xMin;

  /// Maximum X coordinate.
  final double xMax;

  /// Minimum primary Y coordinate.
  final double yMin;

  /// Maximum primary Y coordinate.
  final double yMax;

  /// Optional minimum secondary Y coordinate.
  final double? y2Min;

  /// Optional maximum secondary Y coordinate.
  final double? y2Max;

  /// Horizontal span.
  double get xSpan => xMax - xMin;

  /// Primary vertical span.
  double get ySpan => yMax - yMin;

  /// Secondary vertical span, if both secondary bounds are set.
  double? get y2Span {
    final min2 = y2Min;
    final max2 = y2Max;
    if (min2 == null || max2 == null) return null;
    return max2 - min2;
  }

  /// Whether primary bounds are finite and have positive span.
  bool get isValid =>
      xMin.isFinite &&
      xMax.isFinite &&
      yMin.isFinite &&
      yMax.isFinite &&
      xMax > xMin &&
      yMax > yMin;

  /// Returns a copy with selectively replaced fields.
  Bounds2D copyWith({
    double? xMin,
    double? xMax,
    double? yMin,
    double? yMax,
    double? y2Min,
    double? y2Max,
  }) => Bounds2D(
    xMin: xMin ?? this.xMin,
    xMax: xMax ?? this.xMax,
    yMin: yMin ?? this.yMin,
    yMax: yMax ?? this.yMax,
    y2Min: y2Min ?? this.y2Min,
    y2Max: y2Max ?? this.y2Max,
  );

  /// Returns bounds expanded to include `(x, y)` if finite.
  Bounds2D expandToInclude(double x, double y) {
    if (!x.isFinite || !y.isFinite) return this;
    return Bounds2D(
      xMin: x < xMin ? x : xMin,
      xMax: x > xMax ? x : xMax,
      yMin: y < yMin ? y : yMin,
      yMax: y > yMax ? y : yMax,
      y2Min: y2Min,
      y2Max: y2Max,
    );
  }
}

/// Box 3D data bounds.
class Bounds3D {
  /// Creates 3D bounds.
  const new({
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
    required this.zMin,
    required this.zMax,
  });

  /// Combines multiple 3D bounds into their minimal enclosing bounding box.
  static Bounds3D? union(Iterable<Bounds3D?> bounds) {
    var hasAny = false;
    var xMin = double.infinity;
    var xMax = double.negativeInfinity;
    var yMin = double.infinity;
    var yMax = double.negativeInfinity;
    var zMin = double.infinity;
    var zMax = double.negativeInfinity;

    for (final b in bounds) {
      if (b == null || !b.isValid) continue;
      hasAny = true;
      if (b.xMin < xMin) xMin = b.xMin;
      if (b.xMax > xMax) xMax = b.xMax;
      if (b.yMin < yMin) yMin = b.yMin;
      if (b.yMax > yMax) yMax = b.yMax;
      if (b.zMin < zMin) zMin = b.zMin;
      if (b.zMax > zMax) zMax = b.zMax;
    }

    if (!hasAny) return null;
    return Bounds3D(
      xMin: xMin,
      xMax: xMax,
      yMin: yMin,
      yMax: yMax,
      zMin: zMin,
      zMax: zMax,
    );
  }

  /// Minimum X coordinate.
  final double xMin;

  /// Maximum X coordinate.
  final double xMax;

  /// Minimum Y coordinate.
  final double yMin;

  /// Maximum Y coordinate.
  final double yMax;

  /// Minimum Z coordinate.
  final double zMin;

  /// Maximum Z coordinate.
  final double zMax;

  /// X span.
  double get xSpan => xMax - xMin;

  /// Y span.
  double get ySpan => yMax - yMin;

  /// Z span.
  double get zSpan => zMax - zMin;

  /// Whether all bounds are finite and have positive span.
  bool get isValid =>
      xMin.isFinite &&
      xMax.isFinite &&
      yMin.isFinite &&
      yMax.isFinite &&
      zMin.isFinite &&
      zMax.isFinite &&
      xMax > xMin &&
      yMax > yMin &&
      zMax > zMin;

  /// Returns a copy with selectively replaced fields.
  Bounds3D copyWith({
    double? xMin,
    double? xMax,
    double? yMin,
    double? yMax,
    double? zMin,
    double? zMax,
  }) => Bounds3D(
    xMin: xMin ?? this.xMin,
    xMax: xMax ?? this.xMax,
    yMin: yMin ?? this.yMin,
    yMax: yMax ?? this.yMax,
    zMin: zMin ?? this.zMin,
    zMax: zMax ?? this.zMax,
  );
}
