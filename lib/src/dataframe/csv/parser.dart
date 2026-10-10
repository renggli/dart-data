import 'package:petitparser/petitparser.dart';
import 'package:petitparser/petitparser.dart' as pp;

/// Customizable parser definition for tabular text files.
class TabularDefinition extends GrammarDefinition<List<List<String>>> {
  /// Definition for "Comma-separated values" (CSV) input.
  factory csv({
    Parser<String>? quote,
    Parser<String>? escape,
    Parser<String>? delimiter,
    Parser<String>? newline,
  }) => TabularDefinition(
    quote: quote ?? '"'.toParser(),
    escape: escape ?? '""'.toParser().map((_) => '"'),
    delimiter: delimiter ?? ','.toParser(),
    newline: newline ?? pp.newline(),
  );

  /// Definition for "Tab-separated values" (TSV) input.
  factory tsv({
    Parser<String>? quote,
    Parser<String>? escape,
    Parser<String>? delimiter,
    Parser<String>? newline,
  }) => TabularDefinition(
    quote: quote ?? '"'.toParser(),
    escape:
        escape ??
        [
          seq2(char(r'\'), any()).map2(
            (_, value) => switch (value) {
              't' => '\t',
              'n' => '\n',
              'r' => '\r',
              _ => value,
            },
          ),
          '""'.toParser().map((_) => '"'),
        ].toChoiceParser(),
    delimiter: delimiter ?? '\t'.toParser(),
    newline: newline ?? pp.newline(),
  );

  /// Generic constructor for tabular text files.
  const new({
    required this.quote,
    required this.escape,
    required this.delimiter,
    required this.newline,
  });

  /// Specifies how values are quoted.
  final Parser<String> quote;

  /// Specifies how characters are escaped.
  final Parser<String> escape;

  /// Specifies how values are delimited in a row.
  final Parser<String> delimiter;

  /// Specifies how rows are delimited in a file.
  final Parser<String> newline;

  @override
  Parser<List<List<String>>> start() => <Parser<List<List<String>>>>[
    ref0(_lines),
    epsilonWith(<List<String>>[]),
  ].toChoiceParser().end();

  Parser<List<List<String>>> _lines() =>
      ref0(_records)
          .skip(before: endOfInput().not())
          .plusSeparated(newline)
          .map((list) => list.elements)
          .skip(after: newline.optional());

  Parser<List<String>> _records() =>
      ref0(_field).starSeparated(delimiter).map((list) => list.elements);

  Parser<String> _field() =>
      [ref0(_quotedField), ref0(_plainField)].toChoiceParser();

  Parser<String> _quotedField() =>
      ref0(_quotedFieldContent).skip(before: quote, after: quote);

  Parser<String> _quotedFieldContent() =>
      ref0(_quotedFieldChar).star().map((list) => list.join());

  Parser<String> _quotedFieldChar() => [
    escape,
    [escape, quote].toChoiceParser().neg().plusString(),
  ].toChoiceParser();

  Parser<String> _plainField() =>
      ref0(_plainFieldContent).skip(before: quote.not());

  Parser<String> _plainFieldContent() =>
      ref0(_plainFieldChar).star().map((list) => list.join());

  Parser<String> _plainFieldChar() => [
    escape,
    [escape, delimiter, newline].toChoiceParser().neg().plusString(),
  ].toChoiceParser();
}
