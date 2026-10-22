import 'package:petitparser/petitparser.dart';

import '../linear/matrix.dart';
import '../linear/vector.dart';
import 'algebra/simplify.dart';
import 'ast.dart';
import 'type/expr_data_type.dart';

/// Extensible case-sensitive syntax and parser for mathematical [Expr] strings.
///
/// Identifiers are any character sequence that does not start with a digit and
/// contains no whitespace or mathematical operator/delimiter symbols (`+`, `-`,
/// `*`, `/`, `^`, `(`, `)`, `[`, `]`, `{`, `}`, `,`, `;`, `:`, `.`, `=`, `<`,
/// `>`, `!`, `&`, `|`, `~`, `?`, `@`, `#`, `$`, `%`, `\`, `'`, `"`, `` ` ``).
///
/// Unbound identifiers without arguments resolve to [Variable], and unbound
/// identifiers with arguments resolve to [VariableFunction].
///
/// ```dart
/// final syntax = ExprSyntax(
///   constants: {'important': IntegerNumber.of(42)},
///   unaryFunctions: {'half': (a) => a / IntegerNumber.two},
/// );
/// final expr = syntax.parse('half(important) + f(x)');
/// ```
class ExprSyntax {
  /// Creates a syntax combining the standard mathematical constants and
  /// functions with any custom [constants], [unaryFunctions],
  /// [binaryFunctions], and [variadicFunctions].
  new({
    Map<String, Expr> constants = const {},
    Map<String, Expr Function(Expr)> unaryFunctions = const {},
    Map<String, Expr Function(Expr, Expr)> binaryFunctions = const {},
    Map<String, Expr Function(List<Expr>)> variadicFunctions = const {},
    bool implicitMultiplication = false,
  }) : this.empty(
         constants: {...standardConstants, ...constants},
         unaryFunctions: {...standardUnaryFunctions, ...unaryFunctions},
         binaryFunctions: {...standardBinaryFunctions, ...binaryFunctions},
         variadicFunctions: {
           ...standardVariadicFunctions,
           ...variadicFunctions,
         },
         implicitMultiplication: implicitMultiplication,
       );

  /// Creates a syntax containing only the specified [constants],
  /// [unaryFunctions], [binaryFunctions], and [variadicFunctions].
  new empty({
    Map<String, Expr> constants = const {},
    Map<String, Expr Function(Expr)> unaryFunctions = const {},
    Map<String, Expr Function(Expr, Expr)> binaryFunctions = const {},
    Map<String, Expr Function(List<Expr>)> variadicFunctions = const {},
    this.implicitMultiplication = false,
  }) : constants = Map.unmodifiable(constants),
       unaryFunctions = Map.unmodifiable(unaryFunctions),
       binaryFunctions = Map.unmodifiable(binaryFunctions),
       variadicFunctions = Map.unmodifiable(variadicFunctions);

  /// Standard symbolic syntax with built-in constants and functions.
  static final ExprSyntax standard = ExprSyntax();

  /// Standard mathematical constants.
  static final Map<String, Expr> standardConstants = Map.unmodifiable(
    <String, Expr>{
      'pi': Constant.pi,
      'π': Constant.pi,
      'e': Constant.e,
      'i': ComplexNumber.i,
      'infinity': Constant.infinity,
      '∞': Constant.infinity,
    },
  );

