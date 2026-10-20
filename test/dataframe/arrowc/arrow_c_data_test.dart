@TestOn('vm')
library;

import 'dart:ffi' as ffi;

import 'package:checks/checks.dart';
import 'package:data/dataframe.dart'
    hide
        ArrowArray,
        ArrowCDataFrameExtension,
        ArrowCSeriesExtension,
        ArrowSchema,
        arrowFlagDictionaryOrdered,
        arrowFlagMapKeysSorted,
        arrowFlagNullable,
        exportDataFrameToArrowC,
        exportSeriesToArrowC,
        importDataFrameFromArrowC,
        importSeriesFromArrowC;
import 'package:data/src/dataframe/arrowc/arrow_c_data_ffi.dart';
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
        df.exportToArrowC(outArray, outSchema);

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

        // Import back to DataFrame
        final importedDf = importDataFrameFromArrowC(outArray, outSchema);

        check(importedDf.rowCount).equals(3);
        check(importedDf.columnCount).equals(4);
        check(importedDf.columnNames)
            .deepEquals(['name', 'age', 'score', 'active']);

        check(importedDf['name'].toList())
            .deepEquals(['Alice', null, 'Charlie 🚀']);
        check(importedDf['age'].toList()).deepEquals([30, 25, 40]);
        check(importedDf['score'].toList()).deepEquals([95.5, null, 88.0]);
        check(importedDf['active'].toList()).deepEquals([true, false, true]);
      } finally {
        // Release resources
        if (outSchema.ref.release != ffi.nullptr) {
          outSchema.ref.release
              .asFunction<void Function(ffi.Pointer<ArrowSchema>)>()(outSchema);
        }
        if (outArray.ref.release != ffi.nullptr) {
          outArray.ref.release
              .asFunction<void Function(ffi.Pointer<ArrowArray>)>()(outArray);
        }

        check(outSchema.ref.release).equals(ffi.nullptr);
        check(outArray.ref.release).equals(ffi.nullptr);

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
        series.exportToArrowC(outArray, outSchema);

        check(outSchema.ref.format.toDartString()).equals('u');
        check(outArray.ref.length).equals(4);
        check(outArray.ref.null_count).equals(1);

        final imported = importSeriesFromArrowC(outArray, outSchema);
        check(imported.name).equals('languages');
        check(imported.length).equals(4);
        check(imported.nullCount).equals(1);
        check(imported.toList()).deepEquals(['Dart', 'Rust', null, 'Python']);
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
      series.exportToArrowC(outArray, outSchema);

      // Release
      outSchema.ref.release
          .asFunction<void Function(ffi.Pointer<ArrowSchema>)>()(outSchema);
      outArray.ref.release.asFunction<void Function(ffi.Pointer<ArrowArray>)>()(
        outArray,
      );

      check(() => importSeriesFromArrowC(outArray, outSchema))
          .throws<StateError>();

      check(() => importDataFrameFromArrowC(outArray, outSchema))
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
          series.exportToArrowC(outArray, outSchema);
          check(outSchema.ref.format.toDartString()).equals(expectedFormat);
          final imported = importSeriesFromArrowC(outArray, outSchema);
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
  });
}
