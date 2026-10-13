import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Symbolic Equation Solver', () {
    const x = Variable('x');
    const y = Variable('y');
    const z = Variable('z');

    test('linear equations', () {
      // 2x - 6 = 0 -> x = 3
      final eq1 = const RationalNumber(2) * x - const RationalNumber(6);
      final sol1 = eq1.solve('x');
      check(sol1.length).equals(1);
      check(sol1.first.evaluate(const {})).equals(3.0);

      // 5 - x = 0 -> x = 5
      final eq2 = const RationalNumber(5) - x;
      final sol2 = eq2.solve('x');
      check(sol2.length).equals(1);
      check(sol2.first.evaluate(const {})).equals(5.0);

      // Symbolic linear: 2x + y - 4 = 0 -> x = (4 - y) / 2
      final eq3 = const RationalNumber(2) * x + y - const RationalNumber(4);
      final sol3 = eq3.solve('x');
      check(sol3.length).equals(1);
      check(sol3.first.evaluate({'y': 2.0})).equals(1.0);
      check(sol3.first.evaluate({'y': 0.0})).equals(2.0);
    });

    test('quadratic equations', () {
      // x^2 - 5x + 6 = 0 -> x = 2, 3
      final eq1 =
          x.pow(const RationalNumber(2)) -
          const RationalNumber(5) * x +
          const RationalNumber(6);
      final sol1 = eq1.solve('x');
      check(sol1.length).equals(2);
      final vals1 = sol1.map((s) => s.evaluate(const {})).toList()..sort();
      check(vals1[0]).isCloseTo(2.0, 1e-9);
      check(vals1[1]).isCloseTo(3.0, 1e-9);

      // x^2 - 4 = 0 -> x = -2, 2
      final eq2 = x.pow(const RationalNumber(2)) - const RationalNumber(4);
      final sol2 = eq2.solve('x');
      check(sol2.length).equals(2);
      final vals2 = sol2.map((s) => s.evaluate(const {})).toList()..sort();
      check(vals2[0]).isCloseTo(-2.0, 1e-9);
      check(vals2[1]).isCloseTo(2.0, 1e-9);

      // Double root: (x - 3)^2 = x^2 - 6x + 9 = 0 -> x = 3
      final eq3 =
          x.pow(const RationalNumber(2)) -
          const RationalNumber(6) * x +
          const RationalNumber(9);
      final sol3 = eq3.solve('x');
      check(sol3.length).equals(1);
      check(sol3.first.evaluate(const {})).isCloseTo(3.0, 1e-9);

      // Complex roots for negative discriminant: x^2 + 1 = 0 -> x = i, -i
      final eq4 = x.pow(const RationalNumber(2)) + const RationalNumber(1);
      final sol4 = eq4.solve('x');
      check(sol4).deepEquals([i, -i]);

      // Complex roots with real and imaginary parts: x^2 + 2x + 2 = 0 -> x = -1 + i, -1 - i
      final eq5 =
          x.pow(const RationalNumber(2)) +
          const RationalNumber(2) * x +
          const RationalNumber(2);
      final sol5 = eq5.solve('x');
      check(sol5).deepEquals([
        const RationalNumber(-1) + i,
        const RationalNumber(-1) - i,
      ]);

      // Complex roots with fractional real and radical imaginary parts: x^2 + x + 1 = 0
      final eq6 = x.pow(const RationalNumber(2)) + x + const RationalNumber(1);
      final sol6 = eq6.solve('x');
      check(sol6.length).equals(2);
      check(sol6[0].toString()).equals('-1/2 + 1/2 * i * sqrt(3)');
      check(sol6[1].toString()).equals('-1/2 - 1/2 * i * sqrt(3)');
      check(sol6[0].toMathMl()).equals(
        '<math><mrow><mrow><mo>-</mo><mfrac><mn>1</mn><mn>2</mn></mfrac></mrow><mo>+</mo><mrow><mfrac><mn>1</mn><mn>2</mn></mfrac><mo>&#x22c5;</mo><mrow><mi>i</mi><mo>&#x22c5;</mo><msqrt><mrow><mn>3</mn></mrow></msqrt></mrow></mrow></mrow></math>',
      );
      check(sol6[1].toMathMl()).equals(
        '<math><mrow><mrow><mo>-</mo><mfrac><mn>1</mn><mn>2</mn></mfrac></mrow><mo>-</mo><mrow><mfrac><mn>1</mn><mn>2</mn></mfrac><mo>&#x22c5;</mo><mrow><mi>i</mi><mo>&#x22c5;</mo><msqrt><mrow><mn>3</mn></mrow></msqrt></mrow></mrow></mrow></math>',
      );
    });

    test('factored product equations', () {
      // (x - 1) * (x - 4) = 0 -> x = 1, 4
      final eq = (x - const RationalNumber(1)) * (x - const RationalNumber(4));
      final sol = eq.solve('x');
      check(sol.length).equals(2);
      final vals = sol.map((s) => s.evaluate(const {})).toList()..sort();
      check(vals[0]).equals(1.0);
      check(vals[1]).equals(4.0);
    });

    test('transcendental equations', () {
      // exp(2x - 4) - 1 = 0 -> 2x - 4 = 0 -> x = 2
      final eqExp =
          Exp(const RationalNumber(2) * x - const RationalNumber(4)) -
          const RationalNumber(1);
      final solExp = eqExp.solve('x');
      check(solExp.length).equals(1);
      check(solExp.first.evaluate(const {})).isCloseTo(2.0, 1e-9);

      // ln(x + 1) - 2 = 0 -> x = e^2 - 1
      final eqLn = Ln(x + const RationalNumber(1)) - const RationalNumber(2);
      final solLn = eqLn.solve('x');
      check(solLn.length).equals(1);
      check(solLn.first.evaluate(const {}))
          .isCloseTo(7.38905609893065 - 1.0, 1e-9);

      // (x - 2)^3 - 8 = 0 -> contains real root x = 4
      final eqPow =
          (x - const RationalNumber(2)).pow(const RationalNumber(3)) -
          const RationalNumber(8);
      final solPow = eqPow.solve('x');
      check(solPow).contains(const RationalNumber(4));

      // (x + 1)^2 - 9 = 0 -> x + 1 = +/- 3 -> x = 2, -4
      final eqPowEven =
          (x + const RationalNumber(1)).pow(const RationalNumber(2)) -
          const RationalNumber(9);
      final solPowEven = eqPowEven.solve('x');
      check(solPowEven.length).equals(2);
      final vals = solPowEven.map((s) => s.evaluate(const {})).toList()..sort();
      check(vals[0]).isCloseTo(-4.0, 1e-9);
      check(vals[1]).isCloseTo(2.0, 1e-9);
    });

    test('trigonometric equations', () {
      // 1. Basic zeros
      // sin(x) = 0 -> x = 0, pi
      final solSin0 = const Sin(x).solve('x');
      check(solSin0).contains(RationalNumber.zero);
      check(solSin0).contains(ConstantNumber.pi);

      // cos(x) = 0 -> x = pi/2, 3pi/2
      final solCos0 = const Cos(x).solve('x');
      check(solCos0)
          .contains(const Mul(RationalNumber(1, 2), ConstantNumber.pi));
      check(solCos0)
          .contains(const Mul(RationalNumber(3, 2), ConstantNumber.pi));

      // tan(x) = 0 -> x = 0, pi
      final solTan0 = const Tan(x).solve('x');
      check(solTan0).contains(RationalNumber.zero);
      check(solTan0).contains(ConstantNumber.pi);

      // 2. Special angle constants
      // 2 * sin(x) - 1 = 0 -> sin(x) = 1/2 -> x = pi/6, 5pi/6
      final eqSinHalf =
          const RationalNumber(2) * const Sin(x) - const RationalNumber(1);
      final solSinHalf = eqSinHalf.solve('x');
      check(solSinHalf)
          .contains(const Mul(RationalNumber(1, 6), ConstantNumber.pi));
      check(solSinHalf)
          .contains(const Mul(RationalNumber(5, 6), ConstantNumber.pi));

      // 2 * cos(x) - 1 = 0 -> cos(x) = 1/2 -> x = pi/3, 5pi/3
      final eqCosHalf =
          const RationalNumber(2) * const Cos(x) - const RationalNumber(1);
      final solCosHalf = eqCosHalf.solve('x');
      check(solCosHalf)
          .contains(const Mul(RationalNumber(1, 3), ConstantNumber.pi));
      check(solCosHalf)
          .contains(const Mul(RationalNumber(5, 3), ConstantNumber.pi));

      // tan(x) - 1 = 0 -> x = pi/4, 5pi/4
      final eqTan1 = const Tan(x) - const RationalNumber(1);
      final solTan1 = eqTan1.solve('x');
      check(solTan1)
          .contains(const Mul(RationalNumber(1, 4), ConstantNumber.pi));
      check(solTan1)
          .contains(const Mul(RationalNumber(5, 4), ConstantNumber.pi));

      // 3. Affine argument f(x)
      // sin(2x) = 0 -> x = 0, pi/2
      final eqSin2x = Sin(const RationalNumber(2) * x);
      final solSin2x = eqSin2x.solve('x');
      check(solSin2x).contains(RationalNumber.zero);
      check(solSin2x)
          .contains(const Mul(RationalNumber(1, 2), ConstantNumber.pi));

      // 4. Out of bounds (no real roots)
      // sin(x) - 2 = 0 -> []
      final eqSin2 = const Sin(x) - const RationalNumber(2);
      check(eqSin2.solve('x')).isEmpty();

      // 5. Inverse trigonometric equations
      // asin(x) = 0 -> x = 0
      check(const Asin(x).solve('x')).deepEquals([RationalNumber.zero]);

      // acos(x) - pi/2 = 0 -> x = 0
      final eqAcos =
          const Acos(x) - const Mul(RationalNumber(1, 2), ConstantNumber.pi);
      check(eqAcos.solve('x')).deepEquals([RationalNumber.zero]);

      // 6. Factored products
      // sin(x) * cos(x) = 0
      final eqProd = const Sin(x) * const Cos(x);
      final solProd = eqProd.solve('x');
      check(solProd).contains(RationalNumber.zero);
      check(solProd)
          .contains(const Mul(RationalNumber(1, 2), ConstantNumber.pi));

      // 7. General non-special angle constants (2 roots in [0, 2pi))
      // sin(x) = 1/3
      final eqSinGeneral = const Sin(x) - const RationalNumber(1, 3);
      final solSinGeneral = eqSinGeneral.solve('x');
      check(solSinGeneral.length).equals(2);
      check(solSinGeneral).contains(const Asin(RationalNumber(1, 3)));
      check(solSinGeneral)
          .contains(ConstantNumber.pi - const Asin(RationalNumber(1, 3)));

      // cos(x) = 1/3
      final eqCosGeneral = const Cos(x) - const RationalNumber(1, 3);
      final solCosGeneral = eqCosGeneral.solve('x');
      check(solCosGeneral.length).equals(2);
      check(solCosGeneral).contains(const Acos(RationalNumber(1, 3)));
      check(solCosGeneral).contains(
        const Mul(RationalNumber(2), ConstantNumber.pi) -
            const Acos(RationalNumber(1, 3)),
      );

      // tan(x) = 1/3
      final eqTanGeneral = const Tan(x) - const RationalNumber(1, 3);
      final solTanGeneral = eqTanGeneral.solve('x');
      check(solTanGeneral.length).equals(2);
      check(solTanGeneral).contains(const Atan(RationalNumber(1, 3)));
      check(solTanGeneral).contains(
        (ConstantNumber.pi + const Atan(RationalNumber(1, 3))).simplify(),
      );
    });

    test('reciprocal and rational power equations', () {
      // 1 / x = 0 -> []
      check((const RationalNumber(1) / x).solve('x')).isEmpty();

      // 1 / sin(x) = 0 -> []
      check((const RationalNumber(1) / const Sin(x)).solve('x')).isEmpty();

      // Negative rational exponents: x^(-2) - 4 = 0 -> x = +/- 1/2
      final eqPowNeg =
          x.pow(const RationalNumber(-2)) - const RationalNumber(4);
      final solPowNeg = eqPowNeg.solve('x');
      check(solPowNeg).contains(const RationalNumber(1, 2));
      check(solPowNeg).contains(const RationalNumber(-1, 2));
    });

    test('higher-degree polynomial equations', () {
      // Degree 3: distinct rational roots x^3 - 6x^2 + 11x - 6 = 0 -> x = 1, 2, 3
      final eqCubic1 =
          x.pow(const RationalNumber(3)) -
          const RationalNumber(6) * x.pow(const RationalNumber(2)) +
          const RationalNumber(11) * x -
          const RationalNumber(6);
      final solCubic1 = eqCubic1.solve('x');
      check(solCubic1.length).equals(3);
      check(solCubic1).contains(const RationalNumber(1));
      check(solCubic1).contains(const RationalNumber(2));
      check(solCubic1).contains(const RationalNumber(3));

      // Degree 3: rational root + quadratic with irrational roots: x^3 - x^2 - 2x + 2 = 0 -> x = 1, sqrt(2), -sqrt(2)
      final eqCubic2 =
          x.pow(const RationalNumber(3)) -
          x.pow(const RationalNumber(2)) -
          const RationalNumber(2) * x +
          const RationalNumber(2);
      final solCubic2 = eqCubic2.solve('x');
      check(solCubic2).contains(const RationalNumber(1));

      // Degree 3: rational root + complex quadratic: x^3 - 2x^2 + x - 2 = 0 -> x = 2, i, -i
      final eqCubic3 =
          x.pow(const RationalNumber(3)) -
          const RationalNumber(2) * x.pow(const RationalNumber(2)) +
          x -
          const RationalNumber(2);
      final solCubic3 = eqCubic3.solve('x');
      check(solCubic3).contains(const RationalNumber(2));
      check(solCubic3).contains(i);
      check(solCubic3).contains(-i);

      // Degree 3: fractional rational roots: 6x^3 - 23x^2 - 6x + 8 = 0 -> x = 4, 1/2, -2/3
      final eqCubic4 =
          const RationalNumber(6) * x.pow(const RationalNumber(3)) -
          const RationalNumber(23) * x.pow(const RationalNumber(2)) -
          const RationalNumber(6) * x +
          const RationalNumber(8);
      final solCubic4 = eqCubic4.solve('x');
      check(solCubic4).contains(const RationalNumber(4));
      check(solCubic4).contains(const RationalNumber(1, 2));
      check(solCubic4).contains(const RationalNumber(-2, 3));

      // Degree 3 binomial: x^3 - 27 = 0 -> x = 3
      final eqCubicBin1 =
          x.pow(const RationalNumber(3)) - const RationalNumber(27);
      check(eqCubicBin1.solve('x')).contains(const RationalNumber(3));

      // Degree 3 binomial with negative constant: x^3 + 8 = 0 -> contains real root x = -2 without NaN
      final eqCubicBin2 =
          x.pow(const RationalNumber(3)) + const RationalNumber(8);
      final solCubicBin2 = eqCubicBin2.solve('x');
      check(solCubicBin2).contains(const RationalNumber(-2));

      // Degree 4 biquadratic: x^4 - 5x^2 + 4 = 0 -> x = 1, -1, 2, -2
      final eqBiq1 =
          x.pow(const RationalNumber(4)) -
          const RationalNumber(5) * x.pow(const RationalNumber(2)) +
          const RationalNumber(4);
      final solBiq1 = eqBiq1.solve('x');
      check(solBiq1.length).equals(4);
      check(solBiq1).contains(const RationalNumber(1));
      check(solBiq1).contains(const RationalNumber(-1));
      check(solBiq1).contains(const RationalNumber(2));
      check(solBiq1).contains(const RationalNumber(-2));

      // Degree 4 biquadratic with 4 complex roots: x^4 + 5x^2 + 4 = 0 -> x = i, -i, 2i, -2i
      final eqBiq2 =
          x.pow(const RationalNumber(4)) +
          const RationalNumber(5) * x.pow(const RationalNumber(2)) +
          const RationalNumber(4);
      final solBiq2 = eqBiq2.solve('x');
      check(solBiq2.length).equals(4);
      check(solBiq2).contains(i);
      check(solBiq2).contains(-i);
      check(solBiq2).contains(const RationalNumber(2) * i);
      check(solBiq2).contains(const RationalNumber(-2) * i);

      // Degree 4 biquadratic: x^4 - 1 = 0 -> x = 1, -1, i, -i
      final eqBiq3 = x.pow(const RationalNumber(4)) - const RationalNumber(1);
      final solBiq3 = eqBiq3.solve('x');
      check(solBiq3.length).equals(4);
      check(solBiq3).contains(const RationalNumber(1));
      check(solBiq3).contains(const RationalNumber(-1));
      check(solBiq3).contains(i);
      check(solBiq3).contains(-i);

      // Degree 4 biquadratic: x^4 - 16 = 0 -> x = 2, -2, 2i, -2i
      final eqBiq4 = x.pow(const RationalNumber(4)) - const RationalNumber(16);
      final solBiq4 = eqBiq4.solve('x');
      check(solBiq4.length).equals(4);
      check(solBiq4).contains(const RationalNumber(2));
      check(solBiq4).contains(const RationalNumber(-2));
      check(solBiq4).contains(const RationalNumber(2) * i);
      check(solBiq4).contains(const RationalNumber(-2) * i);

      // Degree 4 irreducible biquadratic: x^4 - 4x^2 + 1 = 0
      final eqBiq5 =
          x.pow(const RationalNumber(4)) -
          const RationalNumber(4) * x.pow(const RationalNumber(2)) +
          const RationalNumber(1);
      final solBiq5 = eqBiq5.solve('x');
      check(solBiq5.length).equals(4);

      // Degree 5 quintic factoring: x^5 - 5x^3 + 4x = 0 -> x = 0, 1, -1, 2, -2
      final eqQuintic =
          x.pow(const RationalNumber(5)) -
          const RationalNumber(5) * x.pow(const RationalNumber(3)) +
          const RationalNumber(4) * x;
      final solQuintic = eqQuintic.solve('x');
      check(solQuintic.length).equals(5);
      check(solQuintic).contains(RationalNumber.zero);
      check(solQuintic).contains(const RationalNumber(1));
      check(solQuintic).contains(const RationalNumber(-1));
      check(solQuintic).contains(const RationalNumber(2));
      check(solQuintic).contains(const RationalNumber(-2));

      // Degree 5 binomial: x^5 - 32 = 0 -> x = 2
      final eqQuinticBin1 =
          x.pow(const RationalNumber(5)) - const RationalNumber(32);
      check(eqQuinticBin1.solve('x')).contains(const RationalNumber(2));

      // Degree 5 negative binomial: x^5 + 32 = 0 -> x = -2
      final eqQuinticBin2 =
          x.pow(const RationalNumber(5)) + const RationalNumber(32);
      check(eqQuinticBin2.solve('x')).contains(const RationalNumber(-2));

      // Degree 5 shifted binomial: (x - 1)^5 - 32 = 0 -> x = 3
      final eqQuinticBin3 =
          (x - const RationalNumber(1)).pow(const RationalNumber(5)) -
          const RationalNumber(32);
      check(eqQuinticBin3.solve('x')).contains(const RationalNumber(3));
    });

    test('2x2 linear system solving', () {
      // 2x + y - 5 = 0
      // x - y - 1 = 0
      // Solution: x = 2, y = 1
      final eq1 = const RationalNumber(2) * x + y - const RationalNumber(5);
      final eq2 = x - y - const RationalNumber(1);

      final sol = [eq1, eq2].solveSystem(['x', 'y']);
      check(sol).isNotNull();
      check(sol!['x']!.evaluate(const {})).isCloseTo(2.0, 1e-9);
      check(sol['y']!.evaluate(const {})).isCloseTo(1.0, 1e-9);
    });

    test('3x3 linear system solving', () {
      // x + y + z - 6 = 0
      // 2y + 5z - 19 = 0
      // 2x + 4y - 3z - 1 = 0
      // Solution: x = 1, y = 2, z = 3
      final eq1 = x + y + z - const RationalNumber(6);
      final eq2 =
          const RationalNumber(2) * y +
          const RationalNumber(5) * z -
          const RationalNumber(19);
      final eq3 =
          const RationalNumber(2) * x +
          const RationalNumber(4) * y -
          const RationalNumber(3) * z -
          const RationalNumber(1);

      final sol = [eq1, eq2, eq3].solveSystem(['x', 'y', 'z']);
      check(sol).isNotNull();
      check(sol!['x']!.evaluate(const {})).isCloseTo(1.0, 1e-9);
      check(sol['y']!.evaluate(const {})).isCloseTo(2.0, 1e-9);
      check(sol['z']!.evaluate(const {})).isCloseTo(3.0, 1e-9);
    });

    test('singular system returns null', () {
      // Parallel lines: x + y - 1 = 0 and x + y - 2 = 0
      final eq1 = x + y - const RationalNumber(1);
      final eq2 = x + y - const RationalNumber(2);

      final sol = [eq1, eq2].solveSystem(['x', 'y']);
      check(sol).isNull();
    });
  });
}
