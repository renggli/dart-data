import 'dart:math' as math;

import '../../../linear.dart';
import '../../../type.dart';
import '../calculus/gradient.dart' as calculus;
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

    final bfgsResult = bfgs(
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
    final subResult = bfgs(
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
