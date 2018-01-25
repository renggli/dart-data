library pandas.type;

import 'package:pandas/src/type/object.dart';
import 'package:pandas/src/type/boolean.dart';
import 'package:pandas/src/type/string.dart';
import 'package:pandas/src/type/numeric.dart';
import 'package:pandas/src/type/integer.dart';
import 'package:pandas/src/type/float.dart';
import 'package:pandas/src/type/nullable.dart';
import 'package:pandas/src/type/utils.dart' ;

abstract class DataType<T> {

  // Object data types
  static const ObjectDataType OBJECT = const ObjectDataType();
  static const StringDataType STRING = const StringDataType();
  static const NumericDataType NUMERIC = const NumericDataType();

  // Bit data types
  static const BooleanDataType BOOLEAN = const BooleanDataType();

  // Integer data types
  static const IntegerDataType INT_8 = const Int8DataType();
  static const IntegerDataType UINT_8 = const Uint8DataType();
  static const IntegerDataType INT_16 = const Int16DataType();
  static const IntegerDataType UINT_16 = const Uint16DataType();
  static const IntegerDataType INT_32 = const Int32DataType();
  static const IntegerDataType UINT_32 = const Uint32DataType();
  static const IntegerDataType INT_64 = const Int64DataType();
  static const IntegerDataType UINT_64 = const Uint64DataType();

  // Float data types
  static const FloatDataType FLOAT_32 = const Float32DataType();
  static const FloatDataType FLOAT_64 = const Float64DataType();

  factory DataType.fromIterable(Iterable elements) {
    return findDataType(elements);
  }

  const DataType();

  /// Returns the name of this [DataType].
  String get name;

  /// Returns true, if this [DataType] supports `null` values.
  bool get isNullable;

  /// Returns a [DataType] that supports `null` values.
  DataType<T> get nullable => isNullable ? this : new NullableDataType<T>(this);

  /// Converts the argument to this data type, otherwise throw an [ArgumentError].
  T convert(Object value) {
    throw new ArgumentError.value(value, 'value', 'Unable to convert "$value" to $this.');
  }

  /// Creates a new list of this data type.
  List<T> newList(int length) => new List(length);

  /// Converts an existing list to this data type.
  List<T> convertList(Iterable<Object> elements) {
    var list = newList(elements.length);
    for (var i = 0, it = elements.iterator; i < elements.length && it.moveNext(); i++) {
      list[i] = convert(it.current);
    }
    return list;
  }

  @override
  String toString() => 'DataType.$name';
}