  /// Standard 1-argument mathematical functions.
  static final Map<String, Expr Function(Expr)> standardUnaryFunctions =
      Map.unmodifiable(<String, Expr Function(Expr)>{
        'sin': Sin.new,
        'cos': Cos.new,
        'tan': Tan.new,
        'sec': (a) => Pow(Cos(a), IntegerNumber.negativeOne),
        'csc': (a) => Pow(Sin(a), IntegerNumber.negativeOne),
        'cot': (a) => Cos(a) / Sin(a),
        'asin': Asin.new,
        'arcsin': Asin.new,
        'acos': Acos.new,
        'arccos': Acos.new,
        'atan': Atan.new,
        'arctan': Atan.new,
        'asec': (a) => Acos(Pow(a, IntegerNumber.negativeOne)),
        'arcsec': (a) => Acos(Pow(a, IntegerNumber.negativeOne)),
        'acsc': (a) => Asin(Pow(a, IntegerNumber.negativeOne)),
        'arccsc': (a) => Asin(Pow(a, IntegerNumber.negativeOne)),
        'acot': (a) => Atan(Pow(a, IntegerNumber.negativeOne)),
        'arccot': (a) => Atan(Pow(a, IntegerNumber.negativeOne)),
        'sinh': Sinh.new,
        'cosh': Cosh.new,
        'tanh': Tanh.new,
        'sech': (a) => Pow(Cosh(a), IntegerNumber.negativeOne),
        'csch': (a) => Pow(Sinh(a), IntegerNumber.negativeOne),
        'coth': (a) => Cosh(a) / Sinh(a),
        'asinh': Asinh.new,
        'arcsinh': Asinh.new,
        'acosh': Acosh.new,
        'arccosh': Acosh.new,
        'atanh': Atanh.new,
        'arctanh': Atanh.new,
        'asech': (a) => Acosh(Pow(a, IntegerNumber.negativeOne)),
        'arcsech': (a) => Acosh(Pow(a, IntegerNumber.negativeOne)),
        'acsch': (a) => Asinh(Pow(a, IntegerNumber.negativeOne)),
        'arccsch': (a) => Asinh(Pow(a, IntegerNumber.negativeOne)),
        'acoth': (a) => Atanh(Pow(a, IntegerNumber.negativeOne)),
        'arccoth': (a) => Atanh(Pow(a, IntegerNumber.negativeOne)),
        'abs': Abs.new,
        'sqrt': (a) => Pow(a, FractionNumber.half),
        'exp': (a) => Pow(Constant.e, a),
        'ln': Ln.new,
        'log': Ln.new,
        'log2': (a) => Ln(a) / Ln(IntegerNumber.two),
        'log10': (a) => Ln(a) / Ln(IntegerNumber.of(10)),
        'erf': Erf.new,
        'erfc': Erfc.new,
        'gamma': Gamma.new,
        'factorial': Factorial.new,
        'floor': Floor.new,
        'ceil': Ceil.new,
        'round': Round.new,
        'sign': Sign.new,
        'sgn': Sign.new,
        're': Re.new,
        'im': Im.new,
        'arg': Arg.new,
        'conj': Conjugate.new,
        'conjugate': Conjugate.new,
        'lambertw': LambertW.new,
        'LambertW': LambertW.new,
        'W': LambertW.new,
        'w': LambertW.new,
        'O': _parseOrderTerm,
      });

  /// Standard 2-argument mathematical functions.
  static final Map<String, Expr Function(Expr, Expr)> standardBinaryFunctions =
      Map.unmodifiable(<String, Expr Function(Expr, Expr)>{
        'pow': Pow.new,
        'log': (a, b) => Ln(b) / Ln(a),
        'root': (a, b) => Pow(a, IntegerNumber.one / b),
        'beta': Beta.new,
        'binomial': Binomial.new,
        'nCr': Binomial.new,
        'mod': Mod.new,
        'gcd': _evalGcdBinary,
        'lcm': _evalLcmBinary,
        'lambertw': _parseLambertWBinary,
        'LambertW': _parseLambertWBinary,
        'W': _parseLambertWBinary,
        'w': _parseLambertWBinary,
        'integrate': (a, b) => _parseIntegralArgs([a, b]),
        'integral': (a, b) => _parseIntegralArgs([a, b]),
        'O': (a, b) => _parseOrderTermArgs([a, b]),
      });

