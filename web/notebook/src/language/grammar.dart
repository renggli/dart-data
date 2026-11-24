import 'package:data/symbolic.dart';
import 'package:petitparser/petitparser.dart';

import 'ast.dart';

/// Offset-rich parse error thrown by [CalcGrammar].
final class CalcParseException implements FormatException {
  const new(
    this.message, {
    required this.offset,
    this.source = '',
    this.suggestion,
  });

  @override
  final String message;

  @override
  final int offset;

  @override
  final String source;

  final String? suggestion;

  @override
  String toString() => 'CalcParseException($offset): $message';
}

/// PetitParser-based grammar for the notebook symbolic language.
final class CalcGrammar {
  new({this.implicitMultiplication = true});

  final bool implicitMultiplication;

  late final Parser<CalcStatement> _programParser = _buildProgramParser();

  /// Normalizes macOS/US-International dead-key sequences (`ˆ`, `\u0302`, `´`).
  static String normalizeDeadKeys(String input) => input
      .replaceAll('ˆ', '^')
      .replaceAll('\u0302', '^')
      .replaceAll('‸', '^')
      .replaceAll('＾', '^')
      .replaceAll('−', '-')
      .replaceAll('–', '-')
      .replaceAll('×', '*')
      .replaceAll('·', '*')
      .replaceAll('÷', '/')
      .replaceAll('≤', '<=')
      .replaceAll('≥', '>=')
      .replaceAll('≠', '!=');

  /// Parses [input] into a [CalcStatement], throwing [CalcParseException] on
  /// syntax errors.
  CalcStatement parse(String input) {
    final normalized = normalizeDeadKeys(input);
    switch (_programParser.parse(normalized)) {
      case Success(:final value):
        return value;
      case Failure(:final message, :final position):
        throw CalcParseException(message, offset: position, source: normalized);
    }
  }

  /// Horizontal whitespace + `// ...` line comment trivia.
  static final Parser<void> _lineComment = seq2(
    string('//'),
    anyOf('\r\n').neg().star(),
  );

  static final Parser<void> _hSpace = <Parser<void>>[
    anyOf(' \t'),
    _lineComment,
  ].toChoiceParser().star();

  static final Parser<void> _anyTrivia = <Parser<void>>[
    whitespace(),
    _lineComment,
  ].toChoiceParser().star();

  static Parser<T> _htrim<T>(Parser<T> parser) =>
      parser.skip(before: _hSpace, after: _hSpace);

  static Parser<T> _trim<T>(Parser<T> parser) =>
      parser.skip(before: _anyTrivia, after: _anyTrivia);

  Parser<CalcStatement> _buildProgramParser() {
    final exprParser = _buildExprParser();

    final ident = ExprSyntax.identifierTokenParser;

    // Parameter definition in `f(x, [a = 1], {scale: 2}) := body`
    final optParam = seq2(ident, seq2(_trim(char('=')), exprParser).optional())
        .skip(before: _trim(char('[')), after: _trim(char(']')))
        .map(
          (pair) => ParamDef(
            pair.$1,
            isOptionalPositional: true,
            defaultExpr: pair.$2?.$2,
          ),
        );

    final namedParam =
        seq2(ident, seq2(_trim(char(':')), exprParser).optional())
            .skip(before: _trim(char('{')), after: _trim(char('}')))
            .map(
              (pair) =>
                  ParamDef(pair.$1, isNamed: true, defaultExpr: pair.$2?.$2),
            );

    final reqParam = ident.map(ParamDef.new);

    final paramDef = <Parser<ParamDef>>[
      optParam,
      namedParam,
      reqParam,
    ].toChoiceParser();

    final paramList = paramDef
        .starSeparated(_trim(char(',')))
        .map((list) => list.elements)
        .skip(before: _trim(char('(')), after: _trim(char(')')));

    final funcDef =
        seq4(
          _htrim(ident).token(),
          paramList,
          _htrim(string(':=')),
          exprParser,
        ).map4(
          (nameTok, params, _, body) => FunctionDefStatement(
            nameTok.value,
            params,
            body,
            offset: nameTok.start,
          ),
        );

    final assignStmt =
        seq3(_htrim(ident).token(), _htrim(string(':=')), exprParser).map3(
          (nameTok, _, value) =>
              AssignmentStatement(nameTok.value, value, offset: nameTok.start),
        );

    final evalStmt = exprParser.map(EvalStatement.new);

    final singleStmt = <Parser<CalcStatement>>[
      funcDef,
      assignStmt,
      evalStmt,
    ].toChoiceParser();

    final sep = <Parser<void>>[
      _htrim(char(';')),
      _htrim(anyOf('\r\n')).plus(),
    ].toChoiceParser().plus();

    return singleStmt
        .plusSeparated(sep)
        .skip(before: _anyTrivia, after: _anyTrivia)
        .end()
        .map((list) {
          final stmts = list.elements;
          if (stmts.length == 1) return stmts.first;
          return MultiStatement(stmts, offset: stmts.first.offset);
        });
  }

