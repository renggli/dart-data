import 'package:more/number.dart';

import 'data_type.dart';
import 'types/object.dart';

/// Derives a fitting [DataType] from [T].
DataType<T> fromType<T>() {
  if (T == int) return DataType.int32 as DataType<T>;
  if (T == double) return DataType.float64 as DataType<T>;
  if (T == bool) return DataType.boolean as DataType<T>;
  if (T == String) return DataType.string as DataType<T>;
  if (T == Complex) return DataType.complex as DataType<T>;
  if (T == Fraction) return DataType.fraction as DataType<T>;
  if (T == BigInt) return DataType.bigInt as DataType<T>;
  if (T == Quaternion) return DataType.quaternion as DataType<T>;
  if (T == dynamic) return DataType.dynamicType as DataType<T>;
  return ObjectDataType<T>(null as T);
}

/// Derives a fitting [DataType] from [instance].
DataType<T> fromInstance<T>(T instance) {
  if (T == int) return DataType.int32 as DataType<T>;
  if (T == double) return DataType.float64 as DataType<T>;
  if (T == bool) return DataType.boolean as DataType<T>;
  if (T == String) return DataType.string as DataType<T>;
  if (T == Complex) return DataType.complex as DataType<T>;
  if (T == Fraction) return DataType.fraction as DataType<T>;
  if (T == BigInt) return DataType.bigInt as DataType<T>;
  if (T == Quaternion) return DataType.quaternion as DataType<T>;
  if (instance is int) return DataType.int32 as DataType<T>;
  if (instance is double) return DataType.float64 as DataType<T>;
  if (instance is bool) return DataType.boolean as DataType<T>;
  if (instance is String) return DataType.string as DataType<T>;
  if (instance is Complex) {
    return DataType.complex as DataType<T>;
  }
  if (instance is Fraction) {
    return DataType.fraction as DataType<T>;
  }
  if (instance is BigInt) return DataType.bigInt as DataType<T>;
  if (instance is Quaternion) {
    return DataType.quaternion as DataType<T>;
  }
  return ObjectDataType<T>(instance);
}

/// Derives a fitting [DataType] from an [iterable].
DataType<T> fromIterable<T>(Iterable<T> iterable) {
  if (T == int) return DataType.int32 as DataType<T>;
  if (T == double) return DataType.float64 as DataType<T>;
  if (iterable.isNotEmpty) {
    return fromInstance<T>(iterable.first);
  }
  return fromType<T>();
}
