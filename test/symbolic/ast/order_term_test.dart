import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('OrderTerm AST construction and traversal', () {
    test(
      'construction, properties, substitution, mapChildren, and equality',
      () {
        const a = Variable('a');
        const u = Variable('u');
        final o3 = OrderTerm('x', 3);
        check(o3.variable).equals('x');
        check(o3.order).equals(3);
        check(o3.point).equals(IntegerNumber.zero);
        check(o3.dependsOn('x')).isTrue;
        check(o3.dependsOn('y')).isFalse;
        check(o3.freeVariables).unorderedEquals(['x']);
        check(o3.evaluate({'x': 2.0})).equals(0.0);
        check(o3.hashCode).equals(OrderTerm('x', 3).hashCode);

        final shifted = OrderTerm('x', 2, point: a);
        check(shifted.point).equals(a);
        check(shifted.dependsOn('a')).isTrue;
        check(shifted.freeVariables).unorderedEquals(['x', 'a']);
        check(shifted.substitute('x', u)).equals(OrderTerm('u', 2, point: a));
        check(shifted.substitute('x', a)).equals(IntegerNumber.zero);
        check(shifted.substitute('x', IntegerNumber.two))
            .equals(IntegerNumber.zero);
        check(OrderTerm('x', 0, point: a).substitute('x', a))
            .equals(Constant.undefined);
        check(
          OrderTerm(
            'x',
            3,
            point: IntegerNumber.one,
          ).substitute('x', const Variable('h') + IntegerNumber.one),
        ).equals(OrderTerm('h', 3));
        check(shifted.substitute('a', IntegerNumber.one))
            .equals(OrderTerm('x', 2, point: IntegerNumber.one));
        check(shifted.mapChildren((_) => IntegerNumber.one))
            .equals(OrderTerm('x', 2, point: IntegerNumber.one));
        check(shifted.anyNode((e) => e == shifted)).isTrue;
        check(shifted.anyNode((e) => e == a)).isTrue;
        check(shifted.anyNode((e) => e == u)).isFalse;
        check(OrderTerm('x', 2, point: IntegerNumber.one).toString())
            .equals('O((x - 1)^2)');
      },
    );

    test('removeOrder strips Landau remainder terms from expressions', () {
      const x = Variable('x');
      final o2 = OrderTerm('x', 2);
      final o3 = OrderTerm('x', 3);

      check(o2.removeOrder()).equals(IntegerNumber.zero);
      check(Add.of([o2, o3]).removeOrder()).equals(IntegerNumber.zero);
      check(Add.of([x, o2]).removeOrder()).equals(x);
      check(Add.of([IntegerNumber.one, x, o2]).removeOrder())
          .equals(Add.of([IntegerNumber.one, x]));
      check(Fn.sin(Add.of([x, o2])).removeOrder()).equals(Fn.sin(x));
    });
  });

  group('OrderTerm asymptotic arithmetic', () {
    test('additive and multiplicative absorption rules', () {
      const x = Variable('x');
      final o2 = OrderTerm('x', 2);
      final o4 = OrderTerm('x', 4);
      final x2 = Pow.of(x, IntegerNumber.two);
      final x3 = Pow.of(x, IntegerNumber.of(3));

      // O(x^2) + O(x^4) -> O(x^2)
      check((o2 + o4).simplify()).equals(o2);

      // 1 + x + x^2 + x^3 + O(x^2) -> 1 + x + O(x^2)
      check((IntegerNumber.one + x + x2 + x3 + o2).simplify())
          .equals(Add.of([IntegerNumber.one, x, o2]));

      // x * O(x^2) -> O(x^3)
      check((x * o2).simplify()).equals(OrderTerm('x', 3));

      // x^2 * O(x^2) -> O(x^4)
      check((x2 * o2).simplify()).equals(o4);

      // O(x^2) * O(x^4) -> O(x^6)
      check((o2 * o4).simplify()).equals(OrderTerm('x', 6));
    });

    test('dependsOn checks variable and point without allocating', () {
      final o = OrderTerm('x', 3);
      check(o.dependsOn('x')).isTrue;
      check(o.dependsOn('y')).isFalse;
      final oPoint = OrderTerm('x', 3, point: const Variable('a'));
      check(oPoint.dependsOn('a')).isTrue;
      check(oPoint.dependsOn('b')).isFalse;
    });
  });
}
