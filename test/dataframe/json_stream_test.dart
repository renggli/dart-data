import 'dart:async';
import 'dart:convert' show utf8;

import 'package:checks/checks.dart';
import 'package:data/dataframe.dart';
import 'package:test/test.dart';

void main() {
  group('DataFrameJsonStream', () {
    test('parses NDJSON stream into a single DataFrame', () async {
      final ndjson = [
        '{"id": 1, "name": "Alice", "score": 90.5}\n',
        '{"id": 2, "name": "Bob", "score": 85.0}\n',
        '{"id": 3, "name": "Charlie", "score": 92.0}\n',
      ];
      final stream = Stream.fromIterable(ndjson);
      final df = await DataFrameJson.readNdjson(stream);

      check(df.rowCount).equals(3);
      check(df.columnNames).deepEquals(['id', 'name', 'score']);
      check(df['id'].toList()).deepEquals([1, 2, 3]);
      check(df['name'].toList()).deepEquals(['Alice', 'Bob', 'Charlie']);
      check(df['score'].toList()).deepEquals([90.5, 85.0, 92.0]);
    });

    test('yields chunked DataFrames from NDJSON stream', () async {
      final lines = [for (var i = 0; i < 25; i++) '{"k": $i, "v": "val_$i"}\n'];
      final stream = Stream.fromIterable(lines);
      final chunks = await DataFrameJson.readNdjsonChunks(
        stream,
        chunkSize: 10,
      ).toList();

      check(chunks.length).equals(3);
      check(chunks[0].rowCount).equals(10);
      check(chunks[1].rowCount).equals(10);
      check(chunks[2].rowCount).equals(5);
      check(chunks[0]['k'][0]).equals(0);
      check(chunks[1]['k'][0]).equals(10);
      check(chunks[2]['k'][0]).equals(20);
    });

    test('parses byte stream of NDJSON', () async {
      const raw = '{"a": 10}\n{"a": 20}\n';
      final byteStream = Stream.value(utf8.encode(raw));
      final df = await DataFrameJsonStream.readByteStream(byteStream);

      check(df.rowCount).equals(2);
      check(df['a'].toList()).deepEquals([10, 20]);
    });

    test('throws FormatException on malformed non-object JSON line', () async {
      final stream = Stream.value('[1, 2, 3]\n');
      await check(DataFrameJson.readNdjson(stream)).throws<FormatException>();
    });
  });
}
