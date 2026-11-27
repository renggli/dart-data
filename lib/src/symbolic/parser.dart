import 'package:petitparser/petitparser.dart';

import '../linear/matrix.dart';
import '../linear/vector.dart';
import 'algebra/orthogonal.dart';
import 'ast.dart';
import 'functions/fn.dart';
import 'type/expr_data_type.dart';

/// Metadata describing a built-in symbolic function in [ExprSyntax].
final class ExprFunctionInfo {
  /// Creates metadata for a built-in symbolic function.
  const new({
    required this.name,
    required this.params,
    required this.doc,
    this.category = 'elementary',
  });

  /// Canonical function name.
  final String name;

  /// Parameter names or signature descriptors (e.g. `['x']`, `['n', 'x']`).
  final List<String> params;

  /// Concise human-readable description of the function.
  final String doc;

  /// Logical category (e.g. `'elementary'`, `'trig'`, `'special'`, `'calculus'`).
  final String category;
}

/// Extensible case-sensitive syntax and parser for mathematical [Expr] strings.
///
/// Built-in mathematical functions use strictly one canonical name each (zero
/// default spelling or casing aliases). Callers needing domain-specific aliases
/// (for example SymPy, Rubi, or Mathematica corpora) may supply [aliases].
class ExprSyntax {
  /// Creates a syntax combining standard mathematical constants and functions
  /// with optional custom [constants], [aliases], [unaryFunctions],
  /// [binaryFunctions], and [variadicFunctions].
  new({
    Map<String, Expr> constants = const {},
    Map<String, FunctionSpec> aliases = const {},
    Map<String, Expr Function(Expr)> unaryFunctions = const {},
    Map<String, Expr Function(Expr, Expr)> binaryFunctions = const {},
    Map<String, Expr Function(List<Expr>)> variadicFunctions = const {},
    bool implicitMultiplication = false,
  }) : this.empty(
         constants: {...standardConstants, ...constants},
         aliases: {...aliases},
         unaryFunctions: {...standardUnaryFunctions, ...unaryFunctions},
         binaryFunctions: {...standardBinaryFunctions, ...binaryFunctions},
         variadicFunctions: {
           ...standardVariadicFunctions,
           ...variadicFunctions,
         },
         implicitMultiplication: implicitMultiplication,
       );

  /// Creates a syntax containing only explicitly supplied bindings.
  new empty({
    Map<String, Expr> constants = const {},
    Map<String, FunctionSpec> aliases = const {},
    Map<String, Expr Function(Expr)> unaryFunctions = const {},
    Map<String, Expr Function(Expr, Expr)> binaryFunctions = const {},
    Map<String, Expr Function(List<Expr>)> variadicFunctions = const {},
    this.implicitMultiplication = false,
  }) : constants = Map.unmodifiable(constants),
       aliases = Map.unmodifiable(aliases),
       unaryFunctions = Map.unmodifiable(unaryFunctions),
       binaryFunctions = Map.unmodifiable(binaryFunctions),
       variadicFunctions = Map.unmodifiable(variadicFunctions),
       _registryLookup = const {};

  new _standard()
    : constants = standardConstants,
      aliases = const {},
      unaryFunctions = standardUnaryFunctions,
      binaryFunctions = standardBinaryFunctions,
      variadicFunctions = standardVariadicFunctions,
      implicitMultiplication = false,
      _registryLookup = Fn.byName;

  /// Standard symbolic syntax with canonical built-in constants and functions.
  static final ExprSyntax standard = ExprSyntax._standard();

  /// Standard mathematical constants.
  static final Map<String, Expr> standardConstants = Map.unmodifiable(
    <String, Expr>{
      'pi': Constant.pi,
      'π': Constant.pi,
      'e': Constant.e,
      'i': ComplexNumber.i,
      'infinity': Constant.infinity,
      '∞': Constant.infinity,
      'undefined': Constant.undefined,
    },
  );

