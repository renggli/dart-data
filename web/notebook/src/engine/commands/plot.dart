import 'package:data/symbolic.dart';

import '../../language/signature.dart';
import '../../model/value.dart';
import '../commands.dart';

void _validatePlot(
  List<Expr> exprs,
  Set<String> allowedVars, {
  required PlotKind kind,
  required String xVar,
  String? yVar,
  String? zVar,
}) {
  final unbound = <String>{};
  for (final expr in exprs) {
    unbound.addAll(expr.freeVariables.difference(allowedVars));
  }
  if (unbound.isNotEmpty) {
    final sorted = unbound.toList()..sort();
    final quoted = sorted.map((v) => "'$v'").join(', ');
    final noun = sorted.length == 1 ? 'variable' : 'variables';
    final pronoun = sorted.length == 1 ? 'it' : 'them';
    throw ArgumentBindingException(
      'Unbound $noun $quoted in plot expression. Define $pronoun first.',
    );
  }
  for (final expr in exprs) {
    switch (kind) {
      case PlotKind.function2d || PlotKind.parametric2d:
        expr.toFunction1D(xVar);
      case PlotKind.complex2d || PlotKind.complex3d:
        expr.toComplexFunction1D(xVar);
      case PlotKind.surface3d ||
          PlotKind.heatmap2d ||
          PlotKind.vectorField2d ||
          PlotKind.ode2d:
        expr.toVectorFunction([xVar, yVar ?? 'y']);
      case PlotKind.vectorField3d:
        expr.toVectorFunction([xVar, yVar ?? 'y', zVar ?? 'z']);
    }
  }
}

({String xVar, String yVar}) _inferVars2D(
  Set<String> vars, {
  String? explicitX,
  String? explicitY,
}) {
  if (explicitX != null && explicitY != null) {
    return (xVar: explicitX, yVar: explicitY);
  }
  final remaining = vars.toList()..sort();
  final xVar =
      explicitX ?? (vars.contains('x') ? 'x' : remaining.firstOrNull ?? 'x');
  remaining.remove(xVar);
  final yVar =
      explicitY ?? (vars.contains('y') ? 'y' : remaining.firstOrNull ?? 'y');
  return (xVar: xVar, yVar: yVar);
}

