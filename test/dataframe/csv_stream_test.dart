import 'dart:async';
import 'dart:convert' show utf8;

import 'package:checks/checks.dart';
import 'package:data/dataframe.dart';
import 'package:test/test.dart';

void main() {
  group('CsvStream', () {
    test('parses basic CSV stream into DataFrame', () async {
      final csvChunks = [
        'id,name,score,active\n',
        '1,Alice,95.5,true\n',
        '2,Bob,88.0,false\n',
      ];
      final stream = Stream.fromIterable(csvChunks);
      final df = await CsvStream.readStream(stream);

      check(df.rowCount).equals(2);
      check(df.columnNames).deepEquals(['id', 'name', 'score', 'active']);
      check(df['id'].toList()).deepEquals([1, 2]);
      check(df['name'].toList()).deepEquals(['Alice', 'Bob']);
      check(df['score'].toList()).deepEquals([95.5, 88.0]);
      check(df['active'].toList()).deepEquals([true, false]);
    });

    test(
      'handles quotes and commas split across arbitrary chunk boundaries',
      () async {
        // Chunk splits directly inside quotes, around commas, and within
        // escaped quotes
        final chunks = [
          'id,description,val\n1,"A field with , co',
          'mma and\nnewline",100\n2,"Escaped ""qu',
          'ote"" inside",200\n',
        ];
        final stream = Stream.fromIterable(chunks);
        final df = await CsvStream.readStream(stream);

        check(df.rowCount).equals(2);
        check(df['description'].toList()).deepEquals([
          'A field with , comma and\nnewline',
          'Escaped "quote" inside',
        ]);
        check(df['val'].toList()).deepEquals([100, 200]);
      },
    );

    test('yields chunked DataFrames of specified chunkSize', () async {
      final rows = ['k,v\n', for (var i = 0; i < 25; i++) '$i,val_$i\n'];
      final stream = Stream.fromIterable(rows);
      final chunks = await CsvStream.readChunks(stream, chunkSize: 10).toList();

      check(chunks.length).equals(3); // 10, 10, 5
      check(chunks[0].rowCount).equals(10);
      check(chunks[1].rowCount).equals(10);
      check(chunks[2].rowCount).equals(5);
      check(chunks[0]['k'][0]).equals(0);
      check(chunks[1]['k'][0]).equals(10);
      check(chunks[2]['k'][0]).equals(20);
    });

    test('parses byte stream (Stream<List<int>>)', () async {
      const raw = 'col1,col2\n10,20\n30,40\n';
      final byteStream = Stream.fromIterable([utf8.encode(raw)]);
      final df = await CsvStream.readByteStream(byteStream);

      check(df.rowCount).equals(2);
      check(df['col1'].toList()).deepEquals([10, 30]);
      check(df['col2'].toList()).deepEquals([20, 40]);
    });

    test('delegates through CsvReader static methods', () async {
      const csv = 'a,b\n1,2\n3,4\n';
      final df = await CsvReader.parseStream(Stream.value(csv));
      check(df.rowCount).equals(2);

      final chunked = await CsvReader.parseStreamChunks(
        Stream.value(csv),
        chunkSize: 1,
      ).toList();
      check(chunked.length).equals(2);
    });

    test('throws FormatException on unterminated quote in stream', () async {
      final stream = Stream.value('a,b\n1,"unterminated');
      await check(CsvStream.readStream(stream)).throws<FormatException>();
    });

    test('handles empty stream gracefully', () async {
      const stream = Stream<String>.empty();
      final df = await CsvStream.readStream(stream);
      check(df.rowCount).equals(0);
    });
  });
}
