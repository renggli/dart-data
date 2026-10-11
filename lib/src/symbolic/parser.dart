import 'package:petitparser/petitparser.dart';

import 'ast.dart';

/// Canonical PetitParser [Parser] for symbolic mathematical expressions.
///
/// Parses strings into symbolic [Expr] abstract syntax trees.
///
/// ```dart
/// final expr = expressionParser.parse('sin(pi * x)').value;
/// ```
final Parser<Expr> expressionParser = buildExpressionParser();

/// Builds a new unanchored [Parser] for symbolic mathematical expressions.
///
/// Supports arithmetic operators, parentheses, brackets, mathematical constants
/// ([pi], [e]), functions ([Sin], [Cos], [Exp], [Ln]), and LaTeX syntax.
///
/// ```dart
/// final parser = buildExpressionParser();
/// final result = parser.parse('2 * x + 1');
/// ```
Parser<Expr> buildExpressionParser() {
  final builder = ExpressionBuilder<Expr>();

  final exponent = pattern('eE') & pattern('+-').optional() & digit().plus();
  final number =
      [
            digit().plus() &
                (char('.') & digit().plus()).optional() &
                exponent.optional(),
            char('.') & digit().plus() & exponent.optional(),
          ]
          .toChoiceParser()
          .flatten('number expected')
          .trim()
          .map((str) => Constant(double.parse(str)));

  final greekLetter = pattern('α-ωΑ-Ω');
  final wordBoundary = (word() | greekLetter | char('_')).not();

  final piConstant = [
    string(r'\pi'),
    string(r'\PI'),
    string(r'\Pi'),
    stringIgnoreCase('pi'),
    pattern('πΠ'),
  ].toChoiceParser().seq(wordBoundary).trim().map((_) => Constant.pi);

  final eConstant = [
    string(r'\e'),
    pattern('e\u212F\u2147'),
  ].toChoiceParser().seq(wordBoundary).trim().map((_) => Constant.e);

  final frac = seq2(
    builder.loopback.skip(
      before:
          [
            string(r'\dfrac'),
            string(r'\frac'),
          ].toChoiceParser().seq(wordBoundary).trim() &
          char('{').trim(),
      after: char('}').trim(),
    ),
    builder.loopback.skip(before: char('{').trim(), after: char('}').trim()),
  ).map2(Div.new);

  final idStart = letter() | greekLetter | char('_');
  final idPart = letter() | digit() | greekLetter | char('_');

  final variable = (char(r'\').optional() & idStart & idPart.star())
      .flatten('variable expected')
      .trim()
      .map((name) {
        final cleanName = name.startsWith(r'\') ? name.substring(1) : name;
        return Variable(cleanName);
      });

  builder.primitive(number);
  builder.primitive(piConstant);
  builder.primitive(eConstant);
  builder.primitive(frac);
  builder.primitive(variable);

  Parser<void> funcPrefix(String name) =>
      (char(r'\').optional() & stringIgnoreCase(name) & wordBoundary).trim();

  final funcGroup = builder.group();
  for (final (open, close) in [
    (char('(').trim(), char(')').trim()),
    (char('[').trim(), char(']').trim()),
    (char('{').trim(), char('}').trim()),
  ]) {
    funcGroup
      ..wrapper(open, close, (_, expr, _) => expr)
      ..wrapper(funcPrefix('sin') & open, close, (_, expr, _) => Sin(expr))
      ..wrapper(funcPrefix('cos') & open, close, (_, expr, _) => Cos(expr))
      ..wrapper(funcPrefix('exp') & open, close, (_, expr, _) => Exp(expr))
      ..wrapper(funcPrefix('ln') & open, close, (_, expr, _) => Ln(expr))
      ..wrapper(funcPrefix('log') & open, close, (_, expr, _) => Ln(expr))
      ..wrapper(
        funcPrefix('sqrt') & open,
        close,
        (_, expr, _) => Pow(expr, const Constant(0.5)),
      );
  }

  builder.group()
    ..prefix(char('-').trim(), (_, expr) => Neg(expr))
    ..prefix(char('+').trim(), (_, expr) => expr);

  final powOp = [char('^'), string('**')].toChoiceParser().trim();

  builder.group().right(powOp, (left, _, right) => Pow(left, right));

  final mulOp = [
    char('*'),
    char('·'),
    char('×'),
    string(r'\cdot'),
    string(r'\times'),
  ].toChoiceParser().trim();

  final divOp = [char('/'), char('÷'), string(r'\div')].toChoiceParser().trim();

  builder.group()
    ..left(mulOp, (left, _, right) => Mul(left, right))
    ..left(divOp, (left, _, right) => Div(left, right));

  final addOp = char('+').trim();
  final subOp = char('-').trim();

  builder.group()
    ..left(addOp, (left, _, right) => Add(left, right))
    ..left(subOp, (left, _, right) => Sub(left, right));

  return builder.build();
}

/// Parser for symbolic [Expr] expressions powered by PetitParser.
final class ExpressionParser {
  const new _();

  static final Parser<Expr> _parser = buildExpressionParser().trim().end();

  /// Parses [input] into an [Expr]. Throws [FormatException] if parsing fails.
  static Expr parse(String input) {
    final result = _parser.parse(input);
    if (result case Success(:final value)) {
      return value;
    }
    throw FormatException(
      'Failed to parse expression: ${result.message} at position ${result.position}',
      input,
      result.position,
    );
  }

  /// Tries to parse [input] into an [Expr], returning `null` on failure.
  static Expr? tryParse(String input) {
    final result = _parser.parse(input);
    return result is Success<Expr> ? result.value : null;
  }
}
