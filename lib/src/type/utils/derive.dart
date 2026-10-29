import 'package:more/number.dart';

import '../data_type.dart';
import '../types/object.dart';

/// Derives a fitting [DataType] from [T].
DataType<T> fromType<T>() =>
    _fromType(T) as DataType<T>? ?? ObjectDataType<T>();

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
  if (T == int) return DataType.integer as DataType<T>;
  if (T == double) return DataType.float as DataType<T>;
  if (_isGeneralType<T>()) {
    DataType<Object?>? candidate;
    for (final element in iterable) {
      if (element == null) {
        if (candidate != null) candidate = candidate.nullable;
        continue;
      }
      final elemType =
          _fromType(element.runtimeType) ?? ObjectDataType<Object?>(element);
      if (candidate == null) {
        candidate = elemType;
      } else if (candidate != elemType) {
        return ObjectDataType<T>();
      }
    }
    if (candidate != null) return candidate as DataType<T>;
    return ObjectDataType<T>();
  }
  if (iterable.isNotEmpty) {
    return fromInstance<T>(iterable.first);
  }
  return fromType<T>();
}

bool _isGeneralType<T>() =>
    T == Object || T == dynamic || _typeOf<T>() == _typeOf<Object?>();

Type _typeOf<T>() => T;

DataType<Object?>? _fromType(Type type) => switch (type) {
  const (int) => DataType.integer,
  const (double) => DataType.float,
  const (num) => DataType.numeric,
  const (bool) => DataType.boolean,
  const (String) => DataType.string,
  const (Complex) => DataType.complex,
  const (Fraction) => DataType.fraction,
  const (BigInt) => DataType.bigInt,
  const (Quaternion) => DataType.quaternion,
  const (dynamic) => DataType.dynamicType,
  _ => null,
};
