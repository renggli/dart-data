import 'package:data/linear.dart';
import 'package:data/symbolic.dart';

import '../language/ast.dart';
import '../language/grammar.dart';
import '../model/environment.dart';
import '../model/session.dart';
import '../model/stack.dart';
import '../model/value.dart';
import 'commands.dart';

/// Outcome of evaluating a single statement in Scroll mode.
final class StatementEvaluationResult {
  const new({
    required this.value,
    this.assignedSymbol,
    this.referencedResults = const {},
    this.referencedSymbols = const {},
  });

  final CalcValue value;
  final String? assignedSymbol;
  final Set<int> referencedResults;
  final Set<String> referencedSymbols;
}

/// Evaluates calculator statements and expressions against an [Environment],
/// [Session], and optional [RpnStack].
final class CalcEvaluator {
  new({required this.environment, required this.session, this.stack});

  final Environment environment;
  final Session session;
  final RpnStack? stack;

  CalcGrammar get _grammar => CalcGrammar(
    implicitMultiplication: environment.settings.implicitMultiplication,
  );

  /// Parses and appends a new cell to [session] in Scroll mode.
  ///
  /// If [forceNumeric] is `true` (e.g. `Alt+Enter`), the evaluated result is
  /// converted to a numeric approximation via `approx`.
  WorksheetCell evaluateScroll(
    String rawInput, {
    bool forceNumeric = false,
    bool recordHistory = true,
  }) {
    final result = evaluateRaw(rawInput, forceNumeric: forceNumeric);
    final cell = session.addResult(
      input: rawInput,
      value: result.value,
      assignedSymbol: result.assignedSymbol,
      referencedResults: result.referencedResults,
      referencedSymbols: result.referencedSymbols,
      recordHistory: recordHistory,
    );
    if (stack != null &&
        cell.value is! ErrorValue &&
        cell.value is! InfoValue) {
      stack!.push(
        StackItem(resultId: cell.id, value: cell.value),
        recordUndo: false,
      );
    }
    return cell;
  }

  /// Re-evaluates an existing cell [cellId] in-place and marks any dependent
  /// cells stale.
  ({WorksheetCell cell, List<int> staleIds}) updateScrollCell(
    int cellId,
    String newInput, {
    bool forceNumeric = false,
  }) {
    final result = evaluateRaw(
      newInput,
      forceNumeric: forceNumeric,
      beforeCellId: cellId,
    );
    final staleIds = session.updateCell(
      cellId,
      input: newInput,
      value: result.value,
      assignedSymbol: result.assignedSymbol,
      referencedResults: result.referencedResults,
      referencedSymbols: result.referencedSymbols,
    );
    stack?.updateResultValue(cellId, result.value);
    return (cell: session.allCells[cellId]!, staleIds: staleIds);
  }

  /// Recomputes all currently stale cells in topological order.
  List<WorksheetCell> recomputeStaleCells() {
    final updated = <WorksheetCell>[];
    for (final cell in session.staleCells) {
      final result = evaluateRaw(cell.input, beforeCellId: cell.id);
      session.updateCell(
        cell.id,
        input: cell.input,
        value: result.value,
        assignedSymbol: result.assignedSymbol,
        referencedResults: result.referencedResults,
        referencedSymbols: result.referencedSymbols,
      );
      final updatedCell = session.allCells[cell.id]!;
      stack?.updateResultValue(cell.id, updatedCell.value);
      updated.add(updatedCell);
    }
    return updated;
  }

