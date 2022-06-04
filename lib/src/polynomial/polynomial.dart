import 'dart:collection' show ListMixin;

import 'package:meta/meta.dart';
import 'package:more/printer.dart' show Printer, StandardPrinter;

import '../../type.dart';
import '../shared/storage.dart';
import 'impl/compressed_polynomial.dart';
import 'impl/keyed_polynomial.dart';
import 'impl/list_polynomial.dart';
import 'impl/standard_polynomial.dart';
import 'polynomial_format.dart';
import 'view/generated_polynomial.dart';

/// Abstract polynomial type.
abstract class Polynomial<T> implements Storage {
  /// Constructs a default vector of the desired [dataType], and possibly a
  /// custom [format].
  factory Polynomial(DataType<T> dataType,
      {int desiredDegree = -1, PolynomialFormat? format}) {
    ArgumentError.checkNotNull(dataType, 'dataType');
    switch (format ?? defaultPolynomialFormat) {
      case PolynomialFormat.standard:
        return StandardPolynomial<T>(dataType, desiredDegree);
      case PolynomialFormat.compressed:
        return CompressedPolynomial<T>(dataType);
      case PolynomialFormat.keyed:
        return KeyedPolynomial<T>(dataType);
      case PolynomialFormat.list:
        return ListPolynomial<T>(dataType, desiredDegree);
    }
  }

  /// Generates a polynomial from calling a [callback] on every value. If
  /// [format] is specified the resulting polynomial is mutable, otherwise this
  /// is a read-only view.
  factory Polynomial.generate(
      DataType<T> dataType, int degree, PolynomialGeneratorCallback<T> callback,
      {PolynomialFormat? format}) {
    final result = GeneratedPolynomial<T>(dataType, degree, callback);
    return format == null ? result : result.toPolynomial(format: format);
  }

  /// Constructs a polynomial from a list of coefficients.
  factory Polynomial.fromCoefficients(DataType<T> dataType, List<T> source,
      {PolynomialFormat? format}) {
    final result =
        Polynomial(dataType, desiredDegree: source.length - 1, format: format);
    for (var i = 0; i < source.length; i++) {
      result.setUnchecked(i, source[source.length - i - 1]);
    }
    return result;
  }

  /// Constructs a polynomial from a list of values.
  factory Polynomial.fromList(DataType<T> dataType, List<T> source,
      {PolynomialFormat? format}) {
    final result =
        Polynomial(dataType, desiredDegree: source.length - 1, format: format);
    for (var i = 0; i < source.length; i++) {
      result.setUnchecked(i, source[i]);
    }
    return result;
  }

  /// Builds a polynomial from a list of roots.
  factory Polynomial.fromRoots(DataType<T> dataType, List<T> roots,
      {PolynomialFormat? format}) {
    final result =
        Polynomial(dataType, desiredDegree: roots.length, format: format);
    if (roots.isEmpty) {
      return result;
    }
    result.setUnchecked(0, dataType.field.neg(roots[0]));
    result.setUnchecked(1, dataType.field.multiplicativeIdentity);
    final sub = dataType.field.sub, mul = dataType.field.mul;
    for (var i = 1; i < roots.length; i++) {
      final root = roots[i];
      for (var j = i + 1; j >= 0; j--) {
        result.setUnchecked(
            j,
            sub(
                j > 0
                    ? result.getUnchecked(j - 1)
                    : dataType.field.additiveIdentity,
                mul(root, result.getUnchecked(j))));
      }
    }
    return result;
  }

  /// Returns the data type of this polynomial.
  DataType<T> get dataType;

  /// Returns the degree this polynomial, that is the highest coefficient.
  int get degree;

  /// Returns the shape of this polynomial.
  @override
  List<int> get shape => [degree + 1];

  /// Returns a copy of this polynomial.
  @override
  Polynomial<T> copy();

  /// Creates a new [Polynomial] containing the same elements as this one.
  Polynomial<T> toPolynomial({PolynomialFormat? format}) {
    final result = Polynomial(dataType, desiredDegree: degree, format: format);
    for (var i = degree; i >= 0; i--) {
      result.setUnchecked(i, getUnchecked(i));
    }
    return result;
  }

  /// Returns the leading term of this polynomial.
  T get lead =>
      degree >= 0 ? getUnchecked(degree) : dataType.field.additiveIdentity;

