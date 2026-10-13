import '../../linear/matrix.dart';
import '../../linear/vector.dart';
import '../algebra/simplify.dart';
import '../ast.dart';
import '../calculus/differentiation.dart';
import '../type/expr_data_type.dart';
import 'bareiss.dart';
import 'faddeev_leverrier.dart';

/// Linear algebra and calculus extensions on symbolic [Matrix].
extension SymbolicMatrixExtension on Matrix<Expr> {
  /// Computes the exact symbolic determinant of this square matrix using the
  /// Bareiss fraction-free algorithm:
  ///
  /// $$\det(A) = (-1)^\sigma M_{n, n}^{(n-1)}$$
  ///
  /// Throws [ArgumentError] if the matrix is not square.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final m = Matrix<Expr>.fromRows([
  ///   [x, const RationalNumber(1)],
  ///   [const RationalNumber(2), x],
  /// ], type: exprDataType);
  /// print(m.determinant()); // x^2 - 2
  /// ```
  Expr determinant() => const BareissEngine().determinant(this);

  /// Computes the characteristic polynomial $p(\lambda) = \det(\lambda I - A)$
  /// of this square matrix using the [FaddeevLeVerrierEngine]:
  ///
  /// $$p(\lambda) = \lambda^n - \sum_{k=1}^n c_k \lambda^{n-k}$$
  ///
  /// Throws [ArgumentError] if the matrix is not square.
  ///
  /// ```dart
  /// final a = Matrix<Expr>.fromRows([
  ///   [const RationalNumber(2), const RationalNumber(1)],
  ///   [RationalNumber.zero, const RationalNumber(3)],
  /// ], type: exprDataType);
  /// print(a.characteristicPolynomial('lambda')); // lambda^2 - 5*lambda + 6
  /// ```
  Expr characteristicPolynomial([String lambda = 'lambda']) =>
      const FaddeevLeVerrierEngine().characteristicPolynomial(this, lambda);

  /// Computes the exact symbolic multiplicative inverse of this square matrix,
  /// or returns `null` if the matrix is singular ($\det(A) = 0$):
  ///
  /// $$A^{-1} = \frac{1}{c_n} B_{n-1}$$
  ///
  /// Throws [ArgumentError] if the matrix is not square.
  ///
  /// ```dart
  /// final a = Matrix<Expr>.fromRows([
  ///   [const RationalNumber(2), RationalNumber.zero],
  ///   [RationalNumber.zero, const RationalNumber(4)],
  /// ], type: exprDataType);
  /// final inv = a.inverse();
  /// // inv[0][0] == 1/2, inv[1][1] == 1/4
  /// ```
  Matrix<Expr>? inverse() => const FaddeevLeVerrierEngine().inverse(this);

  /// Computes the element-wise partial derivative of this matrix with respect
  /// to [variable]:
  ///
  /// $$\frac{\partial A}{\partial x} = \left\[\frac{\partial A_{ij}}{\partial x}\right\]$$
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final m = Matrix<Expr>.fromRows([
  ///   [x * x, Sin(x)],
  ///   [const RationalNumber(3) * x, Exp(x)],
  /// ], type: exprDataType);
  /// final dm = m.derivative('x');
  /// // dm[0][0] == 2*x, dm[0][1] == Cos(x)
  /// // dm[1][0] == 3,   dm[1][1] == Exp(x)
  /// ```
  Matrix<Expr> derivative(String variable) => Matrix<Expr>.generate(
    rowCount,
    colCount,
    (r, c) => getUnchecked(r, c).derivative(variable).simplify(),
    type: type is ExprDataType ? type : exprDataType,
  );
}

/// Calculus extensions on symbolic [Vector].
extension SymbolicVectorExtension on Vector<Expr> {
  /// Computes the element-wise partial derivative of this vector with respect
  /// to [variable]:
  ///
  /// $$\frac{\partial v}{\partial x} = \left\[\frac{\partial v_i}{\partial x}\right\]$$
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final v = Vector<Expr>.fromList([x * x, Sin(x)], type: exprDataType);
  /// final dv = v.derivative('x');
  /// // dv[0] == 2*x, dv[1] == Cos(x)
  /// ```
  Vector<Expr> derivative(String variable) => Vector<Expr>.generate(
    length,
    (i) => getUnchecked(i).derivative(variable).simplify(),
    type: type is ExprDataType ? type : exprDataType,
  );
}
