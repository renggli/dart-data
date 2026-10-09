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

  var t = t0;
  var y = y0.copy();
  final direction = tEnd >= t0 ? 1.0 : -1.0;
  var h = direction * stepSize.abs();

  while ((tEnd - t) * direction > 1e-12) {
    if ((t + h - tEnd) * direction > 0.0) {
      h = tEnd - t;
    }

    final k1 = f(t, y);
    final k2 = f(t + 0.5 * h, y + k1.scale(0.5 * h));
    final k3 = f(t + 0.5 * h, y + k2.scale(0.5 * h));
    final k4 = f(t + h, y + k3.scale(h));

    final dy = (k1 + k2.scale(2.0) + k3.scale(2.0) + k4).scale(h / 6.0);
    y = y + dy;
    t += h;

    tList.add(t);
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

  var t = t0;
  var y = y0.copy();
  final direction = tEnd >= t0 ? 1.0 : -1.0;
  var h = direction * math.min(maxStep, math.max(minStep, initialStep.abs()));

  var k1 = f(t, y);

  var stepCount = 0;
  while ((tEnd - t) * direction > 1e-12 && stepCount < maxSteps) {
    stepCount++;
    if ((t + h - tEnd) * direction > 0.0) {
      h = tEnd - t;
    }

    // Dormand-Prince stage calculations
    final k2 = f(
      t + h * (1.0 / 5.0),
      y + k1.scale(h * (1.0 / 5.0)),
    );
    final k3 = f(
      t + h * (3.0 / 10.0),
      y + k1.scale(h * (3.0 / 40.0)) + k2.scale(h * (9.0 / 40.0)),
    );
    final k4 = f(
      t + h * (4.0 / 5.0),
      y +
          k1.scale(h * (44.0 / 45.0)) -
          k2.scale(h * (56.0 / 15.0)) +
          k3.scale(h * (32.0 / 9.0)),
    );
    final k5 = f(
      t + h * (8.0 / 9.0),
      y +
          k1.scale(h * (19372.0 / 6561.0)) -
          k2.scale(h * (25360.0 / 2187.0)) +
          k3.scale(h * (64448.0 / 6561.0)) -
          k4.scale(h * (212.0 / 729.0)),
    );
    final k6 = f(
      t + h,
      y +
          k1.scale(h * (9017.0 / 3168.0)) -
          k2.scale(h * (355.0 / 33.0)) +
          k3.scale(h * (46732.0 / 5247.0)) +
          k4.scale(h * (49.0 / 176.0)) -
          k5.scale(h * (5103.0 / 18656.0)),
    );

    // 5th order solution
    final y5 = y +
        (k1.scale(35.0 / 384.0) +
                k3.scale(500.0 / 1113.0) +
                k4.scale(125.0 / 192.0) -
                k5.scale(2187.0 / 6784.0) +
                k6.scale(11.0 / 84.0))
            .scale(h);

    final k7 = f(t + h, y5); // FSAL property

    // 4th order solution difference for error estimation
    final errorVec = (k1.scale(71.0 / 57600.0) -
            k3.scale(71.0 / 16695.0) +
            k4.scale(71.0 / 1920.0) -
            k5.scale(17253.0 / 339200.0) +
            k6.scale(22.0 / 525.0) -
            k7.scale(1.0 / 40.0))
        .scale(h);

    // Compute error norm relative to tolerance
    var maxErrorRatio = 0.0;
    for (var i = 0; i < y.length; i++) {
      final sc = absoluteTolerance +
          relativeTolerance * math.max(y[i].abs(), y5[i].abs());
      final ratio = errorVec[i].abs() / sc;
      if (ratio > maxErrorRatio) maxErrorRatio = ratio;
    }

    if (maxErrorRatio <= 1.0) {
      // Step accepted
      t += h;
      y = y5;
      k1 = k7; // Re-use FSAL evaluation
      tList.add(t);
      yList.add(y.copy());
    }

    // Adapt step size
    var factor = 0.9 * math.pow(maxErrorRatio > 0.0 ? 1.0 / maxErrorRatio : 10.0, 0.2);
    factor = math.max(0.2, math.min(5.0, factor));
    h = direction * math.min(maxStep, math.max(minStep, (h * factor).abs()));
  }

  return OdeSolution(t: tList, y: yList);
}
