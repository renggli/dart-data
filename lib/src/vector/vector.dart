library data.vector.vector;

import 'dart:collection' show ListMixin;

import 'package:data/src/shared/storage.dart';
import 'package:more/printer.dart' show Printer;

import '../../type.dart' show DataType;
import 'builder.dart';
import 'format.dart';

/// Abstract vector type.
abstract class Vector<T> implements Storage {
  /// Default builder for new vectors.
  static Builder<Object> get builder =>
      Builder<Object>(Format.standard, DataType.object);

  /// Unnamed default constructor.
  Vector();

  /// Returns the data type of this vector.
  DataType<T> get dataType;

  /// The dimensionality of this vector.
  int get count;

  /// Returns the shape of this vector.
  @override
  List<int> get shape => [count];

  /// Returns a copy of this vector.
  @override
  Vector<T> copy();

  /// Returns the scalar at the provided [index].
  @override
  T operator [](int index) {
    RangeError.checkValidIndex(index, this, 'index', count);
    return getUnchecked(index);
  }

  /// Returns the scalar at the provided [index]. The behavior is undefined if
  /// [index] is outside of bounds.
  T getUnchecked(int index);

  /// Sets the scalar at the provided [index] to [value].
  void operator []=(int index, T value) {
    RangeError.checkValidIndex(index, this, 'index', count);
    setUnchecked(index, value);
  }

  /// Sets the scalar at the provided [index] to [value]. The behavior is
  /// undefined if [index] is outside of bounds.
  void setUnchecked(int index, T value);

  /// Returns a list iterable over the vector.
  List<T> get iterable => _VectorList<T>(this);

  /// Tests if [index] is within the bounds of this vector.
  bool isWithinBounds(int index) => 0 <= index && index < count;

  /// Returns a human readable representation of the vector.
  @override
  String format({
    Printer valuePrinter,
    Printer paddingPrinter,
    Printer ellipsesPrinter,
    bool limit = true,
    int leadingItems = 3,
    int trailingItems = 3,
    // additional options
    String separator = ' ',
    String ellipses = '\u2026',
  }) {
    final buffer = StringBuffer();
    valuePrinter ??= dataType.printer;
    paddingPrinter ??= Printer.standard();
    ellipsesPrinter ??= Printer.standard();
    for (var i = 0; i < count; i++) {
      if (i > 0) {
        buffer.write(separator);
      }
      if (limit && leadingItems <= i && i < count - trailingItems) {
        buffer.write(paddingPrinter(ellipsesPrinter(ellipses)));
        i = count - trailingItems - 1;
      } else {
        buffer.write(paddingPrinter(valuePrinter(getUnchecked(i))));
      }
    }
    return buffer.toString();
  }
}

class _VectorList<T> extends ListMixin<T> {
  final Vector<T> vector;

  _VectorList(this.vector);

  @override
  int get length => vector.count;

  @override
  set length(int newLength) =>
      throw UnsupportedError('Unable to change length of vector.');

  @override
  T operator [](int index) => vector[index];

  @override
  void operator []=(int index, T value) => vector[index] = value;
}
