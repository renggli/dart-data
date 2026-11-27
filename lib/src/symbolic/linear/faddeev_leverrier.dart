import '../../linear/matrix.dart';
import '../algebra/expand.dart';
import '../algebra/factor.dart';
import '../algebra/factor/fraction.dart';
import '../algebra/rational.dart';
import '../algebra/simplify.dart';
import '../assumptions.dart';
import '../ast.dart';
import '../type/expr_data_type.dart';

/// Result record produced by the Faddeev-LeVerrier recurrence algorithm.
class FaddeevLeVerrierResult {
  /// Creates a result record with [coefficients] and auxiliary [bMatrices].
  const new({required this.coefficients, required this.bMatrices});

  /// Recurrence coefficients `c_1, ..., c_n`.
  final List<Expr> coefficients;

  /// Auxiliary matrices `B_1, ..., B_{n-1}` where `B_{k-1} = A_{k-1} - c_{k-1} * I`.
  final List<Matrix<Expr>> bMatrices;
}

/// Computational engine for characteristic polynomials and symbolic matrix inverses
/// using the Faddeev-LeVerrier recurrence algorithm.
class FaddeevLeVerrierEngine {
  /// Const constructor.
  const new();

  /// Computes the Faddeev-LeVerrier sequence for square [matrix].
  FaddeevLeVerrierResult compute(
    Matrix<Expr> matrix, {
    Assumptions assumptions = Assumptions.none,
  }) {
    if (!matrix.isSquare) {
      throw ArgumentError(
        'Matrix must be square, got ${matrix.rowCount} x ${matrix.colCount}.',
      );
    }

    final n = matrix.rowCount;
    if (n == 0) {
      return const FaddeevLeVerrierResult(coefficients: [], bMatrices: []);
    }

    final effectiveType = matrix.type is ExprDataType
        ? matrix.type
        : exprDataType;
    final coefficients = <Expr>[];
    final bMatrices = <Matrix<Expr>>[];

    // B_0 = I_n
    var bCurrent = Matrix<Expr>.identity(n, type: effectiveType);

    for (var k = 1; k <= n; k++) {
      if (k < n) {
        // A_k = A * B_{k-1}
        final ak = Matrix<Expr>.generate(n, n, (r, c) {
          Expr sum = IntegerNumber.zero;
          for (var m = 0; m < n; m++) {
            final aRm = matrix.getUnchecked(r, m);
            if (aRm is Number && aRm.isZero) continue;
            final bMc = bCurrent.getUnchecked(m, c);
            if (bMc is Number && bMc.isZero) continue;
            sum = sum + aRm * bMc;
          }
          return sum.expand().simplify(assumptions: assumptions);
        }, type: effectiveType);

        // tr(A_k)
        Expr tr = IntegerNumber.zero;
        for (var i = 0; i < n; i++) {
          final diag = ak.getUnchecked(i, i);
          if (diag is Number && diag.isZero) continue;
          tr = tr + diag;
        }
        tr = tr.expand().simplify(assumptions: assumptions);

        // c_k = (1 / k) * tr(A_k)
        final ck = (tr * RationalNumber(1, k)).expand().simplify(
          assumptions: assumptions,
        );
        coefficients.add(ck);

        // B_k = A_k - c_k * I
        bCurrent = Matrix<Expr>.generate(n, n, (r, c) {
          final akVal = ak.getUnchecked(r, c);
          if (r != c) return akVal;
          return (akVal - ck).expand().simplify(assumptions: assumptions);
        }, type: effectiveType);
        bMatrices.add(bCurrent);
      } else {
        // For k == n, only tr(A_n) = sum_{i,m} A_{im} * (B_{n-1})_{mi} is needed.
        Expr tr = IntegerNumber.zero;
        for (var i = 0; i < n; i++) {
          for (var m = 0; m < n; m++) {
            final aIm = matrix.getUnchecked(i, m);
            if (aIm is Number && aIm.isZero) continue;
            final bMi = bCurrent.getUnchecked(m, i);
            if (bMi is Number && bMi.isZero) continue;
            tr = tr + aIm * bMi;
          }
        }
        tr = tr.expand().simplify(assumptions: assumptions);
        final ck = (tr * RationalNumber(1, k)).expand().simplify(
          assumptions: assumptions,
        );
        coefficients.add(ck);
      }
    }

    return FaddeevLeVerrierResult(
      coefficients: coefficients,
      bMatrices: bMatrices,
    );
  }

