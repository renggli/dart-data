import 'package:data/numeric.dart';
import 'package:data/symbolic.dart';

import '../../language/signature.dart';
import '../../model/value.dart';
import '../commands.dart';
import '../sampling.dart';

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
      return buildPlotValue(
        exprs,
        v,
        args.doubleVal('from'),
        args.doubleVal('to'),
        yMin: args.doubleOrNull('yMin'),
        yMax: args.doubleOrNull('yMax'),
        title: args.stringOrNull('title'),
        showMarkers: args.boolVal('markers', fallback: true),
        showGrid: args.boolVal('grid', fallback: true),
        maxPoints: (args.intVal('samples') * 3).clamp(128, 4096),
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
      final t = args.symbolOrNull('t') ?? inferVariable(xExpr);
      return buildParametricPlotValue(
        xExpr,
        yExpr,
        t,
        args.doubleVal('from'),
        args.doubleVal('to'),
        title: args.stringOrNull('title'),
        showGrid: args.boolVal('grid', fallback: true),
        maxPoints: (args.intVal('samples') * 4).clamp(256, 8192),
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
    examples: ['plot3d(sin(x)*cos(y), x, y)'],
    run: (args, _) {
      final expr = args.expr('expr');
      final vars = expr.freeVariables.toList()..sort();
      final xVar = args.symbolOrNull('x') ?? (vars.isNotEmpty ? vars[0] : 'x');
      final yVar = args.symbolOrNull('y') ?? (vars.length > 1 ? vars[1] : 'y');
      return buildSurface3dPlotValue(
        expr,
        xVar,
        args.doubleVal('xFrom'),
        args.doubleVal('xTo'),
        yVar,
        args.doubleVal('yFrom'),
        args.doubleVal('yTo'),
        gridSize: args.intVal('grid').clamp(12, 128),
        title: args.stringOrNull('title'),
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
      return buildComplexPlotValue(
        expr,
        zVar,
        args.doubleVal('reFrom'),
        args.doubleVal('reTo'),
        args.doubleVal('imFrom'),
        args.doubleVal('imTo'),
        showContours: args.boolVal('contours', fallback: true),
        title: args.stringOrNull('title'),
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
      return buildComplex3dPlotValue(
        expr,
        zVar,
        args.doubleVal('reFrom'),
        args.doubleVal('reTo'),
        args.doubleVal('imFrom'),
        args.doubleVal('imTo'),
        gridSize: args.intVal('grid').clamp(12, 128),
        title: args.stringOrNull('title'),
      );
    },
  ),
  Command(
    name: 'ode',
    category: CommandCategory.plot,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('rhs', type: ParamType.equation),
        ParamSpec.optional('y', type: ParamType.symbol),
        ParamSpec.optional('t', type: ParamType.symbol),
      ],
      named: [
        ParamSpec.named('at', type: ParamType.number, defaultValue: 0.0),
        ParamSpec.named('y0', type: ParamType.number, defaultValue: 1.0),
        ParamSpec.named('from', type: ParamType.number, defaultValue: 0.0),
        ParamSpec.named('to', type: ParamType.number, defaultValue: 10.0),
        ParamSpec.named(
          'method',
          type: ParamType.string,
          defaultValue: 'rk4',
          enumValues: ['rk4', 'dormandPrince45', 'bdf2'],
        ),
        ParamSpec.named('title', type: ParamType.string),
      ],
    ),
    doc: 'Solves a first-order ODE `dy/dt = f(t, y)` numerically and plots it.',
    examples: ['ode(-y + sin(t), y, t, y0: 1, from: 0, to: 10)'],
    run: (args, _) {
      final raw = args.expr('rhs');
      final rhs = raw is Equal ? raw.right : raw;
      final yVar = args.symbolOrNull('y') ?? 'y';
      final tVar = args.symbolOrNull('t') ?? 't';
      final method = switch (args.stringVal('method')) {
        'dormandPrince45' => OdeMethod.dormandPrince45,
        'bdf2' => OdeMethod.bdf2,
        _ => OdeMethod.rk4,
      };
      return buildOdePlotValue(
        rhs,
        tVar,
        yVar,
        args.doubleVal('y0'),
        args.doubleVal('from'),
        args.doubleVal('to'),
        method: method,
        title: args.stringOrNull('title'),
      );
    },
  ),
];
