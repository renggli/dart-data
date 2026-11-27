import 'package:checks/checks.dart';
import 'package:data/polynomial.dart';
import 'package:data/src/symbolic/poly/bridge.dart';
import 'package:data/src/symbolic/poly/univariate.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Polynomial AST and package:data bridge', () {
    test('converts between Expr, PolyQ, PolyZ, and Polynomial<Expr>', () {
      final expr = Expr.parse('(x + 1)^2 + 1/2 * x');
      final pq = exprToPolyQ(expr, 'x')!;
      check(pq).equals(
        PolyQ([IntegerNumber.one, RationalNumber(5, 2), IntegerNumber.one]),
      );
      check(polyQToExpr(pq, 'x').simplify())
          .equals(Expr.parse('1 + 5/2 * x + x^2').simplify());

      final symPoly = exprToSymbolicPolynomial(
        Expr.parse('a * x^2 + b * x + c'),
        'x',
      );
      check(symPoly).isNotNull();
      check(symPoly!.degree).equals(2);
      check(symPoly).isA<Polynomial<Expr>>();
      check(symbolicPolynomialToExpr(symPoly, 'x'))
          .equals(Expr.parse('c + b * x + a * x^2').simplify());

      check(exprToPolyQ(Expr.parse('sin(x) + 1'), 'x')).isNull;
      check(exprToSymbolicPolynomial(Expr.parse('sin(x) + 1'), 'x')).isNull;
    });
  });
}