  /// Standard variadic mathematical functions.
  static final Map<String, Expr Function(List<Expr>)>
  standardVariadicFunctions = Map.unmodifiable(
    <String, Expr Function(List<Expr>)>{
      'piecewise': _parsePiecewiseArgs,
      'Piecewise': _parsePiecewiseArgs,
      'integrate': _parseIntegralArgs,
      'integral': _parseIntegralArgs,
      'diff': _parseDerivativeArgs,
      'derivative': _parseDerivativeArgs,
      'limit': _parseLimitArgs,
      'sum': _parseSumArgs,
      'product': _parseProductArgs,
      'gcd': _evalGcdVariadic,
      'lcm': _evalLcmVariadic,
      'O': _parseOrderTermArgs,
    },
  );

  static const String _mathSymbols =
      '+-*/^ˆ\u0302‸＾()[]{},;:.=<>!&|~?@#\$%\\\'"`´¨˜−–×·÷≤≥≠²³⁴√';

  /// Registered named constants.
  final Map<String, Expr> constants;

  /// Registered 1-argument functions.
  final Map<String, Expr Function(Expr)> unaryFunctions;

  /// Registered 2-argument functions.
  final Map<String, Expr Function(Expr, Expr)> binaryFunctions;

  /// Registered variadic functions.
  final Map<String, Expr Function(List<Expr>)> variadicFunctions;

  /// Whether juxtaposition (`2x`, `3(x + 1)`, `(a + b)(c + d)`) is parsed as
  /// multiplication.
  final bool implicitMultiplication;

  /// Reusable untrimmed PetitParser [Parser] for identifier tokens.
  static final Parser<String> identifierTokenParser =
      _buildIdentifierTokenParser();

  /// Reusable untrimmed PetitParser [Parser] for numeric literals.
  static final Parser<Expr> numberTokenParser = _buildNumberTokenParser();

  /// Reusable unanchored PetitParser [Parser] for identifier tokens.
  late final Parser<String> identifierParser = identifierTokenParser.trim();

  /// Reusable unanchored PetitParser [Parser] for numeric literals.
  late final Parser<Expr> numberParser = numberTokenParser.trim();

  /// Reusable unanchored PetitParser [Parser] for [Expr] subexpressions.
  late final Parser<Expr> expressionParser = _buildExprParser();

  /// Underlying anchored PetitParser [Parser] for [Expr] strings.
  late final Parser<Expr> parser = expressionParser.end();

  /// Reusable unanchored PetitParser [Parser] for `[a, b, c]` [Vector] literals.
  late final Parser<Vector<Expr>> vectorElementParser =
      _buildBracketedExprList().map(
        (elements) => Vector<Expr>.fromList(elements, type: exprDataType),
      );

  /// Underlying anchored PetitParser [Parser] for `[a, b, c]` [Vector] literals.
  late final Parser<Vector<Expr>> vectorParser = vectorElementParser.end();

  /// Reusable unanchored PetitParser [Parser] for `[[a, b], [c, d]]` [Matrix] literals.
  late final Parser<Matrix<Expr>> matrixElementParser =
      _buildBracketedExprList()
          .plusSeparated(char(',').trim())
          .map((list) => list.elements)
          .skip(before: char('[').trim(), after: char(']').trim())
          .map(_createMatrix);

  /// Underlying anchored PetitParser [Parser] for `[[a, b], [c, d]]` [Matrix] literals.
  late final Parser<Matrix<Expr>> matrixParser = matrixElementParser.end();

  /// Parses [input] into an [Expr], throwing [FormatException] on syntax error.
  Expr parse(String input) => switch (parser.parse(input)) {
    Success(:final value) => value,
    Failure(:final message, :final position) => throw FormatException(
      message,
      input,
      position,
    ),
  };

  /// Parses [input] into an [Expr], or returns `null` if [input] is invalid.
  Expr? tryParse(String input) {
    try {
      return switch (parser.parse(input)) {
        Success(:final value) => value,
        Failure() => null,
      };
    } on FormatException {
      return null;
    }
  }

