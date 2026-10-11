import 'dart:math' as math;

import '../../linear.dart';
import '../../type.dart';
import 'calculus.dart';

/// 1D and multivariate numerical optimization algorithms.

/// Method used for numerical optimization.
enum OptimizationMethod {
  /// 1D Brent minimization combining golden section search and parabolic interpolation.
  brent,

  /// Derivative-free Nelder-Mead downhill simplex algorithm.
  nelderMead,

  /// Quasi-Newton Broyden-Fletcher-Goldfarb-Shanno (BFGS) algorithm.
  bfgs,

  /// Limited-memory BFGS (L-BFGS) algorithm for high-dimensional problems.
  lbfgs,
}

/// Result of a numerical optimization.
class OptimizationResult {
  /// Constructs an optimization result.
  const new({
    required this.point,
    required this.value,
    required this.iterations,
    this.gradientNorm,
    this.converged = true,
  });

  /// The optimal parameter vector found by the optimizer.
  final Vector<double> point;

  /// The objective function value at [point].
  final double value;

  /// Number of iterations executed.
  final int iterations;

  /// The norm of the gradient at [point], if computed.
  final double? gradientNorm;

  /// Whether the optimizer converged within tolerance.
  final bool converged;

  /// Convenience getter returning the first coordinate `point[0]`, useful for 1D problems.
  double get point1D => point[0];

  @override
  String toString() =>
      'OptimizationResult(point: $point, value: $value, iterations: $iterations, converged: $converged)';
}

/// Defines lower and upper bounds for a coordinate in constrained optimization.
class BoxBound {
  /// Creates a box bound with optional [lower] and [upper] limits.
  const new({this.lower, this.upper});

  /// The lower bound, or `null` if unbounded below ($-\infty$).
  final double? lower;

  /// The upper bound, or `null` if unbounded above ($+\infty$).
  final double? upper;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoxBound && other.lower == lower && other.upper == upper;

  @override
  int get hashCode => Object.hash(lower, upper);

  @override
  String toString() => 'BoxBound(lower: $lower, upper: $upper)';
}

