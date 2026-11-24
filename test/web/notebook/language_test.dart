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
          "plot(sin(x), from: -π, to: π, title: 'Wave') // comment\n"
          'r[1] + true';
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
        tokens.any((t) => t.kind == TokenKind.paramLabel && t.text == 'from'),
      ).isTrue;
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

    test('parses positional and named arguments', () {
      final stmt = grammar.parse('integrate(sin(x), x, from: 0, to: pi)');
      check(stmt).isA<EvalStatement>();
      final call = (stmt as EvalStatement).node as CallNode;
      check(call.name).equals('integrate');
      check(call.positionalArgs.length).equals(2);
      check(call.namedArgs.length).equals(2);
      check(call.namedArgs[0].name).equals('from');
      check(call.namedArgs[1].name).equals('to');
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
        ParamSpec.named('from', type: ParamType.number, defaultValue: -5.0),
        ParamSpec.named('to', type: ParamType.number, defaultValue: 5.0),
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
          _ => throw ArgumentBindingException('Unsupported node: $node'),
        };

    test('formats signature and binds defaults', () {
      check(sig.format('limit'))
          .equals('limit(expr, [var], {from: -5.0, to: 5.0, direction: both})');
      final bound = ArgumentBinder.bind(
        'limit',
        sig,
        [const SymbolNode('x', 0)],
        [const NamedArg('direction', StringLiteralNode('right', 5), offset: 5)],
        evalNode,
      );
      check(bound.expr('expr')).equals(const Variable('x'));
      check(bound.symbolOrNull('var')).isNull;
      check(bound.doubleVal('from')).equals(-5.0);
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
    test('round-trips ExprValue, StringValue, BoolValue, and ListValue', () {
      final values = <CalcValue>[
        ExprValue(Expr.parse('x^2 + 1')),
        const StringValue('hello'),
        const BoolValue(true),
        const ListValue([ExprValue(IntegerNumber.two), BoolValue(false)]),
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

    test(
      'suggests commands, math functions, named params, and enum values',
      () {
        final topRes = NotebookCompletion.suggest(
          'cheb',
          4,
          registry: registry,
          env: env,
        );
        check(topRes.items.any((i) => i.label == 'chebyshevT')).isTrue;

        const srcNamed = 'integrate(sin(x), x, ';
        final namedRes = NotebookCompletion.suggest(
          srcNamed,
          srcNamed.length,
          registry: registry,
          env: env,
        );
        check(namedRes.items.any((i) => i.label == 'from:')).isTrue;
        check(namedRes.items.any((i) => i.label == 'to:')).isTrue;
        check(namedRes.signatureHint?.functionName).equals('integrate');

        const srcEnum = "limit(1/x, x, 0, direction: 'r";
        final enumRes = NotebookCompletion.suggest(
          srcEnum,
          srcEnum.length,
          registry: registry,
          env: env,
        );
        check(enumRes.items.any((i) => i.label == "'right'")).isTrue;
        check(enumRes.signatureHint?.activeParamName).equals('direction');
      },
    );

    test('highlights math and markdown into .tok-* spans', () {
      final mathHtml = SyntaxHighlighter.highlightMathHtml(
        'plot(sin(x), from: 0)',
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
