// coverage:ignore-file
// ignore_for_file: non_constant_identifier_names, unreachable_from_main

import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../../type/data_type.dart';
import '../arrow_string_series.dart';
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
void exportDataFrameToArrowC({
  required DataFrame dataFrame,
  required Object outSchema,
  required Object outArray,
}) {
  final outSchemaPtr = outSchema as ffi.Pointer<ArrowSchema>;
  final outArrayPtr = outArray as ffi.Pointer<ArrowArray>;
  final columnCount = dataFrame.columnCount;

  // Initialize pointers to nullptr for safe unwinding in case of exception
  outSchemaPtr.ref.format = ffi.nullptr;
  outSchemaPtr.ref.name = ffi.nullptr;
  outSchemaPtr.ref.metadata = ffi.nullptr;
  outSchemaPtr.ref.flags = 0;
  outSchemaPtr.ref.n_children = 0;
  outSchemaPtr.ref.children = ffi.nullptr;
  outSchemaPtr.ref.dictionary = ffi.nullptr;
  outSchemaPtr.ref.release = ffi.nullptr;
  outSchemaPtr.ref.private_data = ffi.nullptr;

  outArrayPtr.ref.length = 0;
  outArrayPtr.ref.null_count = 0;
  outArrayPtr.ref.offset = 0;
  outArrayPtr.ref.n_buffers = 0;
  outArrayPtr.ref.buffers = ffi.nullptr;
  outArrayPtr.ref.n_children = 0;
  outArrayPtr.ref.children = ffi.nullptr;
  outArrayPtr.ref.dictionary = ffi.nullptr;
  outArrayPtr.ref.release = ffi.nullptr;
  outArrayPtr.ref.private_data = ffi.nullptr;

  ffi.Pointer<ffi.Pointer<ArrowSchema>>? schemaChildren;
  ffi.Pointer<ffi.Pointer<ArrowArray>>? arrayChildren;
  ffi.Pointer<ffi.Pointer<ffi.Void>>? topBuffers;

  try {
    // 1. Populate top-level ArrowSchema for Struct ("+s")
    outSchemaPtr.ref.format = '+s'.toNativeUtf8();
    outSchemaPtr.ref.name = ''.toNativeUtf8();
    outSchemaPtr.ref.flags = 0;
    outSchemaPtr.ref.dictionary = ffi.nullptr;
    outSchemaPtr.ref.release = _releaseArrowSchemaPtr;

    if (columnCount > 0) {
      schemaChildren = calloc<ffi.Pointer<ArrowSchema>>(columnCount);
      for (var i = 0; i < columnCount; i++) {
        schemaChildren[i] = ffi.nullptr;
      }
      outSchemaPtr.ref.children = schemaChildren;
    }

    // 2. Populate top-level ArrowArray for Struct
    outArrayPtr.ref.length = dataFrame.rowCount;
    outArrayPtr.ref.null_count = 0;
    outArrayPtr.ref.offset = 0;
    outArrayPtr.ref.n_buffers = 1;
    topBuffers = calloc<ffi.Pointer<ffi.Void>>(1);
    topBuffers[0] = ffi.nullptr;
    outArrayPtr.ref.buffers = topBuffers;
    outArrayPtr.ref.dictionary = ffi.nullptr;
    outArrayPtr.ref.release = _releaseArrowArrayPtr;

    if (columnCount > 0) {
      arrayChildren = calloc<ffi.Pointer<ArrowArray>>(columnCount);
      for (var i = 0; i < columnCount; i++) {
        arrayChildren[i] = ffi.nullptr;
      }
      outArrayPtr.ref.children = arrayChildren;
    }

    // 3. Export each child column, incrementing n_children dynamically
    for (var i = 0; i < columnCount; i++) {
      final col = dataFrame.columns[i];
      final childSchema = calloc<ArrowSchema>();
      final childArray = calloc<ArrowArray>();
      schemaChildren![i] = childSchema;
      arrayChildren![i] = childArray;
      outSchemaPtr.ref.n_children = i + 1;
      outArrayPtr.ref.n_children = i + 1;
      exportSeriesToArrowC(
        series: col,
        outSchema: childSchema,
        outArray: childArray,
      );
    }
  } catch (e) {
    _releaseArrowSchema(outSchemaPtr);
    _releaseArrowArray(outArrayPtr);
    rethrow;
  }
}

