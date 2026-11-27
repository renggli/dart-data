import 'package:checks/checks.dart';
import 'package:data/src/symbolic/poly/factor.dart';
import 'package:data/src/symbolic/poly/univariate.dart';
import 'package:data/symbolic.dart';
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
  });
}
