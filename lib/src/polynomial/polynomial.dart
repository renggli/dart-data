library data.polynomial.polynomial;

import 'dart:collection' show ListMixin;

import 'package:data/src/polynomial/builder.dart';
import 'package:data/src/polynomial/format.dart';
import 'package:data/src/polynomial/view/differentiate_polynomial.dart';
import 'package:data/src/polynomial/view/integrate_polynomial.dart';
import 'package:data/src/polynomial/view/shift_polynomial.dart';
import 'package:data/src/polynomial/view/unmodifiable_polynomial.dart';
import 'package:data/tensor.dart' show Tensor;
import 'package:data/type.dart' show DataType;
import 'package:meta/meta.dart';
import 'package:more/printer.dart' show Printer;

/// Abstract polynomial type.
abstract class Polynomial<T> extends Tensor<T> {
  /// Default builder for new polynomials.
  static Builder<Object> get builder =>
      Builder<Object>(Format.standard, DataType.object);

  /// Unnamed default constructor.
  Polynomial();

  /// Returns the degree this polynomial, that is the highest coefficient.
  int get degree;

  /// Returns the shape of this polynomial.
  @override
  List<int> get shape => [degree + 1];

  /// Returns a copy of this polynomial.
  @override
  Polynomial<T> copy();

  /// Returns the leading term of this polynomial.
  T get lead => degree >= 0 ? getUnchecked(degree) : zeroCoefficient;

  /// Returns the coefficient at the provided [exponent].
  @override
  T operator [](int exponent) {
    RangeError.checkNotNegative(exponent, 'exponent');
    return getUnchecked(exponent);
  }

  /// Returns the coefficient at the provided [exponent]. The behavior is
  /// undefined if [exponent] is outside of bounds.
  T getUnchecked(int exponent);

  /// Sets the coefficient at the provided [exponent] to [value].
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
      return zeroCoefficient;
    }
    final mul = dataType.field.mul, add = dataType.field.add;
    var sum = getUnchecked(exponent);
    while (--exponent >= 0) {
      sum = add(mul(sum, value), getUnchecked(exponent));
    }
    return sum;
  }

  /// Returns a mutable view of this polynomial shift by [offset].
  Polynomial<T> shift(int offset) =>
      offset == 0 ? this : ShiftPolynomial(this, offset);

  /// Returns a mutable view of the differentiate of this polynomial.
  Polynomial<T> get differentiate => DifferentiatePolynomial<T>(this);

  /// Returns a mutable view of the integrate of this polynomial.
  Polynomial<T> get integrate => IntegratePolynomial<T>(this);

  /// Returns a unmodifiable view of this polynomial.
  Polynomial<T> get unmodifiable => UnmodifiablePolynomial<T>(this);

  /// Returns a list iterable over the polynomial.
  List<T> get iterable => _PolynomialList<T>(this);

  /// Internal method that returns the zero coefficient.
  @protected
  T get zeroCoefficient => dataType.field.additiveIdentity;

  /// Internal method that tests for the zero coefficient or null.
  @protected
  bool isZeroCoefficient(T value) =>
      dataType.nullValue == value || zeroCoefficient == value;

  /// Returns a human readable representation of the polynomial.
  @override
  String format({
    bool limit = true,
    int leadingItems = 3,
    int trailingItems = 3,
    Printer ellipsesPrinter,
    Printer paddingPrinter,
    Printer valuePrinter, // additional options
    String addition = ' + ',
    String ellipses = '\u2026',
    String multiplication = ' ',
    String power = '^',
    String variable = 'x',
    bool skipNulls = true,
    bool skipValues = true,
  }) {
    ellipsesPrinter ??= Printer.standard();
    paddingPrinter ??= Printer.standard();
    valuePrinter ??= dataType.printer;

    String coefficientPrinter(int exponent, T coefficient) {
      if (skipNulls && isZeroCoefficient(coefficient)) {
        return null;
      }
      final buffer = StringBuffer();
      final skipValue = skipValues &&
          exponent != 0 &&
          coefficient == dataType.field.multiplicativeIdentity;
      if (!skipValue) {
        buffer.write(valuePrinter(coefficient));
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
      return paddingPrinter(valuePrinter(zeroCoefficient));
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
}

class _PolynomialList<T> extends ListMixin<T> {
  final Polynomial<T> polynomial;

  _PolynomialList(this.polynomial);

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