  /// Parses a bracketed vector literal `[a, b, c]` into a symbolic [Vector],
  /// throwing [FormatException] on syntax error.
  Vector<Expr> parseVector(String input) => switch (vectorParser.parse(input)) {
    Success(:final value) => value,
    Failure(:final message, :final position) => throw FormatException(
      message,
      input,
      position,
    ),
  };

  /// Parses a bracketed vector literal `[a, b, c]` into a symbolic [Vector],
  /// or returns `null` if [input] is invalid.
  Vector<Expr>? tryParseVector(String input) {
    try {
      return switch (vectorParser.parse(input)) {
        Success(:final value) => value,
        Failure() => null,
      };
    } on FormatException {
      return null;
    }
  }

  /// Parses a nested bracketed matrix literal `[[a, b], [c, d]]` into a
  /// symbolic [Matrix], throwing [FormatException] on syntax error or ragged rows.
  Matrix<Expr> parseMatrix(String input) => switch (matrixParser.parse(input)) {
    Success(:final value) => value,
    Failure(:final message, :final position) => throw FormatException(
      message,
      input,
      position,
    ),
  };

  /// Parses a nested bracketed matrix literal `[[a, b], [c, d]]` into a
  /// symbolic [Matrix], or returns `null` if [input] is invalid.
  Matrix<Expr>? tryParseMatrix(String input) {
    try {
      return switch (matrixParser.parse(input)) {
        Success(:final value) => value,
        Failure() => null,
      };
    } on FormatException {
      return null;
    }
  }

  Parser<List<Expr>> _buildBracketedExprList() => expressionParser
      .starSeparated(char(',').trim())
      .map((list) => list.elements)
      .skip(before: char('[').trim(), after: char(']').trim());

  static Parser<String> _buildIdentifierTokenParser() {
    final symbol = anyOf(_mathSymbols);
    final identifierStart = <Parser<String>>[
      whitespace(),
      digit(),
      symbol,
    ].toChoiceParser().neg(message: 'identifier expected');
    final identifierCont = <Parser<String>>[
      whitespace(),
      symbol,
    ].toChoiceParser().neg();
    return seq2(
      identifierStart,
      identifierCont.starString(),
    ).flatten(message: 'identifier expected');
  }

  static Parser<Expr> _buildNumberTokenParser() {
    final digits = digit().plusString();
    final fractional = seq2(char('.'), digit().starString());
    final exponent = seq3(anyOf('eE'), anyOf('+-').optional(), digits);
    return <Parser<Object>>[
      seq3(digits, fractional.optional(), exponent.optional()),
      seq3(char('.'), digits, exponent.optional()),
    ].toChoiceParser().flatten(message: 'number expected').map(_createNumber);
  }