  /// Parses and evaluates [rawInput] without mutating the [session] cell table
  /// (though variable/function assignments in [rawInput] do update
  /// [environment]).
  StatementEvaluationResult evaluateRaw(
    String rawInput, {
    bool forceNumeric = false,
    int? beforeCellId,
  }) {
    final referencedResults = <int>{};
    final referencedSymbols = <String>{};

    try {
      final stmt = _grammar.parseStatement(rawInput);
      final (:value, :assignedSymbol) = _evalStatement(
        stmt,
        referencedResults: referencedResults,
        referencedSymbols: referencedSymbols,
        beforeCellId: beforeCellId,
      );
      final finalValue = _postProcess(value, forceNumeric: forceNumeric);
      return StatementEvaluationResult(
        value: finalValue,
        assignedSymbol: assignedSymbol,
        referencedResults: referencedResults,
        referencedSymbols: referencedSymbols,
      );
    } on CalcParseException catch (e) {
      return StatementEvaluationResult(
        value: ErrorValue(
          e.message,
          offset: e.offset,
          suggestion: e.suggestion,
          source: e.source ?? rawInput,
        ),
        referencedResults: referencedResults,
        referencedSymbols: referencedSymbols,
      );
    } on FormatException catch (e) {
      return StatementEvaluationResult(
        value: ErrorValue(e.message, offset: e.offset, source: rawInput),
        referencedResults: referencedResults,
        referencedSymbols: referencedSymbols,
      );
    } catch (e) {
      return StatementEvaluationResult(
        value: ErrorValue(_cleanExceptionMessage(e), source: rawInput),
        referencedResults: referencedResults,
        referencedSymbols: referencedSymbols,
      );
    }
  }

  ({CalcValue value, String? assignedSymbol}) _evalStatement(
    CalcStatement stmt, {
    required Set<int> referencedResults,
    required Set<String> referencedSymbols,
    int? beforeCellId,
  }) {
    switch (stmt) {
      case MultiStatement(:final statements):
        CalcValue lastVal = const InfoValue('');
        String? lastAssigned;
        for (final sub in statements) {
          final res = _evalStatement(
            sub,
            referencedResults: referencedResults,
            referencedSymbols: referencedSymbols,
            beforeCellId: beforeCellId,
          );
          lastVal = res.value;
          if (res.assignedSymbol != null) lastAssigned = res.assignedSymbol;
        }
        return (value: lastVal, assignedSymbol: lastAssigned);

      case AssignmentStatement(:final name, :final rhs):
        final val = evalNode(
          rhs,
          referencedResults: referencedResults,
          referencedSymbols: referencedSymbols,
          beforeCellId: beforeCellId,
        );
        final simplified = _postProcess(val, forceNumeric: false);
        environment.setVariable(name, simplified);
        return (value: simplified, assignedSymbol: name);

      case FunctionDefStatement(:final name, :final params, :final body):
        final boundMask = Set<String>.of(params);
        final bodyVal = evalNode(
          body,
          referencedResults: referencedResults,
          referencedSymbols: referencedSymbols,
          boundParams: boundMask,
          beforeCellId: beforeCellId,
        );
        if (bodyVal is! ExprValue) {
          throw ArgumentError(
            'Function $name body must evaluate to a symbolic expression.',
          );
        }
        final fn = UserFunction(
          name: name,
          params: params,
          body: bodyVal.expr,
          sourceText: bodyVal.expr.toString(),
        );
        environment.setFunction(fn);
        return (
          value: ExprValue(
            Equal(
              VariableFunction(name, [for (final p in params) Variable(p)]),
              bodyVal.expr,
            ),
          ),
          assignedSymbol: name,
        );

      case EvalStatement(:final node):
        final val = evalNode(
          node,
          referencedResults: referencedResults,
          referencedSymbols: referencedSymbols,
          beforeCellId: beforeCellId,
        );
        return (value: val, assignedSymbol: null);
    }
  }

