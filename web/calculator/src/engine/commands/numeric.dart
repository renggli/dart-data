import 'dart:math' as math;

import 'package:data/linear.dart';
import 'package:data/numeric.dart' as numeric;
import 'package:data/symbolic.dart';

import '../../model/value.dart';
import '../commands.dart';

/// Builds canonical numerical analysis commands (`nintegrate`, `nsolve`,
/// `nminimize`, `nderivative`).
List<Command> buildNumericCommands() => [
  Command(
    name: 'nintegrate',
    category: CommandCategory.numeric,
    signature: 'nintegrate(expr, [var], [a], [b])',
    paramSpecs: const [
      ParamSpec.expr('expr'),
      ParamSpec.symbol('[var]'),
      ParamSpec.optionalExpr('[a]'),
      ParamSpec.optionalExpr('[b]'),
    ],
    minArity: 1,
    maxArity: 4,
    doc: 'Computes high-precision numerical quadrature on [a, b].',
    examples: const [
      'nintegrate(exp(-x^2) * cos(x^3), x, 0, 1)',
      'nintegrate(sin(x) / x, x, 0, pi)',
    ],
    rpnLabel: 'Numeric ∫',
    rpnArity: 4,
    appliesTo: (v) => v is ExprValue && v.expr is Integral,
    chipLabel: 'Numeric ∫',
    buildChipCall: (id, v) {
      if (v case ExprValue(
        expr: Integral(:final variable, :final lower?, :final upper?),
      )) {
        return 'nintegrate(r[$id], $variable, $lower, $upper)';
      }
      final vName = primaryCommandVar(v) ?? 'x';
      return 'nintegrate(r[$id], $vName, 0, 1)';
    },
    run: (args, ctx) {
      checkCommandArity('nintegrate', args, 1, 4);
      final first = expectCommandExpr(args[0], 'nintegrate');
      if (args.length == 1 && first is Integral && first.isDefinite) {
        final fn = first.integrand.toFunction1D(first.variable);
        final a = first.lower!.evaluate();
        final b = first.upper!.evaluate();
        final val = numeric.integrate(fn, a, b);
        return ExprValue(RealNumber.fromDouble(val));
      }
      if (args.length < 4) {
        throw ArgumentError(
          'nintegrate requires (expr, var, a, b) or a definite Integral.',
        );
      }
      final integrand = first is Integral ? first.integrand : first;
      final varName = expectCommandVarName(args[1], 'nintegrate');
      final a = expectCommandDouble(args[2], 'nintegrate');
      final b = expectCommandDouble(args[3], 'nintegrate');
      final fn = integrand.toFunction1D(varName);
      final val = numeric.integrate(fn, a, b);
      return ExprValue(RealNumber.fromDouble(val));
    },
  ),
  Command(
    name: 'nsolve',
    category: CommandCategory.numeric,
    signature: 'nsolve(eq, var, x0, [x1])',
    paramSpecs: const [
      ParamSpec.expr('eq'),
      ParamSpec.symbol('var'),
      ParamSpec.expr('x0'),
      ParamSpec.optionalExpr('[x1]'),
    ],
    minArity: 3,
    maxArity: 4,
    doc: 'Finds a numerical root near x0 (or bracketed in [x0, x1]).',
    examples: const [
      'nsolve(cos(x) = x, x, 0.5)',
      'nsolve(x^5 - x - 1, x, 1, 2)',
    ],
    rpnLabel: 'NSolve',
    rpnArity: 3,
    appliesTo: (_) => false,
    chipLabel: 'NSolve',
    buildChipCall: (id, v) =>
        'nsolve(r[$id], ${primaryCommandVar(v) ?? 'x'}, 1)',
    run: (args, ctx) {
      checkCommandArity('nsolve', args, 3, 4);
      var expr = expectCommandExpr(args[0], 'nsolve');
      if (expr case Equal(:final left, :final right)) {
        expr = left - right;
      }
      final varName = expectCommandVarName(args[1], 'nsolve');
      final x0 = expectCommandDouble(args[2], 'nsolve');
      final x1 = args.length == 4
          ? expectCommandDouble(args[3], 'nsolve')
          : null;
      final fn = expr.toFunction1D(varName);
      final root = numeric.solve(fn, x0, b: x1);
      return ExprValue(RealNumber.fromDouble(root));
    },
  ),
  Command(
    name: 'nminimize',
    category: CommandCategory.numeric,
    signature: 'nminimize(expr, var, x0, [x1])',
    paramSpecs: const [
      ParamSpec.expr('expr'),
      ParamSpec.symbol('var'),
      ParamSpec.expr('x0'),
      ParamSpec.optionalExpr('[x1]'),
    ],
    minArity: 3,
    maxArity: 4,
    doc: 'Finds a numerical local minimum of expr.',
    examples: const ['nminimize(x^4 - 3*x^2 + x, x, -2, 0)'],
    rpnLabel: 'NMin',
    rpnArity: 3,
    appliesTo: (_) => false,
    chipLabel: 'NMin',
    buildChipCall: (id, v) =>
        'nminimize(r[$id], ${primaryCommandVar(v) ?? 'x'}, -2, 2)',
    run: (args, ctx) {
      checkCommandArity('nminimize', args, 3, 4);
      final expr = expectCommandExpr(args[0], 'nminimize');
      final varName = expectCommandVarName(args[1], 'nminimize');
      final a = expectCommandDouble(args[2], 'nminimize');
      final b = args.length == 4
          ? expectCommandDouble(args[3], 'nminimize')
          : a + 2.0;
      final minBound = math.min(a, b - 1.0);
      final maxBound = math.max(a + 1.0, b);
      final fn = expr.toFunction1D(varName);
      final pt = numeric.minimize(
        (v) => fn(v[0]),
        a: minBound,
        b: maxBound,
        method: numeric.OptimizationMethod.brent,
      );
      return VectorValue(
        Vector<Expr>.fromList([
          RealNumber.fromDouble(pt.point[0]),
          RealNumber.fromDouble(pt.value),
        ], type: exprDataType),
      );
    },
  ),
  Command(
    name: 'nderivative',
    category: CommandCategory.numeric,
    signature: 'nderivative(expr, var, x0, [order])',
    paramSpecs: const [
      ParamSpec.expr('expr'),
      ParamSpec.symbol('var'),
      ParamSpec.expr('x0'),
      ParamSpec.optionalInt('[order]'),
    ],
    minArity: 3,
    maxArity: 4,
    doc: 'Evaluates the high-order numerical derivative at x = x0.',
    examples: const [
      'nderivative(sin(x), x, pi / 3)',
      'nderivative(exp(x), x, 0, 2)',
    ],
    rpnLabel: 'NDeriv',
    rpnArity: 3,
    appliesTo: (_) => false,
    chipLabel: 'NDiff',
    buildChipCall: (id, v) =>
        'nderivative(r[$id], ${primaryCommandVar(v) ?? 'x'}, 1)',
    run: (args, ctx) {
      checkCommandArity('nderivative', args, 3, 4);
      final expr = expectCommandExpr(args[0], 'nderivative');
      final varName = expectCommandVarName(args[1], 'nderivative');
      final x0 = expectCommandDouble(args[2], 'nderivative');
      final order = args.length == 4
          ? expectCommandInt(args[3], 'nderivative')
          : 1;
      final fn = expr.toFunction1D(varName);
      final val = numeric.derivative(fn, x0, order: order);
      return ExprValue(RealNumber.fromDouble(val));
    },
  ),
];