  Parser<Expr> _buildExprParser() {
    final builder = ExpressionBuilder<Expr>();

    builder
      // Numbers
      ..primitive(numberParser)
      // Constants, variables, and functions
      ..primitive(
        seq2(
          identifierParser,
          builder.loopback
              .plusSeparated(char(',').trim())
              .map((list) => list.elements)
              .skip(before: char('(').trim(), after: char(')').trim())
              .optional(),
        ).map2(_createBinding),
      );

    // Parentheses (highest precedence wrapper)
    builder.group().wrapper(
      char('(').trim(),
      char(')').trim(),
      (_, value, _) => value,
    );

    // Postfix factorial (!, not followed by =)
    builder.group().postfix(
      seq2(char('!'), char('=').not()).trim(),
      (a, _) => Factorial(a),
    );

    // Exponentiation (right-associative)
    final caretOp = anyOf('^ˆ\u0302‸＾').trim();
    builder.group()
      ..right(seq2(caretOp, char('-').trim()), (a, _, b) => Pow(a, -b))
      ..right(seq2(caretOp, char('+').trim()), (a, _, b) => Pow(a, b))
      ..right(caretOp, (a, _, b) => Pow(a, b));

    // Unary prefix operators (+, -)
    builder.group()
      ..prefix(char('+').trim(), (_, a) => a)
      ..prefix(char('-').trim(), (_, a) => -a);

    // Multiplicative operators (*, /, and optional implicit juxtaposition)
    final mulGroup = builder.group()
      ..left(char('*').trim(), (a, _, b) => a * b)
      ..left(char('/').trim(), (a, _, b) => a / b);
    if (implicitMultiplication) {
      // Negative lookahead prevents implicit multiplication from consuming a
      // leading '+' or '-' as a unary prefix on the right operand (so 'a - b'
      // remains subtraction, not 'a * (-b)').
      mulGroup.left(
        anyOf('+-*/^ˆ\u0302‸＾)=<>!,;:]').trim().not(),
        (a, _, b) => a * b,
      );
    }

    // Additive operators (+, -, left-associative)
    builder.group()
      ..left(char('+').trim(), (a, _, b) => a + b)
      ..left(char('-').trim(), (a, _, b) => a - b);

    // Relational operators (<=, >=, !=, <, >, ==, =)
    builder.group()
      ..left(string('<=').trim(), (a, _, b) => LessEqual(a, b))
      ..left(string('>=').trim(), (a, _, b) => GreaterEqual(a, b))
      ..left(string('!=').trim(), (a, _, b) => NotEqual(a, b))
      ..left(char('<').trim(), (a, _, b) => LessThan(a, b))
      ..left(char('>').trim(), (a, _, b) => GreaterThan(a, b))
      ..left(
        <Parser<String>>[string('=='), char('=')].toChoiceParser().trim(),
        (a, _, b) => Equal(a, b),
      );

    return resolve(builder.build());
  }

  static Matrix<Expr> _createMatrix(List<List<Expr>> rows) {
    final cols = rows.first.length;
    for (var r = 1; r < rows.length; r++) {
      if (rows[r].length != cols) {
        throw FormatException(
          'Inconsistent matrix row lengths: row 0 has $cols columns, '
          'row $r has ${rows[r].length}',
        );
      }
    }
    return Matrix<Expr>.fromRows(rows, type: exprDataType);
  }

  Expr _createBinding(String name, List<Expr>? arguments) =>
      switch (arguments) {
        null => constants[name] ?? Variable(name),
        [final arg] when unaryFunctions.containsKey(name) =>
          unaryFunctions[name]!(arg),
        [final a, final b] when binaryFunctions.containsKey(name) =>
          binaryFunctions[name]!(a, b),
        final args when variadicFunctions.containsKey(name) =>
          variadicFunctions[name]!(args),
        final args => VariableFunction(name, args),
      };

  static Expr _createNumber(String value) {
    if (value.contains('.') || value.contains('e') || value.contains('E')) {
      return RealNumber.fromDouble(double.parse(value));
    }
    return IntegerNumber(Integer.parse(value));
  }

  static Expr _parseLambertWBinary(Expr a, Expr b) {
    if (b case IntegerNumber(asInt: final int branch && (0 || -1))) {
      return LambertW(a, branch: branch);
    }
    throw FormatException('LambertW branch must be 0 or -1, got: $b');
  }

  static Expr _parseOrderTerm(Expr arg) => switch (arg) {
    IntegerNumber(isOne: true) => const OrderTerm('x', 0),
    Variable(:final name) => OrderTerm(name, 1),
    Pow(
      base: Variable(:final name),
      exponent: IntegerNumber(asInt: final n?),
    ) =>
      OrderTerm(name, n),
    Pow(
      base: Add(terms: [Variable(:final name), final shift]),
      exponent: IntegerNumber(asInt: final n?),
    ) =>
      OrderTerm(name, n, point: -shift),
    Add(terms: [Variable(:final name), final shift]) => OrderTerm(
      name,
      1,
      point: -shift,
    ),
    _ => throw FormatException('Invalid OrderTerm syntax: O($arg)'),
  };

