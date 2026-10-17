import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Faddeev-LeVerrier characteristic polynomial and inverse', () {
    test('computes characteristicPolynomial and exact matrix inverse', () {
      final a = Matrix<Expr>.fromRows([
        [IntegerNumber.of(1), IntegerNumber.of(2)],
        [IntegerNumber.of(3), IntegerNumber.of(4)],
      ], type: exprDataType);

      final charPoly = a.characteristicPolynomial('t').simplify();
      check(charPoly.toString()).equals('-2 - 5 * t + t ^ 2');

      final inv = a.inverse();
      check(inv).isNotNull();
      check(inv!.get(0, 0)).equals(IntegerNumber.of(-2));
      check(inv.get(0, 1)).equals(IntegerNumber.one);
      check(inv.get(1, 0)).equals(RationalNumber(3, 2));
      check(inv.get(1, 1)).equals(FractionNumber.negativeHalf);
    });

    test('returns null inverse for singular matrix', () {
      final singular = Matrix<Expr>.fromRows([
        [IntegerNumber.one, IntegerNumber.two],
        [IntegerNumber.two, IntegerNumber.of(4)],
      ], type: exprDataType);
      check(singular.inverse()).isNull();
    });
  });
}
