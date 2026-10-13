import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  const x = Variable('x');

  group('PowerSeries - Core Algebraic Operations', () {
    test('addition and subtraction with order truncation', () {
      final s1 = PowerSeries('x', RationalNumber.zero, {
        0: const RationalNumber(1),
        1: const RationalNumber(2),
      }, 3);
      final s2 = PowerSeries('x', RationalNumber.zero, {
        1: const RationalNumber(3),
        2: const RationalNumber(4),
      }, 4);

      final sum = s1 + s2;
      check(sum.order).equals(3);
      check(sum.coefficients[0]).equals(const RationalNumber(1));
      check(sum.coefficients[1]).equals(const RationalNumber(5));
      check(sum.coefficients[2]).equals(const RationalNumber(4));

      final diff = s2 - s1;
      check(diff.order).equals(3);
      check(diff.coefficients[0]).equals(const RationalNumber(-1));
      check(diff.coefficients[1]).equals(const RationalNumber(1));
      check(diff.coefficients[2]).equals(const RationalNumber(4));
    });

    test('Cauchy multiplication and remainder degradation', () {
      // (1 + x) * (1 - x) = 1 - x^2
      final p1 = PowerSeries('x', RationalNumber.zero, {
        0: RationalNumber.one,
        1: RationalNumber.one,
      }, 4);
      final p2 = PowerSeries('x', RationalNumber.zero, {
        0: RationalNumber.one,
        1: RationalNumber.negativeOne,
      }, 4);

      final prod = p1 * p2;
      check(prod.order).equals(4);
      check(prod.coefficients[0]).equals(RationalNumber.one);
      check(prod.coefficients.containsKey(1)).isFalse();
      check(prod.coefficients[2]).equals(RationalNumber.negativeOne);
    });

    test('Laurent series inversion recurrence', () {
      // 1 / (1 - x) = 1 + x + x^2 + x^3 + O(x^4)
      final oneMinusX = PowerSeries('x', RationalNumber.zero, {
        0: RationalNumber.one,
        1: RationalNumber.negativeOne,
      }, 4);
      final geom = oneMinusX.reciprocal();
      check(geom.order).equals(4);
      for (var k = 0; k < 4; k++) {
        check(geom.coefficients[k]).equals(RationalNumber.one);
      }

      // 1 / x = x^-1 + O(x^-1)
      final monomialX = PowerSeries('x', RationalNumber.zero, {
        1: RationalNumber.one,
      }, 3);
      final invX = monomialX.reciprocal();
      check(invX.valuation).equals(-1);
      check(invX.coefficients[-1]).equals(RationalNumber.one);
      check(invX.order).equals(1); // 3 - 2(1) = 1
    });

    test('derivative and integrate calculus contracts', () {
      final s = PowerSeries('x', RationalNumber.zero, {
        0: const RationalNumber(5),
        1: const RationalNumber(2),
        2: const RationalNumber(3),
      }, 4);

      final ds = s.derivative();
      check(ds.order).equals(3);
      check(ds.coefficients[0]).equals(const RationalNumber(2));
      check(ds.coefficients[1]).equals(const RationalNumber(6));

      final intS = ds.integrate();
      check(intS.order).equals(4);
      check(intS.coefficients[1]).equals(const RationalNumber(2));
      check(intS.coefficients[2]).equals(const RationalNumber(3));

      // Integrating pole of order 1 throws UnsupportedError
      final pole1 = PowerSeries('x', RationalNumber.zero, {
        -1: RationalNumber.one,
      }, 2);
      check(pole1.integrate).throws<UnsupportedError>();
    });
  });

  group('PowerSeries - Elementary Function Series', () {
    test('Exp(x) series expansion', () {
      final s = const Exp(x).toPowerSeries('x', order: 6);
      check(s.order).equals(6);
      check(s.coefficients[0]).equals(RationalNumber.one);
      check(s.coefficients[1]).equals(RationalNumber.one);
      check(s.coefficients[2]).equals(const RationalNumber(1, 2));
      check(s.coefficients[3]).equals(const RationalNumber(1, 6));
      check(s.coefficients[4]).equals(const RationalNumber(1, 24));
      check(s.coefficients[5]).equals(const RationalNumber(1, 120));
    });

    test('Ln(1 + x) series expansion', () {
      final expr = Ln(RationalNumber.one + x);
      final s = expr.toPowerSeries('x', order: 6);
      check(s.order).equals(6);
      check(s.coefficients[1]).equals(RationalNumber.one);
      check(s.coefficients[2]).equals(const RationalNumber(-1, 2));
      check(s.coefficients[3]).equals(const RationalNumber(1, 3));
      check(s.coefficients[4]).equals(const RationalNumber(-1, 4));
      check(s.coefficients[5]).equals(const RationalNumber(1, 5));
    });

    test('Sin(x) and Cos(x) series expansion', () {
      final sinS = const Sin(x).toPowerSeries('x', order: 6);
      check(sinS.order).equals(6);
      check(sinS.coefficients[1]).equals(RationalNumber.one);
      check(sinS.coefficients[3]).equals(const RationalNumber(-1, 6));
      check(sinS.coefficients[5]).equals(const RationalNumber(1, 120));

      final cosS = const Cos(x).toPowerSeries('x', order: 6);
      check(cosS.order).equals(6);
      check(cosS.coefficients[0]).equals(RationalNumber.one);
      check(cosS.coefficients[2]).equals(const RationalNumber(-1, 2));
      check(cosS.coefficients[4]).equals(const RationalNumber(1, 24));
    });

    test('Tan(x) series expansion', () {
      final tanS = const Tan(x).toPowerSeries('x', order: 6);
      check(tanS.coefficients[1]).equals(RationalNumber.one);
      check(tanS.coefficients[3]).equals(const RationalNumber(1, 3));
      check(tanS.coefficients[5]).equals(const RationalNumber(2, 15));
    });

    test('Sinh(x) and Cosh(x) hyperbolic parity', () {
      final sinhS = const Sinh(x).toPowerSeries('x', order: 6);
      check(sinhS.coefficients[1]).equals(RationalNumber.one);
      check(sinhS.coefficients[3]).equals(const RationalNumber(1, 6));
      check(sinhS.coefficients[5]).equals(const RationalNumber(1, 120));

      final coshS = const Cosh(x).toPowerSeries('x', order: 6);
      check(coshS.coefficients[0]).equals(RationalNumber.one);
      check(coshS.coefficients[2]).equals(const RationalNumber(1, 2));
      check(coshS.coefficients[4]).equals(const RationalNumber(1, 24));
    });

    test('Asin(x) and Atan(x) inverse trigonometric expansions', () {
      final asinS = const Asin(x).toPowerSeries('x', order: 6);
      check(asinS.coefficients[1]).equals(RationalNumber.one);
      check(asinS.coefficients[3]).equals(const RationalNumber(1, 6));
      check(asinS.coefficients[5]).equals(const RationalNumber(3, 40));

      final atanS = const Atan(x).toPowerSeries('x', order: 6);
      check(atanS.coefficients[1]).equals(RationalNumber.one);
      check(atanS.coefficients[3]).equals(const RationalNumber(-1, 3));
      check(atanS.coefficients[5]).equals(const RationalNumber(1, 5));
    });

    test('Binomial powers (1 + x)^alpha', () {
      final sqrtS = Pow(
        RationalNumber.one + x,
        const RationalNumber(1, 2),
      ).toPowerSeries('x', order: 4);
      check(sqrtS.coefficients[0]).equals(RationalNumber.one);
      check(sqrtS.coefficients[1]).equals(const RationalNumber(1, 2));
      check(sqrtS.coefficients[2]).equals(const RationalNumber(-1, 8));
      check(sqrtS.coefficients[3]).equals(const RationalNumber(1, 16));

      final invSqrtS = Pow(
        RationalNumber.one + x,
        const RationalNumber(-1, 2),
      ).toPowerSeries('x', order: 4);
      check(invSqrtS.coefficients[0]).equals(RationalNumber.one);
      check(invSqrtS.coefficients[1]).equals(const RationalNumber(-1, 2));
      check(invSqrtS.coefficients[2]).equals(const RationalNumber(3, 8));
      check(invSqrtS.coefficients[3]).equals(const RationalNumber(-5, 16));
    });
  });

  group('PowerSeries - Composite & Rational Series', () {
    test('Composite exponential-trigonometric: e^sin(x)', () {
      const expr = Exp(Sin(x));
      final s = expr.toPowerSeries('x', order: 6);
      check(s.coefficients[0]).equals(RationalNumber.one);
      check(s.coefficients[1]).equals(RationalNumber.one);
      check(s.coefficients[2]).equals(const RationalNumber(1, 2));
      check(s.coefficients[4]).equals(const RationalNumber(-1, 8));
      check(s.coefficients[5]).equals(const RationalNumber(-1, 15));
    });

    test('Composite log-cosine: ln(cos(x))', () {
      const expr = Ln(Cos(x));
      final s = expr.toPowerSeries('x', order: 7);
      check(s.coefficients[2]).equals(const RationalNumber(-1, 2));
      check(s.coefficients[4]).equals(const RationalNumber(-1, 12));
      check(s.coefficients[6]).equals(const RationalNumber(-1, 45));
    });

    test('Cardinal sine: sin(x) / x', () {
      final expr = const Sin(x) / x;
      final s = expr.toPowerSeries('x', order: 6);
      check(s.order).equals(6);
      check(s.coefficients[0]).equals(RationalNumber.one);
      check(s.coefficients[2]).equals(const RationalNumber(-1, 6));
      check(s.coefficients[4]).equals(const RationalNumber(1, 120));
    });

    test('Laurent pole: 1 / sin(x)', () {
      final expr = RationalNumber.one / const Sin(x);
      final s = expr.toPowerSeries('x', order: 5);
      check(s.valuation).equals(-1);
      check(s.coefficients[-1]).equals(RationalNumber.one);
      check(s.coefficients[1]).equals(const RationalNumber(1, 6));
      check(s.coefficients[3]).equals(const RationalNumber(7, 360));
    });

    test('Cotangent Laurent pole: cot(x) = cos(x) / sin(x)', () {
      final expr = const Cos(x) / const Sin(x);
      final s = expr.toPowerSeries('x', order: 5);
      check(s.valuation).equals(-1);
      check(s.coefficients[-1]).equals(RationalNumber.one);
      check(s.coefficients[1]).equals(const RationalNumber(-1, 3));
      check(s.coefficients[3]).equals(const RationalNumber(-1, 45));
    });
  });

  group('PowerSeries - Expansions Around Non-Zero Points', () {
    test('Ln(x) around a = 1', () {
      const expr = Ln(x);
      final s = expr.toPowerSeries('x', point: RationalNumber.one, order: 4);
      check(s.point).equals(RationalNumber.one);
      check(s.coefficients[1]).equals(RationalNumber.one);
      check(s.coefficients[2]).equals(const RationalNumber(-1, 2));
      check(s.coefficients[3]).equals(const RationalNumber(1, 3));
    });

    test('Exp(x) around a = 1', () {
      const expr = Exp(x);
      final s = expr.toPowerSeries('x', point: RationalNumber.one, order: 3);
      check(s.point).equals(RationalNumber.one);
      check(s.coefficients[0]).equals(ConstantNumber.e);
      check(s.coefficients[1]).equals(ConstantNumber.e);
      check(s.coefficients[2])
          .equals(const Div(ConstantNumber.e, RationalNumber(2)).simplify());
    });

    test('1 / x around a = 2', () {
      final expr = RationalNumber.one / x;
      final s = expr.toPowerSeries(
        'x',
        point: const RationalNumber(2),
        order: 4,
      );
      check(s.point).equals(const RationalNumber(2));
      check(s.coefficients[0]).equals(const RationalNumber(1, 2));
      check(s.coefficients[1]).equals(const RationalNumber(-1, 4));
      check(s.coefficients[2]).equals(const RationalNumber(1, 8));
      check(s.coefficients[3]).equals(const RationalNumber(-1, 16));
    });
  });

  group('SeriesExtension.series() - Expr with OrderTerm', () {
    test('Sin(x).series produces Expr with OrderTerm', () {
      final res = const Sin(x).series('x', order: 5);
      check(res.removeOrder().toString()).equals('x - 1/6 * x ^ 3');
      check(res.freeVariables).unorderedEquals({'x'});
    });
  });

  group('PowerSeries - Adversarial Pole Cauchy Products', () {
    test('Cauchy product of series with poles: (x^-1 + 1) * (x^-2 + 2x)', () {
      // s1: x^-1 + 1, order M = 3, poleOrder p = 1
      final s1 = PowerSeries('x', RationalNumber.zero, {
        -1: RationalNumber.one,
        0: RationalNumber.one,
      }, 3);
      check(s1.valuation).equals(-1);
      check(s1.poleOrder).equals(1);

      // s2: x^-2 + 2x, order N = 4, poleOrder q = 2
      final s2 = PowerSeries('x', RationalNumber.zero, {
        -2: RationalNumber.one,
        1: const RationalNumber(2),
      }, 4);
      check(s2.valuation).equals(-2);
      check(s2.poleOrder).equals(2);

      // Product remainder order: min(N - p, M - q) = min(4 - 1, 3 - 2) = min(3, 1) = 1
      final prod = s1 * s2;
      check(prod.order).equals(1);
      check(prod.valuation).equals(-3);
      check(prod.poleOrder).equals(3);

      // (x^-1 + 1) * (x^-2 + 2x) = x^-3 + x^-2 + 2 + 2x
      // Order is 1, so 2x (degree 1) is absorbed into O(x^1)
      check(prod.coefficients[-3]).equals(RationalNumber.one);
      check(prod.coefficients[-2]).equals(RationalNumber.one);
      check(prod.coefficients[0]).equals(const RationalNumber(2));
      check(prod.coefficients.containsKey(1)).isFalse();

      // Test with larger orders M = 5, N = 5
      // min(5 - 1, 5 - 2) = min(4, 3) = 3
      final s1Boosted = PowerSeries('x', RationalNumber.zero, {
        -1: RationalNumber.one,
        0: RationalNumber.one,
      }, 5);
      final s2Boosted = PowerSeries('x', RationalNumber.zero, {
        -2: RationalNumber.one,
        1: const RationalNumber(2),
      }, 5);
      final prodBoosted = s1Boosted * s2Boosted;
      check(prodBoosted.order).equals(3);
      check(prodBoosted.coefficients[-3]).equals(RationalNumber.one);
      check(prodBoosted.coefficients[-2]).equals(RationalNumber.one);
      check(prodBoosted.coefficients[0]).equals(const RationalNumber(2));
      check(prodBoosted.coefficients[1]).equals(const RationalNumber(2));
      check(prodBoosted.coefficients.containsKey(2)).isFalse();
    });

    test(
      'Cauchy product with higher-order poles and remainder degradation',
      () {
        // sA: x^-3 + 2x^-1, M = 4, p = 3
        final sA = PowerSeries('x', RationalNumber.zero, {
          -3: RationalNumber.one,
          -1: const RationalNumber(2),
        }, 4);
        // sB: x^-2 - 3, N = 5, q = 2
        final sB = PowerSeries('x', RationalNumber.zero, {
          -2: RationalNumber.one,
          0: const RationalNumber(-3),
        }, 5);

        // Expected order: min(5 - 3, 4 - 2) = min(2, 2) = 2
        final prod = sA * sB;
        check(prod.order).equals(2);
        check(prod.valuation).equals(-5);
        // (x^-3 + 2x^-1)(x^-2 - 3) = x^-5 - 3x^-3 + 2x^-3 - 6x^-1 = x^-5 - x^-3 - 6x^-1
        check(prod.coefficients[-5]).equals(RationalNumber.one);
        check(prod.coefficients[-3]).equals(RationalNumber.negativeOne);
        check(prod.coefficients[-1]).equals(const RationalNumber(-6));
        check(prod.coefficients.containsKey(0)).isFalse();
      },
    );
  });

  group('PowerSeries - Adversarial Triangular Inversion & Identity', () {
    test('Invert series with non-zero constant c0 != 0 and verify S * S^-1 = 1 + O(x^N)', () {
      // S = 3 - 2x + 5x^2 - x^3 + O(x^5)
      final s = PowerSeries('x', RationalNumber.zero, {
        0: const RationalNumber(3),
        1: const RationalNumber(-2),
        2: const RationalNumber(5),
        3: const RationalNumber(-1),
      }, 5);
      final invS = s.reciprocal();
      check(invS.order).equals(5);
      check(invS.valuation).equals(0);
      check(invS.coefficients[0]).equals(const RationalNumber(1, 3));

      final identity = s * invS;
      check(identity.order).equals(5);
      check(identity.coefficients[0]).equals(RationalNumber.one);
      for (var k = 1; k < 5; k++) {
        check(identity.coefficients.containsKey(k)).isFalse();
      }
      check(identity.toExpr())
          .equals(RationalNumber.one + const OrderTerm('x', 5));
    });

    test(
      'Invert series with pole x^-m * U(x) and verify S * S^-1 = 1 + O(x^K)',
      () {
        // S = x^-2 + 2x^-1 + 3 + O(x^4), valuation m = -2, poleOrder p = 2
        final s = PowerSeries('x', RationalNumber.zero, {
          -2: RationalNumber.one,
          -1: const RationalNumber(2),
          0: const RationalNumber(3),
        }, 4);
        final invS = s.reciprocal();
        // reciprocal order = order - 2m = 4 - 2(-2) = 8
        check(invS.order).equals(8);
        check(invS.valuation).equals(2);

        final identity = s * invS;
        // prod order = min(invS.order - p, s.order - q) = min(8 - 2, 4 - 0) = 4
        check(identity.order).equals(4);
        check(identity.coefficients[0]).equals(RationalNumber.one);
        for (var k = -3; k < 4; k++) {
          if (k != 0) {
            check(identity.coefficients.containsKey(k)).isFalse();
          }
        }
        check(identity.toExpr())
            .equals(RationalNumber.one + const OrderTerm('x', 4));
      },
    );

    test('Invert series with zero at origin x^m * U(x) and verify S * S^-1 = 1 + O(x^K)', () {
      // S = 2x - x^2 + 3x^3 + O(x^5), m = 1
      final s = PowerSeries('x', RationalNumber.zero, {
        1: const RationalNumber(2),
        2: const RationalNumber(-1),
        3: const RationalNumber(3),
      }, 5);
      final invS = s.reciprocal();
      // order = 5 - 2(1) = 3
      check(invS.order).equals(3);
      check(invS.valuation).equals(-1);

      final identity = s * invS;
      // prod order = min(3 - 0, 5 - 1) = 3
      check(identity.order).equals(3);
      check(identity.coefficients[0]).equals(RationalNumber.one);
      for (var k = -2; k < 3; k++) {
        if (k != 0) {
          check(identity.coefficients.containsKey(k)).isFalse();
        }
      }
      check(identity.toExpr())
          .equals(RationalNumber.one + const OrderTerm('x', 3));
    });
  });

  group('PowerSeries - Adversarial ODE Recurrences & Invariants', () {
    test('e^x ODE recurrence and derivative contract: (e^x)\' = e^x', () {
      final expS = const Exp(x).toPowerSeries('x', order: 8);
      final dExpS = expS.derivative();
      check(dExpS.order).equals(7);
      for (var k = 0; k < 7; k++) {
        check(dExpS.coefficients[k]).equals(expS.coefficients[k]);
      }
    });

    test('sin(x) and cos(x) coupled ODE and Pythagorean identity sin^2 + cos^2 = 1 + O(x^N)', () {
      final s = const Sin(x).toPowerSeries('x', order: 8);
      final c = const Cos(x).toPowerSeries('x', order: 8);

      // Coupled ODE: s\' = c, c\' = -s
      final ds = s.derivative();
      final dc = c.derivative();
      for (var k = 0; k < 7; k++) {
        check(ds.coefficients[k] ?? RationalNumber.zero)
            .equals(c.coefficients[k] ?? RationalNumber.zero);
        final negS = (-(s.coefficients[k] ?? RationalNumber.zero)).simplify();
        check(dc.coefficients[k] ?? RationalNumber.zero).equals(negS);
      }

      // Pythagorean identity: s^2 + c^2 = 1 + O(x^8)
      final pyth = (s * s) + (c * c);
      check(pyth.order).equals(8);
      check(pyth.coefficients[0]).equals(RationalNumber.one);
      for (var k = 1; k < 8; k++) {
        check(pyth.coefficients.containsKey(k)).isFalse();
      }
    });

    test('ln(1 + x) logarithmic ODE recurrence and exponential inversion: e^(ln(1+x)) = 1 + x', () {
      final expr = Ln(RationalNumber.one + x);
      final lnS = expr.toPowerSeries('x', order: 8);
      // derivative of ln(1+x) is (1+x)^-1 = 1 - x + x^2 - x^3 + ...
      final dLnS = lnS.derivative();
      check(dLnS.order).equals(7);
      for (var k = 0; k < 7; k++) {
        final expected = k.isEven
            ? RationalNumber.one
            : RationalNumber.negativeOne;
        check(dLnS.coefficients[k]).equals(expected);
      }

      // Exponential of ln(1+x)
      final expLn = Exp(expr).toPowerSeries('x', order: 6);
      check(expLn.coefficients[0]).equals(RationalNumber.one);
      check(expLn.coefficients[1]).equals(RationalNumber.one);
      for (var k = 2; k < 6; k++) {
        check(expLn.coefficients.containsKey(k)).isFalse();
      }
    });

    test(
      '(1 + x)^alpha binomial power recurrence and reciprocal inversion',
      () {
        // (1 + x)^(1/2) * (1 + x)^(1/2) = 1 + x + O(x^6)
        final sqrtS = Pow(
          RationalNumber.one + x,
          const RationalNumber(1, 2),
        ).toPowerSeries('x', order: 6);
        final sq = sqrtS * sqrtS;
        check(sq.order).equals(6);
        check(sq.coefficients[0]).equals(RationalNumber.one);
        check(sq.coefficients[1]).equals(RationalNumber.one);
        for (var k = 2; k < 6; k++) {
          check(sq.coefficients.containsKey(k)).isFalse();
        }

        // (1 + x)^(2/3) * (1 + x)^(-2/3) = 1 + O(x^6)
        final pPos = Pow(
          RationalNumber.one + x,
          const RationalNumber(2, 3),
        ).toPowerSeries('x', order: 6);
        final pNeg = Pow(
          RationalNumber.one + x,
          const RationalNumber(-2, 3),
        ).toPowerSeries('x', order: 6);
        final pProd = pPos * pNeg;
        check(pProd.order).equals(6);
        check(pProd.coefficients[0]).equals(RationalNumber.one);
        for (var k = 1; k < 6; k++) {
          check(pProd.coefficients.containsKey(k)).isFalse();
        }
      },
    );
  });
}