  /// Evaluates a parsed [CalcNode] into a [CalcValue].
  CalcValue evalNode(
    CalcNode node, {
    Set<int>? referencedResults,
    Set<String>? referencedSymbols,
    Set<String> boundParams = const {},
    int? beforeCellId,
  }) {
    switch (node) {
      case ExprLeafNode(:final expr):
        return ExprValue(expr);

      case SymbolNode(:final name):
        if (boundParams.contains(name)) {
          return ExprValue(Variable(name));
        }
        referencedSymbols?.add(name);
        final bound = environment.getVariable(name);
        if (bound != null) return bound;
        return ExprValue(Variable(name));

      case ResultRefNode(:final index):
        final canonicalId = session.resolveCanonicalId(
          index,
          beforeId: beforeCellId,
        );
        referencedResults?.add(canonicalId);
        return session.resolveResult(index, beforeId: beforeCellId);

      case VectorLiteralNode(:final elements):
        final evaluated = [
          for (final e in elements)
            evalNode(
              e,
              referencedResults: referencedResults,
              referencedSymbols: referencedSymbols,
              boundParams: boundParams,
              beforeCellId: beforeCellId,
            ),
        ];
        if (evaluated.every((v) => v is ExprValue)) {
          return VectorValue(
            Vector<Expr>.fromList([
              for (final v in evaluated) (v as ExprValue).expr,
            ], type: exprDataType),
          );
        }
        return ListValue(evaluated);

      case MatrixLiteralNode(:final rows):
        final exprRows = <List<Expr>>[];
        for (final row in rows) {
          final exprRow = <Expr>[];
          for (final item in row) {
            final v = evalNode(
              item,
              referencedResults: referencedResults,
              referencedSymbols: referencedSymbols,
              boundParams: boundParams,
              beforeCellId: beforeCellId,
            );
            if (v is! ExprValue) {
              throw ArgumentError('Matrix entries must be scalar expressions.');
            }
            exprRow.add(v.expr);
          }
          exprRows.add(exprRow);
        }
        return MatrixValue(Matrix<Expr>.fromRows(exprRows, type: exprDataType));

      case UnaryOpNode(:final op, :final operand):
        final val = evalNode(
          operand,
          referencedResults: referencedResults,
          referencedSymbols: referencedSymbols,
          boundParams: boundParams,
          beforeCellId: beforeCellId,
        );
        return applyUnaryOp(op, val);

      case BinaryOpNode(:final op, :final left, :final right):
        final lVal = evalNode(
          left,
          referencedResults: referencedResults,
          referencedSymbols: referencedSymbols,
          boundParams: boundParams,
          beforeCellId: beforeCellId,
        );
        final rVal = evalNode(
          right,
          referencedResults: referencedResults,
          referencedSymbols: referencedSymbols,
          boundParams: boundParams,
          beforeCellId: beforeCellId,
        );
        return applyBinaryOp(op, lVal, rVal);

      case CallNode(:final name, :final args):
        return _evalCall(
          name,
          args,
          referencedResults: referencedResults,
          referencedSymbols: referencedSymbols,
          boundParams: boundParams,
          beforeCellId: beforeCellId,
        );
    }
  }

