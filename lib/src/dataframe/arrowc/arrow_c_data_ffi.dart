// ignore_for_file: non_constant_identifier_names, unreachable_from_main

import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../../../type.dart';
import '../bitmask.dart';
import '../dataframe.dart';
import '../series.dart';

/// Flag indicating that dictionary values are ordered.
const int arrowFlagDictionaryOrdered = 1;

/// Flag indicating that null values are permitted.
const int arrowFlagNullable = 2;

/// Flag indicating that map keys are sorted.
const int arrowFlagMapKeysSorted = 4;

/// Standard Apache Arrow C Data Interface Schema structure.
///
/// Adheres to the 72-byte ABI layout on 64-bit platforms:
/// - [format]: Pointer to type format string.
/// - [name]: Pointer to field/column name string.
/// - [metadata]: Optional pointer to metadata.
/// - [flags]: Bitfield flags ([arrowFlagNullable], etc.).
/// - [n_children]: Number of child schemas.
/// - [children]: Pointer array of child [ArrowSchema] pointers.
/// - [dictionary]: Optional pointer to dictionary [ArrowSchema].
/// - [release]: Release callback function pointer.
/// - [private_data]: Producer-specific opaque data pointer.
final class ArrowSchema extends ffi.Struct {
  /// Type format string (e.g., `"+s"`, `"g"`, `"i"`, `"u"`, `"b"`).
  external ffi.Pointer<Utf8> format;

  /// Field or column name.
  external ffi.Pointer<Utf8> name;

  /// Optional metadata string.
  external ffi.Pointer<ffi.Char> metadata;

  /// Flags describing the type.
  @ffi.Int64()
  external int flags;

  /// Number of children schemas.
  @ffi.Int64()
  external int n_children;

  /// Array of child [ArrowSchema] pointers.
  external ffi.Pointer<ffi.Pointer<ArrowSchema>> children;

  /// Optional dictionary schema pointer for dictionary-encoded types.
  external ffi.Pointer<ArrowSchema> dictionary;

  /// Release callback. Set to `nullptr` once released.
  external ffi.Pointer<
    ffi.NativeFunction<ffi.Void Function(ffi.Pointer<ArrowSchema>)>
  >
  release;

  /// Producer-specific opaque data.
  external ffi.Pointer<ffi.Void> private_data;
}

/// Standard Apache Arrow C Data Interface Array structure.
///
/// Adheres to the 80-byte ABI layout on 64-bit platforms:
/// - [length]: Logical count of elements.
/// - [null_count]: Number of null elements.
/// - [offset]: Relative offset into buffers.
/// - [n_buffers]: Count of data buffer pointers.
/// - [n_children]: Count of child [ArrowArray] pointers.
/// - [buffers]: Pointer array of buffer addresses.
/// - [children]: Pointer array of child [ArrowArray] pointers.
/// - [dictionary]: Optional dictionary array pointer.
/// - [release]: Release callback function pointer.
/// - [private_data]: Producer-specific opaque data pointer.
final class ArrowArray extends ffi.Struct {
  /// Number of elements in the array.
  @ffi.Int64()
  external int length;

  /// Number of null elements in the array.
  @ffi.Int64()
  external int null_count;

  /// Relative offset into the array buffers.
  @ffi.Int64()
  external int offset;

  /// Number of physical buffers.
  @ffi.Int64()
  external int n_buffers;

  /// Number of children arrays.
  @ffi.Int64()
  external int n_children;

  /// Array of raw data buffer pointers.
  external ffi.Pointer<ffi.Pointer<ffi.Void>> buffers;

  /// Array of child [ArrowArray] pointers.
  external ffi.Pointer<ffi.Pointer<ArrowArray>> children;

  /// Optional dictionary array pointer.
  external ffi.Pointer<ArrowArray> dictionary;

  /// Release callback. Set to `nullptr` once released.
  external ffi.Pointer<
    ffi.NativeFunction<ffi.Void Function(ffi.Pointer<ArrowArray>)>
  >
  release;

  /// Producer-specific opaque data.
  external ffi.Pointer<ffi.Void> private_data;
}

