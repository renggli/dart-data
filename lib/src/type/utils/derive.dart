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
    var hasNull = _isNullableType<T>();
    DataType<Object?>? candidate;
    for (final element in iterable) {
      if (element == null) {
        hasNull = true;
        continue;
      }
      final elemType =
          _fromType(element.runtimeType) ?? ObjectDataType<Object?>(element);
      if (candidate == null) {
        candidate = elemType;
      } else if (candidate != elemType) {
        return (hasNull ? DataType.nullableObject<T>() : ObjectDataType<T>())
            as DataType<T>;
      }
    }
    if (candidate != null) {
      return (hasNull ? candidate.nullable : candidate) as DataType<T>;
    }
    return (hasNull ? DataType.nullableObject<T>() : ObjectDataType<T>())
        as DataType<T>;
  }
  if (iterable.isNotEmpty) {
    return fromInstance<T>(iterable.first);
  }
  return fromType<T>();
}

bool _isGeneralType<T>() =>
    T == Object || T == dynamic || _typeOf<T>() == _typeOf<Object?>();

bool _isNullableType<T>() => T != dynamic && null is T;

Type _typeOf<T>() => T;

typedef _NullableInt = int?;
typedef _NullableDouble = double?;
typedef _NullableNum = num?;
typedef _NullableBool = bool?;
typedef _NullableString = String?;
typedef _NullableComplex = Complex?;
typedef _NullableFraction = Fraction?;
typedef _NullableBigInt = BigInt?;
typedef _NullableQuaternion = Quaternion?;

DataType<Object?>? _fromType(Type type) => switch (type) {
  const (int) => DataType.integer,
  const (_NullableInt) => DataType.integer.nullable,
  const (double) => DataType.float,
  const (_NullableDouble) => DataType.float.nullable,
  const (num) => DataType.numeric,
  const (_NullableNum) => DataType.numeric.nullable,
  const (bool) => DataType.boolean,
  const (_NullableBool) => DataType.boolean.nullable,
  const (String) => DataType.string,
  const (_NullableString) => DataType.string.nullable,
  const (Complex) => DataType.complex,
  const (_NullableComplex) => DataType.complex.nullable,
  const (Fraction) => DataType.fraction,
  const (_NullableFraction) => DataType.fraction.nullable,
  const (BigInt) => DataType.bigInt,
  const (_NullableBigInt) => DataType.bigInt.nullable,
  const (Quaternion) => DataType.quaternion,
  const (_NullableQuaternion) => DataType.quaternion.nullable,
  const (dynamic) => DataType.dynamicType,
  _ => null,
};
