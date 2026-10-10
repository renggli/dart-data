import 'package:checks/checks.dart';
import 'package:data/src/dataframe/csv/parser.dart';
import 'package:petitparser/petitparser.dart';
import 'package:petitparser/reflection.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('TabularDefinition linter', () {
    test('csv parser is free of linter defects', () {
      final parser = TabularDefinition.csv().build();
      check(linter(parser)).isEmpty();
    });

    test('tsv parser is free of linter defects', () {
      final parser = TabularDefinition.tsv().build();
      check(linter(parser)).isEmpty();
    });

    test('custom semicolon delimiter parser is free of linter defects', () {
      final parser = TabularDefinition.csv(delimiter: ';'.toParser()).build();
      check(linter(parser)).isEmpty();
    });

    test('directly parses trailing newline without phantom rows', () {
      final parser = TabularDefinition.csv().build();
      check(parser.parse('a,b\n1,2\n').value)
          .isA<List<List<String>>>()
          .deepEquals([
            ['a', 'b'],
            ['1', '2'],
          ]);
      check(parser.parse('a,b\n1,2').value)
          .isA<List<List<String>>>()
          .deepEquals([
            ['a', 'b'],
            ['1', '2'],
          ]);
      check(parser.parse('').value).isA<List<List<String>>>().deepEquals([]);
      check(parser.parse('a\n\nb\n').value)
          .isA<List<List<String>>>()
          .deepEquals([
            ['a'],
            [''],
            ['b'],
          ]);
    });
  });
}