/// Exports a [DataFrame] to Apache Arrow C Data structures.
void exportDataFrameToArrowC(
  DataFrame df,
  ffi.Pointer<ArrowArray> outArray,
  ffi.Pointer<ArrowSchema> outSchema,
) {
  final columnCount = df.columnCount;

  // 1. Populate top-level ArrowSchema for Struct ("+s")
  outSchema.ref.format = '+s'.toNativeUtf8();
  outSchema.ref.name = ''.toNativeUtf8();
  outSchema.ref.metadata = ffi.nullptr;
  outSchema.ref.flags = 0;
  outSchema.ref.n_children = columnCount;
  outSchema.ref.dictionary = ffi.nullptr;
  outSchema.ref.release = _releaseArrowSchemaPtr;
  outSchema.ref.private_data = ffi.nullptr;

  final schemaChildren = calloc<ffi.Pointer<ArrowSchema>>(columnCount);
  outSchema.ref.children = schemaChildren;

  // 2. Populate top-level ArrowArray for Struct
  outArray.ref.length = df.rowCount;
  outArray.ref.null_count = 0;
  outArray.ref.offset = 0;
  outArray.ref.n_buffers = 1;
  final topBuffers = calloc<ffi.Pointer<ffi.Void>>(1);
  topBuffers[0] = ffi.nullptr;
  outArray.ref.buffers = topBuffers;
  outArray.ref.n_children = columnCount;
  outArray.ref.dictionary = ffi.nullptr;
  outArray.ref.release = _releaseArrowArrayPtr;
  outArray.ref.private_data = ffi.nullptr;

  final arrayChildren = calloc<ffi.Pointer<ArrowArray>>(columnCount);
  outArray.ref.children = arrayChildren;

  // 3. Export each child column
  for (var i = 0; i < columnCount; i++) {
    final col = df.columns[i];
    final childSchema = calloc<ArrowSchema>();
    final childArray = calloc<ArrowArray>();
    schemaChildren[i] = childSchema;
    arrayChildren[i] = childArray;
    exportSeriesToArrowC(col, childArray, childSchema);
  }
}

/// Imports a [DataFrame] from Apache Arrow C Data structures.
DataFrame importDataFrameFromArrowC(
  ffi.Pointer<ArrowArray> array,
  ffi.Pointer<ArrowSchema> schema,
) {
  if (array.ref.release == ffi.nullptr) {
    throw StateError('Cannot import from already-released ArrowArray.');
  }
  if (schema.ref.release == ffi.nullptr) {
    throw StateError('Cannot import from already-released ArrowSchema.');
  }

  final formatStr = schema.ref.format.toDartString();
  if (formatStr != '+s') {
    throw FormatException(
      'Expected struct format "+s" for DataFrame, got "$formatStr".',
    );
  }

  final columnCount = schema.ref.n_children;
  final columns = <Series<Object?>>[];

  for (var i = 0; i < columnCount; i++) {
    final childSchema = schema.ref.children[i];
    final childArray = array.ref.children[i];
    columns.add(importSeriesFromArrowC(childArray, childSchema));
  }

  return DataFrame(columns);
}

