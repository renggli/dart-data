import '../../linear/matrix.dart';
import '../algebra/expand.dart';
import '../algebra/factor.dart';
import '../algebra/factor/fraction.dart';
import '../algebra/simplify.dart';
import '../ast.dart';
import '../type/expr_data_type.dart';

/// Result record produced by the Faddeev-LeVerrier recurrence algorithm.
class FaddeevLeVerrierResult {
  /// Creates a result record with [coefficients] and auxiliary [bMatrices].
  const new({required this.coefficients, required this.bMatrices});

  /// Recurrence coefficients $c_1, \dots, c_n$.
  final List<Expr> coefficients;

  /// Auxiliary matrices $B_1, \dots, B_{n-1}$ where $B_{k-1} = A_{k-1} - c_{k-1} I$.
  final List<Matrix<Expr>> bMatrices;
}

/// Computational engine for characteristic polynomials and symbolic matrix inverses
/// using the Faddeev-LeVerrier recurrence algorithm.
class FaddeevLeVerrierEngine {
  /// Const constructor.
  const new();

  /// Computes the Faddeev-LeVerrier sequence for square [matrix].
  FaddeevLeVerrierResult compute(Matrix<Expr> matrix) {
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
          var sum = IntegerNumber.zero as Expr;
          for (var m = 0; m < n; m++) {
            final prod =
                matrix.getUnchecked(r, m) * bCurrent.getUnchecked(m, c);
            sum = sum + prod;
          }
          return sum.expand().simplify();
        }, type: effectiveType);

        // tr(A_k)
        var tr = IntegerNumber.zero as Expr;
        for (var i = 0; i < n; i++) {
          tr = tr + ak.getUnchecked(i, i);
        }
        tr = tr.expand().simplify();

        // c_k = (1 / k) * tr(A_k)
        final ck = (tr * RationalNumber(1, k)).expand().simplify();
        coefficients.add(ck);

        // B_k = A_k - c_k * I
        bCurrent = Matrix<Expr>.generate(n, n, (r, c) {
          final akVal = ak.getUnchecked(r, c);
          final val = r == c ? (akVal - ck) : akVal;
          return val.expand().simplify();
        }, type: effectiveType);
        bMatrices.add(bCurrent);
      } else {
        // For k == n, only tr(A_n) = sum_{i,m} A_{im} * (B_{n-1})_{mi} is needed.
        var tr = IntegerNumber.zero as Expr;
        for (var i = 0; i < n; i++) {
          for (var m = 0; m < n; m++) {
            tr = tr + matrix.getUnchecked(i, m) * bCurrent.getUnchecked(m, i);
          }
        }
        tr = tr.expand().simplify();
        final ck = (tr * RationalNumber(1, k)).expand().simplify();
        coefficients.add(ck);
      }
    }

    return FaddeevLeVerrierResult(
      coefficients: coefficients,
      bMatrices: bMatrices,
    );
  }

  /// Computes the characteristic polynomial $p(\lambda) = \det(\lambda I - A)$.
  Expr characteristicPolynomial(
    Matrix<Expr> matrix, [
    String lambda = 'lambda',
  ]) {
    if (!matrix.isSquare) {
      throw ArgumentError(
        'Matrix must be square to compute characteristic polynomial, got '
        '${matrix.rowCount} x ${matrix.colCount}.',
      );
    }

    final n = matrix.rowCount;
    if (n == 0) return IntegerNumber.one;

    final result = compute(matrix);
    final c = result.coefficients;
    final lVar = Variable(lambda);

    var poly = n == 1 ? lVar : Pow(lVar, RationalNumber(n));

    for (var k = 1; k <= n; k++) {
      final ck = c[k - 1];
      if (_isZero(ck)) continue;
      final power = n - k;
      final term = power == 0
          ? ck
          : (power == 1
                ? (ck * lVar)
                : (ck * Pow(lVar, RationalNumber(power))));
      poly = poly - term;
    }

    return poly.expand().simplify();
  }

  /// Computes the exact symbolic inverse of square [matrix], or returns `null`
  /// if [matrix] is singular.
  Matrix<Expr>? inverse(Matrix<Expr> matrix) {
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
      final a00 = matrix.getUnchecked(0, 0).simplify();
      if (_isZero(a00)) return null;
      return Matrix<Expr>.generate(
        1,
        1,
        (r, c) => (IntegerNumber.one / a00).simplify(),
        type: effectiveType,
      );
    }

    final result = compute(matrix);
    final cn = result.coefficients.last;
    if (_isZero(cn)) return null;

    final bnMinus1 = result.bMatrices.last;
    return Matrix<Expr>.generate(n, n, (r, c) {
      final num = bnMinus1.getUnchecked(r, c);
      final direct = (num / cn).simplify();
      final hasNegPow = direct.anyNode(
        (node) =>
            node is Pow &&
            node.exponent is RealNumeric &&
            (node.exponent as RealNumeric).isNegative,
      );
      if (!hasNegPow) return direct;
      return cancelFactoredFraction(
        num.factor(),
        cn.factor(),
      ).expand().simplify();
    }, type: effectiveType);
  }

  static bool _isZero(Expr expr) {
    if (expr is Number && expr.isZero) return true;
    final s = expr.expand().simplify();
    return s is Number && s.isZero;
  }
}
