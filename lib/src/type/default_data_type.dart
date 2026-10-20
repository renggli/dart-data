import 'dart:async';

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

  /// Runs [computation] in a [Zone] configured with default data types.
  ///
  /// ```dart
  /// DefaultDataType.withDefault(() {
  ///   // Float operations use float32 in this zone
  /// }, float: DataType.float32);
  /// ```
  static R withDefault<R>(
    R Function() computation, {
    IntegerDataType? integer,
    FloatDataType? float,
  }) {
    final zoneValues = <Symbol, Object?>{};
    if (integer != null) zoneValues[_defaultIntegerZoneKey] = integer;
    if (float != null) zoneValues[_defaultFloatZoneKey] = float;
    return runZoned(
      computation,
      zoneValues: zoneValues.isEmpty ? null : zoneValues,
    );
  }
}

const Symbol _defaultFloatZoneKey = #data_default_float;
const Symbol _defaultIntegerZoneKey = #data_default_integer;
