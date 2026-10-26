import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Indefinite Integral AST node', () {
    test('properties, evaluation, substitution, and equality', () {
      const t = Variable('t');
      const a = Variable('a');
      final indef = Integral(a * t, 't');

      check(indef.isDefinite).isFalse();
      check(indef.evaluate({'a': 1.0, 't': 2.0}).isNaN).isTrue();
      check(indef.freeVariables).unorderedEquals(['a', 't']);
      check(indef.dependsOn('t')).isTrue();
      check(indef.dependsOn('a')).isTrue();
      check(indef.dependsOn('z')).isFalse();
      check(indef.substitute('a', IntegerNumber.two))
          .equals(Integral(IntegerNumber.two * t, 't'));
      const y = Variable('y');
      check(indef.substitute('t', y)).equals(Integral(a * y, 'y'));
      check(indef.substitute('t', a))
          .equals(Integral(const Variable('a_1') * a, 'a'));
      check(indef.substitute('t', IntegerNumber.two)).equals(indef);
      final alphaRenamed = indef.substitute('a', t);
      check(alphaRenamed).isA<Integral>();
      check((alphaRenamed as Integral).variable).not((v) => v.equals('t'));
      check(alphaRenamed.dependsOn('t')).isTrue();
      check(indef.mapChildren((e) => e)).equals(indef);
      check(indef.anyNode((e) => e == a)).isTrue();
      check(indef.hashCode).equals(Integral(a * t, 't').hashCode);
    });
  });

  group('Definite Integral AST node', () {
    test('bounds, infinite quadrature, and bound-variable shadowing', () {
      const t = Variable('t');
      const x = Variable('x');
      final defParam = Integral(
        t * x,
        't',
        lower: IntegerNumber.zero,
        upper: x,
      );

      check(defParam.isDefinite).isTrue();
      check(defParam.freeVariables).unorderedEquals(['x']);
      check(defParam.dependsOn('t')).isFalse();
      check(defParam.dependsOn('x')).isTrue();

      final subT = defParam.substitute('t', IntegerNumber.of(5));
      check(subT).equals(defParam);

      final subX = defParam.substitute('x', IntegerNumber.two);
      check(subX).equals(
        Integral(
          t * IntegerNumber.two,
          't',
          lower: IntegerNumber.zero,
          upper: IntegerNumber.two,
        ),
      );

      // Alpha-renaming prevents variable capture when replacement contains bound variable 't'
      final subAlpha =
          defParam.substitute('x', t + IntegerNumber.one) as Integral;
      check(subAlpha.variable).equals('t_1');
      check(subAlpha).equals(
        Integral(
          const Variable('t_1') * (t + IntegerNumber.one),
          't_1',
          lower: IntegerNumber.zero,
          upper: t + IntegerNumber.one,
        ),
      );
      check(defParam.mapChildren((e) => e)).equals(defParam);
      check(defParam.anyNode((e) => e == IntegerNumber.zero)).isTrue();
      check(defParam.anyNode((e) => e == const Variable('z'))).isFalse();

      final sqInt = Integral(
        Pow(t, IntegerNumber.two),
        't',
        lower: IntegerNumber.zero,
        upper: IntegerNumber.of(3),
      );
      check(sqInt.evaluate()).isCloseTo(9.0, 1e-12);

      final revInt = Integral(
        Pow(t, IntegerNumber.two),
        't',
        lower: IntegerNumber.of(3),
        upper: IntegerNumber.zero,
      );
      check(revInt.evaluate()).isCloseTo(-9.0, 1e-12);

      final eqInt = Integral(
        Pow(t, IntegerNumber.two),
        't',
        lower: IntegerNumber.two,
        upper: IntegerNumber.two,
      );
      check(eqInt.evaluate()).equals(0.0);

      final nanInt = Integral(
        t,
        't',
        lower: Constant.undefined,
        upper: IntegerNumber.one,
      );
      check(nanInt.evaluate().isNaN).isTrue();

      final semiPos = Integral(
        Pow(Constant.e, -t),
        't',
        lower: IntegerNumber.zero,
        upper: Constant.infinity,
      );
      check(semiPos.evaluate()).isCloseTo(1.0, 1e-5);

      final semiNeg = Integral(
        Pow(Constant.e, t),
        't',
        lower: -Constant.infinity,
        upper: IntegerNumber.zero,
      );
      check(semiNeg.evaluate()).isCloseTo(1.0, 1e-5);

      final fullInf = Integral(
        Pow(Constant.e, -Pow(t, IntegerNumber.two)),
        't',
        lower: -Constant.infinity,
        upper: Constant.infinity,
      );
      check(fullInf.evaluate()).isCloseTo(math.sqrt(math.pi), 1e-3);
    });
  });
}
