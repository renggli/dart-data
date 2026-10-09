import 'dart:math' as math;
import 'dart:typed_data';

import 'package:more/number.dart' show Complex, Fraction;

import 'dtype.dart';
import 'equality.dart';
import 'field.dart';

/// Represents a strongly-typed data type with typed memory allocation and operations.
abstract class DataType<T> {
  const new();

  // Static instances
  static const Float64DataType float64 = Float64DataType();
  static const Float32DataType float32 = Float32DataType();
  static const Int32DataType int32 = Int32DataType();
  static const Int64DataType int64 = Int64DataType();
  static const Int16DataType int16 = Int16DataType();
  static const Int8DataType int8 = Int8DataType();
  static const Uint32DataType uint32 = Uint32DataType();
  static const Uint64DataType uint64 = Uint64DataType();
  static const Uint16DataType uint16 = Uint16DataType();
  static const Uint8DataType uint8 = Uint8DataType();
  static const BooleanDataType boolean = BooleanDataType();
  static const StringDataType string = StringDataType();
  static const ComplexDataType complex = ComplexDataType();
  static const FractionDataType fraction = FractionDataType();
  static const BigIntDataType bigInt = BigIntDataType();
  static const ObjectDataType<Object?> objectType = ObjectDataType<Object?>(
    null,
  );

  // Defaults
  static const IntegerDataType index = uint32;
  static const IntegerDataType integer = int32;
  static const FloatDataType float = float64;

  String get name;
  T get defaultValue;
  DType get dType;

  Equality<T> get equality => NaturalEquality<T>();
  Field<T> get field => throw UnsupportedError('Field not supported for $name');
  int comparator(T a, T b) => (a as Comparable).compareTo(b);

  List<T> newList(int length, {T? fillValue, bool readonly = false});

  T cast(dynamic value);

  /// Safe numeric type promotion.
  DataType<Object?> promoteWith(DataType<Object?> other) {
    final self = this as DataType<Object?>;
    if (self == other) return this;
    if (self == DataType.complex || other == DataType.complex) {
      return DataType.complex;
    }
    if (self == DataType.float64 || other == DataType.float64) {
      return DataType.float64;
    }
    if (self == DataType.float32) {
      if (other is IntegerDataType) return DataType.float64;
      return DataType.float32;
    }
    if (other == DataType.float32) {
      if (self is IntegerDataType) return DataType.float64;
      return DataType.float32;
    }
    if (self is IntegerDataType && other is IntegerDataType) {
      final maxBits = math.max(self.bits, other.bits);
      final signed = self.isSigned || other.isSigned;
      return switch (maxBits) {
        <= 8 => signed ? DataType.int8 : DataType.uint8,
        <= 16 => signed ? DataType.int16 : DataType.uint16,
        <= 32 => signed ? DataType.int32 : DataType.uint32,
        _ => signed ? DataType.int64 : DataType.uint64,
      };
    }
    return DataType.objectType;
  }

  static DataType<T> fromInstance<T>(T instance) {
    if (instance is double) return DataType.float64 as DataType<T>;
    if (instance is int) return DataType.int32 as DataType<T>;
    if (instance is bool) return DataType.boolean as DataType<T>;
    if (instance is String) return DataType.string as DataType<T>;
    if (instance is Complex) return DataType.complex as DataType<T>;
    if (instance is Fraction) return DataType.fraction as DataType<T>;
    if (instance is BigInt) return DataType.bigInt as DataType<T>;
    return ObjectDataType<T>(instance);
  }

  static DataType<T> fromType<T>() {
    if (T == double) return DataType.float64 as DataType<T>;
    if (T == int) return DataType.int32 as DataType<T>;
    if (T == bool) return DataType.boolean as DataType<T>;
    if (T == String) return DataType.string as DataType<T>;
    if (T == Complex) return DataType.complex as DataType<T>;
    if (T == Fraction) return DataType.fraction as DataType<T>;
    if (T == BigInt) return DataType.bigInt as DataType<T>;
    return ObjectDataType<T>(null as T);
  }

  static DataType<T> fromIterable<T>(Iterable<T> iterable) {
    if (iterable.isNotEmpty) {
      return fromInstance<T>(iterable.first);
    }
    return fromType<T>();
  }

