import 'dart:math' as math;
import 'dart:typed_data';

import 'package:data/linear.dart';
import 'package:data/numeric.dart';
import 'package:data/symbolic.dart';
import 'package:data/type.dart';

import '../model/value.dart';

/// Returns whether [expr] contains non-real complex constants or `i`.
bool containsComplexConst(Expr expr) => expr.anyNode(
  (n) =>
      (n is ComplexNumber && !n.imaginary.isZero) ||
      (n is Constant && !n.isReal),
);

/// Samples one or more symbolic [expressions] over `[minX, maxX]` using
/// adaptive curvature/discontinuity subdivision (`sampleCurve`).
PlotValue buildPlotValue(
  List<Expr> expressions,
  String variable,
  double minX,
  double maxX, {
  double? yMin,
  double? yMax,
  String? title,
  bool showGrid = true,
  bool showMarkers = true,
  Map<String, double>? parameterValues,
  int maxPoints = 1536,
}) {
  final effectiveMinX = math.min(minX, maxX);
  final effectiveMaxX = math.max(minX, maxX) == effectiveMinX
      ? effectiveMinX + 10.0
      : math.max(minX, maxX);
  final initialPoints = math.min(maxPoints, math.max(129, maxPoints ~/ 3));

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
    final prepared = _substituteParams(expr, substMap);
    final hasImaginary = containsComplexConst(prepared);

    if (hasImaginary) {
      final fnC = prepared.toComplexFunction1D(variable);
      final reSample = sampleCurve(
        (x) => fnC(Complex(x)).real.toDouble(),
        effectiveMinX,
        effectiveMaxX,
        initialPoints: initialPoints,
        maxPoints: maxPoints,
      );
      final imSample = sampleCurve(
        (x) => fnC(Complex(x)).imaginary.toDouble(),
        effectiveMinX,
        effectiveMaxX,
        initialPoints: initialPoints,
        maxPoints: maxPoints,
      );
      final reSegs = _toPlotSegments(reSample.segments, allFiniteY);
      final imSegs = _toPlotSegments(imSample.segments, allFiniteY);
      curves.add(
        PlotCurveData(
          label: expr.toString(),
          exprText: expr.toString(),
          segments: reSegs,
          imaginarySegments: imSegs,
          markers: showMarkers
              ? _detectRealMarkers(
                  (x) => fnC(Complex(x)).real.toDouble(),
                  effectiveMinX,
                  effectiveMaxX,
                )
              : const [],
        ),
      );
    } else {
      final fn = prepared.toFunction1D(variable);
      final sample = sampleCurve(
        fn,
        effectiveMinX,
        effectiveMaxX,
        initialPoints: initialPoints,
        maxPoints: maxPoints,
      );
      final segs = _toPlotSegments(sample.segments, allFiniteY);
      curves.add(
        PlotCurveData(
          label: expr.toString(),
          exprText: expr.toString(),
          segments: segs,
          markers: showMarkers
              ? _detectRealMarkers(fn, effectiveMinX, effectiveMaxX)
              : const [],
        ),
      );
    }
  }

  final autoRange = _computeRobustYRange(allFiniteY);
  return PlotValue(
    expressions: expressions,
    variable: variable,
    minX: effectiveMinX,
    maxX: effectiveMaxX,
    minY: yMin ?? autoRange.minY,
    maxY: yMax ?? autoRange.maxY,
    curves: curves,
    parameters: parameters,
    title: title,
    showGrid: showGrid,
    showMarkers: showMarkers,
  );
}

