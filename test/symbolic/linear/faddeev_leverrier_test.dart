import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/src/symbolic/linear/faddeev_leverrier.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('FaddeevLeVerrierEngine characteristic polynomial', () {
    test('handles 0x0, 1x1, 2x2, 3x3 trace-zero, and non-square error', () {
      const engine = FaddeevLeVerrierEngine();
      final m0 = Matrix<Expr>.filled(
        0,
        0,
        IntegerNumber.zero,
        type: exprDataType,
      );
      check(engine.compute(m0).coefficients).isEmpty();
      check(m0.characteristicPolynomial()).equals(IntegerNumber.one);

      final m1 = Matrix<Expr>.fromRows([
        [IntegerNumber.of(5)],
      ], type: exprDataType);
      check(m1.characteristicPolynomial('t').toString()).equals('-5 + t');

      final a = Matrix<Expr>.fromRows([
        [IntegerNumber.of(1), IntegerNumber.of(2)],
        [IntegerNumber.of(3), IntegerNumber.of(4)],
      ], type: exprDataType);
      check(a.characteristicPolynomial('t').simplify().toString())
          .equals('-2 - 5 * t + t ^ 2');

      // 3x3 matrix with zero trace (c_1 == 0) to exercise _isZero(ck) skip and power > 1
      final m3 = Matrix<Expr>.fromRows([
        [IntegerNumber.one, IntegerNumber.two, IntegerNumber.zero],
        [IntegerNumber.zero, IntegerNumber.negativeOne, IntegerNumber.one],
        [IntegerNumber.one, IntegerNumber.zero, IntegerNumber.zero],
      ], type: exprDataType);
      check(m3.characteristicPolynomial('t').toString())
          .equals('-2 - t + t ^ 3');

      final id3 = Matrix<Expr>.identity(3, type: exprDataType);
      check(id3.characteristicPolynomial('t').toString())
          .equals('-1 + 3 * t - 3 * t ^ 2 + t ^ 3');

      final rect = Matrix<Expr>.filled(
        2,
        3,
        IntegerNumber.one,
        type: exprDataType,
      );
      check(engine.compute.bind(rect)).throws<ArgumentError>();
      check(rect.characteristicPolynomial).throws<ArgumentError>();
    });
  });

  group('FaddeevLeVerrierEngine matrix inverse', () {
    test('computes inverse for 0x0, 1x1, 2x2 numeric and symbolic matrices, and returns null when singular', () {
      final m0 = Matrix<Expr>.filled(
        0,
        0,
        IntegerNumber.zero,
        type: exprDataType,
      );
      check(m0.inverse()!.rowCount).equals(0);

      final m1 = Matrix<Expr>.fromRows([
        [IntegerNumber.two],
      ], type: exprDataType);
      check(m1.inverse()!.get(0, 0)).equals(FractionNumber.half);

      final m1Zero = Matrix<Expr>.fromRows([
        [IntegerNumber.zero],
      ], type: exprDataType);
      check(m1Zero.inverse()).isNull();

      final a = Matrix<Expr>.fromRows([
        [IntegerNumber.of(1), IntegerNumber.of(2)],
        [IntegerNumber.of(3), IntegerNumber.of(4)],
      ], type: exprDataType);
      final inv = a.inverse();
      check(inv).isNotNull();
      check(inv!.get(0, 0)).equals(IntegerNumber.of(-2));
      check(inv.get(0, 1)).equals(IntegerNumber.one);
      check(inv.get(1, 0)).equals(RationalNumber(3, 2));
      check(inv.get(1, 1)).equals(FractionNumber.negativeHalf);

      // Symbolic 2x2 matrix exercising cancelFactoredFraction
      const x = Variable('x');
      final sym = Matrix<Expr>.fromRows([
        [x + IntegerNumber.one, IntegerNumber.zero],
        [IntegerNumber.zero, x + IntegerNumber.two],
      ], type: exprDataType);
      final symInv = sym.inverse();
      check(symInv).isNotNull();
      check(symInv!.get(0, 0).evaluate({'x': 2.0})).isCloseTo(1.0 / 3.0, 1e-12);
      check(symInv.get(1, 1).evaluate({'x': 2.0})).isCloseTo(1.0 / 4.0, 1e-12);

      final singular = Matrix<Expr>.fromRows([
        [IntegerNumber.one, IntegerNumber.two],
        [IntegerNumber.two, IntegerNumber.of(4)],
      ], type: exprDataType);
      check(singular.inverse()).isNull();

      final rect = Matrix<Expr>.filled(
        2,
        3,
        IntegerNumber.one,
        type: exprDataType,
      );
      check(rect.inverse).throws<ArgumentError>();
    });
  });
}

extension on FaddeevLeVerrierResult Function(Matrix<Expr>) {
  FaddeevLeVerrierResult Function() bind(Matrix<Expr> arg) =>
      () => this(arg);
}
