import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

import '../../web/expressions/algebra.dart';
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

  group('VariableAssumption and buildAssumptions', () {
    test(
      'round-trips every VariableAssumption key and applies to Assumptions',
      () {
        for (final assumption in VariableAssumption.values) {
          check(VariableAssumption.parse(assumption.key)).equals(assumption);
        }
        check(VariableAssumption.parse('bogus'))
            .equals(VariableAssumption.unknown);

        const x = Variable('x');
        check(
          Expr.parse('sqrt(x^2)').simplify(
            assumptions: VariableAssumption.negative.applyTo(
              Assumptions.none,
              'x',
            ),
          ),
        ).equals(-x);
        check(
          Expr.parse('sqrt(x^2)').simplify(
            assumptions: VariableAssumption.nonNegative.applyTo(
              Assumptions.none,
              'x',
            ),
          ),
        ).equals(x);
        check(
          Expr.parse('(-1)^x').simplify(
            assumptions: VariableAssumption.odd.applyTo(Assumptions.none, 'x'),
          ),
        ).equals(IntegerNumber.negativeOne);
        check(
          Expr.parse('(-1)^x').simplify(
            assumptions: VariableAssumption.even.applyTo(Assumptions.none, 'x'),
          ),
        ).equals(IntegerNumber.one);
        check(
          VariableAssumption.nonZero
              .applyTo(Assumptions.none, 'x')
              .isNonZero('x'),
        ).isTrue;
      },
    );

    test(
      'parses relational constraints and folds constant variable bounds',
      () {
        final res = buildAssumptions({
          'x': VariableAssumption.real,
        }, relationsRaw: 'x > 2, y <= 10, x > y');
        check(res.invalidRelations).isEmpty;
        check(res.assumptions.relations.length).equals(3);
        check(res.assumptions.boundsOf('x').lower).equals(IntegerNumber.two);
        check(res.assumptions.boundsOf('x').lowerInclusive).isFalse;
        check(res.assumptions.boundsOf('y').upper).equals(IntegerNumber.of(10));
        check(res.assumptions.boundsOf('y').upperInclusive).isTrue;
        check(
          Expr.parse('abs(x - 2) + sqrt((x - 2)^2)')
              .simplify(assumptions: res.assumptions)
              .format(),
        ).equals('-4 + 2 * x');
      },
    );

    test('handles flipped bounds and reports non-relational inputs', () {
      final res = buildAssumptions(
        const {},
        relationsRaw: '1 < x, x <= 5, not_a_relation, sin(x)',
      );
      check(res.invalidRelations).deepEquals(['not_a_relation', 'sin(x)']);
      check(res.assumptions.boundsOf('x').lower).equals(IntegerNumber.one);
      check(res.assumptions.boundsOf('x').upper).equals(IntegerNumber.of(5));
      check(res.assumptions.boundsOf('x').lowerInclusive).isFalse;
      check(res.assumptions.boundsOf('x').upperInclusive).isTrue;
    });
  });
}
