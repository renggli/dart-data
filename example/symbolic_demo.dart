import 'dart:io';

import 'package:data/data.dart';
import 'package:data/symbolic.dart';

void main() {
  stdout.writeln('=== Package:Data Symbolic Computation & CAS Demo ===\n');

  // 1. Exact Symbolic Arithmetic & Simplification
  stdout.writeln('1. Exact Symbolic Arithmetic & Simplification');
  const x = Variable('x');
  const y = Variable('y');
  const z = Variable('z');

  final radical = IntegerNumber.of(12).pow(FractionNumber.half).simplify();
  stdout.writeln('   sqrt(12) exact simplified: $radical');

  final poly = (x + 1) * (x - 1) * (x + 2);
  stdout.writeln('   Factored expression: $poly');
  stdout.writeln('   Expanded polynomial: ${poly.expand()}');
  stdout.writeln('   Re-factored back:    ${poly.expand().factor()}\n');

  // 2. Calculus: Derivatives, Integrals, Limits & Series
  stdout.writeln('2. Calculus (Derivatives, Integrals, Limits, Series)');
  final func = x.pow(3) + (x * 2) - 5;
  stdout.writeln('   f(x)  = $func');
  stdout.writeln('   f\'(x) = ${func.derivative('x').simplify()}');
  stdout.writeln('   f"(x) = ${func.derivative('x', order: 2).simplify()}');

  // Integration
  final int1 = (x.pow(2) * 3).integrate('x');
  stdout.writeln('   ∫ 3*x^2 dx = $int1');
  final defInt = x.pow(2).integrate('x', from: 0, to: 3);
  stdout.writeln('   ∫_0^3 x^2 dx = $defInt (exact: 9)');

  // Limits: sin(x) / x as x -> 0 is 1
  final sinOverX = Sin(x) / x;
  final lim = sinOverX.limit('x', 0);
  stdout.writeln('   lim_{x -> 0} sin(x) / x = $lim');

  // Taylor series of exp(x) around 0
  final expExpr = Pow(Constant.e, x);
  final expSeries = expExpr.series('x', order: 5);
  stdout.writeln(
    '   Maclaurin series of exp(x) to order 5:\n      $expSeries\n',
  );

  // 3. Multivariable Vector Calculus
  stdout.writeln('3. Multivariable Vector Calculus');
  final scalarField = x.pow(2) * y + y.pow(2) * z;
  stdout.writeln('   Scalar field: f(x, y, z) = $scalarField');
  stdout.writeln(
    '   Gradient:   ∇f = ${scalarField.gradient(['x', 'y', 'z'])}',
  );
  stdout.writeln(
    '   Hessian:    H(f) =\n${scalarField.hessian(['x', 'y', 'z'])}',
  );
  stdout.writeln(
    '   Laplacian:  Δf = ${scalarField.laplacian(['x', 'y', 'z'])}',
  );

  final vectorField = [-y, x, z];
  stdout.writeln('   Vector field: F = $vectorField');
  stdout.writeln(
    '   Divergence: ∇ · F = ${vectorField.divergence(['x', 'y', 'z'])}',
  );
  stdout.writeln(
    '   Curl:       ∇ × F = ${vectorField.curl(['x', 'y', 'z'])}\n',
  );

  // 4. Equation & System Solving
  stdout.writeln('4. Equation & System Solving');
  final quad = x.pow(2) - (x * 5) + 6;
  final roots = quad.solve('x');
  stdout.writeln('   Roots of x^2 - 5x + 6 = 0: $roots');

  // 2x2 polynomial system
  final sysEq1 = x + y - 10;
  final sysEq2 = (x * 2) - y - 2;
  final sysSol = [sysEq1, sysEq2].solve(['x', 'y']);
  stdout.writeln('   System {x + y = 10, 2x - y = 2}: $sysSol\n');

  // 5. Symbolic ODE Solving
  stdout.writeln('5. Symbolic ODE Solving');
  // First-order linear ODE: dy/dx + 2*y = 4
  final dy = Derivative(y, 'x');
  final linearOde = dy + (y * 2) - 4;
  final genSol = linearOde.solveOde(dependent: 'y', independent: 'x');
  stdout.writeln('   General solution of y\' + 2y = 4:');
  stdout.writeln('      y(x) = $genSol');

  // Initial Value Problem (IVP): y(0) = 5
  final ivpSol = linearOde.solveOde(
    dependent: 'y',
    independent: 'x',
    at: 0,
    initialValue: 5,
  );
  stdout.writeln('   Particular solution with y(0) = 5:');
  stdout.writeln('      y(x) = $ivpSol\n');

  // 6. Fast Compiled Numeric Closure
  stdout.writeln('6. Fast Compiled Numeric Closure');
  final exprToCompile = x.pow(2) + (x * 3) + 1;
  final compiledFn = exprToCompile.toFunction1D('x');
  stdout.writeln('   Compiled f(x) = x^2 + 3x + 1 to native closure:');
  for (final testVal in [0.0, 1.0, 2.0, 5.0]) {
    stdout.writeln('      f($testVal) = ${compiledFn(testVal)}');
  }
}