/// Exports a single [Series] to Apache Arrow C Data structures.
void exportSeriesToArrowC(
  Series<Object?> series,
  ffi.Pointer<ArrowArray> outArray,
  ffi.Pointer<ArrowSchema> outSchema,
) {
  final formatCode = _getFormatCode(series);
  final isNullable = series.hasNulls;

  // 1. Populate ArrowSchema
  outSchema.ref.format = formatCode.toNativeUtf8();
  outSchema.ref.name = series.name.toNativeUtf8();
  outSchema.ref.metadata = ffi.nullptr;
  outSchema.ref.flags = isNullable ? arrowFlagNullable : 0;
  outSchema.ref.n_children = 0;
  outSchema.ref.children = ffi.nullptr;
  outSchema.ref.dictionary = ffi.nullptr;
  outSchema.ref.release = _releaseArrowSchemaPtr;
  outSchema.ref.private_data = ffi.nullptr;

  // 2. Populate ArrowArray
  outArray.ref.length = series.length;
  outArray.ref.null_count = series.nullCount;
  outArray.ref.offset = 0;
  outArray.ref.n_children = 0;
  outArray.ref.children = ffi.nullptr;
  outArray.ref.dictionary = ffi.nullptr;
  outArray.ref.release = _releaseArrowArrayPtr;
  outArray.ref.private_data = ffi.nullptr;

  // Allocate validity mask buffer if nulls are present
  var maskBuffer = ffi.Pointer<ffi.Void>.fromAddress(0);
  if (series.nullCount > 0 && series.mask != null) {
    final maskBytes = (series.length + 7) ~/ 8;
    final maskPtr = calloc<ffi.Uint8>(maskBytes);
    maskPtr
        .asTypedList(maskBytes)
        .setAll(0, series.mask!.bytes.sublist(0, maskBytes));
    maskBuffer = maskPtr.cast();
  }

  if (series is ArrowStringSeries) {
    outArray.ref.n_buffers = 3;
    final buffers = calloc<ffi.Pointer<ffi.Void>>(3);
    buffers[0] = maskBuffer;

    final offsetsByteLength = (series.length + 1) * 4;
    final offsetsPtr = calloc<ffi.Uint8>(offsetsByteLength);
    offsetsPtr
        .asTypedList(offsetsByteLength)
        .setAll(0, Uint8List.sublistView(series.offsets));
    buffers[1] = offsetsPtr.cast();

    final bytesLength = series.bytes.length;
    final bytesPtr = calloc<ffi.Uint8>(bytesLength == 0 ? 1 : bytesLength);
    if (bytesLength > 0) {
      bytesPtr.asTypedList(bytesLength).setAll(0, series.bytes);
    }
    buffers[2] = bytesPtr.cast();
    outArray.ref.buffers = buffers;
  } else if (series is BoolSeries) {
    outArray.ref.n_buffers = 2;
    final buffers = calloc<ffi.Pointer<ffi.Void>>(2);
    buffers[0] = maskBuffer;

    final boolBytes = (series.length + 7) ~/ 8;
    final boolPtr = calloc<ffi.Uint8>(boolBytes == 0 ? 1 : boolBytes);
    final typedBool = boolPtr.asTypedList(boolBytes);
    for (var i = 0; i < series.length; i++) {
      if (series.data[i]) {
        typedBool[i >> 3] |= 1 << (i & 7);
      }
    }
    buffers[1] = boolPtr.cast();
    outArray.ref.buffers = buffers;
  } else if (series is TypedSeries) {
    outArray.ref.n_buffers = 2;
    final buffers = calloc<ffi.Pointer<ffi.Void>>(2);
    buffers[0] = maskBuffer;

    final typedData = series.data as TypedData;
    final byteLength = typedData.lengthInBytes;
    final dataPtr = calloc<ffi.Uint8>(byteLength == 0 ? 1 : byteLength);
    if (byteLength > 0) {
      dataPtr
          .asTypedList(byteLength)
          .setAll(0, Uint8List.sublistView(typedData));
    }
    buffers[1] = dataPtr.cast();
    outArray.ref.buffers = buffers;
  } else {
    throw UnsupportedError(
      'Exporting series of type ${series.runtimeType} is not supported.',
    );
  }
}