/// Minimizes a scalar objective [function] using the specified [method].
///
/// Conceptually, optimization finds the input parameters that produce
/// the lowest possible value of an objective surface.
/// Formally, it computes $\min_{\mathbf{x}} f(\mathbf{x})$ subject to optional box bounds
/// and constraints using the chosen [method] ([OptimizationMethod.nelderMead] by default
/// for unconstrained problems, [OptimizationMethod.bfgs] for constrained problems,
/// or [OptimizationMethod.brent] for 1D bounded problems).
///
/// For 1D problems, [a] and [b] can be provided to specify the bounded interval.
///
/// ```dart
/// final min = minimize(
///   (v) => (v[0] - 2.0) * (v[0] - 2.0) + (v[1] - 3.0) * (v[1] - 3.0),
///   initialPoint: Vector<double>.fromList([0.0, 0.0]),
/// );
/// print(min.point); // Vector([2.0, 3.0])
/// ```
OptimizationResult minimize(
  double Function(Vector<double>) function, {
  Vector<double>? initialPoint,
  OptimizationMethod? method,
  Vector<double> Function(Vector<double>)? gradient,
  List<BoxBound>? bounds,
  List<double Function(Vector<double>)>? inequalities,
  List<double Function(Vector<double>)>? equalities,
  double? a,
  double? b,
  double tolerance = 1e-8,
  int maxIterations = 500,
  double step = 1.0,
  int memorySize = 7,
}) {
  if (tolerance <= 0) {
    throw ArgumentError('Tolerance must be positive: $tolerance');
  }
  if (maxIterations <= 0) {
    throw ArgumentError('Max iterations must be positive: $maxIterations');
  }

  var init = initialPoint;
  var bnds = bounds;
  var resolvedMethod = method;

  if (init == null) {
    if (a != null && b != null) {
      init = Vector<double>.fromList([(a + b) / 2.0], type: DataType.float64);
      bnds ??= [BoxBound(lower: a, upper: b)];
      resolvedMethod ??= OptimizationMethod.brent;
    } else {
      throw ArgumentError(
        'Either initialPoint or both interval bounds a and b must be provided.',
      );
    }
  }

  if (init.length == 0) {
    throw ArgumentError('Initial point cannot be empty.');
  }

  final hasConstraints =
      (bnds != null && bnds.isNotEmpty) ||
      (inequalities != null && inequalities.isNotEmpty) ||
      (equalities != null && equalities.isNotEmpty);

  resolvedMethod ??= hasConstraints
      ? OptimizationMethod.bfgs
      : OptimizationMethod.nelderMead;

  if (resolvedMethod == OptimizationMethod.brent) {
    final low =
        a ??
        (bnds != null && bnds.isNotEmpty ? bnds[0].lower : null) ??
        (init[0] - 1.0);
    final high =
        b ??
        (bnds != null && bnds.isNotEmpty ? bnds[0].upper : null) ??
        (init[0] + 1.0);
    final res = _brentMinimize(
      (x) => function(Vector<double>.fromList([x], type: DataType.float64)),
      a: low,
      b: high,
      tolerance: tolerance,
      maxIterations: maxIterations,
    );
    return OptimizationResult(
      point: Vector<double>.fromList([res.point], type: DataType.float64),
      value: res.value,
      iterations: res.iterations,
      converged: true,
    );
  }

  if (hasConstraints) {
    final res = _minimizeConstrained(
      function,
      init,
      gradient: gradient,
      bounds: bnds,
      inequalities: inequalities,
      equalities: equalities,
      tolerance: tolerance,
      maxIterations: maxIterations,
    );
    return OptimizationResult(
      point: res.point,
      value: res.value,
      iterations: res.iterations,
      gradientNorm: res.gradientNorm,
      converged: res.converged,
    );
  }

  switch (resolvedMethod) {
    case OptimizationMethod.nelderMead:
      final res = _nelderMead(
        function,
        init,
        step: step,
        tolerance: tolerance,
        maxIterations: maxIterations,
      );
      return OptimizationResult(
        point: res.point,
        value: res.value,
        iterations: res.iterations,
        converged: true,
      );
    case OptimizationMethod.bfgs:
      final res = _bfgs(
        function,
        init,
        gradient: gradient,
        tolerance: tolerance,
        maxIterations: maxIterations,
      );
      return OptimizationResult(
        point: res.point,
        value: res.value,
        iterations: res.iterations,
        gradientNorm: res.gradientNorm,
        converged: res.gradientNorm <= tolerance,
      );
    case OptimizationMethod.lbfgs:
      final res = _lbfgs(
        function,
        init,
        gradient: gradient,
        memorySize: memorySize,
        tolerance: tolerance,
        maxIterations: maxIterations,
      );
      return OptimizationResult(
        point: res.point,
        value: res.value,
        iterations: res.iterations,
        gradientNorm: res.gradientNorm,
        converged: res.gradientNorm <= tolerance,
      );
    case OptimizationMethod.brent:
      throw StateError('Unreachable');
  }
}