/// Imports a [DataFrame] from Apache Arrow C Data structures.
DataFrame importDataFrameFromArrowC({
  required Object schema,
  required Object array,
  bool release = true,
}) {
  final schemaPtr = schema as ffi.Pointer<ArrowSchema>;
  final arrayPtr = array as ffi.Pointer<ArrowArray>;

  if (arrayPtr.ref.release == ffi.nullptr) {
    throw StateError('Cannot import from already-released ArrowArray.');
  }
  if (schemaPtr.ref.release == ffi.nullptr) {
    throw StateError('Cannot import from already-released ArrowSchema.');
  }

  try {
    final formatStr = schemaPtr.ref.format.toDartString();
    if (formatStr != '+s') {
      throw FormatException(
        'Expected struct format "+s" for DataFrame, got "$formatStr".',
      );
    }

    final parentLength = arrayPtr.ref.length;
    final parentOffset = arrayPtr.ref.offset;
    final parentNullCount = arrayPtr.ref.null_count;

    final parentMask = _extractValidityMask(
      buffers: arrayPtr.ref.buffers,
      offset: parentOffset,
      length: parentLength,
      nullCount: parentNullCount,
    );

    final columnCount = schemaPtr.ref.n_children;
    if (arrayPtr.ref.n_children != columnCount) {
      throw FormatException(
        'ArrowArray n_children (${arrayPtr.ref.n_children}) does not match '
        'ArrowSchema n_children ($columnCount).',
      );
    }
    if (columnCount > 0 &&
        (schemaPtr.ref.children == ffi.nullptr ||
            arrayPtr.ref.children == ffi.nullptr)) {
      throw const FormatException(
        'ArrowSchema or ArrowArray children pointer is null when n_children > 0.',
      );
    }
    final columns = <Series<Object?>>[];

    for (var i = 0; i < columnCount; i++) {
      final childSchema = schemaPtr.ref.children[i];
      final childArray = arrayPtr.ref.children[i];
      // Do not release child arrays individually; top-level release handles tree
      var childSeries = importSeriesFromArrowC(
        schema: childSchema,
        array: childArray,
        release: false,
      );

      if (parentOffset > 0 || childSeries.length != parentLength) {
        if (childSeries.length < parentOffset + parentLength) {
          throw FormatException(
            'Child series "${childSeries.name}" length (${childSeries.length}) '
            'is smaller than required parent slice ($parentOffset + $parentLength = ${parentOffset + parentLength}).',
          );
        }
        childSeries = childSeries.slice(
          parentOffset,
          parentOffset + parentLength,
        );
      }

      if (parentMask != null) {
        childSeries = _applyParentMask(childSeries, parentMask);
      }

      columns.add(childSeries);
    }

    return DataFrame(columns);
  } finally {
    if (release) {
      _invokeRelease(schema: schemaPtr, array: arrayPtr);
    }
  }
}

