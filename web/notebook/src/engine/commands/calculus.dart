import 'package:data/symbolic.dart';

import '../../language/signature.dart';
import '../../model/value.dart';
import '../commands.dart';

final List<Command> calculusCommands = [
  Command(
    name: 'diff',
    aliases: ['derivative'],
    category: CommandCategory.calculus,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('expr'),
        ParamSpec.optional('var', type: ParamType.symbol),
      ],
      named: [
        ParamSpec.named('order', type: ParamType.integer, defaultValue: 1),
      ],
    ),
    doc: 'Computes the symbolic derivative of an expression.',
    examples: ['diff(x^3 * sin(x), x)', 'diff(exp(-x^2), x, order: 2)'],
    chipLabel: 'd/dx',
    appliesTo: (v) => v is ExprValue,
    buildChipCall: (input, v) {
      final vName = inferVariable((v as ExprValue).expr);
      return 'diff($input, $vName)';
    },
    run: (args, ctx) {
      final expr = args.expr('expr');
      final v = inferVariable(expr, args.symbolOrNull('var'));
      final order = args.intVal('order');
      if (order < 1) {
        throw const ArgumentBindingException('diff order must be >= 1');
      }
      var cur = expr;
      for (var i = 0; i < order; i++) {
        cur = cur.derivative(v, assumptions: ctx.assumptions);
      }
      return ExprValue(cur.simplify(assumptions: ctx.assumptions));
    },
  ),
  Command(
    name: 'D',
    aliases: ['deriv'],
    category: CommandCategory.calculus,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('expr'),
        ParamSpec.positional('var', type: ParamType.symbol),
      ],
      named: [
        ParamSpec.named('order', type: ParamType.integer, defaultValue: 1),
      ],
    ),
    doc: 'Constructs an unevaluated symbolic derivative for ODE specification.',
    examples: ['D(y, x)', 'dsolve(D(y, x) + 2*y = 0, y, x)'],
    preserveForm: true,
    run: (args, _) {
      final expr = args.expr('expr');
      final v = args.symbol('var');
      final order = args.intVal('order');
      if (order < 1) {
        throw const ArgumentBindingException('D order must be >= 1');
      }
      return ExprValue(Derivative(expr, v, order: order));
    },
  ),
  Command(
    name: 'integrate',
    aliases: ['integral'],
    category: CommandCategory.calculus,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('expr'),
        ParamSpec.optional('var', type: ParamType.symbol),
      ],
      named: [
        ParamSpec.named('from', type: ParamType.expr),
        ParamSpec.named('to', type: ParamType.expr),
      ],
    ),
    doc: 'Computes the indefinite or definite symbolic integral.',
    examples: [
      'integrate(x * exp(x), x)',
      'integrate(sin(x), x, from: 0, to: pi)',
    ],
    chipLabel: '∫ dx',
    appliesTo: (v) => v is ExprValue,
    buildChipCall: (input, v) {
      final vName = inferVariable((v as ExprValue).expr);
      return 'integrate($input, $vName)';
    },
    run: (args, ctx) {
      final expr = args.expr('expr');
      final v = inferVariable(expr, args.symbolOrNull('var'));
      final from = args.exprOrNull('from');
      final to = args.exprOrNull('to');
      if ((from == null) != (to == null)) {
        throw const ArgumentBindingException(
          'Definite integration requires both from: and to: bounds',
        );
      }
      final res = (from != null && to != null)
          ? expr.integrate(v, from: from, to: to, assumptions: ctx.assumptions)
          : expr.integrate(v, assumptions: ctx.assumptions);
      return ExprValue(res.simplify(assumptions: ctx.assumptions));
    },
  ),
  Command(
    name: 'mintegrate',
    category: CommandCategory.calculus,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('expr'),
        ParamSpec.positional('vars', type: ParamType.symbolList),
      ],
      named: [
        ParamSpec.named('from', type: ParamType.exprList),
        ParamSpec.named('to', type: ParamType.exprList),
      ],
    ),
    doc: 'Computes an iterated (multiple) indefinite or definite integral.',
    examples: [
      'mintegrate(x * y, [x, y])',
      'mintegrate(x * y, [y, x], from: [0, 0], to: [x, 1])',
    ],
    run: (args, ctx) {
      final expr = args.expr('expr');
      final vars = args.symbolList('vars');
      final fromList = args.has('from') ? args.exprList('from') : null;
      final toList = args.has('to') ? args.exprList('to') : null;
      if ((fromList == null) != (toList == null)) {
        throw const ArgumentBindingException(
          'mintegrate requires both from: and to: lists when specifying bounds',
        );
      }
      if (fromList != null &&
          (fromList.length != vars.length || toList!.length != vars.length)) {
        throw ArgumentBindingException(
          'mintegrate from: and to: lists must match variable count (${vars.length})',
        );
      }
      final bounds = <IntegrationBound>[
        for (var i = 0; i < vars.length; i++)
          (variable: vars[i], from: fromList?[i], to: toList?[i]),
      ];
      return ExprValue(
        expr
            .integrateMultiple(bounds, assumptions: ctx.assumptions)
            .simplify(assumptions: ctx.assumptions),
      );
    },
  ),
  Command(
    name: 'taylor',
    category: CommandCategory.calculus,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('expr'),
        ParamSpec.optional('var', type: ParamType.symbol),
      ],
      named: [
        ParamSpec.named('at', type: ParamType.expr),
        ParamSpec.named('order', type: ParamType.integer, defaultValue: 5),
      ],
    ),
    doc: 'Computes the truncated Taylor polynomial (without O-term).',
    examples: [
      'taylor(sin(x), x, order: 7)',
      'taylor(ln(x), x, at: 1, order: 4)',
    ],
    run: (args, ctx) {
      final expr = args.expr('expr');
      final v = inferVariable(expr, args.symbolOrNull('var'));
      final at = args.exprOrNull('at') ?? IntegerNumber.zero;
      final order = args.intVal('order');
      return ExprValue(
        expr.series(
          v,
          point: at,
          order: order,
          includeOrder: false,
          assumptions: ctx.assumptions,
        ),
      );
    },
  ),
  Command(
    name: 'series',
    category: CommandCategory.calculus,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('expr'),
        ParamSpec.optional('var', type: ParamType.symbol),
      ],
      named: [
        ParamSpec.named('at', type: ParamType.expr),
        ParamSpec.named('order', type: ParamType.integer, defaultValue: 5),
      ],
    ),
    doc: 'Computes a formal PowerSeries expansion with asymptotic O-term.',
    examples: ['series(exp(x), x, order: 5)'],
    run: (args, ctx) {
      final expr = args.expr('expr');
      final v = inferVariable(expr, args.symbolOrNull('var'));
      final at = args.exprOrNull('at') ?? IntegerNumber.zero;
      final order = args.intVal('order');
      return SeriesValue(
        expr.toPowerSeries(
          v,
          point: at,
          order: order,
          assumptions: ctx.assumptions,
        ),
      );
    },
  ),
  Command(
    name: 'limit',
    category: CommandCategory.calculus,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('expr'),
        ParamSpec.positional('var', type: ParamType.symbol),
        ParamSpec.positional('to', type: ParamType.expr),
      ],
      named: [
        ParamSpec.named(
          'direction',
          type: ParamType.string,
          defaultValue: 'both',
          enumValues: ['both', 'left', 'right'],
        ),
      ],
    ),
    doc: 'Computes the symbolic limit of an expression.',
    examples: ['limit(sin(x)/x, x, 0)', "limit(1/x, x, 0, direction: 'right')"],
    run: (args, ctx) {
      final expr = args.expr('expr');
      final v = args.symbol('var');
      final to = args.expr('to');
      final dir = switch (args.stringVal('direction')) {
        'left' => LimitDirection.fromBelow,
        'right' => LimitDirection.fromAbove,
        _ => LimitDirection.both,
      };
      return ExprValue(
        expr.limit(v, to, direction: dir, assumptions: ctx.assumptions),
      );
    },
  ),
  Command(
    name: 'sum',
    category: CommandCategory.calculus,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('expr'),
        ParamSpec.positional('var', type: ParamType.symbol),
      ],
      named: [
        ParamSpec.named('from', type: ParamType.expr, required: true),
        ParamSpec.named('to', type: ParamType.expr, required: true),
      ],
    ),
    doc: 'Evaluates a symbolic summation from `from:` to `to:`.',
    examples: ['sum(k^2, k, from: 1, to: n)'],
    run: (args, ctx) {
      final expr = args.expr('expr');
      final v = args.symbol('var');
      final from = args.expr('from');
      final to = args.expr('to');
      return ExprValue(
        expr.sum(v, from, to).simplify(assumptions: ctx.assumptions),
      );
    },
  ),
  Command(
    name: 'product',
    category: CommandCategory.calculus,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('expr'),
        ParamSpec.positional('var', type: ParamType.symbol),
      ],
      named: [
        ParamSpec.named('from', type: ParamType.expr, required: true),
        ParamSpec.named('to', type: ParamType.expr, required: true),
      ],
    ),
    doc: 'Represents or evaluates a symbolic product from `from:` to `to:`.',
    examples: ['product(k, k, from: 1, to: n)'],
    run: (args, ctx) {
      final expr = args.expr('expr');
      final v = args.symbol('var');
      final from = args.expr('from');
      final to = args.expr('to');
      return ExprValue(expr.product(v, from, to, assumptions: ctx.assumptions));
    },
  ),
  Command(
    name: 'antidiff',
    category: CommandCategory.calculus,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('expr'),
        ParamSpec.optional('var', type: ParamType.symbol),
      ],
    ),
    doc: 'Computes the indefinite antidifference Δ⁻¹ f(x) for discrete summation.',
    examples: ['antidiff(x * x!, x)', 'antidiff(1 / (x * (x + 1)), x)'],
    run: (args, ctx) {
      final expr = args.expr('expr');
      final v = inferVariable(expr, args.symbolOrNull('var'));
      final res = expr.indefiniteSum(v, assumptions: ctx.assumptions);
      if (res == null) {
        return const InfoValue('No closed-form antidifference found.');
      }
      return ExprValue(res.simplify(assumptions: ctx.assumptions));
    },
  ),
  Command(
    name: 'dsolve',
    category: CommandCategory.calculus,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('eq', type: ParamType.equation),
        ParamSpec.positional('y', type: ParamType.symbol),
        ParamSpec.positional('x', type: ParamType.symbol),
      ],
      named: [
        ParamSpec.named('at', type: ParamType.expr),
        ParamSpec.named('init', type: ParamType.exprList),
        ParamSpec.named('constant', type: ParamType.string, defaultValue: 'C1'),
      ],
    ),
    doc:
        'Solves first-order and constant-coefficient linear ODEs symbolically.',
    examples: [
      'dsolve(D(y, x) - 2*y = 0, y, x)',
      'dsolve(D(y, x, order: 2) + y = 0, y, x, at: 0, init: [1, 0])',
    ],
    run: (args, ctx) {
      final eq = args.expr('eq');
      final dep = args.symbol('y');
      final ind = args.symbol('x');
      final at = args.exprOrNull('at');
      final init = args.has('init') ? args.exprList('init') : const <Expr>[];
      final cName = args.stringVal('constant');
      return ExprValue(
        eq.solveOde(
          dependent: dep,
          independent: ind,
          constant: cName,
          at: at,
          initialValues: init,
          assumptions: ctx.assumptions,
        ),
      );
    },
  ),
  Command(
    name: 'gradient',
    aliases: ['grad'],
    category: CommandCategory.calculus,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('expr'),
        ParamSpec.positional('vars', type: ParamType.symbolList),
      ],
    ),
    doc: 'Computes the gradient vector of a scalar field.',
    examples: ['gradient(x^2 + y^2 + z^2, [x, y, z])'],
    run: (args, ctx) {
      final expr = args.expr('expr');
      final vars = args.symbolList('vars');
      return VectorValue(expr.gradient(vars, assumptions: ctx.assumptions));
    },
  ),
  Command(
    name: 'hessian',
    category: CommandCategory.calculus,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('expr'),
        ParamSpec.positional('vars', type: ParamType.symbolList),
      ],
    ),
    doc: 'Computes the Hessian matrix of second partial derivatives.',
    examples: ['hessian(x^2*y + sin(y), [x, y])'],
    run: (args, ctx) {
      final expr = args.expr('expr');
      final vars = args.symbolList('vars');
      return MatrixValue(expr.hessian(vars, assumptions: ctx.assumptions));
    },
  ),
  Command(
    name: 'jacobian',
    category: CommandCategory.calculus,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('exprs', type: ParamType.exprList),
        ParamSpec.positional('vars', type: ParamType.symbolList),
      ],
    ),
    doc: 'Computes the Jacobian matrix of a vector-valued function.',
    examples: ['jacobian([r*cos(theta), r*sin(theta)], [r, theta])'],
    run: (args, ctx) {
      final exprs = args.exprList('exprs');
      final vars = args.symbolList('vars');
      return MatrixValue(exprs.jacobian(vars, assumptions: ctx.assumptions));
    },
  ),
  Command(
    name: 'laplacian',
    category: CommandCategory.calculus,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('expr'),
        ParamSpec.positional('vars', type: ParamType.symbolList),
      ],
    ),
    doc: 'Computes the Laplacian (sum of unmixed second partial derivatives).',
    examples: ['laplacian(x^2 + y^2, [x, y])'],
    run: (args, ctx) {
      final expr = args.expr('expr');
      final vars = args.symbolList('vars');
      return ExprValue(expr.laplacian(vars, assumptions: ctx.assumptions));
    },
  ),
  Command(
    name: 'divergence',
    aliases: ['div'],
    category: CommandCategory.calculus,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('field', type: ParamType.exprList),
        ParamSpec.positional('vars', type: ParamType.symbolList),
      ],
    ),
    doc: 'Computes the divergence of a vector field.',
    examples: ['divergence([x^2, y^2, z^2], [x, y, z])'],
    run: (args, ctx) {
      final field = args.exprList('field');
      final vars = args.symbolList('vars');
      return ExprValue(field.divergence(vars, assumptions: ctx.assumptions));
    },
  ),
  Command(
    name: 'curl',
    category: CommandCategory.calculus,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('field', type: ParamType.exprList),
        ParamSpec.positional('vars', type: ParamType.symbolList),
      ],
    ),
    doc: 'Computes the 3D curl of a 3-component vector field.',
    examples: ['curl([-y, x, 0], [x, y, z])'],
    run: (args, ctx) {
      final field = args.exprList('field');
      final vars = args.symbolList('vars');
      if (field.length != 3 || vars.length != 3) {
        throw const ArgumentBindingException(
          'curl requires a 3-component vector field and 3 variables',
        );
      }
      return VectorValue(field.curl(vars, assumptions: ctx.assumptions));
    },
  ),
  Command(
    name: 'analyze',
    category: CommandCategory.calculus,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('expr'),
        ParamSpec.optional('var', type: ParamType.symbol),
      ],
    ),
    doc: 'Analyzes a univariate expression (roots, derivative, integral).',
    examples: ['analyze(x^3 - 3*x, x)'],
    run: (args, ctx) {
      final expr = args.expr('expr');
      final v = inferVariable(expr, args.symbolOrNull('var'));
      final df = expr.derivative(v).simplify(assumptions: ctx.assumptions);
      final d2f = df.derivative(v).simplify(assumptions: ctx.assumptions);
      final roots = expr.solve(v, assumptions: ctx.assumptions);
      final buf = StringBuffer()
        ..writeln('f($v) = $expr')
        ..writeln('df/d$v = $df')
        ..writeln('d^2f/d$v^2 = $d2f')
        ..write('roots: ${roots.isEmpty ? 'none found' : roots.join(', ')}');
      return InfoValue(buf.toString(), title: 'Function Analysis');
    },
  ),
];
