library data.type;

import 'package:data/src/type/impl/bigint.dart';
import 'package:data/src/type/impl/boolean.dart';
import 'package:data/src/type/impl/complex.dart';
import 'package:data/src/type/impl/float.dart';
import 'package:data/src/type/impl/fraction.dart';
import 'package:data/src/type/impl/integer.dart';
import 'package:data/src/type/impl/nullable.dart';
import 'package:data/src/type/impl/numeric.dart';
import 'package:data/src/type/impl/object.dart';
import 'package:data/src/type/impl/quaternion.dart';
import 'package:data/src/type/impl/string.dart';
import 'package:data/src/type/models/equality.dart';
import 'package:data/src/type/models/field.dart';
import 'package:data/src/type/models/order.dart';
import 'package:data/src/type/utils.dart' as utils;
import 'package:meta/meta.dart';
import 'package:more/printer.dart';

@immutable
abstract class DataType<T> {
  // Object data types
  static const ObjectDataType object = ObjectDataType();
  static const StringDataType string = StringDataType();
  static const NumericDataType numeric = NumericDataType();

  // Bit data types
  static const BooleanDataType boolean = BooleanDataType();

  // Integer data types
  static const IntegerDataType int8 = Int8DataType();
  static const IntegerDataType uint8 = Uint8DataType();
  static const IntegerDataType int16 = Int16DataType();
  static const IntegerDataType uint16 = Uint16DataType();
  static const IntegerDataType int32 = Int32DataType();
  static const IntegerDataType uint32 = Uint32DataType();
  static const IntegerDataType int64 = Int64DataType();
  static const IntegerDataType uint64 = Uint64DataType();

  // Float data types
  static const FloatDataType float32 = Float32DataType();
  static const FloatDataType float64 = Float64DataType();

  // BigInt, fraction, complex and quaternion data types
  static const BigIntDataType bigInt = BigIntDataType();
  static const FractionDataType fraction = FractionDataType();
  static const ComplexDataType complex = ComplexDataType();
  static const QuaternionDataType quaternion = QuaternionDataType();

  /// Abstract const constructor.
  const DataType();

  /// Derives a fitting [DataType] from [Object] `instance`.
  factory DataType.fromInstance(Object instance) =>
      utils.fromInstance(instance);

  /// Derives a fitting [DataType] from a runtime [Type] `type`.
  factory DataType.fromType(Type type) => utils.fromType(type);

  /// Derives a fitting [DataType] from an [Iterable] of `values`.
  factory DataType.fromIterable(Iterable values) => utils.fromIterable(values);

  /// Returns the name of this [DataType].
  String get name;

  /// Returns true, if this [DataType] supports `null` values.
  bool get isNullable;

  /// Returns the default null value.
  T get nullValue;

  /// Returns a [DataType] that supports `null` values.
  DataType<T> get nullable => isNullable ? this : NullableDataType<T>(this);

  /// Returns an equality relation.
  Equality<T> get equality => Equality<T>();

  /// Returns an order relation, if available.
  Order<T> get order => throw UnsupportedError('No order available for $this.');

  /// Returns a mathematical field, if available.
  Field<T> get field => throw UnsupportedError('No field available for $this.');

  /// Casts the argument to this data type, otherwise throw an
  /// [ArgumentError].
  T cast(Object value) => throw ArgumentError.value(
      value, 'value', 'Unable to cast "$value" to $this.');

  /// Creates a fixed-length list of this data type.
  List<T> newList(int length) => List(length);

  /// Creates a fixed-length list of this data type with a default [fillValue].
  List<T> newListFilled(int length, T fillValue) {
    final result = newList(length);
    if (fillValue != null && fillValue != nullValue) {
      result.fillRange(0, length, fillValue);
    }
    return result;
  }

  /// Creates a fixed-length list copy of this data type, possibly with a
  /// modified [length] and if necessary populated with [fillValue].
  List<T> copyList(Iterable<T> list, {int length, T fillValue}) {
    final listLength = list.length;
    final result = newList(length ?? listLength);
    if (result.length <= listLength) {
      result.setRange(0, result.length, list);
    } else {
      result.setRange(0, listLength, list);
      if (fillValue != null && fillValue != nullValue) {
        result.fillRange(listLength, result.length, fillValue);
      }
    }
    return result;
  }

  /// Casts an existing list to this data type.
  List<T> castList(Iterable<Object> elements) {
    final list = newList(elements.length);
    final it = elements.iterator;
    for (var i = 0; i < elements.length && it.moveNext(); i++) {
      list[i] = cast(it.current);
    }
    return list;
  }

  /// Returns a default printer for this data type.
  Printer get printer => Printer.standard();

  @override
  String toString() => 'DataType.$name';
}
