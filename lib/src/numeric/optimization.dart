import 'dart:math' as math;

import '../../linear.dart';
import '../../symbolic.dart';
import '../../type.dart';
import 'calculus.dart';

/// 1D and multivariate numerical optimization algorithms.

/// Minimizes a 1D scalar function on interval $[a, b]$ using Brent's method.
///
/// Combines golden section search and successive parabolic interpolation.
/// Accepts either `double Function(double)` or an [Expr].
({double point, double value, int iterations}) brentMinimize(
  Object function, {
  required double a,
  required double b,
  String variable = 'x',
  double tolerance = 1e-8,
  int maxIterations = 100,
}) {
  final double Function(double) fn;
  if (function is Expr) {
    fn = (x) => function.evaluate({variable: x});
  } else if (function is double Function(double)) {
    fn = function;
  } else if (function is num Function(num)) {
    fn = (x) => function(x).toDouble();
  } else {
    throw ArgumentError('Unsupported function type: ${function.runtimeType}');
  }

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

/// Derivative-free multivariate optimization using the Nelder-Mead simplex algorithm.
({Vector<double> point, double value, int iterations}) nelderMead(
  Object function,
  Vector<double> initialPoint, {
  List<String>? variables,
  double step = 1.0,
  double tolerance = 1e-8,
  int maxIterations = 1000,
}) {
  final double Function(Vector<double>) fn;
  if (function is Expr) {
    final vars = variables ?? (function.freeVariables.toList()..sort());
    fn = (vec) => function.evaluate({
      for (var i = 0; i < vec.length; i++) vars[i]: vec[i],
    });
  } else if (function is double Function(Vector<double>)) {
    fn = function;
  } else {
    throw ArgumentError('Unsupported function type: ${function.runtimeType}');
  }

  final dim = initialPoint.length;
  // Simplex of dim + 1 vertices
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
    // Sort simplex by values
    final indices = List<int>.generate(dim + 1, (i) => i)
      ..sort((a, b) => values[a].compareTo(values[b]));

    final bestIdx = indices[0];
    final worstIdx = indices[dim];
    final secondWorstIdx = indices[dim - 1];

    // Check convergence: standard deviation of simplex values
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

    // Compute centroid of all vertices except worst
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
      // Outside contraction
      final xC = centroid + (xR - centroid).scale(rho);
      final fC = fn(xC);
      if (fC <= fR) {
        simplex[worstIdx] = xC;
        values[worstIdx] = fC;
        continue;
      }
    } else {
      // Inside contraction
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

/// Quasi-Newton BFGS unconstrained optimization.
///
/// Seamlessly accepts either a numerical closure `double Function(Vector<double>)`
/// or an [Expr] (where analytical gradients are automatically derived).
({Vector<double> point, double value, double gradientNorm, int iterations})
bfgs(
  Object function,
  Vector<double> initialPoint, {
  Object? gradient,
  List<String>? variables,
  double tolerance = 1e-6,
  int maxIterations = 200,
}) {
  final double Function(Vector<double>) fn;
  final Vector<double> Function(Vector<double>) gradFn;

  if (function is Expr) {
    final vars = variables ?? (function.freeVariables.toList()..sort());
    fn = (vec) => function.evaluate({
      for (var i = 0; i < vec.length; i++) vars[i]: vec[i],
    });
    gradFn = (vec) => numericalGradient(function, vec, variables: vars);
  } else if (function is double Function(Vector<double>)) {
    fn = function;
    if (gradient is Vector<double> Function(Vector<double>)) {
      gradFn = gradient;
    } else {
      gradFn = (vec) => numericalGradient(function, vec);
    }
  } else {
    throw ArgumentError('Unsupported function type: ${function.runtimeType}');
  }

  final dim = initialPoint.length;
  var x = initialPoint.copy();
  var fx = fn(x);
  var grad = gradFn(x);

  // Initial inverse Hessian approximation H0 = Identity
  var hMat = Matrix<double>.identity(dim, type: DataType.float64);

  var iter = 0;
  for (; iter < maxIterations; iter++) {
    final gNorm = grad.norm();
    if (gNorm < tolerance) {
      return (point: x, value: fx, gradientNorm: gNorm, iterations: iter);
    }

    // Search direction dir = -H * grad
    final dir = -hMat.apply(grad);

    // Backtracking line search with Armijo condition: f(x + alpha * dir) <= f(x) + c1 * alpha * (grad . dir)
    const c1 = 1e-4;
    var alpha = 1.0;
    final slope = grad.dot(dir);
    if (slope >= 0.0) {
      // Re-initialize Hessian if direction is not descent
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

/// Limited-memory BFGS (L-BFGS) unconstrained optimization.
({Vector<double> point, double value, double gradientNorm, int iterations})
lbfgs(
  Object function,
  Vector<double> initialPoint, {
  Object? gradient,
  List<String>? variables,
  int memorySize = 7,
  double tolerance = 1e-6,
  int maxIterations = 200,
}) {
  final double Function(Vector<double>) fn;
  final Vector<double> Function(Vector<double>) gradFn;

  if (function is Expr) {
    final vars = variables ?? (function.freeVariables.toList()..sort());
    fn = (vec) => function.evaluate({
      for (var i = 0; i < vec.length; i++) vars[i]: vec[i],
    });
    gradFn = (vec) => numericalGradient(function, vec, variables: vars);
  } else if (function is double Function(Vector<double>)) {
    fn = function;
    if (gradient is Vector<double> Function(Vector<double>)) {
      gradFn = gradient;
    } else {
      gradFn = (vec) => numericalGradient(function, vec);
    }
  } else {
    throw ArgumentError('Unsupported function type: ${function.runtimeType}');
  }

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

    // L-BFGS two-loop recursion to compute search direction r = -H_k * g
    final qVec = grad.copy();
    final histLen = sHistory.length;
    final alphas = List<double>.filled(histLen, 0.0);

    for (var i = histLen - 1; i >= 0; i--) {
      alphas[i] = rhoHistory[i] * sHistory[i].dot(qVec);
      qVec.addScaled(yHistory[i], -alphas[i]);
    }

    // Initial scale factor gamma_k = (s_{k-1} . y_{k-1}) / (y_{k-1} . y_{k-1})
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

    // Backtracking line search
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