({double point, double value, int iterations}) _brentMinimize(
  double Function(double) fn, {
  required double a,
  required double b,
  double tolerance = 1e-8,
  int maxIterations = 100,
}) {
  const goldenRatio = 0.38196601125010515179541316563436; // (3 - sqrt(5)) / 2

  var xA = a < b ? a : b;
  var xB = a < b ? b : a;
  var x = xA + goldenRatio * (xB - xA);
  var wVal = x;
  var vVal = wVal;
  var fx = fn(x);
  var fw = fx;
  var fv = fw;
  var dStep = 0.0;
  var eStep = 0.0;

  var iter = 0;
  for (; iter < maxIterations; iter++) {
    final xm = 0.5 * (xA + xB);
    final tol1 = 1e-10 * x.abs() + tolerance;
    final tol2 = 2.0 * tol1;

    if ((x - xm).abs() <= (tol2 - 0.5 * (xB - xA))) {
      break;
    }

    var pVal = 0.0;
    var qVal = 0.0;
    var rVal = 0.0;

    if (eStep.abs() > tol1) {
      rVal = (x - wVal) * (fx - fv);
      qVal = (x - vVal) * (fx - fw);
      pVal = (x - vVal) * qVal - (x - wVal) * rVal;
      qVal = 2.0 * (qVal - rVal);
      if (qVal > 0.0) pVal = -pVal;
      qVal = qVal.abs();
      final rTemp = eStep;
      eStep = dStep;
      if (pVal.abs() < (0.5 * qVal * rTemp).abs() &&
          pVal > qVal * (xA - x) &&
          pVal < qVal * (xB - x)) {
        dStep = pVal / qVal;
        final uVal = x + dStep;
        if (uVal - xA < tol2 || xB - uVal < tol2) {
          dStep = xm - x >= 0 ? tol1 : -tol1;
        }
      } else {
        eStep = x >= xm ? xA - x : xB - x;
        dStep = goldenRatio * eStep;
      }
    } else {
      eStep = x >= xm ? xA - x : xB - x;
      dStep = goldenRatio * eStep;
    }

    final uVal = dStep.abs() >= tol1
        ? x + dStep
        : x + (dStep > 0 ? tol1 : -tol1);
    final fu = fn(uVal);

    if (fu <= fx) {
      if (uVal >= x) {
        xA = x;
      } else {
        xB = x;
      }
      vVal = wVal;
      fv = fw;
      wVal = x;
      fw = fx;
      x = uVal;
      fx = fu;
    } else {
      if (uVal < x) {
        xA = uVal;
      } else {
        xB = uVal;
      }
      if (fu <= fw || wVal == x) {
        vVal = wVal;
        fv = fw;
        wVal = uVal;
        fw = fu;
      } else if (fu <= fv || vVal == x || vVal == wVal) {
        vVal = uVal;
        fv = fu;
      }
    }
  }

  return (point: x, value: fx, iterations: iter);
}

({Vector<double> point, double value, int iterations}) _nelderMead(
  double Function(Vector<double>) fn,
  Vector<double> initialPoint, {
  double step = 1.0,
  double tolerance = 1e-8,
  int maxIterations = 1000,
}) {
  final dim = initialPoint.length;
  final simplex = <Vector<double>>[initialPoint.copy()];
  for (var i = 0; i < dim; i++) {
    final vertex = initialPoint.copy();
    vertex[i] += vertex[i] == 0.0 ? step : vertex[i] * 0.05 + step;
    simplex.add(vertex);
  }

  final values = [for (final pt in simplex) fn(pt)];

  const alpha = 1.0; // reflection
  const gamma = 2.0; // expansion
  const rho = 0.5; // contraction
  const sigma = 0.5; // shrink

  var iter = 0;
  for (; iter < maxIterations; iter++) {
    final indices = List<int>.generate(dim + 1, (i) => i)
      ..sort((a, b) => values[a].compareTo(values[b]));

    final bestIdx = indices[0];
    final worstIdx = indices[dim];
    final secondWorstIdx = indices[dim - 1];

    var meanVal = 0.0;
    for (var i = 0; i <= dim; i++) {
      meanVal += values[i];
    }
    meanVal /= dim + 1;

    var variance = 0.0;
    for (var i = 0; i <= dim; i++) {
      final diff = values[i] - meanVal;
      variance += diff * diff;
    }
    if (math.sqrt(variance / (dim + 1)) < tolerance) {
      return (
        point: simplex[bestIdx],
        value: values[bestIdx],
        iterations: iter,
      );
    }

    final centroid = Vector<double>.filled(dim, 0.0, type: DataType.float64);
    for (var i = 0; i < dim; i++) {
      final idx = indices[i];
      for (var dimIdx = 0; dimIdx < dim; dimIdx++) {
        centroid[dimIdx] += simplex[idx][dimIdx];
      }
    }
    for (var dimIdx = 0; dimIdx < dim; dimIdx++) {
      centroid[dimIdx] /= dim;
    }

    // 1. Reflection
    final xR = centroid + (centroid - simplex[worstIdx]).scale(alpha);
    final fR = fn(xR);

    if (fR < values[secondWorstIdx] && fR >= values[bestIdx]) {
      simplex[worstIdx] = xR;
      values[worstIdx] = fR;
      continue;
    }

    // 2. Expansion
    if (fR < values[bestIdx]) {
      final xE = centroid + (xR - centroid).scale(gamma);
      final fE = fn(xE);
      if (fE < fR) {
        simplex[worstIdx] = xE;
        values[worstIdx] = fE;
      } else {
        simplex[worstIdx] = xR;
        values[worstIdx] = fR;
      }
      continue;
    }

    // 3. Contraction
    if (fR < values[worstIdx]) {
      final xC = centroid + (xR - centroid).scale(rho);
      final fC = fn(xC);
      if (fC <= fR) {
        simplex[worstIdx] = xC;
        values[worstIdx] = fC;
        continue;
      }
    } else {
      final xC = centroid + (simplex[worstIdx] - centroid).scale(rho);
      final fC = fn(xC);
      if (fC < values[worstIdx]) {
        simplex[worstIdx] = xC;
        values[worstIdx] = fC;
        continue;
      }
    }

    // 4. Shrink towards best vertex
    final xBest = simplex[bestIdx];
    for (var i = 1; i <= dim; i++) {
      final idx = indices[i];
      simplex[idx] = xBest + (simplex[idx] - xBest).scale(sigma);
      values[idx] = fn(simplex[idx]);
    }
  }

  final bestIdx = List<int>.generate(
    dim + 1,
    (i) => i,
  ).reduce((a, b) => values[a] < values[b] ? a : b);
  return (point: simplex[bestIdx], value: values[bestIdx], iterations: iter);
}

