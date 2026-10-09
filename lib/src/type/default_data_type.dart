import 'data_type.dart';
import 'types/float.dart';
import 'types/integer.dart';

/// Default data types for index, integer, and floating point arithmetic.
abstract final class DefaultDataType {
  /// Default data type to index collections, rows, columns, etc.
  static const IntegerDataType index = DataType.uint32;

  /// Default data type for integer arithmetic.
  static const IntegerDataType integer = DataType.int32;

  /// Default data type for floating point arithmetic.
  static const FloatDataType float = DataType.float64;
}