  /// Standard 1-argument canonical mathematical shorthand expansions and
  /// registry functions.
  static final Map<String, Expr Function(Expr)> standardUnaryFunctions =
      Map.unmodifiable(<String, Expr Function(Expr)>{
        for (final spec in Fn.registry)
          if (spec is UnaryFunctionSpec) spec.name: spec.call,
        'sec': (a) => Pow.of(Fn.cos(a), IntegerNumber.negativeOne),
        'csc': (a) => Pow.of(Fn.sin(a), IntegerNumber.negativeOne),
        'cot': (a) => Fn.cos(a) / Fn.sin(a),
        'asec': (a) => Fn.acos(Pow.of(a, IntegerNumber.negativeOne)),
        'acsc': (a) => Fn.asin(Pow.of(a, IntegerNumber.negativeOne)),
        'acot': (a) => Fn.atan(Pow.of(a, IntegerNumber.negativeOne)),
        'sech': (a) => Pow.of(Fn.cosh(a), IntegerNumber.negativeOne),
        'csch': (a) => Pow.of(Fn.sinh(a), IntegerNumber.negativeOne),
        'coth': (a) => Fn.cosh(a) / Fn.sinh(a),
        'asech': (a) => Fn.acosh(Pow.of(a, IntegerNumber.negativeOne)),
        'acsch': (a) => Fn.asinh(Pow.of(a, IntegerNumber.negativeOne)),
        'acoth': (a) => Fn.atanh(Pow.of(a, IntegerNumber.negativeOne)),
        'sqrt': (a) => Pow.of(a, FractionNumber.half),
        'cbrt': (a) => Pow.of(a, FractionNumber.third),
        'exp': (a) {
          final node = Pow.of(Constant.e, a);
          if (node is Pow) {
            _isExpFunction[node] = true;
          }
          return node;
        },
        'log2': (a) => Fn.ln(a) / Fn.ln(IntegerNumber.two),
        'log10': (a) => Fn.ln(a) / Fn.ln(IntegerNumber.of(10)),
      });

  /// Standard 2-argument canonical mathematical functions and shorthands.
  static final Map<String, Expr Function(Expr, Expr)> standardBinaryFunctions =
      Map.unmodifiable(<String, Expr Function(Expr, Expr)>{
        for (final spec in Fn.registry)
          if (spec is BinaryFunctionSpec) spec.name: spec.call,
        'pow': Pow.of,
        'log': (base, x) => Fn.ln(x) / Fn.ln(base),
        'root': (x, n) => Pow.of(x, IntegerNumber.one / n),
        'chebyshevT': (n, x) =>
            _parseOrthogonal('chebyshevT', n, x, chebyshevT),
        'chebyshevU': (n, x) =>
            _parseOrthogonal('chebyshevU', n, x, chebyshevU),
        'legendreP': (n, x) => _parseOrthogonal('legendreP', n, x, legendreP),
        'hermiteH': (n, x) => _parseOrthogonal('hermiteH', n, x, hermiteH),
        'hermiteHe': (n, x) => _parseOrthogonal('hermiteHe', n, x, hermiteHe),
      });

  /// Standard variadic and structural canonical mathematical forms.
  static final Map<String, Expr Function(List<Expr>)>
  standardVariadicFunctions = Map.unmodifiable(
    <String, Expr Function(List<Expr>)>{
      for (final spec in Fn.registry)
        if (spec is OptionalBinaryFunctionSpec ||
            spec is TernaryFunctionSpec ||
            spec is VariadicFunctionSpec)
          spec.name: (args) => _buildFromSpec(spec, args),
      'piecewise': _parsePiecewiseArgs,
      'integrate': _parseIntegralArgs,
      'diff': _parseDerivativeArgs,
      'limit': _parseLimitArgs,
      'sum': _parseSumArgs,
      'product': _parseProductArgs,
      'rootsum': _parseRootSumArgs,
      'O': _parseOrderTermArgs,
      'laguerreL': _parseLaguerreLArgs,
    },
  );