({Vector<double> point, double value, double gradientNorm, int iterations})
_bfgs(
  double Function(Vector<double>) fn,
  Vector<double> initialPoint, {
  Vector<double> Function(Vector<double>)? gradient,
  double tolerance = 1e-6,
  int maxIterations = 200,
}) {
  final gradFn =
      gradient ?? ((Vector<double> vec) => calculusGradient(fn, vec));
  final dim = initialPoint.length;
  var x = initialPoint.copy();
  var fx = fn(x);
  var grad = gradFn(x);

  var hMat = Matrix<double>.identity(dim, type: DataType.float64);

  var iter = 0;
  for (; iter < maxIterations; iter++) {
    final gNorm = grad.norm();
    if (gNorm < tolerance) {
      return (point: x, value: fx, gradientNorm: gNorm, iterations: iter);
    }

    final dir = -hMat.apply(grad);

    const c1 = 1e-4;
    var alpha = 1.0;
    final slope = grad.dot(dir);
    if (slope >= 0.0) {
      hMat = Matrix<double>.identity(dim, type: DataType.float64);
      final pReset = -grad;
      final slopeReset = grad.dot(pReset);
      var a = 1.0;
      while (fn(x + pReset.scale(a)) > fx + c1 * a * slopeReset && a > 1e-12) {
        a *= 0.5;
      }
      alpha = a;
    } else {
      while (fn(x + dir.scale(alpha)) > fx + c1 * alpha * slope &&
          alpha > 1e-12) {
        alpha *= 0.5;
      }
    }

    final step = (slope >= 0.0 ? -grad : dir).scale(alpha);
    final xNext = x + step;
    final fxNext = fn(xNext);
    final gNext = gradFn(xNext);
    final y = gNext - grad;

    final ys = y.dot(step);
    if (ys > 1e-10) {
      final rho = 1.0 / ys;
      final eye = Matrix<double>.identity(dim, type: DataType.float64);
      final syT = step.outer(y).scale(rho);
      final ysT = y.outer(step).scale(rho);
      final v1 = eye - syT;
      final v2 = eye - ysT;
      final ssT = step.outer(step).scale(rho);
      hMat = (v1 * hMat * v2) + ssT;
    }

    x = xNext;
    fx = fxNext;
    grad = gNext;
  }

  return (point: x, value: fx, gradientNorm: grad.norm(), iterations: iter);
}

