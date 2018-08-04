library data.type;

import 'boolean.dart';
import 'float.dart';
import 'integer.dart';
import 'nullable.dart';
import 'numeric.dart';
import 'object.dart';
import 'string.dart';
import 'utils.dart';

abstract class DataType<T> {
  // Object data types
  static const ObjectDataType OBJECT = ObjectDataType();
  static const StringDataType STRING = StringDataType();
  static const NumericDataType NUMERIC = NumericDataType();

  // Bit data types
  static const BooleanDataType BOOLEAN = BooleanDataType();

  // Integer data types
  static const IntegerDataType INT_8 = Int8DataType();
  static const IntegerDataType UINT_8 = Uint8DataType();
  static const IntegerDataType INT_16 = Int16DataType();
  static const IntegerDataType UINT_16 = Uint16DataType();
  static const IntegerDataType INT_32 = Int32DataType();
  static const IntegerDataType UINT_32 = Uint32DataType();
  static const IntegerDataType INT_64 = Int64DataType();
  static const IntegerDataType UINT_64 = Uint64DataType();

  // Float data types
  static const FloatDataType FLOAT_32 = Float32DataType();
  static const FloatDataType FLOAT_64 = Float64DataType();

  const DataType();

  factory DataType.fromIterable(Iterable elements) => findDataType(elements);

  /// Returns the name of this [DataType].
  String get name;

  /// Returns true, if this [DataType] supports `null` values.
  bool get isNullable;

  /// Returns a [DataType] that supports `null` values.
  DataType<T> get nullable => isNullable ? this : NullableDataType<T>(this);

  /// Converts the argument to this data type, otherwise throw an [ArgumentError].
  T convert(Object value) {
    throw ArgumentError.value(
        value, 'value', 'Unable to convert "$value" to $this.');
  }

  /// Creates a new list of this data type.
  List<T> newList(int length) => List(length);

  /// Converts an existing list to this data type.
  List<T> convertList(Iterable<Object> elements) {
    final list = newList(elements.length);
    final it = elements.iterator;
    for (var i = 0; i < elements.length && it.moveNext(); i++) {
      list[i] = convert(it.current);
    }
    return list;
  }

  @override
  String toString() => 'DataType.$name';
}
