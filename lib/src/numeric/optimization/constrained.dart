import 'dart:math' as math;

import '../../linear/vector.dart';
import '../../type/data_type.dart';
import '../calculus/gradient.dart' as calculus;
import 'nelder_mead.dart';
import 'optimization_types.dart';
import 'quasi_newton.dart';

/// Constrained numerical optimization using box transformations and augmented
/// Lagrangian.
({
  Vector<double> point,
  double value,
  double gradientNorm,
  int iterations,
  bool converged,
})
minimizeConstrained(
  double Function(Vector<double>) fn,
  Vector<double> initialPoint, {
  Vector<double> Function(Vector<double>)? gradient,
  List<BoxBound>? bounds,
  List<double Function(Vector<double>)>? inequalities,
  List<double Function(Vector<double>)>? equalities,
  OptimizationMethod method = OptimizationMethod.bfgs,
  double step = 1.0,
  int memorySize = 7,
  double tolerance = 1e-6,
  int maxIterations = 200,
}) {
  final dim = initialPoint.length;
  if (dim == 0) {
    throw ArgumentError('Initial point cannot be empty.');
  }
  if (tolerance <= 0.0 || !tolerance.isFinite) {
    throw ArgumentError.value(
      tolerance,
      'tolerance',
      'Tolerance must be positive and finite.',
    );
  }
  if (maxIterations <= 0) {
    throw ArgumentError.value(
      maxIterations,
      'maxIterations',
      'Max iterations must be positive.',
    );
  }
  if (step <= 0.0 || !step.isFinite) {
    throw ArgumentError.value(
      step,
      'step',
      'Step must be positive and finite.',
    );
  }
  if (memorySize <= 0) {
    throw ArgumentError.value(
      memorySize,
      'memorySize',
      'Memory size must be positive.',
    );
  }
  if (bounds != null && bounds.isNotEmpty && bounds.length != dim) {
    throw ArgumentError(
      'Bounds length (${bounds.length}) must match initial point dimension ($dim).',
    );
  }

  final baseGradFn =
      gradient ?? ((Vector<double> vec) => calculus.gradient(fn, vec));

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

    final Vector<double> endY;
    final int iters;
    final double gNorm;
    final bool conv;

    if (method == OptimizationMethod.nelderMead) {
      final nmRes = nelderMead(
        transformedFn,
        y0,
        step: step,
        tolerance: tolerance,
        maxIterations: maxIterations,
      );
      endY = nmRes.point;
      iters = nmRes.iterations;
      gNorm = transformedGrad(nmRes.point).norm();
      conv = nmRes.converged;
    } else if (method == OptimizationMethod.lbfgs) {
      final lbfgsRes = lbfgs(
        transformedFn,
        y0,
        gradient: transformedGrad,
        memorySize: memorySize,
        tolerance: tolerance,
        maxIterations: maxIterations,
      );
      endY = lbfgsRes.point;
      iters = lbfgsRes.iterations;
      gNorm = lbfgsRes.gradientNorm;
      conv = lbfgsRes.gradientNorm <= tolerance;
    } else {
      final bfgsResult = bfgs(
        transformedFn,
        y0,
        gradient: transformedGrad,
        tolerance: tolerance,
        maxIterations: maxIterations,
      );
      endY = bfgsResult.point;
      iters = bfgsResult.iterations;
      gNorm = bfgsResult.gradientNorm;
      conv = bfgsResult.gradientNorm <= tolerance;
    }

    final xAtEnd = boxTransform.toX(endY);
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
      gradientNorm: gNorm,
      iterations: iters,
      converged: conv,
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

    final innerMax = math.min(
      remainingIterations,
      math.max(20, maxIterations ~/ 2),
    );
    final ({Vector<double> point, int iterations, double gradientNorm})
    subResult;
    if (method == OptimizationMethod.nelderMead) {
      final nmRes = nelderMead(
        transformedAugmentedLagrangian,
        currentY,
        step: step,
        tolerance: math.max(tolerance * 0.1, 1e-8),
        maxIterations: innerMax,
      );
      final gNorm = transformedAugmentedLagrangianGrad(nmRes.point).norm();
      subResult = (
        point: nmRes.point,
        iterations: nmRes.iterations,
        gradientNorm: gNorm,
      );
    } else if (method == OptimizationMethod.lbfgs) {
      final lbfgsRes = lbfgs(
        transformedAugmentedLagrangian,
        currentY,
        gradient: transformedAugmentedLagrangianGrad,
        memorySize: memorySize,
        tolerance: math.max(tolerance * 0.1, 1e-8),
        maxIterations: innerMax,
      );
      subResult = (
        point: lbfgsRes.point,
        iterations: lbfgsRes.iterations,
        gradientNorm: lbfgsRes.gradientNorm,
      );
    } else {
      final bfgsRes = bfgs(
        transformedAugmentedLagrangian,
        currentY,
        gradient: transformedAugmentedLagrangianGrad,
        tolerance: math.max(tolerance * 0.1, 1e-8),
        maxIterations: innerMax,
      );
      subResult = (
        point: bfgsRes.point,
        iterations: bfgsRes.iterations,
        gradientNorm: bfgsRes.gradientNorm,
      );
    }

    totalIterations += subResult.iterations;
    currentY = subResult.point;
    currentPoint = boxTransform.toX(currentY);
    lastGradNorm = subResult.gradientNorm;

    var maxViolation = 0.0;
    for (var j = 0; j < numIneq; j++) {
      final gj = parsedIneqs[j].evaluate(currentPoint);
      if (!gj.isFinite) {
        maxViolation = double.infinity;
      } else {
        if (gj > maxViolation) maxViolation = gj;
        lambda[j] = math.max(0.0, lambda[j] + mu * gj);
      }
    }
    for (var k = 0; k < numEq; k++) {
      final hk = parsedEqs[k].evaluate(currentPoint);
      if (!hk.isFinite) {
        maxViolation = double.infinity;
      } else {
        final absHk = hk.abs();
        if (absHk > maxViolation) maxViolation = absHk;
        nu[k] += mu * hk;
      }
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
  new(List<BoxBound>? bounds) {
    if (bounds == null) {
      _lowers = null;
      _uppers = null;
      return;
    }
    final lowers = List<double?>.filled(bounds.length, null);
    final uppers = List<double?>.filled(bounds.length, null);
    for (var i = 0; i < bounds.length; i++) {
      final b = bounds[i];
      final rawLower = b.lower;
      final rawUpper = b.upper;
      if (rawLower != null && (rawLower.isNaN || rawLower == double.infinity)) {
        throw ArgumentError('Invalid lower bound ($rawLower) at index $i.');
      }
      if (rawUpper != null &&
          (rawUpper.isNaN || rawUpper == double.negativeInfinity)) {
        throw ArgumentError('Invalid upper bound ($rawUpper) at index $i.');
      }
      final lower = (rawLower == null || rawLower == double.negativeInfinity)
          ? null
          : rawLower;
      final upper = (rawUpper == null || rawUpper == double.infinity)
          ? null
          : rawUpper;
      if (lower != null && upper != null && lower >= upper) {
        throw ArgumentError(
          'Lower bound ($lower) must be strictly less than upper bound ($upper) at index $i.',
        );
      }
      lowers[i] = lower;
      uppers[i] = upper;
    }
    _lowers = lowers;
    _uppers = uppers;
  }

  late final List<double?>? _lowers;
  late final List<double?>? _uppers;

  Vector<double> toX(Vector<double> y) {
    final lowers = _lowers;
    final uppers = _uppers;
    if (lowers == null || uppers == null) return y.copy();
    final dim = y.length;
    final x = Vector<double>.filled(dim, 0.0, type: DataType.float64);
    for (var i = 0; i < dim; i++) {
      final lower = lowers[i];
      final upper = uppers[i];
      final yi = y.getUnchecked(i);
      if (lower != null && upper != null) {
        x.setUnchecked(i, lower + (upper - lower) * _sigmoid(yi));
      } else if (lower != null) {
        final clampedYi = yi.clamp(-50.0, 50.0);
        x.setUnchecked(i, lower + math.exp(clampedYi));
      } else if (upper != null) {
        final clampedYi = yi.clamp(-50.0, 50.0);
        x.setUnchecked(i, upper - math.exp(-clampedYi));
      } else {
        x.setUnchecked(i, yi);
      }
    }
    return x;
  }

  Vector<double> toY(Vector<double> x) {
    final lowers = _lowers;
    final uppers = _uppers;
    if (lowers == null || uppers == null) return x.copy();
    final dim = x.length;
    final y = Vector<double>.filled(dim, 0.0, type: DataType.float64);
    for (var i = 0; i < dim; i++) {
      final lower = lowers[i];
      final upper = uppers[i];
      final xi = x.getUnchecked(i);
      if (lower != null && upper != null) {
        final span = upper - lower;
        final double t;
        if (xi <= lower) {
          t = 0.05;
        } else if (xi >= upper) {
          t = 0.95;
        } else {
          t = ((xi - lower) / span).clamp(1e-12, 1.0 - 1e-12);
        }
        y.setUnchecked(i, math.log(t / (1.0 - t)));
      } else if (lower != null) {
        final d = xi <= lower ? 0.1 : math.max(xi - lower, 1e-12);
        y.setUnchecked(i, math.log(d));
      } else if (upper != null) {
        final d = xi >= upper ? 0.1 : math.max(upper - xi, 1e-12);
        y.setUnchecked(i, -math.log(d));
      } else {
        y.setUnchecked(i, xi);
      }
    }
    return y;
  }

  Vector<double> chainRuleGradient(Vector<double> gradX, Vector<double> y) {
    final lowers = _lowers;
    final uppers = _uppers;
    if (lowers == null || uppers == null) return gradX.copy();
    final dim = y.length;
    final gradY = Vector<double>.filled(dim, 0.0, type: DataType.float64);
    for (var i = 0; i < dim; i++) {
      final lower = lowers[i];
      final upper = uppers[i];
      final yi = y.getUnchecked(i);
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
      gradY.setUnchecked(i, gradX.getUnchecked(i) * dxiDyi);
    }
    return gradY;
  }

  Vector<double> projectToFeasible(
    Vector<double> x, {
    Vector<double>? gradX,
    double tolerance = 1e-6,
  }) {
    final lowers = _lowers;
    final uppers = _uppers;
    if (lowers == null || uppers == null) return x.copy();
    final dim = x.length;
    final res = Vector<double>.filled(dim, 0.0, type: DataType.float64);
    for (var i = 0; i < dim; i++) {
      final lower = lowers[i];
      final upper = uppers[i];
      var xi = x.getUnchecked(i);
      if (lower != null && upper != null) {
        final span = upper - lower;
        final tol = math.max(tolerance, span * tolerance);
        if (xi <= lower ||
            (xi - lower <= tol &&
                (gradX == null || gradX.getUnchecked(i) > 0.0))) {
          xi = lower;
        } else if (xi >= upper ||
            (upper - xi <= tol &&
                (gradX == null || gradX.getUnchecked(i) < 0.0))) {
          xi = upper;
        }
      } else if (lower != null) {
        if (xi <= lower ||
            (xi - lower <= tolerance &&
                (gradX == null || gradX.getUnchecked(i) > 0.0))) {
          xi = lower;
        }
      } else if (upper != null) {
        if (xi >= upper ||
            (upper - xi <= tolerance &&
                (gradX == null || gradX.getUnchecked(i) < 0.0))) {
          xi = upper;
        }
      }
      res.setUnchecked(i, xi);
    }
    return res;
  }
}

class _Constraint {
  new(
    this.fn, {
    required this.isInequality,
    Vector<double> Function(Vector<double>)? gradFn,
  }) : gradFn = gradFn ?? ((Vector<double> x) => calculus.gradient(fn, x));

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
