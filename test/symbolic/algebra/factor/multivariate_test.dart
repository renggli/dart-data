import 'package:checks/checks.dart';
import 'package:data/src/symbolic/algebra/factor/multivariate.dart';
import 'package:data/src/symbolic/algebra/factor/univariate.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Monomial GCD extraction and division', () {
    test('extractMonomialGcd extracts rational scalar and variable powers', () {
      check(extractMonomialGcd(const [])).isNull;
      check(
        extractMonomialGcd([
          Mul.of([const RealNumber(2.0), const Variable('x')]),
          const Variable('x'),
        ]),
      ).isNull;

      final terms = <Expr>[];
      collectAdditiveTerms(
        Expr.parse('1/2 * x^3 * y^2 + 1/4 * x^2 * y^3'),
        1,
        terms,
      );
      final gcd = extractMonomialGcd(terms);
      check(gcd).isNotNull();
      check(gcd.toString()).equals('1/4 * x ^ 2 * y ^ 2');

      // Divide monomial with residuals and exact cancellation
      const x = Variable('x');
      const y = Variable('y');
      check(divideMonomial(x, x)).equals(IntegerNumber.one);
      final withResiduals = divideMonomial(
        Mul.of([
          IntegerNumber.of(6),
          Pow.of(x, IntegerNumber.of(3)),
          Pow.of(y, IntegerNumber.negativeOne),
          Fn.sin(x),
        ]),
        Mul.of([IntegerNumber.two, x, Fn.sin(x)]),
      );
      check(withResiduals.toString()).equals('3 * x ^ 2 / y');
    });

    test(
      'factorByGrouping4 handles all pairwise partitions and sign variants',
      () {
        const x = Variable('x');
        const y = Variable('y');
        const z = Variable('z');
        const w = Variable('w');

        check(factorByGrouping4([x, y], assumptions: Assumptions.none)).isNull;

        // Partition ((0, 1), (2, 3)) with r1 == r2
        final g1 = factorByGrouping4([
          Mul.of([x, z]),
          Mul.of([x, w]),
          Mul.of([y, z]),
          Mul.of([y, w]),
        ], assumptions: Assumptions.none);
        check(g1).isNotNull();

        // Partition ((0, 2), (1, 3)) with r1 == -r2: x*z - y*w + x*w - y*z
        final g2 = factorByGrouping4([
          Mul.of([x, z]),
          Mul.of([IntegerNumber.negativeOne, y, w]),
          Mul.of([x, w]),
          Mul.of([IntegerNumber.negativeOne, y, z]),
        ], assumptions: Assumptions.none);
        check(g2).isNotNull();
        check((g2!.expand() - Expr.parse('x*z - y*w + x*w - y*z')).simplify())
            .equals(IntegerNumber.zero);

        // Non-factorable 4-term list returns null
        check(factorByGrouping4([x, y, z, w], assumptions: Assumptions.none))
            .isNull;
      },
    );
  });

  group('Difference of squares and sum/difference of cubes', () {
    test(
      'matchDifferenceOfSquares handles both sign orders and product bases',
      () {
        const x = Variable('x');
        const y = Variable('y');
        const z = Variable('z');

        // -4 * x^2 * y^4 + 9 * z^2 (c1 < 0, c2 > 0)
        final diff = matchDifferenceOfSquares([
          Mul.of([
            IntegerNumber.of(-4),
            Pow.of(x, IntegerNumber.two),
            Pow.of(y, IntegerNumber.of(4)),
          ]),
          Mul.of([IntegerNumber.of(9), Pow.of(z, IntegerNumber.two)]),
        ]);
        check(diff).isNotNull();
        final (leftRoot, rightRoot) = diff!;
        check(leftRoot.toString()).equals('3 * z');
        check(rightRoot.toString()).equals('2 * x * y ^ 2');

        check(extractBaseSquareRoot(IntegerNumber.one))
            .equals(IntegerNumber.one);
        check(extractBaseSquareRoot(x)).isNull;
        check(extractBaseSquareRoot(Fn.sin(x))).isNull;
        check(matchDifferenceOfSquares([x])).isNull;
        check(
          matchDifferenceOfSquares([
            Mul.of([const RealNumber(1.0), Pow.of(x, IntegerNumber.two)]),
            Mul.of([const RealNumber(-1.0), Pow.of(y, IntegerNumber.two)]),
          ]),
        ).isNull;
      },
    );

    test(
      'matchSumOrDifferenceOfCubes handles both sign orders and product bases',
      () {
        const x = Variable('x');
        const y = Variable('y');
        const z = Variable('z');

        // -8 * x^3 * y^6 + 27 * z^3 (c1 < 0, c2 > 0)
        final cubes = matchSumOrDifferenceOfCubes([
          Mul.of([
            IntegerNumber.of(-8),
            Pow.of(x, IntegerNumber.of(3)),
            Pow.of(y, IntegerNumber.of(6)),
          ]),
          Mul.of([IntegerNumber.of(27), Pow.of(z, IntegerNumber.of(3))]),
        ]);
        check(cubes).isNotNull();
        check(cubes!.isDifference).isTrue;
        check(cubes.a.toString()).equals('3 * z');
        check(cubes.b.toString()).equals('2 * x * y ^ 2');

        check(extractBaseCubeRoot(IntegerNumber.one)).equals(IntegerNumber.one);
        check(extractBaseCubeRoot(x)).isNull;
        check(integerCbrt(BigInt.zero)).equals(BigInt.zero);
        check(integerCbrt(BigInt.from(-27))).equals(BigInt.from(-3));
        check(integerCbrt(BigInt.from(10))).isNull;
        final bigCube = BigInt.from(10).pow(60);
        check(integerCbrt(bigCube)).equals(BigInt.from(10).pow(20));
        final bigSq = BigInt.from(10).pow(60);
        check(Number.exactIntegerRoot(bigSq, 2))
            .equals(BigInt.from(10).pow(30));
        check(isOne(IntegerNumber.one)).isTrue;
        check(isOne(x)).isFalse;
      },
    );

    test('factors out non-variable symbolic common factors', () {
      check(Expr.parse('x*sin(y) + 2*sin(y)').factor())
          .equals(Expr.parse('(2 + x)*sin(y)').simplify());
      check(Expr.parse('x*exp(x) + exp(x)').factor())
          .equals(Expr.parse('(1 + x)*exp(x)').simplify());
    });
  });
}
