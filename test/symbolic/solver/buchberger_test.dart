import 'package:checks/checks.dart';
import 'package:data/src/symbolic/solver/buchberger.dart';
import 'package:data/src/symbolic/solver/multivariate_polynomial.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('BuchbergerEngine Gröbner basis computation', () {
    test(
      'handles empty input, inconsistent ideals, and Gebauer-Möller criteria',
      () {
        final vars = ['x', 'y', 'z'];
        check(BuchbergerEngine.compute([])).isEmpty();
        check(BuchbergerEngine.compute([MultivariatePolynomial.zero(vars)]))
            .isEmpty();
        check(BuchbergerEngine.autoreduce([])).isEmpty();

        // Inconsistent ideal: {x + y, x + y + 1} -> {1}
        final inc = BuchbergerEngine.compute([
          MultivariatePolynomial.fromExpr(Expr.parse('x + y'), vars),
          MultivariatePolynomial.fromExpr(Expr.parse('x + y + 1'), vars),
        ]);
        check(inc.length).equals(1);
        check(inc.first.leadingMonomial().isZero).isTrue();

        // System exercising Gebauer-Möller Criteria F and M and tie-breaking
        final polys = [
          MultivariatePolynomial.fromExpr(Expr.parse('x^2*y - z'), vars),
          MultivariatePolynomial.fromExpr(Expr.parse('x*y^2 - x'), vars),
          MultivariatePolynomial.fromExpr(Expr.parse('x*y - z'), vars),
          MultivariatePolynomial.fromExpr(Expr.parse('x*y + z - 2'), vars),
        ];
        final gb = BuchbergerEngine.compute(polys);
        check(gb).isNotEmpty();

        // Autoreduce with duplicate leading monomials filters redundant element
        final dup = BuchbergerEngine.autoreduce([
          MultivariatePolynomial.fromExpr(Expr.parse('x + y'), vars),
          MultivariatePolynomial.fromExpr(Expr.parse('x + z'), vars),
        ]);
        check(dup.length).equals(1);
      },
    );
  });

  group('BuchbergerEngine degree and iteration limits', () {
    test('enforces maxDegree and maxIterations bounds', () {
      final vars = ['x', 'y'];
      final highDeg = MultivariatePolynomial.fromExpr(
        Expr.parse('x^5 + y'),
        vars,
      );
      check(() => BuchbergerEngine.compute([highDeg], maxDegree: 3))
          .throws<StateError>();

      final p1 = MultivariatePolynomial.fromExpr(
        Expr.parse('x^2 + y^2 - 1'),
        vars,
      );
      final p2 = MultivariatePolynomial.fromExpr(Expr.parse('x*y - 1'), vars);
      check(() => BuchbergerEngine.compute([p1, p2], maxIterations: 0))
          .throws<StateError>();
      check(() => BuchbergerEngine.compute([p1, p2], maxDegree: 2))
          .throws<StateError>();
    });
  });
}