  CalcValue _evalCall(
    String name,
    List<CalcNode> rawArgs, {
    Set<int>? referencedResults,
    Set<String>? referencedSymbols,
    Set<String> boundParams = const {},
    int? beforeCellId,
  }) {
    final canonicalName = switch (name) {
      'derivative' => 'diff',
      'integral' => 'integrate',
      'conjugate' => 'conj',
      'arcsin' => 'asin',
      'arccos' => 'acos',
      'arctan' => 'atan',
      'arcsinh' => 'asinh',
      'arccosh' => 'acosh',
      'arctanh' => 'atanh',
      _ => name,
    };

    final userFn = environment.getFunction(name);
    final cmd = userFn == null ? CommandRegistry.byName[canonicalName] : null;

    final evaluatedArgs = <CalcValue>[];
    for (var i = 0; i < rawArgs.length; i++) {
      final argNode = rawArgs[i];
      final paramKind = cmd?.paramKindAt(i) ?? ParamKind.expr;
      if (paramKind == ParamKind.symbol &&
          argNode is SymbolNode &&
          environment.getVariable(argNode.name) is! VectorValue) {
        evaluatedArgs.add(ExprValue(Variable(argNode.name)));
      } else if (paramKind == ParamKind.equation &&
          argNode is BinaryOpNode &&
          argNode.op == CalcBinaryOp.eq &&
          argNode.left is SymbolNode) {
        final varName = (argNode.left as SymbolNode).name;
        final rhsVal = evalNode(
          argNode.right,
          referencedResults: referencedResults,
          referencedSymbols: referencedSymbols,
          boundParams: boundParams,
          beforeCellId: beforeCellId,
        );
        if (rhsVal is! ExprValue) {
          throw ArgumentError(
            '$canonicalName replacement for $varName must be a scalar.',
          );
        }
        evaluatedArgs.add(ExprValue(Equal(Variable(varName), rhsVal.expr)));
      } else {
        evaluatedArgs.add(
          evalNode(
            argNode,
            referencedResults: referencedResults,
            referencedSymbols: referencedSymbols,
            boundParams: boundParams,
            beforeCellId: beforeCellId,
          ),
        );
      }
    }

    // 1. User-defined function
    if (userFn != null) {
      referencedSymbols?.add(name);
      final exprArgs = [
        for (final a in evaluatedArgs)
          if (a is ExprValue)
            a.expr
          else
            throw ArgumentError(
              'User function $name expects scalar expressions.',
            ),
      ];
      return ExprValue(userFn.apply(exprArgs));
    }

    // 2. Canonical calculator command
    if (cmd != null) {
      return cmd.run(
        evaluatedArgs,
        EvaluatorContext(environment: environment, session: session),
      );
    }

    // 3. Standard ExprSyntax unary/binary/variadic functions
    if (evaluatedArgs.every((a) => a is ExprValue)) {
      final exprArgs = [for (final a in evaluatedArgs) (a as ExprValue).expr];
      if (exprArgs.length == 1 &&
          ExprSyntax.standardUnaryFunctions.containsKey(name)) {
        final rawFnExpr = ExprSyntax.standardUnaryFunctions[name]!(exprArgs[0]);
        return ExprValue(_applyAngleUnitOnTrigConstruct(name, rawFnExpr));
      }
      if (exprArgs.length == 2 &&
          ExprSyntax.standardBinaryFunctions.containsKey(name)) {
        return ExprValue(
          ExprSyntax.standardBinaryFunctions[name]!(exprArgs[0], exprArgs[1]),
        );
      }
      if (ExprSyntax.standardVariadicFunctions.containsKey(name)) {
        return ExprValue(ExprSyntax.standardVariadicFunctions[name]!(exprArgs));
      }
      // 4. Undefined symbolic function -> VariableFunction(name, args)
      return ExprValue(VariableFunction(name, exprArgs));
    }

    // Element-wise lifting of standard unary math functions over Vector/Matrix
    if (evaluatedArgs.length == 1 &&
        ExprSyntax.standardUnaryFunctions.containsKey(name)) {
      final fn = ExprSyntax.standardUnaryFunctions[name]!;
      final arg = evaluatedArgs.first;
      if (arg case VectorValue(:final vector)) {
        return VectorValue(
          Vector<Expr>.generate(
            vector.length,
            (i) => fn(vector.getUnchecked(i)),
            type: exprDataType,
          ),
        );
      }
      if (arg case MatrixValue(:final matrix)) {
        return MatrixValue(
          Matrix<Expr>.generate(
            matrix.rowCount,
            matrix.colCount,
            (r, c) => fn(matrix.getUnchecked(r, c)),
            type: exprDataType,
          ),
        );
      }
    }

    throw ArgumentError(
      'Cannot apply "$name" to ${evaluatedArgs.map((e) => e.kind).join(', ')}.',
    );
  }

