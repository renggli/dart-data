import 'dart:math' as math;
import 'dart:typed_data';

import 'package:data/linear.dart';
import 'package:data/numeric.dart';
import 'package:data/symbolic.dart';
import 'package:data/type.dart';

import '../../../../shared/graph/model/axis.dart';
import '../../../../shared/graph/model/dataset_2d.dart';
import '../../../../shared/graph/model/dataset_3d.dart';
import '../../../../shared/graph/model/style.dart';
import '../../../../shared/graph/sampling/oklch.dart';
import '../../../../shared/graph/sampling/sampler_2d.dart';
import '../../../../shared/graph/sampling/sampler_3d.dart';
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
      final samples = args.intVal('samples').clamp(32, 2048);

      final datasets = <Dataset2D>[];
      for (var i = 0; i < exprs.length; i++) {
        final expr = exprs[i];
        final fn = expr.toFunction1D(v);
        final color = defaultGraphPalette[i % defaultGraphPalette.length];
        datasets.add(
          sampleFunction2D(
            id: 'f$i',
            label: expr.toString(),
            fn: fn,
            xMin: minX,
            xMax: maxX,
            color: color,
            baseSamples: samples,
          ),
        );
      }

      final scene = Scene2D(
        datasets: datasets,
        xAxis: AxisConfig(label: v, min: minX, max: maxX),
        yAxis: AxisConfig(min: yMinArg, max: yMaxArg),
      );
      final b =
          scene.computeBounds() ??
          Bounds2D(
            xMin: minX,
            xMax: maxX,
            yMin: yMinArg ?? -5.0,
            yMax: yMaxArg ?? 5.0,
          );

      return PlotValue(
        expressions: exprs,
        variable: v,
        minX: b.xMin,
        maxX: b.xMax,
        minY: b.yMin,
        maxY: b.yMax,
        title: args.stringOrNull('title'),
        showMarkers: args.boolVal('markers', fallback: true),
        showGrid: args.boolVal('grid', fallback: true),
        scene2d: scene,
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
      final samples = args.intVal('samples').clamp(32, 4096);

      final xFn = xExpr.toFunction1D(tVar);
      final yFn = yExpr.toFunction1D(tVar);
      final ds = sampleParametric2D(
        id: 'p0',
        label: '($xExpr, $yExpr)',
        fn: (t) => (x: xFn(t), y: yFn(t)),
        tMin: minT,
        tMax: maxT,
        color: defaultGraphPalette[0],
        samples: samples,
      );
      final scene = Scene2D(datasets: [ds], equalAspect: true);
      final b =
          scene.computeBounds() ??
          const Bounds2D(xMin: -1, xMax: 1, yMin: -1, yMax: 1);

      return PlotValue(
        expressions: [xExpr, yExpr],
        variable: tVar,
        minX: b.xMin,
        maxX: b.xMax,
        minY: b.yMin,
        maxY: b.yMax,
        isParametric: true,
        minT: minT,
        maxT: maxT,
        title: args.stringOrNull('title'),
        showGrid: args.boolVal('grid', fallback: true),
        plotKind: PlotKind.parametric2d,
        scene2d: scene,
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
      final xFrom = args.doubleVal('xFrom');
      final xTo = args.doubleVal('xTo');
      final yFrom = args.doubleVal('yFrom');
      final yTo = args.doubleVal('yTo');
      final grid = args.intVal('grid').clamp(12, 128);

      final fn = expr.toVectorFunction([xVar, yVar]);
      final ds = sampleSurface3D(
        id: 's0',
        label: expr.toString(),
        fn: (x, y) => fn(Vector.fromList([x, y])),
        xMin: xFrom,
        xMax: xTo,
        yMin: yFrom,
        yMax: yTo,
        nx: grid,
        ny: grid,
      );
      final scene = Scene3D(
        datasets: [ds],
        xAxis: AxisConfig(label: xVar),
        yAxis: AxisConfig(label: yVar),
        zAxis: const AxisConfig(label: 'z'),
      );

      return PlotValue(
        expressions: [expr],
        variable: xVar,
        minX: xFrom,
        maxX: xTo,
        minY: yFrom,
        maxY: yTo,
        title: args.stringOrNull('title'),
        plotKind: PlotKind.surface3d,
        yVariable: yVar,
        gridSize: grid,
        scene3d: scene,
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
      final domain = Bounds2D(
        xMin: reFrom,
        xMax: reTo,
        yMin: imFrom,
        yMax: imTo,
      );

      final fn = expr.toComplexFunction1D(zVar);
      final ds = sampleComplexDomainGrid(
        id: 'c0',
        label: expr.toString(),
        fn: (x, y) {
          final w = fn(Complex(x, y));
          return (re: w.a.toDouble(), im: w.b.toDouble());
        },
        domain: domain,
      );
      final scene = Scene2D(
        datasets: [ds],
        xAxis: const AxisConfig(label: 'Re(z)'),
        yAxis: const AxisConfig(label: 'Im(z)'),
        equalAspect: true,
      );

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
        scene2d: scene,
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

      final fn = expr.toComplexFunction1D(zVar);
      final ds = sampleSurface3D(
        id: 'c3d',
        label: '|$expr|',
        fn: (x, y) {
          final w = fn(Complex(x, y));
          final mag = math.sqrt(w.a * w.a + w.b * w.b);
          return mag.isFinite ? math.min(mag, 25.0) : double.nan;
        },
        xMin: reFrom,
        xMax: reTo,
        yMin: imFrom,
        yMax: imTo,
        nx: grid,
        ny: grid,
        colormap: Colormap.plasma,
      );
      final scene = Scene3D(
        datasets: [ds],
        xAxis: const AxisConfig(label: 'Re(z)'),
        yAxis: const AxisConfig(label: 'Im(z)'),
        zAxis: const AxisConfig(label: '|f(z)|'),
      );

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
        scene3d: scene,
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
      final y0 = args.doubleVal('y0');
      final t0 = args.doubleVal('from');
      final t1 = args.doubleVal('to');
      final method = switch (args.stringVal('method')) {
        'dormandPrince45' => OdeMethod.dormandPrince45,
        'bdf2' => OdeMethod.bdf2,
        _ => OdeMethod.rk4,
      };

      final f = rhs.toVectorFunction([tVar, yVar]);
      final sol = solveOde(
        f: (double t, Vector<double> y) => Vector.fromList([
          f(Vector.fromList([t, y[0]])),
        ]),
        t0: t0,
        tEnd: t1,
        y0: Vector.fromList([y0]),
        method: method,
      );
      final ts = Float64List.fromList(sol.t);
      final ys = Float64List.fromList([for (final row in sol.y) row[0]]);
      final ds = Function2DDataset(
        id: 'ode0',
        label: '$yVar($tVar)',
        xs: ts,
        ys: ys,
        color: defaultGraphPalette[0],
      );
      final scene = Scene2D(
        datasets: [ds],
        xAxis: AxisConfig(label: tVar),
        yAxis: AxisConfig(label: yVar),
      );
      final b =
          scene.computeBounds() ??
          Bounds2D(xMin: t0, xMax: t1, yMin: y0 - 1, yMax: y0 + 1);

      return PlotValue(
        expressions: [rhs],
        variable: tVar,
        yVariable: yVar,
        minX: b.xMin,
        maxX: b.xMax,
        minY: b.yMin,
        maxY: b.yMax,
        odeY0: y0,
        isOde: true,
        title: args.stringOrNull('title'),
        plotKind: PlotKind.ode2d,
        scene2d: scene,
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

      final uFn = uExpr.toVectorFunction([xVar, yVar]);
      final vFn = vExpr.toVectorFunction([xVar, yVar]);
      final domain = Bounds2D(xMin: xFrom, xMax: xTo, yMin: yFrom, yMax: yTo);
      final ds = sampleVectorField2D(
        id: 'vf2d',
        label: '($uExpr, $vExpr)',
        fn: (x, y) =>
            (u: uFn(Vector.fromList([x, y])), v: vFn(Vector.fromList([x, y]))),
        domain: domain,
        cols: grid,
        rows: grid,
      );
      final scene = Scene2D(
        datasets: [ds],
        xAxis: AxisConfig(label: xVar),
        yAxis: AxisConfig(label: yVar),
        equalAspect: true,
      );

      return PlotValue(
        expressions: [uExpr, vExpr],
        variable: xVar,
        minX: xFrom,
        maxX: xTo,
        minY: yFrom,
        maxY: yTo,
        title: args.stringOrNull('title'),
        plotKind: PlotKind.vectorField2d,
        yVariable: yVar,
        gridSize: grid,
        scene2d: scene,
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

      final fn = expr.toVectorFunction([xVar, yVar]);
      final domain = Bounds2D(xMin: xFrom, xMax: xTo, yMin: yFrom, yMax: yTo);
      final ds = sampleScalarField2D(
        id: 'hm2d',
        label: expr.toString(),
        fn: (x, y) => fn(Vector.fromList([x, y])),
        domain: domain,
        cols: grid,
        rows: grid,
      );
      final scene = Scene2D(
        datasets: [ds],
        xAxis: AxisConfig(label: xVar),
        yAxis: AxisConfig(label: yVar),
      );

      return PlotValue(
        expressions: [expr],
        variable: xVar,
        minX: xFrom,
        maxX: xTo,
        minY: yFrom,
        maxY: yTo,
        title: args.stringOrNull('title'),
        plotKind: PlotKind.heatmap2d,
        yVariable: yVar,
        gridSize: grid,
        scene2d: scene,
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
      final zVar = args.symbolOrNull('z') ?? 'z';
      final from = args.doubleVal('from');
      final to = args.doubleVal('to');
      final grid = args.intVal('grid').clamp(3, 10);

      final vxFn = vxExpr.toVectorFunction([xVar, yVar, zVar]);
      final vyFn = vyExpr.toVectorFunction([xVar, yVar, zVar]);
      final vzFn = vzExpr.toVectorFunction([xVar, yVar, zVar]);
      final ds = sampleVectorField3D(
        id: 'vf3d',
        label: '($vxExpr, $vyExpr, $vzExpr)',
        fn: (x, y, z) => (
          vx: vxFn(Vector.fromList([x, y, z])),
          vy: vyFn(Vector.fromList([x, y, z])),
          vz: vzFn(Vector.fromList([x, y, z])),
        ),
        xMin: from,
        xMax: to,
        yMin: from,
        yMax: to,
        zMin: from,
        zMax: to,
        nx: grid,
        ny: grid,
        nz: grid,
      );
      final scene = Scene3D(
        datasets: [ds],
        xAxis: AxisConfig(label: xVar),
        yAxis: AxisConfig(label: yVar),
        zAxis: AxisConfig(label: zVar),
      );

      return PlotValue(
        expressions: [vxExpr, vyExpr, vzExpr],
        variable: xVar,
        minX: from,
        maxX: to,
        minY: from,
        maxY: to,
        title: args.stringOrNull('title'),
        plotKind: PlotKind.vectorField3d,
        yVariable: yVar,
        gridSize: grid,
        scene3d: scene,
      );
    },
  ),
];
