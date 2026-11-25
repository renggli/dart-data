import 'dart:math' as math;

import '../../linear/vector.dart';
import '../../type/data_type.dart';

/// Derivative-free Nelder-Mead downhill simplex algorithm.
({Vector<double> point, double value, int iterations, bool converged})
nelderMead(
  double Function(Vector<double>) fn,
  Vector<double> initialPoint, {
  double step = 1.0,
  double tolerance = 1e-8,
  int maxIterations = 1000,
}) {
  final dim = initialPoint.length;
  if (dim == 0) {
    throw ArgumentError('Initial point cannot be empty.');
  }
  if (step <= 0.0 || !step.isFinite) {
    throw ArgumentError.value(
      step,
      'step',
      'Step must be positive and finite.',
    );
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

  final simplex = <Vector<double>>[initialPoint.copy()];
  for (var i = 0; i < dim; i++) {
    final vertex = initialPoint.copy();
    vertex[i] += vertex[i] == 0.0 ? step : vertex[i].abs() * 0.05 + step;
    simplex.add(vertex);
  }

  final values = [for (final pt in simplex) fn(pt)];
  final indices = List<int>.generate(dim + 1, (i) => i);
  final centroid = Vector<double>.filled(dim, 0.0, type: DataType.float64);

  const alpha = 1.0; // reflection
  const gamma = 2.0; // expansion
  const rho = 0.5; // contraction
  const sigma = 0.5; // shrink

  var iter = 0;
  for (; iter < maxIterations; iter++) {
    indices.sort(
      (a, b) => _safeValue(values[a]).compareTo(_safeValue(values[b])),
    );

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
    var maxDist = 0.0;
    for (var i = 1; i <= dim; i++) {
      final diff = simplex[indices[i]] - simplex[bestIdx];
      maxDist = math.max(maxDist, diff.norm());
    }

    if (math.sqrt(variance / (dim + 1)) < tolerance && maxDist < tolerance) {
      return (
        point: simplex[bestIdx],
        value: values[bestIdx],
        iterations: iter,
        converged: true,
      );
    }

    for (var dimIdx = 0; dimIdx < dim; dimIdx++) {
      centroid.setUnchecked(dimIdx, 0.0);
    }
    for (var i = 0; i < dim; i++) {
      final v = simplex[indices[i]];
      for (var dimIdx = 0; dimIdx < dim; dimIdx++) {
        centroid.setUnchecked(
          dimIdx,
          centroid.getUnchecked(dimIdx) + v.getUnchecked(dimIdx),
        );
      }
    }
    for (var dimIdx = 0; dimIdx < dim; dimIdx++) {
      centroid.setUnchecked(dimIdx, centroid.getUnchecked(dimIdx) / dim);
    }

    final safeBest = _safeValue(values[bestIdx]);
    final safeSecondWorst = _safeValue(values[secondWorstIdx]);
    final safeWorst = _safeValue(values[worstIdx]);

    // 1. Reflection
    final xR = centroid + (centroid - simplex[worstIdx]).scale(alpha);
    final fR = fn(xR);
    final safeR = _safeValue(fR);

    if (safeR < safeSecondWorst && safeR >= safeBest) {
      simplex[worstIdx] = xR;
      values[worstIdx] = fR;
      continue;
    }

    // 2. Expansion
    if (safeR < safeBest) {
      final xE = centroid + (xR - centroid).scale(gamma);
      final fE = fn(xE);
      if (_safeValue(fE) < safeR) {
        simplex[worstIdx] = xE;
        values[worstIdx] = fE;
      } else {
        simplex[worstIdx] = xR;
        values[worstIdx] = fR;
      }
      continue;
    }

    // 3. Contraction
    if (safeR < safeWorst) {
      final xC = centroid + (xR - centroid).scale(rho);
      final fC = fn(xC);
      if (_safeValue(fC) <= safeR) {
        simplex[worstIdx] = xC;
        values[worstIdx] = fC;
        continue;
      }
    } else {
      final xC = centroid + (simplex[worstIdx] - centroid).scale(rho);
      final fC = fn(xC);
      if (_safeValue(fC) < safeWorst) {
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

  var bestIdx = 0;
  for (var i = 1; i <= dim; i++) {
    final vi = values[i];
    final vb = values[bestIdx];
    if (!vi.isNaN && (vb.isNaN || vi < vb)) {
      bestIdx = i;
    }
  }
  return (
    point: simplex[bestIdx],
    value: values[bestIdx],
    iterations: iter,
    converged: false,
  );
}

double _safeValue(double value) => value.isNaN ? double.infinity : value;
