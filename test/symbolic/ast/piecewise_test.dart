import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Relational operators evaluation & formatting', () {
    test('LessThan evaluation', () {
      const rel = LessThan(Variable('x'), RationalNumber.zero);
      check(rel.evaluate({'x': -2.0})).equals(1.0);
      check(rel.evaluate({'x': 0.0})).equals(0.0);
      check(rel.evaluate({'x': 3.0})).equals(0.0);
    });

    test('LessEqual evaluation', () {
      const rel = LessEqual(Variable('x'), RationalNumber.zero);
      check(rel.evaluate({'x': -2.0})).equals(1.0);
      check(rel.evaluate({'x': 0.0})).equals(1.0);
      check(rel.evaluate({'x': 1.0})).equals(0.0);
    });

    test('GreaterThan and GreaterEqual evaluation', () {
      const gt = GreaterThan(Variable('x'), RationalNumber.one);
      const ge = GreaterEqual(Variable('x'), RationalNumber.one);
      check(gt.evaluate({'x': 1.0})).equals(0.0);
      check(gt.evaluate({'x': 1.5})).equals(1.0);
      check(ge.evaluate({'x': 1.0})).equals(1.0);
      check(ge.evaluate({'x': 0.5})).equals(0.0);
    });

    test('Equal evaluation', () {
      const eq = Equal(Variable('x'), RationalNumber(2));
      check(eq.evaluate({'x': 2.0})).equals(1.0);
      check(eq.evaluate({'x': 2.5})).equals(0.0);
    });

    test('relational formatting', () {
      const rel1 = LessThan(Variable('x'), RationalNumber.zero);
      const rel2 = LessEqual(Variable('x'), RationalNumber.zero);
      check(rel1.toString()).equals('x < 0');
      check(rel2.toString()).equals('x <= 0');
      check(rel2.toLatex()).equals('x \\le 0');
    });
  });

  group('Piecewise evaluation & properties', () {
    test('Piecewise branch selection', () {
      const pw = Piecewise([
        (LessThan(Variable('x'), RationalNumber.zero), Neg(Variable('x'))),
        (GreaterEqual(Variable('x'), RationalNumber.zero), Variable('x')),
      ]);

      check(pw.evaluate({'x': -5.0})).equals(5.0);
      check(pw.evaluate({'x': 0.0})).equals(0.0);
      check(pw.evaluate({'x': 7.0})).equals(7.0);
    });

    test('Piecewise fallback to otherwise', () {
      const pw = Piecewise([
        (LessThan(Variable('x'), RationalNumber.zero), RationalNumber(-1)),
      ], otherwise: RationalNumber.one);

      check(pw.evaluate({'x': -3.0})).equals(-1.0);
      check(pw.evaluate({'x': 5.0})).equals(1.0);
    });

    test(
      'Piecewise throws StateError if no branch matches and no otherwise',
      () {
        const pw = Piecewise([
          (LessThan(Variable('x'), RationalNumber.zero), RationalNumber(-1)),
        ]);

        check(() => pw.evaluate({'x': 2.0})).throws<StateError>();
      },
    );

    test('Piecewise substitution and dependencies', () {
      const pw = Piecewise([
        (
          LessThan(Variable('x'), RationalNumber.zero),
          Add(Variable('x'), Variable('y')),
        ),
      ], otherwise: Mul(Variable('x'), Variable('z')));

      check(pw.dependsOn('x')).isTrue();
      check(pw.dependsOn('y')).isTrue();
      check(pw.dependsOn('z')).isTrue();
      check(pw.freeVariables).unorderedEquals({'x', 'y', 'z'});

      final sub = pw.substitute('x', const Variable('u'));
      check(sub.dependsOn('u')).isTrue();
      check(sub.dependsOn('x')).isFalse();
    });

    test('Piecewise formatting and LaTeX', () {
      const pw = Piecewise([
        (LessThan(Variable('x'), RationalNumber.zero), RationalNumber(-1)),
      ], otherwise: RationalNumber.one);

      check(pw.toString()).contains('Piecewise');
      check(pw.toLatex()).contains(r'\begin{cases}');
    });
  });
}
