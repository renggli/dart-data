import 'dart:math' as math;

import 'package:data/symbolic.dart';
import 'package:petitparser/petitparser.dart';

import 'ast.dart';

/// Structured parse error with a 0-based character [offset] and an optional
/// quick-fix [suggestion].
final class CalcParseException implements FormatException {
  const new(this.message, {this.source, this.offset, this.suggestion});

  @override
  final String message;

  @override
  final String? source;

  @override
  final int? offset;

  final String? suggestion;

  @override
  String toString() {
    final pos = offset != null ? ' (at column ${offset! + 1})' : '';
    final hint = suggestion != null ? ' — $suggestion' : '';
    return 'Syntax error$pos: $message$hint';
  }
}

/// PetitParser `GrammarDefinition` for the calculator input language (shared
/// across Scroll and RPN modes), reusing the core `ExprSyntax` rules.
class CalcGrammarDefinition extends GrammarDefinition<CalcStatement> {
  new({this.implicitMultiplication = true});

  final bool implicitMultiplication;

  static const Set<String> _reservedNames = {
    'pi',
    'π',
    'e',
    'i',
    'infinity',
    '∞',
    'r',
  };

  static Parser<String> get _hWs => anyOf(' \t');

  @override
  Parser<CalcStatement> start() => ref0(multiStatement).end();

  /// Multiple statements separated by `;` or newlines.
  Parser<CalcStatement> multiStatement() =>
      ref0(singleStatement)
          .plusSeparated(anyOf(';\r\n').trim(_hWs).plus())
          .trim(anyOf(' \t\r\n;'))
          .map(
            (list) => list.elements.length == 1
                ? list.elements.first
                : MultiStatement(list.elements),
          );

  /// Single statement: function definition, variable assignment, or expression.
  Parser<CalcStatement> singleStatement() => <Parser<CalcStatement>>[
    ref0(functionDefinition),
    ref0(assignmentStatement),
    ref0(evalStatement),
  ].toChoiceParser();

  /// `name(p1, p2, ...) := body`
  Parser<FunctionDefStatement> functionDefinition() =>
      seq4(
        ref0(identifier),
        ref0(identifier)
            .starSeparated(char(',').trim(_hWs))
            .map((list) => list.elements)
            .skip(before: char('(').trim(_hWs), after: char(')').trim(_hWs)),
        string(':=').trim(_hWs),
        ref0(expression),
      ).map4((name, params, _, body) {
        if (_reservedNames.contains(name)) {
          throw CalcParseException(
            'Cannot redefine reserved symbol "$name"',
            offset: 0,
          );
        }
        return FunctionDefStatement(name, params, body);
      });

  /// `name := rhs`
  Parser<AssignmentStatement> assignmentStatement() =>
      seq3(ref0(identifier), string(':=').trim(_hWs), ref0(expression)).map3((
        name,
        _,
        rhs,
      ) {
        if (_reservedNames.contains(name)) {
          throw CalcParseException(
            'Cannot assign to reserved constant "$name"',
            offset: 0,
            suggestion: 'Choose a different variable name such as "${name}0".',
          );
        }
        return AssignmentStatement(name, rhs);
      });

  /// `expr`
  Parser<EvalStatement> evalStatement() =>
      ref0(expression).map(EvalStatement.new);

  /// Identifiers (reusing `ExprSyntax.identifierTokenParser`, trimmed of
  /// horizontal whitespace so newlines act as statement boundaries).
  Parser<String> identifier() => ExprSyntax.identifierTokenParser.trim(_hWs);

  /// Numbers (reusing `ExprSyntax.numberTokenParser`, trimmed of horizontal
  /// whitespace).
  Parser<ExprLeafNode> number() =>
      ExprSyntax.numberTokenParser.trim(_hWs).map(ExprLeafNode.new);

  /// Result reference: `r[1]`, `r[-1]`.
  Parser<ResultRefNode> resultRef() =>
      seq2(char('-').optional(), digit().plusString())
          .flatten(message: 'integer expected')
          .trim(_hWs)
          .skip(before: string('r[').trim(_hWs), after: char(']').trim(_hWs))
          .map((s) => ResultRefNode(int.parse(s)));

  /// Radical prefix: `√(x)` or `√x` or `√2`.
  Parser<CalcNode> radicalPrefix() => seq2(
    char('√').trim(_hWs),
    <Parser<CalcNode>>[
      ref0(expression)
          .skip(before: char('(').trim(_hWs), after: char(')').trim(_hWs)),
      ref0(number),
      ref0(resultRef),
      ref0(callOrSymbol),
    ].toChoiceParser(),
  ).map2((_, arg) => CallNode('sqrt', [arg]));