/// Exports a single [Series] to Apache Arrow C Data structures.
void exportSeriesToArrowC({
  required Series<Object?> series,
  required Object outSchema,
  required Object outArray,
  bool? nullable,
}) {
  final outSchemaPtr = outSchema as ffi.Pointer<ArrowSchema>;
  final outArrayPtr = outArray as ffi.Pointer<ArrowArray>;
  final formatCode = _getFormatCode(series);
  final isNullable = nullable ?? true;

  // Initialize structs to nullptr for safe unwinding
  outSchemaPtr.ref.format = ffi.nullptr;
  outSchemaPtr.ref.name = ffi.nullptr;
  outSchemaPtr.ref.metadata = ffi.nullptr;
  outSchemaPtr.ref.flags = 0;
  outSchemaPtr.ref.n_children = 0;
  outSchemaPtr.ref.children = ffi.nullptr;
  outSchemaPtr.ref.dictionary = ffi.nullptr;
  outSchemaPtr.ref.release = ffi.nullptr;
  outSchemaPtr.ref.private_data = ffi.nullptr;

  outArrayPtr.ref.length = 0;
  outArrayPtr.ref.null_count = 0;
  outArrayPtr.ref.offset = 0;
  outArrayPtr.ref.n_buffers = 0;
  outArrayPtr.ref.buffers = ffi.nullptr;
  outArrayPtr.ref.n_children = 0;
  outArrayPtr.ref.children = ffi.nullptr;
  outArrayPtr.ref.dictionary = ffi.nullptr;
  outArrayPtr.ref.release = ffi.nullptr;
  outArrayPtr.ref.private_data = ffi.nullptr;

  try {
    // 1. Populate ArrowSchema
    outSchemaPtr.ref.format = formatCode.toNativeUtf8();
    outSchemaPtr.ref.name = series.name.toNativeUtf8();
    outSchemaPtr.ref.metadata = ffi.nullptr;
    outSchemaPtr.ref.flags = isNullable ? arrowFlagNullable : 0;
    outSchemaPtr.ref.n_children = 0;
    outSchemaPtr.ref.children = ffi.nullptr;
    outSchemaPtr.ref.dictionary = ffi.nullptr;
    outSchemaPtr.ref.release = _releaseArrowSchemaPtr;
    outSchemaPtr.ref.private_data = ffi.nullptr;

    // 2. Populate ArrowArray
    outArrayPtr.ref.length = series.length;
    outArrayPtr.ref.null_count = series.nullCount;
    outArrayPtr.ref.offset = 0;
    outArrayPtr.ref.n_children = 0;
    outArrayPtr.ref.children = ffi.nullptr;
    outArrayPtr.ref.dictionary = ffi.nullptr;
    outArrayPtr.ref.release = _releaseArrowArrayPtr;
    outArrayPtr.ref.private_data = ffi.nullptr;

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
      outArrayPtr.ref.n_buffers = 3;
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
      outArrayPtr.ref.buffers = buffers;
    } else if (series is BoolSeries) {
      outArrayPtr.ref.n_buffers = 2;
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
      outArrayPtr.ref.buffers = buffers;
    } else if (series is TypedSeries) {
      outArrayPtr.ref.n_buffers = 2;
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
      outArrayPtr.ref.buffers = buffers;
    } else {
      throw UnsupportedError(
        'Exporting series of type ${series.runtimeType} is not supported.',
      );
    }
  } catch (e) {
    _releaseArrowSchema(outSchemaPtr);
    _releaseArrowArray(outArrayPtr);
    rethrow;
  }
}

