import '../type.dart';

/// Sealed token representing the underlying data type.
enum DType {
  float32,
  float64,
  int8,
  uint8,
  int16,
  uint16,
  int32,
  uint32,
  int64,
  uint64,
  boolean,
  string,
  complex64,
  complex128,
  object;

  /// Returns the byte size of a single element for this data type.
  int get bytesPerElement => switch (this) {
    int8 || uint8 || boolean => 1,
    int16 || uint16 => 2,
    int32 || uint32 || float32 => 4,
    int64 || uint64 || float64 || complex64 => 8,
    complex128 => 16,
    string || object => 8,
  };

  /// Returns `true` if this type is a floating-point number.
  bool get isFloat => this == float32 || this == float64;

  /// Returns `true` if this type is an integer.
  bool get isInteger =>
      this == int8 ||
      this == uint8 ||
      this == int16 ||
      this == uint16 ||
      this == int32 ||
      this == uint32 ||
      this == int64 ||
      this == uint64;

  /// Returns `true` if this type is numeric.
  bool get isNumeric => isFloat || isInteger;

  /// Returns `true` if this type is signed.
  bool get isSigned => switch (this) {
    uint8 || uint16 || uint32 || uint64 || boolean => false,
    _ => true,
  };

  /// Returns the corresponding [DataType].
  DataType<Object?> get dataType => switch (this) {
    float32 => DataType.float32,
    float64 => DataType.float64,
    int8 => DataType.int8,
    uint8 => DataType.uint8,
    int16 => DataType.int16,
    uint16 => DataType.uint16,
    int32 => DataType.int32,
    uint32 => DataType.uint32,
    int64 => DataType.int64,
    uint64 => DataType.uint64,
    boolean => DataType.boolean,
    string => DataType.string,
    complex64 || complex128 => DataType.complex,
    object => DataType.dynamicType,
  };
}
