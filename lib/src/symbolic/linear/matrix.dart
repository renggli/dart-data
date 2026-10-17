import '../../linear/matrix.dart';
import '../../linear/vector.dart';
import '../algebra/approximate.dart';
import '../algebra/expand.dart';
import '../algebra/factor.dart';
import '../algebra/simplify.dart';
import '../ast.dart';
import '../calculus/differentiation.dart';
import '../calculus/integration.dart';
import '../textualization/latex.dart';
import '../textualization/mathml.dart';
import '../textualization/string.dart';
import '../type/expr_data_type.dart';
import 'bareiss.dart';
import 'faddeev_leverrier.dart';

/// Linear algebra, element-wise algebra, calculus, and textualization
/// extensions on symbolic [Matrix].
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
  ///   [x, IntegerNumber.one],
  ///   [IntegerNumber.two, x],
  /// ], type: exprDataType);
  /// print(m.determinant()); // -2 + x^2
  /// ```
  Expr determinant() => const BareissEngine().determinant(this);

  /// Computes the characteristic polynomial $p(\lambda) = \det(\lambda I - A)$
  /// of this square matrix using the Faddeev–LeVerrier algorithm:
  ///
  /// $$p(\lambda) = \lambda^n - \sum_{k=1}^n c_k \lambda^{n-k}$$
  ///
  /// Throws [ArgumentError] if the matrix is not square.
  ///
  /// ```dart
  /// final a = Matrix<Expr>.fromRows([
  ///   [IntegerNumber.two, IntegerNumber.one],
  ///   [IntegerNumber.zero, IntegerNumber.of(3)],
  /// ], type: exprDataType);
  /// print(a.characteristicPolynomial('lambda')); // 6 - 5 * lambda + lambda^2
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
  ///   [IntegerNumber.two, IntegerNumber.zero],
  ///   [IntegerNumber.zero, IntegerNumber.of(4)],
  /// ], type: exprDataType);
  /// final inv = a.inverse();
  /// // inv[0][0] == 1/2, inv[1][1] == 1/4
  /// ```
  Matrix<Expr>? inverse() => const FaddeevLeVerrierEngine().inverse(this);

  /// Canonically simplifies every entry of this matrix.
  Matrix<Expr> simplify() => _mapEntries((e) => e.simplify());

  /// Expands products and powers in every entry of this matrix.
  Matrix<Expr> expand() => _mapEntries((e) => e.expand());

  /// Factors every entry of this matrix.
  Matrix<Expr> factor() => _mapEntries((e) => e.factor());

  /// Substitutes [replacement] for [variable] in every entry of this matrix.
  Matrix<Expr> substitute(String variable, Expr replacement) =>
      _mapEntries((e) => e.substitute(variable, replacement));

  /// Evaluates closed numeric subtrees in every entry of this matrix.
  Matrix<Expr> approximate([Map<String, Expr> bindings = const {}]) =>
      _mapEntries((e) => e.approximate(bindings));

  /// Converts floating-point literals in every entry to exact rationals.
  Matrix<Expr> rationalize({
    int maxDenominator = 1000000,
    double tolerance = 1e-12,
  }) => _mapEntries(
    (e) => e.rationalize(maxDenominator: maxDenominator, tolerance: tolerance),
  );

  /// Computes the element-wise partial derivative of order [order] of this
  /// matrix with respect to [variable]:
  ///
  /// $$\frac{\partial^n A}{\partial x^n} = \left\[\frac{\partial^n A_{ij}}{\partial x^n}\right\]$$
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final m = Matrix<Expr>.fromRows([
  ///   [x * x, Sin(x)],
  ///   [IntegerNumber.of(3) * x, Pow(Constant.e, x)],
  /// ], type: exprDataType);
  /// final dm = m.derivative('x');
  /// // dm[0][0] == 2*x, dm[0][1] == Cos(x)
  /// // dm[1][0] == 3,   dm[1][1] == e^x
  /// ```
  Matrix<Expr> derivative(String variable, {int order = 1}) =>
      _mapEntries((e) => e.derivative(variable, order: order).simplify());

  /// Computes the element-wise symbolic integral of this matrix with respect
  /// to [variable].
  Matrix<Expr> integrate(String variable, {Object? from, Object? to}) =>
      _mapEntries((e) => e.integrate(variable, from: from, to: to));

  /// Formats this matrix into a canonical literal string `[[a, b], [c, d]]`
  /// compatible with `ExprSyntax.parseMatrix`.
  String format() =>
      '[${[
        for (var r = 0; r < rowCount; r++) '[${[for (var c = 0; c < colCount; c++) formatExpr(getUnchecked(r, c))].join(', ')}]',
      ].join(', ')}]';

  /// Formats this matrix into LaTeX `\begin{bmatrix} ... \end{bmatrix}` syntax.
  String toLatex() =>
      '\\begin{bmatrix} ${[
        for (var r = 0; r < rowCount; r++) [for (var c = 0; c < colCount; c++) getUnchecked(r, c).toLatex()].join(' & '),
      ].join(' \\\\ ')} \\end{bmatrix}';

  /// Formats this matrix into W3C MathML `<mtable>` markup.
  ///
  /// If [display] is `true`, produces `<math display="block">` for block-level
  /// rendering; otherwise produces inline `<math>`. If [root] is `false`,
  /// returns only the inner `<mrow><mo>[</mo><mtable>...</mtable><mo>]</mo></mrow>`
  /// without the enclosing `<math>` tag.
  String toMathMl({bool display = false, bool root = true}) {
    final inner =
        '<mrow><mo>[</mo><mtable>${[
          for (var r = 0; r < rowCount; r++) '<mtr>${[for (var c = 0; c < colCount; c++) '<mtd>${getUnchecked(r, c).toMathMl(root: false)}</mtd>'].join()}</mtr>',
        ].join()}</mtable><mo>]</mo></mrow>';
    if (!root) return inner;
    final attr = display ? ' display="block"' : '';
    return '<math$attr>$inner</math>';
  }

  Matrix<Expr> _mapEntries(Expr Function(Expr) transform) =>
      Matrix<Expr>.generate(
        rowCount,
        colCount,
        (r, c) => transform(getUnchecked(r, c)),
        type: type is ExprDataType ? type : exprDataType,
      );
}