  /// Bracketed vector `[e1, e2, ...]` or matrix `[[a, b], [c, d]]`.
  Parser<CalcNode> bracketLiteral() =>
      ref0(expression)
          .starSeparated(char(',').trim())
          .map((list) => list.elements)
          .skip(before: char('[').trim(_hWs), after: char(']').trim(_hWs))
          .map(_classifyBracketLiteral);

  /// Function call `f(a, b)` or symbol/constant `x`, `pi`, `π`.
  Parser<CalcNode> callOrSymbol() =>
      seq2(
        ref0(identifier),
        ref0(expression)
            .starSeparated(char(',').trim())
            .map((list) => list.elements)
            .skip(before: char('(').trim(_hWs), after: char(')').trim(_hWs))
            .optional(),
      ).map2((name, args) {
        if (args != null) return CallNode(name, args);
        final stdConst = ExprSyntax.standardConstants[name];
        if (stdConst != null) return ExprLeafNode(stdConst);
        return SymbolNode(name);
      });

  /// Full expression hierarchy built with PetitParser `ExpressionBuilder`.
  Parser<CalcNode> expression() {
    final builder = ExpressionBuilder<CalcNode>();

    builder
      ..primitive(ref0(resultRef))
      ..primitive(ref0(bracketLiteral))
      ..primitive(ref0(radicalPrefix))
      ..primitive(ref0(number))
      ..primitive(ref0(callOrSymbol));

    // Parentheses wrapper
    builder.group().wrapper(
      char('(').trim(_hWs),
      char(')').trim(_hWs),
      (_, value, _) => value,
    );

    // Postfix operators: factorial (!), transpose ('), Unicode superscripts (², ³, ⁴)
    builder.group()
      ..postfix(
        seq2(char('!'), char('=').not()).trim(_hWs),
        (a, _) => UnaryOpNode(CalcUnaryOp.factorial, a),
      )
      ..postfix(
        anyOf("'´‘’").trim(_hWs),
        (a, _) => UnaryOpNode(CalcUnaryOp.transpose, a),
      )
      ..postfix(
        char('²').trim(_hWs),
        (a, _) => BinaryOpNode(
          CalcBinaryOp.pow,
          a,
          const ExprLeafNode(IntegerNumber.two),
        ),
      )
      ..postfix(
        char('³').trim(_hWs),
        (a, _) => BinaryOpNode(
          CalcBinaryOp.pow,
          a,
          ExprLeafNode(IntegerNumber.of(3)),
        ),
      )
      ..postfix(
        char('⁴').trim(_hWs),
        (a, _) => BinaryOpNode(
          CalcBinaryOp.pow,
          a,
          ExprLeafNode(IntegerNumber.of(4)),
        ),
      );

    // Exponentiation (right-associative, supporting signed exponents)
    final caretChar = anyOf('^ˆ\u0302‸＾').trim(_hWs);
    final minusChar = anyOf('-−–').trim(_hWs);
    final plusChar = char('+').trim(_hWs);
    builder.group()
      ..right(
        seq2(caretChar, minusChar),
        (a, _, b) => BinaryOpNode(
          CalcBinaryOp.pow,
          a,
          UnaryOpNode(CalcUnaryOp.negate, b),
        ),
      )
      ..right(
        seq2(caretChar, plusChar),
        (a, _, b) => BinaryOpNode(CalcBinaryOp.pow, a, b),
      )
      ..right(caretChar, (a, _, b) => BinaryOpNode(CalcBinaryOp.pow, a, b));

    // Unary prefix (+, -, −)
    builder.group()
      ..prefix(plusChar, (_, a) => UnaryOpNode(CalcUnaryOp.plus, a))
      ..prefix(minusChar, (_, a) => UnaryOpNode(CalcUnaryOp.negate, a));

    // Multiplicative (*, ×, ·, /, ÷, and optional implicit multiplication)
    final mulOp = anyOf('*×·').trim(_hWs);
    final divOp = anyOf('/÷').trim(_hWs);
    final mulGroup = builder.group()
      ..left(mulOp, (a, _, b) => BinaryOpNode(CalcBinaryOp.mul, a, b))
      ..left(divOp, (a, _, b) => BinaryOpNode(CalcBinaryOp.div, a, b));
    if (implicitMultiplication) {
      mulGroup.left(
        seq2(_hWs.star(), anyOf('+-−–*/×·÷^ˆ\u0302‸＾)=<>≤≥≠!,;:]\r\n').not()),
        (a, _, b) => BinaryOpNode(CalcBinaryOp.mul, a, b),
      );
    }

    // Additive (+, -, −)
    builder.group()
      ..left(plusChar, (a, _, b) => BinaryOpNode(CalcBinaryOp.add, a, b))
      ..left(minusChar, (a, _, b) => BinaryOpNode(CalcBinaryOp.sub, a, b));

    // Relational (<=, ≤, >=, ≥, !=, ≠, <, >, ==, =)
    builder.group()
      ..left(
        <Parser<String>>[string('<='), char('≤')].toChoiceParser().trim(_hWs),
        (a, _, b) => BinaryOpNode(CalcBinaryOp.le, a, b),
      )
      ..left(
        <Parser<String>>[string('>='), char('≥')].toChoiceParser().trim(_hWs),
        (a, _, b) => BinaryOpNode(CalcBinaryOp.ge, a, b),
      )
      ..left(
        <Parser<String>>[string('!='), char('≠')].toChoiceParser().trim(_hWs),
        (a, _, b) => BinaryOpNode(CalcBinaryOp.ne, a, b),
      )
      ..left(
        char('<').trim(_hWs),
        (a, _, b) => BinaryOpNode(CalcBinaryOp.lt, a, b),
      )
      ..left(
        char('>').trim(_hWs),
        (a, _, b) => BinaryOpNode(CalcBinaryOp.gt, a, b),
      )
      ..left(
        <Parser<String>>[
          string('=='),
          seq2(char('='), char('=').not()).flatten(message: '"=" expected'),
        ].toChoiceParser().trim(_hWs),
        (a, _, b) => BinaryOpNode(CalcBinaryOp.eq, a, b),
      );

    return builder.build();
  }

