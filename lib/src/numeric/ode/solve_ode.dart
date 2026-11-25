import 'dart:math' as math;

import '../../linear/matrix.dart';
import '../../linear/vector.dart';
import '../../type/data_type.dart';
import '../calculus/jacobian.dart' as calculus;
import '../interpolation/search.dart';
import 'ode_method.dart';
import 'ode_solution.dart';

/// Solves an initial value problem `dy/dt = f(t, y)` from [t0] to [tEnd]
/// starting at state [y0] using the specified [method].
///
/// Conceptually, this simulates how a dynamic system evolves over time (such as
/// an orbital trajectory or harmonic oscillator). Formally, it executes the
/// chosen [method] ([OdeMethod.dormandPrince45] by default for adaptive
/// step-size error control, [OdeMethod.rk4] for fixed step size, or
/// [OdeMethod.bdf2] for stiff systems).
///
/// If [tEval] is provided, dense cubic Hermite interpolation evaluates the
/// solution at the requested time coordinates.
///
/// ```dart
/// final sol = solveOde(
///   f: (t, y) => Vector<double>.fromList([-y[0]]),
///   t0: 0.0,
///   tEnd: 1.0,
///   y0: Vector<double>.fromList([1.0]),
/// );
/// ```
OdeSolution solveOde({
  required Vector<double> Function(double t, Vector<double> y) f,
  required double t0,
  required double tEnd,
  required Vector<double> y0,
  OdeMethod method = OdeMethod.dormandPrince45,
  double stepSize = 0.01,
  double relativeTolerance = 1e-6,
  double absoluteTolerance = 1e-8,
  double minStep = 1e-12,
  double maxStep = 1.0,
  int maxSteps = 100000,
  Iterable<double>? tEval,
}) {
  if (!t0.isFinite) {
    throw ArgumentError.value(t0, 't0', 'Must be finite');
  }
  if (!tEnd.isFinite) {
    throw ArgumentError.value(tEnd, 'tEnd', 'Must be finite');
  }
  if (y0.length == 0) {
    throw ArgumentError.value(
      y0.length,
      'y0.length',
      'Initial state vector cannot be empty',
    );
  }
  if (stepSize <= 0 || !stepSize.isFinite) {
    throw ArgumentError.value(
      stepSize,
      'stepSize',
      'Step size must be positive and finite',
    );
  }
  if (relativeTolerance <= 0 || !relativeTolerance.isFinite) {
    throw ArgumentError.value(
      relativeTolerance,
      'relativeTolerance',
      'Relative tolerance must be positive and finite',
    );
  }
  if (absoluteTolerance <= 0 || !absoluteTolerance.isFinite) {
    throw ArgumentError.value(
      absoluteTolerance,
      'absoluteTolerance',
      'Absolute tolerance must be positive and finite',
    );
  }
  if (minStep <= 0 || !minStep.isFinite) {
    throw ArgumentError.value(
      minStep,
      'minStep',
      'Min step must be positive and finite',
    );
  }
  if (maxStep < minStep || !maxStep.isFinite) {
    throw ArgumentError.value(
      maxStep,
      'maxStep',
      'Max step must be finite and >= minStep',
    );
  }
  if (maxSteps <= 0) {
    throw ArgumentError.value(
      maxSteps,
      'maxSteps',
      'Max steps must be positive',
    );
  }

  final timeSpan = (tEnd - t0).abs();
  final timeTol = timeSpan == 0.0
      ? 0.0
      : math.max(
          1e-12 * timeSpan,
          4.0 * 2.220446049250313e-16 * math.max(t0.abs(), tEnd.abs()),
        );

  final rawSol = switch (method) {
    OdeMethod.rk4 => _rk4(
      f: f,
      t0: t0,
      tEnd: tEnd,
      y0: y0,
      stepSize: stepSize,
      maxSteps: maxSteps,
      timeTol: timeTol,
    ),
    OdeMethod.dormandPrince45 => _rk45(
      f: f,
      t0: t0,
      tEnd: tEnd,
      y0: y0,
      initialStep: stepSize,
      relativeTolerance: relativeTolerance,
      absoluteTolerance: absoluteTolerance,
      minStep: minStep,
      maxStep: maxStep,
      maxSteps: maxSteps,
      timeTol: timeTol,
    ),
    OdeMethod.bdf2 => _bdf2(
      f: f,
      t0: t0,
      tEnd: tEnd,
      y0: y0,
      initialStep: stepSize,
      relativeTolerance: relativeTolerance,
      absoluteTolerance: absoluteTolerance,
      minStep: minStep,
      maxStep: maxStep,
      maxSteps: maxSteps,
      timeTol: timeTol,
    ),
  };

  if (tEval != null) {
    return _interpolateHermite(raw: rawSol, f: f, tEval: tEval);
  }
  return rawSol;
}

