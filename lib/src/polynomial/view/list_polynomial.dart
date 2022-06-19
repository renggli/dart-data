import '../../../type.dart';
import '../impl/external_polynomial.dart';
import '../polynomial.dart';
import '../polynomial_format.dart';

extension ListPolynomialExtension<T> on List<T> {
  /// Converts this list to a corresponding polynomial.
  ///
  /// If [format] is provided the list data will be copied into a native format,
  /// otherwise a view onto the (possibly mutable) underlying list will be
  /// returned.
  Polynomial<T> toPolynomial(
      {DataType<T>? dataType, PolynomialFormat? format}) {
    dataType ??= DataType.fromType<T>();
    return format == null
        ? ExternalPolynomial<T>.fromList(dataType, this)
        : Polynomial.fromList(dataType, this, format: format);
  }
}