  /// Metadata for all standard canonical built-in symbolic functions.
  static final List<ExprFunctionInfo> standardFunctions = List.unmodifiable([
    for (final spec in Fn.registry)
      ExprFunctionInfo(
        name: spec.name,
        params: spec.params,
        doc: spec.doc,
        category: spec.category.name,
      ),
    const ExprFunctionInfo(
      name: 'sqrt',
      params: ['x'],
      doc: 'Principal square root',
    ),
    const ExprFunctionInfo(
      name: 'cbrt',
      params: ['x'],
      doc: 'Principal cube root',
    ),
    const ExprFunctionInfo(
      name: 'root',
      params: ['x', 'n'],
      doc: 'Principal n-th root of x',
    ),
    const ExprFunctionInfo(name: 'pow', params: ['x', 'y'], doc: 'Power x^y'),
    const ExprFunctionInfo(
      name: 'exp',
      params: ['x'],
      doc: 'Natural exponential e^x',
    ),
    const ExprFunctionInfo(
      name: 'log',
      params: ['base', 'x'],
      doc: 'Logarithm of x to base',
    ),
    const ExprFunctionInfo(
      name: 'log2',
      params: ['x'],
      doc: 'Base-2 logarithm',
    ),
    const ExprFunctionInfo(
      name: 'log10',
      params: ['x'],
      doc: 'Base-10 logarithm',
    ),
    const ExprFunctionInfo(
      name: 'sec',
      params: ['x'],
      doc: 'Secant 1/cos(x)',
      category: 'trig',
    ),
    const ExprFunctionInfo(
      name: 'csc',
      params: ['x'],
      doc: 'Cosecant 1/sin(x)',
      category: 'trig',
    ),
    const ExprFunctionInfo(
      name: 'cot',
      params: ['x'],
      doc: 'Cotangent cos(x)/sin(x)',
      category: 'trig',
    ),
    const ExprFunctionInfo(
      name: 'asec',
      params: ['x'],
      doc: 'Inverse secant',
      category: 'trig',
    ),
    const ExprFunctionInfo(
      name: 'acsc',
      params: ['x'],
      doc: 'Inverse cosecant',
      category: 'trig',
    ),
    const ExprFunctionInfo(
      name: 'acot',
      params: ['x'],
      doc: 'Inverse cotangent',
      category: 'trig',
    ),
    const ExprFunctionInfo(
      name: 'sech',
      params: ['x'],
      doc: 'Hyperbolic secant',
      category: 'hyperbolic',
    ),
    const ExprFunctionInfo(
      name: 'csch',
      params: ['x'],
      doc: 'Hyperbolic cosecant',
      category: 'hyperbolic',
    ),
    const ExprFunctionInfo(
      name: 'coth',
      params: ['x'],
      doc: 'Hyperbolic cotangent',
      category: 'hyperbolic',
    ),
    const ExprFunctionInfo(
      name: 'asech',
      params: ['x'],
      doc: 'Inverse hyperbolic secant',
      category: 'hyperbolic',
    ),
    const ExprFunctionInfo(
      name: 'acsch',
      params: ['x'],
      doc: 'Inverse hyperbolic cosecant',
      category: 'hyperbolic',
    ),
    const ExprFunctionInfo(
      name: 'acoth',
      params: ['x'],
      doc: 'Inverse hyperbolic cotangent',
      category: 'hyperbolic',
    ),
    const ExprFunctionInfo(
      name: 'chebyshevT',
      params: ['n', 'x'],
      doc: 'Chebyshev polynomial T_n(x)',
      category: 'orthogonal',
    ),
    const ExprFunctionInfo(
      name: 'chebyshevU',
      params: ['n', 'x'],
      doc: 'Chebyshev polynomial U_n(x)',
      category: 'orthogonal',
    ),
    const ExprFunctionInfo(
      name: 'legendreP',
      params: ['n', 'x'],
      doc: 'Legendre polynomial P_n(x)',
      category: 'orthogonal',
    ),
    const ExprFunctionInfo(
      name: 'hermiteH',
      params: ['n', 'x'],
      doc: 'Physicists Hermite polynomial H_n(x)',
      category: 'orthogonal',
    ),
    const ExprFunctionInfo(
      name: 'hermiteHe',
      params: ['n', 'x'],
      doc: 'Probabilists Hermite polynomial He_n(x)',
      category: 'orthogonal',
    ),
    const ExprFunctionInfo(
      name: 'laguerreL',
      params: ['n', 'x', '[alpha]'],
      doc: 'Laguerre polynomial L_n^(alpha)(x)',
      category: 'orthogonal',
    ),
    const ExprFunctionInfo(
      name: 'piecewise',
      params: ['cond1', 'expr1', '...', '[otherwise]'],
      doc: 'Piecewise expression',
      category: 'calculus',
    ),
    const ExprFunctionInfo(
      name: 'integrate',
      params: ['expr', 'x', '[a, b]'],
      doc: 'Symbolic integral',
      category: 'calculus',
    ),
    const ExprFunctionInfo(
      name: 'diff',
      params: ['expr', 'x', '[order, at]'],
      doc: 'Symbolic derivative',
      category: 'calculus',
    ),
    const ExprFunctionInfo(
      name: 'limit',
      params: ['expr', 'x', 'point', '[dir]'],
      doc: 'Symbolic limit',
      category: 'calculus',
    ),
    const ExprFunctionInfo(
      name: 'sum',
      params: ['expr', 'k', 'a', 'b'],
      doc: 'Symbolic summation',
      category: 'calculus',
    ),
    const ExprFunctionInfo(
      name: 'product',
      params: ['expr', 'k', 'a', 'b'],
      doc: 'Symbolic product',
      category: 'calculus',
    ),
    const ExprFunctionInfo(
      name: 'rootsum',
      params: ['poly', 't', 'body'],
      doc: 'Sum over polynomial roots',
      category: 'calculus',
    ),
    const ExprFunctionInfo(
      name: 'O',
      params: ['term'],
      doc: 'Big-O asymptotic order term',
      category: 'calculus',
    ),
  ]);

