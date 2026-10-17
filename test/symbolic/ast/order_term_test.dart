import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('OrderTerm AST construction and traversal', () {
    test(
      'construction, properties, substitution, mapChildren, and equality',
      () {
        const a = Variable('a');
        const u = Variable('u');
        const o3 = OrderTerm('x', 3);
        check(o3.variable).equals('x');
        check(o3.order).equals(3);
        check(o3.point).equals(IntegerNumber.zero);
        check(o3.isSimplified).isTrue();
        check(o3.dependsOn('x')).isTrue();
        check(o3.dependsOn('y')).isFalse();
        check(o3.freeVariables).unorderedEquals(['x']);
        check(o3.evaluate({'x': 2.0})).equals(0.0);
        check(o3.hashCode).equals(const OrderTerm('x', 3).hashCode);

        const shifted = OrderTerm('x', 2, point: a);
        check(shifted.point).equals(a);
        check(shifted.dependsOn('a')).isTrue();
        check(shifted.freeVariables).unorderedEquals(['x', 'a']);
        check(shifted.substitute('x', u))
            .equals(const OrderTerm('u', 2, point: a));
        check(shifted.substitute('x', IntegerNumber.two))
            .equals(const OrderTerm('x', 2, point: a));
        check(shifted.substitute('a', IntegerNumber.one))
            .equals(const OrderTerm('x', 2, point: IntegerNumber.one));
        check(shifted.mapChildren((_) => IntegerNumber.one))
            .equals(const OrderTerm('x', 2, point: IntegerNumber.one));
        check(shifted.anyNode((e) => e == shifted)).isTrue();
        check(shifted.anyNode((e) => e == a)).isTrue();
        check(shifted.anyNode((e) => e == u)).isFalse();
        check(const OrderTerm('x', 2, point: IntegerNumber.one).toString())
            .equals('O((x - 1)^2)');
      },
    );

    test('removeOrder strips Landau remainder terms from expressions', () {
      const x = Variable('x');
      const o2 = OrderTerm('x', 2);
      const o3 = OrderTerm('x', 3);

      check(o2.removeOrder()).equals(IntegerNumber.zero);
      check(Add([o2, o3]).removeOrder()).equals(IntegerNumber.zero);
      check(Add([x, o2]).removeOrder()).equals(x);
      check(Add([IntegerNumber.one, x, o2]).removeOrder())
          .equals(Add([IntegerNumber.one, x]));
      check(Sin(Add([x, o2])).removeOrder()).equals(Sin(x));
    });
  });

  group('OrderTerm asymptotic arithmetic', () {
    test('additive and multiplicative absorption rules', () {
      const x = Variable('x');
      const o2 = OrderTerm('x', 2);
      const o4 = OrderTerm('x', 4);
      final x2 = Pow(x, IntegerNumber.two);
      final x3 = Pow(x, IntegerNumber.of(3));

      // O(x^2) + O(x^4) -> O(x^2)
      check((o2 + o4).simplify()).equals(o2);

      // 1 + x + x^2 + x^3 + O(x^2) -> 1 + x + O(x^2)
      check((IntegerNumber.one + x + x2 + x3 + o2).simplify())
          .equals(Add([IntegerNumber.one, x, o2]));

      // x * O(x^2) -> O(x^3)
      check((x * o2).simplify()).equals(const OrderTerm('x', 3));

      // x^2 * O(x^2) -> O(x^4)
      check((x2 * o2).simplify()).equals(o4);

      // O(x^2) * O(x^4) -> O(x^6)
      check((o2 * o4).simplify()).equals(const OrderTerm('x', 6));
    });
  });
}
