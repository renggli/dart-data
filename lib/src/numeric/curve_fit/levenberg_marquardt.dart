import 'dart:math';

import 'package:more/tuple.dart';

import '../../../matrix.dart';
import '../../../type.dart';
import '../../../vector.dart';
import '../../shared/checks.dart';
import '../curve_fit.dart';
import '../functions.dart';

/// The Levenberg–Marquardt algorithm, also known as the damped least-squares
/// method, is used to solve non-linear least squares problems.
///
/// See https://en.wikipedia.org/wiki/Levenberg%E2%80%93Marquardt_algorithm.
class LevenbergMarquardt extends CurveFit {
  LevenbergMarquardt(
    this.parametrizedFunction, {
    double? initialValue,
    dynamic initialValues,
    double? minValue,
    dynamic minValues,
    double? maxValue,
    dynamic maxValues,
    double gradientDifference = 1e-1,
    dynamic gradientDifferences,
    this.damping = 1e-2,
    this.dampingStepDown = 9.0,
    this.dampingStepUp = 11.0,
    this.centralDifference = false,
    this.improvementThreshold = 1e-3,
    this.errorTolerance = 1e-7,
    this.maxIterations = 100,
  })  : initialValues = parametrizedFunction.toVector(initialValues,
            defaultParam: initialValue),
        minValues = parametrizedFunction.toVector(minValues,
            defaultParam: minValue ?? DataType.integer.safeMin.toDouble()),
        maxValues = parametrizedFunction.toVector(maxValues,
            defaultParam: maxValue ?? DataType.integer.safeMax.toDouble()),
        gradientDifferences = parametrizedFunction.toVector(gradientDifferences,
            defaultParam: gradientDifference) {
    if (parametrizedFunction.count == 0) {
      throw ArgumentError.value(parametrizedFunction, 'parametrizedFunction',
          'Expected at least 1 parameter.');
    }
    if (damping <= 0.0) {
      throw ArgumentError.value(
          damping, 'damping', 'Expected positive damping factor.');
    }
  }

  /// A parametrized function
  final ParametrizedUnaryFunction<double> parametrizedFunction;

  /// A vector of initial parameter values.
  final Vector<double> initialValues;

  /// Minimum allowed values for parameters.
  final Vector<double> minValues;

  /// Maximum allowed values for parameters.
  final Vector<double> maxValues;

  /// The step size to approximate each parameter in the Jacobian matrix.
  final Vector<double> gradientDifferences;

  /// Small values of the damping factor result in a Gauss-Newton update and
  /// large values in a gradient descent update.
  final double damping;

  /// Factor to reduce the damping when there is not an improvement when
  /// updating parameters.
  final double dampingStepDown;

  /// Factor to increase the damping when there is an improvement when updating
  /// parameters.
  final double dampingStepUp;

  /// If true the Jacobian matrix is approximated by central differences
  /// otherwise by forward differences.
  final bool centralDifference;

  /// The threshold to define an improvement through an update of parameters.
  final double improvementThreshold;

  /// Minimum uncertainty allowed for each point.
  final double errorTolerance;

  /// Maximum of allowed iterations
  final int maxIterations;

