import 'dart:math';

import 'package:more/tuple.dart';

import '../../../matrix.dart';
import '../../../type.dart';
import '../../../vector.dart';
import '../../shared/config.dart';
import '../curve_fit.dart';
import '../types.dart';

/// https://github.com/mljs/levenberg-marquardt
class LevenbergMarquardt extends CurveFit {
  LevenbergMarquardt(
    this.function, {
    this.initialDamping = 1e-2,
    this.dampingStepDown = 9.0,
    this.dampingStepUp = 11.0,
    this.improvementThreshold = 1e-3,
    double gradientDifference = 1e-1,
    Vector<double>? gradientDifferences,
    this.centralDifference = false,
    Vector<double>? minValues,
    Vector<double>? maxValues,
    required this.initialValues,
    this.maxIterations = 100,
    this.errorTolerance = 1e-7,
  })  : gradientDifferences = gradientDifferences ??
            Vector<double>.constant(floatDataType, initialValues.count,
                value: gradientDifference),
        minValues = minValues ??
            Vector<double>.constant(floatDataType, initialValues.count,
                value: intDataType.safeMin.toDouble()),
        maxValues = maxValues ??
            Vector<double>.constant(floatDataType, initialValues.count,
                value: intDataType.safeMax.toDouble()) {
    if (initialDamping <= 0) {
      throw ArgumentError.value(
          initialDamping, 'damping', 'Expected positive damping factor.');
    }

    if (initialValues.count == 0) {
      throw ArgumentError.value(initialValues, 'initialValues',
          'The function must have at least 1 parameter');
    }

    if (this.minValues.count != initialValues.count) {
      throw ArgumentError.value(
          minValues, 'The minValues must have the same size');
    }

    if (this.maxValues.count != initialValues.count) {
      throw ArgumentError.value(
          maxValues, 'The maxValues must have the same size');
    }

    if (this.gradientDifferences.count != initialValues.count) {
      throw ArgumentError.value(gradientDifferences,
          'The gradientDifferences must have the same size');
    }
  }

  /// A function with a list of params and the current value.
  final ParameterizedFunction function;

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
  final Vector<double> gradientDifferences;

  /// If true the jacobian matrix is approximated by central differences
  /// otherwise by forward differences.
  final bool centralDifference;

  /// Minimum allowed values for parameters.
  final Vector<double> minValues;

  /// Maximum allowed values for parameters.
  final Vector<double> maxValues;

  /// Array of initial parameter values.
  final Vector<double> initialValues;

  /// Maximum of allowed iterations
  final int maxIterations;

  /// Minimum uncertainty allowed for each point.
  final double errorTolerance;

  /// https://github.com/mljs/levenberg-marquardt
  @override
  LevenbergMarquardtResult fit({
    required Vector<double> x,
    required Vector<double> y,
    double weight = 1.0,
    Vector<double>? weights,
  }) {
    if (x.count < 2) {
      throw ArgumentError.value(x, 'x', 'Expected at least two points.');
    }

    if (y.count != x.count) {
      throw ArgumentError.value(y, 'y', 'Expected ${x.count} values.');
    }

    weights ??= Vector<double>.constant(floatDataType, y.count, value: weight);
    if (weights.count != x.count) {
      throw ArgumentError.value(
          weights, 'weights', 'Expected ${x.count} values.');
    }
    final squaredWeights =
        weights.map((i, v) => v * v, floatDataType).toVector();

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

    return LevenbergMarquardtResult(
      (x) => function(optimalParameters, x),
      parameterValues: optimalParameters,
      parameterError: optimalError,
      iterationCount: iteration,
    );
  }

  /// the sum of the weighted squares of the errors (or weighted residuals)
  /// between the y and the curve-fit function.
  double _errorCalculation({
    required Vector<double> x,
    required Vector<double> y,
    required List<double> parameters,
    required Vector<double> squaredWeights,
  }) {
    var error = 0.0;
    for (var i = 0; i < x.count; i++) {
      final delta = y[i] - function(parameters, x[i]);
      error += squaredWeights.getUnchecked(i) * delta * delta;
    }
    return error;
  }

  /// Iteration for Levenberg-Marquardt.
  Tuple2<Matrix<double>, Matrix<double>> _step({
    required Vector<double> x,
    required Vector<double> y,
    required List<double> params,
    required double damping,
    required Vector<double> squaredWeights,
  }) {
    var identity = Matrix.identity(
        DataType.float64, params.length, params.length,
        value: damping);
    var evaluatedData = Vector.generate(
        DataType.float64, x.count, (i) => function(params, x[i]));

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
    required Vector<double> x,
    required Vector<double> y,
    required Vector<double> evaluatedData,
    required List<double> params,
  }) {
    final nbParams = params.length;
    final nbPoints = x.count;
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
    required Vector<double> x,
    required Vector<double> y,
    required Vector<double> evaluatedData,
  }) {
    final ans = Matrix(DataType.float64, x.count, 1);
    for (var point = 0; point < x.count; point++) {
      ans.set(point, 0, y[point] - evaluatedData[point]);
    }
    return ans;
  }
}

class LevenbergMarquardtResult extends CurveFitResult {
  LevenbergMarquardtResult(
    super.function, {
    required this.parameterValues,
    required this.parameterError,
    required this.iterationCount,
  });

  final List<double> parameterValues;
  final double parameterError;
  final int iterationCount;
}