  /// Computes the characteristic polynomial `p(lambda) = det(lambda * I - A)`.
  Expr characteristicPolynomial(
    Matrix<Expr> matrix, {
    String lambda = 'lambda',
    Assumptions assumptions = Assumptions.none,
  }) {
    if (!matrix.isSquare) {
      throw ArgumentError(
        'Matrix must be square to compute characteristic polynomial, got '
        '${matrix.rowCount} x ${matrix.colCount}.',
      );
    }

    final n = matrix.rowCount;
    if (n == 0) return IntegerNumber.one;

    final result = compute(matrix, assumptions: assumptions);
    final c = result.coefficients;
    final lVar = Variable(lambda);

    var poly = n == 1 ? lVar : Pow.of(lVar, RationalNumber(n));

    for (var k = 1; k <= n; k++) {
      final ck = c[k - 1];
      if (isZeroExpr(ck)) continue;
      final power = n - k;
      final term = power == 0
          ? ck
          : (power == 1
                ? (ck * lVar)
                : (ck * Pow.of(lVar, RationalNumber(power))));
      poly = poly - term;
    }

    return poly.expand().simplify(assumptions: assumptions);
  }

  /// Computes the exact symbolic inverse of square [matrix], or returns `null`
  /// if [matrix] is singular.
  Matrix<Expr>? inverse(
    Matrix<Expr> matrix, {
    Assumptions assumptions = Assumptions.none,
  }) {
    if (!matrix.isSquare) {
      throw ArgumentError(
        'Matrix must be square to compute inverse, got '
        '${matrix.rowCount} x ${matrix.colCount}.',
      );
    }

    final n = matrix.rowCount;
    final effectiveType = matrix.type is ExprDataType
        ? matrix.type
        : exprDataType;
    if (n == 0) {
      return Matrix<Expr>.filled(0, 0, IntegerNumber.zero, type: effectiveType);
    }
    if (n == 1) {
      final a00 = matrix
          .getUnchecked(0, 0)
          .together(assumptions: assumptions)
          .simplify(assumptions: assumptions);
      if (isZeroExpr(a00)) return null;
      return Matrix<Expr>.generate(
        1,
        1,
        (r, c) => (IntegerNumber.one / a00).simplify(assumptions: assumptions),
        type: effectiveType,
      );
    }

    final result = compute(matrix, assumptions: assumptions);
    final cn = result.coefficients.last
        .together(assumptions: assumptions)
        .simplify(assumptions: assumptions);
    if (isZeroExpr(cn)) return null;

    final bnMinus1 = result.bMatrices.last;
    final factoredCn = cn.factor(assumptions: assumptions);
    return Matrix<Expr>.generate(n, n, (r, c) {
      final num = bnMinus1.getUnchecked(r, c);
      if (isZeroExpr(num)) return IntegerNumber.zero;
      final direct = (num / cn).simplify(assumptions: assumptions);
      final hasNegPow = direct.anyNode(
        (node) => switch (node) {
          Pow(exponent: RealNumeric(isNegative: true)) => true,
          _ => false,
        },
      );
      if (!hasNegPow) return direct;
      return cancelFactoredFraction(
        num.factor(assumptions: assumptions),
        factoredCn,
      ).expand().simplify(assumptions: assumptions);
    }, type: effectiveType);
  }
}
