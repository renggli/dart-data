import 'package:data/symbolic.dart';

import '../../model/value.dart';
import '../commands.dart';

/// Builds canonical calculus commands (`diff`, `integrate`, `taylor`, `series`,
/// `limit`, `sum`, `product`, `gradient`, `hessian`, `jacobian`).
List<Command> buildCalculusCommands() => [
  Command(
    name: 'diff',
    category: CommandCategory.calculus,
    signature: 'diff(expr, [var], [order])',
    paramSpecs: const [
      ParamSpec.expr('expr'),
      ParamSpec.symbol('[var]'),
      ParamSpec.optionalInt('[order]'),
    ],
    minArity: 1,
    maxArity: 3,
    doc: 'Computes the symbolic derivative with respect to var.',
    examples: const ['diff(x^3 * sin(x), x)', 'diff(exp(-x^2), x, 2)'],
    rpnLabel: 'd/dx',
    rpnArity: 2,
    appliesTo: (v) =>
        (v is ExprValue && !v.isEquation && v.expr.freeVariables.isNotEmpty) ||
        v is VectorValue ||
        v is MatrixValue,
    chipLabel: 'd/dx',
    buildChipCall: (id, v) => 'diff(r[$id], ${primaryCommandVar(v) ?? 'x'})',
    run: (args, ctx) {
      checkCommandArity('diff', args, 1, 3);
      final varName = args.length >= 2
          ? expectCommandVarName(args[1], 'diff')
          : ctx.inferPrimaryVariable(args[0]);
      final order = args.length >= 3 ? expectCommandInt(args[2], 'diff') : 1;
      return liftUnaryCommand(
        args[0],
        (e) => e
            .derivative(varName, order: order)
            .simplify(assumptions: ctx.assumptions),
        onMatrix: (m) => m.derivative(varName, order: order),
        onVector: (v) => v.derivative(varName, order: order),
      );
    },
  ),
  Command(
    name: 'integrate',
    category: CommandCategory.calculus,
    signature: 'integrate(expr, [var], [a, b])',
    paramSpecs: const [
      ParamSpec.expr('expr'),
      ParamSpec.symbol('[var]'),
      ParamSpec.optionalExpr('[a]'),
      ParamSpec.optionalExpr('[b]'),
    ],
    minArity: 1,
    maxArity: 4,
    doc: 'Computes symbolic indefinite or definite integrals.',
    examples: const [
      'integrate(x * cos(x), x)',
      'integrate(sin(x), x, 0, pi)',
      'integrate(exp(-x), x, 0, infinity)',
    ],
    rpnLabel: '∫',
    rpnArity: 2,
    appliesTo: (v) =>
        v is ExprValue &&
        !v.isEquation &&
        v.expr is! Integral &&
        v.expr.freeVariables.isNotEmpty,
    chipLabel: '∫ dx',
    buildChipCall: (id, v) =>
        'integrate(r[$id], ${primaryCommandVar(v) ?? 'x'})',
    run: (args, ctx) {
      checkCommandArity('integrate', args, 1, 4);
      final String varName;
      final Expr? lower;
      final Expr? upper;
      if (args.length == 3) {
        // 3-arg form: integrate(expr, lower, upper) with inferred variable
        varName = ctx.inferPrimaryVariable(args[0]);
        lower = expectCommandExpr(args[1], 'integrate');
        upper = expectCommandExpr(args[2], 'integrate');
      } else {
        varName = args.length >= 2
            ? expectCommandVarName(args[1], 'integrate')
            : ctx.inferPrimaryVariable(args[0]);
        lower = args.length == 4
            ? expectCommandExpr(args[2], 'integrate')
            : null;
        upper = args.length == 4
            ? expectCommandExpr(args[3], 'integrate')
            : null;
      }
      return liftUnaryCommand(
        args[0],
        (e) => e.integrate(varName, from: lower, to: upper),
        onMatrix: (m) => m.integrate(varName, from: lower, to: upper),
        onVector: (v) => v.integrate(varName, from: lower, to: upper),
      );
    },
  ),
  Command(
    name: 'taylor',
    category: CommandCategory.calculus,
    signature: 'taylor(expr, [var], [point], [order])',
    paramSpecs: const [
      ParamSpec.expr('expr'),
      ParamSpec.symbol('[var]'),
      ParamSpec.optionalExpr('[point]'),
      ParamSpec.optionalInt('[order]'),
    ],
    minArity: 1,
    maxArity: 4,
    doc: 'Computes the Taylor polynomial expansion of degree n around point.',
    examples: const [
      'taylor(sin(x) / x, x, 0, 6)',
      'taylor(cos(x), x, pi / 4, 4)',
    ],
    rpnLabel: 'Taylor',
    rpnArity: 4,
    appliesTo: (v) =>
        v is ExprValue &&
        !v.isEquation &&
        v.expr.freeVariables.length == 1 &&
        !v.expr.anyNode((n) => n is OrderTerm),
    chipLabel: 'Taylor',
    buildChipCall: (id, v) =>
        'taylor(r[$id], ${primaryCommandVar(v) ?? 'x'}, 0, 5)',
    run: (args, ctx) {
      checkCommandArity('taylor', args, 1, 4);
      final expr = expectCommandExpr(args[0], 'taylor');
      if (args.length == 2 &&
          args[1] is ExprValue &&
          (args[1] as ExprValue).expr is IntegerNumber) {
        final varName = ctx.inferPrimaryVariable(args[0]);
        final degree = expectCommandInt(args[1], 'taylor');
        return ExprValue(
          expr.series(
            varName,
            point: IntegerNumber.zero,
            order: degree + 1,
            includeOrder: false,
          ),
        );
      }
      final varName = args.length >= 2
          ? expectCommandVarName(args[1], 'taylor')
          : ctx.inferPrimaryVariable(args[0]);
      final point = args.length >= 3
          ? expectCommandExpr(args[2], 'taylor')
          : IntegerNumber.zero;
      final degree = args.length == 4 ? expectCommandInt(args[3], 'taylor') : 5;
      return ExprValue(
        expr.series(
          varName,
          point: point,
          order: degree + 1,
          includeOrder: false,
        ),
      );
    },
  ),
  Command(
    name: 'series',
    category: CommandCategory.calculus,
    signature: 'series(expr, [var], [point], [order])',
    paramSpecs: const [
      ParamSpec.expr('expr'),
      ParamSpec.symbol('[var]'),
      ParamSpec.optionalExpr('[point]'),
      ParamSpec.optionalInt('[order]'),
    ],
    minArity: 1,
    maxArity: 4,
    doc: 'Computes a truncated power/Laurent series with O((x - a)^n).',
    examples: const ['series(exp(x), x, 0, 5)', 'series(cot(x), x, 0, 4)'],
    rpnLabel: 'Series',
    rpnArity: 4,
    appliesTo: (_) => false,
    chipLabel: 'Series',
    buildChipCall: (id, v) =>
        'series(r[$id], ${primaryCommandVar(v) ?? 'x'}, 0, 5)',
    run: (args, ctx) {
      checkCommandArity('series', args, 1, 4);
      final expr = expectCommandExpr(args[0], 'series');
      if (args.length == 2 &&
          args[1] is ExprValue &&
          (args[1] as ExprValue).expr is IntegerNumber) {
        final varName = ctx.inferPrimaryVariable(args[0]);
        final order = expectCommandInt(args[1], 'series');
        return SeriesValue(
          expr.toPowerSeries(varName, point: IntegerNumber.zero, order: order),
        );
      }
      final varName = args.length >= 2
          ? expectCommandVarName(args[1], 'series')
          : ctx.inferPrimaryVariable(args[0]);
      final point = args.length >= 3
          ? expectCommandExpr(args[2], 'series')
          : IntegerNumber.zero;
      final order = args.length >= 4 ? expectCommandInt(args[3], 'series') : 5;
      return SeriesValue(
        expr.toPowerSeries(varName, point: point, order: order),
      );
    },
  ),
  Command(
    name: 'limit',
    category: CommandCategory.calculus,
    signature: 'limit(expr, [var], [point], [dir])',
    paramSpecs: const [
      ParamSpec.expr('expr'),
      ParamSpec.symbol('[var]'),
      ParamSpec.optionalExpr('[point]'),
      ParamSpec.symbol('[dir]'),
    ],
    minArity: 1,
    maxArity: 4,
    doc: 'Evaluates the symbolic limit as var approaches point (default 0).',
    examples: const [
      'limit(sin(x) / x, x, 0)',
      'limit((1 + 1 / x)^x, x, infinity)',
      'limit(1 / x, x, 0, fromAbove)',
    ],
    rpnLabel: 'Limit',
    rpnArity: 3,
    appliesTo: (_) => false,
    chipLabel: 'Limit',
    buildChipCall: (id, v) =>
        'limit(r[$id], ${primaryCommandVar(v) ?? 'x'}, 0)',
    run: (args, ctx) {
      checkCommandArity('limit', args, 1, 4);
      final expr = expectCommandExpr(args[0], 'limit');
      if (args.length == 1) {
        final varName = ctx.inferPrimaryVariable(args[0]);
        return ExprValue(expr.limit(varName, IntegerNumber.zero));
      }
      if (args.length == 2) {
        if (args[1] is ExprValue && (args[1] as ExprValue).expr is Variable) {
          final varName = expectCommandVarName(args[1], 'limit');
          return ExprValue(expr.limit(varName, IntegerNumber.zero));
        }
        final varName = ctx.inferPrimaryVariable(args[0]);
        final point = expectCommandExpr(args[1], 'limit');
        return ExprValue(expr.limit(varName, point));
      }
      final varName = expectCommandVarName(args[1], 'limit');
      final point = expectCommandExpr(args[2], 'limit');
      final dir = args.length == 4
          ? _parseLimitDir(args[3])
          : LimitDirection.both;
      return ExprValue(expr.limit(varName, point, direction: dir));
    },
  ),
  Command(
    name: 'sum',
    category: CommandCategory.calculus,
    signature: 'sum(expr, var, lower, upper)',
    paramSpecs: const [
      ParamSpec.expr('expr'),
      ParamSpec.symbol('var'),
      ParamSpec.expr('lower'),
      ParamSpec.expr('upper'),
    ],
    minArity: 4,
    maxArity: 4,
    doc: 'Evaluates closed-form symbolic summation (Faulhaber, geometric, Gosper, telescoping).',
    examples: const ['sum(k^2, k, 1, n)', 'sum(1 / (k * (k + 1)), k, 1, n)'],
    rpnLabel: '∑',
    rpnArity: 4,
    appliesTo: (_) => false,
    chipLabel: 'Sum',
    buildChipCall: (id, v) =>
        'sum(r[$id], ${primaryCommandVar(v) ?? 'k'}, 1, n)',
    run: (args, ctx) {
      checkCommandArity('sum', args, 4, 4);
      final expr = expectCommandExpr(args[0], 'sum');
      final varName = expectCommandVarName(args[1], 'sum');
      final lower = expectCommandExpr(args[2], 'sum');
      final upper = expectCommandExpr(args[3], 'sum');
      return ExprValue(expr.sum(varName, lower, upper));
    },
  ),
  Command(
    name: 'product',
    category: CommandCategory.calculus,
    signature: 'product(expr, var, lower, upper)',
    paramSpecs: const [
      ParamSpec.expr('expr'),
      ParamSpec.symbol('var'),
      ParamSpec.expr('lower'),
      ParamSpec.expr('upper'),
    ],
    minArity: 4,
    maxArity: 4,
    doc: 'Evaluates closed-form symbolic products.',
    examples: const ['product(k, k, 1, n)', 'product((k + 1) / k, k, 1, n)'],
    rpnLabel: '∏',
    rpnArity: 4,
    appliesTo: (_) => false,
    chipLabel: 'Product',
    buildChipCall: (id, v) =>
        'product(r[$id], ${primaryCommandVar(v) ?? 'k'}, 1, n)',
    run: (args, ctx) {
      checkCommandArity('product', args, 4, 4);
      final expr = expectCommandExpr(args[0], 'product');
      final varName = expectCommandVarName(args[1], 'product');
      final lower = expectCommandExpr(args[2], 'product');
      final upper = expectCommandExpr(args[3], 'product');
      return ExprValue(expr.product(varName, lower, upper));
    },
  ),
  Command(
    name: 'gradient',
    category: CommandCategory.calculus,
    signature: 'gradient(expr, [vars])',
    paramSpecs: const [
      ParamSpec.expr('expr'),
      ParamSpec.optionalExpr('[vars]'),
    ],
    minArity: 1,
    maxArity: 2,
    doc: 'Computes the symbolic gradient vector ∇f.',
    examples: const ['gradient(x^2 * y + sin(y), [x, y])'],
    rpnLabel: 'Gradient',
    rpnArity: 2,
    appliesTo: (v) => v is ExprValue && v.expr.freeVariables.length >= 2,
    chipLabel: '∇f',
    buildChipCall: (id, v) {
      final vars = (v as ExprValue).expr.freeVariables.join(', ');
      return 'gradient(r[$id], [$vars])';
    },
    run: (args, ctx) {
      checkCommandArity('gradient', args, 1, 2);
      final expr = expectCommandExpr(args[0], 'gradient');
      final vars = args.length == 2
          ? extractCommandVarNameList(args[1], 'gradient')
          : (expr.freeVariables.isNotEmpty
                ? expr.freeVariables.toList()
                : ['x']);
      return VectorValue(expr.gradient(vars));
    },
  ),
  Command(
    name: 'hessian',
    category: CommandCategory.calculus,
    signature: 'hessian(expr, [vars])',
    paramSpecs: const [
      ParamSpec.expr('expr'),
      ParamSpec.optionalExpr('[vars]'),
    ],
    minArity: 1,
    maxArity: 2,
    doc: 'Computes the symbolic Hessian matrix of second partial derivatives.',
    examples: const ['hessian(x^3 + x * y^2, [x, y])'],
    rpnLabel: 'Hessian',
    rpnArity: 2,
    appliesTo: (v) => v is ExprValue && v.expr.freeVariables.length >= 2,
    chipLabel: 'Hessian',
    buildChipCall: (id, v) {
      final vars = (v as ExprValue).expr.freeVariables.join(', ');
      return 'hessian(r[$id], [$vars])';
    },
    run: (args, ctx) {
      checkCommandArity('hessian', args, 1, 2);
      final expr = expectCommandExpr(args[0], 'hessian');
      final vars = args.length == 2
          ? extractCommandVarNameList(args[1], 'hessian')
          : (expr.freeVariables.isNotEmpty
                ? expr.freeVariables.toList()
                : ['x']);
      return MatrixValue(expr.hessian(vars));
    },
  ),
  Command(
    name: 'jacobian',
    category: CommandCategory.calculus,
    signature: 'jacobian([exprs], [vars])',
    paramSpecs: const [
      ParamSpec.expr('[exprs]'),
      ParamSpec.optionalExpr('[vars]'),
    ],
    minArity: 1,
    maxArity: 2,
    doc: 'Computes the symbolic Jacobian matrix of a vector-valued function.',
    examples: const ['jacobian([r * cos(t), r * sin(t)], [r, t])'],
    rpnLabel: 'Jacobian',
    rpnArity: 2,
    appliesTo: (v) => v is VectorValue && v.isExact,
    chipLabel: 'Jacobian',
    buildChipCall: (id, _) => 'jacobian(r[$id])',
    run: (args, ctx) {
      checkCommandArity('jacobian', args, 1, 2);
      final exprs = extractCommandExprList(args[0], 'jacobian');
      final vars = args.length == 2
          ? extractCommandVarNameList(args[1], 'jacobian')
          : inferSystemVariables(exprs);
      return MatrixValue(exprs.jacobian(vars));
    },
  ),
  Command(
    name: 'analyze',
    category: CommandCategory.calculus,
    signature: 'analyze(expr, [var])',
    paramSpecs: const [ParamSpec.expr('expr'), ParamSpec.symbol('[var]')],
    minArity: 1,
    maxArity: 2,
    doc: 'Analyzes parity, y-intercept, exact roots, critical points, and inflection points.',
    examples: const ['analyze(x^3 - 3 * x, x)', 'analyze(x^4 - 2 * x^2 + 1)'],
    rpnLabel: 'Analyze',
    rpnArity: 1,
    appliesTo: (v) =>
        v is ExprValue && !v.isEquation && v.expr.freeVariables.length == 1,
    chipLabel: 'Analyze',
    buildChipCall: (id, v) => 'analyze(r[$id], ${primaryCommandVar(v) ?? 'x'})',
    run: (args, ctx) {
      checkCommandArity('analyze', args, 1, 2);
      final expr = expectCommandExpr(
        args[0],
        'analyze',
      ).simplify(assumptions: ctx.assumptions);
      final varName = args.length == 2
          ? expectCommandVarName(args[1], 'analyze')
          : ctx.inferPrimaryVariable(args[0]);

      // 1. Parity: f(-x) vs f(x) and -f(x)
      final negExpr = expr
          .substitute(varName, -Variable(varName))
          .simplify(assumptions: ctx.assumptions);
      final String parityStr;
      if ((negExpr - expr).simplify(assumptions: ctx.assumptions) ==
          IntegerNumber.zero) {
        parityStr = 'even';
      } else if ((negExpr + expr).simplify(assumptions: ctx.assumptions) ==
          IntegerNumber.zero) {
        parityStr = 'odd';
      } else {
        parityStr = 'neither';
      }

      // 2. Y-intercept f(0)
      Expr yIntercept;
      try {
        yIntercept = expr
            .substitute(varName, IntegerNumber.zero)
            .simplify(assumptions: ctx.assumptions);
      } catch (_) {
        yIntercept = Constant.undefined;
      }

      // 3. Roots f(x) = 0
      List<Expr> roots;
      try {
        roots = Equal(
          expr,
          IntegerNumber.zero,
        ).solve(varName, assumptions: ctx.assumptions);
      } catch (_) {
        roots = const [];
      }

      // 4. First derivative & critical points f'(x) = 0
      final df = expr
          .derivative(varName)
          .simplify(assumptions: ctx.assumptions);
      List<Expr> critical;
      try {
        critical = Equal(
          df,
          IntegerNumber.zero,
        ).solve(varName, assumptions: ctx.assumptions);
      } catch (_) {
        critical = const [];
      }

      // 5. Second derivative & inflection points f''(x) = 0
      final ddf = df.derivative(varName).simplify(assumptions: ctx.assumptions);
      List<Expr> inflection;
      try {
        inflection = Equal(
          ddf,
          IntegerNumber.zero,
        ).solve(varName, assumptions: ctx.assumptions);
      } catch (_) {
        inflection = const [];
      }

      return ListValue([
        ExprValue(Equal(const Variable('parity'), Variable(parityStr))),
        ExprValue(Equal(const Variable('f0'), yIntercept)),
        ListValue([
          for (final r in roots) ExprValue(Equal(const Variable('root'), r)),
        ]),
        ListValue([
          for (final c in critical) ExprValue(Equal(const Variable('crit'), c)),
        ]),
        ListValue([
          for (final inf in inflection)
            ExprValue(Equal(const Variable('infl'), inf)),
        ]),
      ]);
    },
  ),
];

LimitDirection _parseLimitDir(CalcValue v) {
  if (v case ExprValue(:final expr)) {
    return switch (expr) {
      IntegerNumber(isOne: true) ||
      Variable(
        name: 'fromAbove' || 'right' || 'plus',
      ) => LimitDirection.fromAbove,
      IntegerNumber(isNegativeOne: true) ||
      Variable(
        name: 'fromBelow' || 'left' || 'minus',
      ) => LimitDirection.fromBelow,
      _ => LimitDirection.both,
    };
  }
  return LimitDirection.both;
}