({Vector<double> point, double value, double gradientNorm, int iterations})
_lbfgs(
  double Function(Vector<double>) fn,
  Vector<double> initialPoint, {
  Vector<double> Function(Vector<double>)? gradient,
  int memorySize = 7,
  double tolerance = 1e-6,
  int maxIterations = 200,
}) {
  final gradFn =
      gradient ?? ((Vector<double> vec) => calculusGradient(fn, vec));

  var x = initialPoint.copy();
  var fx = fn(x);
  var grad = gradFn(x);

  final sHistory = <Vector<double>>[];
  final yHistory = <Vector<double>>[];
  final rhoHistory = <double>[];

  var iter = 0;
  for (; iter < maxIterations; iter++) {
    final gradNorm = grad.norm();
    if (gradNorm < tolerance) {
      return (point: x, value: fx, gradientNorm: gradNorm, iterations: iter);
    }

    final qVec = grad.copy();
    final histLen = sHistory.length;
    final alphas = List<double>.filled(histLen, 0.0);

    for (var i = histLen - 1; i >= 0; i--) {
      alphas[i] = rhoHistory[i] * sHistory[i].dot(qVec);
      qVec.addScaled(yHistory[i], -alphas[i]);
    }

    var gamma = 1.0;
    if (histLen > 0) {
      final sLast = sHistory.last;
      final yLast = yHistory.last;
      gamma = sLast.dot(yLast) / yLast.dot(yLast);
    }
    final rVec = qVec.scale(gamma);

    for (var i = 0; i < histLen; i++) {
      final beta = rhoHistory[i] * yHistory[i].dot(rVec);
      rVec.addScaled(sHistory[i], alphas[i] - beta);
    }

    final searchDir = -rVec;

    const c1 = 1e-4;
    var alpha = 1.0;
    final slope = grad.dot(searchDir);
    final dir = slope < 0.0 ? searchDir : -grad;
    final effectiveSlope = slope < 0.0 ? slope : -grad.dot(grad);

    while (fn(x + dir.scale(alpha)) > fx + c1 * alpha * effectiveSlope &&
        alpha > 1e-12) {
      alpha *= 0.5;
    }

    final step = dir.scale(alpha);
    final xNext = x + step;
    final fxNext = fn(xNext);
    final gradNext = gradFn(xNext);
    final yGrad = gradNext - grad;

    final ys = yGrad.dot(step);
    if (ys > 1e-10) {
      if (sHistory.length >= memorySize) {
        sHistory.removeAt(0);
        yHistory.removeAt(0);
        rhoHistory.removeAt(0);
      }
      sHistory.add(step);
      yHistory.add(yGrad);
      rhoHistory.add(1.0 / ys);
    }

    x = xNext;
    fx = fxNext;
    grad = gradNext;
  }

  return (point: x, value: fx, gradientNorm: grad.norm(), iterations: iter);
}

