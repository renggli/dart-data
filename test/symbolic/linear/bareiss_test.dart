import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('BareissEngine base cases and pivoting', () {
    test('handles 0x0, 1x1, 2x2, non-square error, row swaps, and singular matrices', () {
      const x = Variable('x');
      final m0 = Matrix<Expr>.filled(
        0,
        0,
        IntegerNumber.zero,
        type: exprDataType,
      );
      check(m0.determinant()).equals(IntegerNumber.one);

      final m1 = Matrix<Expr>.fromRows([
        [x + IntegerNumber.two],
      ], type: exprDataType);
      check(m1.determinant()).equals((x + IntegerNumber.two).simplify());

      final m2 = Matrix<Expr>.fromRows([
        [x, IntegerNumber.one],
        [IntegerNumber.two, x],
      ], type: exprDataType);
      check(m2.determinant().toString()).equals('-2 + x ^ 2');

      final rect = Matrix<Expr>.filled(
        2,
        3,
        IntegerNumber.one,
        type: exprDataType,
      );
      check(rect.determinant).throws<ArgumentError>();

      // 3x3 matrix requiring row swap (zero at (0,0))
      final swapMat = Matrix<Expr>.fromRows([
        [IntegerNumber.zero, IntegerNumber.one, IntegerNumber.two],
        [IntegerNumber.one, IntegerNumber.two, IntegerNumber.of(3)],
        [IntegerNumber.of(3), IntegerNumber.of(4), IntegerNumber.of(6)],
      ], type: exprDataType);
      check(swapMat.determinant()).equals(IntegerNumber.negativeOne);

      // 3x3 singular matrix with zero column
      final zeroCol = Matrix<Expr>.fromRows([
        [IntegerNumber.zero, IntegerNumber.one, IntegerNumber.two],
        [IntegerNumber.zero, IntegerNumber.two, IntegerNumber.of(3)],
        [IntegerNumber.zero, IntegerNumber.of(3), IntegerNumber.of(4)],
      ], type: exprDataType);
      check(zeroCol.determinant()).equals(IntegerNumber.zero);
    });
  });

  group('BareissEngine fraction-free division paths (3x3 and 4x4)', () {
    test(
      'divides by 1, -1, numeric, monomial, and factored univariate pivots',
      () {
        const x = Variable('x');
        const y = Variable('y');
        const z = Variable('z');

        // Pivot = -1
        final mNegOne = Matrix<Expr>.fromRows([
          [IntegerNumber.negativeOne, IntegerNumber.two, IntegerNumber.one],
          [IntegerNumber.two, IntegerNumber.of(3), IntegerNumber.of(4)],
          [IntegerNumber.one, IntegerNumber.of(5), IntegerNumber.of(6)],
        ], type: exprDataType);
        check(mNegOne.determinant()).equals(IntegerNumber.of(-7));

        // Pivot = x (monomial division path on multivariate terms)
        final mMonomial = Matrix<Expr>.fromRows([
          [x, y, z],
          [IntegerNumber.one, x + y, z],
          [IntegerNumber.two, y, x + z],
        ], type: exprDataType);
        final expectedMon =
            (x * (x + y) * (x + z) +
                    IntegerNumber.two * y * z +
                    y * z -
                    IntegerNumber.two * z * (x + y) -
                    x * y * z -
                    y * (x + z))
                .expand()
                .simplify();
        check((mMonomial.determinant() - expectedMon).expand().simplify())
            .equals(IntegerNumber.zero);

        // Pivot = x + 1 (univariate factored cancellation path)
        final mFactored = Matrix<Expr>.fromRows([
          [x + IntegerNumber.one, IntegerNumber.two, IntegerNumber.one],
          [IntegerNumber.one, x + IntegerNumber.two, IntegerNumber.one],
          [IntegerNumber.one, IntegerNumber.one, x + IntegerNumber.of(3)],
        ], type: exprDataType);
        check(mFactored.determinant().toString())
            .equals('7 * x + 6 * x ^ 2 + x ^ 3');

        // Pivot = x * (x + 1) (sequential factor division path on multivariate 3x3)
        final pSeq = x * (y + IntegerNumber.one);
        final mSeq = Matrix<Expr>.fromRows([
          [pSeq, y, z],
          [x, y + z, IntegerNumber.one],
          [IntegerNumber.one, z, x + y],
        ], type: exprDataType);
        final expectedSeq =
            (pSeq * ((y + z) * (x + y) - z) -
                    y * (x * (x + y) - IntegerNumber.one) +
                    z * (x * z - (y + z)))
                .expand()
                .simplify();
        check((mSeq.determinant() - expectedSeq).expand().simplify())
            .equals(IntegerNumber.zero);
      },
    );

    test('executes polynomial long division for monic, rational, constant, and symbolic leading coefficients', () {
      const x = Variable('x');
      const y = Variable('y');
      const z = Variable('z');

      for (final pivot in <Expr>[
        x + y + IntegerNumber.one,
        -x + y + IntegerNumber.one,
        IntegerNumber.two * x + IntegerNumber.of(3) * y + IntegerNumber.one,
        Constant.pi * x + Constant.e * y + IntegerNumber.one,
        (y + IntegerNumber.one) * Pow(x, IntegerNumber.two) + z,
        Pow(x + y + IntegerNumber.one, IntegerNumber.two),
      ]) {
        final m = Matrix<Expr>.fromRows([
          [pivot, x + IntegerNumber.one, y + IntegerNumber.one],
          [y, z + IntegerNumber.one, x],
          [z, x, y + IntegerNumber.two],
        ], type: exprDataType);
        final det = m.determinant();
        final expected =
            (pivot *
                        ((z + IntegerNumber.one) * (y + IntegerNumber.two) -
                            x * x) -
                    (x + IntegerNumber.one) *
                        (y * (y + IntegerNumber.two) - x * z) +
                    (y + IntegerNumber.one) *
                        (x * y - z * (z + IntegerNumber.one)))
                .expand()
                .simplify();
        check((det - expected).expand().simplify()).equals(IntegerNumber.zero);
      }

      // 4x4 symbolic matrix exercising multi-step Bareiss elimination
      final m4 = Matrix<Expr>.fromRows([
        [x + y, IntegerNumber.one, IntegerNumber.zero, IntegerNumber.zero],
        [IntegerNumber.one, x + y, IntegerNumber.one, IntegerNumber.zero],
        [IntegerNumber.zero, IntegerNumber.one, x + z, IntegerNumber.one],
        [IntegerNumber.zero, IntegerNumber.zero, IntegerNumber.one, y + z],
      ], type: exprDataType);
      final det4 = m4.determinant();
      check(det4.freeVariables).unorderedEquals({'x', 'y', 'z'});
    });
  });
}
