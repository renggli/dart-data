import 'dart:math' as math;

import 'package:more/number.dart';

import 'impl/integer.dart';
import 'type.dart';

/// Derives a fitting [DataType] from [T].
DataType<T> fromType<T>() => switch (T) {
  == bool => DataType.boolean as DataType<T>,
  == double => DataType.float as DataType<T>,
  == int => DataType.integer as DataType<T>,
  == BigInt => DataType.bigInt as DataType<T>,
  == Complex => DataType.complex as DataType<T>,
  == Fraction => DataType.fraction as DataType<T>,
  == Quaternion => DataType.quaternion as DataType<T>,
  == String => DataType.string as DataType<T>,
  _ => DataType.dynamicType as DataType<T>,
};

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
