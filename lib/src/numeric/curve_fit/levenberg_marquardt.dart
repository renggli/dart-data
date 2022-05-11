import 'dart:math';

import 'package:more/tuple.dart';

import '../../../matrix.dart';
import '../../../type.dart';
import '../../../vector.dart';
import '../curve_fit.dart';

/// https://github.com/mljs/levenberg-marquardt
class LevenbergMarquardt extends CurveFit {
  LevenbergMarquardt(
    super.function, {
    this.initialDamping = 1e-2,
    this.dampingStepDown = 9.0,
    this.dampingStepUp = 11.0,
    this.improvementThreshold = 1e-3,
    double gradientDifference = 1e-1,
    List<double>? gradientDifferences,
    this.centralDifference = false,
    List<double>? minValues,
    List<double>? maxValues,
    required this.initialValues,
    this.maxIterations = 100,
    this.errorTolerance = 1e-7,
  })  : gradientDifferences = gradientDifferences ??
            List.generate(initialValues.length, (i) => gradientDifference),
        minValues = minValues ??
            List.generate(
                initialValues.length, (i) => DataType.int64.safeMin.toDouble()),
        maxValues = maxValues ??
            List.generate(initialValues.length,
                (i) => DataType.int64.safeMax.toDouble()) {
    if (initialDamping <= 0) {
      throw ArgumentError.value(
          initialDamping, 'damping', 'Expected positive damping factor.');
    }

    if (initialValues.isEmpty) {
      throw ArgumentError.value(
          initialValues, 'The function must have at least 1 parameter');
    }

    if (this.minValues.length != initialValues.length) {
      throw ArgumentError.value(
          minValues, 'The minValues must have the same size');
    }

    if (this.maxValues.length != initialValues.length) {
      throw ArgumentError.value(
          maxValues, 'The maxValues must have the same size');
    }

    if (this.gradientDifferences.length != initialValues.length) {
      throw ArgumentError.value(gradientDifferences,
          'The gradientDifferences must have the same size');
    }
  }

  /// Small values of the damping factor result in a Gauss-Newton update and
  /// large values in a gradient descent update.
  final double initialDamping;

  /// Factor to reduce the damping when there is not an improvement when
  /// updating parameters.
  final double dampingStepDown;

  /// Factor to increase the damping when there is an improvement when updating
  /// parameters.
  final double dampingStepUp;

  /// The threshold to define an improvement through an update of parameters.
  final double improvementThreshold;

  /// The step size to approximate each parameter in the jacobian matrix.
  final List<double> gradientDifferences;

  /// If true the jacobian matrix is approximated by central differences
  /// otherwise by forward differences.
  final bool centralDifference;

  /// Minimum allowed values for parameters.
  final List<double> minValues;

  /// Maximum allowed values for parameters.
  final List<double> maxValues;

  /// Array of initial parameter values.
  final List<double> initialValues;

  /// Maximum of allowed iterations
  final int maxIterations;

  /// Minimum uncertainty allowed for each point.
  final double errorTolerance;

  /// https://github.com/mljs/levenberg-marquardt
  @override
  FitResult fit({
    required List<double> x,
    required List<double> y,
    double weight = 1.0,
    List<double>? weights,
  }) {
    if (x.length < 2) {
      throw ArgumentError.value(x, 'x', 'Expected at least two points.');
    }

    if (y.length != x.length) {
      throw ArgumentError.value(y, 'y', 'Expected ${x.length} values.');
    }

    weights ??= List<double>.generate(y.length, (i) => weight);
    if (weights.length != x.length) {
      throw ArgumentError.value(
          weights, 'weights', 'Expected ${x.length} values.');
    }
    final squaredWeights = weights
        .map((weight) => weight * weight)
        .toList(growable: false)
        .toVector();

    var parameters = initialValues.toList(growable: false);
    var error = _errorCalculation(
        x: x, y: y, parameters: parameters, squaredWeights: squaredWeights);
    var optimalError = error;
    var optimalParameters = parameters.toList(growable: false);
    var converged = error <= errorTolerance;
    var damping = initialDamping;

    var iteration = 0;
    for (; iteration < maxIterations && !converged; iteration++) {
      var previousError = error;

      final stepResult = _step(
        x: x,
        y: y,
        params: parameters,
        damping: damping,
        squaredWeights: squaredWeights,
      );
      final perturbations = stepResult.first;
      final jacobianWeightResidualError = stepResult.second;

      for (var k = 0; k < parameters.length; k++) {
        parameters[k] = (parameters[k] - perturbations.get(k, 0))
            .clamp(minValues[k], maxValues[k]);
      }

      error = _errorCalculation(
        x: x,
        y: y,
        parameters: parameters,
        squaredWeights: squaredWeights,
      );
      if (error.isNaN) break;

      if (error < optimalError - errorTolerance) {
        optimalError = error;
        optimalParameters = parameters.toList(growable: false);
      }

      var improvementMetric = (previousError - error) /
          perturbations.transposed
              .mulMatrix(perturbations
                  .mulScalar(damping)
                  .add(jacobianWeightResidualError))
              .get(0, 0);

      if (improvementMetric > improvementThreshold) {
        damping = max(damping / dampingStepDown, 1e-7);
      } else {
        damping = min(damping * dampingStepUp, 1e7);
      }

      converged = error <= errorTolerance;
    }

    return FitResult(
      parameterValues: optimalParameters,
      parameterError: optimalError,
      iterationCount: iteration,
    );
  }

