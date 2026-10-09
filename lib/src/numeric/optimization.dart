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
  Object f, {
  required double a,
  required double b,
  String variable = 'x',
  double tolerance = 1e-8,
  int maxIterations = 100,
}) {
  final double Function(double) fn;
  if (f is Expr) {
    fn = (x) => f.evaluate({variable: x});
  } else if (f is double Function(double)) {
    fn = f;
  } else if (f is num Function(num)) {
    fn = (x) => f(x).toDouble();
  } else {
    throw ArgumentError('Unsupported function type: ${f.runtimeType}');
  }

  const c = 0.38196601125010515179541316563436; // (3 - sqrt(5)) / 2

  var xA = a < b ? a : b;
  var xB = a < b ? b : a;
  var x = xA + c * (xB - xA);
  var w = x;
  var v = w;
  var fx = fn(x);
  var fw = fx;
  var fv = fw;
  var d = 0.0;
  var e = 0.0;

  var iter = 0;
  for (; iter < maxIterations; iter++) {
    final xm = 0.5 * (xA + xB);
    final tol1 = 1e-10 * x.abs() + tolerance;
    final tol2 = 2.0 * tol1;

    if ((x - xm).abs() <= (tol2 - 0.5 * (xB - xA))) {
      break;
    }

    var p = 0.0;
    var q = 0.0;
    var r = 0.0;

    if (e.abs() > tol1) {
      r = (x - w) * (fx - fv);
      q = (x - v) * (fx - fw);
      p = (x - v) * q - (x - w) * r;
      q = 2.0 * (q - r);
      if (q > 0.0) p = -p;
      q = q.abs();
      final rTemp = e;
      e = d;
      if (p.abs() < (0.5 * q * rTemp).abs() && p > q * (xA - x) && p < q * (xB - x)) {
        d = p / q;
        final u = x + d;
        if (u - xA < tol2 || xB - u < tol2) {
          d = xm - x >= 0 ? tol1 : -tol1;
        }
      } else {
        e = x >= xm ? xA - x : xB - x;
        d = c * e;
      }
    } else {
      e = x >= xm ? xA - x : xB - x;
      d = c * e;
    }

    final u = d.abs() >= tol1 ? x + d : x + (d > 0 ? tol1 : -tol1);
    final fu = fn(u);

    if (fu <= fx) {
      if (u >= x) {
        xA = x;
      } else {
        xB = x;
      }
      v = w;
      fv = fw;
      w = x;
      fw = fx;
      x = u;
      fx = fu;
    } else {
      if (u < x) {
        xA = u;
      } else {
        xB = u;
      }
      if (fu <= fw || w == x) {
        v = w;
        fv = fw;
        w = u;
        fw = fu;
      } else if (fu <= fv || v == x || v == w) {
        v = u;
        fv = fu;
      }
    }
  }

  return (point: x, value: fx, iterations: iter);
}

