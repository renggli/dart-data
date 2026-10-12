import 'package:more/number.dart' show Fraction;
import 'package:petitparser/petitparser.dart';

import 'ast.dart';

/// Builds a PetitParser [Parser] for symbolic mathematical expressions with
/// the specified [maxDenominator] for detecting rational numbers.
///
/// ```dart
/// final p = buildParser();
/// final result = p.parse('2 * x + 1');
/// ```
Parser<Expr> buildParser({int maxDenominator = 64}) {
  final builder = ExpressionBuilder<Expr>();
  builder
    // Numbers
    ..primitive(
      seq3(
            digit().plus(),
            seq2(char('.'), digit().plus()).optional(),
            seq3(
              pattern('eE'),
              anyOf('+-').optional(),
              digit().plus(),
            ).optional(),
          )
          .flatten('number expected')
          .trim()
          .map((value) => _createValue(value, maxDenominator: maxDenominator)),
    )
    // Constant, variables, and functions
    ..primitive(
      seq2(
        seq2(letter(), word().starString()).flatten('name expected').trim(),
        builder.loopback
            .starSeparated(char(',').trim())
            .map((list) => list.elements)
            .skip(before: char('(').trim(), after: char(')').trim())
            .optionalWith(const <Expr>[]),
      ).map2(_createBinding),
    );
  // Parentheses (highest precedence wrapper)
  builder.group().wrapper(
    char('(').trim(),
    char(')').trim(),
    (_, value, _) => value,
  );
  // Exponentiation (right-associative)
  builder.group().right(char('^').trim(), (a, _, b) => Pow(a, b));
  // Unary prefix operators (+, -)
  builder.group()
    ..prefix(char('+').trim(), (_, a) => a)
    ..prefix(char('-').trim(), (_, a) => Neg(a));
  // Multiplicative operators (*, /, left-associative)
  builder.group()
    ..left(char('*').trim(), (a, _, b) => Mul(a, b))
    ..left(char('/').trim(), (a, _, b) => Div(a, b));
  // Additive operators (+, -, left-associative)
  builder.group()
    ..left(char('+').trim(), (a, _, b) => Add(a, b))
    ..left(char('-').trim(), (a, _, b) => Sub(a, b));
  return resolve(builder.build()).end();
}

/// The default internal PetitParser [Parser] for symbolic mathematical expressions.
final parser = buildParser();

Expr _createValue(String value, {int maxDenominator = 64}) {
  final intValue = int.tryParse(value);
  if (intValue != null) {
    return RationalNumber(intValue);
  }
  final doubleValue = double.parse(value);
  if (maxDenominator > 0) {
    final frac = Fraction.fromDouble(
      doubleValue,
      maxDenominator: maxDenominator,
    );
    if (frac.denominator <= maxDenominator &&
        (doubleValue - frac.toDouble()).abs() < 1e-12) {
      return RationalNumber(frac.numerator, frac.denominator);
    }
  }
  return RealNumber(doubleValue);
}

Expr _createBinding(String name, List<Expr> arguments) =>
    switch (arguments.length) {
      0 => switch (name.toLowerCase()) {
        'pi' => ConstantNumber.pi,
        'e' => ConstantNumber.e,
        _ => Variable(name),
      },
      1 => switch (name.toLowerCase()) {
        'sin' => Sin(arguments[0]),
        'cos' => Cos(arguments[0]),
        'tan' => Tan(arguments[0]),
        'asin' || 'arcsin' => Asin(arguments[0]),
        'acos' || 'arccos' => Acos(arguments[0]),
        'atan' || 'arctan' => Atan(arguments[0]),
        'sinh' => Sinh(arguments[0]),
        'cosh' => Cosh(arguments[0]),
        'tanh' => Tanh(arguments[0]),
        'abs' => Abs(arguments[0]),
        'sqrt' => Pow(arguments[0], const RationalNumber(1, 2)),
        'exp' => Exp(arguments[0]),
        'ln' || 'log' => Ln(arguments[0]),
        _ => throw ArgumentError.value(name, 'Unknown function'),
      },
      2 => switch (name.toLowerCase()) {
        'pow' => Pow(arguments[0], arguments[1]),
        'log' => Log(arguments[0], arguments[1]),
        'root' => Pow(arguments[1], Div(RationalNumber.one, arguments[0])),
        _ => throw ArgumentError.value(name, 'Unknown function'),
      },
      _ => throw ArgumentError.value(name, 'Unknown function'),
    };

/// Parses [input] into an [Expr].
///
/// Throws a [FormatException] if parsing fails.
///
/// ```dart
/// final expr = parseExpression('2 * x + 1');
/// ```
Expr parseExpression(String input, {int maxDenominator = 64}) {
  try {
    final p = maxDenominator == 64
        ? parser
        : buildParser(maxDenominator: maxDenominator);
    final result = p.parse(input);
    if (result case Success(:final value)) {
      return value;
    }
    throw FormatException(
      'Failed to parse expression: ${result.message} at position ${result.position}',
      input,
      result.position,
    );
  } on ArgumentError catch (error) {
    throw FormatException(
      error.message?.toString() ?? 'Unknown function',
      input,
    );
  }
}

/// Tries to parse [input] into an [Expr], returning `null` on failure.
///
/// ```dart
/// final expr = tryParseExpression('2 * x + 1');
/// ```
Expr? tryParseExpression(String input, {int maxDenominator = 64}) {
  try {
    final p = maxDenominator == 64
        ? parser
        : buildParser(maxDenominator: maxDenominator);
    final result = p.parse(input);
    return result is Success<Expr> ? result.value : null;
  } on Object {
    return null;
  }
}