  /// Applies a unary operator (`-`, `+`, `!`, `'`) to [val].
  CalcValue applyUnaryOp(CalcUnaryOp op, CalcValue val) {
    switch (op) {
      case CalcUnaryOp.plus:
        return val;
      case CalcUnaryOp.negate:
        return switch (val) {
          ExprValue(:final expr) => ExprValue(-expr),
          VectorValue(:final vector) => VectorValue(
            Vector<Expr>.generate(
              vector.length,
              (i) => -vector.getUnchecked(i),
              type: exprDataType,
            ),
          ),
          MatrixValue(:final matrix) => MatrixValue(
            Matrix<Expr>.generate(
              matrix.rowCount,
              matrix.colCount,
              (r, c) => -matrix.getUnchecked(r, c),
              type: exprDataType,
            ),
          ),
          SeriesValue(:final series) => SeriesValue(-series),
          _ => throw ArgumentError('Cannot negate ${val.kind}.'),
        };
      case CalcUnaryOp.factorial:
        if (val case ExprValue(:final expr)) {
          return ExprValue(Factorial(expr));
        }
        throw ArgumentError('Factorial (!) requires a scalar expression.');
      case CalcUnaryOp.transpose:
        if (val case MatrixValue()) {
          return CommandRegistry.byName['transpose']!.run([
            val,
          ], EvaluatorContext(environment: environment, session: session));
        }
        if (val case VectorValue(:final vector)) {
          // 1 x n row matrix
          return MatrixValue(
            Matrix<Expr>.fromRows([
              [for (var i = 0; i < vector.length; i++) vector.getUnchecked(i)],
            ], type: exprDataType),
          );
        }
        return val;
    }
  }