OdeSolution _rk4({
  required Vector<double> Function(double t, Vector<double> y) f,
  required double t0,
  required double tEnd,
  required Vector<double> y0,
  required double stepSize,
  required int maxSteps,
  required double timeTol,
}) {
  final tList = <double>[t0];
  final yList = <Vector<double>>[y0.copy()];

  var currentTime = t0;
  final y = y0.copy();
  final direction = tEnd >= t0 ? 1.0 : -1.0;
  var step = direction * stepSize.abs();

  var stepCount = 0;
  while ((tEnd - currentTime) * direction > timeTol && stepCount < maxSteps) {
    stepCount++;
    var truncated = false;
    if ((currentTime + step - tEnd) * direction > 0.0) {
      step = tEnd - currentTime;
      truncated = true;
    }

    final k1 = f(currentTime, y);
    final k2 = f(
      currentTime + 0.5 * step,
      (y.copy())..addScaled(k1, 0.5 * step),
    );
    final k3 = f(
      currentTime + 0.5 * step,
      (y.copy())..addScaled(k2, 0.5 * step),
    );
    final k4 = f(currentTime + step, (y.copy())..addScaled(k3, step));

    final dy = (k1.copy())
      ..addScaled(k2, 2.0)
      ..addScaled(k3, 2.0)
      ..addScaled(k4, 1.0)
      ..scaleInPlace(step / 6.0);
    y.addScaled(dy, 1.0);
    if (!_isFiniteVector(y)) {
      return OdeSolution(t: tList, y: yList, converged: false);
    }
    currentTime = truncated ? tEnd : currentTime + step;

    tList.add(currentTime);
    yList.add(y.copy());
  }

  final converged = (tEnd - currentTime).abs() <= timeTol;
  return OdeSolution(t: tList, y: yList, converged: converged);
}