final List<Command> plotCommands = [
  Command(
    name: 'plot',
    category: CommandCategory.plot,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('expr', type: ParamType.exprList),
        ParamSpec.optional('var', type: ParamType.symbol),
      ],
      named: [
        ParamSpec.named(
          'x',
          type: ParamType.range,
          defaultValue: NumericRange(-10.0, 10.0),
        ),
        ParamSpec.named('y', type: ParamType.range),
        ParamSpec.named('title', type: ParamType.string),
        ParamSpec.named('markers', type: ParamType.boolean, defaultValue: true),
        ParamSpec.named('grid', type: ParamType.boolean, defaultValue: true),
      ],
    ),
    doc: 'Plots one or more expressions over a 1D interval.',
    examples: [
      'plot(sin(x), x, x: -pi..pi)',
      "plot([sin(x), cos(x)], x, x: 0..2*pi, y: -1.5..1.5, title: 'Trig')",
    ],
    chipLabel: 'Plot',
    appliesTo: (v) => v is ExprValue && v.expr.freeVariables.length <= 1,
    buildChipCall: (input, v) {
      final vName = inferVariable((v as ExprValue).expr);
      return 'plot($input, $vName)';
    },
    run: (args, _) {
      final exprs = args.exprList('expr');
      final v = inferVariable(exprs.first, args.symbolOrNull('var'));
      final xRange = args.numericRange('x');
      final yRange = args.numericRangeOrNull('y');
      _validatePlot(exprs, {v}, kind: PlotKind.function2d, xVar: v);

      return PlotValue(
        expressions: exprs,
        variable: v,
        minX: xRange.start,
        maxX: xRange.end,
        minY: yRange?.start ?? -5.0,
        maxY: yRange?.end ?? 5.0,
        title: args.stringOrNull('title'),
        showMarkers: args.boolVal('markers', fallback: true),
        showGrid: args.boolVal('grid', fallback: true),
      );
    },
  ),
  Command(
    name: 'parametric',
    category: CommandCategory.plot,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('xExpr'),
        ParamSpec.positional('yExpr'),
        ParamSpec.optional('var', type: ParamType.symbol),
      ],
      named: [
        ParamSpec.named(
          't',
          type: ParamType.range,
          defaultValue: NumericRange(0.0, 6.283185307179586),
        ),
        ParamSpec.named('title', type: ParamType.string),
        ParamSpec.named('grid', type: ParamType.boolean, defaultValue: true),
      ],
    ),
    doc: 'Plots a 2D parametric curve `(x(t), y(t))`.',
    examples: ['parametric(cos(t), sin(t), t, t: 0..2*pi)'],
    run: (args, _) {
      final xExpr = args.expr('xExpr');
      final yExpr = args.expr('yExpr');
      final tVar = args.symbolOrNull('var') ?? inferVariable(xExpr);
      final tRange = args.numericRange('t');
      _validatePlot(
        [xExpr, yExpr],
        {tVar},
        kind: PlotKind.parametric2d,
        xVar: tVar,
      );

      return PlotValue(
        expressions: [xExpr, yExpr],
        variable: tVar,
        minX: -1.0,
        maxX: 1.0,
        minY: -1.0,
        maxY: 1.0,
        isParametric: true,
        minT: tRange.start,
        maxT: tRange.end,
        title: args.stringOrNull('title'),
        showGrid: args.boolVal('grid', fallback: true),
        plotKind: PlotKind.parametric2d,
      );
    },
  ),
  Command(
    name: 'plot3d',
    category: CommandCategory.plot,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('expr'),
        ParamSpec.optional('xVar', type: ParamType.symbol),
        ParamSpec.optional('yVar', type: ParamType.symbol),
      ],
      named: [
        ParamSpec.named(
          'x',
          type: ParamType.range,
          defaultValue: NumericRange(-3.0, 3.0),
        ),
        ParamSpec.named(
          'y',
          type: ParamType.range,
          defaultValue: NumericRange(-3.0, 3.0),
        ),
        ParamSpec.named('grid', type: ParamType.integer, defaultValue: 48),
        ParamSpec.named('title', type: ParamType.string),
      ],
    ),
    doc: 'Plots a 3D surface `z = f(x, y)`.',
    examples: ['plot3d(sin(x) * cos(y), x, y, x: -pi..pi, y: -pi..pi)'],
    appliesTo: (v) => v is ExprValue && v.expr.freeVariables.length == 2,
    chipLabel: 'Plot 3D',
    buildChipCall: (input, _) => 'plot3d($input)',
    run: (args, _) {
      final expr = args.expr('expr');
      final inferred = _inferVars2D(
        expr.freeVariables,
        explicitX: args.symbolOrNull('xVar'),
        explicitY: args.symbolOrNull('yVar'),
      );
      final xVar = inferred.xVar;
      final yVar = inferred.yVar;
      final xRange = args.numericRange('x');
      final yRange = args.numericRange('y');
      final grid = args.intVal('grid').clamp(12, 128);
      _validatePlot(
        [expr],
        {xVar, yVar},
        kind: PlotKind.surface3d,
        xVar: xVar,
        yVar: yVar,
      );

      return PlotValue(
        expressions: [expr],
        variable: xVar,
        yVariable: yVar,
        minX: xRange.start,
        maxX: xRange.end,
        minY: yRange.start,
        maxY: yRange.end,
        title: args.stringOrNull('title'),
        plotKind: PlotKind.surface3d,
        gridSize: grid,
      );
    },
  ),
  Command(
    name: 'plotcomplex',
    category: CommandCategory.plot,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('expr'),
        ParamSpec.optional('var', type: ParamType.symbol),
      ],
      named: [
        ParamSpec.named(
          're',
          type: ParamType.range,
          defaultValue: NumericRange(-3.0, 3.0),
        ),
        ParamSpec.named(
          'im',
          type: ParamType.range,
          defaultValue: NumericRange(-3.0, 3.0),
        ),
        ParamSpec.named(
          'contours',
          type: ParamType.boolean,
          defaultValue: true,
        ),
        ParamSpec.named('title', type: ParamType.string),
      ],
    ),
    doc:
        'Renders a 2D OKLCH domain-coloring plot of a complex function `f(z)`.',
    examples: ['plotcomplex((z^2 - 1)/(z + 2), z, re: -3..3, im: -3..3)'],
    run: (args, _) {
      final expr = args.expr('expr');
      final zVar = args.symbolOrNull('var') ?? inferVariable(expr);
      final reRange = args.numericRange('re');
      final imRange = args.numericRange('im');
      _validatePlot([expr], {zVar}, kind: PlotKind.complex2d, xVar: zVar);

      return PlotValue(
        expressions: [expr],
        variable: zVar,
        minX: reRange.start,
        maxX: reRange.end,
        minY: imRange.start,
        maxY: imRange.end,
        isComplex: true,
        showContours: args.boolVal('contours', fallback: true),
        title: args.stringOrNull('title'),
        plotKind: PlotKind.complex2d,
      );
    },
  ),
  Command(
    name: 'plotcomplex3d',
    category: CommandCategory.plot,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('expr'),
        ParamSpec.optional('var', type: ParamType.symbol),
      ],
      named: [
        ParamSpec.named(
          're',
          type: ParamType.range,
          defaultValue: NumericRange(-3.0, 3.0),
        ),
        ParamSpec.named(
          'im',
          type: ParamType.range,
          defaultValue: NumericRange(-3.0, 3.0),
        ),
        ParamSpec.named('grid', type: ParamType.integer, defaultValue: 64),
        ParamSpec.named('title', type: ParamType.string),
      ],
    ),
    doc: 'Renders a 3D analytic landscape of `|f(z)|` colored by `arg(f(z))`.',
    examples: ['plotcomplex3d(1/(z^2 + 1), z, re: -2..2, im: -2..2)'],
    run: (args, _) {
      final expr = args.expr('expr');
      final zVar = args.symbolOrNull('var') ?? inferVariable(expr);
      final reRange = args.numericRange('re');
      final imRange = args.numericRange('im');
      final grid = args.intVal('grid').clamp(12, 128);
      _validatePlot([expr], {zVar}, kind: PlotKind.complex3d, xVar: zVar);

      return PlotValue(
        expressions: [expr],
        variable: zVar,
        minX: reRange.start,
        maxX: reRange.end,
        minY: imRange.start,
        maxY: imRange.end,
        isComplex: true,
        title: args.stringOrNull('title'),
        plotKind: PlotKind.complex3d,
        gridSize: grid,
      );
    },
  ),
  Command(
    name: 'ode',
    category: CommandCategory.plot,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('rhs'),
        ParamSpec.optional('yVar', type: ParamType.symbol),
        ParamSpec.optional('tVar', type: ParamType.symbol),
      ],
      named: [
        ParamSpec.named('y0', type: ParamType.number, defaultValue: 1.0),
        ParamSpec.named(
          't',
          type: ParamType.range,
          defaultValue: NumericRange(0.0, 10.0),
        ),
        ParamSpec.named(
          'method',
          type: ParamType.string,
          defaultValue: 'dormandPrince45',
          enumValues: ['dormandPrince45', 'rk4', 'bdf2'],
        ),
        ParamSpec.named('title', type: ParamType.string),
        ParamSpec.named('grid', type: ParamType.boolean, defaultValue: true),
      ],
    ),
    doc: 'Numerically solves and plots `dy/dt = rhs(t, y)` over the interval `t: t0..t1` from `y(t0) = y0`.',
    examples: ['ode(-y, y, t, y0: 1, t: 0..5)'],
    run: (args, _) {
      var rhs = args.expr('rhs');
      if (rhs case Relational(op: RelOp.equal, :final right)) rhs = right;
      final yVar = args.symbolOrNull('yVar') ?? 'y';
      final tVar = args.symbolOrNull('tVar') ?? 't';
      final y0 = args.doubleVal('y0');
      final tRange = args.numericRange('t');
      final method = args.stringVal('method');
      _validatePlot(
        [rhs],
        {tVar, yVar},
        kind: PlotKind.ode2d,
        xVar: tVar,
        yVar: yVar,
      );

      return PlotValue(
        expressions: [rhs],
        variable: tVar,
        yVariable: yVar,
        minX: tRange.start,
        maxX: tRange.end,
        minY: y0 - 1.0,
        maxY: y0 + 1.0,
        odeY0: y0,
        odeMethod: method,
        isOde: true,
        showGrid: args.boolVal('grid', fallback: true),
        title: args.stringOrNull('title'),
        plotKind: PlotKind.ode2d,
      );
    },
  ),
  Command(
    name: 'vectorfield',
    category: CommandCategory.plot,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('uExpr'),
        ParamSpec.positional('vExpr'),
        ParamSpec.optional('xVar', type: ParamType.symbol),
        ParamSpec.optional('yVar', type: ParamType.symbol),
      ],
      named: [
        ParamSpec.named(
          'x',
          type: ParamType.range,
          defaultValue: NumericRange(-3.0, 3.0),
        ),
        ParamSpec.named(
          'y',
          type: ParamType.range,
          defaultValue: NumericRange(-3.0, 3.0),
        ),
        ParamSpec.named('grid', type: ParamType.integer, defaultValue: 18),
        ParamSpec.named('title', type: ParamType.string),
      ],
    ),
    doc: 'Plots a 2D vector field `(u(x, y), v(x, y))`.',
    examples: ['vectorfield(-y, x, x, y, x: -3..3, y: -3..3)'],
    run: (args, _) {
      final uExpr = args.expr('uExpr');
      final vExpr = args.expr('vExpr');
      final inferred = _inferVars2D(
        {...uExpr.freeVariables, ...vExpr.freeVariables},
        explicitX: args.symbolOrNull('xVar'),
        explicitY: args.symbolOrNull('yVar'),
      );
      final xVar = inferred.xVar;
      final yVar = inferred.yVar;
      final xRange = args.numericRange('x');
      final yRange = args.numericRange('y');
      final grid = args.intVal('grid').clamp(4, 32);
      _validatePlot(
        [uExpr, vExpr],
        {xVar, yVar},
        kind: PlotKind.vectorField2d,
        xVar: xVar,
        yVar: yVar,
      );

      return PlotValue(
        expressions: [uExpr, vExpr],
        variable: xVar,
        yVariable: yVar,
        minX: xRange.start,
        maxX: xRange.end,
        minY: yRange.start,
        maxY: yRange.end,
        title: args.stringOrNull('title'),
        plotKind: PlotKind.vectorField2d,
        gridSize: grid,
      );
    },
  ),
  Command(
    name: 'heatmap',
    category: CommandCategory.plot,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('expr'),
        ParamSpec.optional('xVar', type: ParamType.symbol),
        ParamSpec.optional('yVar', type: ParamType.symbol),
      ],
      named: [
        ParamSpec.named(
          'x',
          type: ParamType.range,
          defaultValue: NumericRange(-3.0, 3.0),
        ),
        ParamSpec.named(
          'y',
          type: ParamType.range,
          defaultValue: NumericRange(-3.0, 3.0),
        ),
        ParamSpec.named('grid', type: ParamType.integer, defaultValue: 64),
        ParamSpec.named('title', type: ParamType.string),
      ],
    ),
    doc: 'Plots a 2D scalar heatmap `z = f(x, y)`.',
    examples: ['heatmap(sin(x)*cos(y), x, y, x: -pi..pi, y: -pi..pi)'],
    run: (args, _) {
      final expr = args.expr('expr');
      final inferred = _inferVars2D(
        expr.freeVariables,
        explicitX: args.symbolOrNull('xVar'),
        explicitY: args.symbolOrNull('yVar'),
      );
      final xVar = inferred.xVar;
      final yVar = inferred.yVar;
      final xRange = args.numericRange('x');
      final yRange = args.numericRange('y');
      final grid = args.intVal('grid').clamp(16, 200);
      _validatePlot(
        [expr],
        {xVar, yVar},
        kind: PlotKind.heatmap2d,
        xVar: xVar,
        yVar: yVar,
      );

      return PlotValue(
        expressions: [expr],
        variable: xVar,
        yVariable: yVar,
        minX: xRange.start,
        maxX: xRange.end,
        minY: yRange.start,
        maxY: yRange.end,
        title: args.stringOrNull('title'),
        plotKind: PlotKind.heatmap2d,
        gridSize: grid,
      );
    },
  ),
  Command(
    name: 'vectorfield3d',
    category: CommandCategory.plot,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('vxExpr'),
        ParamSpec.positional('vyExpr'),
        ParamSpec.positional('vzExpr'),
        ParamSpec.optional('xVar', type: ParamType.symbol),
        ParamSpec.optional('yVar', type: ParamType.symbol),
        ParamSpec.optional('zVar', type: ParamType.symbol),
      ],
      named: [
        ParamSpec.named(
          'x',
          type: ParamType.range,
          defaultValue: NumericRange(-2.0, 2.0),
        ),
        ParamSpec.named(
          'y',
          type: ParamType.range,
          defaultValue: NumericRange(-2.0, 2.0),
        ),
        ParamSpec.named('grid', type: ParamType.integer, defaultValue: 6),
        ParamSpec.named('title', type: ParamType.string),
      ],
    ),
    doc: 'Plots a 3D vector field `(vx, vy, vz)`.',
    examples: ['vectorfield3d(-y, x, z, x, y, z, x: -2..2, y: -2..2)'],
    run: (args, _) {
      final vxExpr = args.expr('vxExpr');
      final vyExpr = args.expr('vyExpr');
      final vzExpr = args.expr('vzExpr');
      final xVar = args.symbolOrNull('xVar') ?? 'x';
      final yVar = args.symbolOrNull('yVar') ?? 'y';
      final xRange = args.numericRange('x');
      final yRange = args.numericRange('y');
      final grid = args.intVal('grid').clamp(3, 10);
      _validatePlot(
        [vxExpr, vyExpr, vzExpr],
        {xVar, yVar, args.symbolOrNull('zVar') ?? 'z'},
        kind: PlotKind.vectorField3d,
        xVar: xVar,
        yVar: yVar,
        zVar: args.symbolOrNull('zVar') ?? 'z',
      );

      return PlotValue(
        expressions: [vxExpr, vyExpr, vzExpr],
        variable: xVar,
        yVariable: yVar,
        minX: xRange.start,
        maxX: xRange.end,
        minY: yRange.start,
        maxY: yRange.end,
        title: args.stringOrNull('title'),
        plotKind: PlotKind.vectorField3d,
        gridSize: grid,
      );
    },
  ),
];