  /// Applies a binary operator (`+`, `-`, `*`, `/`, `^`, `=`, etc.) to [left]
  /// and [right], supporting scalar, vector, and matrix arithmetic.
  CalcValue applyBinaryOp(CalcBinaryOp op, CalcValue left, CalcValue right) {
    // Series arithmetic
    if (left is SeriesValue && right is SeriesValue) {
      return switch (op) {
        CalcBinaryOp.add => SeriesValue(left.series + right.series),
        CalcBinaryOp.sub => SeriesValue(left.series - right.series),
        CalcBinaryOp.mul => SeriesValue(left.series * right.series),
        CalcBinaryOp.div => SeriesValue(left.series / right.series),
        _ => applyBinaryOp(
          op,
          ExprValue(left.exprWithOrder),
          ExprValue(right.exprWithOrder),
        ),
      };
    }

    // Scalar + Scalar
    if (left is ExprValue && right is ExprValue) {
      final a = left.expr;
      final b = right.expr;
      final res = switch (op) {
        CalcBinaryOp.add => a + b,
        CalcBinaryOp.sub => a - b,
        CalcBinaryOp.mul => a * b,
        CalcBinaryOp.div => a / b,
        CalcBinaryOp.pow => Pow(a, b),
        CalcBinaryOp.eq => Equal(a, b),
        CalcBinaryOp.ne => NotEqual(a, b),
        CalcBinaryOp.lt => LessThan(a, b),
        CalcBinaryOp.le => LessEqual(a, b),
        CalcBinaryOp.gt => GreaterThan(a, b),
        CalcBinaryOp.ge => GreaterEqual(a, b),
      };
      return ExprValue(res);
    }

    // Vector +/- Vector
    if (left is VectorValue && right is VectorValue) {
      final u = left.vector;
      final v = right.vector;
      if (u.length != v.length) {
        throw ArgumentError(
          'Vector dimension mismatch: ${u.length} vs ${v.length}.',
        );
      }
      if (op == CalcBinaryOp.add) {
        return VectorValue(
          Vector<Expr>.generate(
            u.length,
            (i) => (u.getUnchecked(i) + v.getUnchecked(i)).simplify(),
            type: exprDataType,
          ),
        );
      }
      if (op == CalcBinaryOp.sub) {
        return VectorValue(
          Vector<Expr>.generate(
            u.length,
            (i) => (u.getUnchecked(i) - v.getUnchecked(i)).simplify(),
            type: exprDataType,
          ),
        );
      }
      if (op == CalcBinaryOp.mul) {
        return CommandRegistry.byName['dot']!.run([
          left,
          right,
        ], EvaluatorContext(environment: environment, session: session));
      }
    }

    // Scalar * Vector or Vector * Scalar or Vector / Scalar
    if (left is ExprValue && right is VectorValue && op == CalcBinaryOp.mul) {
      final s = left.expr;
      final v = right.vector;
      return VectorValue(
        Vector<Expr>.generate(
          v.length,
          (i) => (s * v.getUnchecked(i)).simplify(),
          type: exprDataType,
        ),
      );
    }
    if (left is VectorValue &&
        right is ExprValue &&
        (op == CalcBinaryOp.mul || op == CalcBinaryOp.div)) {
      final v = left.vector;
      final s = right.expr;
      return VectorValue(
        Vector<Expr>.generate(
          v.length,
          (i) =>
              (op == CalcBinaryOp.mul
                      ? v.getUnchecked(i) * s
                      : v.getUnchecked(i) / s)
                  .simplify(),
          type: exprDataType,
        ),
      );
    }

    // Matrix arithmetic
    if (left is MatrixValue && right is MatrixValue) {
      final a = left.matrix;
      final b = right.matrix;
      if (op == CalcBinaryOp.add || op == CalcBinaryOp.sub) {
        if (a.rowCount != b.rowCount || a.colCount != b.colCount) {
          throw ArgumentError(
            'Matrix dimension mismatch: ${a.rowCount}×${a.colCount} vs ${b.rowCount}×${b.colCount}.',
          );
        }
        return MatrixValue(
          Matrix<Expr>.generate(
            a.rowCount,
            a.colCount,
            (r, c) =>
                (op == CalcBinaryOp.add
                        ? a.getUnchecked(r, c) + b.getUnchecked(r, c)
                        : a.getUnchecked(r, c) - b.getUnchecked(r, c))
                    .simplify(),
            type: exprDataType,
          ),
        );
      }
      if (op == CalcBinaryOp.mul) {
        if (a.colCount != b.rowCount) {
          throw ArgumentError(
            'Matrix multiplication dimension mismatch: ${a.rowCount}×${a.colCount} * ${b.rowCount}×${b.colCount}.',
          );
        }
        return MatrixValue((a * b).simplify());
      }
    }

    // Matrix * Vector
    if (left is MatrixValue && right is VectorValue && op == CalcBinaryOp.mul) {
      final a = left.matrix;
      final v = right.vector;
      if (a.colCount != v.length) {
        throw ArgumentError(
          'Matrix-vector dimension mismatch: ${a.rowCount}×${a.colCount} * ${v.length}.',
        );
      }
      return VectorValue(
        Vector<Expr>.generate(a.rowCount, (r) {
          var sum = IntegerNumber.zero as Expr;
          for (var c = 0; c < a.colCount; c++) {
            sum = (sum + a.getUnchecked(r, c) * v.getUnchecked(c)).simplify();
          }
          return sum;
        }, type: exprDataType),
      );
    }

    // Scalar * Matrix or Matrix * Scalar or Matrix / Scalar
    if (left is ExprValue && right is MatrixValue && op == CalcBinaryOp.mul) {
      final s = left.expr;
      final m = right.matrix;
      return MatrixValue(
        Matrix<Expr>.generate(
          m.rowCount,
          m.colCount,
          (r, c) => (s * m.getUnchecked(r, c)).simplify(),
          type: exprDataType,
        ),
      );
    }
    if (left is MatrixValue &&
        right is ExprValue &&
        (op == CalcBinaryOp.mul || op == CalcBinaryOp.div)) {
      final m = left.matrix;
      final s = right.expr;
      return MatrixValue(
        Matrix<Expr>.generate(
          m.rowCount,
          m.colCount,
          (r, c) =>
              (op == CalcBinaryOp.mul
                      ? m.getUnchecked(r, c) * s
                      : m.getUnchecked(r, c) / s)
                  .simplify(),
          type: exprDataType,
        ),
      );
    }

    // Matrix ^ Integer
    if (left is MatrixValue &&
        right is ExprValue &&
        op == CalcBinaryOp.pow &&
        right.expr is IntegerNumber) {
      final exp = (right.expr as IntegerNumber).asInt;
      if (exp != null) {
        return MatrixValue(left.matrix.power(exp));
      }
    }

    throw ArgumentError(
      'Unsupported operation ${op.name} between ${left.kind} and ${right.kind}.',
    );
  }

