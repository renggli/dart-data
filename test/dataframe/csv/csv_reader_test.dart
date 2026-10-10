import 'package:checks/checks.dart';
import 'package:data/dataframe.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('CsvReader parsing', () {
    test('parses basic CSV with header', () {
      const csv = 'name,age,score\nAlice,30,95.5\nBob,25,88.0';
      final df = CsvReader.parse(csv);
      check(df.rowCount).equals(2);
      check(df.columnNames).deepEquals(['name', 'age', 'score']);
      check(df['name'].toList()).deepEquals(['Alice', 'Bob']);
      check(df['age'].toList()).deepEquals([30, 25]);
      check(df['score'].toList()).deepEquals([95.5, 88.0]);
    });

    test('parses CSV without header', () {
      const csv = '10,foo\n20,bar';
      final df = CsvReader.parse(csv, header: false);
      check(df.rowCount).equals(2);
      check(df.columnNames).deepEquals(['col_0', 'col_1']);
      check(df['col_0'].toList()).deepEquals([10, 20]);
      check(df['col_1'].toList()).deepEquals(['foo', 'bar']);
    });

    test('handles empty or whitespace-only CSV string', () {
      check(CsvReader.parse('').rowCount).equals(0);
      check(CsvReader.parse('   \n  \r\n').rowCount).equals(0);
    });

    test('handles CRLF line endings and trailing newlines', () {
      const csv = 'x,y\r\n1,2\r\n3,4\r\n';
      final df = CsvReader.parse(csv);
      check(df.rowCount).equals(2);
      check(df['x'].toList()).deepEquals([1, 3]);
      check(df['y'].toList()).deepEquals([2, 4]);
    });

    test('parses quoted fields with commas and escaped quotes', () {
      const csv = 'text,val\n"hello, world",1\n"say ""hi"" now",2';
      final df = CsvReader.parse(csv);
      check(df.rowCount).equals(2);
      check(df['text'].toList()).deepEquals(['hello, world', 'say "hi" now']);
      check(df['val'].toList()).deepEquals([1, 2]);
    });

    test('parses multiline quoted fields', () {
      const csv = 'id,comment\n1,"line 1\nline 2"\n2,"single line"';
      final df = CsvReader.parse(csv);
      check(df.rowCount).equals(2);
      check(df['id'].toList()).deepEquals([1, 2]);
      check(df['comment'].toList())
          .deepEquals(['line 1\nline 2', 'single line']);
    });

    test('infers types: int, double, bool, string, and nulls', () {
      const csv =
          'i,d,b,s,n\n'
          '1,1.5,true,alpha,null\n'
          '2,2.5,false,beta,NA\n'
          '3,3.0,true,gamma,\n';
      final df = CsvReader.parse(csv);
      check(df.rowCount).equals(3);
      check(df['i'].toList()).deepEquals([1, 2, 3]);
      check(df['d'].toList()).deepEquals([1.5, 2.5, 3.0]);
      check(df['b'].toList()).deepEquals([true, false, true]);
      check(df['s'].toList()).deepEquals(['alpha', 'beta', 'gamma']);
      check(df['n'].nullCount).equals(3);
    });

    test('handles custom delimiter: semicolon and pipe', () {
      const semiCsv = 'a;b;c\n10;20;30\n40;50;60';
      final dfSemi = CsvReader.parse(semiCsv, separator: ';');
      check(dfSemi.rowCount).equals(2);
      check(dfSemi.columnNames).deepEquals(['a', 'b', 'c']);
      check(dfSemi['b'].toList()).deepEquals([20, 50]);

      const pipeCsv = 'name|desc\nitem1|first\nitem2|second';
      final dfPlainPipe = CsvReader.parse(pipeCsv, separator: '|');
      check(dfPlainPipe.rowCount).equals(2);
      check(dfPlainPipe['desc'].toList()).deepEquals(['first', 'second']);

      // Quoted pipe field
      const quotedPipe = 'name|desc\nitem1|"pipe|inside"\nitem2|normal';
      final dfPipe = CsvReader.parse(quotedPipe, separator: '|');
      check(dfPipe.rowCount).equals(2);
      check(dfPipe['desc'].toList()).deepEquals(['pipe|inside', 'normal']);
    });

    test('throws FormatException on malformed CSV with unclosed quote', () {
      const malformed = 'a,b\n"unclosed,1\n2,3';
      check(() => CsvReader.parse(malformed)).throws<FormatException>();
    });

    test('preserves empty rows and quoted empty strings in 1-column CSV', () {
      const csv = 'name\nAlice\n\nBob\n';
      final df = CsvReader.parse(csv);
      check(df.rowCount).equals(3);
      check(df['name'].toList()).deepEquals(['Alice', null, 'Bob']);

      const quotedEmpty = 'val\n"hello"\n""\n"world"\n';
      final dfQuoted = CsvReader.parse(quotedEmpty);
      check(dfQuoted.rowCount).equals(3);
      check(dfQuoted['val'].toList()).deepEquals(['hello', null, 'world']);
    });

    test('preserves empty rows in multi-column CSV', () {
      const csv = 'a,b\n1,2\n\n3,4\n';
      final df = CsvReader.parse(csv);
      check(df.rowCount).equals(3);
      check(df['a'].toList()).deepEquals([1, null, 3]);
      check(df['b'].toList()).deepEquals([2, null, 4]);
    });
  });

  group('CsvReader TSV parsing', () {
    test('parses TSV using parseTsv with backslash escape sequences', () {
      const tsv =
          'col1\tcol2\n'
          'val1\tval\\twith\\ttabs\n'
          'line1\tmulti\\nline\n'
          'slash\tpath\\\\dir';
      final df = CsvReader.parseTsv(tsv);
      check(df.rowCount).equals(3);
      check(df.columnNames).deepEquals(['col1', 'col2']);
      check(df['col2'].toList())
          .deepEquals(['val\twith\ttabs', 'multi\nline', 'path\\dir']);
    });

    test('parses TSV with quoted fields using separator tab', () {
      const tsv = 'a\tb\n"tab\tinside"\t123';
      final df = CsvReader.parse(tsv, separator: '\t');
      check(df.rowCount).equals(1);
      check(df['a'].toList()).deepEquals(['tab\tinside']);
      check(df['b'].toList()).deepEquals([123]);
    });

    test('parses TSV with mixed backslash escapes and quotes', () {
      const tsv =
          'a\tb\n'
          '"quoted\\tfield"\tplain\\tfield\n'
          '"tab\tinside"\t123';
      final df = CsvReader.parseTsv(tsv);
      check(df.rowCount).equals(2);
      check(df['a'].toList()).deepEquals(['quoted\tfield', 'tab\tinside']);
      check(df['b'].toList()).deepEquals(['plain\tfield', '123']);
    });
  });
}
