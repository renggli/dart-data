import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

Expr _sliceFor1DPlot(Expr expr) {
  final freeVars = expr.freeVariables;
  if (freeVars.length == 1) {
    final v = freeVars.first;
    return v == 'x' ? expr : expr.substitute(v, const Variable('x'));
  }
  if (freeVars.isEmpty) return expr;
  var sub = expr;
  for (final v in freeVars) {
    if (v != 'x') {
      sub = sub.substitute(v, IntegerNumber.one);
    }
  }
  return sub;
}

void main() {
  group('Expressions web app helpers', () {
    test('sliceFor1DPlot maps single free variable to x and slices multivariate expressions', () {
      final tExpr = Sin(const Variable('t'));
      final slicedT = _sliceFor1DPlot(tExpr);
      check(slicedT.toString()).equals('sin(x)');
      check(slicedT.toFunction1D('x')(0.0)).equals(0.0);

      final xExpr = Cos(const Variable('x'));
      check(_sliceFor1DPlot(xExpr).toString()).equals('cos(x)');

      final multiExpr =
          const Variable('x') * const Variable('y') + const Variable('z');
      check(_sliceFor1DPlot(multiExpr).simplify().toString()).equals('1 + x');

      final constExpr = IntegerNumber.of(42);
      check(_sliceFor1DPlot(constExpr).toString()).equals('42');
    });
  });
}