  /// Applies auto-simplify, complex display mode, and exact/approx policy to a
  /// computed [CalcValue].
  CalcValue _postProcess(CalcValue value, {required bool forceNumeric}) {
    final settings = environment.settings;
    final assumptions = settings.assumptions;
    var current = value;

    if (settings.autoSimplify) {
      current = switch (current) {
        ExprValue(:final expr) => ExprValue(
          expr.simplify(assumptions: assumptions),
        ),
        VectorValue(:final vector) => VectorValue(vector.simplify()),
        MatrixValue(:final matrix) => MatrixValue(matrix.simplify()),
        ListValue(:final elements) => ListValue([
          for (final e in elements) _postProcess(e, forceNumeric: false),
        ]),
        _ => current,
      };
    }

    if (forceNumeric || settings.approxMode) {
      current = switch (current) {
        ExprValue(:final expr) => ExprValue(expr.approximate()),
        VectorValue(:final vector) => VectorValue(vector.approximate()),
        MatrixValue(:final matrix) => MatrixValue(matrix.approximate()),
        SeriesValue(:final polynomialExpr) => ExprValue(
          polynomialExpr.approximate(),
        ),
        ListValue(:final elements) => ListValue([
          for (final e in elements) _postProcess(e, forceNumeric: true),
        ]),
        _ => current,
      };
    }

    if (settings.complexDisplay == ComplexDisplayMode.polar &&
        current is ExprValue &&
        _isNonZeroComplexExpr(current.expr)) {
      current = CommandRegistry.byName['polar']!.run([
        current,
      ], EvaluatorContext(environment: environment, session: session));
    }

    return current;
  }

  Expr _applyAngleUnitOnTrigConstruct(String fnName, Expr constructed) {
    if (environment.settings.angleMode != AngleMode.deg) return constructed;
    // In DEG mode, closed numeric arguments to sin/cos/tan convert degrees -> radians
    const directTrig = {'sin', 'cos', 'tan', 'sec', 'csc', 'cot'};
    if (!directTrig.contains(fnName)) return constructed;
    return switch (constructed) {
      Sin(:final expr) when expr.freeVariables.isEmpty => Sin(
        expr * Constant.pi / IntegerNumber.of(180),
      ),
      Cos(:final expr) when expr.freeVariables.isEmpty => Cos(
        expr * Constant.pi / IntegerNumber.of(180),
      ),
      Tan(:final expr) when expr.freeVariables.isEmpty => Tan(
        expr * Constant.pi / IntegerNumber.of(180),
      ),
      _ => constructed,
    };
  }

  static bool _isNonZeroComplexExpr(Expr expr) =>
      expr is ComplexNumber && !expr.imaginary.isZero;

  static String _cleanExceptionMessage(Object error) {
    final raw = error.toString();
    for (final prefix in const [
      'Invalid argument(s): ',
      'Bad state: ',
      'Unsupported operation: ',
      'FormatException: ',
    ]) {
      if (raw.startsWith(prefix)) {
        return raw.substring(prefix.length);
      }
    }
    return raw;
  }
}
