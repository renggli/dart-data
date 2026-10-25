import 'dart:math' as math;
import 'dart:typed_data';

import 'package:data/linear.dart';
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
  Map<String, double>? parameterValues,
  int maxPoints = 512,
}) {
  final effectiveMinX = math.min(minX, maxX);
  final effectiveMaxX = math.max(minX, maxX) == effectiveMinX
      ? effectiveMinX + 10.0
      : math.max(minX, maxX);

  final paramSet = <String>{
    for (final expr in expressions) ...expr.freeVariables,
  }..remove(variable);
  final parameters = paramSet.toList()..sort();
  final substMap = <String, Expr>{
    for (final p in parameters) p: RealNumber(parameterValues?[p] ?? 1.0),
  };

  final curves = <PlotCurveData>[];
  final allFiniteY = <double>[];

  for (final expr in expressions) {
    final substituted = _substituteParams(expr, substMap);
    final prepared = angleMode == AngleMode.deg
        ? _convertTrigArgToDegrees(substituted, variable)
        : substituted;
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
          if (s.x.length > 0)
            PlotSegmentData(
              x: Float64List.fromList(s.x.toList()),
              y: Float64List.fromList(s.y.toList()),
            ),
      ];
      final imSegs = [
        for (final s in imSample.segments)
          if (s.x.length > 0)
            PlotSegmentData(
              x: Float64List.fromList(s.x.toList()),
              y: Float64List.fromList(s.y.toList()),
            ),
      ];
      for (final s in reSegs) {
        allFiniteY.addAll(s.y.where((v) => v.isFinite));
      }
      for (final s in imSegs) {
        allFiniteY.addAll(s.y.where((v) => v.isFinite));
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
          if (s.x.length > 0)
            PlotSegmentData(
              x: Float64List.fromList(s.x.toList()),
              y: Float64List.fromList(s.y.toList()),
            ),
      ];
      for (final s in segs) {
        allFiniteY.addAll(s.y.where((v) => v.isFinite));
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

  final (:minY, :maxY) = _computeRobustYRange(allFiniteY);
  return PlotValue(
    expressions: expressions,
    variable: variable,
    minX: effectiveMinX,
    maxX: effectiveMaxX,
    minY: minY,
    maxY: maxY,
    curves: curves,
    parameters: parameters,
  );
}

/// Samples a 2D parametric curve $(x(t), y(t))$ over $t \in [\text{minT}, \text{maxT}]$.
PlotValue buildParametricPlotValue(
  Expr xExpr,
  Expr yExpr,
  String variable,
  double minT,
  double maxT, {
  AngleMode angleMode = AngleMode.rad,
  Map<String, double>? parameterValues,
  int steps = 360,
}) {
  final t0 = math.min(minT, maxT);
  final t1 = math.max(minT, maxT) == t0
      ? t0 + 2 * math.pi
      : math.max(minT, maxT);
  final paramSet = <String>{...xExpr.freeVariables, ...yExpr.freeVariables}
    ..remove(variable);
  final parameters = paramSet.toList()..sort();
  final substMap = <String, Expr>{
    for (final p in parameters) p: RealNumber(parameterValues?[p] ?? 1.0),
  };

  final subX = _substituteParams(xExpr, substMap);
  final subY = _substituteParams(yExpr, substMap);
  final prepX = angleMode == AngleMode.deg
      ? _convertTrigArgToDegrees(subX, variable)
      : subX;
  final prepY = angleMode == AngleMode.deg
      ? _convertTrigArgToDegrees(subY, variable)
      : subY;

  final fnX = prepX.toFunction1D(variable);
  final fnY = prepY.toFunction1D(variable);

  final xs = <double>[];
  final ys = <double>[];
  final dt = (t1 - t0) / steps;
  for (var i = 0; i <= steps; i++) {
    final t = t0 + i * dt;
    final x = _safeCall(fnX, t);
    final y = _safeCall(fnY, t);
    if (x.isFinite && y.isFinite) {
      xs.add(x);
      ys.add(y);
    }
  }

  final segs = xs.isEmpty
      ? const <PlotSegmentData>[]
      : [
          PlotSegmentData(
            x: Float64List.fromList(xs),
            y: Float64List.fromList(ys),
          ),
        ];

  final (:minY, :maxY) = _computeRobustYRange(ys);
  final xRange = _computeRobustYRange(xs);

  return PlotValue(
    expressions: [xExpr, yExpr],
    variable: variable,
    minX: xRange.minY,
    maxX: xRange.maxY,
    minY: minY,
    maxY: maxY,
    curves: [
      PlotCurveData(
        label: '($xExpr, $yExpr)',
        exprText: '[$xExpr, $yExpr]',
        segments: segs,
      ),
    ],
    parameters: parameters,
    isParametric: true,
  );
}

/// Solves a first-order initial value problem $\frac{dy}{dt} = f(t, y), y(t_0) = y_0$
/// over $[t_0, t_1]$ using Dormand–Prince RK45 (`solveOde`) and returns a [PlotValue].
PlotValue buildOdePlotValue(
  Expr rhs,
  String tVar,
  String yVar,
  double y0,
  double t0,
  double t1, {
  int steps = 256,
}) {
  final vecFn = rhs.toVectorFunction([tVar, yVar]);
  final grid = linearSpaced(t0, t1, count: steps);
  final sol = solveOde(
    f: (t, y) {
      final dy = vecFn(
        Vector<double>.fromList([t, y[0]], type: DataType.float64),
      );
      return Vector<double>.fromList([dy], type: DataType.float64);
    },
    t0: t0,
    tEnd: t1,
    y0: Vector<double>.fromList([y0], type: DataType.float64),
    tEval: grid.toList(),
  );

  final xs = Float64List.fromList(sol.t);
  final ys = Float64List(sol.y.length);
  final finiteY = <double>[];
  for (var i = 0; i < sol.y.length; i++) {
    final v = sol.y[i][0];
    ys[i] = v;
    if (v.isFinite) finiteY.add(v);
  }

  final (:minY, :maxY) = _computeRobustYRange(finiteY);
  return PlotValue(
    expressions: [rhs],
    variable: tVar,
    minX: math.min(t0, t1),
    maxX: math.max(t0, t1),
    minY: minY,
    maxY: maxY,
    curves: [
      PlotCurveData(
        label:
            "y' = $rhs, y(${PlotValue.fmtBound(t0)}) = ${PlotValue.fmtBound(y0)}",
        exprText: rhs.toString(),
        segments: [PlotSegmentData(x: xs, y: ys)],
      ),
    ],
  );
}

/// Samples a multivariable expression $z = f(x, y)$ over an $N \times N$
/// grid on `[minX, maxX] × [minY, maxY]` and returns a 3D [PlotValue].
PlotValue buildSurface3dPlotValue(
  Expr expr,
  String xVar,
  double minX,
  double maxX,
  String yVar,
  double minY,
  double maxY, {
  Map<String, double> parameterValues = const {},
  int gridSize = 64,
}) {
  final freeParams = <String>{
    for (final v in expr.freeVariables)
      if (v != xVar && v != yVar) v,
  };
  final parameters = freeParams.toList()..sort();

  var evalExpr = expr;
  for (final p in parameters) {
    final val = parameterValues[p] ?? 1.0;
    evalExpr = evalExpr.substitute(p, RealNumber(val));
  }

  final vecFn = evalExpr.toVectorFunction([xVar, yVar]);
  final zValues = Float64List(gridSize * gridSize);
  final finiteZ = <double>[];
  final loX = math.min(minX, maxX);
  final hiX = math.max(minX, maxX);
  final loY = math.min(minY, maxY);
  final hiY = math.max(minY, maxY);

  final vecView = Vector<double>.filled(2, 0.0, type: DataType.float64);

  for (var iy = 0; iy < gridSize; iy++) {
    final v = iy / math.max(1, gridSize - 1);
    vecView.setUnchecked(1, loY + v * (hiY - loY));
    for (var ix = 0; ix < gridSize; ix++) {
      final u = ix / math.max(1, gridSize - 1);
      vecView.setUnchecked(0, loX + u * (hiX - loX));
      double z;
      try {
        z = vecFn(vecView);
      } catch (_) {
        z = double.nan;
      }
      zValues[iy * gridSize + ix] = z;
      if (z.isFinite) {
        finiteZ.add(z);
      }
    }
  }

  final zRange = _computeRobustYRange(finiteZ);
  return PlotValue(
    expressions: [expr],
    variable: '$xVar, $yVar',
    minX: loX,
    maxX: hiX,
    minY: loY,
    maxY: hiY,
    parameters: parameters,
    surface3d: Surface3dData(
      xVar: xVar,
      yVar: yVar,
      minX: loX,
      maxX: hiX,
      minY: loY,
      maxY: hiY,
      minZ: zRange.minY,
      maxZ: zRange.maxY,
      gridSize: gridSize,
      zValues: zValues,
    ),
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

Expr _substituteParams(Expr expr, Map<String, Expr> substMap) {
  var cur = expr;
  for (final entry in substMap.entries) {
    cur = cur.substitute(entry.key, entry.value);
  }
  return cur;
}

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