/// Imports a single [Series] from Apache Arrow C Data structures.
Series<Object?> importSeriesFromArrowC({
  required Object schema,
  required Object array,
  bool release = true,
}) {
  final schemaPtr = schema as ffi.Pointer<ArrowSchema>;
  final arrayPtr = array as ffi.Pointer<ArrowArray>;

  if (arrayPtr.ref.release == ffi.nullptr) {
    throw StateError('Cannot import from already-released ArrowArray.');
  }
  if (schemaPtr.ref.release == ffi.nullptr) {
    throw StateError('Cannot import from already-released ArrowSchema.');
  }

  try {
    final name = schemaPtr.ref.name == ffi.nullptr
        ? 'col'
        : schemaPtr.ref.name.toDartString();
    final format = schemaPtr.ref.format.toDartString();
    final length = arrayPtr.ref.length;
    final nullCount = arrayPtr.ref.null_count;
    final offset = arrayPtr.ref.offset;

    if (length == 0) {
      return _createEmptySeries(name: name, format: format);
    }

    final mask = _extractValidityMask(
      buffers: arrayPtr.ref.buffers,
      offset: offset,
      length: length,
      nullCount: nullCount,
    );

    final minBuffers = format == 'u' ? 3 : 2;
    if (arrayPtr.ref.n_buffers < minBuffers ||
        arrayPtr.ref.buffers == ffi.nullptr ||
        arrayPtr.ref.buffers[1] == ffi.nullptr) {
      throw FormatException(
        'Invalid ArrowArray buffers for format "$format" (n_buffers: ${arrayPtr.ref.n_buffers}).',
      );
    }

    switch (format) {
      case 'g':
        final raw = arrayPtr.ref.buffers[1].cast<ffi.Double>().asTypedList(
          offset + length,
        );
        final data = Float64List.fromList(
          Float64List.sublistView(raw, offset, offset + length),
        );
        return TypedSeries<double>(
          name: name,
          data: data,
          mask: mask,
          dataType: DataType.float64,
        );
      case 'f':
        final raw = arrayPtr.ref.buffers[1].cast<ffi.Float>().asTypedList(
          offset + length,
        );
        final data = Float32List.fromList(
          Float32List.sublistView(raw, offset, offset + length),
        );
        return TypedSeries<double>(
          name: name,
          data: data,
          mask: mask,
          dataType: DataType.float32,
        );
      case 'i':
        final raw = arrayPtr.ref.buffers[1].cast<ffi.Int32>().asTypedList(
          offset + length,
        );
        final data = Int32List.fromList(
          Int32List.sublistView(raw, offset, offset + length),
        );
        return TypedSeries<int>(
          name: name,
          data: data,
          mask: mask,
          dataType: DataType.int32,
        );
      case 'l':
        final raw = arrayPtr.ref.buffers[1].cast<ffi.Int64>().asTypedList(
          offset + length,
        );
        final data = Int64List.fromList(
          Int64List.sublistView(raw, offset, offset + length),
        );
        return TypedSeries<int>(
          name: name,
          data: data,
          mask: mask,
          dataType: DataType.int64,
        );
      case 's':
        final raw = arrayPtr.ref.buffers[1].cast<ffi.Int16>().asTypedList(
          offset + length,
        );
        final data = Int16List.fromList(
          Int16List.sublistView(raw, offset, offset + length),
        );
        return TypedSeries<int>(
          name: name,
          data: data,
          mask: mask,
          dataType: DataType.int16,
        );
      case 'c':
        final raw = arrayPtr.ref.buffers[1].cast<ffi.Int8>().asTypedList(
          offset + length,
        );
        final data = Int8List.fromList(
          Int8List.sublistView(raw, offset, offset + length),
        );
        return TypedSeries<int>(
          name: name,
          data: data,
          mask: mask,
          dataType: DataType.int8,
        );
      case 'I':
        final raw = arrayPtr.ref.buffers[1].cast<ffi.Uint32>().asTypedList(
          offset + length,
        );
        final data = Uint32List.fromList(
          Uint32List.sublistView(raw, offset, offset + length),
        );
        return TypedSeries<int>(
          name: name,
          data: data,
          mask: mask,
          dataType: DataType.uint32,
        );
      case 'L':
        final raw = arrayPtr.ref.buffers[1].cast<ffi.Uint64>().asTypedList(
          offset + length,
        );
        final data = Uint64List.fromList(
          Uint64List.sublistView(raw, offset, offset + length),
        );
        return TypedSeries<int>(
          name: name,
          data: data,
          mask: mask,
          dataType: DataType.uint64,
        );
      case 'S':
        final raw = arrayPtr.ref.buffers[1].cast<ffi.Uint16>().asTypedList(
          offset + length,
        );
        final data = Uint16List.fromList(
          Uint16List.sublistView(raw, offset, offset + length),
        );
        return TypedSeries<int>(
          name: name,
          data: data,
          mask: mask,
          dataType: DataType.uint16,
        );
      case 'C':
        final raw = arrayPtr.ref.buffers[1].cast<ffi.Uint8>().asTypedList(
          offset + length,
        );
        final data = Uint8List.fromList(
          Uint8List.sublistView(raw, offset, offset + length),
        );
        return TypedSeries<int>(
          name: name,
          data: data,
          mask: mask,
          dataType: DataType.uint8,
        );
      case 'u':
        final rawOffsets = arrayPtr.ref.buffers[1]
            .cast<ffi.Uint32>()
            .asTypedList(offset + length + 1);
        final baseByte = rawOffsets[offset];
        final totalBytes = rawOffsets[offset + length] - baseByte;
        final sliceOffsets = Uint32List(length + 1);
        for (var i = 0; i <= length; i++) {
          sliceOffsets[i] = rawOffsets[offset + i] - baseByte;
        }

        Uint8List bytes;
        if (totalBytes == 0) {
          bytes = Uint8List(0);
        } else {
          final rawBytes = arrayPtr.ref.buffers[2]
              .cast<ffi.Uint8>()
              .asTypedList(baseByte + totalBytes);
          bytes = Uint8List.fromList(
            Uint8List.sublistView(rawBytes, baseByte, baseByte + totalBytes),
          );
        }
        return ArrowStringSeries(
          name: name,
          bytes: bytes,
          offsets: sliceOffsets,
          mask: mask,
        );
      case 'b':
        final rawBytes = arrayPtr.ref.buffers[1].cast<ffi.Uint8>().asTypedList(
          (offset + length + 7) ~/ 8,
        );
        final boolData = List<bool>.generate(length, (i) {
          final bitIndex = offset + i;
          return ((rawBytes[bitIndex >> 3] >> (bitIndex & 7)) & 1) == 1;
        });
        return BoolSeries(name: name, data: boolData, mask: mask);
      default:
        throw UnsupportedError('Unsupported Arrow format: $format');
    }
  } finally {
    if (release) {
      _invokeRelease(schema: schemaPtr, array: arrayPtr);
    }
  }
}

