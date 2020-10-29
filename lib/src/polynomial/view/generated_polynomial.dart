import '../../../type.dart';
import '../../shared/storage.dart';
import '../mixin/unmodifiable_polynomial.dart';
import '../polynomial.dart';

/// Callback to generate a value in [GeneratedPolynomial].
typedef PolynomialGeneratorCallback<T> = T Function(int exponent);

/// Read-only polynomial generated from a callback.
class GeneratedPolynomial<T>
    with Polynomial<T>, UnmodifiablePolynomialMixin<T> {
  final PolynomialGeneratorCallback<T> callback;

  GeneratedPolynomial(this.dataType, this.degree, this.callback);

  @override
  final DataType<T> dataType;

  @override
  final int degree;

  @override
  Set<Storage> get storage => {this};

  @override
  Polynomial<T> copy() => this;

  @override
  T getUnchecked(int exponent) =>
      exponent <= degree ? callback(exponent) : dataType.field.additiveIdentity;
}
