import 'package:petitparser/petitparser.dart' as pp;

import 'ast.dart';

/// Extensible syntax and parser for mathematical [Expr] strings.
///
/// Use [ExprSyntax.standard] for the default grammar, or customize constants,
/// variable bindings, functions, and implicit multiplication via
/// [ExprSyntaxBuilder].
class ExprSyntax {
  new _({
    required Map<String, Expr> constants,
    required Map<String, Expr> variables,
    required Map<String, Expr Function(Expr)> unaryFunctions,
    required Map<String, Expr Function(Expr, Expr)> binaryFunctions,
    required Map<String, Expr Function(List<Expr>)> variadicFunctions,
    required this.implicitMultiplication,
    required this.caseInsensitiveConstants,
    required this.caseInsensitiveFunctions,
  }) : _constants = Map.unmodifiable(constants),
       _variables = Map.unmodifiable(variables),
       _unaryFunctions = Map.unmodifiable(unaryFunctions),
       _binaryFunctions = Map.unmodifiable(binaryFunctions),
       _variadicFunctions = Map.unmodifiable(variadicFunctions) {
    _parser = _buildParser();
  }

  /// Creates the standard symbolic syntax with built-in constants (`pi`, `π`,
  /// `e`, `i`, `infinity`, `∞`) and elementary/special functions.
  factory standard() => _standard;

  static final ExprSyntax _standard = ExprSyntaxBuilder.standard().build();

  final Map<String, Expr> _constants;
  final Map<String, Expr> _variables;
  final Map<String, Expr Function(Expr)> _unaryFunctions;
  final Map<String, Expr Function(Expr, Expr)> _binaryFunctions;
  final Map<String, Expr Function(List<Expr>)> _variadicFunctions;

  /// Whether adjacent tokens such as `2x`, `2(x + 1)`, or `(x + 1)(x - 1)` are
  /// parsed as multiplication.
  final bool implicitMultiplication;

  /// Whether constant lookup is case-insensitive.
  final bool caseInsensitiveConstants;

  /// Whether function lookup is case-insensitive.
  final bool caseInsensitiveFunctions;

  late final pp.Parser<Expr> _parser;

  /// Returns a new [ExprSyntaxBuilder] initialized with this syntax's rules.
  ExprSyntaxBuilder toBuilder() => ExprSyntaxBuilder._from(this);

  /// Parses [input] into an [Expr], throwing [FormatException] on syntax error.
  Expr parse(String input) {
    final result = _parser.parse(input);
    if (result is pp.Failure) {
      throw FormatException(result.message, input, result.position);
    }
    return result.value;
  }

  /// Parses [input] into an [Expr], or returns `null` if [input] is invalid.
  Expr? tryParse(String input) {
    try {
      final result = _parser.parse(input);
      return result is pp.Success<Expr> ? result.value : null;
    } on Object {
      return null;
    }
  }