Series<Object?> _createEmptySeries({
  required String name,
  required String format,
}) {
  switch (format) {
    case 'g':
      return TypedSeries<double>(
        name: name,
        data: Float64List(0),
        dataType: DataType.float64,
      );
    case 'f':
      return TypedSeries<double>(
        name: name,
        data: Float32List(0),
        dataType: DataType.float32,
      );
    case 'i':
      return TypedSeries<int>(
        name: name,
        data: Int32List(0),
        dataType: DataType.int32,
      );
    case 'l':
      return TypedSeries<int>(
        name: name,
        data: Int64List(0),
        dataType: DataType.int64,
      );
    case 's':
      return TypedSeries<int>(
        name: name,
        data: Int16List(0),
        dataType: DataType.int16,
      );
    case 'c':
      return TypedSeries<int>(
        name: name,
        data: Int8List(0),
        dataType: DataType.int8,
      );
    case 'I':
      return TypedSeries<int>(
        name: name,
        data: Uint32List(0),
        dataType: DataType.uint32,
      );
    case 'L':
      return TypedSeries<int>(
        name: name,
        data: Uint64List(0),
        dataType: DataType.uint64,
      );
    case 'S':
      return TypedSeries<int>(
        name: name,
        data: Uint16List(0),
        dataType: DataType.uint16,
      );
    case 'C':
      return TypedSeries<int>(
        name: name,
        data: Uint8List(0),
        dataType: DataType.uint8,
      );
    case 'u':
      return ArrowStringSeries(
        name: name,
        bytes: Uint8List(0),
        offsets: Uint32List.fromList([0]),
      );
    case 'b':
      return BoolSeries(name: name, data: const []);
    default:
      throw UnsupportedError('Unsupported Arrow format: $format');
  }
}