OdeSolution _rk45({
  required Vector<double> Function(double t, Vector<double> y) f,
  required double t0,
  required double tEnd,
  required Vector<double> y0,
  required double initialStep,
  required double relativeTolerance,
  required double absoluteTolerance,
  required double minStep,
  required double maxStep,
  required int maxSteps,
  required double timeTol,
}) {
  final tList = <double>[t0];
  final yList = <Vector<double>>[y0.copy()];

  var currentTime = t0;
  var y = y0.copy();
  final direction = tEnd >= t0 ? 1.0 : -1.0;
  var step =
      direction * math.min(maxStep, math.max(minStep, initialStep.abs()));

  var k1 = f(currentTime, y);

  var stepCount = 0;
  while ((tEnd - currentTime) * direction > timeTol && stepCount < maxSteps) {
    stepCount++;
    var truncated = false;
    if ((currentTime + step - tEnd) * direction > 0.0) {
      step = tEnd - currentTime;
      truncated = true;
    }

    final k2 = f(
      currentTime + step * (1.0 / 5.0),
      (y.copy())..addScaled(k1, step * (1.0 / 5.0)),
    );
    final k3 = f(
      currentTime + step * (3.0 / 10.0),
      (y.copy())
        ..addScaled(k1, step * (3.0 / 40.0))
        ..addScaled(k2, step * (9.0 / 40.0)),
    );
    final k4 = f(
      currentTime + step * (4.0 / 5.0),
      (y.copy())
        ..addScaled(k1, step * (44.0 / 45.0))
        ..addScaled(k2, -step * (56.0 / 15.0))
        ..addScaled(k3, step * (32.0 / 9.0)),
    );
    final k5 = f(
      currentTime + step * (8.0 / 9.0),
      (y.copy())
        ..addScaled(k1, step * (19372.0 / 6561.0))
        ..addScaled(k2, -step * (25360.0 / 2187.0))
        ..addScaled(k3, step * (64448.0 / 6561.0))
        ..addScaled(k4, -step * (212.0 / 729.0)),
    );
    final k6 = f(
      currentTime + step,
      (y.copy())
        ..addScaled(k1, step * (9017.0 / 3168.0))
        ..addScaled(k2, -step * (355.0 / 33.0))
        ..addScaled(k3, step * (46732.0 / 5247.0))
        ..addScaled(k4, step * (49.0 / 176.0))
        ..addScaled(k5, -step * (5103.0 / 18656.0)),
    );

    final y5 = (y.copy())
      ..addScaled(k1, step * (35.0 / 384.0))
      ..addScaled(k3, step * (500.0 / 1113.0))
      ..addScaled(k4, step * (125.0 / 192.0))
      ..addScaled(k5, -step * (2187.0 / 6784.0))
      ..addScaled(k6, step * (11.0 / 84.0));

    final k7 = f(currentTime + step, y5);

    final errorVec = (k1.scale(71.0 / 57600.0))
      ..addScaled(k3, -71.0 / 16695.0)
      ..addScaled(k4, 71.0 / 1920.0)
      ..addScaled(k5, -17253.0 / 339200.0)
      ..addScaled(k6, 22.0 / 525.0)
      ..addScaled(k7, -1.0 / 40.0)
      ..scaleInPlace(step);

    var maxErrorRatio = 0.0;
    for (var i = 0; i < y.length; i++) {
      final y5i = y5.getUnchecked(i);
      if (!y5i.isFinite) {
        maxErrorRatio = double.infinity;
        break;
      }
      final sc =
          absoluteTolerance +
          relativeTolerance * math.max(y.getUnchecked(i).abs(), y5i.abs());
      final ratio = errorVec.getUnchecked(i).abs() / sc;
      if (ratio.isNaN) {
        maxErrorRatio = double.infinity;
        break;
      }
      if (ratio > maxErrorRatio) maxErrorRatio = ratio;
    }

    if (maxErrorRatio <= 1.0) {
      currentTime = truncated ? tEnd : currentTime + step;
      y = y5;
      k1 = k7;
      tList.add(currentTime);
      yList.add(y.copy());
    } else if (!truncated && step.abs() <= minStep * (1.0 + 1e-12)) {
      // Step size cannot be reduced below minStep; abort with converged = false.
      break;
    } else if (truncated && step.abs() <= 1e-15) {
      break;
    }

    var factor =
        0.9 * math.pow(maxErrorRatio > 0.0 ? 1.0 / maxErrorRatio : 10.0, 0.2);
    factor = math.max(0.2, math.min(5.0, factor));
    final lowerStepBound = truncated ? math.min(minStep, 1e-15) : minStep;
    step =
        direction *
        math.min(maxStep, math.max(lowerStepBound, (step * factor).abs()));
  }

  final converged = (tEnd - currentTime).abs() <= timeTol;
  return OdeSolution(t: tList, y: yList, converged: converged);
}