  pp.Parser<Expr> _buildParser() {
    final builder = pp.ExpressionBuilder<Expr>();

    // Identifier: [a-zA-Z_\u0370-\u03FF][a-zA-Z0-9_\u0370-\u03FF]* | ∞
    final startChar =
        pp.pattern('a-zA-Z_\u0370-\u03FF') | pp.char('\u221E'); // Greek + ∞
    final contChar = pp.pattern('a-zA-Z0-9_\u0370-\u03FF');
    final identifier = (startChar & contChar.star()).flatten().trim();

    // Numeric literal: integer or floating-point with optional exponent
    final digits = pp.digit().plus();
    final fractional = pp.char('.') & pp.digit().star();
    final exponent =
        (pp.char('e') | pp.char('E')) &
        (pp.char('+') | pp.char('-')).optional() &
        digits;
    final numberLexeme =
        ((digits & fractional.optional() & exponent.optional()) |
                (pp.char('.') & digits & exponent.optional()))
            .flatten()
            .trim();

    final number = numberLexeme.map<Expr>((value) {
      if (value.contains('.') || value.contains('e') || value.contains('E')) {
        return RealNumber.fromDouble(double.parse(value));
      }
      return IntegerNumber(Integer.parse(value));
    });

    final exprRef = pp.undefined<Expr>();

    final argList = exprRef.plusSeparated(pp.char(',').trim());
    final functionCall =
        (identifier & pp.char('(').trim() & argList & pp.char(')').trim()).map<
          Expr
        >((values) {
          final rawName = values[0] as String;
          final key = caseInsensitiveFunctions
              ? rawName.toLowerCase()
              : rawName;
          final sepList = values[2] as pp.SeparatedList<Expr, String>;
          final args = sepList.elements;

          if (rawName == 'O') {
            if (args case [final arg]) {
              return _parseOrderTerm(arg);
            }
          }

          final variadic =
              _variadicFunctions[rawName] ?? _variadicFunctions[key];
          if (variadic != null) {
            return variadic(args);
          }

          switch (args) {
            case [final arg]:
              final unary = _unaryFunctions[rawName] ?? _unaryFunctions[key];
              if (unary != null) return unary(arg);
              throw FormatException('Unknown unary function: "$rawName"');
            case [final a, final b]:
              final binary = _binaryFunctions[rawName] ?? _binaryFunctions[key];
              if (binary != null) return binary(a, b);
              throw FormatException('Unknown binary function: "$rawName"');
            default:
              throw FormatException(
                'Unsupported number of arguments (${args.length}) for function "$rawName"',
              );
          }
        });

    final variableOrConstant = identifier.map<Expr>((name) {
      final variableHit = _variables[name];
      if (variableHit != null) return variableHit;

      final directConstant = _constants[name];
      if (directConstant != null) return directConstant;

      if (caseInsensitiveConstants && name != 'i' && name != 'I') {
        final lowerConstant = _constants[name.toLowerCase()];
        if (lowerConstant != null) return lowerConstant;
      }

      return Variable(name);
    });

    final parenthesized = (pp.char('(').trim() & exprRef & pp.char(')').trim())
        .map<Expr>((values) => values[1] as Expr);

    final primary = <pp.Parser<Expr>>[
      functionCall,
      number,
      variableOrConstant,
      parenthesized,
    ].toChoiceParser();

    // 1. Exponentiation (right-associative, highest precedence; allows signed exponents like x^-2)
    final power = pp.undefined<Expr>();
    final signedExponent =
        ((pp.char('+').trim() | pp.char('-').trim()).star() & power).map<Expr>((
          values,
        ) {
          final ops = (values[0] as List<dynamic>).cast<String>();
          var result = values[1] as Expr;
          for (var i = ops.length - 1; i >= 0; i--) {
            if (ops[i] == '-') {
              result = -result;
            }
          }
          return result;
        });
    power.set(
      (primary & (pp.char('^').trim() & signedExponent).optional()).map<Expr>((
        values,
      ) {
        final base = values[0] as Expr;
        final tail = values[1] as List<dynamic>?;
        if (tail == null) return base;
        return Pow(base, tail[1] as Expr);
      }),
    );

    // 1b. Optional implicit multiplication (e.g. 2x, 2(x+1), (a)(b))
    final factor = implicitMultiplication
        ? power.plus().map<Expr>((factors) => factors.reduce((a, b) => a * b))
        : power;

    builder.primitive(factor);

    // 2. Unary prefix operators (+, -)
    builder.group()
      ..prefix(pp.char('-').trim(), (op, a) => -a)
      ..prefix(pp.char('+').trim(), (op, a) => a);

    // 3. Multiplicative operators (*, / left-associative)
    builder.group()
      ..left(pp.char('*').trim(), (a, op, b) => a * b)
      ..left(pp.char('/').trim(), (a, op, b) => a / b);

    // 4. Additive operators (+, - left-associative)
    builder.group()
      ..left(pp.char('+').trim(), (a, op, b) => a + b)
      ..left(pp.char('-').trim(), (a, op, b) => a - b);

    // 5. Relational operators (<, <=, >, >=, ==, = left-associative)
    builder.group()
      ..left(pp.string('<=').trim(), (a, op, b) => LessEqual(a, b))
      ..left(pp.string('>=').trim(), (a, op, b) => GreaterEqual(a, b))
      ..left(pp.string('==').trim(), (a, op, b) => Equal(a, b))
      ..left(pp.char('<').trim(), (a, op, b) => LessThan(a, b))
      ..left(pp.char('>').trim(), (a, op, b) => GreaterThan(a, b))
      ..left(pp.char('=').trim(), (a, op, b) => Equal(a, b));

    final built = builder.build();
    exprRef.set(built);
    return built.end();
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

  static Expr _parsePiecewiseArgs(String rawName, List<Expr> args) {
    if (args.length < 2) {
      throw FormatException(
        '$rawName requires at least 2 arguments (condition, expr)',
      );
    }
    final branches = <(RelationalExpr, Expr)>[];
    final pairCount = args.length ~/ 2;
    for (var i = 0; i < pairCount; i++) {
      final cond = args[2 * i];
      final val = args[2 * i + 1];
      if (cond is! RelationalExpr) {
        throw FormatException(
          '$rawName condition at argument ${2 * i + 1} must be a relational comparison, got: $cond',
        );
      }
      branches.add((cond, val));
    }
    final otherwise = args.length.isOdd ? args.last : null;
    return Piecewise(branches, otherwise: otherwise);
  }
}

/// Builder for configuring custom [ExprSyntax] instances.
class ExprSyntaxBuilder {
  /// Creates an empty builder with no predefined constants or functions.
  new empty();

