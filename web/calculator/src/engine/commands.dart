import 'dart:math' as math;

import 'package:data/linear.dart';
import 'package:data/numeric.dart' as numeric;
import 'package:data/symbolic.dart';

import '../model/environment.dart';
import '../model/session.dart';
import '../model/value.dart';
import 'sampling.dart';

/// Category grouping for calculator commands (drives palette, keypad tabs,
/// soft-key menus, and help reference).
enum CommandCategory {
  algebra('ALG', 'Algebra'),
  calculus('CALC', 'Calculus'),
  linear('MATRIX', 'Linear Algebra'),
  complex('CPLX', 'Complex'),
  numbers('NUM', 'Numbers'),
  numeric('NUMERIC', 'Numeric'),
  plot('PLOT', 'Plotting'),
  session('VARS', 'Session');

  new(this.softMenuLabel, this.title);

  final String softMenuLabel;
  final String title;
}

/// Execution context passed to every command.
final class EvaluatorContext {
  const new({required this.environment, required this.session});

  final Environment environment;
  final Session session;

  CalcSettings get settings => environment.settings;
  Assumptions get assumptions => environment.settings.assumptions;
}

/// Metadata and execution handler for a canonical calculator command.
final class Command {
  const new({
    required this.name,
    required this.category,
    required this.signature,
    required this.params,
    required this.doc,
    required this.examples,
    required this.rpnLabel,
    required this.rpnArity,
    required this.appliesTo,
    required this.chipLabel,
    required this.buildChipCall,
    required this.run,
  });

  /// Canonical command name (`simplify`, `integrate`, `det`, ...).
  final String name;

  /// Command category.
  final CommandCategory category;

  /// Human-readable signature (`integrate(expr, var, [a, b])`).
  final String signature;

  /// Parameter names for active-argument highlighting in autocomplete.
  final List<String> params;

  /// Concise one-line description.
  final String doc;

  /// Runnable example strings.
  final List<String> examples;

  /// Short label shown on HP48 RPN soft keys (`∫`, `d/dx`, `DET`, ...).
  final String rpnLabel;

  /// Number of stack levels consumed when invoked as an RPN soft key.
  final int rpnArity;

  /// Predicate determining whether this command should be surfaced as a
  /// context-aware action chip beneath a given result [CalcValue].
  final bool Function(CalcValue value) appliesTo;

  /// Short label for the context action chip.
  final String chipLabel;

  /// Builds the Scroll statement when the user clicks this command's action
  /// chip on a result cell.
  final String Function(int id, CalcValue value) buildChipCall;

  /// Executes the command on resolved `args`.
  final CalcValue Function(List<CalcValue> args, EvaluatorContext ctx) run;
}

/// Central registry of all canonical calculator commands across categories.
abstract final class CommandRegistry {
  static final List<Command> all = _buildAllCommands();

  static final Map<String, Command> byName = {
    for (final cmd in all) cmd.name: cmd,
  };

  /// Returns commands belonging to [category].
  static List<Command> forCategory(CommandCategory category) => [
    for (final cmd in all)
      if (cmd.category == category) cmd,
  ];

  /// Returns up to [maxChips] applicable action-chip commands for [value], plus
  /// any overflow commands.
  static ({List<Command> primary, List<Command> overflow}) chipsFor(
    CalcValue value, {
    int maxChips = 6,
  }) {
    if (value is ErrorValue || value is InfoValue || value is PlotValue) {
      return (primary: const [], overflow: const []);
    }
    final matching = [
      for (final cmd in all)
        if (cmd.appliesTo(value)) cmd,
    ];
    if (matching.length <= maxChips) {
      return (primary: matching, overflow: const []);
    }
    return (
      primary: matching.sublist(0, maxChips),
      overflow: matching.sublist(maxChips),
    );
  }

