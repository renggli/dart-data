import 'package:checks/checks.dart';
import 'package:data/src/symbolic/poly/bridge.dart';
import 'package:data/src/symbolic/poly/factor.dart';
import 'package:data/src/symbolic/poly/univariate.dart';
import 'package:data/symbolic.dart';
import 'package:more/math.dart' show LcmBigIntExtension;
import 'package:test/scaffolding.dart';

void main() {
  group('PolyQ and PolyZ exact univariate factorization', () {
    test(
      'factors rational linear, quadratic, biquadratic, and Sophie Germain',
      () {
        final p = PolyQ([
          RationalNumber(-1, 2),
          IntegerNumber.zero,
          RationalNumber(1, 2),
        ]);
        final res = factorPolyQ(p);
        check(res.scalar).equals(RationalNumber(1, 2));
        check(res.factors.length).equals(2);
        check(factorPolyQToExpr(p, 'x').toString())
            .equals('1/2 * (-1 + x) * (1 + x)');

        // Sophie Germain: x^4 + 4 = (x^2 - 2x + 2)(x^2 + 2x + 2)
        final sg = PolyZ([
          BigInt.from(4),
          BigInt.zero,
          BigInt.zero,
          BigInt.zero,
          BigInt.one,
        ]);
        final sgRes = factorPolyZ(sg);
        check(sgRes.factors.length).equals(2);
      },
    );

    test(
      'factors high-degree repeated nonlinear factors via Yun decomposition',
      () {
        final quad = PolyZ([BigInt.one, BigInt.one, BigInt.one]); // x^2 + x + 1
        final cube = PolyZ([
          BigInt.from(2),
          BigInt.zero,
          BigInt.one,
        ]); // x^2 + 2
        final poly = quad * quad * cube;
        final res = factorPolyZ(poly);
        check(res.factors.length).equals(2);
        check(res.factors.any((f) => f.factor == quad && f.multiplicity == 2))
            .isTrue;
        check(res.factors.any((f) => f.factor == cube && f.multiplicity == 1))
            .isTrue;
      },
    );

    test('extracts rational polynomials via exprToPolyQ and rejects non-polynomials', () {
      final p0 = exprToPolyQ(IntegerNumber.zero, 'x');
      check(p0).isNotNull();
      check(p0!.isZero).isTrue;
      check(p0.degree).equals(-1);

      final p = exprToPolyQ(Expr.parse('1/2 * x^2 - 3 * x + 5'), 'x');
      check(p).isNotNull();
      check(p!.degree).equals(2);

      check(exprToPolyQ(Expr.parse('1.5 * x + 1'), 'x')).isNull;
      check(exprToPolyQ(Expr.parse('x^(-1) + 1'), 'x')).isNull;
      check(exprToPolyQ(Expr.parse('x + y'), 'x')).isNull;
      check(exprToPolyQ(Expr.parse('sin(x) + 1'), 'x')).isNull;
    });

    test(
      'factors constant, linear, quadratic, BigInt, and rational polynomials',
      () {
        check(factorPolyQToExpr(PolyQ([IntegerNumber.of(7)]), 'x'))
            .equals(IntegerNumber.of(7));

        check(Expr.parse('-2 * x - 4').factor().toString())
            .equals('-2 * (2 + x)');
        check(Expr.parse('x + 3').factor().toString()).equals('3 + x');

        final pureMonomial = exprToPolyQ(Expr.parse('3 * x^2'), 'x')!;
        check(factorPolyQToExpr(pureMonomial, 'x').toString())
            .equals('3 * x ^ 2');

        final bigInt = BigInt.two.pow(70);
        final bigNum = IntegerNumber(bigInt);
        final bigDen = RationalNumber.of(BigInt.one, bigInt);
        check(factorPolyQToExpr(PolyQ([IntegerNumber.one, bigNum]), 'x'))
            .isA<Add>();
        check(factorPolyQToExpr(PolyQ([IntegerNumber.one, bigDen]), 'x'))
            .isA<Mul>();

        final big140 = BigInt.two.pow(140);
        final polyBigSq = PolyQ([
          IntegerNumber(-big140),
          IntegerNumber.zero,
          IntegerNumber.one,
        ]);
        check(factorPolyQToExpr(polyBigSq, 'x').toString()).equals(
          '(-1180591620717411303424 + x) * (1180591620717411303424 + x)',
        );

        check(Expr.parse('2 * x^3 - 3 * x^2').factor().toString())
            .equals('x ^ 2 * (-3 + 2 * x)');
        check(Expr.parse('2 * x^2 + 2').factor().toString())
            .equals('2 * (1 + x ^ 2)');
        check(Expr.parse('1/2 * x^2 - 1/2').factor().toString())
            .equals('1/2 * (-1 + x) * (1 + x)');
      },
    );

    test(
      'factors biquadratics, quadratics, and irreducible higher degrees',
      () {
        check(Expr.parse('x^4 + 3*x^2 + 2').factor().toString())
            .equals('(1 + x ^ 2) * (2 + x ^ 2)');

        final quadFactors = factorQuadraticInX(
          BigInt.one,
          BigInt.from(-4),
          'x',
        );
        check(quadFactors.length).equals(2);

        check(Expr.parse('x^5 + x + 1').factor().toString())
            .equals('1 + x + x ^ 5');
        check(Expr.parse('2*x^5 + 2*x + 2').factor().toString())
            .equals('2 * (1 + x + x ^ 5)');
      },
    );

    test('computes divisors and integer roots accurately', () {
      check(BigInt.from(12).gcd(BigInt.from(18))).equals(BigInt.from(6));
      check(BigInt.zero.lcm(BigInt.from(5))).equals(BigInt.zero);
      check(BigInt.from(4).lcm(BigInt.from(6))).equals(BigInt.from(12));
      check(Number.exactIntegerRoot(BigInt.from(-4), 2)).isNull;
      check(Number.exactIntegerRoot(BigInt.zero, 2)).equals(BigInt.zero);
      check(Number.exactIntegerRoot(BigInt.from(16), 2)).equals(BigInt.from(4));
      check(Number.exactIntegerRoot(BigInt.from(15), 2)).isNull;
      check(divisors(BigInt.zero)).isEmpty;
      check(divisors(BigInt.from(12))).deepEquals([
        BigInt.one,
        BigInt.two,
        BigInt.from(3),
        BigInt.from(4),
        BigInt.from(6),
        BigInt.from(12),
      ]);
      check(Expr.parse('x^2 - 3*2^31*x + 2^63').factor())
          .equals(Expr.parse('(x - 2^31)*(x - 2^32)').simplify());
      final mixedDivs = divisors(BigInt.one << 60);
      check(mixedDivs.length).equals(61);
      check(mixedDivs.first).equals(BigInt.one);
      check(mixedDivs.last).equals(BigInt.one << 60);
    });

    test('factors high-degree polynomials with large coefficients without GCD blowup', () {
      final poly = Expr.parse(
        '(x^8 + 256 * x^4 + 65536) * (x^8 + 512 * x^3 + 131072)',
      ).expand();
      final sw = Stopwatch()..start();
      final factored = poly.factor();
      sw.stop();
      check(sw.elapsedMilliseconds).isLessThan(200);
      check(factored.expand().simplify()).equals(poly.simplify());

      final irred = Expr.parse('x^10 + 131072 * x^6 + 65536 * x^2 + 1');
      final sw2 = Stopwatch()..start();
      final irredFactored = irred.factor();
      sw2.stop();
      check(sw2.elapsedMilliseconds).isLessThan(200);
      check(irredFactored.expand().simplify()).equals(irred.simplify());
    });
  });
}
