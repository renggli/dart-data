import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('ExprDataType and ExprField algebraic integration', () {
    test('field identities, casting, and arithmetic operations', () {
      const dt = exprDataType;
      check(dt.name).equals('expr');
      check(dt.defaultValue).equals(IntegerNumber.zero);
      check(dt.field.additiveIdentity).equals(IntegerNumber.zero);
      check(dt.field.multiplicativeIdentity).equals(IntegerNumber.one);

      check(dt.cast(5)).equals(IntegerNumber.of(5));
      check(dt.cast(2.5)).equals(const RealNumber(2.5));
      check(dt.cast('x + 1')).equals(Expr.parse('x + 1'));

      final a = Expr.parse('x + 1');
      final b = Expr.parse('x - 1');
      check(dt.field.add(a, b).toString()).equals('2 * x');
      check(dt.field.sub(a, b)).equals(IntegerNumber.two);
      check(dt.field.mul(a, b).expand().toString()).equals('-1 + x ^ 2');
    });
  });
}
