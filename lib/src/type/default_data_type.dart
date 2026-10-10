import 'dart:async';

import 'buffers/native_buffer.dart';
import 'data_type.dart';
import 'types/float.dart';
import 'types/integer.dart';

/// Default data types for index, integer, and floating point arithmetic.
abstract final class DefaultDataType {
  /// Default data type to index collections, rows, columns, etc.
  static const IntegerDataType index = DataType.uint32;

  /// Default data type for integer arithmetic.
  static IntegerDataType get integer =>
      Zone.current[_defaultIntegerZoneKey] as IntegerDataType? ??
      DataType.int32;

  /// Default data type for floating point arithmetic.
  static FloatDataType get float =>
      Zone.current[_defaultFloatZoneKey] as FloatDataType? ?? DataType.float64;

  /// Whether default containers should be allocated off-heap natively.
  static bool get isNative {
    final zoneNative = Zone.current[_defaultNativeZoneKey] as bool?;
    if (zoneNative != null) return zoneNative;
    return NativeBuffer.isActive;
  }

  /// Runs [computation] in a [Zone] configured with default data types and
  /// storage preferences.
  ///
  /// ```dart
  /// DefaultDataType.withDefault(() {
  ///   // Float operations use float32 in this zone
  /// }, float: DataType.float32, native: true);
  /// ```
  static R withDefault<R>(
    R Function() computation, {
    IntegerDataType? integer,
    FloatDataType? float,
    bool? native,
  }) {
    final zoneValues = <Symbol, Object?>{};
    if (integer != null) zoneValues[_defaultIntegerZoneKey] = integer;
    if (float != null) zoneValues[_defaultFloatZoneKey] = float;
    if (native != null) zoneValues[_defaultNativeZoneKey] = native;
    return runZoned(
      computation,
      zoneValues: zoneValues.isEmpty ? null : zoneValues,
    );
  }
}

const Symbol _defaultFloatZoneKey = #data_default_float;
const Symbol _defaultIntegerZoneKey = #data_default_integer;
const Symbol _defaultNativeZoneKey = #data_default_native;