  static List<Command> _buildAllCommands() => [
    // =========================================================================
    // 1. ALGEBRA
    // =========================================================================
    Command(
      name: 'simplify',
      category: CommandCategory.algebra,
      signature: 'simplify(expr)',
      params: const ['expr'],
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
        _checkArity('simplify', args, 1, 1);
        return _liftUnary(
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
      params: const ['expr'],
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
        _checkArity('expand', args, 1, 1);
        return _liftUnary(
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
      params: const ['expr'],
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
        _checkArity('factor', args, 1, 1);
        return _liftUnary(
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
      params: const ['eq', '[var]'],
      doc:
          'Solves an algebraic/transcendental equation or system of equations.',
      examples: const [
        'solve(x^2 - 5*x + 6 = 0, x)',
        'solve([x + y = 3, x - y = 1], [x, y])',
      ],
      rpnLabel: 'Solve',
      rpnArity: 2,
      appliesTo: (v) => v is ExprValue && v.expr.freeVariables.isNotEmpty,
      chipLabel: 'Roots',
      buildChipCall: (id, v) {
        final vName = _primaryVar(v) ?? 'x';
        return 'solve(r[$id], $vName)';
      },
      run: (args, ctx) {
        _checkArity('solve', args, 1, 2);
        // System solve: solve([eq1, eq2], [x, y])
        if (args[0] is VectorValue || args[0] is ListValue) {
          final eqs = _extractExprList(args[0], 'solve');
          final vars = args.length >= 2
              ? _extractVarNameList(args[1], 'solve')
              : _inferSystemVariables(eqs);
          final solutions = eqs.solve(vars);
          return ListValue([
            for (final sol in solutions)
              ListValue([
                for (final v in vars)
                  ExprValue(Equal(Variable(v), sol[v] ?? IntegerNumber.zero)),
              ]),
          ]);
        }
        final target = _expectExpr(args[0], 'solve');
        final varName = args.length >= 2
            ? _expectVarName(args[1], 'solve')
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
      params: const ['expr', 'var = val'],
      doc: 'Substitutes variables in an expression, vector, or matrix.',
      examples: const ['subs(x^2 + y, x = 3)', 'subs(sin(x), x = pi / 4)'],
      rpnLabel: 'Subs',
      rpnArity: 2,
      appliesTo: (_) => false,
      chipLabel: 'Subs',
      buildChipCall: (id, v) => 'subs(r[$id], ${_primaryVar(v) ?? 'x'} = 0)',
      run: (args, ctx) {
        _checkArity('subs', args, 2, 16);
        var current = args[0];
        if (args.length == 3 &&
            args[1] is ExprValue &&
            (args[1] as ExprValue).expr is Variable) {
          final varName = ((args[1] as ExprValue).expr as Variable).name;
          final rep = _expectExpr(args[2], 'subs');
          return _applySubstitution(current, varName, rep, ctx);
        }
        for (var i = 1; i < args.length; i++) {
          final eq = _expectExpr(args[i], 'subs');
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
      params: const ['expr', '[var]'],
      doc:
          'Computes the partial fraction decomposition of a rational function.',
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
      buildChipCall: (id, v) => 'apart(r[$id], ${_primaryVar(v) ?? 'x'})',
      run: (args, ctx) {
        _checkArity('apart', args, 1, 2);
        final expr = _expectExpr(args[0], 'apart');
        final v = args.length >= 2
            ? _expectVarName(args[1], 'apart')
            : (expr.freeVariables.isNotEmpty ? expr.freeVariables.first : 'x');
        return ExprValue(expr.apart(v));
      },
    ),
    Command(
      name: 'together',
      category: CommandCategory.algebra,
      signature: 'together(expr)',
      params: const ['expr'],
      doc: 'Combines rational terms over a common reduced denominator.',
      examples: const ['together(1 / (x - 1) + 1 / (x + 1))'],
      rpnLabel: 'Together',
      rpnArity: 1,
      appliesTo: (_) => false,
      chipLabel: 'Together',
      buildChipCall: (id, _) => 'together(r[$id])',
      run: (args, ctx) {
        _checkArity('together', args, 1, 1);
        return _liftUnary(args[0], (e) => e.together());
      },
    ),
    Command(
      name: 'cancel',
      category: CommandCategory.algebra,
      signature: 'cancel(expr)',
      params: const ['expr'],
      doc: 'Cancels common polynomial factors between numerator and denominator.',
      examples: const ['cancel((x^2 - 1) / (x^2 + 2*x + 1))'],
      rpnLabel: 'Cancel',
      rpnArity: 1,
      appliesTo: (_) => false,
      chipLabel: 'Cancel',
      buildChipCall: (id, _) => 'cancel(r[$id])',
      run: (args, ctx) {
        _checkArity('cancel', args, 1, 1);
        return _liftUnary(args[0], (e) => e.cancel());
      },
    ),
    Command(
      name: 'collect',
      category: CommandCategory.algebra,
      signature: 'collect(expr, var)',
      params: const ['expr', 'var'],
      doc: 'Collects additive terms by powers of the given variable.',
      examples: const ['collect(a*x^2 + b*x^2 + c*x + d*x, x)'],
      rpnLabel: 'Collect',
      rpnArity: 2,
      appliesTo: (_) => false,
      chipLabel: 'Collect',
      buildChipCall: (id, v) => 'collect(r[$id], ${_primaryVar(v) ?? 'x'})',
      run: (args, ctx) {
        _checkArity('collect', args, 1, 2);
        final expr = _expectExpr(args[0], 'collect');
        final v = args.length >= 2
            ? _expectVarName(args[1], 'collect')
            : (expr.freeVariables.isNotEmpty ? expr.freeVariables.first : 'x');
        return ExprValue(expr.collect(v));
      },
    ),
    Command(
      name: 'numer',
      category: CommandCategory.algebra,
      signature: 'numer(expr)',
      params: const ['expr'],
      doc: 'Extracts the syntactic numerator of an expression.',
      examples: const ['numer((x^2 + 1) / (x - 2))'],
      rpnLabel: 'Numerator',
      rpnArity: 1,
      appliesTo: (_) => false,
      chipLabel: 'Numer',
      buildChipCall: (id, _) => 'numer(r[$id])',
      run: (args, ctx) {
        _checkArity('numer', args, 1, 1);
        return _liftUnary(args[0], (e) => e.numerator);
      },
    ),
    Command(
      name: 'denom',
      category: CommandCategory.algebra,
      signature: 'denom(expr)',
      params: const ['expr'],
      doc: 'Extracts the syntactic denominator of an expression.',
      examples: const ['denom((x^2 + 1) / (x - 2))'],
      rpnLabel: 'Denominator',
      rpnArity: 1,
      appliesTo: (_) => false,
      chipLabel: 'Denom',
      buildChipCall: (id, _) => 'denom(r[$id])',
      run: (args, ctx) {
        _checkArity('denom', args, 1, 1);
        return _liftUnary(args[0], (e) => e.denominator);
      },
    ),
    Command(
      name: 'trigexpand',
      category: CommandCategory.algebra,
      signature: 'trigexpand(expr)',
      params: const ['expr'],
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
        _checkArity('trigexpand', args, 1, 1);
        return _liftUnary(args[0], (e) => e.expandTrig());
      },
    ),
    Command(
      name: 'trigsimplify',
      category: CommandCategory.algebra,
      signature: 'trigsimplify(expr)',
      params: const ['expr'],
      doc:
          'Contracts trigonometric products into sums and reduces tan/sin/cos.',
      examples: const ['trigsimplify(sin(x) * cos(y))'],
      rpnLabel: 'Trig Reduce',
      rpnArity: 1,
      appliesTo: (_) => false,
      chipLabel: 'TrigSimp',
      buildChipCall: (id, _) => 'trigsimplify(r[$id])',
      run: (args, ctx) {
        _checkArity('trigsimplify', args, 1, 1);
        return _liftUnary(args[0], (e) => e.simplifyTrig());
      },
    ),

    // =========================================================================
    // 2. CALCULUS
    // =========================================================================
    Command(
      name: 'diff',
      category: CommandCategory.calculus,
      signature: 'diff(expr, [var], [order])',
      params: const ['expr', '[var]', '[order]'],
      doc: 'Computes the symbolic derivative with respect to var.',
      examples: const ['diff(x^3 * sin(x), x)', 'diff(exp(-x^2), x, 2)'],
      rpnLabel: 'd/dx',
      rpnArity: 2,
      appliesTo: (v) =>
          (v is ExprValue &&
              !v.isEquation &&
              v.expr.freeVariables.isNotEmpty) ||
          v is VectorValue ||
          v is MatrixValue,
      chipLabel: 'd/dx',
      buildChipCall: (id, v) => 'diff(r[$id], ${_primaryVar(v) ?? 'x'})',
      run: (args, ctx) {
        _checkArity('diff', args, 1, 3);
        final varName = args.length >= 2
            ? _expectVarName(args[1], 'diff')
            : (_primaryVar(args[0]) ?? 'x');
        final order = args.length >= 3 ? _expectInt(args[2], 'diff') : 1;
        return _liftUnary(
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
      params: const ['expr', '[var]', '[a]', '[b]'],
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
      buildChipCall: (id, v) => 'integrate(r[$id], ${_primaryVar(v) ?? 'x'})',
      run: (args, ctx) {
        _checkArity('integrate', args, 1, 4);
        if (args.length == 3) {
          throw ArgumentError(
            'integrate requires 1, 2, or 4 arguments (expr, var, [lower, upper]).',
          );
        }
        final varName = args.length >= 2
            ? _expectVarName(args[1], 'integrate')
            : (_primaryVar(args[0]) ?? 'x');
        final lower = args.length == 4
            ? _expectExpr(args[2], 'integrate')
            : null;
        final upper = args.length == 4
            ? _expectExpr(args[3], 'integrate')
            : null;
        return _liftUnary(
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
      params: const ['expr', '[var]', '[point]', '[order]'],
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
          'taylor(r[$id], ${_primaryVar(v) ?? 'x'}, 0, 5)',
      run: (args, ctx) {
        _checkArity('taylor', args, 1, 4);
        final expr = _expectExpr(args[0], 'taylor');
        final varName = args.length >= 2
            ? _expectVarName(args[1], 'taylor')
            : (expr.freeVariables.isNotEmpty ? expr.freeVariables.first : 'x');
        final point = args.length >= 3
            ? _expectExpr(args[2], 'taylor')
            : IntegerNumber.zero;
        final degree = args.length == 4 ? _expectInt(args[3], 'taylor') : 5;
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
      params: const ['expr', '[var]', '[point]', '[order]'],
      doc: 'Computes a truncated power/Laurent series with O((x - a)^n).',
      examples: const ['series(exp(x), x, 0, 5)', 'series(cot(x), x, 0, 4)'],
      rpnLabel: 'Series',
      rpnArity: 4,
      appliesTo: (_) => false,
      chipLabel: 'Series',
      buildChipCall: (id, v) =>
          'series(r[$id], ${_primaryVar(v) ?? 'x'}, 0, 5)',
      run: (args, ctx) {
        _checkArity('series', args, 1, 4);
        final expr = _expectExpr(args[0], 'series');
        final varName = args.length >= 2
            ? _expectVarName(args[1], 'series')
            : (expr.freeVariables.isNotEmpty ? expr.freeVariables.first : 'x');
        final point = args.length >= 3
            ? _expectExpr(args[2], 'series')
            : IntegerNumber.zero;
        final order = args.length >= 4 ? _expectInt(args[3], 'series') : 5;
        return SeriesValue(
          expr.toPowerSeries(varName, point: point, order: order),
        );
      },
    ),
    Command(
      name: 'limit',
      category: CommandCategory.calculus,
      signature: 'limit(expr, var, point, [dir])',
      params: const ['expr', 'var', 'point', '[dir]'],
      doc: 'Evaluates the symbolic limit as var approaches point.',
      examples: const [
        'limit(sin(x) / x, x, 0)',
        'limit((1 + 1 / x)^x, x, infinity)',
        'limit(1 / x, x, 0, fromAbove)',
      ],
      rpnLabel: 'Limit',
      rpnArity: 3,
      appliesTo: (_) => false,
      chipLabel: 'Limit',
      buildChipCall: (id, v) => 'limit(r[$id], ${_primaryVar(v) ?? 'x'}, 0)',
      run: (args, ctx) {
        _checkArity('limit', args, 3, 4);
        final expr = _expectExpr(args[0], 'limit');
        final varName = _expectVarName(args[1], 'limit');
        final point = _expectExpr(args[2], 'limit');
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
      params: const ['expr', 'var', 'lower', 'upper'],
      doc: 'Evaluates closed-form symbolic summation (Faulhaber, geometric, Gosper, telescoping).',
      examples: const ['sum(k^2, k, 1, n)', 'sum(1 / (k * (k + 1)), k, 1, n)'],
      rpnLabel: '∑',
      rpnArity: 4,
      appliesTo: (_) => false,
      chipLabel: 'Sum',
      buildChipCall: (id, v) => 'sum(r[$id], ${_primaryVar(v) ?? 'k'}, 1, n)',
      run: (args, ctx) {
        _checkArity('sum', args, 4, 4);
        final expr = _expectExpr(args[0], 'sum');
        final varName = _expectVarName(args[1], 'sum');
        final lower = _expectExpr(args[2], 'sum');
        final upper = _expectExpr(args[3], 'sum');
        return ExprValue(expr.sum(varName, lower, upper));
      },
    ),
    Command(
      name: 'product',
      category: CommandCategory.calculus,
      signature: 'product(expr, var, lower, upper)',
      params: const ['expr', 'var', 'lower', 'upper'],
      doc: 'Evaluates closed-form symbolic products.',
      examples: const ['product(k, k, 1, n)', 'product((k + 1) / k, k, 1, n)'],
      rpnLabel: '∏',
      rpnArity: 4,
      appliesTo: (_) => false,
      chipLabel: 'Product',
      buildChipCall: (id, v) =>
          'product(r[$id], ${_primaryVar(v) ?? 'k'}, 1, n)',
      run: (args, ctx) {
        _checkArity('product', args, 4, 4);
        final expr = _expectExpr(args[0], 'product');
        final varName = _expectVarName(args[1], 'product');
        final lower = _expectExpr(args[2], 'product');
        final upper = _expectExpr(args[3], 'product');
        return ExprValue(expr.product(varName, lower, upper));
      },
    ),
    Command(
      name: 'gradient',
      category: CommandCategory.calculus,
      signature: 'gradient(expr, [vars])',
      params: const ['expr', '[vars]'],
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
        _checkArity('gradient', args, 1, 2);
        final expr = _expectExpr(args[0], 'gradient');
        final vars = args.length == 2
            ? _extractVarNameList(args[1], 'gradient')
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
      params: const ['expr', '[vars]'],
      doc:
          'Computes the symbolic Hessian matrix of second partial derivatives.',
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
        _checkArity('hessian', args, 1, 2);
        final expr = _expectExpr(args[0], 'hessian');
        final vars = args.length == 2
            ? _extractVarNameList(args[1], 'hessian')
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
      params: const ['[exprs]', '[vars]'],
      doc: 'Computes the symbolic Jacobian matrix of a vector-valued function.',
      examples: const ['jacobian([r * cos(t), r * sin(t)], [r, t])'],
      rpnLabel: 'Jacobian',
      rpnArity: 2,
      appliesTo: (v) => v is VectorValue && !v.isExact == false,
      chipLabel: 'Jacobian',
      buildChipCall: (id, _) => 'jacobian(r[$id])',
      run: (args, ctx) {
        _checkArity('jacobian', args, 1, 2);
        final exprs = _extractExprList(args[0], 'jacobian');
        final vars = args.length == 2
            ? _extractVarNameList(args[1], 'jacobian')
            : _inferSystemVariables(exprs);
        return MatrixValue(exprs.jacobian(vars));
      },
    ),

    // =========================================================================
    // 3. LINEAR ALGEBRA
    // =========================================================================
    Command(
      name: 'det',
      category: CommandCategory.linear,
      signature: 'det(A)',
      params: const ['A'],
      doc: 'Computes the exact symbolic determinant using Bareiss elimination.',
      examples: const [
        'det([[a, b], [c, d]])',
        'det([[1, 2, 3], [0, 4, 5], [1, 0, 6]])',
      ],
      rpnLabel: 'Det',
      rpnArity: 1,
      appliesTo: (v) => v is MatrixValue && v.matrix.isSquare,
      chipLabel: 'det',
      buildChipCall: (id, _) => 'det(r[$id])',
      run: (args, ctx) {
        _checkArity('det', args, 1, 1);
        final m = _expectMatrix(args[0], 'det');
        return ExprValue(m.determinant());
      },
    ),
    Command(
      name: 'inv',
      category: CommandCategory.linear,
      signature: 'inv(A)',
      params: const ['A'],
      doc: 'Computes the exact symbolic matrix inverse A⁻¹.',
      examples: const ['inv([[a, b], [c, d]])', 'inv([[2, 1], [1, 1]])'],
      rpnLabel: 'Inv',
      rpnArity: 1,
      appliesTo: (v) => v is MatrixValue && v.matrix.isSquare,
      chipLabel: 'inv',
      buildChipCall: (id, _) => 'inv(r[$id])',
      run: (args, ctx) {
        _checkArity('inv', args, 1, 1);
        final m = _expectMatrix(args[0], 'inv');
        final inv = m.inverse();
        if (inv == null) {
          throw StateError('Matrix is singular (determinant is 0).');
        }
        return MatrixValue(inv);
      },
    ),
    Command(
      name: 'transpose',
      category: CommandCategory.linear,
      signature: 'transpose(A)',
      params: const ['A'],
      doc: 'Returns the matrix transpose Aᵀ (also available via postfix A\').',
      examples: const [
        'transpose([[1, 2, 3], [4, 5, 6]])',
        '[[1, 2], [3, 4]]\'',
      ],
      rpnLabel: 'Transpose',
      rpnArity: 1,
      appliesTo: (v) => v is MatrixValue,
      chipLabel: 'Aᵀ',
      buildChipCall: (id, _) => 'transpose(r[$id])',
      run: (args, ctx) {
        _checkArity('transpose', args, 1, 1);
        final m = _expectMatrix(args[0], 'transpose');
        final rows = [
          for (var c = 0; c < m.colCount; c++)
            [for (var r = 0; r < m.rowCount; r++) m.getUnchecked(r, c)],
        ];
        return MatrixValue(Matrix<Expr>.fromRows(rows, type: exprDataType));
      },
    ),
    Command(
      name: 'trace',
      category: CommandCategory.linear,
      signature: 'trace(A)',
      params: const ['A'],
      doc: 'Computes the sum of diagonal elements of a square matrix.',
      examples: const ['trace([[a, b], [c, d]])'],
      rpnLabel: 'Trace',
      rpnArity: 1,
      appliesTo: (v) => v is MatrixValue && v.matrix.isSquare,
      chipLabel: 'trace',
      buildChipCall: (id, _) => 'trace(r[$id])',
      run: (args, ctx) {
        _checkArity('trace', args, 1, 1);
        final m = _expectMatrix(args[0], 'trace');
        if (!m.isSquare) {
          throw ArgumentError('trace requires a square matrix.');
        }
        var sum = IntegerNumber.zero as Expr;
        for (var i = 0; i < m.rowCount; i++) {
          sum = (sum + m.getUnchecked(i, i)).simplify();
        }
        return ExprValue(sum);
      },
    ),
    Command(
      name: 'charpoly',
      category: CommandCategory.linear,
      signature: 'charpoly(A, [lambda])',
      params: const ['A', '[lambda]'],
      doc: 'Computes the characteristic polynomial det(λI - A).',
      examples: const ['charpoly([[2, 1], [1, 2]], x)'],
      rpnLabel: 'CharPoly',
      rpnArity: 1,
      appliesTo: (v) => v is MatrixValue && v.matrix.isSquare,
      chipLabel: 'charpoly',
      buildChipCall: (id, _) => 'charpoly(r[$id], x)',
      run: (args, ctx) {
        _checkArity('charpoly', args, 1, 2);
        final m = _expectMatrix(args[0], 'charpoly');
        final v = args.length == 2 ? _expectVarName(args[1], 'charpoly') : 'x';
        return ExprValue(m.characteristicPolynomial(v));
      },
    ),
    Command(
      name: 'rank',
      category: CommandCategory.linear,
      signature: 'rank(A)',
      params: const ['A'],
      doc: 'Computes the exact algebraic rank of a matrix.',
      examples: const ['rank([[1, 2, 3], [2, 4, 6], [1, 1, 1]])'],
      rpnLabel: 'Rank',
      rpnArity: 1,
      appliesTo: (_) => false,
      chipLabel: 'rank',
      buildChipCall: (id, _) => 'rank(r[$id])',
      run: (args, ctx) {
        _checkArity('rank', args, 1, 1);
        final m = _expectMatrix(args[0], 'rank');
        return ExprValue(IntegerNumber.of(m.rank()));
      },
    ),
    Command(
      name: 'rref',
      category: CommandCategory.linear,
      signature: 'rref(A)',
      params: const ['A'],
      doc: 'Computes the Reduced Row Echelon Form (RREF) of a matrix.',
      examples: const [
        'rref([[1, 2, -1, -4], [2, 3, -1, -11], [-2, 0, -3, 22]])',
      ],
      rpnLabel: 'RREF',
      rpnArity: 1,
      appliesTo: (v) => v is MatrixValue,
      chipLabel: 'rref',
      buildChipCall: (id, _) => 'rref(r[$id])',
      run: (args, ctx) {
        _checkArity('rref', args, 1, 1);
        final m = _expectMatrix(args[0], 'rref');
        return MatrixValue(m.rowEchelon());
      },
    ),
    Command(
      name: 'nullspace',
      category: CommandCategory.linear,
      signature: 'nullspace(A)',
      params: const ['A'],
      doc: 'Computes a basis of vectors for the right nullspace ker(A).',
      examples: const ['nullspace([[1, 2, 3], [4, 5, 6], [7, 8, 9]])'],
      rpnLabel: 'NullSpace',
      rpnArity: 1,
      appliesTo: (_) => false,
      chipLabel: 'nullspace',
      buildChipCall: (id, _) => 'nullspace(r[$id])',
      run: (args, ctx) {
        _checkArity('nullspace', args, 1, 1);
        final m = _expectMatrix(args[0], 'nullspace');
        final basis = m.nullSpace();
        return ListValue([for (final v in basis) VectorValue(v)]);
      },
    ),
    Command(
      name: 'eigenvals',
      category: CommandCategory.linear,
      signature: 'eigenvals(A)',
      params: const ['A'],
      doc: 'Computes the symbolic eigenvalues of a square matrix.',
      examples: const [
        'eigenvals([[2, 1], [1, 2]])',
        'eigenvals([[0, -1], [1, 0]])',
      ],
      rpnLabel: 'Eigenvalues',
      rpnArity: 1,
      appliesTo: (v) => v is MatrixValue && v.matrix.isSquare,
      chipLabel: 'eigen',
      buildChipCall: (id, _) => 'eigenvals(r[$id])',
      run: (args, ctx) {
        _checkArity('eigenvals', args, 1, 1);
        final m = _expectMatrix(args[0], 'eigenvals');
        final vals = m.eigenvalues();
        return ListValue([for (final e in vals) ExprValue(e)]);
      },
    ),
    Command(
      name: 'eigenvects',
      category: CommandCategory.linear,
      signature: 'eigenvects(A)',
      params: const ['A'],
      doc: 'Computes eigenvalues and basis eigenvectors of a square matrix.',
      examples: const ['eigenvects([[2, 1], [1, 2]])'],
      rpnLabel: 'Eigenvectors',
      rpnArity: 1,
      appliesTo: (_) => false,
      chipLabel: 'eigenvects',
      buildChipCall: (id, _) => 'eigenvects(r[$id])',
      run: (args, ctx) {
        _checkArity('eigenvects', args, 1, 1);
        final m = _expectMatrix(args[0], 'eigenvects');
        final pairs = m.eigenvectors();
        return ListValue([
          for (final p in pairs)
            ListValue([
              ExprValue(p.eigenvalue),
              ExprValue(IntegerNumber.of(p.algebraicMultiplicity)),
              ListValue([for (final v in p.eigenvectors) VectorValue(v)]),
            ]),
        ]);
      },
    ),
    Command(
      name: 'identity',
      category: CommandCategory.linear,
      signature: 'identity(n)',
      params: const ['n'],
      doc: 'Creates an n × n symbolic identity matrix.',
      examples: const ['identity(3)'],
      rpnLabel: 'Identity',
      rpnArity: 1,
      appliesTo: (_) => false,
      chipLabel: 'identity',
      buildChipCall: (id, _) => 'identity(3)',
      run: (args, ctx) {
        _checkArity('identity', args, 1, 1);
        final n = _expectInt(args[0], 'identity');
        if (n < 1 || n > 32) {
          throw ArgumentError('identity dimension must be between 1 and 32.');
        }
        return MatrixValue(Matrix<Expr>.identity(n, type: exprDataType));
      },
    ),
    Command(
      name: 'zeros',
      category: CommandCategory.linear,
      signature: 'zeros(m, [n])',
      params: const ['m', '[n]'],
      doc: 'Creates an m × n matrix (or m-vector) of zeros.',
      examples: const ['zeros(2, 3)', 'zeros(4)'],
      rpnLabel: 'Zeros',
      rpnArity: 2,
      appliesTo: (_) => false,
      chipLabel: 'zeros',
      buildChipCall: (id, _) => 'zeros(3, 3)',
      run: (args, ctx) {
        _checkArity('zeros', args, 1, 2);
        final m = _expectInt(args[0], 'zeros');
        if (args.length == 1) {
          return VectorValue(
            Vector<Expr>.generate(
              m,
              (_) => IntegerNumber.zero,
              type: exprDataType,
            ),
          );
        }
        final n = _expectInt(args[1], 'zeros');
        return MatrixValue(
          Matrix<Expr>.generate(
            m,
            n,
            (_, _) => IntegerNumber.zero,
            type: exprDataType,
          ),
        );
      },
    ),
    Command(
      name: 'dot',
      category: CommandCategory.linear,
      signature: 'dot(u, v)',
      params: const ['u', 'v'],
      doc: 'Computes the symbolic dot product u · v of two vectors.',
      examples: const ['dot([1, x, x^2], [2, 3, 4])'],
      rpnLabel: 'Dot',
      rpnArity: 2,
      appliesTo: (_) => false,
      chipLabel: 'dot',
      buildChipCall: (id, _) => 'dot(r[$id], r[$id])',
      run: (args, ctx) {
        _checkArity('dot', args, 2, 2);
        final u = _expectVector(args[0], 'dot');
        final v = _expectVector(args[1], 'dot');
        if (u.length != v.length) {
          throw ArgumentError(
            'dot requires vectors of equal length (${u.length} != ${v.length}).',
          );
        }
        var sum = IntegerNumber.zero as Expr;
        for (var i = 0; i < u.length; i++) {
          sum = (sum + u.getUnchecked(i) * v.getUnchecked(i)).simplify();
        }
        return ExprValue(sum);
      },
    ),
    Command(
      name: 'cross',
      category: CommandCategory.linear,
      signature: 'cross(u, v)',
      params: const ['u', 'v'],
      doc: 'Computes the 3D vector cross product u × v.',
      examples: const ['cross([1, 0, 0], [0, 1, 0])'],
      rpnLabel: 'Cross',
      rpnArity: 2,
      appliesTo: (_) => false,
      chipLabel: 'cross',
      buildChipCall: (id, _) => 'cross(r[$id], r[$id])',
      run: (args, ctx) {
        _checkArity('cross', args, 2, 2);
        final u = _expectVector(args[0], 'cross');
        final v = _expectVector(args[1], 'cross');
        if (u.length != 3 || v.length != 3) {
          throw ArgumentError('cross product is only defined for 3D vectors.');
        }
        final c0 = (u[1] * v[2] - u[2] * v[1]).simplify();
        final c1 = (u[2] * v[0] - u[0] * v[2]).simplify();
        final c2 = (u[0] * v[1] - u[1] * v[0]).simplify();
        return VectorValue(
          Vector<Expr>.fromList([c0, c1, c2], type: exprDataType),
        );
      },
    ),
    Command(
      name: 'norm',
      category: CommandCategory.linear,
      signature: 'norm(v)',
      params: const ['v'],
      doc: 'Computes the Euclidean norm ||v||₂ of a vector or Frobenius norm of a matrix.',
      examples: const ['norm([3, 4])', 'norm([x, y, z])'],
      rpnLabel: 'Norm',
      rpnArity: 1,
      appliesTo: (v) => v is VectorValue,
      chipLabel: '||v||',
      buildChipCall: (id, _) => 'norm(r[$id])',
      run: (args, ctx) {
        _checkArity('norm', args, 1, 1);
        if (args[0] case VectorValue(:final vector)) {
          var sumSq = IntegerNumber.zero as Expr;
          for (var i = 0; i < vector.length; i++) {
            final item = vector.getUnchecked(i);
            sumSq = (sumSq + item * item).simplify();
          }
          return ExprValue(
            Pow(
              sumSq,
              FractionNumber.half,
            ).simplify(assumptions: ctx.assumptions),
          );
        }
        if (args[0] case MatrixValue(:final matrix)) {
          var sumSq = IntegerNumber.zero as Expr;
          for (var r = 0; r < matrix.rowCount; r++) {
            for (var c = 0; c < matrix.colCount; c++) {
              final item = matrix.getUnchecked(r, c);
              sumSq = (sumSq + item * item).simplify();
            }
          }
          return ExprValue(
            Pow(
              sumSq,
              FractionNumber.half,
            ).simplify(assumptions: ctx.assumptions),
          );
        }
        final e = _expectExpr(args[0], 'norm');
        return ExprValue(Abs(e).simplify(assumptions: ctx.assumptions));
      },
    ),

    // =========================================================================
    // 4. COMPLEX
    // =========================================================================
    Command(
      name: 're',
      category: CommandCategory.complex,
      signature: 're(z)',
      params: const ['z'],
      doc: 'Extracts the real part Re(z) of a complex expression.',
      examples: const ['re(3 + 4 * i)', 're(exp(i * x))'],
      rpnLabel: 'Re',
      rpnArity: 1,
      appliesTo: (v) => v is ExprValue && _hasImaginary(v.expr),
      chipLabel: 'Re',
      buildChipCall: (id, _) => 're(r[$id])',
      run: (args, ctx) {
        _checkArity('re', args, 1, 1);
        return _liftUnary(
          args[0],
          (e) => Re(e).simplify(assumptions: ctx.assumptions),
        );
      },
    ),
    Command(
      name: 'im',
      category: CommandCategory.complex,
      signature: 'im(z)',
      params: const ['z'],
      doc: 'Extracts the imaginary part Im(z) of a complex expression.',
      examples: const ['im(3 + 4 * i)', 'im(exp(i * x))'],
      rpnLabel: 'Im',
      rpnArity: 1,
      appliesTo: (v) => v is ExprValue && _hasImaginary(v.expr),
      chipLabel: 'Im',
      buildChipCall: (id, _) => 'im(r[$id])',
      run: (args, ctx) {
        _checkArity('im', args, 1, 1);
        return _liftUnary(
          args[0],
          (e) => Im(e).simplify(assumptions: ctx.assumptions),
        );
      },
    ),
    Command(
      name: 'conj',
      category: CommandCategory.complex,
      signature: 'conj(z)',
      params: const ['z'],
      doc: 'Computes the complex conjugate z* of an expression.',
      examples: const ['conj(3 + 4 * i)', 'conj(a + b * i)'],
      rpnLabel: 'Conj',
      rpnArity: 1,
      appliesTo: (v) => v is ExprValue && _hasImaginary(v.expr),
      chipLabel: 'conj',
      buildChipCall: (id, _) => 'conj(r[$id])',
      run: (args, ctx) {
        _checkArity('conj', args, 1, 1);
        return _liftUnary(
          args[0],
          (e) => Conjugate(e).simplify(assumptions: ctx.assumptions),
        );
      },
    ),
    Command(
      name: 'arg',
      category: CommandCategory.complex,
      signature: 'arg(z)',
      params: const ['z'],
      doc: 'Computes the complex phase angle arg(z) ∈ (-π, π].',
      examples: const ['arg(1 + i)', 'arg(-1)'],
      rpnLabel: 'Arg',
      rpnArity: 1,
      appliesTo: (v) => v is ExprValue && _hasImaginary(v.expr),
      chipLabel: 'arg',
      buildChipCall: (id, _) => 'arg(r[$id])',
      run: (args, ctx) {
        _checkArity('arg', args, 1, 1);
        return _liftUnary(
          args[0],
          (e) => Arg(e).simplify(assumptions: ctx.assumptions),
        );
      },
    ),
    Command(
      name: 'abs',
      category: CommandCategory.complex,
      signature: 'abs(z)',
      params: const ['z'],
      doc: 'Computes the absolute value or complex modulus |z|.',
      examples: const ['abs(3 + 4 * i)', 'abs(-42)'],
      rpnLabel: 'Abs',
      rpnArity: 1,
      appliesTo: (_) => false,
      chipLabel: '|z|',
      buildChipCall: (id, _) => 'abs(r[$id])',
      run: (args, ctx) {
        _checkArity('abs', args, 1, 1);
        return _liftUnary(
          args[0],
          (e) => Abs(e).simplify(assumptions: ctx.assumptions),
        );
      },
    ),
    Command(
      name: 'polar',
      category: CommandCategory.complex,
      signature: 'polar(z)',
      params: const ['z'],
      doc: 'Rewrites a complex expression in polar form r * e^(i * θ).',
      examples: const ['polar(1 + i)', 'polar(-2 * i)'],
      rpnLabel: 'Polar',
      rpnArity: 1,
      appliesTo: (v) => v is ExprValue && _hasImaginary(v.expr),
      chipLabel: 'Polar',
      buildChipCall: (id, _) => 'polar(r[$id])',
      run: (args, ctx) {
        _checkArity('polar', args, 1, 1);
        return _liftUnary(args[0], (e) => _toPolarExpr(e, ctx.assumptions));
      },
    ),
    Command(
      name: 'rect',
      category: CommandCategory.complex,
      signature: 'rect(z)',
      params: const ['z'],
      doc: 'Rewrites a complex expression in rectangular form Re(z) + i * Im(z).',
      examples: const ['rect(exp(i * pi / 3))', 'rect((1 + i)^4)'],
      rpnLabel: 'Rect',
      rpnArity: 1,
      appliesTo: (_) => false,
      chipLabel: 'Rect',
      buildChipCall: (id, _) => 'rect(r[$id])',
      run: (args, ctx) {
        _checkArity('rect', args, 1, 1);
        return _liftUnary(args[0], (e) {
          final re = Re(e).simplify(assumptions: ctx.assumptions);
          final im = Im(e).simplify(assumptions: ctx.assumptions);
          return (re + ComplexNumber.i * im).simplify(
            assumptions: ctx.assumptions,
          );
        });
      },
    ),

    // =========================================================================
    // 5. NUMBERS
    // =========================================================================
    Command(
      name: 'approx',
      category: CommandCategory.numbers,
      signature: 'approx(expr, [digits])',
      params: const ['expr', '[digits]'],
      doc:
          'Evaluates closed constant subexpressions to floating-point numbers.',
      examples: const ['approx(sqrt(2) + pi)', 'approx(sin(1), 8)'],
      rpnLabel: 'Approx',
      rpnArity: 1,
      appliesTo: (v) =>
          v.isExact && !(v is ExprValue && v.expr is IntegerNumber),
      chipLabel: '≈',
      buildChipCall: (id, _) => 'approx(r[$id])',
      run: (args, ctx) {
        _checkArity('approx', args, 1, 2);
        return _liftUnary(
          args[0],
          (e) => e.approximate(),
          onMatrix: (m) => m.approximate(),
          onVector: (v) => v.approximate(),
        );
      },
    ),
    Command(
      name: 'exact',
      category: CommandCategory.numbers,
      signature: 'exact(expr)',
      params: const ['expr'],
      doc: 'Reconstructs exact rationals from floating-point numbers via continued fractions.',
      examples: const ['exact(0.333333333333)', 'exact(0.75 * x + 0.125)'],
      rpnLabel: 'Exact',
      rpnArity: 1,
      appliesTo: (v) => !v.isExact,
      chipLabel: 'Exact',
      buildChipCall: (id, _) => 'exact(r[$id])',
      run: (args, ctx) {
        _checkArity('exact', args, 1, 1);
        return _liftUnary(
          args[0],
          (e) => e.rationalize(),
          onMatrix: (m) => m.rationalize(),
          onVector: (v) => v.rationalize(),
        );
      },
    ),
    Command(
      name: 'gcd',
      category: CommandCategory.numbers,
      signature: 'gcd(a, b, ...)',
      params: const ['a', 'b'],
      doc: 'Computes the greatest common divisor of integers or rationals.',
      examples: const ['gcd(84, 126)', 'gcd(12, 18, 30)'],
      rpnLabel: 'GCD',
      rpnArity: 2,
      appliesTo: (_) => false,
      chipLabel: 'gcd',
      buildChipCall: (id, _) => 'gcd(r[$id], 1)',
      run: (args, ctx) {
        _checkArity('gcd', args, 2, 16);
        final exprArgs = [for (final a in args) _expectExpr(a, 'gcd')];
        return ExprValue(
          ExprSyntax.standardVariadicFunctions['gcd']!(exprArgs).simplify(),
        );
      },
    ),
    Command(
      name: 'lcm',
      category: CommandCategory.numbers,
      signature: 'lcm(a, b, ...)',
      params: const ['a', 'b'],
      doc: 'Computes the least common multiple of integers or rationals.',
      examples: const ['lcm(12, 18)', 'lcm(4, 6, 15)'],
      rpnLabel: 'LCM',
      rpnArity: 2,
      appliesTo: (_) => false,
      chipLabel: 'lcm',
      buildChipCall: (id, _) => 'lcm(r[$id], 1)',
      run: (args, ctx) {
        _checkArity('lcm', args, 2, 16);
        final exprArgs = [for (final a in args) _expectExpr(a, 'lcm')];
        return ExprValue(
          ExprSyntax.standardVariadicFunctions['lcm']!(exprArgs).simplify(),
        );
      },
    ),
    Command(
      name: 'mod',
      category: CommandCategory.numbers,
      signature: 'mod(a, b)',
      params: const ['a', 'b'],
      doc: 'Computes the modulo remainder a mod b.',
      examples: const ['mod(17, 5)', 'mod(-7, 3)'],
      rpnLabel: 'MOD',
      rpnArity: 2,
      appliesTo: (_) => false,
      chipLabel: 'mod',
      buildChipCall: (id, _) => 'mod(r[$id], 2)',
      run: (args, ctx) {
        _checkArity('mod', args, 2, 2);
        final a = _expectExpr(args[0], 'mod');
        final b = _expectExpr(args[1], 'mod');
        return ExprValue(Mod(a, b).simplify());
      },
    ),
    Command(
      name: 'isprime',
      category: CommandCategory.numbers,
      signature: 'isprime(n)',
      params: const ['n'],
      doc:
          'Tests whether integer n is prime (returns 1 if prime, 0 otherwise).',
      examples: const ['isprime(97)', 'isprime(100)'],
      rpnLabel: 'IsPrime',
      rpnArity: 1,
      appliesTo: (v) => v is ExprValue && v.expr is IntegerNumber,
      chipLabel: 'Prime?',
      buildChipCall: (id, _) => 'isprime(r[$id])',
      run: (args, ctx) {
        _checkArity('isprime', args, 1, 1);
        final e = _expectExpr(args[0], 'isprime').simplify();
        if (e is IntegerNumber) {
          return ExprValue(e.isPrime ? IntegerNumber.one : IntegerNumber.zero);
        }
        throw ArgumentError('isprime expects an integer argument, got: $e');
      },
    ),
    Command(
      name: 'factorial',
      category: CommandCategory.numbers,
      signature: 'factorial(n)',
      params: const ['n'],
      doc: 'Computes the exact factorial n!.',
      examples: const ['factorial(30)', '25!'],
      rpnLabel: 'n!',
      rpnArity: 1,
      appliesTo: (_) => false,
      chipLabel: 'n!',
      buildChipCall: (id, _) => 'factorial(r[$id])',
      run: (args, ctx) {
        _checkArity('factorial', args, 1, 1);
        return _liftUnary(args[0], (e) => Factorial(e).simplify());
      },
    ),
    Command(
      name: 'binomial',
      category: CommandCategory.numbers,
      signature: 'binomial(n, k)',
      params: const ['n', 'k'],
      doc: 'Computes the binomial coefficient C(n, k).',
      examples: const ['binomial(10, 3)', 'binomial(n, 2)'],
      rpnLabel: 'nCr',
      rpnArity: 2,
      appliesTo: (_) => false,
      chipLabel: 'nCr',
      buildChipCall: (id, _) => 'binomial(r[$id], 2)',
      run: (args, ctx) {
        _checkArity('binomial', args, 2, 2);
        final a = _expectExpr(args[0], 'binomial');
        final b = _expectExpr(args[1], 'binomial');
        return ExprValue(Binomial(a, b).simplify());
      },
    ),
    Command(
      name: 'floor',
      category: CommandCategory.numbers,
      signature: 'floor(x)',
      params: const ['x'],
      doc: 'Rounds down to the greatest integer ≤ x.',
      examples: const ['floor(7 / 3)', 'floor(pi)'],
      rpnLabel: 'Floor',
      rpnArity: 1,
      appliesTo: (_) => false,
      chipLabel: 'floor',
      buildChipCall: (id, _) => 'floor(r[$id])',
      run: (args, ctx) {
        _checkArity('floor', args, 1, 1);
        return _liftUnary(args[0], (e) => Floor(e).simplify());
      },
    ),
    Command(
      name: 'ceil',
      category: CommandCategory.numbers,
      signature: 'ceil(x)',
      params: const ['x'],
      doc: 'Rounds up to the least integer ≥ x.',
      examples: const ['ceil(7 / 3)', 'ceil(pi)'],
      rpnLabel: 'Ceil',
      rpnArity: 1,
      appliesTo: (_) => false,
      chipLabel: 'ceil',
      buildChipCall: (id, _) => 'ceil(r[$id])',
      run: (args, ctx) {
        _checkArity('ceil', args, 1, 1);
        return _liftUnary(args[0], (e) => Ceil(e).simplify());
      },
    ),
    Command(
      name: 'round',
      category: CommandCategory.numbers,
      signature: 'round(x)',
      params: const ['x'],
      doc: 'Rounds to the nearest integer.',
      examples: const ['round(7 / 3)', 'round(pi)'],
      rpnLabel: 'Round',
      rpnArity: 1,
      appliesTo: (_) => false,
      chipLabel: 'round',
      buildChipCall: (id, _) => 'round(r[$id])',
      run: (args, ctx) {
        _checkArity('round', args, 1, 1);
        return _liftUnary(args[0], (e) => Round(e).simplify());
      },
    ),

    // =========================================================================
    // 6. NUMERIC
    // =========================================================================
    Command(
      name: 'nintegrate',
      category: CommandCategory.numeric,
      signature: 'nintegrate(expr, [var], [a], [b])',
      params: const ['expr', '[var]', '[a]', '[b]'],
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
        final vName = _primaryVar(v) ?? 'x';
        return 'nintegrate(r[$id], $vName, 0, 1)';
      },
      run: (args, ctx) {
        _checkArity('nintegrate', args, 1, 4);
        final first = _expectExpr(args[0], 'nintegrate');
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
        final varName = _expectVarName(args[1], 'nintegrate');
        final a = _expectDouble(args[2], 'nintegrate');
        final b = _expectDouble(args[3], 'nintegrate');
        final fn = integrand.toFunction1D(varName);
        final val = numeric.integrate(fn, a, b);
        return ExprValue(RealNumber.fromDouble(val));
      },
    ),
    Command(
      name: 'nsolve',
      category: CommandCategory.numeric,
      signature: 'nsolve(eq, var, x0, [x1])',
      params: const ['eq', 'var', 'x0', '[x1]'],
      doc: 'Finds a numerical root near x0 (or bracketed in [x0, x1]).',
      examples: const [
        'nsolve(cos(x) = x, x, 0.5)',
        'nsolve(x^5 - x - 1, x, 1, 2)',
      ],
      rpnLabel: 'NSolve',
      rpnArity: 3,
      appliesTo: (_) => false,
      chipLabel: 'NSolve',
      buildChipCall: (id, v) => 'nsolve(r[$id], ${_primaryVar(v) ?? 'x'}, 1)',
      run: (args, ctx) {
        _checkArity('nsolve', args, 3, 4);
        var expr = _expectExpr(args[0], 'nsolve');
        if (expr case Equal(:final left, :final right)) {
          expr = left - right;
        }
        final varName = _expectVarName(args[1], 'nsolve');
        final x0 = _expectDouble(args[2], 'nsolve');
        final x1 = args.length == 4 ? _expectDouble(args[3], 'nsolve') : null;
        final fn = expr.toFunction1D(varName);
        final root = numeric.solve(fn, x0, b: x1);
        return ExprValue(RealNumber.fromDouble(root));
      },
    ),
    Command(
      name: 'nminimize',
      category: CommandCategory.numeric,
      signature: 'nminimize(expr, var, x0, [x1])',
      params: const ['expr', 'var', 'x0', '[x1]'],
      doc: 'Finds a numerical local minimum of expr.',
      examples: const ['nminimize(x^4 - 3*x^2 + x, x, -2, 0)'],
      rpnLabel: 'NMin',
      rpnArity: 3,
      appliesTo: (_) => false,
      chipLabel: 'NMin',
      buildChipCall: (id, v) =>
          'nminimize(r[$id], ${_primaryVar(v) ?? 'x'}, -2, 2)',
      run: (args, ctx) {
        _checkArity('nminimize', args, 3, 4);
        final expr = _expectExpr(args[0], 'nminimize');
        final varName = _expectVarName(args[1], 'nminimize');
        final a = _expectDouble(args[2], 'nminimize');
        final b = args.length == 4
            ? _expectDouble(args[3], 'nminimize')
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
      params: const ['expr', 'var', 'x0', '[order]'],
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
          'nderivative(r[$id], ${_primaryVar(v) ?? 'x'}, 1)',
      run: (args, ctx) {
        _checkArity('nderivative', args, 3, 4);
        final expr = _expectExpr(args[0], 'nderivative');
        final varName = _expectVarName(args[1], 'nderivative');
        final x0 = _expectDouble(args[2], 'nderivative');
        final order = args.length == 4 ? _expectInt(args[3], 'nderivative') : 1;
        final fn = expr.toFunction1D(varName);
        final val = numeric.derivative(fn, x0, order: order);
        return ExprValue(RealNumber.fromDouble(val));
      },
    ),

    // =========================================================================
    // 7. PLOTTING
    // =========================================================================
    Command(
      name: 'plot',
      category: CommandCategory.plot,
      signature: 'plot(expr, [var], [a, b])',
      params: const ['expr', '[var]', '[a]', '[b]'],
      doc: 'Plots one or more expressions over [a, b] with adaptive sampling.',
      examples: const [
        'plot(sin(x) / x, x, -10, 10)',
        'plot([sin(x), cos(x)], x, -pi, pi)',
        'plot(tan(x), x, -5, 5)',
      ],
      rpnLabel: 'Plot',
      rpnArity: 1,
      appliesTo: (v) =>
          (v is ExprValue &&
              !v.isEquation &&
              v.expr.freeVariables.length <= 1) ||
          (v is SeriesValue),
      chipLabel: 'Plot',
      buildChipCall: (id, v) => 'plot(r[$id], ${_primaryVar(v) ?? 'x'}, -5, 5)',
      run: (args, ctx) {
        _checkArity('plot', args, 1, 4);
        final exprs = _extractPlotExpressions(args[0]);
        final inferredVar = _inferPlotVariable(exprs);
        final varName = args.length >= 2
            ? _expectVarName(args[1], 'plot')
            : inferredVar;
        final a = args.length >= 3 ? _expectDouble(args[2], 'plot') : -5.0;
        final b = args.length >= 4 ? _expectDouble(args[3], 'plot') : 5.0;
        return buildPlotValue(
          exprs,
          varName,
          a,
          b,
          angleMode: ctx.settings.angleMode,
        );
      },
    ),

    // =========================================================================
    // 8. SESSION
    // =========================================================================
    Command(
      name: 'clear',
      category: CommandCategory.session,
      signature: 'clear(name, ...)',
      params: const ['name'],
      doc: 'Unbinds one or more assigned variables or user functions.',
      examples: const ['clear(a)', 'clear(f)'],
      rpnLabel: 'Delete',
      rpnArity: 1,
      appliesTo: (_) => false,
      chipLabel: 'Clear',
      buildChipCall: (id, _) => 'clear(a)',
      run: (args, ctx) {
        _checkArity('clear', args, 1, 16);
        final cleared = <String>[];
        for (final arg in args) {
          final name = _expectVarName(arg, 'clear');
          ctx.environment.clearSymbol(name);
          cleared.add(name);
          ctx.session.markDependentsStale(changedSymbols: {name});
        }
        return InfoValue('Cleared: ${cleared.join(', ')}');
      },
    ),
    Command(
      name: 'clearall',
      category: CommandCategory.session,
      signature: 'clearall()',
      params: const [],
      doc: 'Unbinds all user variables and functions.',
      examples: const ['clearall()'],
      rpnLabel: 'ClearAll',
      rpnArity: 0,
      appliesTo: (_) => false,
      chipLabel: 'Clear All',
      buildChipCall: (_, _) => 'clearall()',
      run: (args, ctx) {
        final names = {
          ...ctx.environment.variables.keys,
          ...ctx.environment.functions.keys,
        };
        ctx.environment.clearAll();
        if (names.isNotEmpty) {
          ctx.session.markDependentsStale(changedSymbols: names);
        }
        return const InfoValue('All variables and functions cleared.');
      },
    ),
    Command(
      name: 'vars',
      category: CommandCategory.session,
      signature: 'vars()',
      params: const [],
      doc: 'Lists all currently assigned variables and user functions.',
      examples: const ['vars()'],
      rpnLabel: 'Vars',
      rpnArity: 0,
      appliesTo: (_) => false,
      chipLabel: 'Vars',
      buildChipCall: (_, _) => 'vars()',
      run: (args, ctx) {
        final vars = ctx.environment.variables;
        final fns = ctx.environment.functions;
        if (vars.isEmpty && fns.isEmpty) {
          return const InfoValue('No variables or functions defined.');
        }
        final parts = <String>[
          for (final e in vars.entries)
            '${e.key} := ${e.value.toCanonicalText()}',
          for (final f in fns.values) '${f.signature} := ${f.body}',
        ];
        return InfoValue(parts.join('; '), title: 'Environment');
      },
    ),
    Command(
      name: 'help',
      category: CommandCategory.session,
      signature: 'help([command])',
      params: const ['[command]'],
      doc: 'Displays signature, documentation, and examples for a command.',
      examples: const ['help(integrate)', 'help(solve)'],
      rpnLabel: 'Help',
      rpnArity: 1,
      appliesTo: (_) => false,
      chipLabel: 'Help',
      buildChipCall: (_, _) => 'help()',
      run: (args, ctx) {
        if (args.isEmpty) {
          final names = all.map((c) => c.name).join(', ');
          return InfoValue('Available commands: $names', title: 'Help');
        }
        final name = _expectVarName(args[0], 'help').toLowerCase();
        final cmd = byName[name];
        if (cmd == null) {
          return InfoValue(
            'Unknown command "$name". Type help() to list all commands.',
          );
        }
        final ex = cmd.examples.isNotEmpty
            ? ' | Examples: ${cmd.examples.join(' ; ')}'
            : '';
        return InfoValue('${cmd.signature} — ${cmd.doc}$ex', title: cmd.name);
      },
    ),
  ];

  // ===========================================================================
  // Helpers
  // ===========================================================================

  static void _checkArity(
    String name,
    List<CalcValue> args,
    int minArgs,
    int maxArgs,
  ) {
    if (args.length < minArgs || args.length > maxArgs) {
      if (minArgs == maxArgs) {
        throw ArgumentError(
          '$name expects $minArgs argument(s), got ${args.length}.',
        );
      }
      throw ArgumentError(
        '$name expects $minArgs to $maxArgs arguments, got ${args.length}.',
      );
    }
  }

  static CalcValue _liftUnary(
    CalcValue value,
    Expr Function(Expr) onExpr, {
    Matrix<Expr> Function(Matrix<Expr>)? onMatrix,
    Vector<Expr> Function(Vector<Expr>)? onVector,
  }) => switch (value) {
    ExprValue(:final expr) => ExprValue(onExpr(expr)),
    SeriesValue(:final series) => ExprValue(onExpr(series.toExpr())),
    VectorValue(:final vector) => VectorValue(
      onVector != null
          ? onVector(vector)
          : Vector<Expr>.generate(
              vector.length,
              (i) => onExpr(vector.getUnchecked(i)),
              type: exprDataType,
            ),
    ),
    MatrixValue(:final matrix) => MatrixValue(
      onMatrix != null
          ? onMatrix(matrix)
          : Matrix<Expr>.generate(
              matrix.rowCount,
              matrix.colCount,
              (r, c) => onExpr(matrix.getUnchecked(r, c)),
              type: exprDataType,
            ),
    ),
    ListValue(:final elements) => ListValue([
      for (final elem in elements)
        _liftUnary(elem, onExpr, onMatrix: onMatrix, onVector: onVector),
    ]),
    _ => value,
  };

  static CalcValue _applySubstitution(
    CalcValue target,
    String varName,
    Expr replacement,
    EvaluatorContext ctx,
  ) => _liftUnary(
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

  static Expr _expectExpr(CalcValue value, String cmdName) => switch (value) {
    ExprValue(:final expr) => expr,
    SeriesValue(:final polynomialExpr) => polynomialExpr,
    _ => throw ArgumentError(
      '$cmdName expected a symbolic expression, got ${value.kind}.',
    ),
  };

  static String _expectVarName(CalcValue value, String cmdName) {
    if (value case ExprValue(expr: Variable(:final name))) {
      return name;
    }
    throw ArgumentError(
      '$cmdName expected a variable name (e.g. x), got $value.',
    );
  }

  static int _expectInt(CalcValue value, String cmdName) {
    if (value case ExprValue(expr: IntegerNumber(asInt: final n?))) {
      return n;
    }
    throw ArgumentError('$cmdName expected an integer argument, got $value.');
  }

  static double _expectDouble(CalcValue value, String cmdName) {
    if (value case ExprValue(:final expr)) {
      final approx = expr.approximate();
      if (approx is RealNumeric) {
        return approx.toDouble();
      }
      final eval = expr.evaluate();
      if (!eval.isNaN) return eval;
    }
    throw ArgumentError('$cmdName expected a real number, got $value.');
  }

  static Matrix<Expr> _expectMatrix(CalcValue value, String cmdName) {
    if (value case MatrixValue(:final matrix)) return matrix;
    throw ArgumentError(
      '$cmdName expected a Matrix [[...]], got ${value.kind}.',
    );
  }

  static Vector<Expr> _expectVector(CalcValue value, String cmdName) {
    if (value case VectorValue(:final vector)) return vector;
    throw ArgumentError('$cmdName expected a Vector [...], got ${value.kind}.');
  }

  static List<Expr> _extractExprList(CalcValue value, String cmdName) =>
      switch (value) {
        VectorValue(:final vector) => [
          for (var i = 0; i < vector.length; i++) vector.getUnchecked(i),
        ],
        ListValue(:final elements) => [
          for (final e in elements) _expectExpr(e, cmdName),
        ],
        ExprValue(:final expr) => [expr],
        _ => throw ArgumentError(
          '$cmdName expected a list or vector of expressions.',
        ),
      };

  static List<String> _extractVarNameList(CalcValue value, String cmdName) =>
      switch (value) {
        VectorValue(:final vector) => [
          for (var i = 0; i < vector.length; i++)
            _expectVarName(ExprValue(vector.getUnchecked(i)), cmdName),
        ],
        ListValue(:final elements) => [
          for (final e in elements) _expectVarName(e, cmdName),
        ],
        ExprValue() => [_expectVarName(value, cmdName)],
        _ => throw ArgumentError(
          '$cmdName expected a list of variable names [x, y].',
        ),
      };

  static List<String> _inferSystemVariables(List<Expr> exprs) {
    final vars = <String>{};
    for (final e in exprs) {
      vars.addAll(e.freeVariables);
    }
    final sorted = vars.toList()..sort();
    return sorted.isEmpty ? const ['x'] : sorted;
  }

  static List<Expr> _extractPlotExpressions(CalcValue arg) => switch (arg) {
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

  static String _inferPlotVariable(List<Expr> exprs) {
    for (final e in exprs) {
      final free = e.freeVariables;
      if (free.contains('x')) return 'x';
      if (free.contains('t')) return 't';
      if (free.isNotEmpty) return free.first;
    }
    return 'x';
  }

  static LimitDirection _parseLimitDir(CalcValue v) {
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

  static String? _primaryVar(CalcValue value) {
    if (value case ExprValue(:final expr)) {
      final free = expr.freeVariables;
      if (free.contains('x')) return 'x';
      if (free.isNotEmpty) return free.first;
    }
    if (value case SeriesValue(:final series)) {
      return series.variable;
    }
    return null;
  }

  static bool _hasImaginary(Expr expr) => expr.anyNode(
    (n) =>
        (n is ComplexNumber && !n.imaginary.isZero) ||
        (n is Constant && !n.isReal),
  );

  static Expr _toPolarExpr(Expr expr, Assumptions assumptions) {
    final r = Abs(expr).simplify(assumptions: assumptions);
    if (r is Number && r.isZero) return IntegerNumber.zero;
    final theta = Arg(expr).simplify(assumptions: assumptions);
    if (theta is Number && theta.isZero) return r;
    final expPart = Pow(
      Constant.e,
      (ComplexNumber.i * theta).simplify(assumptions: assumptions),
    );
    if (r is IntegerNumber && r.isOne) return expPart;
    return Mul([r, expPart]);
  }
}
