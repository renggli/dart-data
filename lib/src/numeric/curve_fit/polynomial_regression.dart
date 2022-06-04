import '../../../matrix.dart';
import '../../../polynomial.dart';
import '../../../vector.dart';
import '../../shared/config.dart';
import '../curve_fit.dart';

/// Polynomial least-squares regression, in which the relationship between the
/// independent variable `x` and the dependent variable `y` is modelled as a
/// polynomial of a given [degree].
///
/// See https://en.wikipedia.org/wiki/Polynomial_regression.
class PolynomialRegression extends CurveFit<Polynomial<double>> {
  /// Constructs a polynomial least-squares regression model.
  PolynomialRegression({required this.degree}) {
    RangeError.checkNotNegative(degree, 'degree');
  }

  /// The desired degree of the fitted polynomial.
  final int degree;

  @override
  PolynomialRegressionResult fit({
    required Vector<double> x,
    required Vector<double> y,
  }) {
    if (x.count != y.count) {
      throw ArgumentError.value(y, 'y', 'Expected ${x.count} values.');
    }
    final vandermonde = Matrix.vandermonde(floatDataType, x, degree + 1);
    final vandermondeTransposed = vandermonde.transposed;
    final result = vandermondeTransposed
        .mulMatrix(vandermonde)
        .inverse
        .mulMatrix(vandermondeTransposed)
        .mulVector(y);
    return PolynomialRegressionResult(result.toList().toPolynomial());
  }
}

class PolynomialRegressionResult extends CurveFitResult {
  PolynomialRegressionResult(this.polynomial) : super(polynomial);

  final Polynomial<double> polynomial;
}