  /// Creates a builder pre-populated with the standard symbolic constants and
  /// elementary/special functions.
  factory standard() {
    final builder = ExprSyntaxBuilder.empty()
      ..defineConstant('pi', Constant.pi, aliases: const ['π'])
      ..defineConstant('e', Constant.e)
      ..defineConstant('i', ComplexNumber.i)
      ..defineConstant('infinity', Constant.infinity, aliases: const ['∞'])
      ..defineUnaryFunction('sin', Sin.new)
      ..defineUnaryFunction('cos', Cos.new)
      ..defineUnaryFunction('tan', Tan.new)
      ..defineUnaryFunction('asin', Asin.new, aliases: const ['arcsin'])
      ..defineUnaryFunction('acos', Acos.new, aliases: const ['arccos'])
      ..defineUnaryFunction('atan', Atan.new, aliases: const ['arctan'])
      ..defineUnaryFunction('sinh', Sinh.new)
      ..defineUnaryFunction('cosh', Cosh.new)
      ..defineUnaryFunction('tanh', Tanh.new)
      ..defineUnaryFunction('asinh', Asinh.new, aliases: const ['arcsinh'])
      ..defineUnaryFunction('acosh', Acosh.new, aliases: const ['arccosh'])
      ..defineUnaryFunction('atanh', Atanh.new, aliases: const ['arctanh'])
      ..defineUnaryFunction('abs', Abs.new)
      ..defineUnaryFunction('sqrt', (a) => Pow(a, FractionNumber.half))
      ..defineUnaryFunction('exp', (a) => Pow(Constant.e, a))
      ..defineUnaryFunction('ln', Ln.new, aliases: const ['log'])
      ..defineUnaryFunction('erf', Erf.new)
      ..defineUnaryFunction('erfc', Erfc.new)
      ..defineUnaryFunction('gamma', Gamma.new)
      ..defineUnaryFunction('lambertw', LambertW.new, aliases: const ['w'])
      ..defineBinaryFunction('pow', Pow.new)
      ..defineBinaryFunction('log', (a, b) => Ln(b) / Ln(a))
      ..defineBinaryFunction('root', (a, b) => Pow(a, IntegerNumber.one / b))
      ..defineBinaryFunction('beta', Beta.new)
      ..defineBinaryFunction('lambertw', (a, b) {
        if (b case IntegerNumber(asInt: final int branch && (0 || -1))) {
          return LambertW(a, branch: branch);
        }
        throw FormatException('LambertW branch must be 0 or -1, got: $b');
      }, aliases: const ['w'])
      ..defineVariadicFunction(
        'piecewise',
        (args) => ExprSyntax._parsePiecewiseArgs('piecewise', args),
      );
    return builder;
  }

  new _from(ExprSyntax syntax)
    : implicitMultiplication = syntax.implicitMultiplication,
      caseInsensitiveConstants = syntax.caseInsensitiveConstants,
      caseInsensitiveFunctions = syntax.caseInsensitiveFunctions {
    _constants.addAll(syntax._constants);
    _variables.addAll(syntax._variables);
    _unaryFunctions.addAll(syntax._unaryFunctions);
    _binaryFunctions.addAll(syntax._binaryFunctions);
    _variadicFunctions.addAll(syntax._variadicFunctions);
  }