/// Samples a 2D parametric curve `(x(t), y(t))` over `[minT, maxT]`.
PlotValue buildParametricPlotValue(
  Expr xExpr,
  Expr yExpr,
  String variable,
  double minT,
  double maxT, {
  String? title,
  bool showGrid = true,
  Map<String, double>? parameterValues,
  int maxPoints = 4096,
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

  final fnX = _compileRealFn(_substituteParams(xExpr, substMap), variable);
  final fnY = _compileRealFn(_substituteParams(yExpr, substMap), variable);

  final sampled = _sampleParametric(
    (t) => (x: _safeCall(fnX, t), y: _safeCall(fnY, t)),
    t0,
    t1,
    maxPoints: maxPoints,
  );

  return PlotValue(
    expressions: [xExpr, yExpr],
    variable: variable,
    minX: sampled.minX,
    maxX: sampled.maxX,
    minY: sampled.minY,
    maxY: sampled.maxY,
    curves: [
      PlotCurveData(
        label: '($xExpr, $yExpr)',
        exprText: '[$xExpr, $yExpr]',
        segments: sampled.segments,
      ),
    ],
    parameters: parameters,
    isParametric: true,
    minT: t0,
    maxT: t1,
    title: title,
    showGrid: showGrid,
  );
}

/// Samples a 3D parametric space curve `(x(t), y(t), z(t))` over `[minT, maxT]`.
PlotValue buildParametric3dPlotValue(
  Expr xExpr,
  Expr yExpr,
  Expr zExpr,
  String variable,
  double minT,
  double maxT, {
  String? title,
  Map<String, double>? parameterValues,
  int maxPoints = 4096,
}) {
  final t0 = math.min(minT, maxT);
  final t1 = math.max(minT, maxT) == t0
      ? t0 + 2 * math.pi
      : math.max(minT, maxT);
  final paramSet = <String>{
    ...xExpr.freeVariables,
    ...yExpr.freeVariables,
    ...zExpr.freeVariables,
  }..remove(variable);
  final parameters = paramSet.toList()..sort();
  final substMap = <String, Expr>{
    for (final p in parameters) p: RealNumber(parameterValues?[p] ?? 1.0),
  };

  final fnX = _compileRealFn(_substituteParams(xExpr, substMap), variable);
  final fnY = _compileRealFn(_substituteParams(yExpr, substMap), variable);
  final fnZ = _compileRealFn(_substituteParams(zExpr, substMap), variable);

  final sampled = _sampleParametric3d(
    (t) => (x: _safeCall(fnX, t), y: _safeCall(fnY, t), z: _safeCall(fnZ, t)),
    t0,
    t1,
    maxPoints: maxPoints,
  );

  return PlotValue(
    expressions: [xExpr, yExpr, zExpr],
    variable: variable,
    minX: sampled.minX,
    maxX: sampled.maxX,
    minY: sampled.minY,
    maxY: sampled.maxY,
    parameters: parameters,
    isParametric: true,
    minT: t0,
    maxT: t1,
    title: title,
    parametric3d: Parametric3dData(
      tVar: variable,
      minT: t0,
      maxT: t1,
      minX: sampled.minX,
      maxX: sampled.maxX,
      minY: sampled.minY,
      maxY: sampled.maxY,
      minZ: sampled.minZ,
      maxZ: sampled.maxZ,
      tValues: sampled.tValues,
      xValues: sampled.xValues,
      yValues: sampled.yValues,
      zValues: sampled.zValues,
    ),
  );
}

/// Builds a domain-coloring complex plot value for `f(z)`.
PlotValue buildComplexPlotValue(
  Expr expr,
  String variable,
  double minRe,
  double maxRe,
  double minIm,
  double maxIm, {
  bool showContours = true,
  String? title,
}) {
  final loRe = math.min(minRe, maxRe);
  final hiRe = math.max(minRe, maxRe) == loRe
      ? loRe + 6.0
      : math.max(minRe, maxRe);
  final loIm = math.min(minIm, maxIm);
  final hiIm = math.max(minIm, maxIm) == loIm
      ? loIm + 6.0
      : math.max(minIm, maxIm);

  final paramSet = <String>{...expr.freeVariables}..remove(variable);
  final parameters = paramSet.toList()..sort();

  return PlotValue(
    expressions: [expr],
    variable: variable,
    minX: loRe,
    maxX: hiRe,
    minY: loIm,
    maxY: hiIm,
    curves: [
      PlotCurveData(
        label: 'ℂ: $expr',
        exprText: expr.toString(),
        segments: const [],
      ),
    ],
    parameters: parameters,
    isComplex: true,
    showContours: showContours,
    title: title,
  );
}

/// Samples a 3D analytic landscape of `f(z)` with height `|f(z)|` and phase coloring.
PlotValue buildComplex3dPlotValue(
  Expr expr,
  String variable,
  double minRe,
  double maxRe,
  double minIm,
  double maxIm, {
  Map<String, double> parameterValues = const {},
  int gridSize = 48,
  String? title,
}) {
  final loRe = math.min(minRe, maxRe);
  final hiRe = math.max(minRe, maxRe) == loRe
      ? loRe + 6.0
      : math.max(minRe, maxRe);
  final loIm = math.min(minIm, maxIm);
  final hiIm = math.max(minIm, maxIm) == loIm
      ? loIm + 6.0
      : math.max(minIm, maxIm);

  final paramSet = <String>{...expr.freeVariables}..remove(variable);
  final parameters = paramSet.toList()..sort();
  final substMap = <String, Expr>{
    for (final p in parameters) p: RealNumber(parameterValues[p] ?? 1.0),
  };

  final prepared = _substituteParams(expr, substMap);
  final fnC = prepared.toComplexFunction1D(variable);

  final zValues = Float64List(gridSize * gridSize);
  final phaseValues = Float64List(gridSize * gridSize);
  final finiteMag = <double>[];

  for (var iy = 0; iy < gridSize; iy++) {
    final v = iy / math.max(1, gridSize - 1);
    final im = loIm + v * (hiIm - loIm);
    for (var ix = 0; ix < gridSize; ix++) {
      final u = ix / math.max(1, gridSize - 1);
      final re = loRe + u * (hiRe - loRe);
      final idx = iy * gridSize + ix;
      Complex w;
      try {
        w = fnC(Complex(re, im));
      } on Object {
        w = Complex.nan;
      }
      final wRe = w.real.toDouble();
      final wIm = w.imaginary.toDouble();
      final mag = (wRe.isFinite && wIm.isFinite)
          ? math.sqrt(wRe * wRe + wIm * wIm)
          : double.nan;
      zValues[idx] = mag;
      phaseValues[idx] = mag.isFinite ? math.atan2(wIm, wRe) : double.nan;
      if (mag.isFinite) finiteMag.add(mag);
    }
  }

  final (:minZ, :maxZ) = _computeComplexHeightRange(finiteMag);
  return PlotValue(
    expressions: [expr],
    variable: variable,
    minX: loRe,
    maxX: hiRe,
    minY: loIm,
    maxY: hiIm,
    parameters: parameters,
    isComplex: true,
    title: title,
    surface3d: Surface3dData(
      xVar: 'Re($variable)',
      yVar: 'Im($variable)',
      minX: loRe,
      maxX: hiRe,
      minY: loIm,
      maxY: hiIm,
      minZ: minZ,
      maxZ: maxZ,
      gridSize: gridSize,
      zValues: zValues,
      phaseValues: phaseValues,
    ),
  );
}

/// Solves a first-order IVP `dy/dt = f(t, y), y(t0) = y0` over `[t0, t1]`.
PlotValue buildOdePlotValue(
  Expr rhs,
  String tVar,
  String yVar,
  double y0,
  double t0,
  double t1, {
  OdeMethod method = OdeMethod.rk4,
  int steps = 256,
  String? title,
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
    method: method,
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
            'd$yVar/d$tVar = $rhs, $yVar(${PlotValue.fmtBound(t0)}) = ${PlotValue.fmtBound(y0)}',
        exprText: rhs.toString(),
        segments: [PlotSegmentData(x: xs, y: ys)],
      ),
    ],
    isOde: true,
    title: title,
  );
}

