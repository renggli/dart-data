import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Affine linear form extraction', () {
    test(
      'matches affine expressions a * x + b and rejects non-linear terms',
      () {
        final lin1 = Expr.parse('3 * x - 7').matchLinear('x');
        check(lin1).isNotNull();
        check(lin1!.a).equals(IntegerNumber.of(3));
        check(lin1.b).equals(IntegerNumber.of(-7));

        final lin2 = Expr.parse('(2 * x + y) / 5').matchLinear('x');
        check(lin2).isNotNull();
        check(lin2!.a).equals(RationalNumber(2, 5));
        check(lin2.b.simplify()).equals((const Variable('y') / 5).simplify());

        check(Expr.parse('x^2 + 1').matchLinear('x')).isNull();
        check(Expr.parse('sin(x)').matchLinear('x')).isNull();
      },
    );
  });
}
