import 'dart:math' as math;

import '../../../linear.dart';
import '../../../type.dart';

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
  return (
    point: simplex[bestIdx],
    value: values[bestIdx],
    iterations: iter,
    converged: false,
  );
}