  @override
  LevenbergMarquardtResult fit({
    required Vector<double> xs,
    required Vector<double> ys,
    double weight = 1.0,
    Vector<double>? weights,
  }) {
    checkPoints(DataType.float, xs: xs, ys: ys, min: 2);

    weights ??=
        Vector<double>.constant(DataType.float, ys.count, value: weight);
    if (weights.count != xs.count) {
      throw ArgumentError.value(
          weights, 'weights', 'Expected ${xs.count} values.');
    }
    final squaredWeights =
        weights.map((i, v) => v * v, DataType.float).toVector();

    final parameters = initialValues.toVector();
    var error = _errorCalculation(parametrizedFunction.bind(parameters),
        x: xs, y: ys, squaredWeights: squaredWeights);
    var optimalError = error;
    var optimalParameters = parameters.toVector();
    var converged = error <= errorTolerance;
    var currentDamping = damping;

    var iteration = 0;
    for (; iteration < maxIterations && !converged; iteration++) {
      final previousError = error;

      final stepResult = _step(
        x: xs,
        y: ys,
        params: parameters,
        currentDamping: currentDamping,
        squaredWeights: squaredWeights,
      );
      final perturbations = stepResult.first;
      final jacobianWeightResidualError = stepResult.second;

      for (var k = 0; k < parameters.count; k++) {
        parameters[k] = (parameters[k] - perturbations.get(k, 0))
            .clamp(minValues[k], maxValues[k]);
      }

      error = _errorCalculation(
        parametrizedFunction.bind(parameters),
        x: xs,
        y: ys,
        squaredWeights: squaredWeights,
      );
      if (error.isNaN) break;

      if (error < optimalError - errorTolerance) {
        optimalError = error;
        optimalParameters = parameters.toVector();
      }

      final improvementMetric = (previousError - error) /
          (perturbations.transposed *
                  (perturbations * currentDamping +
                      jacobianWeightResidualError))
              .get(0, 0);

      if (improvementMetric > improvementThreshold) {
        currentDamping = max(currentDamping / dampingStepDown, 1e-7);
      } else {
        currentDamping = min(currentDamping * dampingStepUp, 1e7);
      }

      converged = error <= errorTolerance;
    }

    return LevenbergMarquardtResult(
      parametrizedFunction.bind(optimalParameters),
      parameters: parametrizedFunction.toBindings(optimalParameters),
      error: optimalError,
      iterations: iteration,
    );
  }

  /// the sum of the weighted squares of the errors (or weighted residuals)
  /// between the y and the curve-fit function.
  double _errorCalculation(
    UnaryFunction<double> function, {
    required Vector<double> x,
    required Vector<double> y,
    required Vector<double> squaredWeights,
  }) {
    var error = 0.0;
    for (var i = 0; i < x.count; i++) {
      final delta = y[i] - function(x[i]);
      error += squaredWeights.getUnchecked(i) * delta * delta;
    }
    return error;
  }

  /// Iteration for Levenberg-Marquardt.
  (Matrix<double>, Matrix<double>) _step({
    required Vector<double> x,
    required Vector<double> y,
    required Vector<double> params,
    required double currentDamping,
    required Vector<double> squaredWeights,
  }) {
    final function = parametrizedFunction.bind(params);
    final identity = Matrix.identity(
        DataType.float64, params.count, params.count,
        value: currentDamping);
    final evaluatedData =
        Vector.generate(DataType.float64, x.count, (i) => function(x[i]));

    final gradientFunc = _gradientFunction(
      x: x,
      y: y,
      evaluatedData: evaluatedData,
      params: params,
    );
    final residualError =
        _matrixFunction(x: x, y: y, evaluatedData: evaluatedData);
    final inverseMatrix = (identity +
            gradientFunc.mulMatrix(gradientFunc.transposed
                .applyByRow(identity.dataType.field.mul, squaredWeights)))
        .inverse;
    final jacobianWeightResidualError = gradientFunc.mulMatrix(
        residualError.applyByRow(identity.dataType.field.mul, squaredWeights));
    final perturbations = inverseMatrix.mulMatrix(jacobianWeightResidualError);
    return (perturbations, jacobianWeightResidualError);
  }

  /// Difference of the matrix function over the parameters.
  Matrix<double> _gradientFunction({
    required Vector<double> x,
    required Vector<double> y,
    required Vector<double> evaluatedData,
    required Vector<double> params,
  }) {
    final nbParams = params.count;
    final nbPoints = x.count;
    final ans = Matrix(DataType.float64, nbParams, nbPoints);

    var rowIndex = 0;
    for (var param = 0; param < nbParams; param++) {
      if (gradientDifferences[param] == 0) continue;
      var delta = gradientDifferences[param];
      final auxParams = params.toVector();
      auxParams[param] += delta;
      final funcParam = parametrizedFunction.bind(auxParams);
      if (centralDifference) {
        final auxParams2 = params.toVector();
        auxParams2[param] -= delta;
        delta *= 2;
        final funcParam2 = parametrizedFunction.bind(auxParams2);
        for (var point = 0; point < nbPoints; point++) {
          ans.set(
            rowIndex,
            point,
            (funcParam2(x[point]) - funcParam(x[point])) / delta,
          );
        }
      } else {
        for (var point = 0; point < nbPoints; point++) {
          ans.set(
            rowIndex,
            point,
            (evaluatedData[point] - funcParam(x[point])) / delta,
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
    required this.parameters,
    required this.error,
    required this.iterations,
  });

  final dynamic parameters;
  final double error;
  final int iterations;
}
