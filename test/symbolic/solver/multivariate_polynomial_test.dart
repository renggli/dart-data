import 'package:checks/checks.dart';
import 'package:data/src/symbolic/solver/multivariate_polynomial.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Monomial and MonomialOrder', () {
    test(
      'supports arithmetic, divisibility, lcm, gcd, coprime, and purePower',
      () {
        final z = Monomial.zero(3);
        check(z.isZero).isTrue();
        check(z.length).equals(3);
        check(z[0]).equals(0);

        final m1 = Monomial([2, 1, 0]);
        final m2 = Monomial([1, 3, 0]);
        final m3 = Monomial([0, 0, 2]);

        check(m1 * m2).equals(Monomial([3, 4, 0]));
        check(Monomial([1, 1, 0]).divides(m1)).isTrue();
        check(m2.divides(m1)).isFalse();
        check(m1.divide(Monomial([1, 1, 0]))).equals(Monomial([1, 0, 0]));
        check(() => m1.divide(m2)).throws<ArgumentError>();

        check(m1.lcm(m2)).equals(Monomial([2, 3, 0]));
        check(m1.gcd(m2)).equals(Monomial([1, 1, 0]));
        check(m1.isCoprime(m2)).isFalse();
        check(m1.isCoprime(m3)).isTrue();

        check(m3.isPurePower(2)).isTrue();
        check(m3.isPurePower(0)).isFalse();
        check(m1.isPurePower(0)).isFalse();

        check(m1.hashCode).equals(Monomial([2, 1, 0]).hashCode);
        check(m1.toString()).equals('Monomial[2, 1, 0]');
      },
    );

    test('compares monomials under grevlex and lex orders', () {
      final a = Monomial([2, 0, 0]);
      final b = Monomial([1, 1, 0]);
      final c = Monomial([1, 0, 1]);
      final d = Monomial([1, 0, 0]);

      check(MonomialOrder.grevlex.compare(a, d)).isGreaterThan(0);
      check(MonomialOrder.grevlex.compare(a, b)).isGreaterThan(0);
      check(MonomialOrder.grevlex.compare(b, c)).isGreaterThan(0);
      check(MonomialOrder.grevlex.compare(a, a)).equals(0);

      check(MonomialOrder.lex.compare(a, b)).isGreaterThan(0);
      check(MonomialOrder.lex.compare(d, b)).isLessThan(0);
      check(MonomialOrder.lex.compare(b, b)).equals(0);
    });
  });

  group('MultivariatePolynomial operations', () {
    test(
      'supports ring arithmetic, monic scaling, reduction, and S-polynomials',
      () {
        final vars = ['x', 'y'];
        final zero = MultivariatePolynomial.zero(vars);
        check(zero.isZero).isTrue();
        check(zero.length).equals(2);
        check(zero.totalDegree).equals(0);
        check(zero.leadingMonomial()).equals(Monomial.zero(2));
        check(zero.leadingCoefficient()).equals(IntegerNumber.zero);
        check(zero.monic()).equals(zero);
        check(zero.scale(IntegerNumber.two)).equals(zero);
        check(zero.multiplyMonomial(Monomial([1, 0]), IntegerNumber.two))
            .equals(zero);
        check(zero.reduce([])).equals(zero);
        check(zero.toExpr()).equals(IntegerNumber.zero);

        final p = MultivariatePolynomial.fromExpr(
          Expr.parse('2*x + 2*y'),
          vars,
        );
        final q = MultivariatePolynomial.fromExpr(Expr.parse('x - y'), vars);

        check(p.totalDegree).equals(1);
        check(p.scale(IntegerNumber.zero)).equals(zero);
        check(p.multiplyMonomial(Monomial([1, 0]), IntegerNumber.zero))
            .equals(zero);
        check(p.monic().leadingCoefficient()).equals(IntegerNumber.one);
        check(q.monic()).equals(q);

        // Addition and subtraction with term cancellation
        final sum = p + q.scale(IntegerNumber.of(2));
        check(sum.toExpr()).equals(Expr.parse('4*x'));
        check(p - p).equals(zero);

        // Multiplication with middle-term cancellation: (x + y)*(x - y) = x^2 - y^2
        final diffSq = p.monic() * q;
        check(diffSq.toExpr().simplify())
            .equals(Expr.parse('x^2 - y^2').simplify());
        check(p * zero).equals(zero);

        // Reduction with non-zero remainder and empty divisors
        check(p.reduce([zero])).equals(p);
        final f = MultivariatePolynomial.fromExpr(
          Expr.parse('x^2 + x*y + 1'),
          vars,
        );
        final rem = f.reduce([q]);
        check(rem.toExpr().simplify())
            .equals(Expr.parse('1 + 2*y^2').simplify());

        // S-polynomial
        final sPoly = MultivariatePolynomial.sPolynomial(p, q);
        check(sPoly.toExpr().simplify()).equals(Expr.parse('2*y').simplify());

        // Equality, hashCode, and toString
        final pCopy = MultivariatePolynomial.fromExpr(
          Expr.parse('2*x + 2*y'),
          vars,
        );
        check(p).equals(pCopy);
        check(p.hashCode).equals(pCopy.hashCode);
        check(p == q).isFalse();
        check(p.toString()).isNotEmpty();
      },
    );

    test('validates input expressions in fromExpr', () {
      final vars = ['x', 'y'];
      // Duplicate additive terms cancelling to zero
      final cancelled = MultivariatePolynomial.fromExpr(
        Add([const Variable('x'), -const Variable('x')]),
        vars,
      );
      check(cancelled.isZero).isTrue();

      // Single constant term toExpr
      final constPoly = MultivariatePolynomial.fromExpr(
        IntegerNumber.of(5),
        vars,
      );
      check(constPoly.toExpr()).equals(IntegerNumber.of(5));

      // Non-rational coefficient throws ArgumentError
      check(
        () => MultivariatePolynomial.fromExpr(
          const RealNumber(1.5) * const Variable('x'),
          vars,
        ),
      ).throws<ArgumentError>();

      // Non-polynomial factor throws ArgumentError
      check(
        () => MultivariatePolynomial.fromExpr(Sin(const Variable('x')), vars),
      ).throws<ArgumentError>();

      // Unknown variable throws ArgumentError
      check(() => MultivariatePolynomial.fromExpr(Expr.parse('x + z'), vars))
          .throws<ArgumentError>();
    });
  });
}
