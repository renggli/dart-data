import 'dart:math' as math;

import 'package:data/numeric.dart';
import 'package:data/symbolic.dart';
import 'package:data/type.dart';

import '../model/environment.dart';
import '../model/value.dart';

/// Samples one or more symbolic [expressions] over `[minX, maxX]` using
/// adaptive curvature/discontinuity subdivision (`sampleCurve`) and robust
/// quantile auto-scaling.
PlotValue buildPlotValue(
  List<Expr> expressions,
  String variable,
  double minX,
  double maxX, {
  AngleMode angleMode = AngleMode.rad,
  int maxPoints = 512,
}) {
  final effectiveMinX = math.min(minX, maxX);
  final effectiveMaxX = math.max(minX, maxX) == effectiveMinX
      ? effectiveMinX + 10.0
      : math.max(minX, maxX);

  final curves = <PlotCurveData>[];
  final allFinanceY = <double>[];

  for (final expr in expressions) {
    final prepared = angleMode == AngleMode.deg
        ? _convertTrigArgToDegrees(expr, variable)
        : expr;
    final hasImaginary = _containsComplexConst(prepared);

    if (hasImaginary) {
      final fnC = prepared.toComplexFunction1D(variable);
      final reSample = sampleCurve(
        (x) => fnC(Complex(x)).real.toDouble(),
        effectiveMinX,
        effectiveMaxX,
        maxPoints: maxPoints,
      );
      final imSample = sampleCurve(
        (x) => fnC(Complex(x)).imaginary.toDouble(),
        effectiveMinX,
        effectiveMaxX,
        maxPoints: maxPoints,
      );
      final reSegs = [
        for (final s in reSample.segments)
          if (s.x.length > 0) PlotSegmentData(x: s.x.toList(), y: s.y.toList()),
      ];
      final imSegs = [
        for (final s in imSample.segments)
          if (s.x.length > 0) PlotSegmentData(x: s.x.toList(), y: s.y.toList()),
      ];
      for (final s in reSegs) {
        allFinanceY.addAll(s.y.where((v) => v.isFinite));
      }
      for (final s in imSegs) {
        allFinanceY.addAll(s.y.where((v) => v.isFinite));
      }
      curves.add(
        PlotCurveData(
          label: expr.toString(),
          exprText: expr.toString(),
          segments: reSegs,
          imaginarySegments: imSegs,
          markers: _detectRealMarkers(
            (x) => fnC(Complex(x)).real.toDouble(),
            effectiveMinX,
            effectiveMaxX,
          ),
        ),
      );
    } else {
      final fn = prepared.toFunction1D(variable);
      final sample = sampleCurve(
        fn,
        effectiveMinX,
        effectiveMaxX,
        maxPoints: maxPoints,
      );
      final segs = [
        for (final s in sample.segments)
          if (s.x.length > 0) PlotSegmentData(x: s.x.toList(), y: s.y.toList()),
      ];
      for (final s in segs) {
        allFinanceY.addAll(s.y.where((v) => v.isFinite));
      }
      curves.add(
        PlotCurveData(
          label: expr.toString(),
          exprText: expr.toString(),
          segments: segs,
          markers: _detectRealMarkers(fn, effectiveMinX, effectiveMaxX),
        ),
      );
    }
  }

  final (:minY, :maxY) = _computeRobustYRange(allFinanceY);
  return PlotValue(
    expressions: expressions,
    variable: variable,
    minX: effectiveMinX,
    maxX: effectiveMaxX,
    minY: minY,
    maxY: maxY,
    curves: curves,
  );
}

({double minY, double maxY}) _computeRobustYRange(List<double> values) {
  if (values.isEmpty) return (minY: -5.0, maxY: 5.0);
  final sorted = List<double>.of(values)..sort();
  final n = sorted.length;
  final loIdx = (n * 0.02).floor().clamp(0, n - 1);
  final hiIdx = (n * 0.98).ceil().clamp(0, n - 1);
  var lo = sorted[loIdx];
  var hi = sorted[hiIdx];

  // If quantile clipping did not blow up, prefer full min/max unless extreme
  final fullSpan = sorted.last - sorted.first;
  final clippedSpan = hi - lo;
  if (clippedSpan > 0 && fullSpan <= clippedSpan * 4.0) {
    lo = sorted.first;
    hi = sorted.last;
  }

  if ((hi - lo).abs() < 1e-9) {
    final center = (hi + lo) * 0.5;
    return (minY: center - 2.0, maxY: center + 2.0);
  }
  final pad = (hi - lo) * 0.12;
  return (minY: lo - pad, maxY: hi + pad);
}

List<PlotMarkerData> _detectRealMarkers(
  double Function(double) fn,
  double minX,
  double maxX,
) {
  final markers = <PlotMarkerData>[];
  const steps = 120;
  final dx = (maxX - minX) / steps;
  if (dx <= 0) return markers;

  var prevX = minX;
  var prevY = _safeCall(fn, prevX);

  for (var i = 1; i <= steps; i++) {
    final curX = minX + i * dx;
    final curY = _safeCall(fn, curX);
    if (prevY.isFinite && curY.isFinite) {
      if (prevY == 0.0) {
        _addUniqueMarker(markers, prevX, 0.0, 'root');
      } else if ((prevY < 0 && curY > 0) || (prevY > 0 && curY < 0)) {
        // Check not an asymptote jump
        final midY = _safeCall(fn, 0.5 * (prevX + curX));
        if (midY.isFinite && midY.abs() <= math.max(prevY.abs(), curY.abs())) {
          try {
            final rootX = solve(fn, prevX, b: curX);
            final rootY = _safeCall(fn, rootX);
            if (rootY.abs() < 1e-4) {
              _addUniqueMarker(markers, rootX, 0.0, 'root');
            }
          } catch (_) {
            // Ignore failed bracket root
          }
        }
      }
    }
    prevX = curX;
    prevY = curY;
  }
  return markers;
}

void _addUniqueMarker(
  List<PlotMarkerData> markers,
  double x,
  double y,
  String kind,
) {
  if (markers.length >= 16) return;
  for (final m in markers) {
    if (m.kind == kind && (m.x - x).abs() < 1e-4) return;
  }
  final cleanX = x.abs() < 1e-10 ? 0.0 : x;
  final cleanY = y.abs() < 1e-10 ? 0.0 : y;
  markers.add(
    PlotMarkerData(
      x: cleanX,
      y: cleanY,
      label: '(${formatRealDigits(cleanX, 4)}, ${formatRealDigits(cleanY, 4)})',
      kind: kind,
    ),
  );
}

double _safeCall(double Function(double) fn, double x) {
  try {
    return fn(x);
  } catch (_) {
    return double.nan;
  }
}

bool _containsComplexConst(Expr expr) => expr.anyNode(
  (n) =>
      (n is ComplexNumber && !n.imaginary.isZero) ||
      (n is Constant && !n.isReal),
);

Expr _convertTrigArgToDegrees(Expr expr, String variable) {
  final degFactor = Constant.pi / IntegerNumber.of(180);
  final mapped = expr.mapChildren(
    (child) => _convertTrigArgToDegrees(child, variable),
  );
  return switch (mapped) {
    Sin(:final expr) => Sin(expr * degFactor),
    Cos(:final expr) => Cos(expr * degFactor),
    Tan(:final expr) => Tan(expr * degFactor),
    _ => mapped,
  };
}