/// Samples a 3D surface `z = f(x, y)` over `[minX, maxX] x [minY, maxY]`.
PlotValue buildSurface3dPlotValue(
  Expr expr,
  String xVar,
  double minX,
  double maxX,
  String yVar,
  double minY,
  double maxY, {
  Map<String, double> parameterValues = const {},
  int gridSize = 48,
  String? title,
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
      if (z.isFinite) finiteZ.add(z);
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
    title: title,
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

List<PlotSegmentData> _toPlotSegments(
  List<dynamic> rawSegments,
  List<double> allFiniteY,
) {
  final segs = <PlotSegmentData>[];
  for (final s in rawSegments) {
    final seg = s as ({Vector<double> x, Vector<double> y});
    if (seg.x.length > 0) {
      final xs = Float64List.fromList(seg.x.toList());
      final ys = Float64List.fromList(seg.y.toList());
      for (final y in ys) {
        if (y.isFinite) allFiniteY.add(y);
      }
      segs.add(PlotSegmentData(x: xs, y: ys));
    }
  }
  return segs;
}

({double minZ, double maxZ}) _computeComplexHeightRange(List<double> mags) {
  if (mags.isEmpty) return (minZ: 0.0, maxZ: 5.0);
  final sorted = List<double>.of(mags)..sort();
  final n = sorted.length;
  final lo = sorted.first;
  final p95 = sorted[(n * 0.95).floor().clamp(0, n - 1)];
  final hi = (sorted.last <= p95 * 2.5) ? sorted.last : p95;
  final minZ = lo < hi * 0.15 ? 0.0 : lo;
  if ((hi - minZ).abs() < 1e-9) {
    return (minZ: math.max(0.0, minZ - 1.0), maxZ: hi + 1.0);
  }
  return (minZ: minZ, maxZ: hi * 1.08);
}

({double minY, double maxY}) _computeRobustYRange(List<double> values) {
  if (values.isEmpty) return (minY: -5.0, maxY: 5.0);
  final sorted = List<double>.of(values)..sort();
  final n = sorted.length;
  final loIdx = (n * 0.02).floor().clamp(0, n - 1);
  final hiIdx = (n * 0.98).ceil().clamp(0, n - 1);
  var lo = sorted[loIdx];
  var hi = sorted[hiIdx];

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
        final midY = _safeCall(fn, 0.5 * (prevX + curX));
        if (midY.isFinite && midY.abs() <= math.max(prevY.abs(), curY.abs())) {
          try {
            final rootX = solve(fn, prevX, b: curX);
            final rootY = _safeCall(fn, rootX);
            if (rootY.abs() < 1e-4) {
              _addUniqueMarker(markers, rootX, 0.0, 'root');
            }
          } catch (_) {}
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

double Function(double) _compileRealFn(Expr expr, String variable) {
  if (containsComplexConst(expr)) {
    final fnC = expr.toComplexFunction1D(variable);
    return (t) => fnC(Complex(t)).real.toDouble();
  }
  return expr.toFunction1D(variable);
}

({
  List<PlotSegmentData> segments,
  double minX,
  double maxX,
  double minY,
  double maxY,
})
_sampleParametric(
  ({double x, double y}) Function(double t) evaluate,
  double t0,
  double t1, {
  int maxPoints = 4096,
}) {
  final initialPoints = math.min(maxPoints, math.max(129, maxPoints ~/ 16));
  final step = (t1 - t0) / (initialPoints - 1);
  const jitter = 1e-9 * 0.6180339887498949;
  final initialT = List<double>.generate(initialPoints, (i) {
    if (i == 0) return t0;
    if (i == initialPoints - 1) return t1;
    return t0 + (i + jitter) * step;
  });
  final initialPts = List<({double x, double y})>.generate(
    initialPoints,
    (i) => evaluate(initialT[i]),
  );

  final (scale: scaleX, center: centerX) = _estimateScaleAndCenter([
    for (final p in initialPts)
      if (p.x.isFinite) p.x,
  ]);
  final (scale: scaleY, center: centerY) = _estimateScaleAndCenter([
    for (final p in initialPts)
      if (p.y.isFinite) p.y,
  ]);

  const tolerance = 1.5e-3;
  final maxDepth = math.min(
    12,
    math.max(1, (math.log(maxPoints / initialPoints) / math.ln2).ceil() + 4),
  );
  var remainingBudget = maxPoints - initialPoints;
  final maxPerInterval = math.max(
    16,
    (maxPoints - initialPoints) ~/ math.max(1, initialPoints ~/ 4),
  );

  final outX = <double>[initialPts.first.x];
  final outY = <double>[initialPts.first.y];
  final outT = <double>[initialT.first];
  var intervalBudget = 0;

  void refine(
    double ta,
    ({double x, double y}) pa,
    double tb,
    ({double x, double y}) pb,
    int depth,
  ) {
    if (remainingBudget <= 0 || intervalBudget <= 0 || depth >= maxDepth) {
      outX.add(pb.x);
      outY.add(pb.y);
      outT.add(tb);
      return;
    }
    final tm = 0.5 * (ta + tb);
    if (tm <= ta || tm >= tb) {
      outX.add(pb.x);
      outY.add(pb.y);
      outT.add(tb);
      return;
    }
    final fa = pa.x.isFinite && pa.y.isFinite;
    final fb = pb.x.isFinite && pb.y.isFinite;
    if (!fa && !fb) {
      outX.add(pb.x);
      outY.add(pb.y);
      outT.add(tb);
      return;
    }
    final pm = evaluate(tm);
    remainingBudget--;
    intervalBudget--;
    final fm = pm.x.isFinite && pm.y.isFinite;

    if (fa != fb || !fm) {
      refine(ta, pa, tm, pm, depth + 1);
      refine(tm, pm, tb, pb, depth + 1);
      return;
    }

    final errX = (pm.x - 0.5 * (pa.x + pb.x)).abs() / scaleX;
    final errY = (pm.y - 0.5 * (pa.y + pb.y)).abs() / scaleY;
    final chordX = (pb.x - pa.x).abs() / scaleX;
    final chordY = (pb.y - pa.y).abs() / scaleY;

    if (errX > tolerance ||
        errY > tolerance ||
        (math.max(chordX, chordY) > 0.08 && depth < 6)) {
      refine(ta, pa, tm, pm, depth + 1);
      refine(tm, pm, tb, pb, depth + 1);
    } else {
      outX.add(pm.x);
      outY.add(pm.y);
      outT.add(tm);
      outX.add(pb.x);
      outY.add(pb.y);
      outT.add(tb);
    }
  }

  for (var i = 0; i < initialPoints - 1; i++) {
    intervalBudget = maxPerInterval;
    refine(initialT[i], initialPts[i], initialT[i + 1], initialPts[i + 1], 0);
  }

  final cutoffX = 100.0 * scaleX;
  final cutoffY = 100.0 * scaleY;
  final segments = <PlotSegmentData>[];
  var curX = <double>[];
  var curY = <double>[];
  var curT = <double>[];
  final finiteX = <double>[];
  final finiteY = <double>[];

  void flush() {
    if (curX.isNotEmpty) {
      segments.add(
        PlotSegmentData(
          x: Float64List.fromList(curX),
          y: Float64List.fromList(curY),
          t: Float64List.fromList(curT),
        ),
      );
      curX = <double>[];
      curY = <double>[];
      curT = <double>[];
    }
  }

  for (var i = 0; i < outX.length; i++) {
    final x = outX[i];
    final y = outY[i];
    final t = outT[i];
    if (!x.isFinite ||
        !y.isFinite ||
        (x - centerX).abs() > cutoffX ||
        (y - centerY).abs() > cutoffY) {
      flush();
      continue;
    }
    if (curX.isNotEmpty) {
      final jumpX = (x - curX.last).abs() / scaleX;
      final jumpY = (y - curY.last).abs() / scaleY;
      if (jumpX > 2.5 || jumpY > 2.5) flush();
    }
    curX.add(x);
    curY.add(y);
    curT.add(t);
    finiteX.add(x);
    finiteY.add(y);
  }
  flush();

  final xRange = _computeRobustYRange(finiteX);
  final yRange = _computeRobustYRange(finiteY);
  return (
    segments: segments,
    minX: xRange.minY,
    maxX: xRange.maxY,
    minY: yRange.minY,
    maxY: yRange.maxY,
  );
}

({
  Float64List tValues,
  Float64List xValues,
  Float64List yValues,
  Float64List zValues,
  double minX,
  double maxX,
  double minY,
  double maxY,
  double minZ,
  double maxZ,
})
_sampleParametric3d(
  ({double x, double y, double z}) Function(double t) evaluate,
  double t0,
  double t1, {
  int maxPoints = 4096,
}) {
  final initialPoints = math.min(maxPoints, math.max(129, maxPoints ~/ 16));
  final step = (t1 - t0) / (initialPoints - 1);
  const jitter = 1e-9 * 0.6180339887498949;
  final initialT = List<double>.generate(initialPoints, (i) {
    if (i == 0) return t0;
    if (i == initialPoints - 1) return t1;
    return t0 + (i + jitter) * step;
  });
  final initialPts = List<({double x, double y, double z})>.generate(
    initialPoints,
    (i) => evaluate(initialT[i]),
  );

  final (scale: scaleX, center: _) = _estimateScaleAndCenter([
    for (final p in initialPts)
      if (p.x.isFinite) p.x,
  ]);
  final (scale: scaleY, center: _) = _estimateScaleAndCenter([
    for (final p in initialPts)
      if (p.y.isFinite) p.y,
  ]);
  final (scale: scaleZ, center: _) = _estimateScaleAndCenter([
    for (final p in initialPts)
      if (p.z.isFinite) p.z,
  ]);

  const tolerance = 1.5e-3;
  final maxDepth = math.min(
    12,
    math.max(1, (math.log(maxPoints / initialPoints) / math.ln2).ceil() + 4),
  );
  var remainingBudget = maxPoints - initialPoints;
  final maxPerInterval = math.max(
    16,
    (maxPoints - initialPoints) ~/ math.max(1, initialPoints ~/ 4),
  );

  final outT = <double>[initialT.first];
  final outX = <double>[initialPts.first.x];
  final outY = <double>[initialPts.first.y];
  final outZ = <double>[initialPts.first.z];
  var intervalBudget = 0;

  void refine(
    double ta,
    ({double x, double y, double z}) pa,
    double tb,
    ({double x, double y, double z}) pb,
    int depth,
  ) {
    if (remainingBudget <= 0 || intervalBudget <= 0 || depth >= maxDepth) {
      outT.add(tb);
      outX.add(pb.x);
      outY.add(pb.y);
      outZ.add(pb.z);
      return;
    }
    final tm = 0.5 * (ta + tb);
    if (tm <= ta || tm >= tb) {
      outT.add(tb);
      outX.add(pb.x);
      outY.add(pb.y);
      outZ.add(pb.z);
      return;
    }
    final fa = pa.x.isFinite && pa.y.isFinite && pa.z.isFinite;
    final fb = pb.x.isFinite && pb.y.isFinite && pb.z.isFinite;
    if (!fa && !fb) {
      outT.add(tb);
      outX.add(pb.x);
      outY.add(pb.y);
      outZ.add(pb.z);
      return;
    }
    final pm = evaluate(tm);
    remainingBudget--;
    intervalBudget--;
    final fm = pm.x.isFinite && pm.y.isFinite && pm.z.isFinite;

    if (fa != fb || !fm) {
      refine(ta, pa, tm, pm, depth + 1);
      refine(tm, pm, tb, pb, depth + 1);
      return;
    }

    final errX = (pm.x - 0.5 * (pa.x + pb.x)).abs() / scaleX;
    final errY = (pm.y - 0.5 * (pa.y + pb.y)).abs() / scaleY;
    final errZ = (pm.z - 0.5 * (pa.z + pb.z)).abs() / scaleZ;
    final chordX = (pb.x - pa.x).abs() / scaleX;
    final chordY = (pb.y - pa.y).abs() / scaleY;
    final chordZ = (pb.z - pa.z).abs() / scaleZ;

    if (errX > tolerance ||
        errY > tolerance ||
        errZ > tolerance ||
        (math.max(chordX, math.max(chordY, chordZ)) > 0.08 && depth < 6)) {
      refine(ta, pa, tm, pm, depth + 1);
      refine(tm, pm, tb, pb, depth + 1);
    } else {
      outT.add(tm);
      outX.add(pm.x);
      outY.add(pm.y);
      outZ.add(pm.z);
      outT.add(tb);
      outX.add(pb.x);
      outY.add(pb.y);
      outZ.add(pb.z);
    }
  }

  for (var i = 0; i < initialPoints - 1; i++) {
    intervalBudget = maxPerInterval;
    refine(initialT[i], initialPts[i], initialT[i + 1], initialPts[i + 1], 0);
  }

  final finiteX = [
    for (final v in outX)
      if (v.isFinite) v,
  ];
  final finiteY = [
    for (final v in outY)
      if (v.isFinite) v,
  ];
  final finiteZ = [
    for (final v in outZ)
      if (v.isFinite) v,
  ];
  final xRange = _computeRobustYRange(finiteX);
  final yRange = _computeRobustYRange(finiteY);
  final zRange = _computeRobustYRange(finiteZ);
  return (
    tValues: Float64List.fromList(outT),
    xValues: Float64List.fromList(outX),
    yValues: Float64List.fromList(outY),
    zValues: Float64List.fromList(outZ),
    minX: xRange.minY,
    maxX: xRange.maxY,
    minY: yRange.minY,
    maxY: yRange.maxY,
    minZ: zRange.minY,
    maxZ: zRange.maxY,
  );
}

({double scale, double center}) _estimateScaleAndCenter(List<double> values) {
  if (values.isEmpty) return (scale: 1.0, center: 0.0);
  final sorted = List<double>.of(values)..sort();
  final center = sorted[sorted.length ~/ 2];
  final lo = sorted[(sorted.length * 0.1).floor()];
  final hi = sorted[((sorted.length - 1) * 0.9).ceil()];
  final span = (hi - lo).abs();
  if (span > 1e-9) return (scale: span, center: center);
  final fullSpan = (sorted.last - sorted.first).abs();
  if (fullSpan > 1e-9) return (scale: fullSpan, center: center);
  final maxAbs = math.max(sorted.first.abs(), sorted.last.abs());
  return (scale: maxAbs > 1e-9 ? maxAbs : 1.0, center: center);
}

Expr _substituteParams(Expr expr, Map<String, Expr> substMap) {
  var cur = expr;
  for (final entry in substMap.entries) {
    cur = cur.substitute(entry.key, entry.value);
  }
  return cur;
}