  /// the sum of the weighted squares of the errors (or weighted residuals)
  /// between the y and the curve-fit function.
  double _errorCalculation({
    required List<double> x,
    required List<double> y,
    required List<double> parameters,
    required Vector<double> squaredWeights,
  }) {
    var error = 0.0;
    for (var i = 0; i < x.length; i++) {
      final delta = y[i] - function(parameters, x[i]);
      error += squaredWeights.getUnchecked(i) * delta * delta;
    }
    return error;
  }

  /// Iteration for Levenberg-Marquardt.
  Tuple2<Matrix<double>, Matrix<double>> _step({
    required List<double> x,
    required List<double> y,
    required List<double> params,
    required double damping,
    required Vector<double> squaredWeights,
  }) {
    var identity = Matrix.identity(
        DataType.float64, params.length, params.length,
        value: damping);
    var evaluatedData = Vector.generate(
        DataType.float64, x.length, (i) => function(params, x[i]));

    var gradientFunc = _gradientFunction(
      x: x,
      y: y,
      evaluatedData: evaluatedData,
      params: params,
    );
    var residualError =
        _matrixFunction(x: x, y: y, evaluatedData: evaluatedData);
    final inverseMatrix = identity
        .add(gradientFunc.mulMatrix(gradientFunc.transposed
            .applyByRow(identity.dataType.field.mul, squaredWeights)))
        .inverse;
    var jacobianWeightResidualError = gradientFunc.mulMatrix(
        residualError.applyByRow(identity.dataType.field.mul, squaredWeights));
    var perturbations = inverseMatrix.mulMatrix(jacobianWeightResidualError);
    return Tuple2(perturbations, jacobianWeightResidualError);
  }

  /// Difference of the matrix function over the parameters.
  Matrix<double> _gradientFunction({
    required List<double> x,
    required List<double> y,
    required Vector<double> evaluatedData,
    required List<double> params,
  }) {
    final nbParams = params.length;
    final nbPoints = x.length;
    final ans = Matrix(DataType.float64, nbParams, nbPoints);

    var rowIndex = 0;
    for (var param = 0; param < nbParams; param++) {
      if (gradientDifferences[param] == 0) continue;
      var delta = gradientDifferences[param];
      var auxParams = params.toList(growable: false);
      auxParams[param] += delta;
      if (centralDifference) {
        var auxParams2 = params.toList(growable: false);
        auxParams2[param] -= delta;
        delta *= 2;
        for (var point = 0; point < nbPoints; point++) {
          ans.set(
            rowIndex,
            point,
            (function(auxParams2, x[point]) - function(auxParams, x[point])) /
                delta,
          );
        }
      } else {
        for (var point = 0; point < nbPoints; point++) {
          ans.set(
            rowIndex,
            point,
            (evaluatedData[point] - function(auxParams, x[point])) / delta,
          );
        }
      }
      rowIndex++;
    }

    return ans;
  }

  /// Matrix function over the samples.
  Matrix<double> _matrixFunction({
    required List<double> x,
    required List<double> y,
    required Vector<double> evaluatedData,
  }) {
    final ans = Matrix(DataType.float64, x.length, 1);
    for (var point = 0; point < x.length; point++) {
      ans.set(point, 0, y[point] - evaluatedData[point]);
    }
    return ans;
  }
}