  @override
  String toString() => 'DataType.$name';
}

/// Defaults class for scoped access.
abstract final class DataTypeDefaults {
  static const IntegerDataType index = DataType.uint32;
  static const IntegerDataType integer = DataType.int32;
  static const FloatDataType float = DataType.float64;
}

abstract class FloatDataType extends DataType<double> {
  const new();
  int get bits;
  @override
  double get defaultValue => 0.0;
  @override
  Field<double> get field => const FloatField();
  @override
  Equality<double> get equality => const FloatEquality();
  @override
  int comparator(double a, double b) => a.compareTo(b);
  @override
  double cast(dynamic value) => (value as num).toDouble();
}

class Float64DataType extends FloatDataType {
  const new();
  @override
  String get name => 'float64';
  @override
  int get bits => 64;
  @override
  DType get dType => DType.float64;
  @override
  Float64List newList(int length, {double? fillValue, bool readonly = false}) {
    final list = Float64List(length);
    if (fillValue != null && fillValue != 0.0)
      list.fillRange(0, length, fillValue);
    return list;
  }
}

class Float32DataType extends FloatDataType {
  const new();
  @override
  String get name => 'float32';
  @override
  int get bits => 32;
  @override
  DType get dType => DType.float32;
  @override
  Float32List newList(int length, {double? fillValue, bool readonly = false}) {
    final list = Float32List(length);
    if (fillValue != null && fillValue != 0.0)
      list.fillRange(0, length, fillValue);
    return list;
  }
}

abstract class IntegerDataType extends DataType<int> {
  const new();
  int get bits;
  bool get isSigned;
  @override
  int get defaultValue => 0;
  @override
  Field<int> get field => const IntegerField();
  @override
  int comparator(int a, int b) => a.compareTo(b);
  @override
  int cast(dynamic value) => (value as num).toInt();
}

class Int32DataType extends IntegerDataType {
  const new();
  @override
  String get name => 'int32';
  @override
  int get bits => 32;
  @override
  bool get isSigned => true;
  @override
  DType get dType => DType.int32;
  @override
  Int32List newList(int length, {int? fillValue, bool readonly = false}) {
    final list = Int32List(length);
    if (fillValue != null && fillValue != 0)
      list.fillRange(0, length, fillValue);
    return list;
  }
}

class Int64DataType extends IntegerDataType {
  const new();
  @override
  String get name => 'int64';
  @override
  int get bits => 64;
  @override
  bool get isSigned => true;
  @override
  DType get dType => DType.int64;
  @override
  Int64List newList(int length, {int? fillValue, bool readonly = false}) {
    final list = Int64List(length);
    if (fillValue != null && fillValue != 0)
      list.fillRange(0, length, fillValue);
    return list;
  }
}

class Int16DataType extends IntegerDataType {
  const new();
  @override
  String get name => 'int16';
  @override
  int get bits => 16;
  @override
  bool get isSigned => true;
  @override
  DType get dType => DType.int16;
  @override
  Int16List newList(int length, {int? fillValue, bool readonly = false}) {
    final list = Int16List(length);
    if (fillValue != null && fillValue != 0)
      list.fillRange(0, length, fillValue);
    return list;
  }
}

class Int8DataType extends IntegerDataType {
  const new();
  @override
  String get name => 'int8';
  @override
  int get bits => 8;
  @override
  bool get isSigned => true;
  @override
  DType get dType => DType.int8;
  @override
  Int8List newList(int length, {int? fillValue, bool readonly = false}) {
    final list = Int8List(length);
    if (fillValue != null && fillValue != 0)
      list.fillRange(0, length, fillValue);
    return list;
  }
}

class Uint8DataType extends IntegerDataType {
  const new();
  @override
  String get name => 'uint8';
  @override
  int get bits => 8;
  @override
  bool get isSigned => false;
  @override
  DType get dType => DType.uint8;
  @override
  Uint8List newList(int length, {int? fillValue, bool readonly = false}) {
    final list = Uint8List(length);
    if (fillValue != null && fillValue != 0)
      list.fillRange(0, length, fillValue);
    return list;
  }
}

