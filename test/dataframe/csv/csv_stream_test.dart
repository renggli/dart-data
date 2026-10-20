import 'dart:async';
import 'dart:convert' show utf8;

import 'package:checks/checks.dart';
import 'package:data/dataframe.dart';
import 'package:data/type.dart';
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

    test('handles CRLF and CR line endings', () async {
      const crlfCsv = 'id,val\r\n1,foo\r\n2,bar\r\n';
      final dfCrlf = await CsvStream.readStream(Stream.value(crlfCsv));
      check(dfCrlf.rowCount).equals(2);
      check(dfCrlf['id'].toList()).deepEquals([1, 2]);
      check(dfCrlf['val'].toList()).deepEquals(['foo', 'bar']);

      const crCsv = 'id,val\r1,foo\r2,bar\r';
      final dfCr = await CsvStream.readStream(Stream.value(crCsv));
      check(dfCr.rowCount).equals(2);
      check(dfCr['id'].toList()).deepEquals([1, 2]);
      check(dfCr['val'].toList()).deepEquals(['foo', 'bar']);
    });

    test('handles header: false generating automatic col_i names', () async {
      const csv = '10,20\n30,40\n';
      final df = await CsvStream.readStream(Stream.value(csv), header: false);
      check(df.rowCount).equals(2);
      check(df.columnNames).deepEquals(['col_0', 'col_1']);
      check(df['col_0'].toList()).deepEquals([10, 30]);
      check(df['col_1'].toList()).deepEquals([20, 40]);
    });

    test('supports explicit columnNames and columnTypes', () async {
      const csv = '10\nnull\n20\n';
      final df = await CsvStream.readStream(
        Stream.value(csv),
        header: false,
        columnNames: ['val'],
        columnTypes: {'val': DataType.int32.nullable},
      );
      check(df.rowCount).equals(3);
      check(df['val'].toList()).deepEquals([10, null, 20]);
    });

    test('readByteChunks processes byte streams in chunks', () async {
      const raw = 'a,b\n1,2\n3,4\n5,6\n';
      final stream = Stream.value(utf8.encode(raw));
      final chunks = await CsvStream.readByteChunks(
        stream,
        chunkSize: 2,
      ).toList();
      check(chunks.length).equals(2);
      check(chunks[0].rowCount).equals(2);
      check(chunks[1].rowCount).equals(1);
    });

    test('handles empty CSV with only header row', () async {
      const csv = 'col1,col2\n';
      final df = await CsvStream.readStream(Stream.value(csv));
      check(df.rowCount).equals(0);
      check(df.columnNames).deepEquals(['col1', 'col2']);

      final chunks = await CsvStream.readChunks(
        Stream.value(csv),
        chunkSize: 10,
      ).toList();
      check(chunks.length).equals(1);
      check(chunks[0].rowCount).equals(0);
      check(chunks[0].columnNames).deepEquals(['col1', 'col2']);
    });

    test('handles final row without trailing newline', () async {
      const csv = 'x,y\n10,20';
      final df = await CsvStream.readStream(Stream.value(csv));
      check(df.rowCount).equals(1);
      check(df['x'].toList()).deepEquals([10]);
      check(df['y'].toList()).deepEquals([20]);
    });

    test('handles empty and trailing fields in row', () async {
      const csv = 'a,b,c\n1,,3\n,,4\n5,6,\n';
      final df = await CsvStream.readStream(Stream.value(csv));
      check(df.rowCount).equals(3);
      check(df['a'].toList()).deepEquals([1, null, 5]);
      check(df['b'].toList()).deepEquals([null, null, 6]);
      check(df['c'].toList()).deepEquals([3, 4, null]);
    });
  });
}
