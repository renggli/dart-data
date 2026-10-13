import 'package:petitparser/petitparser.dart';

import 'ast.dart';

/// Builds a PetitParser [Parser] for symbolic mathematical expressions.
///
/// ```dart
/// final expr = Expr.parse('2 * x + 1');
/// ```
Parser<Expr> buildParser() {
  final builder = ExpressionBuilder<Expr>();
  builder
    // Numbers
    ..primitive(
      seq3(
        digit().plus(),
        seq2(char('.'), digit().plus()).optional(),
        seq3(pattern('eE'), anyOf('+-').optional(), digit().plus()).optional(),
      ).flatten(message: 'number expected').trim().map(_createValue),
    )
    // Constant, variables, and functions
    ..primitive(
      seq2(
        seq2(
          letter(),
          word().starString(),
        ).flatten(message: 'name expected').trim(),
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
  // Relational operators (<=, >=, <, >, ==, =)
  builder.group()
    ..left(string('<=').trim(), (a, _, b) => LessEqual(a, b))
    ..left(string('>=').trim(), (a, _, b) => GreaterEqual(a, b))
    ..left(char('<').trim(), (a, _, b) => LessThan(a, b))
    ..left(char('>').trim(), (a, _, b) => GreaterThan(a, b))
    ..left((string('==') | char('=')).trim(), (a, _, b) => Equal(a, b));
  return resolve(builder.build()).end();
}

/// The default internal PetitParser [Parser] for symbolic mathematical expressions.
final parser = buildParser();

Expr _createValue(String value) {
  if (value.contains('.')) {
    return RealNumber(double.parse(value));
  }
  final intValue = int.tryParse(value);
  if (intValue != null) {
    return RationalNumber(intValue);
  }
  final doubleValue = double.parse(value);
  final asInt = doubleValue.toInt();
  if (asInt.toDouble() == doubleValue) {
    return RationalNumber(asInt);
  }
  return RealNumber(doubleValue);
}

Expr _createBinding(String name, List<Expr> arguments) =>
    switch (arguments.length) {
      0 => switch (name.toLowerCase()) {
        'pi' => ConstantNumber.pi,
        'e' => ConstantNumber.e,
        'i' => ComplexNumber.i,
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
        'o' || 'order' => _parseOrderArg(arguments[0]),
        'lambertw' || 'w' => LambertW(arguments[0]),
        'erf' => Erf(arguments[0]),
        'erfc' => Erfc(arguments[0]),
        'gamma' => Gamma(arguments[0]),
        'asinh' || 'arsinh' => Asinh(arguments[0]),
        'acosh' || 'arcosh' => Acosh(arguments[0]),
        'atanh' || 'artanh' => Atanh(arguments[0]),
        _ => throw ArgumentError.value(name, 'Unknown function'),
      },
      2 => switch (name.toLowerCase()) {
        'pow' => Pow(arguments[0], arguments[1]),
        'log' => Div(Ln(arguments[1]), Ln(arguments[0])),
        'root' => Pow(arguments[1], Div(RationalNumber.one, arguments[0])),
        'lambertw' || 'w' => switch (arguments[1]) {
          RationalNumber(isInteger: true, numerator: final b) => LambertW(
            arguments[0],
            branch: b,
          ),
          _ => throw ArgumentError('Lambert W branch must be an integer'),
        },
        'beta' => Beta(arguments[0], arguments[1]),
        'o' || 'order' => switch (arguments) {
          [
            Variable(:final name),
            RationalNumber(isInteger: true, numerator: final k),
          ] =>
            OrderTerm(name, k),
          _ => throw ArgumentError.value(name, 'Unknown function'),
        },
        _ => throw ArgumentError.value(name, 'Unknown function'),
      },
      _ => throw ArgumentError.value(name, 'Unknown function'),
    };

Expr _parseOrderArg(Expr arg) => switch (arg) {
  Variable(:final name) => OrderTerm(name, 1),
  RationalNumber(isOne: true) => const OrderTerm('x', 0),
  Pow(
    :final base,
    exponent: RationalNumber(isInteger: true, numerator: final k),
  )
      when base is Variable =>
    OrderTerm(base.name, k),
  Sub(left: Variable(:final name), :final right) => OrderTerm(
    name,
    1,
    point: right,
  ),
  Pow(
    base: Sub(left: Variable(:final name), :final right),
    exponent: RationalNumber(isInteger: true, numerator: final k),
  ) =>
    OrderTerm(name, k, point: right),
  _ => OrderTerm(arg.freeVariables.firstOrNull ?? 'x', 1),
};

/// Parses [input] into an [Expr].
///
/// Throws a [FormatException] if parsing fails.
///
/// ```dart
/// final expr = Expr.parse('2 * x + 1');
/// ```
Expr parseExpression(String input) {
  try {
    final result = parser.parse(input);
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
/// final expr = Expr.tryParse('2 * x + 1');
/// ```
Expr? tryParseExpression(String input) {
  try {
    final result = parser.parse(input);
    return result is Success<Expr> ? result.value : null;
  } on Object {
    return null;
  }
}
