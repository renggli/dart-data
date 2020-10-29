import '../../../type.dart';
import '../polynomial.dart';
import '../polynomial_format.dart';
import 'utils.dart';

extension NegExtension<T> on Polynomial<T> {
  /// Negates this [Polynomial].
  Polynomial<T> neg({DataType<T>? dataType, PolynomialFormat? format}) {
    final result = createPolynomial<T>(this, degree, dataType, format);
    unaryOperator<T>(result, this, result.dataType.field.neg);
    return result;
  }

  /// Negates this [Polynomial].
  Polynomial<T> operator -() => neg();
}
