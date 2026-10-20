import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  const k = Variable('k');
  const n = Variable('n');

  group('Sum AST node', () {
    test('attributes, free variables, and dependencies', () {
      final sum = Sum(k * k, 'k', IntegerNumber.one, n);
      check(sum.variable).equals('k');
      check(sum.lower).equals(IntegerNumber.one);
      check(sum.upper).equals(n);
      check(sum.freeVariables).unorderedEquals(['n']);
      check(sum.dependsOn('n')).isTrue();
      check(sum.dependsOn('k')).isFalse();
      check(sum.dependsOn('x')).isFalse();
    });

    test('anyNode traversal', () {
      final sum = Sum(k * k, 'k', IntegerNumber.one, n);
      check(sum.anyNode((e) => e == n)).isTrue();
      check(sum.anyNode((e) => e == IntegerNumber.one)).isTrue();
      check(sum.anyNode((e) => e == const Variable('nonexistent'))).isFalse();
    });

    test('copyWith, substitute, and mapChildren', () {
      final sum = Sum(k, 'k', IntegerNumber.one, n);
      final copiedDefault = sum.copyWith();
      check(copiedDefault).equals(sum);

      final copied = sum.copyWith(
        expr: k * k,
        variable: 'j',
        lower: IntegerNumber.zero,
        upper: n + IntegerNumber.one,
        isSimplified: true,
      );
      check(copied.variable).equals('j');
      check(copied.lower).equals(IntegerNumber.zero);
      check(copied.isSimplified).isTrue();

      // Substitution of upper bound
      final substituted = sum.substitute('n', IntegerNumber.of(10)) as Sum;
      check(substituted.upper).equals(IntegerNumber.of(10));

      // Map children
      final mapped = sum.mapChildren((e) => e + IntegerNumber.one) as Sum;
      check(mapped.lower).equals(IntegerNumber.one + IntegerNumber.one);
    });

    test('equality and hashCode', () {
      final s1 = Sum(k, 'k', IntegerNumber.one, n);
      final s2 = Sum(k, 'k', IntegerNumber.one, n);
      final s3 = Sum(k * k, 'k', IntegerNumber.one, n);
      check(s1).equals(s2);
      check(s1.hashCode).equals(s2.hashCode);
      check(s1 == s3).isFalse();
    });
  });

  group('Product AST node', () {
    test('attributes, free variables, and dependencies', () {
      final prod = Product(k, 'k', IntegerNumber.one, n);
      check(prod.variable).equals('k');
      check(prod.lower).equals(IntegerNumber.one);
      check(prod.upper).equals(n);
      check(prod.freeVariables).unorderedEquals(['n']);
      check(prod.dependsOn('n')).isTrue();
      check(prod.dependsOn('k')).isFalse();
    });

    test('anyNode traversal', () {
      final prod = Product(k, 'k', IntegerNumber.one, n);
      check(prod.anyNode((e) => e == n)).isTrue();
      check(prod.anyNode((e) => e == IntegerNumber.one)).isTrue();
      check(prod.anyNode((e) => e == const Variable('nonexistent'))).isFalse();
    });

    test('copyWith, substitute, and mapChildren', () {
      final prod = Product(k, 'k', IntegerNumber.one, n);
      final copiedDefault = prod.copyWith();
      check(copiedDefault).equals(prod);

      final copied = prod.copyWith(
        expr: k * IntegerNumber.two,
        variable: 'm',
        lower: IntegerNumber.two,
        upper: n + IntegerNumber.two,
        isSimplified: true,
      );
      check(copied.variable).equals('m');
      check(copied.lower).equals(IntegerNumber.two);
      check(copied.isSimplified).isTrue();

      final substituted = prod.substitute('n', IntegerNumber.of(20)) as Product;
      check(substituted.upper).equals(IntegerNumber.of(20));

      final mapped = prod.mapChildren((e) => e * IntegerNumber.two) as Product;
      check(mapped.lower).equals(IntegerNumber.one * IntegerNumber.two);
    });

    test('equality and hashCode', () {
      final p1 = Product(k, 'k', IntegerNumber.one, n);
      final p2 = Product(k, 'k', IntegerNumber.one, n);
      final p3 = Product(k * k, 'k', IntegerNumber.one, n);
      check(p1).equals(p2);
      check(p1.hashCode).equals(p2.hashCode);
      check(p1 == p3).isFalse();
    });
  });
}
