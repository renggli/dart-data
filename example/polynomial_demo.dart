import 'dart:io';

import 'package:data/data.dart';

void main() {
  stdout.writeln('=== Package:Data Polynomial Algebra Demo ===\n');

  // 1. Polynomial Algebra
  stdout.writeln('1. Polynomial Algebra');
  // p(x) = (x - 2)(x + 3) = x^2 + x - 6
  final p1 = Polynomial<double>.fromCoefficients([
    -2.0,
    1.0,
  ], type: DataType.float64); // x - 2
  final p2 = Polynomial<double>.fromCoefficients([
    3.0,
    1.0,
  ], type: DataType.float64); // x + 3
  final product = p1 * p2;
  stdout.writeln('   (x - 2) * (x + 3) = $product');
  stdout.writeln('   Degree: ${product.degree}');
  stdout.writeln(
    '   Value at x = 4: ${product.evaluate(4.0)} (expected 14.0)\n',
  );

  // 2. Calculus on Polynomials
  stdout.writeln('2. Polynomial Calculus');
  final dProduct = product.differentiate();
  final iProduct = product.integrate();
  stdout.writeln('   d/dx ($product) = $dProduct');
  stdout.writeln('   ∫ ($product) dx = $iProduct\n');

  // 3. Root Finding via Companion Matrix Eigenvalues
  stdout.writeln('3. Root Finding');
  // Find roots of x^3 - 6x^2 + 11x - 6 = (x - 1)(x - 2)(x - 3)
  final cubic = Polynomial<double>.fromCoefficients([
    -6.0,
    11.0,
    -6.0,
    1.0,
  ], type: DataType.float64);
  stdout.writeln('   Cubic: $cubic');
  final roots = cubic.roots;
  stdout.writeln('   Computed roots: $roots (expected: 1.0, 2.0, 3.0)\n');

  // 4. Orthogonal Polynomials
  stdout.writeln('4. Orthogonal Polynomial Families');
  final t4 = Polynomial.chebyshevT(4);
  stdout.writeln('   Chebyshev T_4(x) = $t4');
  final leg3 = Polynomial.legendreP(3);
  stdout.writeln('   Legendre P_3(x) = $leg3');
  final herm4 = Polynomial.hermiteH(4);
  stdout.writeln('   Physicist Hermite H_4(x) = $herm4\n');

  // 5. Clenshaw Algorithm Evaluation
  stdout.writeln('5. Clenshaw Algorithm Evaluation');
  // Evaluate series c_0*T_0 + c_1*T_1 + c_2*T_2 at x = 0.5
  final clenshawVal = clenshawEvaluate(
    [1.0, 0.5, 0.25],
    0.5,
    family: OrthogonalFamily.chebyshevT,
  );
  stdout.writeln(
    '   Clenshaw evaluation of Chebyshev series at x = 0.5: $clenshawVal',
  );
}