  /// RPN token stream production (`2 3 + 'x^2 + 1' factor`).
  Parser<List<RpnToken>> rpnLine() => ref0(rpnToken).star().trim().end();

  Parser<RpnToken> rpnToken() => <Parser<RpnToken>>[
    ref0(rpnQuotedAlgebraic),
    ref0(rpnResultRef),
    ref0(rpnBracketLiteral),
    ref0(rpnFunctionCall),
    ref0(rpnSignedNumber),
    ref0(rpnOperatorChar),
    ref0(rpnCommandWord),
  ].toChoiceParser();

  /// Single-quoted algebraic token in RPN mode: `'x^2 + 1'`.
  Parser<RpnPushNodeToken> rpnQuotedAlgebraic() => pattern("^'´‘’")
      .starString()
      .skip(
        before: anyOf("'´‘’").trim(),
        after: anyOf("'´‘’").optional().trim(),
      )
      .map((inner) {
        final exprParser = buildNodeParser();
        return switch (exprParser.parse(inner)) {
          Success(:final value) => RpnPushNodeToken(value, inner),
          Failure(:final message, :final position) => throw CalcParseException(
            message,
            source: inner,
            offset: position,
          ),
        };
      });

  /// `r[n]` token in RPN mode.
  Parser<RpnPushNodeToken> rpnResultRef() =>
      ref0(resultRef).token().map((t) => RpnPushNodeToken(t.value, t.input));

  /// `[...]` or `[[...]]` token in RPN mode.
  Parser<RpnPushNodeToken> rpnBracketLiteral() =>
      ref0(bracketLiteral)
          .token()
          .map((t) => RpnPushNodeToken(t.value, t.input));

  /// `sin(pi/4)` call token in RPN mode.
  Parser<RpnPushNodeToken> rpnFunctionCall() =>
      seq2(
            ref0(identifier),
            ref0(expression)
                .starSeparated(char(',').trim())
                .map((list) => list.elements)
                .skip(before: char('(').trim(), after: char(')').trim()),
          )
          .map2(CallNode.new)
          .token()
          .map((t) => RpnPushNodeToken(t.value, t.input.trim()));

  /// Signed or unsigned numeric literal in RPN mode (reusing
  /// `ExprSyntax.numberTokenParser`, not immediately followed by identifier
  /// characters).
  Parser<RpnPushNodeToken> rpnSignedNumber() =>
      seq3(
            anyOf('+-').optional(),
            ExprSyntax.numberTokenParser,
            ExprSyntax.identifierTokenParser.not(),
          )
          .map3((sign, numExpr, _) => sign == '-' ? -numExpr : numExpr)
          .token()
          .trim()
          .map((t) => RpnPushNodeToken(ExprLeafNode(t.value), t.input.trim()));