({
  Vector<double> point,
  double value,
  double gradientNorm,
  int iterations,
  bool converged,
})
_minimizeConstrained(
  double Function(Vector<double>) fn,
  Vector<double> initialPoint, {
  Vector<double> Function(Vector<double>)? gradient,
  List<BoxBound>? bounds,
  List<double Function(Vector<double>)>? inequalities,
  List<double Function(Vector<double>)>? equalities,
  double tolerance = 1e-6,
  int maxIterations = 200,
}) {
  final dim = initialPoint.length;
  if (dim == 0) {
    throw ArgumentError('Initial point cannot be empty.');
  }
  if (tolerance <= 0) {
    throw ArgumentError('Tolerance must be positive: $tolerance');
  }
  if (maxIterations <= 0) {
    throw ArgumentError('Max iterations must be positive: $maxIterations');
  }
  if (bounds != null && bounds.isNotEmpty && bounds.length != dim) {
    throw ArgumentError(
      'Bounds length (${bounds.length}) must match initial point dimension ($dim).',
    );
  }

  final baseGradFn =
      gradient ?? ((Vector<double> vec) => calculusGradient(fn, vec));

  final boxTransform = _BoxTransform(
    bounds != null && bounds.isNotEmpty ? bounds : null,
  );

  final parsedIneqs = <_Constraint>[
    if (inequalities != null)
      for (final ineq in inequalities) _Constraint(ineq, isInequality: true),
  ];
  final parsedEqs = <_Constraint>[
    if (equalities != null)
      for (final eq in equalities) _Constraint(eq, isInequality: false),
  ];

  final hasGeneralConstraints = parsedIneqs.isNotEmpty || parsedEqs.isNotEmpty;

  if (!hasGeneralConstraints) {
    final y0 = boxTransform.toY(initialPoint);
    double transformedFn(Vector<double> y) => fn(boxTransform.toX(y));

    Vector<double> transformedGrad(Vector<double> y) {
      final x = boxTransform.toX(y);
      final gradX = baseGradFn(x);
      return boxTransform.chainRuleGradient(gradX, y);
    }

    final bfgsResult = _bfgs(
      transformedFn,
      y0,
      gradient: transformedGrad,
      tolerance: tolerance,
      maxIterations: maxIterations,
    );

    final xAtEnd = boxTransform.toX(bfgsResult.point);
    final gradAtEnd = baseGradFn(xAtEnd);
    final finalPoint = boxTransform.projectToFeasible(
      xAtEnd,
      gradX: gradAtEnd,
      tolerance: tolerance,
    );
    final finalVal = fn(finalPoint);
    return (
      point: finalPoint,
      value: finalVal,
      gradientNorm: bfgsResult.gradientNorm,
      iterations: bfgsResult.iterations,
      converged: bfgsResult.gradientNorm <= tolerance,
    );
  }

  var currentPoint = initialPoint.copy();
  var currentY = boxTransform.toY(currentPoint);
  currentPoint = boxTransform.toX(currentY);

  final numIneq = parsedIneqs.length;
  final numEq = parsedEqs.length;
  final lambda = List<double>.filled(numIneq, 0.0);
  final nu = List<double>.filled(numEq, 0.0);
  var mu = 10.0;
  var prevViolation = double.infinity;
  var totalIterations = 0;
  var isConverged = false;
  var lastGradNorm = 0.0;

  final maxOuter = math.min(30, math.max(5, maxIterations ~/ 5));
  for (var outer = 0; outer < maxOuter; outer++) {
    final remainingIterations = maxIterations - totalIterations;
    if (remainingIterations <= 0) break;

    double augmentedLagrangian(Vector<double> x) {
      var val = fn(x);
      for (var j = 0; j < numIneq; j++) {
        final gj = parsedIneqs[j].evaluate(x);
        final psi = math.max(0.0, lambda[j] + mu * gj);
        val += 0.5 / mu * (psi * psi - lambda[j] * lambda[j]);
      }
      for (var k = 0; k < numEq; k++) {
        final hk = parsedEqs[k].evaluate(x);
        val += nu[k] * hk + 0.5 * mu * hk * hk;
      }
      return val;
    }

    Vector<double> augmentedLagrangianGrad(Vector<double> x) {
      final gradX = baseGradFn(x).copy();
      for (var j = 0; j < numIneq; j++) {
        final gj = parsedIneqs[j].evaluate(x);
        final psi = math.max(0.0, lambda[j] + mu * gj);
        if (psi > 0.0) {
          final gradG = parsedIneqs[j].gradient(x);
          gradX.addScaled(gradG, psi);
        }
      }
      for (var k = 0; k < numEq; k++) {
        final hk = parsedEqs[k].evaluate(x);
        final gradH = parsedEqs[k].gradient(x);
        gradX.addScaled(gradH, nu[k] + mu * hk);
      }
      return gradX;
    }

    double transformedAugmentedLagrangian(Vector<double> y) =>
        augmentedLagrangian(boxTransform.toX(y));

    Vector<double> transformedAugmentedLagrangianGrad(Vector<double> y) {
      final x = boxTransform.toX(y);
      final gradX = augmentedLagrangianGrad(x);
      return boxTransform.chainRuleGradient(gradX, y);
    }

    final innerMax = math.max(10, remainingIterations);
    final subResult = _bfgs(
      transformedAugmentedLagrangian,
      currentY,
      gradient: transformedAugmentedLagrangianGrad,
      tolerance: math.max(tolerance * 0.1, 1e-8),
      maxIterations: innerMax,
    );

    totalIterations += subResult.iterations;
    currentY = subResult.point;
    currentPoint = boxTransform.toX(currentY);
    lastGradNorm = subResult.gradientNorm;

    var maxViolation = 0.0;
    for (var j = 0; j < numIneq; j++) {
      final gj = parsedIneqs[j].evaluate(currentPoint);
      if (gj > maxViolation) maxViolation = gj;
    }
    for (var k = 0; k < numEq; k++) {
      final hk = parsedEqs[k].evaluate(currentPoint).abs();
      if (hk > maxViolation) maxViolation = hk;
    }

    for (var j = 0; j < numIneq; j++) {
      final gj = parsedIneqs[j].evaluate(currentPoint);
      lambda[j] = math.max(0.0, lambda[j] + mu * gj);
    }
    for (var k = 0; k < numEq; k++) {
      final hk = parsedEqs[k].evaluate(currentPoint);
      nu[k] += mu * hk;
    }

    if (maxViolation <= tolerance && subResult.gradientNorm <= tolerance * 10) {
      isConverged = true;
      break;
    }

    if (maxViolation > 0.25 * prevViolation) {
      mu = math.min(mu * 10.0, 1e8);
    }
    prevViolation = maxViolation;
  }

  final finalPoint = boxTransform.projectToFeasible(
    currentPoint,
    gradX: baseGradFn(currentPoint),
    tolerance: tolerance,
  );
  final finalVal = fn(finalPoint);

  return (
    point: finalPoint,
    value: finalVal,
    gradientNorm: lastGradNorm,
    iterations: totalIterations,
    converged: isConverged,
  );
}

