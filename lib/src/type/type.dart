import 'dart:collection';
import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:more/functional.dart';
import 'package:more/number.dart';
import 'package:more/printer.dart' show Printer, StandardPrinter;

import 'impl/bigint.dart';
import 'impl/boolean.dart';
import 'impl/complex.dart';
import 'impl/dynamic.dart';
import 'impl/float.dart';
import 'impl/fraction.dart';
import 'impl/integer.dart';
import 'impl/modulo.dart';
import 'impl/nullable.dart';
import 'impl/numeric.dart';
import 'impl/object.dart';
import 'impl/quaternion.dart';
import 'impl/string.dart';
import 'models/equality.dart';
import 'models/field.dart';
import 'utils.dart' as utils;

/// Descriptor of a data type [T], how it is efficiently represented and stored
/// in memory, and strategy of how common operations work.
@immutable
abstract class DataType<T> {
  /// Abstract const constructor.
  const DataType();

  /// Return an object type [T] with the given [defaultValue].
  static ObjectDataType<T> object<T>(T defaultValue) =>
      ObjectDataType<T>(defaultValue);

  /// Return a nullable object type [T] with the optional [defaultValue].
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

  /// Configurable default data type to index collections, rows, columns, etc.
  static IntegerDataType index = uint32;

  /// Configurable default data type for integer arithmetic.
  static IntegerDataType integer = int32;

  /// Signed 8-bit [int] data type.
  static const IntegerDataType int8 = Int8DataType();

  /// Unsigned 8-bit [int] data type.
  static const IntegerDataType uint8 = Uint8DataType();

  /// Signed 16-bit [int] data type.
  static const IntegerDataType int16 = Int16DataType();

  /// Unsigned 16-bit [int] data type.
  static const IntegerDataType uint16 = Uint16DataType();

  /// Signed 32-bit [int] data type.
  static const IntegerDataType int32 = Int32DataType();

  /// Unsigned 32-bit [int] data type.
  static const IntegerDataType uint32 = Uint32DataType();

  /// Signed 64-bit [int] data type.
  static const IntegerDataType int64 = Int64DataType();

  /// Unsigned 64-bit [int] data type.
  static const IntegerDataType uint64 = Uint64DataType();

  /// Return an modulo data type.
  static ModuloDataType<T> modulo<T>(DataType<T> delegate, T modulus) =>
      ModuloDataType<T>(delegate, modulus);

  /// Configurable default data type for floating point arithmetic.
  static FloatDataType float = float64;

  /// 32-bit [double] data type.
  static const FloatDataType float32 = Float32DataType();

  /// 64-bit [double] data type.
  static const FloatDataType float64 = Float64DataType();

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

  /// Casts the argument to this data type, otherwise throw an
  /// [ArgumentError].
  T cast(dynamic value) =>
      throw ArgumentError.value(
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
    final result =
        generate != null
            ? List<T>.generate(length, generate, growable: false)
            : List<T>.filled(
              length,
              fillValue ?? defaultValue,
              growable: false,
            );
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
    final listLength = iterable.length;
    final result = newList(
      length ?? listLength,
      fillValue: fillValue ?? defaultValue,
    );
    result.setRange(0, math.min(result.length, listLength), iterable);
    return readonly ? UnmodifiableListView<T>(result) : result;
  }

  /// Casts an existing [elements] to this data type.
  List<T> castList(Iterable<Object?> elements) {
    final list = newList(elements.length);
    final it = elements.iterator;
    for (var i = 0; i < elements.length && it.moveNext(); i++) {
      list[i] = cast(it.current);
    }
    return list;
  }

  /// Returns a default printer for this data type.
  Printer<T> get printer => StandardPrinter<T>();

  @override
  String toString() => 'DataType.$name';
}
