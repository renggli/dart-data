import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

import '../../../web/calculator/src/model/environment.dart';
import '../../../web/calculator/src/model/serialization.dart';
import '../../../web/calculator/src/model/session.dart';
import '../../../web/calculator/src/model/stack.dart';
import '../../../web/calculator/src/model/value.dart';

void main() {
  group('CalcValue & CalcSerialization', () {
    test(
      'tracks exactness, canonical text, MathML, LaTeX, and approxSummary',
      () {
        final exactRad = ExprValue(Expr.parse('sqrt(2)'));
        check(exactRad.isExact).isTrue();
        check(exactRad.toCanonicalText()).equals('sqrt(2)');
        check(exactRad.toMathMl()).contains('<msqrt>');
        check(exactRad.toLatex()).contains(r'\sqrt');
        check(exactRad.approxSummary(digits: 6)).equals('1.41421');

        final intVal = ExprValue(IntegerNumber.of(42));
        check(intVal.isExact).isTrue();
        check(intVal.approxSummary()).isNull();

        const approxVal = ExprValue(RealNumber(1.5));
        check(approxVal.isExact).isFalse();
        check(approxVal.approxSummary()).isNull();

        final symVal = ExprValue(Expr.parse('x^2 + 1'));
        check(symVal.isExact).isTrue();
        check(symVal.approxSummary()).isNull();

        final eqVal = ExprValue(Expr.parse('x = 2'));
        check(eqVal.isEquation).isTrue();
        check(eqVal.kind).equals('equation');
      },
    );

    test('round-trips ExprValue, VectorValue, MatrixValue, ListValue, SeriesValue, PlotValue, InfoValue, ErrorValue', () {
      final values = <CalcValue>[
        ExprValue(Expr.parse('1/3 * x^2 + sin(pi / 4)')),
        VectorValue(ExprSyntax.standard.parseVector('[1, x, x^2]')),
        MatrixValue(ExprSyntax.standard.parseMatrix('[[1, 2], [3, x]]')),
        const ListValue([
          ExprValue(IntegerNumber.one),
          ExprValue(IntegerNumber.negativeOne),
        ]),
        SeriesValue(Expr.parse('sin(x)').toPowerSeries('x', order: 5)),
        PlotValue(
          expressions: [Expr.parse('sin(x)')],
          variable: 'x',
          minX: -5,
          maxX: 5,
          minY: -1.2,
          maxY: 1.2,
          curves: [
            PlotCurveData(
              label: 'sin(x)',
              exprText: 'sin(x)',
              segments: [
                PlotSegmentData(
                  x: Float64List.fromList([-1.0, 0.0, 1.0]),
                  y: Float64List.fromList([-0.84, 0.0, 0.84]),
                ),
              ],
              markers: const [
                PlotMarkerData(x: 0.0, y: 0.0, label: '(0, 0)', kind: 'root'),
              ],
            ),
          ],
        ),
        PlotValue(
          expressions: [Expr.parse('x^2 - y^2')],
          variable: 'x, y',
          minX: -4,
          maxX: 4,
          minY: -4,
          maxY: 4,
          surface3d: Surface3dData(
            xVar: 'x',
            yVar: 'y',
            minX: -4,
            maxX: 4,
            minY: -4,
            maxY: 4,
            minZ: -16,
            maxZ: 16,
            gridSize: 2,
            zValues: Float64List.fromList([0.0, 16.0, -16.0, 0.0]),
          ),
        ),
        const InfoValue('Cleared: a', title: 'Info'),
        const ErrorValue(
          'Unclosed "("',
          offset: 3,
          suggestion: 'Add ")"',
          source: 'sin(x',
        ),
      ];

      for (final v in values) {
        final json = CalcSerialization.toJson(v);
        final decoded = CalcSerialization.fromJson(json);
        check(decoded).equals(v);
      }

      check(CalcSerialization.parseCanonical('[[1, 2], [3, 4]]'))
          .isA<MatrixValue>();
      check(CalcSerialization.parseCanonical('[1, 2, 3]')).isA<VectorValue>();
      check(CalcSerialization.parseCanonical('x + 1')).isA<ExprValue>();
      check(CalcSerialization.parseCanonical('Error: boom')).isA<ErrorValue>();
    });
  });

  group('Environment & CalcSettings', () {
    test(
      'manages variables, user functions, settings, and domain assumptions',
      () {
        final env = Environment();
        env.setVariable('a', ExprValue(IntegerNumber.of(10)));
        check(env.getVariable('a')).equals(ExprValue(IntegerNumber.of(10)));

        final fn = UserFunction(
          name: 'sq',
          params: const ['x'],
          body: Expr.parse('x^2 + 1'),
          sourceText: 'x^2 + 1',
        );
        env.setFunction(fn);
        check(fn.signature).equals('sq(x)');
        check(fn.apply([IntegerNumber.of(3)]).simplify())
            .equals(IntegerNumber.of(10));

        final settings = env.settings.copyWith(
          domain: VariableDomain.positive,
          digits: 8,
          angleMode: AngleMode.deg,
        );
        final restored = CalcSettings.fromJson(settings.toJson());
        check(restored.domain).equals(VariableDomain.positive);
        check(restored.digits).equals(8);
        check(restored.angleMode).equals(AngleMode.deg);
        check(restored.assumptions.domainOf('x'))
            .equals(VariableDomain.positive);

        check(env.clearSymbol('a')).isTrue();
        check(env.getVariable('a')).isNull();
        env.clearAll();
        check(env.functions).isEmpty();
      },
    );
  });

  group('Session & Dependency Graph', () {
    test('resolves r[n], r[-k], tombstones, and transitive stale cells', () {
      final session = Session();
      final c1 = session.addResult(
        input: 'a := 5',
        value: ExprValue(IntegerNumber.of(5)),
        assignedSymbol: 'a',
      );
      final c2 = session.addResult(
        input: 'r[1] + 2',
        value: ExprValue(IntegerNumber.of(7)),
        referencedResults: {c1.id},
      );
      final c3 = session.addResult(
        input: 'r[2] * a',
        value: ExprValue(IntegerNumber.of(35)),
        referencedResults: {c2.id},
        referencedSymbols: {'a'},
      );

      check(session.resolveResult(1)).equals(c1.value);
      check(session.resolveResult(-1)).equals(c3.value);
      check(session.resolveResult(-2)).equals(c2.value);

      // Updating cell 1 marks both cell 2 and cell 3 stale transitively
      final staleIds = session.updateCell(
        c1.id,
        input: 'a := 10',
        value: ExprValue(IntegerNumber.of(10)),
        assignedSymbol: 'a',
      );
      check(staleIds).deepEquals([2, 3]);
      check(session.staleCells.map((c) => c.id)).deepEquals([2, 3]);

      // Deleting cell 2 leaves a tombstone so r[2] fails explicitly and r[3] does not renumber
      session.deleteCell(2);
      check(session.activeCells.map((c) => c.id)).deepEquals([1, 3]);
      check(() => session.resolveResult(2)).throws<StateError>();

      // Round-trip session JSON
      final clone = Session()..loadFromJson(session.toJson());
      check(clone.activeCells.map((c) => c.id)).deepEquals([1, 3]);
      check(clone.nextId).equals(4);
    });
  });

  group('RpnStack', () {
    test('supports DUP, DROP, SWAP, OVER, ROT, PICK, ROLL, DEPTH, CLEAR, and checkpoints', () {
      final stack = RpnStack();
      StackItem item(int n) =>
          StackItem(resultId: n, value: ExprValue(IntegerNumber.of(n)));

      stack.push(item(10));
      stack.push(item(20));
      stack.push(item(30));
      check(stack.depth).equals(3);
      check(stack.level(1).value).equals(ExprValue(IntegerNumber.of(30)));
      check(stack.level(3).value).equals(ExprValue(IntegerNumber.of(10)));

      // SWAP exchanges 1: and 2:
      stack.swap();
      check(stack.level(1).value).equals(ExprValue(IntegerNumber.of(20)));
      check(stack.level(2).value).equals(ExprValue(IntegerNumber.of(30)));

      // ROT rotates 3: a, 2: b, 1: c -> 3: b, 2: c, 1: a
      stack.rot();
      check(stack.level(1).value).equals(ExprValue(IntegerNumber.of(10)));

      // OVER copies level 2: to top
      stack.over();
      check(stack.depth).equals(4);
      check(stack.level(1).value).equals(stack.level(3).value);

      // DUP and DROP
      stack.dup();
      check(stack.depth).equals(5);
      stack.drop();
      check(stack.depth).equals(4);

      // PICK with integer on level 1
      stack.push(item(2));
      stack.pick();
      check(stack.level(1).value).equals(ExprValue(IntegerNumber.of(10)));

      // popArgs
      final args = stack.popArgs(2);
      check(args.length).equals(2);

      // checkpoint and rollback
      final cp = stack.checkpoint();
      stack.push(item(999));
      stack.drop();
      stack.popArgs(1);
      check(stack.depth).not((it) => it.equals(cp.items.length));
      stack.restoreCheckpoint(cp);
      check(stack.depth).equals(cp.items.length);
      check(stack.level(1).value).equals(cp.items.last.value);

      // CLEAR
      stack.clear();
      check(stack.isEmpty).isTrue();
    });
  });
}