OdeSolution _bdf2({
  required Vector<double> Function(double t, Vector<double> y) f,
  required double t0,
  required double tEnd,
  required Vector<double> y0,
  required double initialStep,
  required double relativeTolerance,
  required double absoluteTolerance,
  required double minStep,
  required double maxStep,
  required int maxSteps,
  required double timeTol,
  int maxNewtonIters = 20,
}) {
  final tList = <double>[t0];
  final yList = <Vector<double>>[y0.copy()];

  final direction = tEnd >= t0 ? 1.0 : -1.0;
  var step =
      direction * math.min(maxStep, math.max(minStep, initialStep.abs()));
  final dim = y0.length;

  var currentTime = t0;
  var stepCount = 0;
  var allStepsConverged = true;

  Vector<double>? cachedFN;
  Vector<double>? cachedFPrev;

  // Step 1: implicit trapezoidal rule
  while ((tEnd - currentTime) * direction > timeTol &&
      stepCount < maxSteps &&
      tList.length < 2) {
    stepCount++;
    var truncated = false;
    if ((currentTime + step - tEnd) * direction > 0.0) {
      step = tEnd - currentTime;
      truncated = true;
    }
    final t1 = truncated ? tEnd : currentTime + step;
    final f0 = f(currentTime, y0);
    var y1 = y0 + f0.scale(step);
    final gamma = step * 0.5;

    var stepConverged = false;
    Matrix<double>? mat;
    for (var iter = 0; iter < maxNewtonIters; iter++) {
      final f1 = f(t1, y1);
      final residual = y1 - y0 - (f0 + f1).scale(gamma);
      final resNorm = residual.norm();
      if (!resNorm.isFinite) break;
      final newtonTol =
          0.1 * (absoluteTolerance + relativeTolerance * y1.norm());
      if (resNorm < newtonTol) {
        stepConverged = true;
        break;
      }

      if (mat == null || iter >= 5) {
        final jac = calculus.jacobian((v) => f(t1, v), y1, step: 1e-6);
        mat = Matrix<double>.generate(dim, dim, (r, c) {
          final id = r == c ? 1.0 : 0.0;
          return id - gamma * jac.getUnchecked(r, c);
        }, type: DataType.float64);
      }

      final Vector<double> delta;
      try {
        delta = mat.solveVector(-residual);
      } on StateError {
        break;
      } on ArgumentError {
        break;
      }
      if (!_isFiniteVector(delta)) break;
      y1 += delta;
      if (delta.norm() < newtonTol) {
        stepConverged = true;
        break;
      }
    }

    if (!stepConverged) {
      if (step.abs() <= minStep * (1.0 + 1e-12)) {
        allStepsConverged = false;
        break;
      }
      step = direction * math.max(minStep, step.abs() * 0.5);
      continue;
    }

    // Local truncation error estimate for trapezoidal rule vs explicit Euler:
    final f1Final = f(t1, y1);
    final errorVec = (f1Final - f0)..scaleInPlace(0.5 * step.abs());
    var maxErrorRatio = 0.0;
    for (var i = 0; i < dim; i++) {
      final y1i = y1.getUnchecked(i);
      if (!y1i.isFinite) {
        maxErrorRatio = double.infinity;
        break;
      }
      final sc =
          absoluteTolerance +
          relativeTolerance * math.max(y0.getUnchecked(i).abs(), y1i.abs());
      final ratio = errorVec.getUnchecked(i).abs() / sc;
      if (ratio.isNaN) {
        maxErrorRatio = double.infinity;
        break;
      }
      if (ratio > maxErrorRatio) maxErrorRatio = ratio;
    }

    if (maxErrorRatio <= 1.0) {
      currentTime = t1;
      tList.add(currentTime);
      yList.add(y1.copy());
      cachedFPrev = f0;
      cachedFN = f1Final;
      var factor =
          0.9 *
          math.pow(maxErrorRatio > 0.0 ? 1.0 / maxErrorRatio : 10.0, 1.0 / 2.0);
      factor = math.max(0.2, math.min(5.0, factor));
      step =
          direction * math.min(maxStep, math.max(minStep, step.abs() * factor));
    } else {
      if (step.abs() <= minStep * (1.0 + 1e-12)) {
        allStepsConverged = false;
        break;
      }
      step = direction * math.max(minStep, step.abs() * 0.5);
    }
  }

  if (tList.length < 2) {
    final reachedEnd = (tEnd - currentTime).abs() <= timeTol;
    return OdeSolution(
      t: tList,
      y: yList,
      converged: reachedEnd && allStepsConverged,
    );
  }

  // Subsequent steps: adaptive BDF2 (Modified Newton with local truncation error control)
  double? cachedGamma;
  Matrix<double>? cachedMat;
  var fPrev = cachedFPrev!;
  var fN = cachedFN!;

  while ((tEnd - currentTime) * direction > timeTol && stepCount < maxSteps) {
    stepCount++;
    var truncated = false;
    if ((currentTime + step - tEnd) * direction > 0.0) {
      step = tEnd - currentTime;
      truncated = true;
    }
    final tNext = truncated ? tEnd : currentTime + step;
    final yN = yList[yList.length - 1];
    final yPrev = yList[yList.length - 2];

    final hPrev = tList[tList.length - 1] - tList[tList.length - 2];
    final omega = step / hPrev;
    final alpha = (1.0 + omega) * (1.0 + omega) / (1.0 + 2.0 * omega);
    final beta = (omega * omega) / (1.0 + 2.0 * omega);
    final gamma = ((1.0 + omega) / (1.0 + 2.0 * omega)) * step;

    // Linear predictor
    final yPredictor = yN.scale(1.0 + omega) - yPrev.scale(omega);
    var yNext = yPredictor.copy();

    final needJacobian =
        cachedMat == null ||
        cachedGamma == null ||
        (cachedGamma - gamma).abs() > 0.2 * gamma.abs();
    if (needJacobian) {
      final jac = calculus.jacobian((v) => f(tNext, v), yPredictor, step: 1e-6);
      cachedGamma = gamma;
      cachedMat = Matrix<double>.generate(dim, dim, (r, c) {
        final id = r == c ? 1.0 : 0.0;
        return id - gamma * jac.getUnchecked(r, c);
      }, type: DataType.float64);
    }

    var stepConverged = false;
    for (var iter = 0; iter < maxNewtonIters; iter++) {
      final fNext = f(tNext, yNext);
      final residual =
          yNext - yN.scale(alpha) + yPrev.scale(beta) - fNext.scale(gamma);
      final resNorm = residual.norm();
      if (!resNorm.isFinite) break;
      final newtonTol =
          0.1 * (absoluteTolerance + relativeTolerance * yNext.norm());
      if (resNorm < newtonTol) {
        stepConverged = true;
        break;
      }

      if (iter >= 3) {
        final jac = calculus.jacobian((v) => f(tNext, v), yNext, step: 1e-6);
        cachedMat = Matrix<double>.generate(dim, dim, (r, c) {
          final id = r == c ? 1.0 : 0.0;
          return id - gamma * jac.getUnchecked(r, c);
        }, type: DataType.float64);
      }

      final Vector<double> delta;
      try {
        delta = cachedMat!.solveVector(-residual);
      } on StateError {
        break;
      } on ArgumentError {
        break;
      }
      if (!_isFiniteVector(delta)) break;
      yNext += delta;
      if (delta.norm() < newtonTol) {
        stepConverged = true;
        break;
      }
    }

    if (!stepConverged) {
      if (step.abs() <= minStep * (1.0 + 1e-12)) {
        allStepsConverged = false;
        break;
      }
      step = direction * math.max(minStep, step.abs() * 0.5);
      cachedMat = null;
      continue;
    }

    // Local truncation error estimate for BDF2 via second backward difference of f:
    // LTE ~= (2/9) * step * (f(t_next) - (1 + omega)*f(t_n) + omega*f(t_{n-1}))
    final fNextFinal = f(tNext, yNext);
    final d2f = fNextFinal - fN.scale(1.0 + omega) + fPrev.scale(omega);
    final errorVec = d2f..scaleInPlace((2.0 / 9.0) * step.abs());

    var maxErrorRatio = 0.0;
    for (var i = 0; i < dim; i++) {
      final yNextI = yNext.getUnchecked(i);
      if (!yNextI.isFinite) {
        maxErrorRatio = double.infinity;
        break;
      }
      final sc =
          absoluteTolerance +
          relativeTolerance * math.max(yN.getUnchecked(i).abs(), yNextI.abs());
      final ratio = errorVec.getUnchecked(i).abs() / sc;
      if (ratio.isNaN) {
        maxErrorRatio = double.infinity;
        break;
      }
      if (ratio > maxErrorRatio) maxErrorRatio = ratio;
    }

    if (maxErrorRatio <= 1.0) {
      currentTime = tNext;
      tList.add(currentTime);
      yList.add(yNext.copy());
      fPrev = fN;
      fN = fNextFinal;
    } else if (!truncated && step.abs() <= minStep * (1.0 + 1e-12)) {
      allStepsConverged = false;
      break;
    } else if (truncated && step.abs() <= 1e-15) {
      break;
    }

    var factor =
        0.9 *
        math.pow(maxErrorRatio > 0.0 ? 1.0 / maxErrorRatio : 10.0, 1.0 / 3.0);
    factor = math.max(0.2, math.min(5.0, factor));
    final lowerStepBound = truncated ? math.min(minStep, 1e-15) : minStep;
    step =
        direction *
        math.min(maxStep, math.max(lowerStepBound, step.abs() * factor));
  }

  final reachedEnd = (tEnd - currentTime).abs() <= timeTol;
  return OdeSolution(
    t: tList,
    y: yList,
    converged: reachedEnd && allStepsConverged,
  );
}