  /// Returns the coefficient at the provided [exponent].
  @nonVirtual
  T operator [](int exponent) {
    RangeError.checkNotNegative(exponent, 'exponent');
    return getUnchecked(exponent);
  }

  /// Returns the coefficient at the provided [exponent]. The behavior is
  /// undefined if [exponent] is outside of bounds.
  T getUnchecked(int exponent);

  /// Sets the coefficient at the provided [exponent] to [value].
  @nonVirtual
  void operator []=(int exponent, T value) {
    RangeError.checkNotNegative(exponent, 'exponent');
    setUnchecked(exponent, value);
  }

  /// Sets the coefficient at the provided [exponent] to [value]. The behavior
  /// is undefined if [exponent] is outside of bounds.
  void setUnchecked(int exponent, T value);

  /// Evaluates the polynomial at [value].
  T call(T value) {
    var exponent = degree;
    if (exponent < 0) {
      return dataType.defaultValue;
    }
    final mul = dataType.field.mul, add = dataType.field.add;
    var sum = getUnchecked(exponent);
    while (--exponent >= 0) {
      sum = add(mul(sum, value), getUnchecked(exponent));
    }
    return sum;
  }

  /// Returns a list iterable over the polynomial.
  List<T> get iterable => _PolynomialList<T>(this);

  /// Iterates over each element of the polynomial from the largest exponent
  /// down to the smallest exponent. This way of iteration is more efficient
  /// on sparse data structure and skips over neutral elements.
  void forEach(void Function(int exponent, T value) callback) {
    final additiveIdentity = dataType.field.additiveIdentity;
    for (var exponent = degree; exponent >= 0; exponent--) {
      final value = getUnchecked(exponent);
      if (value != additiveIdentity) {
        callback(exponent, this[exponent]);
      }
    }
  }

  /// Returns a human readable representation of the polynomial.
  String format({
    bool limit = true,
    int leadingItems = 3,
    int trailingItems = 3,
    Printer<String>? ellipsesPrinter,
    Printer<String>? paddingPrinter,
    Printer<T>? valuePrinter,
    String addition = ' + ',
    String ellipses = '\u2026',
    String multiplication = '',
    String power = '^',
    String variable = 'x',
    bool skipNulls = true,
    bool skipValues = true,
  }) {
    ellipsesPrinter ??= const StandardPrinter<String>();
    paddingPrinter ??= const StandardPrinter<String>();
    valuePrinter ??= dataType.printer;

    String? coefficientPrinter(int exponent, T coefficient) {
      if (skipNulls && dataType.field.additiveIdentity == coefficient) {
        return null;
      }
      final buffer = StringBuffer();
      final skipValue = skipValues &&
          exponent != 0 &&
          coefficient == dataType.field.multiplicativeIdentity;
      if (!skipValue) {
        buffer.write(valuePrinter!(coefficient));
      }
      if (exponent > 0) {
        if (!skipValue) {
          buffer.write(multiplication);
        }
        buffer.write(variable);
        if (exponent > 1) {
          buffer.write(power);
          buffer.write(exponent);
        }
      }
      return buffer.toString();
    }

    final count = degree;
    if (count < 0) {
      return paddingPrinter(valuePrinter(dataType.field.additiveIdentity));
    }
    final parts = <String>[];
    for (var i = count; i >= 0; i--) {
      final part = coefficientPrinter(i, getUnchecked(i));
      if (part != null) {
        parts.add(part);
      }
    }
    final buffer = StringBuffer();
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) {
        buffer.write(addition);
      }
      if (limit && leadingItems <= i && i < count - trailingItems) {
        buffer.write(paddingPrinter(ellipsesPrinter(ellipses)));
        i = count - trailingItems - 1;
      } else {
        buffer.write(paddingPrinter(parts[i]));
      }
    }
    return buffer.toString();
  }

  /// Returns the string representation of this polynomial.
  @override
  String toString() => '$runtimeType('
      'dataType: ${dataType.name}, '
      'degree: $degree):\n'
      '${format()}';
}

class _PolynomialList<T> extends ListMixin<T> {
  _PolynomialList(this.polynomial);

  final Polynomial<T> polynomial;

  @override
  int get length => polynomial.degree + 1;

  @override
  set length(int newLength) =>
      throw UnsupportedError('Unable to change length of polynomial.');

  @override
  T operator [](int index) => polynomial[index];

  @override
  void operator []=(int index, T value) => polynomial[index] = value;
}