  /// Immediate single-character RPN operator (`+`, `-`, `*`, `/`, `^`, `!`, `²`, `³`, `⁴`).
  Parser<RpnCommandToken> rpnOperatorChar() =>
      anyOf('+-−–*/×·÷^ˆ\u0302‸＾!²³⁴')
          .trim()
          .map((op) => RpnCommandToken(_normalizeOperatorChar(op)));

  /// Word command or variable name in RPN mode (`SWAP`, `DUP`, `factor`, `x`).
  Parser<RpnCommandToken> rpnCommandWord() => ref0(
    identifier,
  ).map((w) => RpnCommandToken(w == 'π' ? 'pi' : (w == '∞' ? 'infinity' : w)));

  /// Builds an anchored [Parser] for [CalcNode] expressions.
  Parser<CalcNode> buildNodeParser() => buildFrom(ref0(expression).end());

  /// Builds an anchored [Parser] for RPN token lines.
  Parser<List<RpnToken>> buildRpnParser() => buildFrom(ref0(rpnLine));

  static String _normalizeOperatorChar(String op) => switch (op) {
    '−' || '–' => '-',
    '×' || '·' => '*',
    '÷' => '/',
    'ˆ' || '\u0302' || '‸' || '＾' => '^',
    _ => op,
  };

  static CalcNode _classifyBracketLiteral(List<CalcNode> elements) {
    if (elements.isNotEmpty && elements.every((e) => e is VectorLiteralNode)) {
      final rows = [
        for (final e in elements) (e as VectorLiteralNode).elements,
      ];
      final cols = rows.first.length;
      for (var r = 1; r < rows.length; r++) {
        if (rows[r].length != cols) {
          throw CalcParseException(
            'Inconsistent matrix row lengths: row 1 has $cols column(s), '
            'row ${r + 1} has ${rows[r].length}.',
            suggestion:
                'Ensure every row in [[...], [...]] has the same length.',
          );
        }
      }
      return MatrixLiteralNode(rows);
    }
    return VectorLiteralNode(elements);
  }
}

/// High-level facade over [CalcGrammarDefinition] providing statement, node,
/// and RPN parsing with rich diagnostics and quick-fix suggestions.
final class CalcGrammar {
  new({this.implicitMultiplication = true})
    : _definition = CalcGrammarDefinition(
        implicitMultiplication: implicitMultiplication,
      );

  final bool implicitMultiplication;
  final CalcGrammarDefinition _definition;

  late final Parser<CalcStatement> statementParser = _definition.build();
  late final Parser<CalcNode> nodeParser = _definition.buildNodeParser();
  late final Parser<List<RpnToken>> rpnParser = _definition.buildRpnParser();

  /// Normalizes keyboard dead-key circumflexes (`ˆ` U+02C6, U+0302, `‸`, `＾`)
  /// and acute quotes (`´` U+00B4, U+0301) to standard ASCII `^` and `'`.
  static String normalizeDeadKeys(String input) => input
      .replaceAll('ˆ', '^')
      .replaceAll('\u0302', '^')
      .replaceAll('‸', '^')
      .replaceAll('＾', '^')
      .replaceAll('´', "'")
      .replaceAll('\u0301', "'");

  /// Fast syntax check using PetitParser `.accept()` without AST allocation.
  bool acceptStatement(String input) {
    final norm = normalizeDeadKeys(input);
    return norm.trim().isNotEmpty && statementParser.accept(norm);
  }

  /// Parses [rawInput] into a [CalcStatement].
  CalcStatement parseStatement(String rawInput) {
    final norm = normalizeDeadKeys(rawInput);
    if (norm.trim().isEmpty) {
      throw const CalcParseException(
        'Empty input',
        offset: 0,
        suggestion: 'Enter an expression such as x^2 - 1 or sin(pi / 4).',
      );
    }
    return switch (statementParser.parse(norm)) {
      Success(:final value) => value,
      Failure(:final message, :final position) => throw _createFailureException(
        norm,
        position,
        message,
      ),
    };
  }

  /// Parses [rawInput] into a [CalcNode].
  CalcNode parseNode(String rawInput) {
    final norm = normalizeDeadKeys(rawInput);
    return switch (nodeParser.parse(norm)) {
      Success(:final value) => value,
      Failure(:final message, :final position) => throw _createFailureException(
        norm,
        position,
        message,
      ),
    };
  }

  /// Parses an RPN command line into a list of [RpnToken]s.
  List<RpnToken> parseRpnTokens(String rawLine) {
    final norm = normalizeDeadKeys(rawLine);
    if (norm.trim().isEmpty) return const [];
    return switch (rpnParser.parse(norm)) {
      Success(:final value) => value,
      Failure(:final message, :final position) => throw _createFailureException(
        norm,
        position,
        message,
      ),
    };
  }

