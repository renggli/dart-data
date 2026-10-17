import 'package:checks/checks.dart';
import 'package:data/src/symbolic/algebra/simplify/additive.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Additive simplification (simplifyAdd and simplifySub)', () {
    test('handles empty, single-element, and numeric pair additions', () {
      const x = Variable('x');
      const y = Variable('y');

      check(simplifyAdd(const [])).equals(IntegerNumber.zero);
      check(simplifyAdd([x])).equals(x);
      check(simplifyAdd([IntegerNumber.two, IntegerNumber.of(3)]))
          .equals(IntegerNumber.of(5));

      // Single element that is itself an unsimplified Add or negated Add
      check(
        simplifyAdd([
          Add([x, x]),
        ]).toString(),
      ).equals('2 * x');
      check(
        simplifyAdd([
          Mul([
            IntegerNumber.negativeOne,
            Add([x, y]),
          ]),
        ]).toString(),
      ).equals('-x - y');
    });

    test('simplifies subtraction across numbers and symbolic sums', () {
      const x = Variable('x');
      check(simplifySub(IntegerNumber.of(7), IntegerNumber.of(2)))
          .equals(IntegerNumber.of(5));
      check(simplifySub(Add([x, IntegerNumber.one]), x))
          .equals(IntegerNumber.one);
    });
  });

  group('Unary negation simplification (simplifyNeg)', () {
    test(
      'negates numbers, OrderTerms, sums, products, and general expressions',
      () {
        const x = Variable('x');
        const y = Variable('y');

        check(simplifyNeg(IntegerNumber.of(4))).equals(IntegerNumber.of(-4));
        check(simplifyNeg(const OrderTerm('x', 3)))
            .equals(const OrderTerm('x', 3));

        check(simplifyNeg(Add([x, IntegerNumber.of(-2)])).toString())
            .equals('2 - x');

        // Mul with leading -1 and 1 or multiple remaining factors
        check(simplifyNeg(Mul([IntegerNumber.negativeOne, x]))).equals(x);
        check(simplifyNeg(Mul([IntegerNumber.negativeOne, x, y])).toString())
            .equals('x * y');

        // Mul with leading scalar != -1
        check(simplifyNeg(Mul([IntegerNumber.of(3), x])).toString())
            .equals('-3 * x');

        // Mul without leading scalar
        check(simplifyNeg(Mul([x, y])))
            .equals(Mul([IntegerNumber.negativeOne, x, y]));

        // General expression
        check(simplifyNeg(Sin(x)).toString()).equals('-sin(x)');
      },
    );
  });
}
