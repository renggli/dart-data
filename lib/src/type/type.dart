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

  const DataType();

  factory DataType.fromIterable(Iterable elements) => findDataType(elements);

  /// Returns the name of this [DataType].
  String get name;

  /// Returns true, if this [DataType] supports `null` values.
  bool get isNullable;

  /// Returns the default null vaue.
  T get nullValue;

  /// Returns a [DataType] that supports `null` values.
  DataType<T> get nullable => isNullable ? this : NullableDataType<T>(this);

  /// Converts the argument to this data type, otherwise throw an
  /// [ArgumentError].
  T convert(Object value) => throw ArgumentError.value(
      value, 'value', 'Unable to convert "$value" to $this.');

  /// Creates a new list of this data type.
  List<T> newList(int length) => List(length);

  /// Creates a copy of a list of this data type, possibly with a modified
  /// [length] and if necessary populated with [fillValue].
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
