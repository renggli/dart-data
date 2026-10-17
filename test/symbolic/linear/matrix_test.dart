import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('SymbolicMatrixExtension and SymbolicVectorExtension', () {
    test('element-wise derivative of Matrix<Expr> and Vector<Expr>', () {
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

      final v = Vector<Expr>.fromList([x * x, Sin(x)], type: exprDataType);
      final dv = v.derivative('x');
      check(dv[0].toString()).equals('2 * x');
      check(dv[1]).equals(Cos(x));
    });
  });
}
