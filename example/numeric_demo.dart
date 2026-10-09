import 'dart:io';
import 'dart:math' as math;

import 'package:data/data.dart';

void main() {
  stdout.writeln('=== Package:Data Modern Numerical Algorithms Demo ===\n');

  // 1. Fast Fourier Transform (FFT)
  stdout.writeln('1. Fast Fourier Transform (FFT)');
  const n = 8;
  final signal = List<double>.generate(
    n,
    (i) => math.sin(2.0 * math.pi * 1.0 * i / n),
  );
  stdout.writeln('   Time-domain signal: $signal');
  final spectrum = rfft(signal);
  stdout.writeln('   Frequency spectrum (rfft): $spectrum');
  final reconstructed = irfft(spectrum, n);
  stdout.writeln('   Reconstructed signal (irfft): $reconstructed\n');

  // 2. Numerical Integration
  stdout.writeln('2. Numerical Integration');
  // Exact integral of sin(x) from 0 to pi is 2.0
  final simpsonResult = adaptiveSimpson(math.sin, 0.0, math.pi);
  final kronrodResult = gaussKronrod(math.sin, 0.0, math.pi);
  stdout.writeln(
    '   Simpson integral of sin(x) on [0, π]: $simpsonResult (exact: 2.0)',
  );
  stdout.writeln(
    '   Gauss-Kronrod integral of sin(x): $kronrodResult (exact: 2.0)\n',
  );

  // 3. Root Finding
  stdout.writeln('3. Root Finding');
  // Find root of cos(x) - x = 0 (Dottie number ≈ 0.739085)
  final brentR = brentRoot((double x) => math.cos(x) - x, 0.0, 1.0);
  stdout.writeln('   Brent-Dekker root of cos(x) - x = 0: $brentR\n');

  // 4. Non-Linear Optimization (Rosenbrock Banana Function)
  stdout.writeln('4. Optimization (Rosenbrock Banana Function)');
  double rosenbrock(Vector<double> v) {
    final x = v[0];
    final y = v[1];
    final d1 = 1.0 - x;
    final d2 = y - x * x;
    return d1 * d1 + 100.0 * d2 * d2;
  }

  final start = Vector<double>.fromList([-1.2, 1.0], type: DataType.float64);
  final optResult = bfgs(rosenbrock, start);
  stdout.writeln(
    '   BFGS minimum at (${optResult.point[0]}, ${optResult.point[1]}) with value ${optResult.value}\n',
  );

  // 5. Adaptive ODE Integration (RK45)
  stdout.writeln('5. Adaptive ODE Integration (RK45 - Harmonic Oscillator)');
  // d^2 y / dt^2 = -y -> y' = v, v' = -y. Initial y(0) = 0, v(0) = 1.
  Vector<double> oscillator(double t, Vector<double> state) =>
      Vector<double>.fromList([state[1], -state[0]], type: DataType.float64);

  final y0 = Vector<double>.fromList([0.0, 1.0], type: DataType.float64);
  final odeSol = rk45(f: oscillator, t0: 0.0, tEnd: 2.0 * math.pi, y0: y0);
  stdout.writeln('   Steps taken: ${odeSol.t.length}');
  stdout.writeln(
    '   Final state at t = 2π: [y = ${odeSol.last[0]}, v = ${odeSol.last[1]}]',
  );
  stdout.writeln('   (Expected exact: [y = 0.0, v = 1.0])\n');

  // 6. Non-Linear Curve Fitting (Levenberg-Marquardt)
  stdout.writeln('6. Curve Fitting (Levenberg-Marquardt)');
  // Target: y = 2.5 * exp(-0.8 * x)
  final xData = [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0];
  final yData = xData.map((x) => 2.5 * math.exp(-0.8 * x)).toList();
  Vector<double> expResiduals(Vector<double> p) {
    final res = <double>[];
    for (var i = 0; i < xData.length; i++) {
      final pred = p[0] * math.exp(-p[1] * xData[i]);
      res.add(pred - yData[i]);
    }
    return Vector<double>.fromList(res, type: DataType.float64);
  }

  final initialGuess = Vector<double>.fromList([
    1.0,
    1.0,
  ], type: DataType.float64);
  final fit = levenbergMarquardt(
    residualFunction: expResiduals,
    initialParams: initialGuess,
  );
  stdout.writeln('   Fitted parameters: a = ${fit[0]}, b = ${fit[1]}');
  stdout.writeln('   (Target: a = 2.5, b = 0.8)');
}