OdeSolution _interpolateHermite({
  required OdeSolution raw,
  required Vector<double> Function(double t, Vector<double> y) f,
  required Iterable<double> tEval,
}) {
  final tRaw = raw.t;
  final yRaw = raw.y;
  final n = tRaw.length;
  final dim = yRaw[0].length;
  if (n == 1) {
    return OdeSolution(
      t: [for (final t in tEval) t],
      y: [
        for (final t in tEval)
          if (t.isNaN)
            Vector<double>.filled(dim, double.nan, type: DataType.float64)
          else
            yRaw[0].copy(),
      ],
      converged: raw.converged,
    );
  }

  final fRaw = <Vector<double>>[
    for (var i = 0; i < n; i++) f(tRaw[i], yRaw[i]),
  ];

  final evalT = <double>[];
  final evalY = <Vector<double>>[];

  for (final t in tEval) {
    evalT.add(t);
    if (t.isNaN) {
      evalY.add(Vector<double>.filled(dim, double.nan, type: DataType.float64));
      continue;
    }
    var k = 0;
    final isAscending = tRaw.last >= tRaw.first;
    if (isAscending) {
      if (t <= tRaw.first) {
        evalY.add(yRaw.first.copy());
        continue;
      }
      if (t >= tRaw.last) {
        evalY.add(yRaw.last.copy());
        continue;
      }
      k = binarySearchInterval(tRaw, t);
    } else {
      if (t >= tRaw.first) {
        evalY.add(yRaw.first.copy());
        continue;
      }
      if (t <= tRaw.last) {
        evalY.add(yRaw.last.copy());
        continue;
      }
      var low = 0;
      var high = n - 2;
      while (low <= high) {
        final mid = (low + high) >>> 1;
        if (tRaw[mid] >= t && t >= tRaw[mid + 1]) {
          k = mid;
          break;
        } else if (t > tRaw[mid]) {
          high = mid - 1;
        } else {
          low = mid + 1;
        }
      }
    }

    final t0 = tRaw[k];
    final t1 = tRaw[k + 1];
    final h = t1 - t0;
    if (h.abs() < 1e-15) {
      evalY.add(yRaw[k].copy());
      continue;
    }
    final theta = (t - t0) / h;
    final theta2 = theta * theta;
    final theta3 = theta2 * theta;

    final h00 = 2 * theta3 - 3 * theta2 + 1;
    final h10 = (theta3 - 2 * theta2 + theta) * h;
    final h01 = -2 * theta3 + 3 * theta2;
    final h11 = (theta3 - theta2) * h;

    final y0 = yRaw[k];
    final y1 = yRaw[k + 1];
    final f0 = fRaw[k];
    final f1 = fRaw[k + 1];

    final interp = Vector<double>.generate(
      dim,
      (i) =>
          h00 * y0.getUnchecked(i) +
          h10 * f0.getUnchecked(i) +
          h01 * y1.getUnchecked(i) +
          h11 * f1.getUnchecked(i),
      type: DataType.float64,
    );
    evalY.add(interp);
  }

  return OdeSolution(t: evalT, y: evalY, converged: raw.converged);
}

bool _isFiniteVector(Vector<double> v) {
  for (var i = 0; i < v.length; i++) {
    if (!v.getUnchecked(i).isFinite) return false;
  }
  return true;
}
