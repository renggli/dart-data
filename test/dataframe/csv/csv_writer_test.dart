import 'package:checks/checks.dart';
import 'package:data/dataframe.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('CsvWriter serialization & escaping', () {
    test('properly escapes commas in standard CSV', () {
      final df = DataFrame.fromColumns({
        'name': ['Smith, John', 'Doe'],
        'age': [30, 25],
      });
      final csv = CsvWriter.write(df);
      check(csv).contains('"Smith, John",30');
      check(csv).contains('Doe,25');
    });

    test('properly escapes custom separators: tabs', () {
      final df = DataFrame.fromColumns({
        'notes': ['has\ttab', 'plain'],
        'count': [1, 2],
      });
      final tsv = CsvWriter.write(df, separator: '\t');
      check(tsv).contains('"has\ttab"\t1');
      check(tsv).contains('plain\t2');
    });

    test('properly escapes custom separators: semicolons', () {
      final df = DataFrame.fromColumns({
        'header;with;semi': ['a;b', 'plain'],
        'val': [10, 20],
      });
      final semi = CsvWriter.write(df, separator: ';');
      check(semi).contains('"header;with;semi";val');
      check(semi).contains('"a;b";10');
      check(semi).contains('plain;20');
    });

    test('properly escapes double quotes and newlines', () {
      final df = DataFrame.fromColumns({
        'quote': ['she said "hello"', 'newline\nhere'],
      });
      final csv = CsvWriter.write(df);
      check(csv).contains('"she said ""hello"""');
      check(csv).contains('"newline\nhere"');
    });

    test('properly formats null values as empty string', () {
      final df = DataFrame.fromColumns({
        'a': [1, null, 3],
        'b': ['x', 'y', null],
      });
      final csv = CsvWriter.write(df);
      check(csv).contains('1,x');
      check(csv).contains(',y');
      check(csv).contains('3,');
    });
  });

  group('CSV roundtrip', () {
    test('roundtrip standard CSV with multiple data types', () {
      final original = DataFrame.fromColumns({
        'int_col': [1, 2, 3],
        'double_col': [1.1, 2.2, 3.3],
        'bool_col': [true, false, true],
        'str_col': ['alpha', 'beta', 'gamma'],
      });
      final serialized = CsvWriter.write(original);
      final deserialized = CsvReader.parse(serialized);

      check(deserialized.rowCount).equals(3);
      check(deserialized.columnNames).deepEquals(original.columnNames);
      check(deserialized['int_col'].toList()).deepEquals([1, 2, 3]);
      check(deserialized['double_col'].toList()).deepEquals([1.1, 2.2, 3.3]);
      check(deserialized['bool_col'].toList()).deepEquals([true, false, true]);
      check(deserialized['str_col'].toList())
          .deepEquals(['alpha', 'beta', 'gamma']);
    });

    test('roundtrip TSV with tab escaping', () {
      final original = DataFrame.fromColumns({
        'title': ['tab\there', 'quote "test"', 'comma,separated'],
        'value': [100, 200, 300],
      });
      final tsv = CsvWriter.write(original, separator: '\t');
      final roundtripped = CsvReader.parse(tsv, separator: '\t');

      check(roundtripped.rowCount).equals(3);
      check(roundtripped['title'].toList())
          .deepEquals(['tab\there', 'quote "test"', 'comma,separated']);
      check(roundtripped['value'].toList()).deepEquals([100, 200, 300]);

      // Roundtrip through CsvReader.parseTsv
      final tsvRestored = CsvReader.parseTsv(tsv);
      check(tsvRestored.rowCount).equals(3);
      check(tsvRestored['title'].toList())
          .deepEquals(['tab\there', 'quote "test"', 'comma,separated']);
      check(tsvRestored['value'].toList()).deepEquals([100, 200, 300]);
    });

    test('roundtrip semicolon-separated data with semicolon escaping', () {
      final original = DataFrame.fromColumns({
        'desc': ['semi;colon', 'normal', 'multi\nline'],
        'id': [1, 2, 3],
      });
      final semi = CsvWriter.write(original, separator: ';');
      final roundtripped = CsvReader.parse(semi, separator: ';');

      check(roundtripped.rowCount).equals(3);
      check(roundtripped['desc'].toList())
          .deepEquals(['semi;colon', 'normal', 'multi\nline']);
      check(roundtripped['id'].toList()).deepEquals([1, 2, 3]);
    });

    test('roundtrip 1-column DataFrame with null values', () {
      final original = DataFrame.fromColumns({
        'val': ['hello', null, 'world', null],
      });
      final csv = CsvWriter.write(original);
      final deserialized = CsvReader.parse(csv);

      check(deserialized.rowCount).equals(4);
      check(deserialized['val'].toList())
          .deepEquals(['hello', null, 'world', null]);
    });

    test('roundtrip 1-column DataFrame with single row null', () {
      final original = DataFrame.fromColumns({
        'val': [null],
      });
      final csv = CsvWriter.write(original);
      final deserialized = CsvReader.parse(csv);

      check(deserialized.rowCount).equals(1);
      check(deserialized['val'].toList()).deepEquals([null]);
    });

    test('DataFrame.fromCsv and DataFrame.toCsv convenience integration', () {
      final original = DataFrame.fromColumns({
        'x': [1, 2],
        'y': ['a|b', 'c'],
      });
      final csv = original.toCsv(separator: '|');
      final restored = DataFrame.fromCsv(csv, separator: '|');
      check(restored.rowCount).equals(2);
      check(restored['y'].toList()).deepEquals(['a|b', 'c']);
    });
  });
}
