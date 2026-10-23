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

    test('multi-batch stream accumulates and concatenates all batches', () {
      final batch1 = DataFrame.fromColumns({
        'str': ['a', 'b'],
        'num': [10.0, 20.0],
        'flag': [true, false],
      });
      final batch2 = DataFrame.fromColumns({
        'str': ['c', null, 'e'],
        'num': [30.0, null, 50.0],
        'flag': [true, true, false],
      });
      final batch3 = DataFrame.fromColumns({
        'str': ['f'],
        'num': [60.0],
        'flag': [true],
      });

      final multiBytes = ArrowIpc.encodeBatches([batch1, batch2, batch3]);
      final imported = ArrowIpc.decode(multiBytes);

      check(imported.rowCount).equals(6);
      check(imported.columnCount).equals(3);
      check(imported['str'].toList())
          .deepEquals(['a', 'b', 'c', null, 'e', 'f']);
      check(imported['str'].nullCount).equals(1);
      check(imported['num'].toList())
          .deepEquals([10.0, 20.0, 30.0, null, 50.0, 60.0]);
      check(imported['num'].nullCount).equals(1);
      check(imported['flag'].toList())
          .deepEquals([true, false, true, true, false, true]);
    });

    test('unaligned Uint8List.sublistView decodes without alignment crash', () {
      final df = DataFrame.fromColumns({
        'f64': [1.1, 2.2, 3.3, 4.4],
        'f32': [10.5, 20.5, 30.5, 40.5],
        'i32': [100, 200, 300, 400],
        'i16': [1, 2, 3, 4],
        'str': ['one', 'two', 'three', 'four'],
        'bool': [true, false, true, false],
      });
      final original = df.toArrowIpc();

      for (final offset in [1, 2, 3, 4, 5, 6, 7]) {
        final padded = Uint8List(original.length + offset + 8);
        padded.setRange(offset, offset + original.length, original);
        final slice = Uint8List.sublistView(
          padded,
          offset,
          offset + original.length,
        );

        final imported = ArrowIpc.decode(slice);
        check(imported.rowCount).equals(4);
        check(imported.columnCount).equals(6);
        check(imported['f64'].toList()).deepEquals([1.1, 2.2, 3.3, 4.4]);
        check(imported['i32'].toList()).deepEquals([100, 200, 300, 400]);
        check(imported['str'].toList())
            .deepEquals(['one', 'two', 'three', 'four']);
      }
    });

    test('throws UnsupportedError on dictionary-encoded fields', () {
      final df = DataFrame.fromColumns({
        'x': [1, 2, 3],
      });
      final dictBytes = ArrowIpc.encodeForTesting(df, dictionaryEncoding: true);
      check(() => ArrowIpc.decode(dictBytes)).throws<UnsupportedError>();
    });

    test('throws UnsupportedError on compressed record batches', () {
      final df = DataFrame.fromColumns({
        'x': [1, 2, 3],
      });
      final compBytes = ArrowIpc.encodeForTesting(
        df,
        recordBatchCompression: true,
      );
      check(() => ArrowIpc.decode(compBytes)).throws<UnsupportedError>();
    });

    test('field table schema emits empty children vector for Arrow C++/PyArrow compatibility', () {
      final df = DataFrame.fromColumns({
        'int_col': [1, 2],
        'str_col': ['a', 'b'],
      });
      final bytes = df.toArrowIpc();
      final byteData = ByteData.sublistView(bytes);
      final metaLength = byteData.getUint32(4, Endian.little);

      // Read FlatBuffer Schema message
      final fbBytes = bytes.sublist(8, 8 + metaLength);
      final fbReader = ByteData.sublistView(fbBytes);
      final rootTableOffset = fbReader.getUint32(0, Endian.little);

      // Schema table is at header (slot 2) of Message table
      final vtableOffset = fbReader.getInt32(rootTableOffset, Endian.little);
      final vtablePos = rootTableOffset - vtableOffset;
      // slot 2 offset in message table:
      final headerOffsetInTable = fbReader.getUint16(
        vtablePos + 8,
        Endian.little,
      );
      final headerPos = rootTableOffset + headerOffsetInTable;
      final schemaOffset =
          headerPos + fbReader.getUint32(headerPos, Endian.little);

      // In Schema table, fields vector is at slot 1
      final schemaVtableOffset = fbReader.getInt32(schemaOffset, Endian.little);
      final schemaVtablePos = schemaOffset - schemaVtableOffset;
      final fieldsVecOffsetInSchema = fbReader.getUint16(
        schemaVtablePos + 6,
        Endian.little,
      );
      final fieldsVecPos = schemaOffset + fieldsVecOffsetInSchema;
      final fieldsVecTablePos =
          fieldsVecPos + fbReader.getUint32(fieldsVecPos, Endian.little);
      final fieldCount = fbReader.getUint32(fieldsVecTablePos, Endian.little);
      check(fieldCount).equals(2);

      // Check slot 5 (children) on each field table
      for (var i = 0; i < fieldCount; i++) {
        final fieldElemPos = fieldsVecTablePos + 4 + i * 4;
        final fieldPos =
            fieldElemPos + fbReader.getUint32(fieldElemPos, Endian.little);
        final fieldVtableOffset = fbReader.getInt32(fieldPos, Endian.little);
        final fieldVtablePos = fieldPos - fieldVtableOffset;
        final fieldVtableLen = fbReader.getUint16(
          fieldVtablePos,
          Endian.little,
        );

        // vtable must have at least slot 5 (vtable len >= 4 + 2 * 6 = 16)
        check(fieldVtableLen).isGreaterOrEqual(16);
        // slot 5 is children vector: 4 (vtable header) + 5 * 2 = 14
        final childrenOffsetInField = fbReader.getUint16(
          fieldVtablePos + 14,
          Endian.little,
        );
        check(childrenOffsetInField).isGreaterThan(0);
        final childrenVecPos = fieldPos + childrenOffsetInField;
        final childrenVecActualPos =
            childrenVecPos + fbReader.getUint32(childrenVecPos, Endian.little);
        final childrenLen = fbReader.getUint32(
          childrenVecActualPos,
          Endian.little,
        );
        check(childrenLen).equals(0);
      }
    });

    test('throws UnsupportedError on half-precision float at schema time', () {
      final df = DataFrame.fromColumns({
        'f': [1.0, 2.0],
      });
      final bytes = Uint8List.fromList(df.toArrowIpc());
      final byteData = ByteData.sublistView(bytes);

      // In the message FlatBuffer:
      final rootTableOffset = byteData.getUint32(8, Endian.little);
      final vtableOffset = byteData.getInt32(
        8 + rootTableOffset,
        Endian.little,
      );
      final vtablePos = 8 + rootTableOffset - vtableOffset;
      final headerOffsetInTable = byteData.getUint16(
        vtablePos + 8,
        Endian.little,
      );
      final headerPos = 8 + rootTableOffset + headerOffsetInTable;
      final schemaOffset =
          headerPos + byteData.getUint32(headerPos, Endian.little);

      final schemaVtableOffset = byteData.getInt32(schemaOffset, Endian.little);
      final schemaVtablePos = schemaOffset - schemaVtableOffset;
      final fieldsVecOffsetInSchema = byteData.getUint16(
        schemaVtablePos + 6,
        Endian.little,
      );
      final fieldsVecPos = schemaOffset + fieldsVecOffsetInSchema;
      final fieldsVecTablePos =
          fieldsVecPos + byteData.getUint32(fieldsVecPos, Endian.little);

      final field0Pos =
          fieldsVecTablePos +
          4 +
          byteData.getUint32(fieldsVecTablePos + 4, Endian.little);
      final field0VtableOffset = byteData.getInt32(field0Pos, Endian.little);
      final field0VtablePos = field0Pos - field0VtableOffset;

      // slot 3 in field0 is type table (FloatingPoint)
      final typeOffsetInField = byteData.getUint16(
        field0VtablePos + 10,
        Endian.little,
      );
      final typePos = field0Pos + typeOffsetInField;
      final fpTablePos = typePos + byteData.getUint32(typePos, Endian.little);
      final fpVtableOffset = byteData.getInt32(fpTablePos, Endian.little);
      final fpVtablePos = fpTablePos - fpVtableOffset;
      final precOffset = byteData.getUint16(fpVtablePos + 4, Endian.little);
      final precPos = fpTablePos + precOffset;

      // Mutate precision from 2 (Double) to 0 (Half)
      byteData.setInt16(precPos, 0, Endian.little);

      check(() => ArrowIpc.decode(bytes)).throws<UnsupportedError>();
    });

    test('throws UnsupportedError on unsupported typeType at schema time', () {
      final df = DataFrame.fromColumns({
        'f': [1.0, 2.0],
      });
      final bytes = Uint8List.fromList(df.toArrowIpc());
      final byteData = ByteData.sublistView(bytes);

      final rootTableOffset = byteData.getUint32(8, Endian.little);
      final vtableOffset = byteData.getInt32(
        8 + rootTableOffset,
        Endian.little,
      );
      final vtablePos = 8 + rootTableOffset - vtableOffset;
      final headerOffsetInTable = byteData.getUint16(
        vtablePos + 8,
        Endian.little,
      );
      final headerPos = 8 + rootTableOffset + headerOffsetInTable;
      final schemaOffset =
          headerPos + byteData.getUint32(headerPos, Endian.little);

      final schemaVtableOffset = byteData.getInt32(schemaOffset, Endian.little);
      final schemaVtablePos = schemaOffset - schemaVtableOffset;
      final fieldsVecOffsetInSchema = byteData.getUint16(
        schemaVtablePos + 6,
        Endian.little,
      );
      final fieldsVecPos = schemaOffset + fieldsVecOffsetInSchema;
      final fieldsVecTablePos =
          fieldsVecPos + byteData.getUint32(fieldsVecPos, Endian.little);

      final field0Pos =
          fieldsVecTablePos +
          4 +
          byteData.getUint32(fieldsVecTablePos + 4, Endian.little);
      final field0VtableOffset = byteData.getInt32(field0Pos, Endian.little);
      final field0VtablePos = field0Pos - field0VtableOffset;

      // slot 2 in field0 is typeType (uint8)
      final typeTypeOffset = byteData.getUint16(
        field0VtablePos + 8,
        Endian.little,
      );
      final typeTypePos = field0Pos + typeTypeOffset;

      // Mutate typeType from 3 (FloatingPoint) to 99 (unknown)
      byteData.setUint8(typeTypePos, 99);

      check(() => ArrowIpc.decode(bytes)).throws<UnsupportedError>();
    });
  });
}
