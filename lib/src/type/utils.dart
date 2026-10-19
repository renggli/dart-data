import 'package:more/number.dart';

import 'data_type.dart';
import 'default_data_type.dart';
import 'types/object.dart';

/// Derives a fitting [DataType] from [T].
DataType<T> fromType<T>() =>
    _fromType(T) as DataType<T>? ?? ObjectDataType<T>(null as T);

/// Derives a fitting [DataType] from [instance].
DataType<T> fromInstance<T>(T instance) {
  final byType = _fromType(T);
  if (byType != null) return byType as DataType<T>;
  if (instance != null) {
    final byInstanceType = _fromType(instance.runtimeType);
    if (byInstanceType != null) return byInstanceType as DataType<T>;
  }
  return ObjectDataType<T>(instance);
}

/// Derives a fitting [DataType] from an [iterable].
DataType<T> fromIterable<T>(Iterable<T> iterable) {
  if (T == int) return DefaultDataType.integer as DataType<T>;
  if (T == double) return DefaultDataType.float as DataType<T>;
  if (iterable.isNotEmpty) {
    return fromInstance<T>(iterable.first);
  }
  return fromType<T>();
}

DataType<Object?>? _fromType(Type type) => switch (type) {
  const (int) => DefaultDataType.integer,
  const (double) => DefaultDataType.float,
  const (bool) => DataType.boolean,
  const (String) => DataType.string,
  const (Complex) => DataType.complex,
  const (Fraction) => DataType.fraction,
  const (BigInt) => DataType.bigInt,
  const (Quaternion) => DataType.quaternion,
  const (dynamic) => DataType.dynamicType,
  _ => null,
};