  static CalcParseException _createFailureException(
    String source,
    int position,
    String message,
  ) {
    final openParens = char('(').allMatches(source).length;
    final closeParens = char(')').allMatches(source).length;
    if (openParens > closeParens) {
      return CalcParseException(
        'Unclosed "("',
        source: source,
        offset: position.clamp(0, source.length),
        suggestion: 'Append ")" to close the expression.',
      );
    }
    if (closeParens > openParens) {
      return CalcParseException(
        'Unexpected closing ")"',
        source: source,
        offset: position.clamp(0, source.length),
        suggestion: 'Remove the extra ")" or add a matching "(".',
      );
    }
    final openBrackets = char('[').allMatches(source).length;
    final closeBrackets = char(']').allMatches(source).length;
    if (openBrackets > closeBrackets) {
      return CalcParseException(
        'Unclosed "["',
        source: source,
        offset: position.clamp(0, source.length),
        suggestion: 'Append "]" to close the vector or matrix.',
      );
    }
    if (closeBrackets > openBrackets) {
      return CalcParseException(
        'Unexpected closing "]"',
        source: source,
        offset: position.clamp(0, source.length),
        suggestion: 'Remove the extra "]" or add a matching "[".',
      );
    }
    return CalcParseException(
      message,
      source: source,
      offset: position.clamp(0, source.length),
      suggestion: _suggestForFailure(source, position, message),
    );
  }

  static String? _suggestForFailure(String source, int offset, String message) {
    final trimmed = source.trim();
    if (trimmed.endsWith(':=') ||
        trimmed.endsWith('+') ||
        trimmed.endsWith('-') ||
        trimmed.endsWith('*') ||
        trimmed.endsWith('/') ||
        trimmed.endsWith('^')) {
      return 'Complete the right-hand expression.';
    }
    final wordParser = letter().plusString();
    final slice = source.substring(math.max(0, offset - 12));
    for (final word in wordParser.allMatches(slice)) {
      final closest = suggestClosestIdentifier(word);
      if (closest != null && closest != word) {
        return 'Did you mean "$closest"?';
      }
    }
    return 'Check operator syntax or press Ctrl+/ for the syntax guide.';
  }

  /// Finds the closest built-in function or command name within Levenshtein
  /// distance $\le 2$.
  static String? suggestClosestIdentifier(String typo) {
    final target = typo.toLowerCase();
    const candidates = <String>[
      'simplify',
      'expand',
      'factor',
      'subs',
      'solve',
      'numer',
      'denom',
      'apart',
      'together',
      'cancel',
      'collect',
      'diff',
      'integrate',
      'taylor',
      'series',
      'limit',
      'sum',
      'product',
      'gradient',
      'hessian',
      'jacobian',
      'det',
      'inv',
      'transpose',
      'trace',
      'charpoly',
      'rank',
      'rref',
      'nullspace',
      'eigenvals',
      'eigenvects',
      'identity',
      'zeros',
      'dot',
      'cross',
      'norm',
      're',
      'im',
      'conj',
      'arg',
      'abs',
      'polar',
      'rect',
      'approx',
      'exact',
      'gcd',
      'lcm',
      'mod',
      'isprime',
      'factorial',
      'binomial',
      'floor',
      'ceil',
      'round',
      'nintegrate',
      'nsolve',
      'nminimize',
      'nderivative',
      'plot',
      'clear',
      'clearall',
      'vars',
      'help',
      'sin',
      'cos',
      'tan',
      'asin',
      'acos',
      'atan',
      'sinh',
      'cosh',
      'tanh',
      'asinh',
      'acosh',
      'atanh',
      'sqrt',
      'exp',
      'ln',
      'log',
      'erf',
      'erfc',
      'gamma',
      'beta',
      'lambertw',
      'piecewise',
    ];
    String? best;
    var bestDist = 3;
    for (final candidate in candidates) {
      final d = _levenshtein(target, candidate);
      if (d < bestDist) {
        bestDist = d;
        best = candidate;
      }
    }
    return best;
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final prev = List<int>.generate(b.length + 1, (j) => j);
    final curr = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        curr[j] = math.min(
          math.min(curr[j - 1] + 1, prev[j] + 1),
          prev[j - 1] + cost,
        );
      }
      for (var j = 0; j <= b.length; j++) {
        prev[j] = curr[j];
      }
    }
    return prev[b.length];
  }
}
