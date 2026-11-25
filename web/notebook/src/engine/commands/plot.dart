import 'package:data/symbolic.dart';

import '../../language/signature.dart';
import '../../model/value.dart';
import '../commands.dart';

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
        ParamSpec.named('from', type: ParamType.number, defaultValue: -5.0),
        ParamSpec.named('to', type: ParamType.number, defaultValue: 5.0),
        ParamSpec.named('yMin', type: ParamType.number),
        ParamSpec.named('yMax', type: ParamType.number),
        ParamSpec.named('title', type: ParamType.string),
        ParamSpec.named('samples', type: ParamType.integer, defaultValue: 400),
        ParamSpec.named('markers', type: ParamType.boolean, defaultValue: true),
        ParamSpec.named('grid', type: ParamType.boolean, defaultValue: true),
      ],
    ),
    doc: 'Plots one or more expressions over a 1D interval.',
    examples: [
      'plot(sin(x), x, from: -pi, to: pi)',
      "plot([sin(x), cos(x)], x, title: 'Trig')",
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
      final minX = args.doubleVal('from');
      final maxX = args.doubleVal('to');
      final yMinArg = args.doubleOrNull('yMin');
      final yMaxArg = args.doubleOrNull('yMax');

      return PlotValue(
        expressions: exprs,
        variable: v,
        minX: minX,
        maxX: maxX,
        minY: yMinArg ?? -5.0,
        maxY: yMaxArg ?? 5.0,
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
        ParamSpec.optional('t', type: ParamType.symbol),
      ],
      named: [
        ParamSpec.named('from', type: ParamType.number, defaultValue: 0.0),
        ParamSpec.named(
          'to',
          type: ParamType.number,
          defaultValue: 6.283185307179586,
        ),
        ParamSpec.named('title', type: ParamType.string),
        ParamSpec.named('samples', type: ParamType.integer, defaultValue: 400),
        ParamSpec.named('grid', type: ParamType.boolean, defaultValue: true),
      ],
    ),
    doc: 'Plots a 2D parametric curve `(x(t), y(t))`.',
    examples: ['parametric(cos(t), sin(t), t, from: 0, to: 2*pi)'],
    run: (args, _) {
      final xExpr = args.expr('xExpr');
      final yExpr = args.expr('yExpr');
      final tVar = args.symbolOrNull('t') ?? inferVariable(xExpr);
      final minT = args.doubleVal('from');
      final maxT = args.doubleVal('to');

      return PlotValue(
        expressions: [xExpr, yExpr],
        variable: tVar,
        minX: -1.0,
        maxX: 1.0,
        minY: -1.0,
        maxY: 1.0,
        isParametric: true,
        minT: minT,
        maxT: maxT,
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
        ParamSpec.optional('x', type: ParamType.symbol),
        ParamSpec.optional('y', type: ParamType.symbol),
      ],
      named: [
        ParamSpec.named('xFrom', type: ParamType.number, defaultValue: -3.0),
        ParamSpec.named('xTo', type: ParamType.number, defaultValue: 3.0),
        ParamSpec.named('yFrom', type: ParamType.number, defaultValue: -3.0),
        ParamSpec.named('yTo', type: ParamType.number, defaultValue: 3.0),
        ParamSpec.named('grid', type: ParamType.integer, defaultValue: 48),
        ParamSpec.named('title', type: ParamType.string),
      ],
    ),
    doc: 'Plots a 3D surface `z = f(x, y)`.',
    examples: ['plot3d(sin(x) * cos(y), x, y)'],
    appliesTo: (v) => v is ExprValue && v.expr.freeVariables.length == 2,
    chipLabel: 'Plot 3D',
    buildChipCall: (input, _) => 'plot3d($input)',
    run: (args, _) {
      final expr = args.expr('expr');
      final vars = expr.freeVariables.toList()..sort();
      final xVar = args.symbolOrNull('x') ?? (vars.isNotEmpty ? vars[0] : 'x');
      final yVar = args.symbolOrNull('y') ?? (vars.length > 1 ? vars[1] : 'y');
      final xFrom = args.doubleVal('xFrom');
      final xTo = args.doubleVal('xTo');
      final yFrom = args.doubleVal('yFrom');
      final yTo = args.doubleVal('yTo');
      final grid = args.intVal('grid').clamp(12, 128);

      return PlotValue(
        expressions: [expr],
        variable: xVar,
        yVariable: yVar,
        minX: xFrom,
        maxX: xTo,
        minY: yFrom,
        maxY: yTo,
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
        ParamSpec.optional('z', type: ParamType.symbol),
      ],
      named: [
        ParamSpec.named('reFrom', type: ParamType.number, defaultValue: -3.0),
        ParamSpec.named('reTo', type: ParamType.number, defaultValue: 3.0),
        ParamSpec.named('imFrom', type: ParamType.number, defaultValue: -3.0),
        ParamSpec.named('imTo', type: ParamType.number, defaultValue: 3.0),
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
    examples: ['plotcomplex((z^2 - 1)/(z + 2), z)'],
    run: (args, _) {
      final expr = args.expr('expr');
      final zVar = args.symbolOrNull('z') ?? inferVariable(expr, null);
      final reFrom = args.doubleVal('reFrom');
      final reTo = args.doubleVal('reTo');
      final imFrom = args.doubleVal('imFrom');
      final imTo = args.doubleVal('imTo');

      return PlotValue(
        expressions: [expr],
        variable: zVar,
        minX: reFrom,
        maxX: reTo,
        minY: imFrom,
        maxY: imTo,
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
        ParamSpec.optional('z', type: ParamType.symbol),
      ],
      named: [
        ParamSpec.named('reFrom', type: ParamType.number, defaultValue: -3.0),
        ParamSpec.named('reTo', type: ParamType.number, defaultValue: 3.0),
        ParamSpec.named('imFrom', type: ParamType.number, defaultValue: -3.0),
        ParamSpec.named('imTo', type: ParamType.number, defaultValue: 3.0),
        ParamSpec.named('grid', type: ParamType.integer, defaultValue: 48),
        ParamSpec.named('title', type: ParamType.string),
      ],
    ),
    doc: 'Renders a 3D analytic landscape of `|f(z)|` colored by `arg(f(z))`.',
    examples: ['plotcomplex3d(1/(z^2 + 1), z)'],
    run: (args, _) {
      final expr = args.expr('expr');
      final zVar = args.symbolOrNull('z') ?? inferVariable(expr, null);
      final reFrom = args.doubleVal('reFrom');
      final reTo = args.doubleVal('reTo');
      final imFrom = args.doubleVal('imFrom');
      final imTo = args.doubleVal('imTo');
      final grid = args.intVal('grid').clamp(12, 128);

      return PlotValue(
        expressions: [expr],
        variable: zVar,
        minX: reFrom,
        maxX: reTo,
        minY: imFrom,
        maxY: imTo,
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
        ParamSpec.optional('y', type: ParamType.symbol),
        ParamSpec.optional('t', type: ParamType.symbol),
      ],
      named: [
        ParamSpec.named('y0', type: ParamType.number, defaultValue: 1.0),
        ParamSpec.named('from', type: ParamType.number, defaultValue: 0.0),
        ParamSpec.named('to', type: ParamType.number, defaultValue: 10.0),
        ParamSpec.named(
          'method',
          type: ParamType.string,
          defaultValue: 'rk4',
          enumValues: ['euler', 'rk4', 'rk45'],
        ),
        ParamSpec.named('title', type: ParamType.string),
      ],
    ),
    doc:
        'Numerically solves and plots `dy/dt = rhs(t, y)` from `y(from) = y0`.',
    examples: ['ode(-y, y, t, y0: 1, from: 0, to: 5)'],
    run: (args, _) {
      var rhs = args.expr('rhs');
      if (rhs case Equal(:final right)) rhs = right;
      final yVar = args.symbolOrNull('y') ?? 'y';
      final tVar = args.symbolOrNull('t') ?? 't';
      final y0 = args.doubleVal('y0');
      final t0 = args.doubleVal('from');
      final t1 = args.doubleVal('to');

      return PlotValue(
        expressions: [rhs],
        variable: tVar,
        yVariable: yVar,
        minX: t0,
        maxX: t1,
        minY: y0 - 1.0,
        maxY: y0 + 1.0,
        odeY0: y0,
        isOde: true,
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
        ParamSpec.optional('x', type: ParamType.symbol),
        ParamSpec.optional('y', type: ParamType.symbol),
      ],
      named: [
        ParamSpec.named('xFrom', type: ParamType.number, defaultValue: -3.0),
        ParamSpec.named('xTo', type: ParamType.number, defaultValue: 3.0),
        ParamSpec.named('yFrom', type: ParamType.number, defaultValue: -3.0),
        ParamSpec.named('yTo', type: ParamType.number, defaultValue: 3.0),
        ParamSpec.named('grid', type: ParamType.integer, defaultValue: 16),
        ParamSpec.named('title', type: ParamType.string),
      ],
    ),
    doc: 'Plots a 2D vector field `(u(x, y), v(x, y))`.',
    examples: ['vectorfield(-y, x, x, y)'],
    run: (args, _) {
      final uExpr = args.expr('uExpr');
      final vExpr = args.expr('vExpr');
      final vars = {...uExpr.freeVariables, ...vExpr.freeVariables}.toList()
        ..sort();
      final xVar = args.symbolOrNull('x') ?? (vars.isNotEmpty ? vars[0] : 'x');
      final yVar = args.symbolOrNull('y') ?? (vars.length > 1 ? vars[1] : 'y');
      final xFrom = args.doubleVal('xFrom');
      final xTo = args.doubleVal('xTo');
      final yFrom = args.doubleVal('yFrom');
      final yTo = args.doubleVal('yTo');
      final grid = args.intVal('grid').clamp(4, 32);

      return PlotValue(
        expressions: [uExpr, vExpr],
        variable: xVar,
        yVariable: yVar,
        minX: xFrom,
        maxX: xTo,
        minY: yFrom,
        maxY: yTo,
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
        ParamSpec.optional('x', type: ParamType.symbol),
        ParamSpec.optional('y', type: ParamType.symbol),
      ],
      named: [
        ParamSpec.named('xFrom', type: ParamType.number, defaultValue: -3.0),
        ParamSpec.named('xTo', type: ParamType.number, defaultValue: 3.0),
        ParamSpec.named('yFrom', type: ParamType.number, defaultValue: -3.0),
        ParamSpec.named('yTo', type: ParamType.number, defaultValue: 3.0),
        ParamSpec.named('grid', type: ParamType.integer, defaultValue: 80),
        ParamSpec.named('title', type: ParamType.string),
      ],
    ),
    doc: 'Plots a 2D scalar heatmap `z = f(x, y)`.',
    examples: ['heatmap(sin(x)*cos(y), x, y)'],
    run: (args, _) {
      final expr = args.expr('expr');
      final vars = expr.freeVariables.toList()..sort();
      final xVar = args.symbolOrNull('x') ?? (vars.isNotEmpty ? vars[0] : 'x');
      final yVar = args.symbolOrNull('y') ?? (vars.length > 1 ? vars[1] : 'y');
      final xFrom = args.doubleVal('xFrom');
      final xTo = args.doubleVal('xTo');
      final yFrom = args.doubleVal('yFrom');
      final yTo = args.doubleVal('yTo');
      final grid = args.intVal('grid').clamp(16, 200);

      return PlotValue(
        expressions: [expr],
        variable: xVar,
        yVariable: yVar,
        minX: xFrom,
        maxX: xTo,
        minY: yFrom,
        maxY: yTo,
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
        ParamSpec.optional('x', type: ParamType.symbol),
        ParamSpec.optional('y', type: ParamType.symbol),
        ParamSpec.optional('z', type: ParamType.symbol),
      ],
      named: [
        ParamSpec.named('from', type: ParamType.number, defaultValue: -2.0),
        ParamSpec.named('to', type: ParamType.number, defaultValue: 2.0),
        ParamSpec.named('grid', type: ParamType.integer, defaultValue: 5),
        ParamSpec.named('title', type: ParamType.string),
      ],
    ),
    doc: 'Plots a 3D vector field `(vx, vy, vz)`.',
    examples: ['vectorfield3d(-y, x, z, x, y, z)'],
    run: (args, _) {
      final vxExpr = args.expr('vxExpr');
      final vyExpr = args.expr('vyExpr');
      final vzExpr = args.expr('vzExpr');
      final xVar = args.symbolOrNull('x') ?? 'x';
      final yVar = args.symbolOrNull('y') ?? 'y';
      final from = args.doubleVal('from');
      final to = args.doubleVal('to');
      final grid = args.intVal('grid').clamp(3, 10);

      return PlotValue(
        expressions: [vxExpr, vyExpr, vzExpr],
        variable: xVar,
        yVariable: yVar,
        minX: from,
        maxX: to,
        minY: from,
        maxY: to,
        title: args.stringOrNull('title'),
        plotKind: PlotKind.vectorField3d,
        gridSize: grid,
      );
    },
  ),
];
