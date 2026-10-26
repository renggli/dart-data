import 'dart:collection';
import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:more/functional.dart';
import 'package:more/number.dart';
import 'package:more/printer.dart' show Printer, StandardPrinter;

import 'models/equality.dart';
import 'models/field.dart';
import 'types/bigint.dart';
import 'types/boolean.dart';
import 'types/complex.dart';
import 'types/dynamic.dart';
import 'types/float.dart';
import 'types/fraction.dart';
import 'types/integer.dart';
import 'types/nullable.dart';
import 'types/numeric.dart';
import 'types/object.dart';
import 'types/quaternion.dart';
import 'types/string.dart';
import 'utils/derive.dart' as utils;

/// Descriptor of a data type [T], how it is efficiently represented and stored
/// in memory, and strategy of how common operations work.
@immutable
abstract base class DataType<T> {
  /// Abstract const constructor.
  const new();

  /// Object data type.
  static const ObjectDataType<Object?> object = ObjectDataType<Object?>(null);

  /// Creates an object type [T] with the given [defaultValue].
  static ObjectDataType<T> createObject<T>(T defaultValue) =>
      ObjectDataType<T>(defaultValue);

  /// Return a nullable object type [T] with the optional [defaultValue].
  ///
  /// ```dart
  /// final personType = DataType.nullableObject<Person?>();
  /// ```
  static ObjectDataType<T?> nullableObject<T>([T? defaultValue]) =>
      ObjectDataType<T?>(defaultValue);

  /// Dynamic object type that can hold any [Object] or `null`.
  static const DynamicDataType dynamicType = DynamicDataType();

  /// [String] object data type.
  static const StringDataType string = StringDataType();

  /// [num] object data type.
  static const NumericDataType numeric = NumericDataType();

  /// [bool] object data type.
  static const BooleanDataType boolean = BooleanDataType();

  /// Default data type to index collections, rows, columns, etc.
  static const IntegerDataType index = uint32;

  /// Default data type for integer arithmetic.
  static const IntegerDataType integer = int32;

  /// Signed 8-bit [int] data type.
  static const Int8DataType int8 = Int8DataType();

  /// Unsigned 8-bit [int] data type.
  static const Uint8DataType uint8 = Uint8DataType();

  /// Signed 16-bit [int] data type.
  static const Int16DataType int16 = Int16DataType();

  /// Unsigned 16-bit [int] data type.
  static const Uint16DataType uint16 = Uint16DataType();

  /// Signed 32-bit [int] data type.
  static const Int32DataType int32 = Int32DataType();

  /// Unsigned 32-bit [int] data type.
  static const Uint32DataType uint32 = Uint32DataType();

  /// Signed 64-bit [int] data type.
  static const Int64DataType int64 = Int64DataType();

  /// Unsigned 64-bit [int] data type.
  static const Uint64DataType uint64 = Uint64DataType();

  /// Default data type for floating point arithmetic.
  static const FloatDataType float = float64;

  /// 32-bit [double] data type.
  static const Float32DataType float32 = Float32DataType();

  /// 64-bit [double] data type.
  static const Float64DataType float64 = Float64DataType();

  /// [BigInt] object data type.
  static const BigIntDataType bigInt = BigIntDataType();

  /// [Fraction] object data type.
  static const FractionDataType fraction = FractionDataType();

  /// [Complex] object data type.
  static const ComplexDataType complex = ComplexDataType();

  /// [Quaternion] object data type.
  static const QuaternionDataType quaternion = QuaternionDataType();

  /// Derives a fitting [DataType] from [T].
  static DataType<T> fromType<T>() => utils.fromType<T>();

  /// Derives a fitting [DataType] from [instance].
  static DataType<T> fromInstance<T>(T instance) =>
      utils.fromInstance(instance);

  /// Derives a fitting [DataType] from an [iterable].
  static DataType<T> fromIterable<T>(Iterable<T> iterable) =>
      utils.fromIterable(iterable);

  /// Returns the name of this [DataType].
  String get name;

  /// Returns true, if this [DataType] supports `null` values.
  bool get isNullable => false;

  /// The size of an element in bits, or 0 if not fixed size.
  int get bits => 0;

  /// The size of an element in bytes, or 0 if not fixed size.
  int get bytesPerElement => (bits + 7) ~/ 8;

  /// True if this data type has a fixed-size native memory representation.
  bool get isNative => bits > 0;

  /// True if this data type is a floating-point number.
  bool get isFloat => false;

  /// True if this data type is an integer number.
  bool get isInteger => false;

  /// True if this data type is numeric.
  bool get isNumeric => isFloat || isInteger;

  /// True if this data type is signed.
  bool get isSigned => true;

  /// Returns the default value, typically equivalent to the zero or null value.
  T get defaultValue;

  /// Returns a [DataType] that supports `null` values.
  DataType<T?> get nullable =>
      isNullable ? this as DataType<T?> : NullableDataType<T>(this);

  /// Returns an equality relation.
  Equality<T> get equality => NaturalEquality<T>();

  /// Returns a mathematical field, if available.
  Field<T> get field => throw UnsupportedError('No field available for $this.');

  /// Returns a [Comparator] that compares one element to another.
  int comparator(T a, T b) =>
      throw UnsupportedError('No comparator available for $this.');

  /// Casts the argument to this data type, otherwise throw an [ArgumentError].
  T cast(Object? value) => throw ArgumentError.value(
    value,
    'value',
    'Unable to cast "$value" to $this.',
  );

  /// Creates a fixed-length list of this data type.
  List<T> newList(
    int length, {
    Map1<int, T>? generate,
    T? fillValue,
    bool readonly = false,
  }) {
    final result = generate != null
        ? List<T>.generate(length, generate, growable: false)
        : List<T>.filled(length, fillValue ?? defaultValue, growable: false);
    return readonly ? UnmodifiableListView(result) : result;
  }

  /// Creates a fixed-length list copy of the [iterable], possibly with a
  /// modified [length] and if necessary populated with [fillValue].
  List<T> copyList(
    Iterable<T> iterable, {
    int? length,
    T? fillValue,
    bool readonly = false,
  }) {
    final list = iterable is List<T>
        ? iterable
        : iterable.toList(growable: false);
    final listLength = list.length;
    final targetLength = length ?? listLength;
    final List<T> result;
    if (targetLength <= listLength && fillValue == null) {
      result = newList(targetLength, generate: (i) => list[i]);
    } else {
      result = newList(targetLength, fillValue: fillValue ?? defaultValue);
      result.setRange(0, math.min(targetLength, listLength), list);
    }
    return readonly ? UnmodifiableListView<T>(result) : result;
  }

  /// Casts an existing [elements] to this data type.
  List<T> castList(Iterable<Object?> elements) {
    final source = elements is List<Object?>
        ? elements
        : elements.toList(growable: false);
    return newList(source.length, generate: (i) => cast(source[i]));
  }

  /// Returns a default printer for this data type.
  Printer<T> get printer => StandardPrinter<T>();

  /// Promotes this data type with [other] to find a common super-type.
  DataType<Object?> promoteWith(DataType<Object?> other) {
    final self = this as DataType<Object?>;
    if (self == other) return this;
    if (self is NullableDataType<Object?> ||
        other is NullableDataType<Object?>) {
      final baseSelf = self is NullableDataType<Object?> ? self.delegate : self;
      final baseOther = other is NullableDataType<Object?>
          ? other.delegate
          : other;
      return baseSelf.promoteWith(baseOther).nullable;
    }
    bool isAlgebraicNumber(DataType<Object?> t) =>
        t.isNumeric ||
        t == DataType.bigInt ||
        t == DataType.fraction ||
        t == DataType.complex ||
        t == DataType.quaternion;
    if (!isAlgebraicNumber(self) || !isAlgebraicNumber(other)) {
      return DataType.object;
    }
    if (self == DataType.quaternion || other == DataType.quaternion) {
      return DataType.quaternion;
    }
    if (self == DataType.complex || other == DataType.complex) {
      return DataType.complex;
    }
    if (self == DataType.numeric || other == DataType.numeric) {
      return DataType.numeric;
    }
    if (self == DataType.float64 || other == DataType.float64) {
      return DataType.float64;
    }
    if (self == DataType.float32 || other == DataType.float32) {
      return DataType.float64;
    }
    if (self == DataType.fraction || other == DataType.fraction) {
      return DataType.fraction;
    }
    if (self == DataType.bigInt || other == DataType.bigInt) {
      return DataType.bigInt;
    }
    if (self is IntegerDataType && other is IntegerDataType) {
      if (self.isSigned == other.isSigned) {
        final maxBits = math.max(self.bits, other.bits);
        return switch (maxBits) {
          <= 8 => self.isSigned ? DataType.int8 : DataType.uint8,
          <= 16 => self.isSigned ? DataType.int16 : DataType.uint16,
          <= 32 => self.isSigned ? DataType.int32 : DataType.uint32,
          _ => self.isSigned ? DataType.int64 : DataType.uint64,
        };
      }
      final signedBits = self.isSigned ? self.bits : other.bits;
      final unsignedBits = self.isSigned ? other.bits : self.bits;
      if (signedBits > unsignedBits) {
        return switch (signedBits) {
          <= 16 => DataType.int16,
          <= 32 => DataType.int32,
          _ => DataType.int64,
        };
      }
      return switch (unsignedBits) {
        <= 8 => DataType.int16,
        <= 16 => DataType.int32,
        <= 32 => DataType.int64,
        _ => DataType.bigInt,
      };
    }
    return DataType.object;
  }

  @override
  String toString() => 'DataType.$name';
}