  /// Registered named constants.
  final Map<String, Expr> constants;

  /// Optional caller-supplied alias map from external name to canonical [FunctionSpec].
  final Map<String, FunctionSpec> aliases;

  /// Registered 1-argument functions.
  final Map<String, Expr Function(Expr)> unaryFunctions;

  /// Registered 2-argument functions.
  final Map<String, Expr Function(Expr, Expr)> binaryFunctions;

  /// Registered variadic functions.
  final Map<String, Expr Function(List<Expr>)> variadicFunctions;

  /// Whether juxtaposition (`2x`, `3(x + 1)`, `(a + b)(c + d)`) is parsed as
  /// multiplication.
  final bool implicitMultiplication;

  final Map<String, FunctionSpec> _registryLookup;

  /// Parser for identifier tokens without whitespace trimming.
  static final Parser<String> identifierTokenParser =
      _buildIdentifierTokenParser();

  /// Parser for number literal tokens without whitespace trimming.
  static final Parser<Expr> numberTokenParser = _buildNumberTokenParser();

  /// Underlying anchored PetitParser [Parser] for [Expr] strings.
  late final Parser<Expr> parser = _expressionParser.end();

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

  /// Parses a bracketed vector literal `[a, b, c]` into a symbolic [Vector].
  Vector<Expr> parseVector(String input) =>
      switch (_vectorParser.parse(input)) {
        Success(:final value) => value,
        Failure(:final message, :final position) => throw FormatException(
          message,
          input,
          position,
        ),
      };

  /// Parses a bracketed vector literal, returning `null` if invalid.
  Vector<Expr>? tryParseVector(String input) {
    try {
      return switch (_vectorParser.parse(input)) {
        Success(:final value) => value,
        Failure() => null,
      };
    } on FormatException {
      return null;
    }
  }

  /// Parses a nested bracketed matrix literal `[[a, b], [c, d]]`.
  Matrix<Expr> parseMatrix(String input) =>
      switch (_matrixParser.parse(input)) {
        Success(:final value) => value,
        Failure(:final message, :final position) => throw FormatException(
          message,
          input,
          position,
        ),
      };

