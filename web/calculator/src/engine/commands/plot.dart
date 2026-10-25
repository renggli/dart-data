import 'dart:math' as math;

import 'package:data/symbolic.dart';

import '../../model/value.dart';
import '../commands.dart';
import '../sampling.dart';

/// Builds canonical plotting commands (`plot`, `parametric`, `ode`).
List<Command> buildPlotCommands() => [
  Command(
    name: 'plot',
    category: CommandCategory.plot,
    signature: 'plot(expr, [var], [a, b])',
    paramSpecs: const [
      ParamSpec.expr('expr'),
      ParamSpec.symbol('[var]'),
      ParamSpec.optionalExpr('[a]'),
      ParamSpec.optionalExpr('[b]'),
    ],
    minArity: 1,
    maxArity: 4,
    doc: 'Plots one or more expressions (or parametric [x(t), y(t)]) over [a, b].',
    examples: const [
      'plot(sin(x) / x, x, -10, 10)',
      'plot([sin(x), cos(x)], x, -pi, pi)',
      'plot([cos(t), sin(t)], t, 0, 2 * pi)',
      'plot(sin(a * x + b), x, -5, 5)',
    ],
    rpnLabel: 'Plot',
    rpnArity: 1,
    appliesTo: (v) =>
        (v is ExprValue && !v.isEquation && v.expr.freeVariables.length <= 1) ||
        (v is SeriesValue),
    chipLabel: 'Plot',
    buildChipCall: (id, v) =>
        'plot(r[$id], ${primaryCommandVar(v) ?? 'x'}, -5, 5)',
    run: (args, ctx) {
      checkCommandArity('plot', args, 1, 4);
      final exprs = _extractPlotExpressions(args[0]);
      final inferredVar = _inferPlotVariable(exprs);
      final varName = args.length >= 2
          ? expectCommandVarName(args[1], 'plot')
          : inferredVar;
      // 2D Parametric curve when [x(t), y(t)] is plotted with parameter t
      if (args[0] is VectorValue && exprs.length == 2 && varName == 't') {
        final tMin = args.length >= 3
            ? expectCommandDouble(args[2], 'plot')
            : 0.0;
        final tMax = args.length >= 4
            ? expectCommandDouble(args[3], 'plot')
            : 2 * math.pi;
        return buildParametricPlotValue(
          exprs[0],
          exprs[1],
          varName,
          tMin,
          tMax,
          angleMode: ctx.settings.angleMode,
        );
      }
      final a = args.length >= 3 ? expectCommandDouble(args[2], 'plot') : -5.0;
      final b = args.length >= 4 ? expectCommandDouble(args[3], 'plot') : 5.0;
      return buildPlotValue(
        exprs,
        varName,
        a,
        b,
        angleMode: ctx.settings.angleMode,
      );
    },
  ),
  Command(
    name: 'parametric',
    category: CommandCategory.plot,
    signature: 'parametric([x(t), y(t)], [t], [tMin, tMax])',
    paramSpecs: const [
      ParamSpec.expr('[x(t), y(t)]'),
      ParamSpec.symbol('[t]'),
      ParamSpec.optionalExpr('[tMin]'),
      ParamSpec.optionalExpr('[tMax]'),
    ],
    minArity: 1,
    maxArity: 4,
    doc: 'Plots a 2D parametric curve (x(t), y(t)) over t ∈ [tMin, tMax].',
    examples: const [
      'parametric([cos(3 * t), sin(2 * t)], t, 0, 2 * pi)',
      'parametric([t * cos(t), t * sin(t)], t, 0, 4 * pi)',
    ],
    rpnLabel: 'Parametric',
    rpnArity: 1,
    appliesTo: (v) => v is VectorValue && v.vector.length == 2,
    chipLabel: 'Parametric',
    buildChipCall: (id, _) => 'parametric(r[$id], t, 0, 2 * pi)',
    run: (args, ctx) {
      checkCommandArity('parametric', args, 1, 4);
      final exprs = _extractPlotExpressions(args[0]);
      if (exprs.length != 2) {
        throw ArgumentError(
          'parametric expects a 2-element vector [x(t), y(t)].',
        );
      }
      final varName = args.length >= 2
          ? expectCommandVarName(args[1], 'parametric')
          : _inferPlotVariable(exprs);
      final tMin = args.length >= 3
          ? expectCommandDouble(args[2], 'parametric')
          : 0.0;
      final tMax = args.length >= 4
          ? expectCommandDouble(args[3], 'parametric')
          : 2 * math.pi;
      return buildParametricPlotValue(
        exprs[0],
        exprs[1],
        varName,
        tMin,
        tMax,
        angleMode: ctx.settings.angleMode,
      );
    },
  ),
  Command(
    name: 'ode',
    category: CommandCategory.plot,
    signature: 'ode(rhs, y0, [t0, t1])',
    paramSpecs: const [
      ParamSpec.expr('rhs'),
      ParamSpec.expr('y0'),
      ParamSpec.optionalExpr('[t0]'),
      ParamSpec.optionalExpr('[t1]'),
    ],
    minArity: 2,
    maxArity: 4,
    doc: "Integrates and plots y'(t) = f(t, y) with initial value y(t0) = y0 using RK45.",
    examples: const [
      'ode(-y + sin(t), 1, 0, 10)',
      'ode(y * (1 - y), 0.1, 0, 8)',
    ],
    rpnLabel: 'ODE Plot',
    rpnArity: 2,
    appliesTo: (_) => false,
    chipLabel: 'ODE',
    buildChipCall: (id, _) => 'ode(r[$id], 1, 0, 10)',
    run: (args, ctx) {
      checkCommandArity('ode', args, 2, 4);
      final rhs = expectCommandExpr(args[0], 'ode');
      final y0 = expectCommandDouble(args[1], 'ode');
      final t0 = args.length >= 3 ? expectCommandDouble(args[2], 'ode') : 0.0;
      final t1 = args.length >= 4 ? expectCommandDouble(args[3], 'ode') : 10.0;
      final free = rhs.freeVariables;
      final tVar = free.contains('t') ? 't' : (free.contains('x') ? 'x' : 't');
      final yVar = free.contains('y')
          ? 'y'
          : (free.where((v) => v != tVar).firstOrNull ?? 'y');
      return buildOdePlotValue(rhs, tVar, yVar, y0, t0, t1);
    },
  ),
];

List<Expr> _extractPlotExpressions(CalcValue arg) => switch (arg) {
  ExprValue(:final expr) => [
    if (expr case Equal(:final left, :final right)) left - right else expr,
  ],
  SeriesValue(:final polynomialExpr) => [polynomialExpr],
  VectorValue(:final vector) => [
    for (var i = 0; i < vector.length; i++) vector.getUnchecked(i),
  ],
  ListValue(:final elements) => [
    for (final elem in elements) ..._extractPlotExpressions(elem),
  ],
  _ => throw ArgumentError('Cannot plot value of kind ${arg.kind}.'),
};

String _inferPlotVariable(List<Expr> exprs) {
  for (final e in exprs) {
    final free = e.freeVariables;
    if (free.contains('x')) return 'x';
    if (free.contains('t')) return 't';
    if (free.isNotEmpty) return free.first;
  }
  return 'x';
}
