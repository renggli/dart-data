import 'dart:math' as math;

import 'integer.dart';
import 'type.dart';

/// Finds the most specific data type for the provided values.
DataType findDataType(Iterable values) {
  if (values.isEmpty) {
    return DataType.object;
  }

  var nullCount = 0;
  var boolCount = 0;
  var stringCount = 0;
  var intCount = 0;
  var doubleCount = 0;
  num minValue = double.infinity;
  num maxValue = double.negativeInfinity;

  for (var value in values) {
    if (value == null) {
      nullCount++;
    } else if (value is bool) {
      boolCount++;
    } else if (value is String) {
      stringCount++;
    } else if (value is num) {
      minValue = math.min(minValue, value);
      maxValue = math.max(maxValue, value);
      if (value is int) {
        intCount++;
      } else if (value is double) {
        doubleCount++;
      }
    } else {
      return DataType.object;
    }
  }

  DataType resolve() {
    if (boolCount > 0 &&
        stringCount == 0 &&
        intCount == 0 &&
        doubleCount == 0) {
      return DataType.boolean;
    } else if (boolCount == 0 &&
        stringCount > 0 &&
        intCount == 0 &&
        doubleCount == 0) {
      return DataType.string;
    } else if (boolCount == 0 &&
        stringCount == 0 &&
        intCount > 0 &&
        doubleCount == 0) {
      for (var dataType in _intDataTypes) {
        if (dataType.min <= minValue &&
            minValue <= dataType.max &&
            dataType.min <= maxValue &&
            maxValue <= dataType.max) {
          return dataType;
        }
      }
      return DataType.numeric;
    } else if (boolCount == 0 &&
        stringCount == 0 &&
        intCount == 0 &&
        doubleCount > 0) {
      return DataType.float64;
    } else if (boolCount == 0 &&
        stringCount == 0 &&
        intCount > 0 &&
        doubleCount > 0) {
      return DataType.numeric;
    } else {
      return DataType.object;
    }
  }

  return nullCount == 0 ? resolve() : resolve().nullable;
}

const List<IntegerDataType> _intDataTypes = [
  DataType.uint8,
  DataType.int8,
  DataType.uint16,
  DataType.int16,
  DataType.uint32,
  DataType.int32,
  DataType.uint64,
  DataType.int64,
];