  static Expr _parseOrderTermArgs(List<Expr> args) => switch (args) {
    [final arg] => _parseOrderTerm(arg),
    [Variable(:final name), IntegerNumber(asInt: final n?)] => OrderTerm(
      name,
      n,
    ),
    [Variable(:final name), IntegerNumber(asInt: final n?), final point] =>
      OrderTerm(name, n, point: point),
    _ => throw FormatException(
      'Invalid OrderTerm syntax: O(${args.join(', ')})',
    ),
  };

  static Expr _parsePiecewiseArgs(List<Expr> args) {
    if (args.length < 2) {
      throw const FormatException(
        'piecewise requires at least 2 arguments (condition, expr)',
      );
    }
    final branches = <PiecewiseBranch>[];
    final pairCount = args.length ~/ 2;
    for (var i = 0; i < pairCount; i++) {
      final cond = args[2 * i];
      final val = args[2 * i + 1];
      if (cond is! RelationalExpr) {
        throw FormatException(
          'piecewise condition at argument ${2 * i + 1} must be a relational comparison, got: $cond',
        );
      }
      branches.add((relation: cond, expr: val));
    }
    final otherwise = args.length.isOdd ? args.last : null;
    return Piecewise(branches, otherwise: otherwise);
  }

  static Expr _parseIntegralArgs(List<Expr> args) => switch (args) {
    [final integrand, Variable(:final name)] => Integral(integrand, name),
    [final integrand, final v] when _asVariableName(v) != null => Integral(
      integrand,
      _asVariableName(v)!,
    ),
    [final integrand, Variable(:final name), final lower, final upper] =>
      Integral(integrand, name, lower: lower, upper: upper),
    [final integrand, final v, final lower, final upper]
        when _asVariableName(v) != null =>
      Integral(integrand, _asVariableName(v)!, lower: lower, upper: upper),
    [_, final invalidVar, ...] => throw FormatException(
      'integrate second argument must be a variable identifier, got: $invalidVar',
    ),
    _ => throw FormatException(
      'integrate requires 2 or 4 arguments, got ${args.length}',
    ),
  };

  static Expr _parseDerivativeArgs(List<Expr> args) => switch (args) {
    [final expr, Variable(:final name)] => Derivative(expr, name),
    [final expr, final v] when _asVariableName(v) != null => Derivative(
      expr,
      _asVariableName(v)!,
    ),
    [final expr, Variable(:final name), IntegerNumber(asInt: final order?)]
        when order >= 1 =>
      Derivative(expr, name, order: order),
    [final expr, final v, IntegerNumber(asInt: final order?)]
        when order >= 1 && _asVariableName(v) != null =>
      Derivative(expr, _asVariableName(v)!, order: order),
    [_, Variable(), final invalidOrder] => throw FormatException(
      'diff order must be a positive integer, got: $invalidOrder',
    ),
    [_, final invalidVar, ...] => throw FormatException(
      'diff second argument must be a variable identifier, got: $invalidVar',
    ),
    _ => throw FormatException(
      'diff requires 2 or 3 arguments, got ${args.length}',
    ),
  };

  static Expr _parseLimitArgs(List<Expr> args) => switch (args) {
    [final expr, Variable(:final name), final point] => Limit(
      expr,
      name,
      point,
    ),
    [final expr, final v, final point] when _asVariableName(v) != null => Limit(
      expr,
      _asVariableName(v)!,
      point,
    ),
    [final expr, Variable(:final name), final point, final dirExpr] => Limit(
      expr,
      name,
      point,
      direction: _parseLimitDirection(dirExpr),
    ),
    [final expr, final v, final point, final dirExpr]
        when _asVariableName(v) != null =>
      Limit(
        expr,
        _asVariableName(v)!,
        point,
        direction: _parseLimitDirection(dirExpr),
      ),
    [_, final invalidVar, ...] => throw FormatException(
      'limit second argument must be a variable identifier, got: $invalidVar',
    ),
    _ => throw FormatException(
      'limit requires 3 or 4 arguments, got ${args.length}',
    ),
  };

