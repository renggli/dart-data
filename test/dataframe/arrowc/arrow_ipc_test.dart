import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/dataframe.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('Arrow IPC Streaming', () {
    test('round-trips DataFrame with numbers, strings, and booleans', () {
      final df = DataFrame.fromColumns({
        'name': ['Alice', null, 'Bob', 'Charlie 🚀'],
        'age': [25, 30, null, 42],
        'score': [95.5, 88.0, 72.3, null],
        'verified': [true, false, true, false],
      });

      final ipcBytes = df.toArrowIpc();
      check(ipcBytes.isNotEmpty).isTrue();

      // Check header continuation token (0xFFFFFFFF)
      check(ipcBytes[0]).equals(0xFF);
      check(ipcBytes[1]).equals(0xFF);
      check(ipcBytes[2]).equals(0xFF);
      check(ipcBytes[3]).equals(0xFF);

      final imported = DataFrame.fromArrowIpc(ipcBytes);
      check(imported.rowCount).equals(4);
      check(imported.columnCount).equals(4);
      check(imported.columnNames)
          .deepEquals(['name', 'age', 'score', 'verified']);

      check(imported['name'].toList())
          .deepEquals(['Alice', null, 'Bob', 'Charlie 🚀']);
      check(imported['age'].toList()).deepEquals([25, 30, null, 42]);
      check(imported['score'].toList()).deepEquals([95.5, 88.0, 72.3, null]);
      check(imported['verified'].toList())
          .deepEquals([true, false, true, false]);
    });

    test('round-trips all integer and float types', () {
      final df = DataFrame([
        Series.fromList('i8', [-10, 20], type: DataType.int8),
        Series.fromList('i16', [-1000, 2000], type: DataType.int16),
        Series.fromList('i32', [-100000, 200000], type: DataType.int32),
        Series.fromList('i64', [
          -10000000000,
          20000000000,
        ], type: DataType.int64),
        Series.fromList('u8', [10, 200], type: DataType.uint8),
        Series.fromList('u16', [1000, 50000], type: DataType.uint16),
        Series.fromList('u32', [100000, 3000000000], type: DataType.uint32),
        Series.fromList('u64', [1000000000, 8000000000], type: DataType.uint64),
        Series.fromList('f32', [1.5, -2.5], type: DataType.float32),
        Series.fromList('f64', [3.14159, -2.71828], type: DataType.float64),
      ]);

      final ipcBytes = df.toArrowIpc();
      final imported = DataFrame.fromArrowIpc(ipcBytes);

      check(imported.rowCount).equals(2);
      check(imported.columnCount).equals(10);
      check(imported['i8'].toList()).deepEquals([-10, 20]);
      check(imported['i16'].toList()).deepEquals([-1000, 2000]);
      check(imported['i32'].toList()).deepEquals([-100000, 200000]);
      check(imported['i64'].toList()).deepEquals([-10000000000, 20000000000]);
      check(imported['u8'].toList()).deepEquals([10, 200]);
      check(imported['u16'].toList()).deepEquals([1000, 50000]);
      check(imported['u32'].toList()).deepEquals([100000, 3000000000]);
      check(imported['u64'].toList()).deepEquals([1000000000, 8000000000]);
      check(imported['f32'][0] as double).isCloseTo(1.5, 1e-5);
      check(imported['f64'][0] as double).isCloseTo(3.14159, 1e-10);
    });

    test('round-trips empty DataFrame with all schema types', () {
      final df = DataFrame([
        Series.fromList('str', <String>[], type: DataType.string),
        Series.fromList('bool', <bool>[], type: DataType.boolean),
        Series.fromList('i8', <int>[], type: DataType.int8),
        Series.fromList('i16', <int>[], type: DataType.int16),
        Series.fromList('i32', <int>[], type: DataType.int32),
        Series.fromList('i64', <int>[], type: DataType.int64),
        Series.fromList('u8', <int>[], type: DataType.uint8),
        Series.fromList('u16', <int>[], type: DataType.uint16),
        Series.fromList('u32', <int>[], type: DataType.uint32),
        Series.fromList('u64', <int>[], type: DataType.uint64),
        Series.fromList('f32', <double>[], type: DataType.float32),
        Series.fromList('f64', <double>[], type: DataType.float64),
      ]);

      final ipcBytes = df.toArrowIpc();
      final imported = DataFrame.fromArrowIpc(ipcBytes);

      check(imported.rowCount).equals(0);
      check(imported.columnCount).equals(12);
      check(imported['str'].dataType).equals(DataType.string);
      check(imported['bool'].dataType).equals(DataType.boolean);
      check(imported['i8'].dataType).equals(DataType.int8);
      check(imported['u64'].dataType).equals(DataType.uint64);
    });

    test('round-trips completely empty DataFrame without columns', () {
      final df = DataFrame([]);
      final bytes = df.toArrowIpc();
      final imported = DataFrame.fromArrowIpc(bytes);
      check(imported.rowCount).equals(0);
      check(imported.columnCount).equals(0);
    });

    test('triggers FlatBuffers growth with large payload and many columns', () {
      final largeStrings = List.generate(
        300,
        (i) => 'Item $i with long text payload to trigger buffer resizing',
      );
      final manyColumns = <Series<dynamic>>[
        Series.fromList('text', largeStrings),
        for (var i = 0; i < 60; i++)
          Series.fromList('col_$i', List.filled(300, i)),
      ];
      final df = DataFrame(manyColumns);
      final bytes = df.toArrowIpc();
      final imported = DataFrame.fromArrowIpc(bytes);
      check(imported.rowCount).equals(300);
      check(imported['text'][150])
          .equals('Item 150 with long text payload to trigger buffer resizing');
      check(imported.columnCount).equals(61);
    });

    test('serializes generic ObjectSeries across data types', () {
      final df = DataFrame([
        ObjectSeries<String>(
          name: 'str',
          data: ['hello', 'world'],
          dataType: DataType.string,
        ),
        ObjectSeries<bool>(
          name: 'bool',
          data: [true, false],
          dataType: DataType.boolean,
        ),
        ObjectSeries<int>(
          name: 'i64',
          data: [-10000000000, 20000000000],
          dataType: DataType.int64,
        ),
        ObjectSeries<int>(
          name: 'u64',
          data: [1000, 5000],
          dataType: DataType.uint64,
        ),
        ObjectSeries<int>(
          name: 'i32',
          data: [42, 84],
          dataType: DataType.int32,
        ),
      ]);
      final bytes = df.toArrowIpc();
      final imported = DataFrame.fromArrowIpc(bytes);
      check(imported.rowCount).equals(2);
      check(imported['str'].toList()).deepEquals(['hello', 'world']);
      check(imported['bool'].toList()).deepEquals([true, false]);
      check(imported['i64'].toList()).deepEquals([-10000000000, 20000000000]);
      check(imported['u64'].toList()).deepEquals([1000, 5000]);
      check(imported['i32'].toList()).deepEquals([42, 84]);
    });

    test('schema-only IPC stream reconstructs typed empty columns', () {
      final df = DataFrame([
        Series.fromList('str', <String>[], type: DataType.string),
        Series.fromList('bool', <bool>[], type: DataType.boolean),
        Series.fromList('f64', <double>[], type: DataType.float64),
        Series.fromList('f32', <double>[], type: DataType.float32),
        Series.fromList('i64', <int>[], type: DataType.int64),
        Series.fromList('i32', <int>[], type: DataType.int32),
        Series.fromList('i16', <int>[], type: DataType.int16),
        Series.fromList('i8', <int>[], type: DataType.int8),
        Series.fromList('u64', <int>[], type: DataType.uint64),
        Series.fromList('u32', <int>[], type: DataType.uint32),
        Series.fromList('u16', <int>[], type: DataType.uint16),
        Series.fromList('u8', <int>[], type: DataType.uint8),
      ]);
      final fullBytes = df.toArrowIpc();
      final byteData = ByteData.sublistView(fullBytes);
      final metaLength = byteData.getUint32(4, Endian.little);
      final schemaMessageTotal = 8 + metaLength;

      // Extract schema message only, and append EOS marker (8 bytes: 0xFFFFFFFF, 0x00000000)
      final eos = Uint8List(8)
        ..[0] = 0xFF
        ..[1] = 0xFF
        ..[2] = 0xFF
        ..[3] = 0xFF;
      final schemaOnlyBytes = Uint8List.fromList([
        ...fullBytes.sublist(0, schemaMessageTotal),
        ...eos,
      ]);

      final imported = DataFrame.fromArrowIpc(schemaOnlyBytes);
      check(imported.rowCount).equals(0);
      check(imported.columnCount).equals(12);
      check(imported['str'].dataType).equals(DataType.string);
      check(imported['bool'].dataType).equals(DataType.boolean);
      check(imported['f64'].dataType).equals(DataType.float64);
      check(imported['f32'].dataType).equals(DataType.float32);
      check(imported['i64'].dataType).equals(DataType.int64);
      check(imported['i32'].dataType).equals(DataType.int32);
      check(imported['i16'].dataType).equals(DataType.int16);
      check(imported['i8'].dataType).equals(DataType.int8);
      check(imported['u64'].dataType).equals(DataType.uint64);
      check(imported['u32'].dataType).equals(DataType.uint32);
      check(imported['u16'].dataType).equals(DataType.uint16);
      check(imported['u8'].dataType).equals(DataType.uint8);
    });

    test('unsupported column type throws on export', () {
      final df = DataFrame([
        Series.fromList('obj', [Object(), Object()]),
      ]);
      check(df.toArrowIpc).throws<UnsupportedError>();
    });
  });
}
