import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/src/dataframe/arrow/flatbuffer.dart';
import 'package:test/test.dart';

void main() {
  group('FlatBufferWriter and FlatBufferReader', () {
    test('round-trips primitive values and tables', () {
      final writer = FlatBufferWriter();
      final strOffset = writer.addString('Hello Arrow');
      final tableOffset = writer.addTable(
        [true, 42, 1000, 100000, 1234567890123, strOffset],
        [
          FbFieldType.boolean,
          FbFieldType.uint8,
          FbFieldType.int16,
          FbFieldType.int32,
          FbFieldType.int64,
          FbFieldType.offset,
        ],
      );
      writer.finish(tableOffset);
      final bytes = writer.toBytes();

      final reader = FlatBufferReader(bytes);
      final root = reader.rootTableOffset;

      check(reader.readUint8(root, 0)).equals(1);
      check(reader.readUint8(root, 1)).equals(42);
      check(reader.readInt16(root, 2)).equals(1000);
      check(reader.readInt32(root, 3)).equals(100000);
      check(reader.readInt64(root, 4)).equals(1234567890123);
      check(reader.readString(root, 5)).equals('Hello Arrow');
    });

    test('64-bit integer little-endian read/write helpers', () {
      final data = ByteData(16);
      writeInt64LE(data, 0, -9007199254740991);
      writeUint64LE(data, 8, 9007199254740991);

      check(readInt64LE(data, 0)).equals(-9007199254740991);
      check(readUint64LE(data, 8)).equals(9007199254740991);
    });
  });
}
