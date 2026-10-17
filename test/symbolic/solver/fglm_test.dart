import 'package:checks/checks.dart';
import 'package:data/src/symbolic/solver/buchberger.dart';
import 'package:data/src/symbolic/solver/fglm.dart';
import 'package:data/src/symbolic/solver/multivariate_polynomial.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('FglmEngine basis conversion', () {
    test(
      'handles empty basis, trivial ideal {1}, and non-zero-dimensional error',
      () {
        final vars = ['x', 'y'];
        check(FglmEngine.convert([])).isEmpty();

        // Trivial ideal {1}
        final unit = MultivariatePolynomial.fromExpr(IntegerNumber.one, vars);
        final convUnit = FglmEngine.convert([unit]);
        check(convUnit.length).equals(1);
        check(convUnit.first.toExpr()).equals(IntegerNumber.one);

        // Positive-dimensional ideal (missing pure power of y)
        final posDim = [
          MultivariatePolynomial.fromExpr(Expr.parse('x^2 - y'), vars),
        ];
        check(() => FglmEngine.convert(posDim)).throws<UnsupportedError>();
      },
    );
  });

  group('FglmEngine grevlex to lex conversion', () {
    test('converts zero-dimensional grevlex Gröbner basis to lex basis', () {
      final vars = ['x', 'y'];
      final polys = [
        MultivariatePolynomial.fromExpr(Expr.parse('x^2 + y^2 - 5'), vars),
        MultivariatePolynomial.fromExpr(Expr.parse('x*y - 2'), vars),
      ];
      final grevlex = BuchbergerEngine.compute(
        polys,
        order: MonomialOrder.grevlex,
      );
      final lex = FglmEngine.convert(grevlex);
      check(lex.length).equals(2);
      // Last polynomial in lex order is univariate in y
      check(lex.last.toExpr().dependsOn('x')).isFalse();
      check(lex.last.toExpr().dependsOn('y')).isTrue();
    });
  });
}
