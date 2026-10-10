import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:more/functional.dart';

import '../buffers/native_buffer.dart';
import '../data_type.dart';
import '../default_data_type.dart';

abstract class TypedDataType<T, L extends List<T>> extends DataType<T> {
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
    bool? native,
  }) {
    final useNative = (native ?? DefaultDataType.isNative) && isNative;
    final result = useNative
        ? (NativeBuffer<T>(length, type: this).data as L)
        : emptyList(length);
    if (generate != null) {
      for (var i = 0; i < length; i++) {
        result[i] = generate(i);
      }
    } else if (fillValue != null && fillValue != defaultValue) {
      result.fillRange(0, length, fillValue);
    }
    if (readonly) {
      final unmod = readonlyList(result);
      final nb = NativeBuffer.find(result);
      if (nb != null) NativeBuffer.register(unmod, nb);
      return unmod;
    }
    return result;
  }

  @override
  L copyList(
    Iterable<T> iterable, {
    int? length,
    T? fillValue,
    bool readonly = false,
    bool? native,
  }) {
    final listLength = iterable.length;
    final result = newList(
      length ?? listLength,
      fillValue: fillValue ?? defaultValue,
      native: native,
    );
    result.setRange(0, math.min(result.length, listLength), iterable);
    if (readonly) {
      final unmod = readonlyList(result);
      final nb = NativeBuffer.find(result);
      if (nb != null) NativeBuffer.register(unmod, nb);
      return unmod;
    }
    return result;
  }

  /// Internal method to create an empty typed-list of the requested [length].
  @protected
  L emptyList(int length);

  /// Internal method to make the typed-list read-only.
  @protected
  L readonlyList(L list);
}