/// Imports a single [Series] from Apache Arrow C Data structures.
Series<Object?> importSeriesFromArrowC(
  ffi.Pointer<ArrowArray> array,
  ffi.Pointer<ArrowSchema> schema,
) {
  if (array.ref.release == ffi.nullptr) {
    throw StateError('Cannot import from already-released ArrowArray.');
  }
  if (schema.ref.release == ffi.nullptr) {
    throw StateError('Cannot import from already-released ArrowSchema.');
  }

  final name = schema.ref.name == ffi.nullptr
      ? 'col'
      : schema.ref.name.toDartString();
  final format = schema.ref.format.toDartString();
  final length = array.ref.length;
  final nullCount = array.ref.null_count;

  ValidityMask? mask;
  if (nullCount > 0 && array.ref.buffers[0] != ffi.nullptr) {
    final maskBytes = (length + 7) ~/ 8;
    final maskList = Uint8List.fromList(
      array.ref.buffers[0].cast<ffi.Uint8>().asTypedList(maskBytes),
    );
    mask = ValidityMask.fromBytes(length, maskList, nullCount);
  }

  switch (format) {
    case 'g':
      final data = Float64List.fromList(
        array.ref.buffers[1].cast<ffi.Double>().asTypedList(length),
      );
      return TypedSeries<double>(
        name: name,
        data: data,
        mask: mask,
        dataType: DataType.float64,
      );
    case 'f':
      final data = Float32List.fromList(
        array.ref.buffers[1].cast<ffi.Float>().asTypedList(length),
      );
      return TypedSeries<double>(
        name: name,
        data: data,
        mask: mask,
        dataType: DataType.float32,
      );
    case 'i':
      final data = Int32List.fromList(
        array.ref.buffers[1].cast<ffi.Int32>().asTypedList(length),
      );
      return TypedSeries<int>(
        name: name,
        data: data,
        mask: mask,
        dataType: DataType.int32,
      );
    case 'l':
      final data = Int64List.fromList(
        array.ref.buffers[1].cast<ffi.Int64>().asTypedList(length),
      );
      return TypedSeries<int>(
        name: name,
        data: data,
        mask: mask,
        dataType: DataType.int64,
      );
    case 's':
      final data = Int16List.fromList(
        array.ref.buffers[1].cast<ffi.Int16>().asTypedList(length),
      );
      return TypedSeries<int>(
        name: name,
        data: data,
        mask: mask,
        dataType: DataType.int16,
      );
    case 'c':
      final data = Int8List.fromList(
        array.ref.buffers[1].cast<ffi.Int8>().asTypedList(length),
      );
      return TypedSeries<int>(
        name: name,
        data: data,
        mask: mask,
        dataType: DataType.int8,
      );
    case 'I':
      final data = Uint32List.fromList(
        array.ref.buffers[1].cast<ffi.Uint32>().asTypedList(length),
      );
      return TypedSeries<int>(
        name: name,
        data: data,
        mask: mask,
        dataType: DataType.uint32,
      );
    case 'L':
      final data = Uint64List.fromList(
        array.ref.buffers[1].cast<ffi.Uint64>().asTypedList(length),
      );
      return TypedSeries<int>(
        name: name,
        data: data,
        mask: mask,
        dataType: DataType.uint64,
      );
    case 'S':
      final data = Uint16List.fromList(
        array.ref.buffers[1].cast<ffi.Uint16>().asTypedList(length),
      );
      return TypedSeries<int>(
        name: name,
        data: data,
        mask: mask,
        dataType: DataType.uint16,
      );
    case 'C':
      final data = Uint8List.fromList(
        array.ref.buffers[1].cast<ffi.Uint8>().asTypedList(length),
      );
      return TypedSeries<int>(
        name: name,
        data: data,
        mask: mask,
        dataType: DataType.uint8,
      );
    case 'u':
      final offsets = Uint32List.fromList(
        array.ref.buffers[1].cast<ffi.Uint32>().asTypedList(length + 1),
      );
      final totalBytes = offsets[length];
      final bytes = totalBytes == 0
          ? Uint8List(0)
          : Uint8List.fromList(
              array.ref.buffers[2].cast<ffi.Uint8>().asTypedList(totalBytes),
            );
      return ArrowStringSeries(
        name: name,
        bytes: bytes,
        offsets: offsets,
        mask: mask,
      );
    case 'b':
      final byteCount = (length + 7) ~/ 8;
      final rawBytes = array.ref.buffers[1].cast<ffi.Uint8>().asTypedList(
        byteCount,
      );
      final boolData = List<bool>.generate(
        length,
        (i) => ((rawBytes[i >> 3] >> (i & 7)) & 1) == 1,
      );
      return BoolSeries(name: name, data: boolData, mask: mask);
    default:
      throw UnsupportedError('Unsupported Arrow format: $format');
  }
}