ValidityMask? _extractValidityMask({
  required ffi.Pointer<ffi.Pointer<ffi.Void>> buffers,
  required int offset,
  required int length,
  required int nullCount,
}) {
  // Arrow C Data specification: null_count == 0 means no nulls (validity bitmap may be null).
  // null_count == -1 means null count unknown; validity bitmap is present if buffers[0] != nullptr.
  // null_count > 0 means validity bitmap is present at buffers[0].
  if (nullCount == 0 || buffers == ffi.nullptr || buffers[0] == ffi.nullptr) {
    return null;
  }

  final totalBits = offset + length;
  final totalBytes = (totalBits + 7) ~/ 8;
  final rawMaskBytes = buffers[0].cast<ffi.Uint8>().asTypedList(totalBytes);

  final outBytesCount = (length + 7) ~/ 8;
  final outMaskBytes = Uint8List(outBytesCount);

  var actualNulls = 0;
  for (var i = 0; i < length; i++) {
    final bitPos = offset + i;
    final isSet = ((rawMaskBytes[bitPos >> 3] >> (bitPos & 7)) & 1) == 1;
    if (isSet) {
      outMaskBytes[i >> 3] |= 1 << (i & 7);
    } else {
      actualNulls++;
    }
  }

  if (actualNulls == 0) {
    return null;
  }

  return ValidityMask.fromBytes(length, outMaskBytes, actualNulls);
}

void _invokeRelease({
  required ffi.Pointer<ArrowSchema> schema,
  required ffi.Pointer<ArrowArray> array,
}) {
  if (schema != ffi.nullptr && schema.ref.release != ffi.nullptr) {
    final schemaRelease = schema.ref.release
        .asFunction<void Function(ffi.Pointer<ArrowSchema>)>();
    schemaRelease(schema);
    schema.ref.release = ffi.nullptr;
  }
  if (array != ffi.nullptr && array.ref.release != ffi.nullptr) {
    final arrayRelease = array.ref.release
        .asFunction<void Function(ffi.Pointer<ArrowArray>)>();
    arrayRelease(array);
    array.ref.release = ffi.nullptr;
  }
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

ValidityMask _combineMasks(ValidityMask parentMask, ValidityMask? childMask) {
  if (childMask == null) {
    return parentMask;
  }
  final len = parentMask.length;
  final numBytes = (len + 7) ~/ 8;
  final pBytes = parentMask.bytes;
  final cBytes = childMask.bytes;
  final combined = Uint8List(numBytes);
  for (var i = 0; i < numBytes; i++) {
    combined[i] = pBytes[i] & cBytes[i];
  }
  return ValidityMask.fromBytes(len, combined);
}

Series<Object?> _applyParentMask(
  Series<Object?> series,
  ValidityMask parentMask,
) {
  final combinedMask = _combineMasks(parentMask, series.mask);
  return switch (series) {
    final TypedSeries<int> s => TypedSeries<int>(
      name: s.name,
      data: s.data,
      dataType: s.dataType,
      mask: combinedMask,
    ),
    final TypedSeries<double> s => TypedSeries<double>(
      name: s.name,
      data: s.data,
      dataType: s.dataType,
      mask: combinedMask,
    ),
    final TypedSeries<num> s => TypedSeries<num>(
      name: s.name,
      data: s.data,
      dataType: s.dataType,
      mask: combinedMask,
    ),
    final ArrowStringSeries s => ArrowStringSeries(
      name: s.name,
      bytes: s.bytes,
      offsets: s.offsets,
      mask: combinedMask,
    ),
    final BoolSeries s => BoolSeries(
      name: s.name,
      data: s.data,
      mask: combinedMask,
    ),
    _ => series,
  };
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
