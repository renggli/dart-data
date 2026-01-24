import '../../../matrix.dart';
import '../../../polynomial.dart';
import '../../../type.dart';
import '../../../vector.dart';
import '../../shared/checks.dart';
import '../curve_fit.dart';

/// Polynomial least-squares regression, in which the relationship between the
/// independent elements `xs` and the dependent elements `ys` is modelled as a
/// polynomial of a given [degree].
///
/// See https://en.wikipedia.org/wiki/Polynomial_regression.
///
/// ```dart
/// final xs = Vector.fromList(DataType.float, [0.0, 1.0, 2.0, 3.0]);
/// final ys = Vector.fromList(DataType.float, [1.0, 3.0, 5.0, 7.0]);
/// final regression = PolynomialRegression(degree: 1);
/// final result = regression.fit(xs: xs, ys: ys);
/// print(result.polynomial);  // 1.0 + 2.0 * x
/// ```
class PolynomialRegression extends CurveFit {
  /// Constructs a polynomial least-squares regression model.
  PolynomialRegression({required this.degree}) {
    RangeError.checkNotNegative(degree, 'degree');
  }

  /// The desired degree of the fitted polynomial.
  final int degree;

  @override
  PolynomialRegressionResult fit({
    required Vector<double> xs,
    required Vector<double> ys,
  }) {
    checkPoints(DataType.float, xs: xs, ys: ys);
    final vandermonde = Matrix.vandermonde(DataType.float, xs, degree + 1);
    final vandermondeTransposed = vandermonde.transposed;
    final result = vandermondeTransposed
        .mulMatrix(vandermonde)
        .inverse
        .mulMatrix(vandermondeTransposed)
        .mulVector(ys);
    return PolynomialRegressionResult(result.toList().toPolynomial());
  }
}

class PolynomialRegressionResult extends CurveFitResult {
  PolynomialRegressionResult(this.polynomial) : super(polynomial.evaluate);

  final Polynomial<double> polynomial;
}
