import '../../../linear.dart';
import '../../../type.dart';
import '../calculus/gradient.dart' as calculus;

/// Quasi-Newton Broyden-Fletcher-Goldfarb-Shanno (BFGS) algorithm.
({Vector<double> point, double value, double gradientNorm, int iterations})
bfgs(
  double Function(Vector<double>) fn,
  Vector<double> initialPoint, {
  Vector<double> Function(Vector<double>)? gradient,
  double tolerance = 1e-6,
  int maxIterations = 200,
}) {
  final gradFn =
      gradient ?? ((Vector<double> vec) => calculus.gradient(fn, vec));
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

/// Limited-memory BFGS (L-BFGS) algorithm for high-dimensional problems.
({Vector<double> point, double value, double gradientNorm, int iterations})
lbfgs(
  double Function(Vector<double>) fn,
  Vector<double> initialPoint, {
  Vector<double> Function(Vector<double>)? gradient,
  int memorySize = 7,
  double tolerance = 1e-6,
  int maxIterations = 200,
}) {
  final gradFn =
      gradient ?? ((Vector<double> vec) => calculus.gradient(fn, vec));

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