  final Map<String, Expr> _constants = {};
  final Map<String, Expr> _variables = {};
  final Map<String, Expr Function(Expr)> _unaryFunctions = {};
  final Map<String, Expr Function(Expr, Expr)> _binaryFunctions = {};
  final Map<String, Expr Function(List<Expr>)> _variadicFunctions = {};

  /// Whether adjacent tokens are parsed as multiplication.
  bool implicitMultiplication = false;

  /// Whether constant lookup is case-insensitive.
  bool caseInsensitiveConstants = true;

  /// Whether function lookup is case-insensitive.
  bool caseInsensitiveFunctions = true;

  /// Registers or replaces a named constant (and optional [aliases]) resolving
  /// to [expr].
  void defineConstant(
    String name,
    Expr expr, {
    Iterable<String> aliases = const [],
  }) {
    _constants[name] = expr;
    if (caseInsensitiveConstants && name != 'i' && name != 'I') {
      _constants[name.toLowerCase()] = expr;
    }
    for (final alias in aliases) {
      _constants[alias] = expr;
      if (caseInsensitiveConstants && alias != 'i' && alias != 'I') {
        _constants[alias.toLowerCase()] = expr;
      }
    }
  }

  /// Removes a constant binding so [name] parses as a [Variable].
  void removeConstant(String name) {
    _constants.remove(name);
    _constants.remove(name.toLowerCase());
  }

  /// Clears all registered constants.
  void clearConstants() => _constants.clear();

  /// Binds an identifier [name] (such as `'r0'` or `'ans'`) to [expr] at parse
  /// time.
  void defineVariable(String name, Expr expr) {
    _variables[name] = expr;
  }

  /// Removes a bound variable [name].
  void removeVariable(String name) {
    _variables.remove(name);
  }

  /// Clears all bound variables.
  void clearVariables() => _variables.clear();

  /// Registers or replaces a 1-argument function [name].
  void defineUnaryFunction(
    String name,
    Expr Function(Expr arg) builder, {
    Iterable<String> aliases = const [],
  }) {
    _unaryFunctions[name] = builder;
    _unaryFunctions[name.toLowerCase()] = builder;
    for (final alias in aliases) {
      _unaryFunctions[alias] = builder;
      _unaryFunctions[alias.toLowerCase()] = builder;
    }
  }

  /// Registers or replaces a 2-argument function [name].
  void defineBinaryFunction(
    String name,
    Expr Function(Expr a, Expr b) builder, {
    Iterable<String> aliases = const [],
  }) {
    _binaryFunctions[name] = builder;
    _binaryFunctions[name.toLowerCase()] = builder;
    for (final alias in aliases) {
      _binaryFunctions[alias] = builder;
      _binaryFunctions[alias.toLowerCase()] = builder;
    }
  }

  /// Registers or replaces a variadic function [name].
  void defineVariadicFunction(
    String name,
    Expr Function(List<Expr> args) builder, {
    Iterable<String> aliases = const [],
  }) {
    _variadicFunctions[name] = builder;
    _variadicFunctions[name.toLowerCase()] = builder;
    for (final alias in aliases) {
      _variadicFunctions[alias] = builder;
      _variadicFunctions[alias.toLowerCase()] = builder;
    }
  }

  /// Removes all function bindings with [name].
  void removeFunction(String name) {
    final lower = name.toLowerCase();
    _unaryFunctions
      ..remove(name)
      ..remove(lower);
    _binaryFunctions
      ..remove(name)
      ..remove(lower);
    _variadicFunctions
      ..remove(name)
      ..remove(lower);
  }

  /// Builds an immutable [ExprSyntax] from the current configuration.
  ExprSyntax build() => ExprSyntax._(
    constants: _constants,
    variables: _variables,
    unaryFunctions: _unaryFunctions,
    binaryFunctions: _binaryFunctions,
    variadicFunctions: _variadicFunctions,
    implicitMultiplication: implicitMultiplication,
    caseInsensitiveConstants: caseInsensitiveConstants,
    caseInsensitiveFunctions: caseInsensitiveFunctions,
  );
}