/// Element-wise algebra, calculus, and textualization extensions on symbolic [Vector].
extension SymbolicVectorExtension on Vector<Expr> {
  /// Canonically simplifies every entry of this vector.
  Vector<Expr> simplify() => _mapEntries((e) => e.simplify());

  /// Expands products and powers in every entry of this vector.
  Vector<Expr> expand() => _mapEntries((e) => e.expand());

  /// Factors every entry of this vector.
  Vector<Expr> factor() => _mapEntries((e) => e.factor());

  /// Substitutes [replacement] for [variable] in every entry of this vector.
  Vector<Expr> substitute(String variable, Expr replacement) =>
      _mapEntries((e) => e.substitute(variable, replacement));

  /// Evaluates closed numeric subtrees in every entry of this vector.
  Vector<Expr> approximate([Map<String, Expr> bindings = const {}]) =>
      _mapEntries((e) => e.approximate(bindings));

  /// Converts floating-point literals in every entry to exact rationals.
  Vector<Expr> rationalize({
    int maxDenominator = 1000000,
    double tolerance = 1e-12,
  }) => _mapEntries(
    (e) => e.rationalize(maxDenominator: maxDenominator, tolerance: tolerance),
  );

  /// Computes the element-wise partial derivative of order [order] of this
  /// vector with respect to [variable]:
  ///
  /// $$\frac{\partial^n v}{\partial x^n} = \left\[\frac{\partial^n v_i}{\partial x^n}\right\]$$
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final v = Vector<Expr>.fromList([x * x, Sin(x)], type: exprDataType);
  /// final dv = v.derivative('x');
  /// // dv[0] == 2*x, dv[1] == Cos(x)
  /// ```
  Vector<Expr> derivative(String variable, {int order = 1}) =>
      _mapEntries((e) => e.derivative(variable, order: order).simplify());

  /// Computes the element-wise symbolic integral of this vector with respect
  /// to [variable].
  Vector<Expr> integrate(String variable, {Object? from, Object? to}) =>
      _mapEntries((e) => e.integrate(variable, from: from, to: to));

  /// Formats this vector into a canonical literal string `[a, b, c]`
  /// compatible with `ExprSyntax.parseVector`.
  String format() =>
      '[${[for (var i = 0; i < length; i++) formatExpr(getUnchecked(i))].join(', ')}]';

  /// Formats this vector into a column vector in LaTeX `\begin{bmatrix} ... \end{bmatrix}` syntax.
  String toLatex() =>
      '\\begin{bmatrix} ${[for (var i = 0; i < length; i++) getUnchecked(i).toLatex()].join(' \\\\ ')} \\end{bmatrix}';

  /// Formats this vector into a column vector in W3C MathML `<mtable>` markup.
  ///
  /// If [display] is `true`, produces `<math display="block">` for block-level
  /// rendering; otherwise produces inline `<math>`. If [root] is `false`,
  /// returns only the inner `<mrow><mo>[</mo><mtable>...</mtable><mo>]</mo></mrow>`
  /// without the enclosing `<math>` tag.
  String toMathMl({bool display = false, bool root = true}) {
    final inner =
        '<mrow><mo>[</mo><mtable>${[for (var i = 0; i < length; i++) '<mtr><mtd>${getUnchecked(i).toMathMl(root: false)}</mtd></mtr>'].join()}</mtable><mo>]</mo></mrow>';
    if (!root) return inner;
    final attr = display ? ' display="block"' : '';
    return '<math$attr>$inner</math>';
  }

  Vector<Expr> _mapEntries(Expr Function(Expr) transform) =>
      Vector<Expr>.generate(
        length,
        (i) => transform(getUnchecked(i)),
        type: type is ExprDataType ? type : exprDataType,
      );
}
