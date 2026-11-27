import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

import '../../web/expressions/presets.dart';

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
      final tExpr = Fn.sin(const Variable('t'));
      final slicedT = _sliceFor1DPlot(tExpr);
      check(slicedT.toString()).equals('sin(x)');
      check(slicedT.toFunction1D('x')(0.0)).equals(0.0);

      final xExpr = Fn.cos(const Variable('x'));
      check(_sliceFor1DPlot(xExpr).toString()).equals('cos(x)');

      final multiExpr =
          const Variable('x') * const Variable('y') + const Variable('z');
      check(_sliceFor1DPlot(multiExpr).simplify().toString()).equals('1 + x');

      final constExpr = IntegerNumber.of(42);
      check(_sliceFor1DPlot(constExpr).toString()).equals('42');
    });

    test('all expressionPresets parse and evaluate without errors', () {
      check(expressionPresets).isNotEmpty;
      final seenIds = <String>{};
      for (final preset in expressionPresets) {
        check(seenIds.add(preset.id)).isTrue;
        check(preset.name).isNotEmpty;
        check(preset.category).isNotEmpty;
        check(preset.description).isNotEmpty;
        final parsed = Expr.parse(preset.formula);
        check(parsed.simplify()).isA<Expr>();
      }
    });
  });
}