class _BoxTransform {
  new(this.bounds) {
    if (bounds != null) {
      for (var i = 0; i < bounds!.length; i++) {
        final b = bounds![i];
        final lower = (b.lower == null || b.lower!.isInfinite) ? null : b.lower;
        final upper = (b.upper == null || b.upper!.isInfinite) ? null : b.upper;
        if (lower != null && upper != null && lower >= upper) {
          throw ArgumentError(
            'Lower bound ($lower) must be strictly less than upper bound ($upper) at index $i.',
          );
        }
      }
    }
  }

  final List<BoxBound>? bounds;

  Vector<double> toX(Vector<double> y) {
    if (bounds == null) return y.copy();
    final dim = y.length;
    final x = Vector<double>.filled(dim, 0.0, type: DataType.float64);
    for (var i = 0; i < dim; i++) {
      final b = bounds![i];
      final lower = (b.lower == null || b.lower!.isInfinite) ? null : b.lower;
      final upper = (b.upper == null || b.upper!.isInfinite) ? null : b.upper;
      final yi = y[i];
      if (lower != null && upper != null) {
        x[i] = lower + (upper - lower) * _sigmoid(yi);
      } else if (lower != null) {
        final clampedYi = yi.clamp(-50.0, 50.0);
        x[i] = lower + math.exp(clampedYi);
      } else if (upper != null) {
        final clampedYi = yi.clamp(-50.0, 50.0);
        x[i] = upper - math.exp(-clampedYi);
      } else {
        x[i] = yi;
      }
    }
    return x;
  }

  Vector<double> toY(Vector<double> x) {
    if (bounds == null) return x.copy();
    final dim = x.length;
    final y = Vector<double>.filled(dim, 0.0, type: DataType.float64);
    for (var i = 0; i < dim; i++) {
      final b = bounds![i];
      final lower = (b.lower == null || b.lower!.isInfinite) ? null : b.lower;
      final upper = (b.upper == null || b.upper!.isInfinite) ? null : b.upper;
      final xi = x[i];
      if (lower != null && upper != null) {
        final span = upper - lower;
        final t = ((xi - lower) / span).clamp(0.01, 0.99);
        y[i] = math.log(t / (1.0 - t));
      } else if (lower != null) {
        final d = math.max(xi - lower, 0.1);
        y[i] = math.log(d);
      } else if (upper != null) {
        final d = math.max(upper - xi, 0.1);
        y[i] = -math.log(d);
      } else {
        y[i] = xi;
      }
    }
    return y;
  }

