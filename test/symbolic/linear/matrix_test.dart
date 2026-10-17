import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('SymbolicMatrixExtension', () {
    test(
      'computes determinant, characteristicPolynomial, inverse, and derivative',
      () {
        const x = Variable('x');
        final m = Matrix<Expr>.fromRows([
          [x * x, Sin(x)],
          [IntegerNumber.of(3) * x, Pow(Constant.e, x)],
        ], type: exprDataType);
        final dm = m.derivative('x');
        check(dm.get(0, 0).toString()).equals('2 * x');
        check(dm.get(0, 1)).equals(Cos(x));
        check(dm.get(1, 0)).equals(IntegerNumber.of(3));
        check(dm.get(1, 1)).equals(Pow(Constant.e, x, isSimplified: true));

        final a = Matrix<Expr>.fromRows([
          [IntegerNumber.two, IntegerNumber.zero],
          [IntegerNumber.zero, IntegerNumber.of(4)],
        ], type: exprDataType);
        check(a.determinant()).equals(IntegerNumber.of(8));
        check(a.characteristicPolynomial('t').toString())
            .equals('8 - 6 * t + t ^ 2');
        check(a.inverse()!.get(0, 0)).equals(FractionNumber.half);
      },
    );
  });

  group('SymbolicVectorExtension', () {
    test('computes element-wise derivative of Vector<Expr>', () {
      const x = Variable('x');
      final v = Vector<Expr>.fromList([x * x, Sin(x)], type: exprDataType);
      final dv = v.derivative('x');
      check(dv[0].toString()).equals('2 * x');
      check(dv[1]).equals(Cos(x));
    });
  });
}
