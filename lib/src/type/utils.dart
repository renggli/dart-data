import 'package:pandas/src/type.dart';
import 'package:pandas/src/type/integer.dart';

import 'dart:math' show min, max;

/// Finds the most specific data type for the provided values.
DataType findDataType(Iterable values) {
  if (values.isEmpty) {
    return DataType.OBJECT;
  }

  int nullCount = 0;
  int boolCount = 0;
  int stringCount = 0;
  int intCount = 0;
  int doubleCount = 0;
  num minValue = double.INFINITY;
  num maxValue = double.NEGATIVE_INFINITY;

  for (var value in values) {
    if (value == null) {
      nullCount++;
    } else if (value is bool) {
      boolCount++;
    } else if (value is String) {
      stringCount++;
    } else if (value is num) {
      minValue = min(minValue, value);
      maxValue = max(maxValue, value);
      if (value is int) {
        intCount++;
      } else if (value is double) {
        doubleCount++;
      }
    } else {
      return DataType.OBJECT;
    }
  }

  DataType resolve() {
    if (boolCount > 0 && stringCount == 0 && intCount == 0 && doubleCount == 0) {
      return DataType.BOOLEAN;
    } else if (boolCount == 0 && stringCount > 0 && intCount == 0 && doubleCount == 0) {
      return DataType.STRING;
    } else if (boolCount == 0 && stringCount == 0 && intCount > 0 && doubleCount == 0) {
      for (var dataType in INTEGER_DATA_TYPES) {
        if (dataType.min <= minValue &&
            minValue <= dataType.max &&
            dataType.min <= maxValue &&
            maxValue <= dataType.max) {
          return dataType;
        }
      }
      return DataType.NUMERIC;
    } else if (boolCount == 0 && stringCount == 0 && intCount == 0 && doubleCount > 0) {
      return DataType.FLOAT_64;
    } else if (boolCount == 0 && stringCount == 0 && intCount > 0 && doubleCount > 0) {
      return DataType.NUMERIC;
    } else {
      return DataType.OBJECT;
    }
  }

  return nullCount == 0 ? resolve() : resolve().nullable;
}

const List<IntegerDataType> INTEGER_DATA_TYPES = const [
  DataType.UINT_8,
  DataType.INT_8,
  DataType.UINT_16,
  DataType.INT_16,
  DataType.UINT_32,
  DataType.INT_32,
  DataType.UINT_64,
  DataType.INT_64,
];
