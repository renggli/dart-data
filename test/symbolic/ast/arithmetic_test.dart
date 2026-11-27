import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Add and Mul n-ary operators', () {
    test('flatten operands, canonicalize deterministically, and support AST traversals', () {
      const x = Variable('x');
      const y = Variable('y');
      const z = Variable('z');

      final sum = x + y - z + 1;
      check(sum).isA<Add>();
      final terms = (sum as Add).terms;
      check(terms.length).equals(4);
      check(sum.evaluate({'x': 1.0, 'y': 2.0, 'z': 0.5})).equals(3.5);
      check(sum.mapChildren((e) => e)).equals(sum);
      check(sum.anyNode((e) => e == z)).isTrue;
      check(sum.anyNode((e) => e == const Variable('w'))).isFalse;
      check(sum == Add.of([x, y])).isFalse;
      check(sum == Add.of([x, y, -z, IntegerNumber.two])).isFalse;

      final prod = x * y / z;
      check(prod).isA<Mul>();
      final factors = (prod as Mul).factors;
      check(factors.length).equals(3);
      check(prod.evaluate({'x': 3.0, 'y': 4.0, 'z': 2.0})).equals(6.0);
      check(prod.mapChildren((e) => e)).equals(prod);
      check(prod.anyNode((e) => e == z)).isTrue;
      check(prod.anyNode((e) => e == const Variable('w'))).isFalse;
      check(prod == Mul.of([x, y])).isFalse;
      check(prod == Mul.of([x, y, z])).isFalse;
    });
  });

  group('Pow binary operator', () {
    test(
      'evaluation with e, sqrt, odd roots of negative bases, and mapChildren',
      () {
        const x = Variable('x');
        check(Pow.of(Constant.e, IntegerNumber.one).evaluate())
            .isCloseTo(math.e, 1e-15);
        check(Pow.of(x, FractionNumber.half).evaluate({'x': 9.0})).equals(3.0);
        check(Pow.of(x, FractionNumber.third).evaluate({'x': -8.0}))
            .isCloseTo(-2.0, 1e-15);
        check(Pow.of(x, RationalNumber(2, 3)).evaluate({'x': -8.0}))
            .isCloseTo(4.0, 1e-15);
        check(Pow.of(x, IntegerNumber.two).substitute('x', IntegerNumber.of(3)))
            .equals(IntegerNumber.of(9));
        check(Pow.of(x, IntegerNumber.two).mapChildren((e) => e))
            .equals(Pow.of(x, IntegerNumber.two));
        check(
          Pow.of(x, IntegerNumber.two).anyNode((e) => e == IntegerNumber.two),
        ).isTrue;
      },
    );

    test(
      'defers negative-rational fractional power folding to simplification',
      () {
        final pow13 = Pow.of(IntegerNumber.negativeOne, FractionNumber.third);
        final pow23 = Pow.of(IntegerNumber.negativeOne, RationalNumber(2, 3));
        final powNeg8 = Pow.of(IntegerNumber.of(-8), FractionNumber.third);

        check(pow13).isA<Pow>();
        check(pow23).isA<Pow>();
        check(powNeg8).isA<Pow>();

        check(pow13.simplify()).equals(IntegerNumber.negativeOne);
        check(pow23.simplify()).equals(IntegerNumber.one);
        check(powNeg8.simplify()).equals(IntegerNumber.of(-2));

        const complexAssumptions = Assumptions(
          defaultDomain: VariableDomain.complex,
        );
        check(pow13.simplify(assumptions: complexAssumptions)).equals(pow13);
        check(pow23.simplify(assumptions: complexAssumptions)).equals(pow23);
        check(powNeg8.simplify(assumptions: complexAssumptions))
            .equals(Mul.of([IntegerNumber.two, pow13]));

        final z = pow13.evaluateComplex();
        check(z.a.toDouble()).isCloseTo(0.5, 1e-12);
        check(z.b.toDouble()).isCloseTo(math.sqrt(3) / 2, 1e-12);
      },
    );
  });
}
