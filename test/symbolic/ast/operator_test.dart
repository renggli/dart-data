import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Add and Mul n-ary operators', () {
    test('flatten unsimplified operands, preserve order, and support AST traversals', () {
      const x = Variable('x');
      const y = Variable('y');
      const z = Variable('z');

      final sum = x + y - z + 1;
      check(sum).isA<Add>();
      final terms = (sum as Add).terms;
      check(terms.length).equals(4);
      check(sum.evaluate({'x': 1.0, 'y': 2.0, 'z': 0.5})).equals(3.5);
      check(sum.mapChildren((e) => e)).equals(sum);
      check(sum.anyNode((e) => e == z)).isTrue();
      check(sum.anyNode((e) => e == const Variable('w'))).isFalse();
      check(sum == Add([x, y])).isFalse();
      check(sum == Add([x, y, -z, IntegerNumber.two])).isFalse();

      final prod = x * y / z;
      check(prod).isA<Mul>();
      final factors = (prod as Mul).factors;
      check(factors.length).equals(3);
      check(prod.evaluate({'x': 3.0, 'y': 4.0, 'z': 2.0})).equals(6.0);
      check(prod.mapChildren((e) => e)).equals(prod);
      check(prod.anyNode((e) => e == z)).isTrue();
      check(prod.anyNode((e) => e == const Variable('w'))).isFalse();
      check(prod == Mul([x, y])).isFalse();
      check(prod == Mul([x, y, z])).isFalse();
    });
  });

  group('Pow binary operator', () {
    test(
      'evaluation with e, sqrt, odd roots of negative bases, and mapChildren',
      () {
        const x = Variable('x');
        check(Pow(Constant.e, IntegerNumber.one).evaluate())
            .isCloseTo(math.e, 1e-15);
        check(Pow(x, FractionNumber.half).evaluate({'x': 9.0})).equals(3.0);
        check(Pow(x, FractionNumber.third).evaluate({'x': -8.0}))
            .isCloseTo(-2.0, 1e-15);
        check(Pow(x, RationalNumber(2, 3)).evaluate({'x': -8.0}))
            .isCloseTo(4.0, 1e-15);
        check(Pow(x, IntegerNumber.two).substitute('x', IntegerNumber.of(3)))
            .equals(Pow(IntegerNumber.of(3), IntegerNumber.two));
        check(Pow(x, IntegerNumber.two).mapChildren((e) => e))
            .equals(Pow(x, IntegerNumber.two));
        check(Pow(x, IntegerNumber.two).anyNode((e) => e == IntegerNumber.two))
            .isTrue();
      },
    );
  });
}