  /// Parses a nested bracketed matrix literal, returning `null` if invalid.
  Matrix<Expr>? tryParseMatrix(String input) {
    try {
      return switch (_matrixParser.parse(input)) {
        Success(:final value) => value,
        Failure() => null,
      };
    } on FormatException {
      return null;
    }
  }

  static const String _mathSymbols =
      '+-*/^ˆ\u0302‸＾()[]{},;:.=<>!&|~?@#\$%\\\'"`´¨˜−–×·÷≤≥≠²³⁴√';

  late final Parser<String> _identifierParser = identifierTokenParser.trim();
  late final Parser<Expr> _numberParser = numberTokenParser.trim();
  late final Parser<Expr> _expressionParser = _buildExprParser();

  late final Parser<Vector<Expr>> _vectorElementParser =
      _buildBracketedExprList().map(
        (elements) => Vector<Expr>.fromList(elements, type: exprDataType),
      );
  late final Parser<Vector<Expr>> _vectorParser = _vectorElementParser.end();

  late final Parser<Matrix<Expr>> _matrixElementParser =
      _buildBracketedExprList()
          .plusSeparated(char(',').trim())
          .map((list) => list.elements)
          .skip(before: char('[').trim(), after: char(']').trim())
          .map(_createMatrix);
  late final Parser<Matrix<Expr>> _matrixParser = _matrixElementParser.end();

  Parser<List<Expr>> _buildBracketedExprList() => _expressionParser
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
      ..primitive(_numberParser)
      ..primitive(
        seq2(
          _identifierParser,
          builder.loopback
              .plusSeparated(char(',').trim())
              .map((list) => list.elements)
              .skip(before: char('(').trim(), after: char(')').trim())
              .optional(),
        ).map2(_createBinding),
      )
      ..primitive(
        builder.loopback
            .starSeparated(char(',').trim())
            .map<Expr>((list) => Fn.tuple(list.elements))
            .skip(before: char('[').trim(), after: char(']').trim()),
      );

    builder.group().wrapper(
      char('(').trim(),
      char(')').trim(),
      (_, value, _) => value,
    );

    builder.group().postfix(
      seq2(char('!'), char('=').not()).trim(),
      (a, _) => Fn.factorial(a),
    );

    final caretOp = <Parser<String>>[
      string('**'),
      anyOf('^ˆ\u0302‸＾'),
    ].toChoiceParser().trim();
    final unarySignList = anyOf('+-').trim().plus();
    builder.group()
      ..right(
        seq2(
          caretOp,
          unarySignList,
        ).map2((_, signs) => signs.where((s) => s == '-').length.isOdd),
        (a, isOddNeg, b) => Pow.of(a, isOddNeg ? -b : b),
      )
      ..right(caretOp, (a, _, b) => Pow.of(a, b));

    builder.group()
      ..prefix(char('+').trim(), (_, a) => a)
      ..prefix(char('-').trim(), (_, a) => -a);

    final mulGroup = builder.group()
      ..left(char('*').trim(), (a, _, b) => a * b)
      ..left(char('/').trim(), (a, _, b) => a / b);
    if (implicitMultiplication) {
      mulGroup.left(
        anyOf('+-*/^ˆ\u0302‸＾)=<>!,;:].').trim().not(),
        (a, _, b) => a * b,
      );
    }

    builder.group()
      ..left(char('+').trim(), (a, _, b) => a + b)
      ..left(char('-').trim(), (a, _, b) => a - b);