/// Derivative-free multivariate optimization using the Nelder-Mead simplex algorithm.
({Vector<double> point, double value, int iterations}) nelderMead(
  Object f,
  Vector<double> initialPoint, {
  List<String>? variables,
  double step = 1.0,
  double tolerance = 1e-8,
  int maxIterations = 1000,
}) {
  final double Function(Vector<double>) fn;
  if (f is Expr) {
    final vars = variables ?? (f.freeVariables.toList()..sort());
    fn = (vec) => f.evaluate({
          for (var i = 0; i < vec.length; i++) vars[i]: vec[i],
        });
  } else if (f is double Function(Vector<double>)) {
    fn = f;
  } else {
    throw ArgumentError('Unsupported function type: ${f.runtimeType}');
  }

  final n = initialPoint.length;
  // Simplex of n + 1 vertices
  final simplex = <Vector<double>>[initialPoint.copy()];
  for (var i = 0; i < n; i++) {
    final vertex = initialPoint.copy();
    vertex[i] += vertex[i] == 0.0 ? step : vertex[i] * 0.05 + step;
    simplex.add(vertex);
  }

  final values = [for (final v in simplex) fn(v)];

  const alpha = 1.0; // reflection
  const gamma = 2.0; // expansion
  const rho = 0.5; // contraction
  const sigma = 0.5; // shrink

  var iter = 0;
  for (; iter < maxIterations; iter++) {
    // Sort simplex by values
    final indices = List<int>.generate(n + 1, (i) => i)
      ..sort((a, b) => values[a].compareTo(values[b]));

    final bestIdx = indices[0];
    final worstIdx = indices[n];
    final secondWorstIdx = indices[n - 1];

    // Check convergence: standard deviation of simplex values
    var meanVal = 0.0;
    for (var i = 0; i <= n; i++) {
      meanVal += values[i];
    }
    meanVal /= n + 1;

    var variance = 0.0;
    for (var i = 0; i <= n; i++) {
      final diff = values[i] - meanVal;
      variance += diff * diff;
    }
    if (math.sqrt(variance / (n + 1)) < tolerance) {
      return (point: simplex[bestIdx], value: values[bestIdx], iterations: iter);
    }

    // Compute centroid of all vertices except worst
    final centroid = Vector<double>.filled(n, 0.0, type: DataType.float64);
    for (var i = 0; i < n; i++) {
      final idx = indices[i];
      for (var d = 0; d < n; d++) {
        centroid[d] += simplex[idx][d];
      }
    }
    for (var d = 0; d < n; d++) {
      centroid[d] /= n;
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
    for (var i = 1; i <= n; i++) {
      final idx = indices[i];
      simplex[idx] = xBest + (simplex[idx] - xBest).scale(sigma);
      values[idx] = fn(simplex[idx]);
    }
  }

  final bestIdx = List<int>.generate(n + 1, (i) => i)
      .reduce((a, b) => values[a] < values[b] ? a : b);
  return (point: simplex[bestIdx], value: values[bestIdx], iterations: iter);
}

/// Quasi-Newton BFGS unconstrained optimization.
///
/// Seamlessly accepts either a numerical closure `double Function(Vector<double>)`
/// or an [Expr] (where analytical gradients are automatically derived).
({Vector<double> point, double value, double gradientNorm, int iterations}) bfgs(
  Object f,
  Vector<double> initialPoint, {
  Object? gradient,
  List<String>? variables,
  double tolerance = 1e-6,
  int maxIterations = 200,
}) {
  final double Function(Vector<double>) fn;
  final Vector<double> Function(Vector<double>) gradFn;

  if (f is Expr) {
    final vars = variables ?? (f.freeVariables.toList()..sort());
    fn = (vec) => f.evaluate({
          for (var i = 0; i < vec.length; i++) vars[i]: vec[i],
        });
    gradFn = (vec) => numericalGradient(f, vec, variables: vars);
  } else if (f is double Function(Vector<double>)) {
    fn = f;
    if (gradient is Vector<double> Function(Vector<double>)) {
      gradFn = gradient;
    } else {
      gradFn = (vec) => numericalGradient(f, vec);
    }
  } else {
    throw ArgumentError('Unsupported function type: ${f.runtimeType}');
  }

  final n = initialPoint.length;
  var x = initialPoint.copy();
  var fx = fn(x);
  var g = gradFn(x);

  // Initial inverse Hessian approximation H0 = Identity
  var hMat = Matrix<double>.identity(n, type: DataType.float64);

  var iter = 0;
  for (; iter < maxIterations; iter++) {
    final gNorm = g.norm();
    if (gNorm < tolerance) {
      return (point: x, value: fx, gradientNorm: gNorm, iterations: iter);
    }

    // Search direction p = -H * g
    final p = -hMat.apply(g);

    // Backtracking line search with Armijo condition: f(x + alpha * p) <= f(x) + c1 * alpha * (g . p)
    const c1 = 1e-4;
    var alpha = 1.0;
    final slope = g.dot(p);
    if (slope >= 0.0) {
      // Re-initialize Hessian if direction is not descent
      hMat = Matrix<double>.identity(n, type: DataType.float64);
      final pReset = -g;
      final slopeReset = g.dot(pReset);
      var a = 1.0;
      while (fn(x + pReset.scale(a)) > fx + c1 * a * slopeReset && a > 1e-12) {
        a *= 0.5;
      }
      alpha = a;
    } else {
      while (fn(x + p.scale(alpha)) > fx + c1 * alpha * slope && alpha > 1e-12) {
        alpha *= 0.5;
      }
    }

    final s = (slope >= 0.0 ? -g : p).scale(alpha);
    final xNext = x + s;
    final fxNext = fn(xNext);
    final gNext = gradFn(xNext);
    final y = gNext - g;

    final ys = y.dot(s);
    if (ys > 1e-10) {
      final rho = 1.0 / ys;
      final eye = Matrix<double>.identity(n, type: DataType.float64);
      final syT = s.outer(y).scale(rho);
      final ysT = y.outer(s).scale(rho);
      final v1 = eye - syT;
      final v2 = eye - ysT;
      final ssT = s.outer(s).scale(rho);
      hMat = (v1 * hMat * v2) + ssT;
    }

    x = xNext;
    fx = fxNext;
    g = gNext;
  }

  return (point: x, value: fx, gradientNorm: g.norm(), iterations: iter);
}

/// Limited-memory BFGS (L-BFGS) unconstrained optimization.
({Vector<double> point, double value, double gradientNorm, int iterations}) lbfgs(
  Object f,
  Vector<double> initialPoint, {
  Object? gradient,
  List<String>? variables,
  int memorySize = 7,
  double tolerance = 1e-6,
  int maxIterations = 200,
}) {
  final double Function(Vector<double>) fn;
  final Vector<double> Function(Vector<double>) gradFn;

  if (f is Expr) {
    final vars = variables ?? (f.freeVariables.toList()..sort());
    fn = (vec) => f.evaluate({
          for (var i = 0; i < vec.length; i++) vars[i]: vec[i],
        });
    gradFn = (vec) => numericalGradient(f, vec, variables: vars);
  } else if (f is double Function(Vector<double>)) {
    fn = f;
    if (gradient is Vector<double> Function(Vector<double>)) {
      gradFn = gradient;
    } else {
      gradFn = (vec) => numericalGradient(f, vec);
    }
  } else {
    throw ArgumentError('Unsupported function type: ${f.runtimeType}');
  }

  var x = initialPoint.copy();
  var fx = fn(x);
  var g = gradFn(x);

  final sHistory = <Vector<double>>[];
  final yHistory = <Vector<double>>[];
  final rhoHistory = <double>[];

  var iter = 0;
  for (; iter < maxIterations; iter++) {
    final gNorm = g.norm();
    if (gNorm < tolerance) {
      return (point: x, value: fx, gradientNorm: gNorm, iterations: iter);
    }

    // L-BFGS two-loop recursion to compute search direction r = -H_k * g
    var q = g.copy();
    final k = sHistory.length;
    final alphas = List<double>.filled(k, 0.0);

    for (var i = k - 1; i >= 0; i--) {
      alphas[i] = rhoHistory[i] * sHistory[i].dot(q);
      q = q - yHistory[i].scale(alphas[i]);
    }

    // Initial scale factor gamma_k = (s_{k-1} . y_{k-1}) / (y_{k-1} . y_{k-1})
    var gamma = 1.0;
    if (k > 0) {
      final sLast = sHistory.last;
      final yLast = yHistory.last;
      gamma = sLast.dot(yLast) / yLast.dot(yLast);
    }
    var r = q.scale(gamma);

    for (var i = 0; i < k; i++) {
      final beta = rhoHistory[i] * yHistory[i].dot(r);
      r = r + sHistory[i].scale(alphas[i] - beta);
    }

    final p = -r;

    // Backtracking line search
    const c1 = 1e-4;
    var alpha = 1.0;
    final slope = g.dot(p);
    final dir = slope < 0.0 ? p : -g;
    final effectiveSlope = slope < 0.0 ? slope : -g.dot(g);

    while (fn(x + dir.scale(alpha)) > fx + c1 * alpha * effectiveSlope &&
        alpha > 1e-12) {
      alpha *= 0.5;
    }

    final s = dir.scale(alpha);
    final xNext = x + s;
    final fxNext = fn(xNext);
    final gNext = gradFn(xNext);
    final y = gNext - g;

    final ys = y.dot(s);
    if (ys > 1e-10) {
      if (sHistory.length >= memorySize) {
        sHistory.removeAt(0);
        yHistory.removeAt(0);
        rhoHistory.removeAt(0);
      }
      sHistory.add(s);
      yHistory.add(y);
      rhoHistory.add(1.0 / ys);
    }

    x = xNext;
    fx = fxNext;
    g = gNext;
  }

  return (point: x, value: fx, gradientNorm: g.norm(), iterations: iter);
}
