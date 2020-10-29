import 'dart:math' as math;

import 'package:more/number.dart';

import '../shared/config.dart' as config;
import 'impl/integer.dart';
import 'type.dart';

/// Derives a fitting [DataType] from [T].
DataType<T> fromType<T>() {
  switch (T) {
    case double:
      return config.floatDataType as DataType<T>;
    case int:
      return config.intDataType as DataType<T>;
    case bool:
      return DataType.boolean as DataType<T>;
    case String:
      return DataType.string as DataType<T>;
    case BigInt:
      return DataType.bigInt as DataType<T>;
    case Fraction:
      return DataType.fraction as DataType<T>;
    case Complex:
      return DataType.complex as DataType<T>;
    case Quaternion:
      return DataType.quaternion as DataType<T>;
    default:
      return DataType.object as DataType<T>;
  }
}

/// Derives a fitting [DataType] from [instance].
DataType<T> fromInstance<T>(T instance) => fromType<T>();

/// Derives a fitting [DataType] from an [iterable].
DataType<T> fromIterable<T>(Iterable<T> iterable) {
  // Do a refinement of DataType<int>:
  if (iterable.isNotEmpty && T == int) {
    const integerDataTypes = <IntegerDataType>[
      DataType.uint8,
      DataType.int8,
      DataType.uint16,
      DataType.int16,
      DataType.uint32,
      DataType.int32,
      DataType.uint64,
      DataType.int64,
    ];
    var minValue = 0, maxValue = 0;
    for (final value in iterable.cast<int>()) {
      minValue = math.min(minValue, value);
      maxValue = math.max(maxValue, value);
    }
    for (final dataType in integerDataTypes) {
      if (dataType.safeMin <= minValue &&
          minValue <= dataType.safeMax &&
          dataType.safeMin <= maxValue &&
          maxValue <= dataType.safeMax) {
        return dataType as DataType<T>;
      }
    }
  }
  // Fall back to the default type.
  return fromType<T>();
}
