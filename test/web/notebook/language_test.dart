import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

import '../../../web/notebook/src/engine/commands.dart';
import '../../../web/notebook/src/language/ast.dart';
import '../../../web/notebook/src/language/completion.dart';
import '../../../web/notebook/src/language/grammar.dart';
import '../../../web/notebook/src/language/lexer.dart';
import '../../../web/notebook/src/language/signature.dart';
import '../../../web/notebook/src/model/environment.dart';
import '../../../web/notebook/src/model/serialization.dart';
import '../../../web/notebook/src/model/value.dart';
import '../../../web/notebook/src/ui/highlighter.dart';

void main() {
  group('CalcLexer', () {
    test('covers entire input without gaps and classifies tokens', () {
      const src =
          "plot(sin(x), x, x: -π..π, title: 'Wave') // comment\n"
          'r[1] + true + 2..5 + 2.5..5.5';
      final tokens = CalcLexer.tokenize(
        src,
        commands: {'plot'},
        mathFuncs: {'sin'},
        boundVars: {'x'},
      );
      check(tokens.map((t) => t.text).join()).equals(src);
      for (var i = 0; i < tokens.length; i++) {
        if (i == 0) check(tokens[i].start).equals(0);
        if (i > 0) check(tokens[i].start).equals(tokens[i - 1].end);
      }
      check(tokens.last.end).equals(src.length);

      check(tokens.any((t) => t.kind == TokenKind.command && t.text == 'plot'))
          .isTrue;
      check(tokens.any((t) => t.kind == TokenKind.mathFunc && t.text == 'sin'))
          .isTrue;
      check(
        tokens.any((t) => t.kind == TokenKind.paramLabel && t.text == 'title'),
      ).isTrue;
      check(
        tokens
            .where((t) => t.kind == TokenKind.operator && t.text == '..')
            .length,
      ).equals(3);
      check(tokens.any((t) => t.kind == TokenKind.number && t.text == '2'))
          .isTrue;
      check(tokens.any((t) => t.kind == TokenKind.number && t.text == '2.5'))
          .isTrue;
      check(tokens.any((t) => t.kind == TokenKind.constant && t.text == 'π'))
          .isTrue;
      check(tokens.any((t) => t.kind == TokenKind.string && t.text == "'Wave'"))
          .isTrue;
      check(
        tokens.any(
          (t) => t.kind == TokenKind.comment && t.text == '// comment',
        ),
      ).isTrue;
      check(
        tokens.any((t) => t.kind == TokenKind.resultRef && t.text == 'r[1]'),
      ).isTrue;
      check(tokens.any((t) => t.kind == TokenKind.boolean && t.text == 'true'))
          .isTrue;
    });
  });

  group('CalcGrammar', () {
    final grammar = CalcGrammar();

    test('parses range expressions, named arguments, and precedence', () {
      final stmt = grammar.parse(
        'plotcomplex((z^2 - 1)/(z + 2), z, re: -2..2)',
      );
      check(stmt).isA<EvalStatement>();
      final call = (stmt as EvalStatement).node as CallNode;
      check(call.name).equals('plotcomplex');
      check(call.positionalArgs.length).equals(2);
      check(call.namedArgs.length).equals(1);
      check(call.namedArgs[0].name).equals('re');
      check(call.namedArgs[0].value).isA<RangeNode>();

      final rangeStmt = grammar.parse('a + 1..2 * pi') as EvalStatement;
      check(rangeStmt.node).isA<RangeNode>();
      final rng = rangeStmt.node as RangeNode;
      check(rng.start).isA<BinaryOpNode>();
      check(rng.end).isA<BinaryOpNode>();

      check(() => grammar.parse('1..2..3')).throws<CalcParseException>();
    });

    test(
      'parses user function definitions with optional and named defaults',
      () {
        final stmt = grammar.parse(
          'wave(x, [amp = 1], {freq: 2}) := amp * sin(freq * x)',
        );
        check(stmt).isA<FunctionDefStatement>();
        final def = stmt as FunctionDefStatement;
        check(def.name).equals('wave');
        check(def.params.length).equals(3);
        check(def.params[0].isOptionalPositional).isFalse;
        check(def.params[1].isOptionalPositional).isTrue;
        check(def.params[1].defaultExpr).isNotNull();
        check(def.params[2].isNamed).isTrue;
        check(def.params[2].defaultExpr).isNotNull();
      },
    );

    test('rejects positional-after-named and duplicate named arguments', () {
      check(() => grammar.parse('plot(sin(x), from: 0, x)'))
          .throws<CalcParseException>();
      check(() => grammar.parse('plot(sin(x), from: 0, from: 1)'))
          .throws<CalcParseException>();
    });

    test('normalizes macOS dead keys and ignores line comments', () {
      final stmt = grammar.parse('xˆ2 + 1 // quadratic');
      check(stmt).isA<EvalStatement>();
      final bin = (stmt as EvalStatement).node as BinaryOpNode;
      check(bin.op).equals('+');
    });
  });

  group('FunctionSignature & ArgumentBinder', () {
    const sig = FunctionSignature(
      positional: [
        ParamSpec.positional('expr'),
        ParamSpec.optional('var', type: ParamType.symbol),
      ],
      named: [
        ParamSpec.named(
          'range',
          type: ParamType.range,
          defaultValue: NumericRange(-5.0, 5.0),
        ),
        ParamSpec.named(
          'direction',
          type: ParamType.string,
          defaultValue: 'both',
          enumValues: ['both', 'left', 'right'],
        ),
      ],
    );

    CalcValue evalNode(CalcNode node, {Set<String> boundSymbols = const {}}) =>
        switch (node) {
          ExprLeafNode(:final expr) => ExprValue(expr),
          StringLiteralNode(:final value) => StringValue(value),
          BoolLiteralNode(:final value) => BoolValue(value),
          SymbolNode(:final name) => ExprValue(Variable(name)),
          UnaryOpNode(op: '-', :final operand) => ExprValue(
            -(evalNode(operand, boundSymbols: boundSymbols) as ExprValue).expr,
          ),
          RangeNode(:final start, :final end) => RangeValue(
            (evalNode(start, boundSymbols: boundSymbols) as ExprValue).expr,
            (evalNode(end, boundSymbols: boundSymbols) as ExprValue).expr,
          ),
          _ => throw ArgumentBindingException('Unsupported node: $node'),
        };

    test('formats signature and binds defaults', () {
      check(sig.format('limit'))
          .equals('limit(expr, [var], {range: -5..5, direction: both})');
      final bound = ArgumentBinder.bind(
        'limit',
        sig,
        [const SymbolNode('x', 0)],
        [const NamedArg('direction', StringLiteralNode('right', 5), offset: 5)],
        evalNode,
      );
      check(bound.expr('expr')).equals(const Variable('x'));
      check(bound.symbolOrNull('var')).isNull;
      check(bound.numericRange('range')).equals((start: -5.0, end: 5.0));
      check(bound.stringVal('direction')).equals('right');
    });

    test('suggests closest named arg and validates enum values', () {
      check(
            () => ArgumentBinder.bind(
              'limit',
              sig,
              [const SymbolNode('x', 0)],
              [
                const NamedArg(
                  'directon',
                  StringLiteralNode('left', 5),
                  offset: 5,
                ),
              ],
              evalNode,
            ),
          )
          .throws<ArgumentBindingException>()
          .has('suggestion', (ArgumentBindingException e) => e.suggestion)
          .equals('direction');

      check(
        () => ArgumentBinder.bind(
          'limit',
          sig,
          [const SymbolNode('x', 0)],
          [const NamedArg('direction', StringLiteralNode('up', 5), offset: 5)],
          evalNode,
        ),
      ).throws<ArgumentBindingException>();
    });
  });

  group('CalcValue serialization', () {
    test('round-trips ExprValue, StringValue, BoolValue, RangeValue, and ListValue', () {
      final values = <CalcValue>[
        ExprValue(Expr.parse('x^2 + 1')),
        const StringValue('hello'),
        const BoolValue(true),
        RangeValue(IntegerNumber.of(-2), IntegerNumber.two),
        ListValue([ExprValue(IntegerNumber.two), const BoolValue(false)]),
      ];
      for (final v in values) {
        final decoded = valueFromJson(valueToJson(v));
        check(decoded).equals(v);
      }
    });
  });

  group('NotebookCompletion & SyntaxHighlighter', () {
    final registry = CommandRegistry();
    final env = Environment();

    test('suggests commands, math functions, named params, and enum values in context', () {
      final topRes = NotebookCompletion.suggest(
        'cheb',
        4,
        registry: registry,
        env: env,
      );
      check(topRes.items.any((i) => i.label == 'chebyshevT')).isTrue;
      check(topRes.items.first.cursorBackOffset).equals(1);

      const srcNamed = 'plotcomplex(z^2, z, ';
      final namedRes = NotebookCompletion.suggest(
        srcNamed,
        srcNamed.length,
        registry: registry,
        env: env,
      );
      check(namedRes.items.any((i) => i.label == 're:')).isTrue;
      check(namedRes.items.any((i) => i.label == 'im:')).isTrue;
      check(namedRes.signatureHint?.functionName).equals('plotcomplex');

      const srcEnum = "limit(1/x, x, 0, direction: 'r";
      final enumRes = NotebookCompletion.suggest(
        srcEnum,
        srcEnum.length,
        registry: registry,
        env: env,
      );
      check(enumRes.items.any((i) => i.label == "'right'")).isTrue;
      check(enumRes.signatureHint?.activeParamName).equals('direction');

      // Context suppression checks:
      // 1. Inside comment -> empty
      const commentSrc = 'x + 1 // pl';
      check(
        NotebookCompletion.suggest(
          commentSrc,
          commentSrc.length,
          registry: registry,
          env: env,
        ).items,
      ).isEmpty;

      // 2. Inside non-enum string -> empty items
      const strSrc = "plot(sin(x), title: 'si";
      check(
        NotebookCompletion.suggest(
          strSrc,
          strSrc.length,
          registry: registry,
          env: env,
        ).items,
      ).isEmpty;

      // 3. Inside function definition head -> empty
      const fnHeadSrc = 'f(x, p';
      const fnHeadFull = 'f(x, pl) := x';
      check(
        NotebookCompletion.suggest(
          fnHeadFull,
          fnHeadSrc.length,
          registry: registry,
          env: env,
        ).items,
      ).isEmpty;

      // 4. Before required first positional arg in plot(|) -> no named params
      const reqPosSrc = 'plot(';
      check(
        NotebookCompletion.suggest(
          reqPosSrc,
          reqPosSrc.length,
          registry: registry,
          env: env,
        ).items,
      ).isEmpty;

      // 5. After param: value slot (`re: `) -> no other named param labels
      const afterColonSrc = 'plotcomplex(z^2, z, re: ';
      final afterColonRes = NotebookCompletion.suggest(
        afterColonSrc,
        afterColonSrc.length,
        registry: registry,
        env: env,
      );
      check(afterColonRes.items.any((i) => i.kind == CompletionKind.paramLabel))
          .isFalse;
      check(afterColonRes.signatureHint?.activeParamName).equals('re');

      // 6. Nested call suppresses top-level plot/session commands & deduplicates
      const nestedSrc = 'sin(plo';
      final nestedRes = NotebookCompletion.suggest(
        nestedSrc,
        nestedSrc.length,
        registry: registry,
        env: env,
      );
      check(nestedRes.items.any((i) => i.label == 'plot')).isFalse;

      const dedupSrc = 'ab';
      final dedupRes = NotebookCompletion.suggest(
        dedupSrc,
        dedupSrc.length,
        registry: registry,
        env: env,
      );
      check(dedupRes.items.where((i) => i.label == 'abs').length).equals(1);
    });

    test('highlights math and markdown into .tok-* spans', () {
      final mathHtml = SyntaxHighlighter.highlightMathHtml(
        'plot(sin(x), x: -2..2)',
        registry: registry,
        env: env,
        cursorOffset: 4,
      );
      check(mathHtml).contains('tok-command');
      check(mathHtml).contains('tok-math-func');
      check(mathHtml).contains('tok-param-label');
      check(mathHtml).contains('tok-bracket-match');

      final mdHtml = SyntaxHighlighter.highlightMarkdownHtml(
        '# Title\nValue {{r[1]}} and \$x^2\$',
      );
      check(mdHtml).contains('tok-command');
      check(mdHtml).contains('tok-result-ref');
      check(mdHtml).contains('tok-math-func');
    });
  });
}
