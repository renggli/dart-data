import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:data/type.dart' show Complex;
import 'package:test/scaffolding.dart';

void main() {
  const x = Variable('x');
  const y = Variable('y');
  const z = Variable('z');

  group('ConstantNumber.i properties', () {
    test('symbolic identity and name', () {
      check(ConstantNumber.i.name).equals('i');
      check(i).equals(ConstantNumber.i);
      check(i.toString()).equals('i');
    });

    test('variable dependency and calculus properties', () {
      check(i.freeVariables).isEmpty();
      check(i.dependsOn('x')).isFalse();
      check(i.derivative('x')).equals(RationalNumber.zero);
    });

    test('type checks and value access', () {
      check(i.isReal).isFalse();
      check(i.complexValue).equals(Complex.i);
      check(i.value)
          .equals(const Pow(RationalNumber.negativeOne, RationalNumber(1, 2)));
      check(() => i.toDouble()).throws<UnsupportedError>();
    });
  });

  group('Complex wrapping and conversion', () {
    test('operator overloads wrap Complex operands', () {
      final exprAdd = x + const Complex(1, 2);
      check(exprAdd).equals(
        const Add(
          x,
          Add(RationalNumber(1), Mul(RationalNumber(2), ConstantNumber.i)),
        ),
      );

      final exprMul = x * Complex.i;
      check(exprMul).equals(const Mul(x, ConstantNumber.i));

      final exprReal = x + const Complex(5, 0);
      check(exprReal).equals(const Add(x, RationalNumber(5)));
    });
  });

  group('Exact Gaussian arithmetic & polynomial expansion', () {
    test('addition of complex and imaginary terms', () {
      final expr1 =
          (const RationalNumber(2) * i) + (const RationalNumber(3) * i);
      check(expr1.simplify()).equals(const RationalNumber(5) * i);

      final expr2 = i + (-i);
      check(expr2.simplify()).equals(RationalNumber.zero);

      final expr3 =
          (const RationalNumber(1) + (const RationalNumber(2) * i)) +
          (const RationalNumber(3) - (const RationalNumber(2) * i));
      check(expr3.simplify()).equals(const RationalNumber(4));
    });

    test('subtraction of complex and imaginary terms', () {
      final expr1 =
          (const RationalNumber(5) * i) - (const RationalNumber(2) * i);
      check(expr1.simplify()).equals(const RationalNumber(3) * i);

      final expr2 = i - i;
      check(expr2.simplify()).equals(RationalNumber.zero);
    });

    test('multiplication reductions and constant ordering', () {
      final expr1 = i * i;
      check(expr1.simplify()).equals(RationalNumber.negativeOne);

      final expr2 =
          (const RationalNumber(2) * i) * (const RationalNumber(3) * i);
      check(expr2.simplify()).equals(const RationalNumber(-6));

      final expr3 = i * (-i);
      check(expr3.simplify()).equals(RationalNumber.one);

      final expr4 = (-i) * i;
      check(expr4.simplify()).equals(RationalNumber.one);

      final expr5 = (-i) * (-i);
      check(expr5.simplify()).equals(RationalNumber.negativeOne);

      final expr6 = i * const RationalNumber(3);
      check(expr6.simplify()).equals(const RationalNumber(3) * i);
    });

    test('division by imaginary unit', () {
      check((RationalNumber.one / i).simplify()).equals(-i);
      check((RationalNumber.negativeOne / i).simplify()).equals(i);
      check((RationalNumber.one / (-i)).simplify()).equals(i);
      check((RationalNumber.negativeOne / (-i)).simplify()).equals(-i);
      check((i / i).simplify()).equals(RationalNumber.one);
      check(((-i) / i).simplify()).equals(RationalNumber.negativeOne);
      check((i / (-i)).simplify()).equals(RationalNumber.negativeOne);
      check(((-i) / (-i)).simplify()).equals(RationalNumber.one);
      check((const RationalNumber(2) / i).simplify())
          .equals(const RationalNumber(-2) * i);
      check((x / i).simplify()).equals(-(x * i));
      check((x / (-i)).simplify()).equals(x * i);
      check(() => (i / RationalNumber.zero).simplify())
          .throws<UnsupportedError>();
    });

    test('Gaussian integer product expansion and conjugate product', () {
      final expr = (RationalNumber.one + i) * (RationalNumber.one - i);
      check(expr.expand().simplify()).equals(const RationalNumber(2));

      final z1 = const RationalNumber(2) + const RationalNumber(3) * i;
      final z2 = const RationalNumber(4) + const RationalNumber(5) * i;
      // (2 + 3i)(4 + 5i) = (8 - 15) + (10 + 12)i = -7 + 22i
      final prod = (z1 * z2).expand().simplify();
      check(prod)
          .equals(const RationalNumber(-7) + const RationalNumber(22) * i);

      // (3 + 4i)(3 - 4i) = 25
      final z3 = const RationalNumber(3) + const RationalNumber(4) * i;
      final z4 = const RationalNumber(3) - const RationalNumber(4) * i;
      check((z3 * z4).expand().simplify()).equals(const RationalNumber(25));

      // Symbolic conjugate: (x + i*y)(x - i*y) = x^2 + y^2
      check(((x + i * y) * (x - i * y)).expand().simplify())
          .equals(x.pow(2) + y.pow(2));
    });

    test('associativity and distributivity', () {
      final z1 = const RationalNumber(1) + const RationalNumber(2) * i;
      final z2 = const RationalNumber(3) + const RationalNumber(4) * i;
      final z3 = const RationalNumber(5) + const RationalNumber(6) * i;

      final sum1 = ((z1 + z2) + z3).simplify();
      final sum2 = (z1 + (z2 + z3)).simplify();
      check(sum1).equals(sum2);
      check(sum1)
          .equals(const RationalNumber(9) + const RationalNumber(12) * i);

      final dist = i * (x + y);
      check(dist.expand().simplify()).equals(x * i + y * i);
    });

    test('canonical reconstruction: a + b * i', () {
      final c1 =
          (const RationalNumber(2) + const RationalNumber(3) * i) +
          (const RationalNumber(4) + const RationalNumber(5) * i);
      check(c1.simplify())
          .equals(const RationalNumber(6) + const RationalNumber(8) * i);

      final c2 =
          (const RationalNumber(2) + const RationalNumber(3) * i) -
          (const RationalNumber(4) + const RationalNumber(5) * i);
      check(c2.simplify())
          .equals(const RationalNumber(-2) - const RationalNumber(2) * i);

      // Fraction simplification: -1/2 + 2/4*i -> -1/2 + 1/2*i
      final cFrac =
          const RationalNumber(-1, 2) + (const RationalNumber(2, 4) * i);
      check(
        cFrac.simplify(),
      ).equals(const RationalNumber(-1, 2) + (const RationalNumber(1, 2) * i));

      // Radical ordering
      const sqrt3 = Pow(RationalNumber(3), RationalNumber(1, 2));
      final cRadical1 =
          (const RationalNumber(1, 2) * i * sqrt3) - const RationalNumber(1, 2);
      check(cRadical1.simplify()).equals(
        const RationalNumber(-1, 2) +
            (const RationalNumber(1, 2) * (sqrt3 * i)),
      );

      final cRadical2 =
          (-const RationalNumber(1, 2) * i * sqrt3) -
          const RationalNumber(1, 2);
      check(cRadical2.simplify()).equals(
        const RationalNumber(-1, 2) -
            (const RationalNumber(1, 2) * (sqrt3 * i)),
      );

      // Deterministic 4-tier ordering: variables < rationals < transcendentals < i
      final mixed1 = ConstantNumber.pi + const RationalNumber(1);
      check(mixed1.simplify())
          .equals(const RationalNumber(1) + ConstantNumber.pi);

      final mixed2 =
          i +
          ConstantNumber.pi +
          ConstantNumber.e +
          const RationalNumber(1) +
          x;
      check(mixed2.simplify()).equals(
        x + const RationalNumber(1) + ConstantNumber.e + ConstantNumber.pi + i,
      );
    });
  });

  group('Cyclic power simplification & modulo arithmetic', () {
    test('positive integer exponents modulo 4', () {
      check(i.pow(0).simplify()).equals(RationalNumber.one);
      check(i.pow(1).simplify()).equals(i);
      check(i.pow(2).simplify()).equals(RationalNumber.negativeOne);
      check(i.pow(3).simplify()).equals(-i);
      check(i.pow(4).simplify()).equals(RationalNumber.one);
      check(i.pow(5).simplify()).equals(i);
      check(i.pow(6).simplify()).equals(RationalNumber.negativeOne);
      check(i.pow(7).simplify()).equals(-i);
      check(i.pow(8).simplify()).equals(RationalNumber.one);
      check(i.pow(17).simplify()).equals(i);
      check(i.pow(42).simplify()).equals(RationalNumber.negativeOne);
      check(i.pow(99).simplify()).equals(-i);
      check(i.pow(100).simplify()).equals(RationalNumber.one);

      for (var k = 0; k < 20; k++) {
        final expected = switch (k % 4) {
          0 => RationalNumber.one,
          1 => ConstantNumber.i,
          2 => RationalNumber.negativeOne,
          3 => const Neg(ConstantNumber.i),
          _ => throw StateError('Unreachable'),
        };
        check(i.pow(k).simplify()).equals(expected);
      }
    });

    test('large positive and negative powers of i', () {
      check(i.pow(1000000).simplify()).equals(RationalNumber.one);
      check(i.pow(1000001).simplify()).equals(i);
      check(i.pow(1000002).simplify()).equals(RationalNumber.negativeOne);
      check(i.pow(1000003).simplify()).equals(-i);
      check(i.pow(1000000007).simplify()).equals(-i);

      check(i.pow(-1).simplify()).equals(-i);
      check(i.pow(-2).simplify()).equals(RationalNumber.negativeOne);
      check(i.pow(-3).simplify()).equals(i);
      check(i.pow(-4).simplify()).equals(RationalNumber.one);
      check(i.pow(-5).simplify()).equals(-i);
      check(i.pow(-100).simplify()).equals(RationalNumber.one);
      check(i.pow(-1000000).simplify()).equals(RationalNumber.one);
      check(i.pow(-1000000007).simplify()).equals(i);
    });

    test('powers of -i modulo 4', () {
      check((-i).pow(0).simplify()).equals(RationalNumber.one);
      check((-i).pow(1).simplify()).equals(-i);
      check((-i).pow(2).simplify()).equals(RationalNumber.negativeOne);
      check((-i).pow(3).simplify()).equals(i);
      check((-i).pow(4).simplify()).equals(RationalNumber.one);
      check((-i).pow(5).simplify()).equals(-i);
      check((-i).pow(6).simplify()).equals(RationalNumber.negativeOne);
      check((-i).pow(7).simplify()).equals(i);
      check((-i).pow(8).simplify()).equals(RationalNumber.one);

      check((-i).pow(-1).simplify()).equals(i);
      check((-i).pow(-2).simplify()).equals(RationalNumber.negativeOne);
      check((-i).pow(-3).simplify()).equals(-i);
      check((-i).pow(-4).simplify()).equals(RationalNumber.one);
      check((-i).pow(-1000000).simplify()).equals(RationalNumber.one);
    });

    test('real number exponent powers of i and -i', () {
      check(i.pow(const RealNumber(0.0)).simplify()).equals(RationalNumber.one);
      check(i.pow(const RealNumber(1.0)).simplify()).equals(i);
      check(i.pow(const RealNumber(2.0)).simplify())
          .equals(RationalNumber.negativeOne);
      check(i.pow(const RealNumber(3.0)).simplify()).equals(-i);
      check(i.pow(const RealNumber(4.0)).simplify()).equals(RationalNumber.one);
      check(i.pow(const RealNumber(-1.0)).simplify()).equals(-i);
      check(i.pow(const RealNumber(-2.0)).simplify())
          .equals(RationalNumber.negativeOne);

      check((-i).pow(const RealNumber(1.0)).simplify()).equals(-i);
      check((-i).pow(const RealNumber(2.0)).simplify())
          .equals(RationalNumber.negativeOne);
      check((-i).pow(const RealNumber(3.0)).simplify()).equals(i);
      check((-i).pow(const RealNumber(4.0)).simplify())
          .equals(RationalNumber.one);
    });

    test('powers of scaled imaginary terms', () {
      final expr = (const RationalNumber(2) * i).pow(2);
      check(expr.simplify()).equals(const RationalNumber(-4));

      check((const RationalNumber(3) * i).pow(3).simplify())
          .equals(const RationalNumber(-27) * i);
      check((const RationalNumber(3) * i).pow(4).simplify())
          .equals(const RationalNumber(81));
    });

    test('fractional powers evaluation of i and negative numbers', () {
      // i^(1/2) = e^(i * pi / 4)
      final sqrtI = i.pow(const RationalNumber(1, 2));
      final valSqrtI = sqrtI.evaluateComplex();
      final expectedSqrt2Over2 = math.sqrt(2) / 2;
      check((valSqrtI.a - expectedSqrt2Over2).abs()).isLessThan(1e-12);
      check((valSqrtI.b - expectedSqrt2Over2).abs()).isLessThan(1e-12);

      // (-1)^(1/2) = i
      final sqrtNegOne = RationalNumber.negativeOne.pow(
        const RationalNumber(1, 2),
      );
      check((sqrtNegOne.evaluateComplex() - Complex.i).abs()).isLessThan(1e-12);

      // (-8)^(1/3) = 1 + i * sqrt(3)
      final cubeRootNegEight = const RationalNumber(-8)
          .pow(const RationalNumber(1, 3));
      final valCube = cubeRootNegEight.evaluateComplex();
      check((valCube.a - 1.0).abs()).isLessThan(1e-12);
      check((valCube.b - math.sqrt(3)).abs()).isLessThan(1e-12);
    });
  });

  group('Complex evaluation with evaluateComplex', () {
    test('evaluates real expressions into Complex domain', () {
      final expr = const RationalNumber(3) + const RationalNumber(4);
      check(expr.evaluateComplex()).equals(const Complex(7.0, 0.0));
    });

    test('evaluates i and complex expressions directly', () {
      check(i.evaluateComplex()).equals(Complex.i);
      check(
        (const RationalNumber(2) + const RationalNumber(3) * i)
            .evaluateComplex(),
      ).equals(const Complex(2, 3));
    });

    test('evaluates expressions with variables bound to Complex values', () {
      final expr = x * x + 1;
      check(expr.evaluateComplex({'x': Complex.i})).equals(Complex.zero);

      final val = expr.evaluateComplex({'x': const Complex(1.0, 2.0)});
      check(val).equals(const Complex(-2.0, 4.0));
    });

    test('evaluates zero base complex powers', () {
      check(x.pow(2).evaluateComplex({'x': Complex.zero})).equals(Complex.zero);
      check(x.pow(0).evaluateComplex({'x': Complex.zero})).equals(Complex.one);
      check((x.pow(2) + 1).evaluateComplex({'x': Complex.zero}))
          .equals(Complex.one);
      check((x * x + 1).toComplexFunction1D('x')(Complex.zero))
          .equals(Complex.one);
      check((x * x).compileComplex()({'x': Complex.zero})).equals(Complex.zero);

      // 0^x for various x
      final zeroPowX = const RationalNumber(0).pow(x);
      check(zeroPowX.evaluateComplex({'x': Complex.zero})).equals(Complex.one);
      check(zeroPowX.evaluateComplex({'x': Complex.one})).equals(Complex.zero);
      check(zeroPowX.evaluateComplex({'x': const Complex(2, 0)}))
          .equals(Complex.zero);
      check(zeroPowX.evaluateComplex({'x': const Complex(0.5, 0)}))
          .equals(Complex.zero);
      check(zeroPowX.evaluateComplex({'x': const Complex(1, 2)}))
          .equals(Complex.zero);
      check(zeroPowX.evaluateComplex({'x': const Complex(-1, 0)}))
          .equals(const Complex(double.infinity, 0.0));
      check(zeroPowX.evaluateComplex({'x': Complex.i}).isNaN).isTrue();
    });

    test("verifies Euler's identity: exp(i * pi) + 1 = 0", () {
      final euler = Exp(i * ConstantNumber.pi) + RationalNumber.one;
      final result = euler.evaluateComplex();
      check(result.abs()).isLessThan(1e-12);

      final expHalfPi = Exp(i * (ConstantNumber.pi / const RationalNumber(2)));
      final valHalfPi = expHalfPi.evaluateComplex();
      check(valHalfPi.a.abs()).isLessThan(1e-12);
      check((valHalfPi.b - 1.0).abs()).isLessThan(1e-12);

      final exp2Pi = Exp(i * (const RationalNumber(2) * ConstantNumber.pi));
      final val2Pi = exp2Pi.evaluateComplex();
      check((val2Pi.a - 1.0).abs()).isLessThan(1e-12);
      check(val2Pi.b.abs()).isLessThan(1e-12);
    });

    test('evaluates complex trigonometric and hyperbolic relationships', () {
      final cosIx = Cos(i * RationalNumber.one).evaluateComplex();
      final cosh1 = const Cosh(RationalNumber.one).evaluateComplex();
      check((cosIx - cosh1).abs()).isLessThan(1e-12);

      final sinIx = Sin(i * RationalNumber.one).evaluateComplex();
      check((sinIx - Complex.i.sin()).abs()).isLessThan(1e-12);

      final tanVal = const Tan(i).evaluateComplex();
      final expectedTanh = (math.exp(2.0) - 1.0) / (math.exp(2.0) + 1.0);
      check((tanVal.b - expectedTanh).abs()).isLessThan(1e-12);

      final sinhVal = const Sinh(i).evaluateComplex();
      check((sinhVal.b - math.sin(1.0)).abs()).isLessThan(1e-12);

      final coshVal = const Cosh(i).evaluateComplex();
      check((coshVal.a - math.cos(1.0)).abs()).isLessThan(1e-12);

      final tanhVal = const Tanh(i).evaluateComplex();
      check((tanhVal.b - math.tan(1.0)).abs()).isLessThan(1e-12);
    });

    test('evaluates inverse trigonometric and hyperbolic functions', () {
      final asinVal = const Asin(RationalNumber.zero).evaluateComplex();
      check(asinVal.abs()).isLessThan(1e-12);

      final acosVal = const Acos(RationalNumber.zero).evaluateComplex();
      check((acosVal.a - math.pi / 2).abs()).isLessThan(1e-12);

      final atanVal = const Atan(RationalNumber.one).evaluateComplex();
      check((atanVal.a - math.pi / 4).abs()).isLessThan(1e-12);
    });

    test('evaluates square root and logarithm of negative numbers', () {
      final sqrtNegFour = const RationalNumber(-4)
          .pow(const RationalNumber(1, 2));
      check((sqrtNegFour.evaluateComplex() - const Complex(0.0, 2.0)).abs())
          .isLessThan(1e-12);

      final lnNegOne = const Ln(RationalNumber.negativeOne).evaluateComplex();
      check((lnNegOne - const Complex(0.0, math.pi)).abs()).isLessThan(1e-12);

      final lnI = const Ln(i).evaluateComplex();
      check(lnI.a.abs()).isLessThan(1e-12);
      check((lnI.b - math.pi / 2).abs()).isLessThan(1e-12);

      final logVal = const Div(
        Ln(RationalNumber(100)),
        Ln(RationalNumber(10)),
      ).evaluateComplex();
      check((logVal.a - 2.0).abs()).isLessThan(1e-12);
    });

    test('evaluates absolute value of complex numbers', () {
      final absVal = Abs(const RationalNumber(3) + const RationalNumber(4) * i)
          .evaluateComplex();
      check(absVal).equals(const Complex(5.0, 0.0));
    });
  });

  group('High-speed numerical JIT compilation & oracle parity', () {
    final testPoints = <Complex>[
      Complex.zero,
      Complex.one,
      -Complex.one,
      Complex.i,
      -Complex.i,
      const Complex(1.0, 1.0),
      const Complex(1.0, -1.0),
      const Complex(-1.0, 1.0),
      const Complex(-1.0, -1.0),
      const Complex(0.5, 2.5),
      const Complex(3.0, -4.0),
      const Complex(-0.125, 0.75),
    ];

    void verifyOracleParity1D(Expr expr, {double tol = 1e-10}) {
      final compiled1D = expr.toComplexFunction1D('x');
      final compiledMap = expr.compileComplex();

      for (final pt in testPoints) {
        final evalRes = expr.evaluateComplex({'x': pt});
        final fast1DRes = compiled1D(pt);
        final mapRes = compiledMap({'x': pt});

        if (evalRes.isNaN || fast1DRes.isNaN || mapRes.isNaN) {
          continue;
        }
        if (evalRes.isInfinite || fast1DRes.isInfinite || mapRes.isInfinite) {
          continue;
        }

        check((evalRes - fast1DRes).abs()).isLessThan(tol);
        check((evalRes - mapRes).abs()).isLessThan(tol);
      }
    }

    test('compiles univariate expressions to Complex closures', () {
      final fn = (x * x + 1).toComplexFunction1D('x');
      check(fn(Complex.i).abs()).isLessThan(1e-12);
      check((fn(const Complex(1.0, 2.0)) - const Complex(-2.0, 4.0)).abs())
          .isLessThan(1e-12);

      final fnTrans = Exp(i * x).toComplexFunction1D('x');
      final valPi = fnTrans(const Complex(math.pi));
      check((valPi - const Complex(-1.0, 0.0)).abs()).isLessThan(1e-12);

      final fnFrac = ((x + 1) / (x - 1)).toComplexFunction1D('x');
      final valI = fnFrac(Complex.i);
      check((valI - const Complex(0.0, -1.0)).abs()).isLessThan(1e-12);
    });

    test(
      'oracle parity across polynomial, rational, and transcendental suites',
      () {
        verifyOracleParity1D(
          x * x * x -
              const RationalNumber(2) * x.pow(2) +
              const RationalNumber(4) * x -
              const RationalNumber(7),
        );
        verifyOracleParity1D(x.pow(4) + const RationalNumber(1));
        verifyOracleParity1D((x + i) * (x - i));
        verifyOracleParity1D(x.pow(2) + i * x + const RationalNumber(1));
        verifyOracleParity1D(
          (x + const RationalNumber(1)) / (x - const RationalNumber(2)),
        );
        verifyOracleParity1D(Exp(i * x));
        verifyOracleParity1D(const Sin(x) + const Cos(x));
        verifyOracleParity1D(const Sinh(x) + const Cosh(x));
        verifyOracleParity1D(const Atan(x));
        verifyOracleParity1D(const Abs(x));
      },
    );

    test('multi-variable compileComplex parity', () {
      final expr = x * x + y * y + z * i;
      final compiled = expr.compileComplex();

      final nonZeroPoints = testPoints.where((p) => p != Complex.zero).take(4);
      for (final px in nonZeroPoints) {
        for (final py in nonZeroPoints) {
          final ctx = {'x': px, 'y': py, 'z': Complex.i};
          final directVal = expr.evaluateComplex(ctx);
          final compiledVal = compiled(ctx);
          check((directVal - compiledVal).abs()).isLessThan(1e-12);
        }
      }
    });
  });

  group('Higher-degree complex polynomials & multi-factor expansion', () {
    test('expanding and simplifying products of complex linear factors', () {
      // (x + i) * (x - i) * (x + 2*i) * (x - 2*i) = (x^2 + 1)(x^2 + 4) = x^4 + 5*x^2 + 4
      final p1 =
          ((x + i) * (x - i)) *
          ((x + const RationalNumber(2) * i) *
              (x - const RationalNumber(2) * i));
      final expanded1 = p1.expand().simplify();
      check(expanded1).equals(
        x.pow(4) +
            (const RationalNumber(5) * x.pow(2)) +
            const RationalNumber(4),
      );

      // (x - (1 + i)) * (x - (1 - i)) * (x - 2*i) * (x + 2*i) = x^4 - 2*x^3 + 6*x^2 - 8*x + 8
      final p2 =
          ((x - RationalNumber.one - i) * (x - RationalNumber.one + i)) *
          ((x - const RationalNumber(2) * i) *
              (x + const RationalNumber(2) * i));
      final expanded2 = p2.expand().simplify();
      check(expanded2).equals(
        x.pow(4) -
            (const RationalNumber(2) * x.pow(3)) +
            (const RationalNumber(6) * x.pow(2)) -
            (const RationalNumber(8) * x) +
            const RationalNumber(8),
      );
    });

    test('expanding higher-degree powers of complex binomials', () {
      // (x + i)^3 = x^3 + 3*x^2*i - 3*x - i
      final pCube = (x + i).pow(3);
      check(pCube.expand().simplify()).equals(
        x.pow(3) +
            (const RationalNumber(3) * (x.pow(2) * i)) -
            (const RationalNumber(3) * x) -
            i,
      );

      // (x - i)^4 = x^4 - 4*x^3*i - 6*x^2 + 4*x*i + 1
      final pQuad = (x - i).pow(4);
      check(pQuad.expand().simplify()).equals(
        x.pow(4) -
            (const RationalNumber(4) * (x.pow(3) * i)) -
            (const RationalNumber(6) * x.pow(2)) +
            (const RationalNumber(4) * (x * i)) +
            RationalNumber.one,
      );

      // (x - i)^5 = x^5 - 5*x^4*i - 10*x^3 + 10*x^2*i + 5*x - i
      final pPower5 = (x - i).pow(5);
      final expanded5 = pPower5.expand().simplify();
      check(expanded5).equals(
        x.pow(5) -
            (const RationalNumber(5) * (x.pow(4) * i)) -
            (const RationalNumber(10) * x.pow(3)) +
            (const RationalNumber(10) * (x.pow(2) * i)) +
            (const RationalNumber(5) * x) -
            i,
      );
    });

    test(
      'evaluations of degree 4 and 6 complex polynomials at roots and origin',
      () {
        final p =
            ((x - RationalNumber.one - i) * (x - RationalNumber.one + i)) *
            ((x - const RationalNumber(2) * i) *
                (x + const RationalNumber(2) * i));
        check(p.evaluateComplex({'x': Complex.zero}))
            .equals(const Complex(8, 0));
        check(p.evaluateComplex({'x': const Complex(1, 1)}).abs())
            .isLessThan(1e-10);
        check(p.evaluateComplex({'x': const Complex(1, -1)}).abs())
            .isLessThan(1e-10);
        check(p.evaluateComplex({'x': const Complex(0, 2)}).abs())
            .isLessThan(1e-10);
        check(p.evaluateComplex({'x': const Complex(0, -2)}).abs())
            .isLessThan(1e-10);

        // Q(x) = (x^2 + 1) * (x^2 + 4) * (x^2 + 9)
        final q =
            (x.pow(2) + RationalNumber.one) *
            (x.pow(2) + const RationalNumber(4)) *
            (x.pow(2) + const RationalNumber(9));
        check(q.evaluateComplex({'x': Complex.zero}))
            .equals(const Complex(36, 0));
        check(q.evaluateComplex({'x': const Complex(0, 1)}).abs())
            .isLessThan(1e-10);
        check(q.evaluateComplex({'x': const Complex(0, 2)}).abs())
            .isLessThan(1e-10);
        check(q.evaluateComplex({'x': const Complex(0, 3)}).abs())
            .isLessThan(1e-10);
        check(q.evaluateComplex({'x': const Complex(1, 0)}))
            .equals(const Complex(100, 0));
      },
    );
  });

  group('Calculus with complex constants', () {
    test('derivatives of complex linear and polynomial expressions', () {
      check((x * i).derivative('x').simplify()).equals(i);
      check((x.pow(2) * i).derivative('x').simplify())
          .equals(Mul(const RationalNumber(2), x * i));
      check((x + i).derivative('x').simplify()).equals(RationalNumber.one);
      check(
        (x + const RationalNumber(3) + const RationalNumber(4) * i)
            .derivative('x')
            .simplify(),
      ).equals(RationalNumber.one);
    });

    test('derivative of complex exponential', () {
      final deriv = Exp(i * x).derivative('x').simplify();
      check(deriv).equals(Exp(x * i) * i);
    });

    test('anti-derivative of complex expressions w.r.t real variable', () {
      check(i.integrate('x').simplify()).equals(x * i);

      final anti = (x * i).integrate('x').simplify();
      check(anti.derivative('x').simplify()).equals(x * i);
    });

    test('differentiation commutes with expansion on complex polynomials', () {
      final p = (x + i).pow(4);
      final d1 = p.derivative('x').expand().simplify();
      final d2 = p.expand().simplify().derivative('x').simplify();
      check(d1).equals(d2);
      check(d1).equals(
        (const RationalNumber(4) * x.pow(3)) +
            (const RationalNumber(12) * (x.pow(2) * i)) -
            (const RationalNumber(12) * x) -
            (const RationalNumber(4) * i),
      );
    });
  });

  group('Structural order stability & total ordering invariants', () {
    final testNodes = <Expr>[
      RationalNumber.zero,
      RationalNumber.one,
      RationalNumber.negativeOne,
      const RationalNumber(1, 2),
      const RealNumber(0.5),
      ConstantNumber.e,
      ConstantNumber.pi,
      ConstantNumber.i,
      const RationalNumber(1) + const RationalNumber(2) * i,
      const RationalNumber(2) - i,
      x,
      y,
      -x,
      -i,
      x + 1,
      x + i,
      x * i,
      i * x,
      x.pow(2),
      const Pow(i, RationalNumber(2)),
      const Sin(x),
      const Cos(i),
      Exp(i * ConstantNumber.pi),
      const Ln(x),
    ];

    test(
      'structural order satisfies reflexivity, antisymmetry, and transitivity',
      () {
        for (final node in testNodes) {
          check(compareStructural(node, node)).equals(0);
        }

        for (var j = 0; j < testNodes.length; j++) {
          for (var k = 0; k < testNodes.length; k++) {
            final cmpJK = compareStructural(testNodes[j], testNodes[k]);
            final cmpKJ = compareStructural(testNodes[k], testNodes[j]);
            if (cmpJK == 0) {
              check(cmpKJ).equals(0);
            } else if (cmpJK < 0) {
              check(cmpKJ).isGreaterThan(0);
            } else {
              check(cmpKJ).isLessThan(0);
            }
          }
        }

        for (var a = 0; a < testNodes.length; a++) {
          for (var b = 0; b < testNodes.length; b++) {
            final cmpAB = compareStructural(testNodes[a], testNodes[b]);
            if (cmpAB <= 0) {
              for (var c = 0; c < testNodes.length; c++) {
                final cmpBC = compareStructural(testNodes[b], testNodes[c]);
                if (cmpBC <= 0) {
                  final cmpAC = compareStructural(testNodes[a], testNodes[c]);
                  check(cmpAC).isLessOrEqual(0);
                }
              }
            }
          }
        }
      },
    );

    test('sorting expressions is stable and deterministic', () {
      final list1 = List<Expr>.from(testNodes)..shuffle(math.Random(42));
      final list2 = List<Expr>.from(testNodes)..shuffle(math.Random(99));
      list1.sort(compareStructural);
      list2.sort(compareStructural);
      check(list1).deepEquals(list2);
    });

    test('compares complex expressions and powers with i', () {
      final c1 = const RationalNumber(1) + const RationalNumber(2) * i;
      final c2 = const RationalNumber(1) + const RationalNumber(2) * i;
      final c3 = const RationalNumber(1) + const RationalNumber(3) * i;
      final c4 = const RationalNumber(2) + const RationalNumber(1) * i;

      check(compareStructural(c1, c2)).equals(0);
      check(compareStructural(c1, c3)).isLessThan(0);
      check(compareStructural(c3, c1)).isGreaterThan(0);
      check(compareStructural(c1, c4)).isLessThan(0);

      check(compareStructural(x.pow(i), x.pow(2)) != 0).isTrue();
    });
  });

  group('Textualization: String, LaTeX, MathML & parenthesization', () {
    test('String formatting for complex expressions and parenthesization', () {
      check(formatExpr(i)).equals('i');
      check(formatExpr(-i)).equals('-i');
      check(formatExpr(const RationalNumber(2) * i)).equals('2 * i');
      check(formatExpr(const RationalNumber(-3) * i)).equals('-3 * i');
      check(formatExpr(const RationalNumber(2) + const RationalNumber(3) * i))
          .equals('2 + 3 * i');
      check(formatExpr(const RationalNumber(3) - const RationalNumber(4) * i))
          .equals('3 - 4 * i');

      final c = const RationalNumber(3) + const RationalNumber(4) * i;
      check(formatExpr(c * x)).equals('(3 + 4 * i) * x');
      check(formatExpr(x / c)).equals('x / (3 + 4 * i)');
      check(formatExpr(c.pow(2))).equals('(3 + 4 * i) ^ 2');
    });

    test('LaTeX serialization and parenthesization', () {
      check(i.toLatex()).equals('i');
      check((-i).toLatex()).equals('-i');
      check((const RationalNumber(2) * i).toLatex()).equals(r'2 \cdot i');
      check((const RationalNumber(3) - const RationalNumber(4) * i).toLatex())
          .equals(r'3 - 4 \cdot i');

      final c2I = const RationalNumber(2) * i;
      final cNegI = -i;
      check(c2I.pow(2).toLatex()).equals(r'{(2 \cdot i)}^{2}');
      check(cNegI.pow(2).toLatex()).equals(r'{(-i)}^{2}');
      check((x * cNegI).toLatex()).equals(r'x \cdot (-i)');
      check((x - cNegI).toLatex()).equals(r'x - (-i)');
      check((-cNegI).toLatex()).equals(r'-(-i)');
    });

    test('MathML serialization and parenthesization', () {
      check(i.toMathMl()).equals('<math><mi>i</mi></math>');
      check((-i).toMathMl())
          .equals('<math><mrow><mo>-</mo><mi>i</mi></mrow></math>');
      check((const RationalNumber(3) + const RationalNumber(4) * i).toMathMl())
          .equals(
            '<math><mrow><mn>3</mn><mo>+</mo><mrow><mn>4</mn><mo>&#x22c5;</mo><mi>i</mi></mrow></mrow></math>',
          );

      final c2I = const RationalNumber(2) * i;
      final cNegI = -i;
      check(c2I.pow(2).toMathMl()).equals(
        '<math><msup><mrow><mo>(</mo><mrow><mn>2</mn><mo>&#x22c5;</mo><mi>i</mi></mrow><mo>)</mo></mrow><mn>2</mn></msup></math>',
      );
      check((x * cNegI).toMathMl()).equals(
        '<math><mrow><mi>x</mi><mo>&#x22c5;</mo><mrow><mo>(</mo><mrow><mo>-</mo><mi>i</mi></mrow><mo>)</mo></mrow></mrow></math>',
      );
      check((-cNegI).toMathMl()).equals(
        '<math><mrow><mo>-</mo><mrow><mo>(</mo><mrow><mo>-</mo><mi>i</mi></mrow><mo>)</mo></mrow></mrow></math>',
      );
    });
  });

  group('Parser recognition, round-trips & identifier distinction', () {
    test('parses i and Gaussian expressions', () {
      check(Expr.parse('i')).equals(ConstantNumber.i);
      check(Expr.parse('I')).equals(ConstantNumber.i);
      check(Expr.parse('2 + 3 * i')).equals(
        const Add(RationalNumber(2), Mul(RationalNumber(3), ConstantNumber.i)),
      );
      check(Expr.parse('1/2 + 3/4 * i')).equals(
        const Add(
          Div(RationalNumber(1), RationalNumber(2)),
          Mul(Div(RationalNumber(3), RationalNumber(4)), ConstantNumber.i),
        ),
      );
      check(Expr.parse('i ^ 2'))
          .equals(const Pow(ConstantNumber.i, RationalNumber(2)));
      check(Expr.parse('exp(i * pi)'))
          .equals(const Exp(Mul(ConstantNumber.i, ConstantNumber.pi)));
      check(Expr.parse('-i')).equals(const Neg(ConstantNumber.i));
    });

    test('distinguishes i from multi-letter identifier prefixes', () {
      check(Expr.parse('item')).equals(const Variable('item'));
      check(Expr.parse('i1')).equals(const Variable('i1'));
      check(Expr.parse('imag')).equals(const Variable('imag'));
      check(Expr.parse('identity')).equals(const Variable('identity'));
    });

    test('round-trip parsing and evaluation', () {
      final parsed = Expr.parse('2 + 3 * i');
      check(parsed.evaluateComplex()).equals(const Complex(2.0, 3.0));

      final euler = Expr.parse('exp(i * pi) + 1');
      check(euler.evaluateComplex().abs()).isLessThan(1e-12);
    });
  });

  group('Error handling & boundary robustness', () {
    test(
      'real evaluators and compilers safely reject imaginary expressions',
      () {
        final exprI = x + i;
        check(() => exprI.evaluate({'x': 1.0})).throws<UnsupportedError>();
        check(() => exprI.toFunction1D('x')).throws<UnsupportedError>();
        check(() => exprI.compile(['x'])).throws<UnsupportedError>();
        check(() => exprI.toVectorFunction(['x'])).throws<UnsupportedError>();
        check(() => exprI.compileTensorKernel(['x']))
            .throws<UnsupportedError>();
      },
    );

    test('missing variable in evaluateComplex and compileComplex throws ArgumentError', () {
      check(() => x.evaluateComplex()).throws<ArgumentError>();
      check(() => (x + y).evaluateComplex({'x': Complex.one}))
          .throws<ArgumentError>();

      final compiled = (x + y).compileComplex();
      check(() => compiled({'x': Complex.one})).throws<ArgumentError>();
      check(() => compiled({})).throws<ArgumentError>();
    });
  });

  group('Adversarial stress-test: Complex operations, powers, evaluation and functions', () {
    test('ConstantNumber.i properties and Liskov substitution invariants', () {
      // ConstantNumber.i identity and interface contracts
      const expectedI = ConstantNumber(
        'i',
        Pow(RationalNumber.negativeOne, RationalNumber(1, 2)),
      );
      check(ConstantNumber.i).equals(expectedI);
      check(ConstantNumber.i.hashCode).equals(expectedI.hashCode);
      check(ConstantNumber.i.value)
          .equals(const Pow(RationalNumber.negativeOne, RationalNumber(1, 2)));
      check(ConstantNumber.i.isReal).isFalse();
      check(() => ConstantNumber.i.toDouble()).throws<UnsupportedError>();
      check(ConstantNumber.i.complexValue).equals(const Complex(0, 1));
      check(ConstantNumber.i.name).equals('i');

      // Number polymorphism: non-real Number throws on toDouble, real Number succeeds
      const Number numReal = RationalNumber(-15, 2);
      check(numReal.toDouble()).equals(-7.5);
      const Number numImag = ConstantNumber.i;
      check(() => numImag.toDouble()).throws<UnsupportedError>();
    });

    test('cyclic integer powers of imaginary unit i across positive and negative bounds', () {
      final powers = {
        -8: RationalNumber.one,
        -7: ConstantNumber.i,
        -6: RationalNumber.negativeOne,
        -5: const Neg(ConstantNumber.i),
        -4: RationalNumber.one,
        -3: ConstantNumber.i,
        -2: RationalNumber.negativeOne,
        -1: const Neg(ConstantNumber.i),
        0: RationalNumber.one,
        1: ConstantNumber.i,
        2: RationalNumber.negativeOne,
        3: const Neg(ConstantNumber.i),
        4: RationalNumber.one,
        5: ConstantNumber.i,
        6: RationalNumber.negativeOne,
        7: const Neg(ConstantNumber.i),
        8: RationalNumber.one,
        100: RationalNumber.one,
        101: ConstantNumber.i,
        102: RationalNumber.negativeOne,
        103: const Neg(ConstantNumber.i),
        -100: RationalNumber.one,
        -99: ConstantNumber.i,
        -98: RationalNumber.negativeOne,
        -97: const Neg(ConstantNumber.i),
      };

      for (final entry in powers.entries) {
        final p = entry.key;
        final expected = entry.value;
        final expr = Pow(ConstantNumber.i, RationalNumber(p)).simplify();
        check(expr).equals(expected);
      }
    });

    test('cyclic powers of negated imaginary unit -i across bounds', () {
      final negPowers = {
        -4: RationalNumber.one,
        -3: const Neg(ConstantNumber.i),
        -2: RationalNumber.negativeOne,
        -1: ConstantNumber.i,
        0: RationalNumber.one,
        1: const Neg(ConstantNumber.i),
        2: RationalNumber.negativeOne,
        3: ConstantNumber.i,
        4: RationalNumber.one,
        5: const Neg(ConstantNumber.i),
        6: RationalNumber.negativeOne,
        7: ConstantNumber.i,
      };

      for (final entry in negPowers.entries) {
        final p = entry.key;
        final expected = entry.value;
        final expr = Pow(
          const Neg(ConstantNumber.i),
          RationalNumber(p),
        ).simplify();
        check(expr).equals(expected);
      }
    });

    test('real number exponent powers on imaginary unit', () {
      check(const Pow(ConstantNumber.i, RealNumber(0.0)).simplify())
          .equals(RationalNumber.one);
      check(const Pow(ConstantNumber.i, RealNumber(1.0)).simplify())
          .equals(ConstantNumber.i);
      check(const Pow(ConstantNumber.i, RealNumber(2.0)).simplify())
          .equals(RationalNumber.negativeOne);
      check(const Pow(ConstantNumber.i, RealNumber(3.0)).simplify())
          .equals(const Neg(ConstantNumber.i));
      check(const Pow(ConstantNumber.i, RealNumber(4.0)).simplify())
          .equals(RationalNumber.one);

      check(const Pow(Neg(ConstantNumber.i), RealNumber(2.0)).simplify())
          .equals(RationalNumber.negativeOne);
      check(const Pow(Neg(ConstantNumber.i), RealNumber(3.0)).simplify())
          .equals(ConstantNumber.i);
    });

    test('scaled imaginary product powers (c * i)^k and (i * c)^k', () {
      // (2 * i)^2 = -4
      const twoI = Mul(RationalNumber(2), ConstantNumber.i);
      check(const Pow(twoI, RationalNumber(2)).simplify())
          .equals(const RationalNumber(-4));

      // (2 * i)^3 = -8i
      check(const Pow(twoI, RationalNumber(3)).simplify())
          .equals(const Mul(RationalNumber(-8), ConstantNumber.i));

      // (2 * i)^4 = 16
      check(const Pow(twoI, RationalNumber(4)).simplify())
          .equals(const RationalNumber(16));

      // (i * 2)^2 = -4
      const iTwo = Mul(ConstantNumber.i, RationalNumber(2));
      check(const Pow(iTwo, RationalNumber(2)).simplify())
          .equals(const RationalNumber(-4));

      // (1/2 * i)^2 = -1/4
      const halfI = Mul(RationalNumber(1, 2), ConstantNumber.i);
      check(const Pow(halfI, RationalNumber(2)).simplify())
          .equals(const RationalNumber(-1, 4));

      // (1/2 * i)^(-2) = -4
      check(const Pow(halfI, RationalNumber(-2)).simplify())
          .equals(const RationalNumber(-4));
    });

    test('complexPow edge cases at zero base and zero exponent', () {
      // 0^0 = 1
      check(complexPow(Complex.zero, Complex.zero)).equals(Complex.one);
      // 0^(positive real) = 0
      check(complexPow(Complex.zero, const Complex(3, 0))).equals(Complex.zero);
      // 0^(positive real + imag) = 0
      check(complexPow(Complex.zero, const Complex(3, 2))).equals(Complex.zero);
      // 0^(negative real) = infinity
      final infReal = complexPow(Complex.zero, const Complex(-2, 0));
      check(infReal.a.isInfinite).isTrue();
      check(infReal.b).equals(0.0);
      // 0^(negative real + imag) = infinity + nan i
      final infComplex = complexPow(Complex.zero, const Complex(-2, 3));
      check(infComplex.a.isInfinite).isTrue();
      check(infComplex.b.isNaN).isTrue();
      // z^0 = 1
      check(complexPow(const Complex(3, 4), Complex.zero)).equals(Complex.one);
      check(complexPow(const Complex(-2, -5), Complex.zero))
          .equals(Complex.one);
    });

    test('complex functions evaluation via evaluateComplex', () {
      // Euler's identity: exp(i * pi) + 1 = 0
      const euler = Add(
        Exp(Mul(ConstantNumber.i, ConstantNumber.pi)),
        RationalNumber.one,
      );
      check(euler.evaluateComplex().abs()).isLessThan(1e-12);

      // sin(i) matches Complex.i.sin()
      final sinI = const Sin(ConstantNumber.i).evaluateComplex();
      check((sinI - Complex.i.sin()).abs()).isLessThan(1e-12);
      check(sinI.a.abs()).isLessThan(1e-12);
      check(sinI.b).equals(Complex.i.sin().b);

      // cos(i) = cosh(1)
      final cosI = const Cos(ConstantNumber.i).evaluateComplex();
      check((cosI.a - ((math.exp(1) + math.exp(-1)) / 2)).abs())
          .isLessThan(1e-12);
      check(cosI.b.abs()).isLessThan(1e-12);

      // tan(i) = i * tanh(1)
      final tanI = const Tan(ConstantNumber.i).evaluateComplex();
      check(tanI.a.abs()).isLessThan(1e-12);
      final expectedTanh =
          (math.exp(1) - math.exp(-1)) / (math.exp(1) + math.exp(-1));
      check((tanI.b - expectedTanh).abs()).isLessThan(1e-12);

      // sinh(i) = i * sin(1)
      final sinhI = const Sinh(ConstantNumber.i).evaluateComplex();
      check(sinhI.a.abs()).isLessThan(1e-12);
      check((sinhI.b - math.sin(1)).abs()).isLessThan(1e-12);

      // cosh(i) = cos(1)
      final coshI = const Cosh(ConstantNumber.i).evaluateComplex();
      check((coshI.a - math.cos(1)).abs()).isLessThan(1e-12);
      check(coshI.b.abs()).isLessThan(1e-12);

      // tanh(i) = i * tan(1)
      final tanhI = const Tanh(ConstantNumber.i).evaluateComplex();
      check(tanhI.a.abs()).isLessThan(1e-12);
      check((tanhI.b - math.tan(1)).abs()).isLessThan(1e-12);

      // ln(i) = i * pi / 2
      final lnI = const Ln(ConstantNumber.i).evaluateComplex();
      check(lnI.a.abs()).isLessThan(1e-12);
      check((lnI.b - math.pi / 2).abs()).isLessThan(1e-12);

      // abs(3 + 4i) = 5
      const threePlusFourI = Add(
        RationalNumber(3),
        Mul(RationalNumber(4), ConstantNumber.i),
      );
      check(const Abs(threePlusFourI).evaluateComplex().a).equals(5.0);
    });

    test('complex division and cancellation in simplify', () {
      // z / i = -z * i = -(z * i) canonically
      final divI = const Div(x, ConstantNumber.i).simplify();
      check(divI).equals(const Neg(Mul(x, ConstantNumber.i)));

      // z / (-i) = z * i canonically
      final divNegI = const Div(x, Neg(ConstantNumber.i)).simplify();
      check(divNegI).equals(const Mul(x, ConstantNumber.i));

      // i / i = 1
      check(const Div(ConstantNumber.i, ConstantNumber.i).simplify())
          .equals(RationalNumber.one);

      // (2 * i) / i = 2
      final twoIDivI = const Div(
        Mul(RationalNumber(2), ConstantNumber.i),
        ConstantNumber.i,
      ).simplify();
      check(twoIDivI).equals(const RationalNumber(2));

      // i * i = -1
      check(const Mul(ConstantNumber.i, ConstantNumber.i).simplify())
          .equals(RationalNumber.negativeOne);

      // i * (-i) = 1
      check(const Mul(ConstantNumber.i, Neg(ConstantNumber.i)).simplify())
          .equals(RationalNumber.one);

      // erf(z) and erfc(z) for |z| > 2.5
      final erfLarge = const Erf(x).evaluateComplex({'x': const Complex(4, 1)});
      final erfcLarge = const Erfc(x)
          .evaluateComplex({'x': const Complex(4, 1)});
      check(erfLarge.a).isCloseTo(1.0, 1e-6);
      check(erfLarge.b).isCloseTo(0.0, 1e-6);
      check((erfLarge + erfcLarge - Complex.one).abs()).isLessThan(1e-12);
    });
  });
}
