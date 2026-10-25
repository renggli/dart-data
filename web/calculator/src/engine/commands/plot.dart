import 'package:data/symbolic.dart';

import '../../model/value.dart';
import '../commands.dart';
import '../sampling.dart';

/// Builds canonical plotting commands (`plot`).
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
    doc: 'Plots one or more expressions over [a, b] with adaptive sampling.',
    examples: const [
      'plot(sin(x) / x, x, -10, 10)',
      'plot([sin(x), cos(x)], x, -pi, pi)',
      'plot(tan(x), x, -5, 5)',
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