  Vector<double> chainRuleGradient(Vector<double> gradX, Vector<double> y) {
    if (bounds == null) return gradX.copy();
    final dim = y.length;
    final gradY = Vector<double>.filled(dim, 0.0, type: DataType.float64);
    for (var i = 0; i < dim; i++) {
      final b = bounds![i];
      final lower = (b.lower == null || b.lower!.isInfinite) ? null : b.lower;
      final upper = (b.upper == null || b.upper!.isInfinite) ? null : b.upper;
      final yi = y[i];
      final double dxiDyi;
      if (lower != null && upper != null) {
        dxiDyi = (upper - lower) * _sigmoidDeriv(yi);
      } else if (lower != null) {
        final clampedYi = yi.clamp(-50.0, 50.0);
        dxiDyi = math.exp(clampedYi);
      } else if (upper != null) {
        final clampedYi = yi.clamp(-50.0, 50.0);
        dxiDyi = math.exp(-clampedYi);
      } else {
        dxiDyi = 1.0;
      }
      gradY[i] = gradX[i] * dxiDyi;
    }
    return gradY;
  }

  Vector<double> projectToFeasible(
    Vector<double> x, {
    Vector<double>? gradX,
    double tolerance = 1e-6,
  }) {
    if (bounds == null) return x.copy();
    final dim = x.length;
    final res = Vector<double>.filled(dim, 0.0, type: DataType.float64);
    for (var i = 0; i < dim; i++) {
      final b = bounds![i];
      final lower = (b.lower == null || b.lower!.isInfinite) ? null : b.lower;
      final upper = (b.upper == null || b.upper!.isInfinite) ? null : b.upper;
      var xi = x[i];
      if (lower != null && upper != null) {
        final span = upper - lower;
        final tol = math.max(tolerance, span * tolerance);
        if (xi <= lower ||
            (xi - lower <= tol && (gradX == null || gradX[i] > 0.0))) {
          xi = lower;
        } else if (xi >= upper ||
            (upper - xi <= tol && (gradX == null || gradX[i] < 0.0))) {
          xi = upper;
        }
      } else if (lower != null) {
        if (xi <= lower ||
            (xi - lower <= tolerance && (gradX == null || gradX[i] > 0.0))) {
          xi = lower;
        }
      } else if (upper != null) {
        if (xi >= upper ||
            (upper - xi <= tolerance && (gradX == null || gradX[i] < 0.0))) {
          xi = upper;
        }
      }
      res[i] = xi;
    }
    return res;
  }
}

class _Constraint {
  new(
    this.fn, {
    required this.isInequality,
    Vector<double> Function(Vector<double>)? gradFn,
  }) : gradFn = gradFn ?? ((Vector<double> x) => calculusGradient(fn, x));

  final double Function(Vector<double>) fn;
  final bool isInequality;
  final Vector<double> Function(Vector<double>) gradFn;

  double evaluate(Vector<double> x) => fn(x);
  Vector<double> gradient(Vector<double> x) => gradFn(x);
}

double _sigmoid(double y) {
  if (y >= 50.0) return 1.0;
  if (y <= -50.0) return 0.0;
  if (y >= 0.0) {
    return 1.0 / (1.0 + math.exp(-y));
  } else {
    final e = math.exp(y);
    return e / (1.0 + e);
  }
}

double _sigmoidDeriv(double y) {
  final clampedY = y.clamp(-50.0, 50.0);
  if (clampedY >= 0.0) {
    final e = math.exp(-clampedY);
    final denom = 1.0 + e;
    return e / (denom * denom);
  } else {
    final e = math.exp(clampedY);
    final denom = 1.0 + e;
    return e / (denom * denom);
  }
}

/// Calculus gradient helper alias to avoid naming conflict.
Vector<double> calculusGradient(
  double Function(Vector<double>) function,
  Vector<double> point,
) => gradient(function, point);
