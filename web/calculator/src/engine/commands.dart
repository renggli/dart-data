import 'package:data/linear.dart';
import 'package:data/symbolic.dart';

import '../model/environment.dart';
import '../model/session.dart';
import '../model/value.dart';
import 'commands/algebra.dart';
import 'commands/calculus.dart';
import 'commands/complex.dart';
import 'commands/linear.dart';
import 'commands/numbers.dart';
import 'commands/numeric.dart';
import 'commands/plot.dart';
import 'commands/session.dart';

/// Category grouping for calculator commands (drives palette, keypad tabs,
/// and help reference).
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

/// Parameter evaluation policy for a command argument.
enum ParamKind {
  /// Standard evaluated expression, vector, or matrix.
  expr,

  /// Bare symbol identifier (`x`, `t`, `lambda`) kept unbound when passed as a
  /// scalar symbol.
  symbol,

  /// Substitution equation (`x = val`) where the LHS identifier stays unbound.
  equation,

  /// Optional evaluated expression.
  optionalExpr,

  /// Optional integer literal.
  optionalInt,
}

/// Declarative parameter descriptor for a [Command].
final class ParamSpec {
  const new(this.name, [this.kind = ParamKind.expr]);

  const new expr(this.name) : kind = ParamKind.expr;
  const new symbol(this.name) : kind = ParamKind.symbol;
  const new equation(this.name) : kind = ParamKind.equation;
  const new optionalExpr(this.name) : kind = ParamKind.optionalExpr;
  const new optionalInt(this.name) : kind = ParamKind.optionalInt;

  final String name;
  final ParamKind kind;
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
    required this.paramSpecs,
    required this.minArity,
    required this.maxArity,
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

  /// Human-readable signature (`integrate(expr, [var], [a, b])`).
  final String signature;

  /// Declarative parameter specifications driving evaluation and signature
  /// hints.
  final List<ParamSpec> paramSpecs;

  /// Minimum number of arguments accepted.
  final int minArity;

  /// Maximum number of arguments accepted.
  final int maxArity;

  /// Parameter display names for active-argument highlighting in autocomplete.
  List<String> get params => [for (final p in paramSpecs) p.name];

  /// Concise one-line description.
  final String doc;

  /// Runnable example strings.
  final List<String> examples;

  /// Short label shown on RPN keys (`∫`, `d/dx`, `Det`, ...).
  final String rpnLabel;

  /// Default number of stack levels consumed when invoked in RPN mode.
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

  /// Returns the [ParamKind] for argument at [index], repeating the last
  /// parameter specification for variadic commands.
  ParamKind paramKindAt(int index) {
    if (paramSpecs.isEmpty) return ParamKind.expr;
    if (index < paramSpecs.length) return paramSpecs[index].kind;
    return paramSpecs.last.kind;
  }
}

/// Central registry of all canonical calculator commands across categories.
abstract final class CommandRegistry {
  static final List<Command> all = [
    ...buildAlgebraCommands(),
    ...buildCalculusCommands(),
    ...buildLinearCommands(),
    ...buildComplexCommands(),
    ...buildNumbersCommands(),
    ...buildNumericCommands(),
    ...buildPlotCommands(),
    ...buildSessionCommands(),
  ];

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
}

// =============================================================================
// Shared Command Helpers
// =============================================================================

void checkCommandArity(
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

CalcValue liftUnaryCommand(
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
      liftUnaryCommand(elem, onExpr, onMatrix: onMatrix, onVector: onVector),
  ]),
  _ => value,
};

Expr expectCommandExpr(CalcValue value, String cmdName) => switch (value) {
  ExprValue(:final expr) => expr,
  SeriesValue(:final polynomialExpr) => polynomialExpr,
  _ => throw ArgumentError(
    '$cmdName expected a symbolic expression, got ${value.kind}.',
  ),
};

String expectCommandVarName(CalcValue value, String cmdName) {
  if (value case ExprValue(expr: Variable(:final name))) {
    return name;
  }
  throw ArgumentError(
    '$cmdName expected a variable name (e.g. x), got $value.',
  );
}

int expectCommandInt(CalcValue value, String cmdName) {
  if (value case ExprValue(expr: IntegerNumber(asInt: final n?))) {
    return n;
  }
  throw ArgumentError('$cmdName expected an integer argument, got $value.');
}

double expectCommandDouble(CalcValue value, String cmdName) {
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

Matrix<Expr> expectCommandMatrix(CalcValue value, String cmdName) {
  if (value case MatrixValue(:final matrix)) return matrix;
  throw ArgumentError('$cmdName expected a Matrix [[...]], got ${value.kind}.');
}

Vector<Expr> expectCommandVector(CalcValue value, String cmdName) {
  if (value case VectorValue(:final vector)) return vector;
  throw ArgumentError('$cmdName expected a Vector [...], got ${value.kind}.');
}

List<Expr> extractCommandExprList(CalcValue value, String cmdName) =>
    switch (value) {
      VectorValue(:final vector) => [
        for (var i = 0; i < vector.length; i++) vector.getUnchecked(i),
      ],
      ListValue(:final elements) => [
        for (final e in elements) expectCommandExpr(e, cmdName),
      ],
      ExprValue(:final expr) => [expr],
      _ => throw ArgumentError(
        '$cmdName expected a list or vector of expressions.',
      ),
    };

List<String> extractCommandVarNameList(CalcValue value, String cmdName) =>
    switch (value) {
      VectorValue(:final vector) => [
        for (var i = 0; i < vector.length; i++)
          expectCommandVarName(ExprValue(vector.getUnchecked(i)), cmdName),
      ],
      ListValue(:final elements) => [
        for (final e in elements) expectCommandVarName(e, cmdName),
      ],
      ExprValue() => [expectCommandVarName(value, cmdName)],
      _ => throw ArgumentError(
        '$cmdName expected a list of variable names [x, y].',
      ),
    };

List<String> inferSystemVariables(List<Expr> exprs) {
  final vars = <String>{};
  for (final e in exprs) {
    vars.addAll(e.freeVariables);
  }
  final sorted = vars.toList()..sort();
  return sorted.isEmpty ? const ['x'] : sorted;
}

String? primaryCommandVar(CalcValue value) {
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
