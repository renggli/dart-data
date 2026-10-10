import 'dart:math' as math;

import '../../linear.dart';

/// Trajectory of an ODE simulation containing time points [t] and state vectors [y].
class OdeSolution {
  /// Constructs an ODE solution.
  const new({required this.t, required this.y});

  /// The recorded time points.
  final List<double> t;

  /// The state vectors at each corresponding time point.
  final List<Vector<double>> y;

  /// The final state vector of the simulation.
  Vector<double> get last => y.last;

  /// Number of recorded steps.
  int get stepCount => t.length;
}

/// Solves an initial value problem $\frac{dy}{dt} = f(t, y)$ using classical
/// 4th order Runge-Kutta (RK4) with fixed step size [stepSize].
OdeSolution rk4({
  required Vector<double> Function(double t, Vector<double> y) f,
  required double t0,
  required double tEnd,
  required Vector<double> y0,
  double stepSize = 0.01,
}) {
  final tList = <double>[t0];
  final yList = <Vector<double>>[y0.copy()];

  var currentTime = t0;
  final y = y0.copy();
  final direction = tEnd >= t0 ? 1.0 : -1.0;
  var step = direction * stepSize.abs();

  while ((tEnd - currentTime) * direction > 1e-12) {
    if ((currentTime + step - tEnd) * direction > 0.0) {
      step = tEnd - currentTime;
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
    currentTime += step;

    tList.add(currentTime);
    yList.add(y.copy());
  }

  return OdeSolution(t: tList, y: yList);
}

/// Solves an initial value problem $\frac{dy}{dt} = f(t, y)$ using adaptive
/// Dormand-Prince 5(4) Runge-Kutta (RK45) with local error control.
OdeSolution rk45({
  required Vector<double> Function(double t, Vector<double> y) f,
  required double t0,
  required double tEnd,
  required Vector<double> y0,
  double initialStep = 0.01,
  double relativeTolerance = 1e-6,
  double absoluteTolerance = 1e-8,
  double minStep = 1e-12,
  double maxStep = 1.0,
  int maxSteps = 100000,
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
  while ((tEnd - currentTime) * direction > 1e-12 && stepCount < maxSteps) {
    stepCount++;
    if ((currentTime + step - tEnd) * direction > 0.0) {
      step = tEnd - currentTime;
    }

    // Dormand-Prince stage calculations
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

    // 5th order solution
    final y5 = (y.copy())
      ..addScaled(k1, step * (35.0 / 384.0))
      ..addScaled(k3, step * (500.0 / 1113.0))
      ..addScaled(k4, step * (125.0 / 192.0))
      ..addScaled(k5, -step * (2187.0 / 6784.0))
      ..addScaled(k6, step * (11.0 / 84.0));

    final k7 = f(currentTime + step, y5); // FSAL property

    // 4th order solution difference for error estimation
    final errorVec = (k1.scale(71.0 / 57600.0))
      ..addScaled(k3, -71.0 / 16695.0)
      ..addScaled(k4, 71.0 / 1920.0)
      ..addScaled(k5, -17253.0 / 339200.0)
      ..addScaled(k6, 22.0 / 525.0)
      ..addScaled(k7, -1.0 / 40.0)
      ..scaleInPlace(step);

    // Compute error norm relative to tolerance
    var maxErrorRatio = 0.0;
    for (var i = 0; i < y.length; i++) {
      final sc =
          absoluteTolerance +
          relativeTolerance * math.max(y[i].abs(), y5[i].abs());
      final ratio = errorVec[i].abs() / sc;
      if (ratio > maxErrorRatio) maxErrorRatio = ratio;
    }

    if (maxErrorRatio <= 1.0) {
      // Step accepted
      currentTime += step;
      y = y5;
      k1 = k7; // Re-use FSAL evaluation
      tList.add(currentTime);
      yList.add(y.copy());
    }

    // Adapt step size
    var factor =
        0.9 * math.pow(maxErrorRatio > 0.0 ? 1.0 / maxErrorRatio : 10.0, 0.2);
    factor = math.max(0.2, math.min(5.0, factor));
    step =
        direction * math.min(maxStep, math.max(minStep, (step * factor).abs()));
  }

  return OdeSolution(t: tList, y: yList);
}
