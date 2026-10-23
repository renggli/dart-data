import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:more/functional.dart';

import '../data_type.dart';

/// Base data type descriptor for fixed-size typed storage lists ([L]).
abstract base class TypedDataType<T, L extends List<T>> extends DataType<T> {
  /// Default constant constructor for [TypedDataType].
  const new();

  /// Returns the size of one value in bits.
  @override
  int get bits;

  /// Returns the minimum finite value of this value.
  T get min;

  /// Returns the maximum finite value of this value.
  T get max;

  @override
  L newList(
    int length, {
    Map1<int, T>? generate,
    T? fillValue,
    bool readonly = false,
  }) {
    final result = emptyList(length);
    if (generate != null) {
      for (var i = 0; i < length; i++) {
        result[i] = generate(i);
      }
    } else if (fillValue != null && fillValue != defaultValue) {
      result.fillRange(0, length, fillValue);
    }
    return readonly ? readonlyList(result) : result;
  }

  @override
  L copyList(
    Iterable<T> iterable, {
    int? length,
    T? fillValue,
    bool readonly = false,
  }) {
    final listLength = iterable.length;
    final result = newList(
      length ?? listLength,
      fillValue: fillValue ?? defaultValue,
    );
    result.setRange(0, math.min(result.length, listLength), iterable);
    return readonly ? readonlyList(result) : result;
  }

  /// Internal method to create an empty typed-list of the requested [length].
  @protected
  L emptyList(int length);

  /// Internal method to make the typed-list read-only.
  @protected
  L readonlyList(L list);
}