/// Extension methods for exporting a [DataFrame] to Arrow C Data.
extension ArrowCDataFrameExtension on DataFrame {
  /// Exports this DataFrame into provided [outArray] and [outSchema] structs.
  void exportToArrowC(
    ffi.Pointer<ArrowArray> outArray,
    ffi.Pointer<ArrowSchema> outSchema,
  ) => exportDataFrameToArrowC(this, outArray, outSchema);
}

/// Extension methods for exporting a [Series] to Arrow C Data.
extension ArrowCSeriesExtension on Series<Object?> {
  /// Exports this Series into provided [outArray] and [outSchema] structs.
  void exportToArrowC(
    ffi.Pointer<ArrowArray> outArray,
    ffi.Pointer<ArrowSchema> outSchema,
  ) => exportSeriesToArrowC(this, outArray, outSchema);
}

String _getFormatCode(Series<Object?> series) {
  if (series is ArrowStringSeries) return 'u';
  if (series is BoolSeries) return 'b';
  if (series is TypedSeries) {
    final type = series.dataType;
    if (type == DataType.float64) return 'g';
    if (type == DataType.float32) return 'f';
    if (type == DataType.int64) return 'l';
    if (type == DataType.int32) return 'i';
    if (type == DataType.int16) return 's';
    if (type == DataType.int8) return 'c';
    if (type == DataType.uint64) return 'L';
    if (type == DataType.uint32) return 'I';
    if (type == DataType.uint16) return 'S';
    if (type == DataType.uint8) return 'C';
  }
  throw UnsupportedError(
    'Unsupported series data type for Arrow C Data: ${series.dataType}',
  );
}

void _releaseArrowSchema(ffi.Pointer<ArrowSchema> schema) {
  if (schema == ffi.nullptr || schema.ref.release == ffi.nullptr) return;

  final nChildren = schema.ref.n_children;
  if (nChildren > 0 && schema.ref.children != ffi.nullptr) {
    for (var i = 0; i < nChildren; i++) {
      final childPtr = schema.ref.children[i];
      if (childPtr != ffi.nullptr) {
        if (childPtr.ref.release != ffi.nullptr) {
          final childRelease = childPtr.ref.release
              .asFunction<void Function(ffi.Pointer<ArrowSchema>)>();
          childRelease(childPtr);
        }
        calloc.free(childPtr);
      }
    }
    calloc.free(schema.ref.children);
  }

  if (schema.ref.format != ffi.nullptr) {
    calloc.free(schema.ref.format);
  }
  if (schema.ref.name != ffi.nullptr) {
    calloc.free(schema.ref.name);
  }
  if (schema.ref.metadata != ffi.nullptr) {
    calloc.free(schema.ref.metadata);
  }

  schema.ref.release = ffi.nullptr;
}

void _releaseArrowArray(ffi.Pointer<ArrowArray> array) {
  if (array == ffi.nullptr || array.ref.release == ffi.nullptr) return;

  final nChildren = array.ref.n_children;
  if (nChildren > 0 && array.ref.children != ffi.nullptr) {
    for (var i = 0; i < nChildren; i++) {
      final childPtr = array.ref.children[i];
      if (childPtr != ffi.nullptr) {
        if (childPtr.ref.release != ffi.nullptr) {
          final childRelease = childPtr.ref.release
              .asFunction<void Function(ffi.Pointer<ArrowArray>)>();
          childRelease(childPtr);
        }
        calloc.free(childPtr);
      }
    }
    calloc.free(array.ref.children);
  }

  final nBuffers = array.ref.n_buffers;
  if (nBuffers > 0 && array.ref.buffers != ffi.nullptr) {
    for (var i = 0; i < nBuffers; i++) {
      final buf = array.ref.buffers[i];
      if (buf != ffi.nullptr) {
        calloc.free(buf);
      }
    }
    calloc.free(array.ref.buffers);
  }

  array.ref.release = ffi.nullptr;
}

final _releaseArrowSchemaPtr =
    ffi.Pointer.fromFunction<ffi.Void Function(ffi.Pointer<ArrowSchema>)>(
      _releaseArrowSchema,
    );

final _releaseArrowArrayPtr =
    ffi.Pointer.fromFunction<ffi.Void Function(ffi.Pointer<ArrowArray>)>(
      _releaseArrowArray,
    );