  static LimitDirection _parseLimitDirection(Expr dirExpr) => switch (dirExpr) {
    IntegerNumber(isZero: true) ||
    Variable(name: 'both') => LimitDirection.both,
    IntegerNumber(isOne: true) ||
    Variable(name: 'fromAbove' || 'right') => LimitDirection.fromAbove,
    IntegerNumber(isNegativeOne: true) ||
    Variable(name: 'fromBelow' || 'left') => LimitDirection.fromBelow,
    _ => throw FormatException(
      'Invalid limit direction: $dirExpr (expected -1, 0, 1, fromBelow, both, or fromAbove)',
    ),
  };

  static Expr _parseSumArgs(List<Expr> args) => switch (args) {
    [final expr, Variable(:final name), final lower, final upper] => Sum(
      expr,
      name,
      lower,
      upper,
    ),
    [final expr, final v, final lower, final upper]
        when _asVariableName(v) != null =>
      Sum(expr, _asVariableName(v)!, lower, upper),
    [_, final invalidVar, _, _] => throw FormatException(
      'sum second argument must be a variable identifier, got: $invalidVar',
    ),
    _ => throw FormatException('sum requires 4 arguments, got ${args.length}'),
  };

  static Expr _parseProductArgs(List<Expr> args) => switch (args) {
    [final expr, Variable(:final name), final lower, final upper] => Product(
      expr,
      name,
      lower,
      upper,
    ),
    [final expr, final v, final lower, final upper]
        when _asVariableName(v) != null =>
      Product(expr, _asVariableName(v)!, lower, upper),
    [_, final invalidVar, _, _] => throw FormatException(
      'product second argument must be a variable identifier, got: $invalidVar',
    ),
    _ => throw FormatException(
      'product requires 4 arguments, got ${args.length}',
    ),
  };

  static String? _asVariableName(Expr expr) => switch (expr) {
    Variable(:final name) => name,
    ComplexNumber(:final real, :final imaginary)
        when real.isZero && imaginary.isOne =>
      'i',
    Constant.e => 'e',
    Constant.pi => 'pi',
    _ => null,
  };

  static Expr _evalGcdBinary(Expr a, Expr b) {
    final sa = a.simplify();
    final sb = b.simplify();
    if (sa is RationalNumber && sb is RationalNumber) {
      return sa.gcd(sb);
    }
    return VariableFunction('gcd', [a, b]);
  }

  static Expr _evalLcmBinary(Expr a, Expr b) {
    final sa = a.simplify();
    final sb = b.simplify();
    if (sa is RationalNumber && sb is RationalNumber) {
      return sa.lcm(sb);
    }
    return VariableFunction('lcm', [a, b]);
  }

  static Expr _evalGcdVariadic(List<Expr> args) {
    if (args.isEmpty) {
      throw const FormatException('gcd requires at least 1 argument');
    }
    final current = args.first.simplify();
    if (current is! RationalNumber) {
      return VariableFunction('gcd', args);
    }
    var acc = current.abs();
    for (var i = 1; i < args.length; i++) {
      final next = args[i].simplify();
      if (next is! RationalNumber) {
        return VariableFunction('gcd', args);
      }
      acc = acc.gcd(next);
    }
    return acc;
  }

  static Expr _evalLcmVariadic(List<Expr> args) {
    if (args.isEmpty) {
      throw const FormatException('lcm requires at least 1 argument');
    }
    final current = args.first.simplify();
    if (current is! RationalNumber) {
      return VariableFunction('lcm', args);
    }
    var acc = current.abs();
    for (var i = 1; i < args.length; i++) {
      final next = args[i].simplify();
      if (next is! RationalNumber) {
        return VariableFunction('lcm', args);
      }
      acc = acc.lcm(next);
    }
    return acc;
  }
}