  Parser<CalcNode> _buildExprParser() {
    final builder = ExpressionBuilder<CalcNode>();

    // String literal
    final singleQuoted = seq3(
      char("'"),
      <Parser<String>>[
        seq2(char(r'\'), any()).map2((_, c) => _unescape(c)),
        noneOf("'\\\r\n"),
      ].toChoiceParser().starString(),
      char("'"),
    ).token().map((tok) => StringLiteralNode(tok.value.$2, tok.start));

    final doubleQuoted = seq3(
      char('"'),
      <Parser<String>>[
        seq2(char(r'\'), any()).map2((_, c) => _unescape(c)),
        noneOf('"\\\r\n'),
      ].toChoiceParser().starString(),
      char('"'),
    ).token().map((tok) => StringLiteralNode(tok.value.$2, tok.start));

    // Result reference: r[n] or r[-n]
    final resultRef = seq4(
      char('r'),
      char('['),
      seq2(char('-').optional(), digit().plusString()).flatten(),
      char(']'),
    ).token().map((tok) => ResultRefNode(int.parse(tok.value.$3), tok.start));

    // Number literal
    final numberLit = ExprSyntax.numberTokenParser.token().map(
      (tok) => ExprLeafNode(tok.value, tok.start),
    );

    // Call arguments: positional or named (`name: expr`)
    final namedArg =
        seq3(
          ExprSyntax.identifierTokenParser.token(),
          _trim(char(':')),
          builder.loopback,
        ).map3(
          (tok, _, val) =>
              _ParsedArg.named(NamedArg(tok.value, val, offset: tok.start)),
        );

    final posArg = builder.loopback.map(_ParsedArg.positional);

    final argList = <Parser<_ParsedArg>>[
      namedArg,
      posArg,
    ].toChoiceParser().starSeparated(_trim(char(',')));

    // Identifier, boolean, constant, or call
    final identOrCall =
        seq2(
          ExprSyntax.identifierTokenParser.token(),
          argList
              .skip(before: _trim(char('(')), after: _trim(char(')')))
              .optional(),
        ).map2((nameTok, args) {
          final name = nameTok.value;
          final offset = nameTok.start;
          if (args == null) {
            if (name == 'true') return BoolLiteralNode(true, offset);
            if (name == 'false') return BoolLiteralNode(false, offset);
            final constant = ExprSyntax.standardConstants[name];
            if (constant != null) return ExprLeafNode(constant, offset);
            return SymbolNode(name, offset);
          }

          final positional = <CalcNode>[];
          final named = <NamedArg>[];
          final seenNamed = <String>{};
          var sawNamed = false;

          for (final item in args.elements) {
            if (item.named case final n?) {
              if (!seenNamed.add(n.name)) {
                throw CalcParseException(
                  "Duplicate named argument '${n.name}'",
                  offset: n.offset,
                );
              }
              sawNamed = true;
              named.add(n);
            } else if (item.positional case final p?) {
              if (sawNamed) {
                throw CalcParseException(
                  'Positional argument cannot follow a named argument',
                  offset: p.offset,
                );
              }
              positional.add(p);
            }
          }
          return CallNode(name, positional, named, offset);
        });

    // Vector or Matrix literal
    final bracketLiteral = builder.loopback
        .starSeparated(_trim(char(',')))
        .skip(before: _trim(char('[')), after: _trim(char(']')))
        .token()
        .map((tok) {
          final elements = tok.value.elements;
          if (elements.isNotEmpty &&
              elements.every((e) => e is VectorLiteralNode)) {
            final rows = [
              for (final e in elements) (e as VectorLiteralNode).elements,
            ];
            return MatrixLiteralNode(rows, tok.start);
          }
          return VectorLiteralNode(elements, tok.start);
        });

    // Unicode constants π, ∞
    final unicodeConst = anyOf('π∞').token().map((tok) {
      final expr = tok.value == 'π' ? Constant.pi : Constant.infinity;
      return ExprLeafNode(expr, tok.start);
    });

    builder
      ..primitive(_htrim(singleQuoted))
      ..primitive(_htrim(doubleQuoted))
      ..primitive(_htrim(resultRef))
      ..primitive(_htrim(numberLit))
      ..primitive(_htrim(unicodeConst))
      ..primitive(_htrim(identOrCall))
      ..primitive(_htrim(bracketLiteral));

    // Parentheses
    builder.group().wrapper(
      _htrim(char('(')),
      _htrim(char(')')),
      (_, value, _) => value,
    );

    // Postfix factorial (`!`, not `!=`) and Unicode superscripts (², ³, ⁴)
    builder.group()
      ..postfix(
        _htrim(seq2(char('!'), char('=').not()).flatten()),
        (a, _) => PostfixOpNode('!', a, a.offset),
      )
      ..postfix(
        _htrim(char('²')),
        (a, _) => BinaryOpNode(
          '^',
          a,
          ExprLeafNode(IntegerNumber.two, a.offset),
          a.offset,
        ),
      )
      ..postfix(
        _htrim(char('³')),
        (a, _) => BinaryOpNode(
          '^',
          a,
          ExprLeafNode(IntegerNumber.of(3), a.offset),
          a.offset,
        ),
      )
      ..postfix(
        _htrim(char('⁴')),
        (a, _) => BinaryOpNode(
          '^',
          a,
          ExprLeafNode(IntegerNumber.of(4), a.offset),
          a.offset,
        ),
      );

    // Prefix √
    builder.group().prefix(
      _htrim(char('√')),
      (_, a) => UnaryOpNode('√', a, a.offset),
    );

    // Exponentiation (right-associative)
    final caretOp = _htrim(
      <Parser<String>>[string('**'), char('^')].toChoiceParser(),
    );
    builder.group()
      ..right(
        seq2(caretOp, _htrim(char('-'))),
        (a, _, b) =>
            BinaryOpNode('^', a, UnaryOpNode('-', b, b.offset), a.offset),
      )
      ..right(
        seq2(caretOp, _htrim(char('+'))),
        (a, _, b) => BinaryOpNode('^', a, b, a.offset),
      )
      ..right(caretOp, (a, _, b) => BinaryOpNode('^', a, b, a.offset));

    // Unary prefix (+, -)
    builder.group()
      ..prefix(_htrim(char('+')), (_, a) => a)
      ..prefix(_htrim(char('-')), (_, a) => UnaryOpNode('-', a, a.offset));

    // Multiplicative (*, /, implicit juxtaposition)
    final mulGroup = builder.group()
      ..left(_htrim(char('*')), (a, _, b) => BinaryOpNode('*', a, b, a.offset))
      ..left(_htrim(char('/')), (a, _, b) => BinaryOpNode('/', a, b, a.offset));
    if (implicitMultiplication) {
      mulGroup.left(
        anyOf('+-*/^)=<>!,;:]\r\n').trim().not(),
        (a, _, b) => BinaryOpNode('*', a, b, a.offset),
      );
    }

    // Additive (+, -)
    builder.group()
      ..left(_htrim(char('+')), (a, _, b) => BinaryOpNode('+', a, b, a.offset))
      ..left(_htrim(char('-')), (a, _, b) => BinaryOpNode('-', a, b, a.offset));

    // Relational (=, ==, !=, <=, >=, <, >)
    builder.group()
      ..left(
        _htrim(string('<=')),
        (a, _, b) => BinaryOpNode('<=', a, b, a.offset),
      )
      ..left(
        _htrim(string('>=')),
        (a, _, b) => BinaryOpNode('>=', a, b, a.offset),
      )
      ..left(
        _htrim(string('!=')),
        (a, _, b) => BinaryOpNode('!=', a, b, a.offset),
      )
      ..left(_htrim(char('<')), (a, _, b) => BinaryOpNode('<', a, b, a.offset))
      ..left(_htrim(char('>')), (a, _, b) => BinaryOpNode('>', a, b, a.offset))
      ..left(
        _htrim(<Parser<String>>[string('=='), char('=')].toChoiceParser()),
        (a, _, b) => BinaryOpNode('=', a, b, a.offset),
      );

    return resolve(builder.build());
  }

  static String _unescape(String c) => switch (c) {
    'n' => '\n',
    't' => '\t',
    'r' => '\r',
    _ => c,
  };
}

final class _ParsedArg {
  const new positional(this.positional) : named = null;
  const new named(this.named) : positional = null;

  final CalcNode? positional;
  final NamedArg? named;
}
