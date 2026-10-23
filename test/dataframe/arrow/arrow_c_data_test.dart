@TestOn('vm')
library;

import 'dart:ffi' as ffi;

import 'package:checks/checks.dart';
import 'package:data/dataframe.dart'
    hide
        ArrowArray,
        ArrowSchema,
        arrowFlagDictionaryOrdered,
        arrowFlagMapKeysSorted,
        arrowFlagNullable;
import 'package:data/src/dataframe/arrow/arrow_c_data_ffi.dart';
import 'package:data/type.dart';
import 'package:ffi/ffi.dart';
import 'package:test/test.dart';

void main() {
  group('Apache Arrow C Data Interface', () {
    test('ABI struct sizes align with 64-bit Arrow specification', () {
      check(ffi.sizeOf<ArrowSchema>()).equals(72);
      check(ffi.sizeOf<ArrowArray>()).equals(80);
    });

    test('DataFrame export and import round-trip', () {
      final df = DataFrame.fromColumns({
        'name': ['Alice', null, 'Charlie 🚀'],
        'age': [30, 25, 40],
        'score': [95.5, null, 88.0],
        'active': [true, false, true],
      });

      final outArray = calloc<ArrowArray>();
      final outSchema = calloc<ArrowSchema>();

      try {
        df.exportTo(outSchema: outSchema, outArray: outArray);

        check(outSchema.ref.format.toDartString()).equals('+s');
        check(outSchema.ref.n_children).equals(4);
        check(outArray.ref.length).equals(3);
        check(outArray.ref.n_children).equals(4);

        // Check child schemas
        check(outSchema.ref.children[0].ref.name.toDartString()).equals('name');
        check(outSchema.ref.children[0].ref.format.toDartString()).equals('u');
        check(outSchema.ref.children[0].ref.flags & arrowFlagNullable)
            .equals(arrowFlagNullable);

        check(outSchema.ref.children[1].ref.name.toDartString()).equals('age');
        check(outSchema.ref.children[1].ref.format.toDartString()).equals('i');

        check(outSchema.ref.children[2].ref.name.toDartString())
            .equals('score');
        check(outSchema.ref.children[2].ref.format.toDartString()).equals('g');

        check(outSchema.ref.children[3].ref.name.toDartString())
            .equals('active');
        check(outSchema.ref.children[3].ref.format.toDartString()).equals('b');

        // Import back to DataFrame using DataFrame.importFrom
        final importedDf = DataFrame.importFrom(
          schema: outSchema,
          array: outArray,
        );

        check(importedDf.rowCount).equals(3);
        check(importedDf.columnCount).equals(4);
        check(importedDf.columnNames)
            .deepEquals(['name', 'age', 'score', 'active']);

        check(importedDf['name'].toList())
            .deepEquals(['Alice', null, 'Charlie 🚀']);
        check(importedDf['age'].toList()).deepEquals([30, 25, 40]);
        check(importedDf['score'].toList()).deepEquals([95.5, null, 88.0]);
        check(importedDf['active'].toList()).deepEquals([true, false, true]);

        // Producer release should have been called and pointers cleared to nullptr
        check(outSchema.ref.release).equals(ffi.nullptr);
        check(outArray.ref.release).equals(ffi.nullptr);
      } finally {
        if (outSchema.ref.release != ffi.nullptr) {
          outSchema.ref.release
              .asFunction<void Function(ffi.Pointer<ArrowSchema>)>()(outSchema);
        }
        if (outArray.ref.release != ffi.nullptr) {
          outArray.ref.release
              .asFunction<void Function(ffi.Pointer<ArrowArray>)>()(outArray);
        }

        calloc.free(outSchema);
        calloc.free(outArray);
      }
    });

    test('Series export and import round-trip', () {
      final series = ArrowStringSeries.fromList('languages', [
        'Dart',
        'Rust',
        null,
        'Python',
      ]);

      final outArray = calloc<ArrowArray>();
      final outSchema = calloc<ArrowSchema>();

      try {
        series.exportTo(outSchema: outSchema, outArray: outArray);

        check(outSchema.ref.format.toDartString()).equals('u');
        check(outArray.ref.length).equals(4);
        check(outArray.ref.null_count).equals(1);

        final imported = Series.importFrom(schema: outSchema, array: outArray);
        check(imported.name).equals('languages');
        check(imported.length).equals(4);
        check(imported.nullCount).equals(1);
        check(imported.toList()).deepEquals(['Dart', 'Rust', null, 'Python']);

        check(outSchema.ref.release).equals(ffi.nullptr);
        check(outArray.ref.release).equals(ffi.nullptr);
      } finally {
        if (outSchema.ref.release != ffi.nullptr) {
          outSchema.ref.release
              .asFunction<void Function(ffi.Pointer<ArrowSchema>)>()(outSchema);
        }
        if (outArray.ref.release != ffi.nullptr) {
          outArray.ref.release
              .asFunction<void Function(ffi.Pointer<ArrowArray>)>()(outArray);
        }
        calloc.free(outSchema);
        calloc.free(outArray);
      }
    });

    test('Throws StateError on already released structures', () {
      final outArray = calloc<ArrowArray>();
      final outSchema = calloc<ArrowSchema>();

      final series = Series<int>.fromList('nums', [1, 2, 3]);
      series.exportTo(outSchema: outSchema, outArray: outArray);

      // Release explicitly
      outSchema.ref.release
          .asFunction<void Function(ffi.Pointer<ArrowSchema>)>()(outSchema);
      outArray.ref.release.asFunction<void Function(ffi.Pointer<ArrowArray>)>()(
        outArray,
      );

      check(() => Series.importFrom(schema: outSchema, array: outArray))
          .throws<StateError>();

      check(() => DataFrame.importFrom(schema: outSchema, array: outArray))
          .throws<StateError>();

      calloc.free(outSchema);
      calloc.free(outArray);
    });

    test('Round-trips all primitive integer and float series types', () {
      final types = [
        (Series.fromList('i8', [-5, 10], type: DataType.int8), 'c'),
        (Series.fromList('i16', [-500, 1000], type: DataType.int16), 's'),
        (
          Series.fromList('i64', [
            -5000000000,
            10000000000,
          ], type: DataType.int64),
          'l',
        ),
        (Series.fromList('u8', [5, 200], type: DataType.uint8), 'C'),
        (Series.fromList('u16', [500, 50000], type: DataType.uint16), 'S'),
        (
          Series.fromList('u32', [50000, 3000000000], type: DataType.uint32),
          'I',
        ),
        (
          Series.fromList('u64', [50000, 8000000000], type: DataType.uint64),
          'L',
        ),
        (Series.fromList('f32', [1.5, -2.5], type: DataType.float32), 'f'),
      ];

      for (final (series, expectedFormat) in types) {
        final outArray = calloc<ArrowArray>();
        final outSchema = calloc<ArrowSchema>();
        try {
          series.exportTo(outSchema: outSchema, outArray: outArray);
          check(outSchema.ref.format.toDartString()).equals(expectedFormat);
          final imported = Series.importFrom(
            schema: outSchema,
            array: outArray,
          );
          check(imported.length).equals(series.length);
          if (series.dataType == DataType.float32) {
            check(imported[0] as double).isCloseTo(1.5, 1e-5);
          } else {
            check(imported.toList()).deepEquals(series.toList());
          }
        } finally {
          if (outSchema.ref.release != ffi.nullptr) {
            outSchema.ref.release
                .asFunction<void Function(ffi.Pointer<ArrowSchema>)>()(
              outSchema,
            );
          }
          if (outArray.ref.release != ffi.nullptr) {
            outArray.ref.release
                .asFunction<void Function(ffi.Pointer<ArrowArray>)>()(outArray);
          }
          calloc.free(outSchema);
          calloc.free(outArray);
        }
      }
    });

    test('Imports sliced ArrowArray with non-zero offset', () {
      // Create a 5-element float64 array [10.0, 20.0, 30.0, 40.0, 50.0]
      // and slice with offset = 2, length = 3 -> [30.0, 40.0, 50.0]
      final schema = calloc<ArrowSchema>();
      final array = calloc<ArrowArray>();

      schema.ref.format = 'g'.toNativeUtf8();
      schema.ref.name = 'sliced_col'.toNativeUtf8();
      schema.ref.flags = 0;
      schema.ref.n_children = 0;
      schema.ref.children = ffi.nullptr;
      schema.ref.dictionary = ffi.nullptr;
      schema.ref.release = _mockReleaseSchemaPtr;

      array.ref.length = 3;
      array.ref.offset = 2;
      array.ref.null_count = 0;
      array.ref.n_buffers = 2;
      final buffers = calloc<ffi.Pointer<ffi.Void>>(2);
      buffers[0] = ffi.nullptr; // No nulls

      final dataPtr = calloc<ffi.Double>(5);
      final rawData = dataPtr.asTypedList(5);
      rawData[0] = 10.0;
      rawData[1] = 20.0;
      rawData[2] = 30.0;
      rawData[3] = 40.0;
      rawData[4] = 50.0;
      buffers[1] = dataPtr.cast();

      array.ref.buffers = buffers;
      array.ref.n_children = 0;
      array.ref.children = ffi.nullptr;
      array.ref.dictionary = ffi.nullptr;
      array.ref.release = _mockReleaseArrayPtr;

      _lastReleasedBuffers = buffers;
      _lastReleasedData = dataPtr.cast();

      final imported = Series.importFrom(schema: schema, array: array);
      check(imported.name).equals('sliced_col');
      check(imported.length).equals(3);
      check(imported.toList()).deepEquals([30.0, 40.0, 50.0]);
      check(schema.ref.release).equals(ffi.nullptr);
      check(array.ref.release).equals(ffi.nullptr);

      calloc.free(schema);
      calloc.free(array);
    });

    test('Imports sliced ArrowStringSeries with non-zero offset', () {
      // 4 strings: ["hello", "world", "dart", "arrow"]
      // Offsets: [0, 5, 10, 14, 19]
      // Slice offset = 1, length = 2 -> ["world", "dart"]
      final schema = calloc<ArrowSchema>();
      final array = calloc<ArrowArray>();

      schema.ref.format = 'u'.toNativeUtf8();
      schema.ref.name = 'sliced_strings'.toNativeUtf8();
      schema.ref.flags = 0;
      schema.ref.n_children = 0;
      schema.ref.children = ffi.nullptr;
      schema.ref.dictionary = ffi.nullptr;
      schema.ref.release = _mockReleaseSchemaPtr;

      array.ref.length = 2;
      array.ref.offset = 1;
      array.ref.null_count = 0;
      array.ref.n_buffers = 3;
      final buffers = calloc<ffi.Pointer<ffi.Void>>(3);
      buffers[0] = ffi.nullptr;

      final offsetsPtr = calloc<ffi.Uint32>(5);
      final rawOffsets = offsetsPtr.asTypedList(5);
      rawOffsets.setAll(0, [0, 5, 10, 14, 19]);
      buffers[1] = offsetsPtr.cast();

      final bytesPtr = 'helloworlddartarrow'.toNativeUtf8();
      buffers[2] = bytesPtr.cast();

      array.ref.buffers = buffers;
      array.ref.n_children = 0;
      array.ref.children = ffi.nullptr;
      array.ref.dictionary = ffi.nullptr;
      array.ref.release = _mockReleaseArrayPtr;

      _lastReleasedBuffers = buffers;
      _lastReleasedData = offsetsPtr.cast();
      _lastReleasedExtra = bytesPtr.cast();

      final imported = Series.importFrom(schema: schema, array: array);
      check(imported.name).equals('sliced_strings');
      check(imported.length).equals(2);
      check(imported.toList()).deepEquals(['world', 'dart']);
      check(schema.ref.release).equals(ffi.nullptr);
      check(array.ref.release).equals(ffi.nullptr);

      calloc.free(schema);
      calloc.free(array);
    });

    test(
      'Imports sliced BoolSeries with non-zero offset and null_count == -1',
      () {
        // 8 booleans: [false, true, false, true, true, false, true, false]
        // Null validity bitmap with element 3 null (bit 3 == 0)
        // null_count = -1 (unknown null count)
        // Slice with offset = 2, length = 4:
        // elements 2, 3, 4, 5 -> [false, null, true, false]
        final schema = calloc<ArrowSchema>();
        final array = calloc<ArrowArray>();

        schema.ref.format = 'b'.toNativeUtf8();
        schema.ref.name = 'sliced_bools'.toNativeUtf8();
        schema.ref.flags = arrowFlagNullable;
        schema.ref.n_children = 0;
        schema.ref.children = ffi.nullptr;
        schema.ref.dictionary = ffi.nullptr;
        schema.ref.release = _mockReleaseSchemaPtr;

        array.ref.length = 4;
        array.ref.offset = 2;
        array.ref.null_count = -1; // Unknown null count
        array.ref.n_buffers = 2;
        final buffers = calloc<ffi.Pointer<ffi.Void>>(2);

        // Validity mask: 1 byte: 11110111 (bit 3 is 0, rest 1) = 0xF7
        final maskPtr = calloc<ffi.Uint8>(1);
        maskPtr[0] = 0xF7;
        buffers[0] = maskPtr.cast();

        // Boolean data: bits: 0, 1, 0, 1, 1, 0, 1, 0 = 0x5A
        final boolPtr = calloc<ffi.Uint8>(1);
        boolPtr[0] = 0x5A;
        buffers[1] = boolPtr.cast();

        array.ref.buffers = buffers;
        array.ref.n_children = 0;
        array.ref.children = ffi.nullptr;
        array.ref.dictionary = ffi.nullptr;
        array.ref.release = _mockReleaseArrayPtr;

        _lastReleasedBuffers = buffers;
        _lastReleasedData = maskPtr.cast();
        _lastReleasedExtra = boolPtr.cast();

        final imported = Series.importFrom(schema: schema, array: array);
        check(imported.name).equals('sliced_bools');
        check(imported.length).equals(4);
        check(imported.nullCount).equals(1);
        check(imported.toList()).deepEquals([false, null, true, false]);
        check(schema.ref.release).equals(ffi.nullptr);
        check(array.ref.release).equals(ffi.nullptr);

        calloc.free(schema);
        calloc.free(array);
      },
    );

    test('Zero-length array import handles empty structures cleanly', () {
      final schema = calloc<ArrowSchema>();
      final array = calloc<ArrowArray>();

      schema.ref.format = 'g'.toNativeUtf8();
      schema.ref.name = 'empty_col'.toNativeUtf8();
      schema.ref.flags = 0;
      schema.ref.n_children = 0;
      schema.ref.children = ffi.nullptr;
      schema.ref.dictionary = ffi.nullptr;
      schema.ref.release = _mockReleaseSchemaPtr;

      array.ref.length = 0;
      array.ref.offset = 0;
      array.ref.null_count = 0;
      array.ref.n_buffers = 0;
      array.ref.buffers = ffi.nullptr;
      array.ref.n_children = 0;
      array.ref.children = ffi.nullptr;
      array.ref.dictionary = ffi.nullptr;
      array.ref.release = _mockReleaseArrayPtr;

      _lastReleasedBuffers = ffi.nullptr;
      _lastReleasedData = ffi.nullptr;

      final imported = Series.importFrom(schema: schema, array: array);
      check(imported.name).equals('empty_col');
      check(imported.length).equals(0);
      check(imported.toList()).isEmpty();

      calloc.free(schema);
      calloc.free(array);
    });

    test('Imports sliced DataFrame with parent struct offset and length', () {
      final df = DataFrame.fromColumns({
        'val': [10, 20, 30, 40, 50],
        'str': ['a', 'b', 'c', 'd', 'e'],
      });

      final outArray = calloc<ArrowArray>();
      final outSchema = calloc<ArrowSchema>();

      try {
        df.exportTo(outSchema: outSchema, outArray: outArray);

        // Slice the parent struct array
        outArray.ref.offset = 1;
        outArray.ref.length = 3;

        final imported = DataFrame.importFrom(
          schema: outSchema,
          array: outArray,
        );

        check(imported.rowCount).equals(3);
        check(imported['val'].toList()).deepEquals([20, 30, 40]);
        check(imported['str'].toList()).deepEquals(['b', 'c', 'd']);
      } finally {
        if (outSchema.ref.release != ffi.nullptr) {
          outSchema.ref.release
              .asFunction<void Function(ffi.Pointer<ArrowSchema>)>()(outSchema);
        }
        if (outArray.ref.release != ffi.nullptr) {
          outArray.ref.release
              .asFunction<void Function(ffi.Pointer<ArrowArray>)>()(outArray);
        }
        calloc.free(outSchema);
        calloc.free(outArray);
      }
    });

    test('Imports DataFrame with parent struct validity bitmap', () {
      final df = DataFrame.fromColumns({
        'val': [10, 20, 30, 40],
        'str': ['a', 'b', 'c', 'd'],
      });

      final outArray = calloc<ArrowArray>();
      final outSchema = calloc<ArrowSchema>();
      final maskPtr = calloc<ffi.Uint8>(1);

      try {
        df.exportTo(outSchema: outSchema, outArray: outArray);

        // Set row 2 as null in parent struct mask (0b1011 = 11)
        maskPtr.value = 0x0B;
        outArray.ref.null_count = 1;
        outArray.ref.buffers[0] = maskPtr.cast();

        final imported = DataFrame.importFrom(
          schema: outSchema,
          array: outArray,
        );

        check(imported.rowCount).equals(4);
        check(imported['val'].toList()).deepEquals([10, 20, null, 40]);
        check(imported['str'].toList()).deepEquals(['a', 'b', null, 'd']);
      } finally {
        if (outSchema.ref.release != ffi.nullptr) {
          outSchema.ref.release
              .asFunction<void Function(ffi.Pointer<ArrowSchema>)>()(outSchema);
        }
        if (outArray.ref.release != ffi.nullptr) {
          outArray.ref.release
              .asFunction<void Function(ffi.Pointer<ArrowArray>)>()(outArray);
        }
        calloc.free(outSchema);
        calloc.free(outArray);
      }
    });
  });
}