    builder.group()
      ..left(string('<=').trim(), (a, _, b) => Relational.lessEqual(a, b))
      ..left(string('>=').trim(), (a, _, b) => Relational.greaterEqual(a, b))
      ..left(string('!=').trim(), (a, _, b) => Relational.notEqual(a, b))
      ..left(char('<').trim(), (a, _, b) => Relational.lessThan(a, b))
      ..left(char('>').trim(), (a, _, b) => Relational.greaterThan(a, b))
      ..left(
        <Parser<String>>[string('=='), char('=')].toChoiceParser().trim(),
        (a, _, b) => Relational.equal(a, b),
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

  Expr _createBinding(String name, List<Expr>? arguments) {
    if (arguments == null) return constants[name] ?? Variable(name);
    if (arguments.length == 1) {
      if (unaryFunctions[name] case final fn?) return fn(arguments[0]);
    } else if (arguments.length == 2) {
      if (binaryFunctions[name] case final fn?) {
        return fn(arguments[0], arguments[1]);
      }
    }
    if (variadicFunctions[name] case final fn?) return fn(arguments);
    if (_registryLookup[name] ?? aliases[name] case final spec?) {
      return _buildFromSpec(spec, arguments);
    }
    return Call.symbolic(name, arguments);
  }

  static Expr _buildFromSpec(FunctionSpec spec, List<Expr> args) {
    switch (spec.id) {
      case FunctionId.lambertW:
        if (args.length == 1) return Fn.lambertW(args[0]);
        if (args.length == 2) {
          if (args[1] case IntegerNumber(asInt: final b && (0 || -1))) {
            return b == 0
                ? Fn.lambertW(args[0])
                : Fn.lambertW(args[0], args[1]);
          }
          throw FormatException(
            'lambertW branch must be 0 or -1, got: ${args[1]}',
          );
        }
        throw FormatException(
          'lambertW requires 1 or 2 arguments, got ${args.length}',
        );
      case FunctionId.ellipticPi:
        if (args.length == 2) {
          return Fn.ellipticPi(
            args[0],
            FractionNumber.half * Constant.pi,
            args[1],
          );
        }
        if (args.length == 3) return Fn.ellipticPi(args[0], args[1], args[2]);
        throw FormatException(
          'ellipticPi requires 2 or 3 arguments, got ${args.length}',
        );
      case FunctionId.hypergeometric:
        if (args.length != 3) {
          throw FormatException(
            'hypergeometric requires 3 arguments, got ${args.length}',
          );
        }
        final upper =
            args[0] is Call && (args[0] as Call).id == FunctionId.tuple
            ? args[0]
            : Fn.tuple([args[0]]);
        final lower =
            args[1] is Call && (args[1] as Call).id == FunctionId.tuple
            ? args[1]
            : Fn.tuple([args[1]]);
        return Fn.hypergeometric(upper, lower, args[2]);
      default:
        try {
          return spec.buildCall(args);
        } on ArgumentError catch (e) {
          throw FormatException(e.message?.toString() ?? e.toString());
        }
    }
  }

  static Expr _createNumber(String value) {
    if (value.contains('.') || value.contains('e') || value.contains('E')) {
      return RealNumber.fromDouble(double.parse(value));
    }
    return IntegerNumber.parse(value);
  }

  static Expr _parseOrderTerm(Expr arg) {
    if (arg is IntegerNumber && arg.isOne) return OrderTerm('x', 0);
    final (Expr baseExpr, int order) = switch (arg) {
      Pow(:final base, exponent: IntegerNumber(asInt: final n?)) => (base, n),
      _ => (arg, 1),
    };
    return switch (baseExpr) {
      Variable(:final name) => OrderTerm(name, order),
      Pow(
        base: Variable(:final name),
        exponent: IntegerNumber(asInt: final m?),
      ) =>
        OrderTerm(name, m * order),
      Add(terms: [final first, final second]) => switch ((first, second)) {
        (Variable(:final name), final shift) => OrderTerm(
          name,
          order,
          point: -shift,
        ),
        (
          final shift,
          Mul(
            factors: [
              IntegerNumber(isNegativeOne: true),
              Variable(:final name),
            ],
          ),
        ) =>
          OrderTerm(name, order, point: shift),
        (
          Mul(
            factors: [
              IntegerNumber(isNegativeOne: true),
              Variable(:final name),
            ],
          ),
          final shift,
        ) =>
          OrderTerm(name, order, point: shift),
        (final Expr a, Variable(:final name)) => OrderTerm(
          name,
          order,
          point: -a,
        ),
        _ => throw FormatException('Invalid OrderTerm syntax: O($arg)'),
      },
      _ => throw FormatException('Invalid OrderTerm syntax: O($arg)'),
    };
  }

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
      if (cond is! Relational) {
        throw FormatException(
          'piecewise condition at argument ${2 * i + 1} must be a relational comparison, got: $cond',
        );
      }
      branches.add((relation: cond, expr: val));
    }
    final otherwise = args.length.isOdd ? args.last : null;
    return Piecewise(branches, otherwise: otherwise);
  }

  static Expr _parseIntegralArgs(List<Expr> args) {
    if (args case [final integrand, final v]) {
      final vName = _asVariableName(v);
      if (vName != null) {
        return Integral(_unbindConstant(integrand, v, vName), vName);
      }
      throw FormatException(
        'integrate second argument must be a variable identifier, got: $v',
      );
    }
    if (args case [final integrand, final v, final lower, final upper]) {
      final vName = _asVariableName(v);
      if (vName != null) {
        return Integral(
          _unbindConstant(integrand, v, vName),
          vName,
          lower: lower,
          upper: upper,
        );
      }
      throw FormatException(
        'integrate second argument must be a variable identifier, got: $v',
      );
    }
    throw FormatException(
      'integrate requires 2 or 4 arguments, got ${args.length}',
    );
  }

  static Expr _parseDerivativeArgs(List<Expr> args) {
    if (args case [final expr, final v]) {
      final vName = _asVariableName(v);
      if (vName != null) {
        return Derivative(_unbindConstant(expr, v, vName), vName);
      }
      throw FormatException(
        'diff second argument must be a variable identifier, got: $v',
      );
    }
    if (args case [final expr, final v, final orderExpr]) {
      final vName = _asVariableName(v);
      if (vName == null) {
        throw FormatException(
          'diff second argument must be a variable identifier, got: $v',
        );
      }
      if (orderExpr case IntegerNumber(asInt: final order?) when order >= 1) {
        return Derivative(_unbindConstant(expr, v, vName), vName, order: order);
      }
      throw FormatException(
        'diff order must be a positive integer, got: $orderExpr',
      );
    }
    if (args case [final expr, final v, final orderExpr, final point]) {
      final vName = _asVariableName(v);
      if (vName == null) {
        throw FormatException(
          'diff second argument must be a variable identifier, got: $v',
        );
      }
      if (orderExpr case IntegerNumber(asInt: final order?) when order >= 1) {
        return Derivative(
          _unbindConstant(expr, v, vName),
          vName,
          order: order,
          point: point,
        );
      }
      throw FormatException(
        'diff order must be a positive integer, got: $orderExpr',
      );
    }
    throw FormatException(
      'diff requires 2, 3, or 4 arguments, got ${args.length}',
    );
  }

  static Expr _parseLimitArgs(List<Expr> args) {
    if (args case [final expr, final v, final point]) {
      final vName = _asVariableName(v);
      if (vName != null) {
        return Limit(_unbindConstant(expr, v, vName), vName, point);
      }
      throw FormatException(
        'limit second argument must be a variable identifier, got: $v',
      );
    }
    if (args case [final expr, final v, final point, final dirExpr]) {
      final vName = _asVariableName(v);
      if (vName != null) {
        return Limit(
          _unbindConstant(expr, v, vName),
          vName,
          point,
          direction: _parseLimitDirection(dirExpr),
        );
      }
      throw FormatException(
        'limit second argument must be a variable identifier, got: $v',
      );
    }
    throw FormatException(
      'limit requires 3 or 4 arguments, got ${args.length}',
    );
  }

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

  static Expr _parseSumArgs(List<Expr> args) {
    if (args case [final expr, final v, final lower, final upper]) {
      final vName = _asVariableName(v);
      if (vName != null) {
        return Sum(_unbindConstant(expr, v, vName), vName, lower, upper);
      }
      throw FormatException(
        'sum second argument must be a variable identifier, got: $v',
      );
    }
    throw FormatException('sum requires 4 arguments, got ${args.length}');
  }

  static Expr _parseProductArgs(List<Expr> args) {
    if (args case [final expr, final v, final lower, final upper]) {
      final vName = _asVariableName(v);
      if (vName != null) {
        return Product(_unbindConstant(expr, v, vName), vName, lower, upper);
      }
      throw FormatException(
        'product second argument must be a variable identifier, got: $v',
      );
    }
    throw FormatException('product requires 4 arguments, got ${args.length}');
  }

  static Expr _parseRootSumArgs(List<Expr> args) {
    if (args case [final polynomial, final v, final body]) {
      final vName = _asVariableName(v);
      if (vName != null) {
        return RootSum(
          _unbindConstant(polynomial, v, vName),
          vName,
          _unbindConstant(body, v, vName),
        );
      }
      throw FormatException(
        'rootsum second argument must be a variable identifier, got: $v',
      );
    }
    throw FormatException('rootsum requires 3 arguments, got ${args.length}');
  }

  static final Expando<bool> _isExpFunction = Expando<bool>('isExpFunction');

  static Expr _unbindConstant(Expr expr, Expr varToken, String varName) {
    if (varToken is Variable) return expr;
    Expr visit(Expr node) {
      if (node == varToken) return Variable(varName);
      if (varName == 'i' && node is ComplexNumber) {
        final imagExpr = switch (node.imaginary) {
          IntegerNumber(isOne: true) => Variable(varName),
          IntegerNumber(isNegativeOne: true) => -Variable(varName),
          _ => node.imaginary * Variable(varName),
        };
        return node.real.isZero ? imagExpr : node.real + imagExpr;
      }
      if (varName == 'e' && node is Pow && node.base == Constant.e) {
        if (_isExpFunction[node] == true) {
          final res = Pow.of(Constant.e, visit(node.exponent));
          if (res is Pow) {
            _isExpFunction[res] = true;
          }
          return res;
        }
        return Pow.of(visit(node.base), visit(node.exponent));
      }
      if (node
          case Integral(
            :final integrand,
            :final variable,
            lower: final low?,
            upper: final up?,
          )
          when variable == varName) {
        return Integral(
          integrand,
          variable,
          lower: visit(low),
          upper: visit(up),
        );
      }
      if (node
          case Derivative(
            :final expr,
            :final variable,
            :final order,
            point: final pt?,
          )
          when variable == varName) {
        return Derivative(expr, variable, order: order, point: visit(pt));
      }
      if (node is Limit && node.variable == varName) {
        return Limit(
          node.expr,
          node.variable,
          visit(node.point),
          direction: node.direction,
        );
      }
      if (node is Sum && node.variable == varName) {
        return Sum(
          node.expr,
          node.variable,
          visit(node.lower),
          visit(node.upper),
        );
      }
      if (node is Product && node.variable == varName) {
        return Product(
          node.expr,
          node.variable,
          visit(node.lower),
          visit(node.upper),
        );
      }
      if (node is RootSum && node.variable == varName) {
        return node;
      }
      return node.mapChildren(visit);
    }

    return visit(expr);
  }

  static String? _asVariableName(Expr expr) => switch (expr) {
    Variable(:final name) => name,
    ComplexNumber(:final real, :final imaginary)
        when real.isZero && imaginary.isOne =>
      'i',
    Constant.e => 'e',
    Constant.pi => 'pi',
    _ => null,
  };

  static Expr _parseOrthogonal(
    String name,
    Expr nExpr,
    Expr x,
    Expr Function(int, Expr) builder,
  ) {
    if (nExpr case IntegerNumber(asInt: final n?) when n >= 0) {
      return builder(n, x);
    }
    throw FormatException(
      '$name degree must be a non-negative integer, got: $nExpr',
    );
  }

  static Expr _parseLaguerreLArgs(List<Expr> args) => switch (args) {
    [final nExpr, final x] => _parseOrthogonal(
      'laguerreL',
      nExpr,
      x,
      laguerreL,
    ),
    [final nExpr, final x, final alpha] => switch (nExpr) {
      IntegerNumber(asInt: final n?) when n >= 0 => laguerreL(n, x, alpha),
      _ => throw FormatException(
        'laguerreL degree must be a non-negative integer, got: $nExpr',
      ),
    },
    _ => throw FormatException(
      'laguerreL requires 2 or 3 arguments, got ${args.length}',
    ),
  };
}
