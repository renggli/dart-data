import 'package:data/symbolic.dart';

import '../../model/value.dart';
import '../commands.dart';

/// Builds canonical algebra commands (`simplify`, `expand`, `factor`, `solve`,
/// `subs`, `apart`, `together`, `cancel`, `collect`, `numer`, `denom`,
/// `trigexpand`, `trigsimplify`).
List<Command> buildAlgebraCommands() => [
  Command(
    name: 'simplify',
    category: CommandCategory.algebra,
    signature: 'simplify(expr)',
    paramSpecs: const [ParamSpec.expr('expr')],
    minArity: 1,
    maxArity: 1,
    doc: 'Simplifies an expression, vector, or matrix to canonical form.',
    examples: const [
      'simplify((x^2 - 1) / (x - 1))',
      'simplify(sin(x)^2 + cos(x)^2)',
    ],
    rpnLabel: 'Simplify',
    rpnArity: 1,
    appliesTo: (v) => v is ExprValue || v is VectorValue || v is MatrixValue,
    chipLabel: 'Simplify',
    buildChipCall: (id, _) => 'simplify(r[$id])',
    run: (args, ctx) {
      checkCommandArity('simplify', args, 1, 1);
      return liftUnaryCommand(
        args[0],
        (e) => e.simplify(assumptions: ctx.assumptions),
        onMatrix: (m) => m.simplify(),
        onVector: (v) => v.simplify(),
      );
    },
  ),
  Command(
    name: 'expand',
    category: CommandCategory.algebra,
    signature: 'expand(expr)',
    paramSpecs: const [ParamSpec.expr('expr')],
    minArity: 1,
    maxArity: 1,
    doc: 'Expands products and positive integer powers.',
    examples: const ['expand((x + 1)^3)', 'expand((x - 1) * (x + 2))'],
    rpnLabel: 'Expand',
    rpnArity: 1,
    appliesTo: (v) =>
        v is ExprValue &&
        !v.isEquation &&
        v.expr.anyNode((n) => n is Mul || n is Pow),
    chipLabel: 'Expand',
    buildChipCall: (id, _) => 'expand(r[$id])',
    run: (args, ctx) {
      checkCommandArity('expand', args, 1, 1);
      return liftUnaryCommand(
        args[0],
        (e) => e.expand(),
        onMatrix: (m) => m.expand(),
        onVector: (v) => v.expand(),
      );
    },
  ),
  Command(
    name: 'factor',
    category: CommandCategory.algebra,
    signature: 'factor(expr)',
    paramSpecs: const [ParamSpec.expr('expr')],
    minArity: 1,
    maxArity: 1,
    doc: 'Factors polynomials over Q[x] and integers into prime powers.',
    examples: const ['factor(x^4 - 1)', 'factor(360)'],
    rpnLabel: 'Factor',
    rpnArity: 1,
    appliesTo: (v) =>
        v is ExprValue &&
        !v.isEquation &&
        (v.expr is Add || v.expr is IntegerNumber),
    chipLabel: 'Factor',
    buildChipCall: (id, _) => 'factor(r[$id])',
    run: (args, ctx) {
      checkCommandArity('factor', args, 1, 1);
      return liftUnaryCommand(
        args[0],
        (e) => e.factor(),
        onMatrix: (m) => m.factor(),
        onVector: (v) => v.factor(),
      );
    },
  ),
  Command(
    name: 'solve',
    category: CommandCategory.algebra,
    signature: 'solve(eq, [var])',
    paramSpecs: const [ParamSpec.expr('eq'), ParamSpec.symbol('[var]')],
    minArity: 1,
    maxArity: 2,
    doc: 'Solves an algebraic/transcendental equation or system of equations.',
    examples: const [
      'solve(x^2 - 5*x + 6 = 0, x)',
      'solve([x + y = 3, x - y = 1], [x, y])',
    ],
    rpnLabel: 'Solve',
    rpnArity: 2,
    appliesTo: (v) => v is ExprValue && v.expr.freeVariables.isNotEmpty,
    chipLabel: 'Roots',
    buildChipCall: (id, v) {
      final vName = primaryCommandVar(v) ?? 'x';
      return 'solve(r[$id], $vName)';
    },
    run: (args, ctx) {
      checkCommandArity('solve', args, 1, 2);
      if (args[0] is VectorValue || args[0] is ListValue) {
        final eqs = extractCommandExprList(args[0], 'solve');
        final vars = args.length >= 2
            ? extractCommandVarNameList(args[1], 'solve')
            : inferSystemVariables(eqs);
        final solutions = eqs.solve(vars);
        return ListValue([
          for (final sol in solutions)
            ListValue([
              for (final v in vars)
                ExprValue(Equal(Variable(v), sol[v] ?? IntegerNumber.zero)),
            ]),
        ]);
      }
      final target = expectCommandExpr(args[0], 'solve');
      final varName = args.length >= 2
          ? expectCommandVarName(args[1], 'solve')
          : (target.freeVariables.isNotEmpty
                ? target.freeVariables.first
                : 'x');
      final roots = target.solve(varName, assumptions: ctx.assumptions);
      return ListValue([for (final r in roots) ExprValue(r)]);
    },
  ),
  Command(
    name: 'subs',
    category: CommandCategory.algebra,
    signature: 'subs(expr, var = val, ...)',
    paramSpecs: const [ParamSpec.expr('expr'), ParamSpec.equation('var = val')],
    minArity: 2,
    maxArity: 16,
    doc: 'Substitutes variables in an expression, vector, or matrix.',
    examples: const ['subs(x^2 + y, x = 3)', 'subs(sin(x), x = pi / 4)'],
    rpnLabel: 'Subs',
    rpnArity: 2,
    appliesTo: (_) => false,
    chipLabel: 'Subs',
    buildChipCall: (id, v) =>
        'subs(r[$id], ${primaryCommandVar(v) ?? 'x'} = 0)',
    run: (args, ctx) {
      checkCommandArity('subs', args, 2, 16);
      var current = args[0];
      if (args.length == 3 &&
          args[1] is ExprValue &&
          (args[1] as ExprValue).expr is Variable) {
        final varName = ((args[1] as ExprValue).expr as Variable).name;
        final rep = expectCommandExpr(args[2], 'subs');
        return _applySubstitution(current, varName, rep, ctx);
      }
      for (var i = 1; i < args.length; i++) {
        final eq = expectCommandExpr(args[i], 'subs');
        if (eq case Equal(left: Variable(:final name), :final right)) {
          current = _applySubstitution(current, name, right, ctx);
        } else {
          throw ArgumentError(
            'subs expects equations of the form "x = value", got: $eq',
          );
        }
      }
      return current;
    },
  ),
  Command(
    name: 'apart',
    category: CommandCategory.algebra,
    signature: 'apart(expr, [var])',
    paramSpecs: const [ParamSpec.expr('expr'), ParamSpec.symbol('[var]')],
    minArity: 1,
    maxArity: 2,
    doc: 'Computes the partial fraction decomposition of a rational function.',
    examples: const [
      'apart(1 / (x^2 - 1), x)',
      'apart((3*x + 5) / (x^3 - x), x)',
    ],
    rpnLabel: 'Apart',
    rpnArity: 2,
    appliesTo: (v) =>
        v is ExprValue &&
        !v.isEquation &&
        v.expr.denominator != IntegerNumber.one &&
        v.expr.freeVariables.isNotEmpty,
    chipLabel: 'Apart',
    buildChipCall: (id, v) => 'apart(r[$id], ${primaryCommandVar(v) ?? 'x'})',
    run: (args, ctx) {
      checkCommandArity('apart', args, 1, 2);
      final expr = expectCommandExpr(args[0], 'apart');
      final v = args.length >= 2
          ? expectCommandVarName(args[1], 'apart')
          : (expr.freeVariables.isNotEmpty ? expr.freeVariables.first : 'x');
      return ExprValue(expr.apart(v));
    },
  ),
  Command(
    name: 'together',
    category: CommandCategory.algebra,
    signature: 'together(expr)',
    paramSpecs: const [ParamSpec.expr('expr')],
    minArity: 1,
    maxArity: 1,
    doc: 'Combines rational terms over a common reduced denominator.',
    examples: const ['together(1 / (x - 1) + 1 / (x + 1))'],
    rpnLabel: 'Together',
    rpnArity: 1,
    appliesTo: (_) => false,
    chipLabel: 'Together',
    buildChipCall: (id, _) => 'together(r[$id])',
    run: (args, ctx) {
      checkCommandArity('together', args, 1, 1);
      return liftUnaryCommand(args[0], (e) => e.together());
    },
  ),
  Command(
    name: 'cancel',
    category: CommandCategory.algebra,
    signature: 'cancel(expr)',
    paramSpecs: const [ParamSpec.expr('expr')],
    minArity: 1,
    maxArity: 1,
    doc: 'Cancels common polynomial factors between numerator and denominator.',
    examples: const ['cancel((x^2 - 1) / (x^2 + 2*x + 1))'],
    rpnLabel: 'Cancel',
    rpnArity: 1,
    appliesTo: (_) => false,
    chipLabel: 'Cancel',
    buildChipCall: (id, _) => 'cancel(r[$id])',
    run: (args, ctx) {
      checkCommandArity('cancel', args, 1, 1);
      return liftUnaryCommand(args[0], (e) => e.cancel());
    },
  ),
  Command(
    name: 'collect',
    category: CommandCategory.algebra,
    signature: 'collect(expr, var)',
    paramSpecs: const [ParamSpec.expr('expr'), ParamSpec.symbol('var')],
    minArity: 1,
    maxArity: 2,
    doc: 'Collects additive terms by powers of the given variable.',
    examples: const ['collect(a*x^2 + b*x^2 + c*x + d*x, x)'],
    rpnLabel: 'Collect',
    rpnArity: 2,
    appliesTo: (_) => false,
    chipLabel: 'Collect',
    buildChipCall: (id, v) => 'collect(r[$id], ${primaryCommandVar(v) ?? 'x'})',
    run: (args, ctx) {
      checkCommandArity('collect', args, 1, 2);
      final expr = expectCommandExpr(args[0], 'collect');
      final v = args.length >= 2
          ? expectCommandVarName(args[1], 'collect')
          : (expr.freeVariables.isNotEmpty ? expr.freeVariables.first : 'x');
      return ExprValue(expr.collect(v));
    },
  ),
  Command(
    name: 'numer',
    category: CommandCategory.algebra,
    signature: 'numer(expr)',
    paramSpecs: const [ParamSpec.expr('expr')],
    minArity: 1,
    maxArity: 1,
    doc: 'Extracts the syntactic numerator of an expression.',
    examples: const ['numer((x^2 + 1) / (x - 2))'],
    rpnLabel: 'Numerator',
    rpnArity: 1,
    appliesTo: (_) => false,
    chipLabel: 'Numer',
    buildChipCall: (id, _) => 'numer(r[$id])',
    run: (args, ctx) {
      checkCommandArity('numer', args, 1, 1);
      return liftUnaryCommand(args[0], (e) => e.numerator);
    },
  ),
  Command(
    name: 'denom',
    category: CommandCategory.algebra,
    signature: 'denom(expr)',
    paramSpecs: const [ParamSpec.expr('expr')],
    minArity: 1,
    maxArity: 1,
    doc: 'Extracts the syntactic denominator of an expression.',
    examples: const ['denom((x^2 + 1) / (x - 2))'],
    rpnLabel: 'Denominator',
    rpnArity: 1,
    appliesTo: (_) => false,
    chipLabel: 'Denom',
    buildChipCall: (id, _) => 'denom(r[$id])',
    run: (args, ctx) {
      checkCommandArity('denom', args, 1, 1);
      return liftUnaryCommand(args[0], (e) => e.denominator);
    },
  ),
  Command(
    name: 'trigexpand',
    category: CommandCategory.algebra,
    signature: 'trigexpand(expr)',
    paramSpecs: const [ParamSpec.expr('expr')],
    minArity: 1,
    maxArity: 1,
    doc: 'Expands trigonometric and hyperbolic multiple-angle/sum formulas.',
    examples: const ['trigexpand(sin(2*x))', 'trigexpand(cos(x + y))'],
    rpnLabel: 'Trig Expand',
    rpnArity: 1,
    appliesTo: (v) =>
        v is ExprValue &&
        v.expr.anyNode((n) => n is Sin || n is Cos || n is Tan),
    chipLabel: 'TrigExpand',
    buildChipCall: (id, _) => 'trigexpand(r[$id])',
    run: (args, ctx) {
      checkCommandArity('trigexpand', args, 1, 1);
      return liftUnaryCommand(args[0], (e) => e.expandTrig());
    },
  ),
  Command(
    name: 'trigsimplify',
    category: CommandCategory.algebra,
    signature: 'trigsimplify(expr)',
    paramSpecs: const [ParamSpec.expr('expr')],
    minArity: 1,
    maxArity: 1,
    doc: 'Contracts trigonometric products into sums and reduces tan/sin/cos.',
    examples: const ['trigsimplify(sin(x) * cos(y))'],
    rpnLabel: 'Trig Reduce',
    rpnArity: 1,
    appliesTo: (_) => false,
    chipLabel: 'TrigSimp',
    buildChipCall: (id, _) => 'trigsimplify(r[$id])',
    run: (args, ctx) {
      checkCommandArity('trigsimplify', args, 1, 1);
      return liftUnaryCommand(args[0], (e) => e.simplifyTrig());
    },
  ),
];

CalcValue _applySubstitution(
  CalcValue target,
  String varName,
  Expr replacement,
  EvaluatorContext ctx,
) => liftUnaryCommand(
  target,
  (e) {
    final sub = e.substitute(varName, replacement);
    return ctx.settings.autoSimplify
        ? sub.simplify(assumptions: ctx.assumptions)
        : sub;
  },
  onMatrix: (m) {
    final sub = m.substitute(varName, replacement);
    return ctx.settings.autoSimplify ? sub.simplify() : sub;
  },
  onVector: (v) {
    final sub = v.substitute(varName, replacement);
    return ctx.settings.autoSimplify ? sub.simplify() : sub;
  },
);
