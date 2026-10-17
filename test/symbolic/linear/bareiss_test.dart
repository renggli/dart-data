import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Bareiss fraction-free determinant engine', () {
    test('computes exact determinants for numeric and symbolic matrices', () {
      const x = Variable('x');
      final m2 = Matrix<Expr>.fromRows([
        [x, IntegerNumber.one],
        [IntegerNumber.two, x],
      ], type: exprDataType);
      check(m2.determinant().toString()).equals('-2 + x ^ 2');

      final m3 = Matrix<Expr>.fromRows([
        [IntegerNumber.one, IntegerNumber.two, IntegerNumber.of(3)],
        [IntegerNumber.zero, x, IntegerNumber.of(4)],
        [IntegerNumber.zero, IntegerNumber.zero, x + IntegerNumber.one],
      ], type: exprDataType);
      check((m3.determinant() - x * (x + 1)).expand().simplify())
          .equals(IntegerNumber.zero);
    });
  });
}
