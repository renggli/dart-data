import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

import '../../../web/calculator/src/language/ast.dart';
import '../../../web/calculator/src/language/completion.dart';
import '../../../web/calculator/src/language/grammar.dart';
import '../../../web/calculator/src/model/environment.dart';
import '../../../web/calculator/src/model/session.dart';
import '../../../web/calculator/src/model/value.dart';

void main() {
  group('CalcGrammar statements & expressions', () {
    test('parses assignments, function definitions, multi-statements, and expressions', () {
      final grammar = CalcGrammar(implicitMultiplication: true);

      final assign = grammar.parseStatement('a := [[1, 2], [3, 4]]');
      check(assign).isA<AssignmentStatement>();
      check((assign as AssignmentStatement).name).equals('a');
      check(assign.rhs).isA<MatrixLiteralNode>();

      final fnDef = grammar.parseStatement('f(x, y) := x^2 + 2*y');
      check(fnDef).isA<FunctionDefStatement>();
      final def = fnDef as FunctionDefStatement;
      check(def.name).equals('f');
      check(def.params).deepEquals(['x', 'y']);

      final multi = grammar.parseStatement('a := 2; b := 3\na + b');
      check(multi).isA<MultiStatement>();
      check((multi as MultiStatement).statements.length).equals(3);
    });

    test('parses r[n], vectors, matrices, transpose, factorial, Unicode, and implicit multiplication', () {
      final grammar = CalcGrammar(implicitMultiplication: true);

      final rNode = grammar.parseNode('r[3] + r[-1]');
      check(rNode).isA<BinaryOpNode>();

      final vecNode = grammar.parseNode('[1, x, x^2]');
      check(vecNode).isA<VectorLiteralNode>();
      check((vecNode as VectorLiteralNode).elements.length).equals(3);

      final matNode = grammar.parseNode("[[1, 2], [3, 4]]'");
      check(matNode).isA<UnaryOpNode>();
      check((matNode as UnaryOpNode).op).equals(CalcUnaryOp.transpose);

      // Implicit multiplication: 2x + 3(x + 1) - x
      final impNode = grammar.parseNode('2x + 3(x + 1) - x');
      check(impNode).isA<BinaryOpNode>();
      check((impNode as BinaryOpNode).op).equals(CalcBinaryOp.sub);

      // Unicode operators: √(x² + 1) · π ÷ 2 ≤ ∞
      final uniNode = grammar.parseNode('√(x² + 1) · π ÷ 2 ≤ ∞');
      check(uniNode).isA<BinaryOpNode>();
      check((uniNode as BinaryOpNode).op).equals(CalcBinaryOp.le);
    });

    test(
      'reports precise offsets and quick-fix suggestions on parse errors',
      () {
        final grammar = CalcGrammar();

        check(() => grammar.parseStatement(''))
            .throws<CalcParseException>()
            .has((e) => e.offset, 'offset')
            .equals(0);

        check(() => grammar.parseStatement('sin(x + 1'))
            .throws<CalcParseException>()
            .has((e) => e.suggestion, 'suggestion')
            .isNotNull();

        check(() => grammar.parseStatement('[[1, 2], [3]]'))
            .throws<CalcParseException>()
            .has((e) => e.message, 'message')
            .contains('Inconsistent matrix row lengths');

        check(() => grammar.parseStatement('pi := 3'))
            .throws<CalcParseException>()
            .has((e) => e.message, 'message')
            .contains('reserved');

        check(CalcGrammar.suggestClosestIdentifier('integrat'))
            .equals('integrate');
        check(CalcGrammar.suggestClosestIdentifier('simplfy'))
            .equals('simplify');
      },
    );
  });

  group('CalcGrammar RPN token stream', () {
    test('parses numbers, quoted algebraics, vectors, matrices, r[n], and operators', () {
      final grammar = CalcGrammar();
      final tokens = grammar.parseRpnTokens(
        "2 3 + 'x^2 - 1' factor [1, 2] [[1, 0], [0, 1]] r[1] SWAP",
      );
      check(tokens.length).equals(9);
      check(tokens[0]).isA<RpnPushNodeToken>();
      check(tokens[2]).isA<RpnCommandToken>();
      check(tokens[3]).isA<RpnPushNodeToken>();
      check(tokens[4]).isA<RpnCommandToken>();
      check(tokens[5]).isA<RpnPushNodeToken>();
      check(tokens[6]).isA<RpnPushNodeToken>();
      check(tokens[7]).isA<RpnPushNodeToken>();
      check(tokens[8]).isA<RpnCommandToken>();
    });

    test('normalizes US International dead-key circumflex (ˆ) and acute quotes (´)', () {
      final grammar = CalcGrammar();
      // In Scroll / statement mode: '2ˆ3' parses as BinaryOpNode(pow, 2, 3), never 2 * Variable('ˆ')
      final stmt = grammar.parseStatement('2ˆ3') as EvalStatement;
      check(stmt.node)
          .isA<BinaryOpNode>()
          .has((n) => n.op, 'op')
          .equals(CalcBinaryOp.pow);

      // In RPN mode: '2 3 ˆ' parses as [2, 3, ^] and '2ˆ' parses as [2, ^]
      final rpnTokens = grammar.parseRpnTokens('2 3 ˆ');
      check(rpnTokens.length).equals(3);
      check(rpnTokens[2])
          .isA<RpnCommandToken>()
          .has((t) => t.name, 'name')
          .equals('^');

      final gluedTokens = grammar.parseRpnTokens('2ˆ');
      check(gluedTokens.length).equals(2);
      check(gluedTokens[0]).isA<RpnPushNodeToken>();
      check(gluedTokens[1])
          .isA<RpnCommandToken>()
          .has((t) => t.name, 'name')
          .equals('^');

      final quotedTokens = grammar.parseRpnTokens('´xˆ2 - 1´ factor');
      check(quotedTokens.length).equals(2);
      check(quotedTokens[0]).isA<RpnPushNodeToken>();
      check(quotedTokens[1])
          .isA<RpnCommandToken>()
          .has((t) => t.name, 'name')
          .equals('factor');
    });
  });

  group('CalcCompletion', () {
    test(
      'completes commands, functions, variables, results, and signature hints',
      () {
        final env = Environment();
        env.setVariable('alpha', ExprValue(IntegerNumber.of(7)));
        env.setFunction(
          UserFunction(
            name: 'myfn',
            params: const ['u', 'v'],
            body: Expr.parse('u + v'),
            sourceText: 'u + v',
          ),
        );
        final session = Session();
        session.addResult(input: 'x^2', value: ExprValue(Expr.parse('x^2')));

        final cmdComp = CalcCompletion.complete(
          'integ',
          5,
          environment: env,
          session: session,
        );
        check(cmdComp.items.map((i) => i.label)).contains('integrate');

        final varComp = CalcCompletion.complete(
          '2 + alp',
          7,
          environment: env,
          session: session,
        );
        check(varComp.items.first.label).equals('alpha');

        final resComp = CalcCompletion.complete(
          'factor(r[',
          9,
          environment: env,
          session: session,
        );
        check(resComp.items.first.label).equals('r[1]');

        // Active parameter signature hint inside integrate(sin(x), |)
        final hintComp = CalcCompletion.complete(
          'integrate(sin(x), ',
          18,
          environment: env,
          session: session,
        );
        check(hintComp.signatureHint).isNotNull();
        check(hintComp.signatureHint!.name).equals('integrate');
        check(hintComp.signatureHint!.activeParamIndex).equals(1);
      },
    );
  });
}
