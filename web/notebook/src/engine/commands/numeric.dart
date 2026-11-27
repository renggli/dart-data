import 'package:data/linear.dart';
import 'package:data/numeric.dart';
import 'package:data/symbolic.dart';
import 'package:data/type.dart';

import '../../language/signature.dart';
import '../../model/value.dart';
import '../commands.dart';

final List<Command> numericCommands = [
  Command(
    name: 'nintegrate',
    category: CommandCategory.numeric,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('expr'),
        ParamSpec.optional('var', type: ParamType.symbol),
      ],
      named: [
        ParamSpec.named('from', type: ParamType.number, required: true),
        ParamSpec.named('to', type: ParamType.number, required: true),
        ParamSpec.named(
          'method',
          type: ParamType.string,
          defaultValue: 'gaussKronrod',
          enumValues: ['gaussKronrod', 'simpson'],
        ),
        ParamSpec.named('tol', type: ParamType.number, defaultValue: 1e-10),
      ],
    ),
    doc: 'Computes a definite integral numerically.',
    examples: ['nintegrate(exp(-x^2), x, from: 0, to: 1)'],
    run: (args, _) {
      final expr = args.expr('expr');
      final v = inferVariable(expr, args.symbolOrNull('var'));
      final fn = expr.toFunction1D(v);
      final method = switch (args.stringVal('method')) {
        'simpson' => IntegrationMethod.simpson,
        _ => IntegrationMethod.gaussKronrod,
      };
      final value = integrate(
        fn,
        args.doubleVal('from'),
        args.doubleVal('to'),
        method: method,
        tolerance: args.doubleVal('tol'),
      );
      return ExprValue(RealNumber.fromDouble(value));
    },
  ),
  Command(
    name: 'nsolve',
    category: CommandCategory.numeric,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('eq', type: ParamType.equation),
        ParamSpec.optional('var', type: ParamType.symbol),
      ],
      named: [
        ParamSpec.named('guess', type: ParamType.number),
        ParamSpec.named('from', type: ParamType.number),
        ParamSpec.named('to', type: ParamType.number),
        ParamSpec.named(
          'method',
          type: ParamType.string,
          defaultValue: 'brent',
          enumValues: ['brent', 'bisection', 'newtonRaphson'],
        ),
        ParamSpec.named('tol', type: ParamType.number, defaultValue: 1e-12),
      ],
    ),
    doc: 'Finds a numerical root of an equation or expression.',
    examples: ['nsolve(cos(x) = x, x, from: 0, to: 1)'],
    run: (args, _) {
      final raw = args.expr('eq');
      final expr = raw is Relational && raw.op == RelOp.equal
          ? raw.left - raw.right
          : raw;
      final v = inferVariable(expr, args.symbolOrNull('var'));
      final fn = expr.toFunction1D(v);
      final a = args.doubleOrNull('from') ?? args.doubleOrNull('guess') ?? 0.0;
      final b = args.doubleOrNull('to');
      final method = switch (args.stringVal('method')) {
        'bisection' => RootMethod.bisection,
        'newtonRaphson' => RootMethod.newtonRaphson,
        _ => RootMethod.brent,
      };
      final root = solve(
        fn,
        a,
        b: b,
        method: method,
        tolerance: args.doubleVal('tol'),
      );
      return ExprValue(RealNumber.fromDouble(root));
    },
  ),
  Command(
    name: 'nminimize',
    category: CommandCategory.numeric,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('expr'),
        ParamSpec.optional('var', type: ParamType.symbol),
      ],
      named: [
        ParamSpec.named('from', type: ParamType.number, defaultValue: -5.0),
        ParamSpec.named('to', type: ParamType.number, defaultValue: 5.0),
        ParamSpec.named('guess', type: ParamType.number),
        ParamSpec.named(
          'method',
          type: ParamType.string,
          defaultValue: 'brent',
          enumValues: ['brent', 'nelderMead', 'bfgs', 'lbfgs'],
        ),
        ParamSpec.named('tol', type: ParamType.number, defaultValue: 1e-10),
      ],
    ),
    doc: 'Finds a local minimum of a 1D expression numerically.',
    examples: ['nminimize(x^2 - 4*x + 5, x, from: 0, to: 5)'],
    run: (args, _) {
      final expr = args.expr('expr');
      final v = inferVariable(expr, args.symbolOrNull('var'));
      final fn = expr.toFunction1D(v);
      final from = args.doubleVal('from');
      final to = args.doubleVal('to');
      final guess = args.doubleOrNull('guess') ?? 0.5 * (from + to);
      final method = switch (args.stringVal('method')) {
        'nelderMead' => OptimizationMethod.nelderMead,
        'bfgs' => OptimizationMethod.bfgs,
        'lbfgs' => OptimizationMethod.lbfgs,
        _ => OptimizationMethod.brent,
      };
      final res = minimize(
        (vec) => fn(vec[0]),
        initialPoint: Vector<double>.fromList([guess], type: DataType.float64),
        a: from,
        b: to,
        method: method,
        tolerance: args.doubleVal('tol'),
      );
      return ListValue([
        ExprValue(RealNumber.fromDouble(res.point[0])),
        ExprValue(RealNumber.fromDouble(res.value)),
      ]);
    },
  ),
  Command(
    name: 'nsolvesystem',
    category: CommandCategory.numeric,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('equations', type: ParamType.exprList),
        ParamSpec.positional('vars', type: ParamType.symbolList),
        ParamSpec.positional('guess', type: ParamType.exprList),
      ],
      named: [
        ParamSpec.named('tol', type: ParamType.number, defaultValue: 1e-10),
      ],
    ),
    doc: 'Solves a nonlinear system F(x) = 0 numerically via multivariate Newton-Raphson.',
    examples: ['nsolvesystem([x^2 + y^2 - 5, x - y - 1], [x, y], [2, 1])'],
    run: (args, _) {
      final rawEqs = args.exprList('equations');
      final vars = args.symbolList('vars');
      final guessExprs = args.exprList('guess');
      if (rawEqs.length != vars.length || guessExprs.length != vars.length) {
        throw ArgumentBindingException(
          'nsolvesystem requires matching counts for equations (${rawEqs.length}), '
          'variables (${vars.length}), and initial guess (${guessExprs.length})',
        );
      }
      final guessVals = <double>[];
      for (final g in guessExprs) {
        final approx = g.approximate();
        final double v;
        if (approx is RealNumber) {
          v = approx.value;
        } else if (approx is IntegerNumber) {
          v = approx.value.toDouble();
        } else {
          throw const ArgumentBindingException(
            'Initial guess coordinates must evaluate to real numbers',
          );
        }
        guessVals.add(v);
      }
      final fns = [
        for (final raw in rawEqs)
          (raw is Relational && raw.op == RelOp.equal
                  ? raw.left - raw.right
                  : raw)
              .toVectorFunction(vars),
      ];
      final sol = solveSystem(
        fns,
        Vector<double>.fromList(guessVals, type: DataType.float64),
        tolerance: args.doubleVal('tol'),
      );
      return VectorValue(
        Vector<Expr>.generate(
          sol.length,
          (i) => RealNumber.fromDouble(sol[i]),
          type: exprDataType,
        ),
      );
    },
  ),
  Command(
    name: 'nderivative',
    category: CommandCategory.numeric,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('expr'),
        ParamSpec.positional('varOrAt', type: ParamType.any),
        ParamSpec.optional('at', type: ParamType.number),
      ],
      named: [
        ParamSpec.named('order', type: ParamType.integer, defaultValue: 1),
      ],
    ),
    doc: 'Computes the numerical derivative at a point.',
    examples: ['nderivative(sin(x), x, 0)', 'nderivative(sin(x), 0)'],
    run: (args, _) {
      final expr = args.expr('expr');
      final atOpt = args.doubleOrNull('at');
      final String v;
      final double at;
      if (atOpt != null) {
        final rawVar = args.raw('varOrAt');
        if (rawVar is ExprValue && rawVar.expr is Variable) {
          v = (rawVar.expr as Variable).name;
        } else {
          throw const ArgumentBindingException(
            'nderivative second argument must be a variable symbol',
          );
        }
        at = atOpt;
      } else {
        v = inferVariable(expr);
        final rawAt = args.raw('varOrAt');
        if (rawAt is ExprValue) {
          final approx = rawAt.expr.approximate();
          if (approx is RealNumber) {
            at = approx.value;
          } else if (approx is IntegerNumber) {
            at = approx.value.toDouble();
          } else {
            throw const ArgumentBindingException(
              'nderivative evaluation point must be a real number',
            );
          }
        } else {
          throw const ArgumentBindingException(
            'nderivative evaluation point must be a real number',
          );
        }
      }
      final order = args.intVal('order');
      final val = derivative(expr.toFunction1D(v), at, order: order);
      return ExprValue(RealNumber.fromDouble(val));
    },
  ),
];