class Uint16DataType extends IntegerDataType {
  const new();
  @override
  String get name => 'uint16';
  @override
  int get bits => 16;
  @override
  bool get isSigned => false;
  @override
  DType get dType => DType.uint16;
  @override
  Uint16List newList(int length, {int? fillValue, bool readonly = false}) {
    final list = Uint16List(length);
    if (fillValue != null && fillValue != 0)
      list.fillRange(0, length, fillValue);
    return list;
  }
}

class Uint32DataType extends IntegerDataType {
  const new();
  @override
  String get name => 'uint32';
  @override
  int get bits => 32;
  @override
  bool get isSigned => false;
  @override
  DType get dType => DType.uint32;
  @override
  Uint32List newList(int length, {int? fillValue, bool readonly = false}) {
    final list = Uint32List(length);
    if (fillValue != null && fillValue != 0)
      list.fillRange(0, length, fillValue);
    return list;
  }
}

class Uint64DataType extends IntegerDataType {
  const new();
  @override
  String get name => 'uint64';
  @override
  int get bits => 64;
  @override
  bool get isSigned => false;
  @override
  DType get dType => DType.uint64;
  @override
  Uint64List newList(int length, {int? fillValue, bool readonly = false}) {
    final list = Uint64List(length);
    if (fillValue != null && fillValue != 0)
      list.fillRange(0, length, fillValue);
    return list;
  }
}

class BooleanDataType extends DataType<bool> {
  const new();
  @override
  String get name => 'boolean';
  @override
  bool get defaultValue => false;
  @override
  DType get dType => DType.boolean;
  @override
  List<bool> newList(int length, {bool? fillValue, bool readonly = false}) =>
      List<bool>.filled(length, fillValue ?? false, growable: false);
  @override
  bool cast(dynamic value) => value as bool;
}

class StringDataType extends DataType<String> {
  const new();
  @override
  String get name => 'string';
  @override
  String get defaultValue => '';
  @override
  DType get dType => DType.string;
  @override
  List<String> newList(
    int length, {
    String? fillValue,
    bool readonly = false,
  }) => List<String>.filled(length, fillValue ?? '', growable: false);
  @override
  String cast(dynamic value) => value.toString();
}

class ComplexDataType extends DataType<Complex> {
  const new();
  @override
  String get name => 'complex';
  @override
  Complex get defaultValue => Complex.zero;
  @override
  DType get dType => DType.complex128;
  @override
  Field<Complex> get field => const ComplexField();
  @override
  List<Complex> newList(
    int length, {
    Complex? fillValue,
    bool readonly = false,
  }) =>
      List<Complex>.filled(length, fillValue ?? Complex.zero, growable: false);
  @override
  Complex cast(dynamic value) =>
      value is Complex ? value : Complex((value as num).toDouble());
}

class FractionDataType extends DataType<Fraction> {
  const new();
  @override
  String get name => 'fraction';
  @override
  Fraction get defaultValue => Fraction.zero;
  @override
  DType get dType => DType.object;
  @override
  Field<Fraction> get field => const FractionField();
  @override
  List<Fraction> newList(
    int length, {
    Fraction? fillValue,
    bool readonly = false,
  }) => List<Fraction>.filled(
    length,
    fillValue ?? Fraction.zero,
    growable: false,
  );
  @override
  Fraction cast(dynamic value) =>
      value is Fraction ? value : Fraction((value as num).toInt());
}

class BigIntDataType extends DataType<BigInt> {
  const new();
  @override
  String get name => 'bigInt';
  @override
  BigInt get defaultValue => BigInt.zero;
  @override
  DType get dType => DType.object;
  @override
  Field<BigInt> get field => const BigIntField();
  @override
  List<BigInt> newList(
    int length, {
    BigInt? fillValue,
    bool readonly = false,
  }) => List<BigInt>.filled(length, fillValue ?? BigInt.zero, growable: false);
  @override
  BigInt cast(dynamic value) =>
      value is BigInt ? value : BigInt.from(value as num);
}

class ObjectDataType<T> extends DataType<T> {
  const new(this.defaultValue);
  @override
  final T defaultValue;
  @override
  String get name => 'object';
  @override
  DType get dType => DType.object;
  @override
  List<T> newList(int length, {T? fillValue, bool readonly = false}) =>
      List<T>.filled(length, fillValue ?? defaultValue, growable: false);
  @override
  T cast(dynamic value) => value as T;
}