ffi.Pointer<ffi.Pointer<ffi.Void>> _lastReleasedBuffers = ffi.nullptr;
ffi.Pointer<ffi.Void> _lastReleasedData = ffi.nullptr;
ffi.Pointer<ffi.Void> _lastReleasedExtra = ffi.nullptr;

void _mockReleaseSchema(ffi.Pointer<ArrowSchema> schema) {
  if (schema.ref.format != ffi.nullptr) calloc.free(schema.ref.format);
  if (schema.ref.name != ffi.nullptr) calloc.free(schema.ref.name);
  schema.ref.release = ffi.nullptr;
}

void _mockReleaseArray(ffi.Pointer<ArrowArray> array) {
  if (_lastReleasedBuffers != ffi.nullptr) {
    calloc.free(_lastReleasedBuffers);
    _lastReleasedBuffers = ffi.nullptr;
  }
  if (_lastReleasedData != ffi.nullptr) {
    calloc.free(_lastReleasedData);
    _lastReleasedData = ffi.nullptr;
  }
  if (_lastReleasedExtra != ffi.nullptr) {
    calloc.free(_lastReleasedExtra);
    _lastReleasedExtra = ffi.nullptr;
  }
  array.ref.release = ffi.nullptr;
}

final _mockReleaseSchemaPtr =
    ffi.Pointer.fromFunction<ffi.Void Function(ffi.Pointer<ArrowSchema>)>(
      _mockReleaseSchema,
    );

final _mockReleaseArrayPtr =
    ffi.Pointer.fromFunction<ffi.Void Function(ffi.Pointer<ArrowArray>)>(
      _mockReleaseArray,
    );
