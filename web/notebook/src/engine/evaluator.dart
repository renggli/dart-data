import 'package:data/linear.dart';
import 'package:data/symbolic.dart';

import '../language/ast.dart';
import '../language/grammar.dart';
import '../language/signature.dart';
import '../model/environment.dart';
import '../model/value.dart';
import 'commands.dart';

/// Result of evaluating a notebook math cell.
final class EvalResult {
  const new({
    required this.value,
    this.assignedSymbol,
    this.definedFunction,
    this.preserveForm = false,
    this.referencedResults = const {},
    this.referencedSymbols = const {},
  });

  final CalcValue value;
  final String? assignedSymbol;
  final String? definedFunction;
  final bool preserveForm;
  final Set<int> referencedResults;
  final Set<String> referencedSymbols;
}

/// Callback resolving `r[n]` / `r[-n]` cell references during evaluation.
typedef ResultLookup = CalcValue? Function(int id);

/// Evaluates notebook math statements against an [Environment] and
/// [CommandRegistry].
final class NotebookEvaluator implements EvaluatorContext {
  new({Environment? env, CommandRegistry? registry})
    : env = env ?? Environment(),
      registry = registry ?? CommandRegistry();

  @override
  final Environment env;

  @override
  final CommandRegistry registry;

  @override
  Assumptions get assumptions => env.settings.toAssumptions();

  /// Evaluates [source] and returns an [EvalResult].
  ///
  /// When [forceApprox] is `true` (or `env.settings.approxMode` is `true`),
  /// exact symbolic results are numerically approximated.
  EvalResult evaluate(
    String source, {
    ResultLookup? lookupResult,
    bool forceApprox = false,
    int? currentMathId,
  }) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      return const EvalResult(value: InfoValue(''));
    }

    final referencedResults = <int>{};
    final referencedSymbols = <String>{};
    var preserveForm = false;

    CalcValue resolveRef(int index, int offset) {
      final targetId = index < 0 && currentMathId != null
          ? currentMathId + index
          : index;
      referencedResults.add(targetId);
      final val = lookupResult?.call(targetId);
      if (val == null) {
        throw ArgumentBindingException(
          'Undefined result reference r[$index]',
          offset: offset,
        );
      }
      return val;
    }

    final grammar = CalcGrammar(
      implicitMultiplication: env.settings.implicitMultiplication,
    );

    try {
      final stmt = grammar.parse(trimmed);
      final result = _evalStatement(
        stmt,
        resolveRef: resolveRef,
        referencedSymbols: referencedSymbols,
        onPreserveForm: () => preserveForm = true,
      );

      var val = result.value;
      if ((forceApprox || env.settings.approxMode) && val is ExprValue) {
        val = ExprValue(val.expr.approximate());
      } else if (!preserveForm &&
          env.settings.autoSimplify &&
          val is ExprValue &&
          val.expr is! RelationalExpr) {
        val = ExprValue(val.expr.simplify(assumptions: assumptions));
      }

      return EvalResult(
        value: val,
        assignedSymbol: result.assignedSymbol,
        definedFunction: result.definedFunction,
        preserveForm: preserveForm,
        referencedResults: referencedResults,
        referencedSymbols: referencedSymbols,
      );
    } on CalcParseException catch (e) {
      return EvalResult(
        value: ErrorValue(
          e.message,
          offset: e.offset,
          suggestion: e.suggestion,
          source: trimmed,
        ),
        referencedResults: referencedResults,
        referencedSymbols: referencedSymbols,
      );
    } on ArgumentBindingException catch (e) {
      return EvalResult(
        value: ErrorValue(
          e.message,
          offset: e.offset,
          suggestion: e.suggestion,
          source: trimmed,
        ),
        referencedResults: referencedResults,
        referencedSymbols: referencedSymbols,
      );
    } on FormatException catch (e) {
      return EvalResult(
        value: ErrorValue(e.message, offset: e.offset, source: trimmed),
        referencedResults: referencedResults,
        referencedSymbols: referencedSymbols,
      );
    } on ArgumentError catch (e) {
      return EvalResult(
        value: ErrorValue('${e.message ?? e}', source: trimmed),
        referencedResults: referencedResults,
        referencedSymbols: referencedSymbols,
      );
    } on StateError catch (e) {
      return EvalResult(
        value: ErrorValue(e.message, source: trimmed),
        referencedResults: referencedResults,
        referencedSymbols: referencedSymbols,
      );
    }
  }

  ({CalcValue value, String? assignedSymbol, String? definedFunction})
  _evalStatement(
    CalcStatement stmt, {
    required CalcValue Function(int index, int offset) resolveRef,
    required Set<String> referencedSymbols,
    required void Function() onPreserveForm,
    Map<String, CalcValue> localScope = const {},
  }) {
    switch (stmt) {
      case AssignmentStatement(:final name, :final value):
        final evaluated = _evalNode(
          value,
          resolveRef: resolveRef,
          referencedSymbols: referencedSymbols,
          onPreserveForm: onPreserveForm,
          localScope: localScope,
        );
        final simplified =
            (env.settings.autoSimplify &&
                evaluated is ExprValue &&
                evaluated.expr is! RelationalExpr)
            ? ExprValue(evaluated.expr.simplify(assumptions: assumptions))
            : evaluated;
        env.variables[name] = simplified;
        return (value: simplified, assignedSymbol: name, definedFunction: null);

      case FunctionDefStatement(:final name, :final params, :final body):
        final fn = UserFunction(
          name: name,
          params: params,
          body: body,
          source: stmt.toString(),
        );
        env.functions[name] = fn;
        return (
          value: InfoValue('Defined ${fn.formatSignature()}'),
          assignedSymbol: null,
          definedFunction: name,
        );

      case EvalStatement(:final node):
        final val = _evalNode(
          node,
          resolveRef: resolveRef,
          referencedSymbols: referencedSymbols,
          onPreserveForm: onPreserveForm,
          localScope: localScope,
        );
        return (value: val, assignedSymbol: null, definedFunction: null);

      case MultiStatement(:final statements):
        late ({
          CalcValue value,
          String? assignedSymbol,
          String? definedFunction,
        })
        last;
        for (final s in statements) {
          last = _evalStatement(
            s,
            resolveRef: resolveRef,
            referencedSymbols: referencedSymbols,
            onPreserveForm: onPreserveForm,
            localScope: localScope,
          );
        }
        return last;
    }
  }

  CalcValue _evalNode(
    CalcNode node, {
    required CalcValue Function(int index, int offset) resolveRef,
    required Set<String> referencedSymbols,
    required void Function() onPreserveForm,
    Map<String, CalcValue> localScope = const {},
    Set<String> boundSymbols = const {},
  }) {
    switch (node) {
      case ExprLeafNode(:final expr):
        return ExprValue(expr);

      case StringLiteralNode(:final value):
        return StringValue(value);

      case BoolLiteralNode(:final value):
        return BoolValue(value);

      case ResultRefNode(:final index, :final offset):
        return resolveRef(index, offset);

      case SymbolNode(:final name):
        if (localScope.containsKey(name)) return localScope[name]!;
        if (boundSymbols.contains(name)) return ExprValue(Variable(name));
        if (env.variables.containsKey(name)) {
          referencedSymbols.add(name);
          return env.variables[name]!;
        }
        return ExprValue(Variable(name));

      case VectorLiteralNode(:final elements):
        final vals = [
          for (final el in elements)
            _evalNode(
              el,
              resolveRef: resolveRef,
              referencedSymbols: referencedSymbols,
              onPreserveForm: onPreserveForm,
              localScope: localScope,
              boundSymbols: boundSymbols,
            ),
        ];
        if (vals.every((v) => v is ExprValue)) {
          return VectorValue(
            Vector<Expr>.fromList([
              for (final v in vals) (v as ExprValue).expr,
            ], type: exprDataType),
          );
        }
        return ListValue(vals);

      case MatrixLiteralNode(:final rows):
        final rowCount = rows.length;
        final colCount = rows.first.length;
        for (var r = 1; r < rowCount; r++) {
          if (rows[r].length != colCount) {
            throw FormatException(
              'Inconsistent matrix row lengths: expected $colCount, got ${rows[r].length}',
            );
          }
        }
        final exprRows = <List<Expr>>[];
        for (final row in rows) {
          final exprRow = <Expr>[];
          for (final cell in row) {
            final v = _evalNode(
              cell,
              resolveRef: resolveRef,
              referencedSymbols: referencedSymbols,
              onPreserveForm: onPreserveForm,
              localScope: localScope,
              boundSymbols: boundSymbols,
            );
            if (v is! ExprValue) {
              throw ArgumentBindingException(
                'Matrix entries must be scalar expressions',
                offset: cell.offset,
              );
            }
            exprRow.add(v.expr);
          }
          exprRows.add(exprRow);
        }
        return MatrixValue(Matrix<Expr>.fromRows(exprRows, type: exprDataType));

      case UnaryOpNode(:final op, :final operand):
        final val = _evalNode(
          operand,
          resolveRef: resolveRef,
          referencedSymbols: referencedSymbols,
          onPreserveForm: onPreserveForm,
          localScope: localScope,
          boundSymbols: boundSymbols,
        );
        if (op == '-') {
          return switch (val) {
            ExprValue(:final expr) => ExprValue(-expr),
            VectorValue(:final vector) => VectorValue(-vector),
            MatrixValue(:final matrix) => MatrixValue(-matrix),
            _ => throw ArgumentBindingException(
              "Cannot negate value of type '${val.kind}'",
              offset: node.offset,
            ),
          };
        }
        if (op == '√') {
          if (val is ExprValue) {
            return ExprValue(Pow(val.expr, FractionNumber.half));
          }
          throw ArgumentBindingException(
            "Cannot take square root of '${val.kind}'",
            offset: node.offset,
          );
        }
        return val;

      case PostfixOpNode(:final op, :final operand):
        if (op == '!') {
          final val = _evalNode(
            operand,
            resolveRef: resolveRef,
            referencedSymbols: referencedSymbols,
            onPreserveForm: onPreserveForm,
            localScope: localScope,
            boundSymbols: boundSymbols,
          );
          if (val is ExprValue) return ExprValue(Factorial(val.expr));
        }
        throw ArgumentBindingException(
          "Unsupported postfix operator '$op'",
          offset: node.offset,
        );

      case BinaryOpNode(:final op, :final left, :final right):
        final lv = _evalNode(
          left,
          resolveRef: resolveRef,
          referencedSymbols: referencedSymbols,
          onPreserveForm: onPreserveForm,
          localScope: localScope,
          boundSymbols: boundSymbols,
        );
        final rv = _evalNode(
          right,
          resolveRef: resolveRef,
          referencedSymbols: referencedSymbols,
          onPreserveForm: onPreserveForm,
          localScope: localScope,
          boundSymbols: boundSymbols,
        );
        return _evalBinary(op, lv, rv, node.offset);

      case CallNode(:final name, :final positionalArgs, :final namedArgs):
        return _evalCall(
          name,
          positionalArgs,
          namedArgs,
          node.offset,
          resolveRef: resolveRef,
          referencedSymbols: referencedSymbols,
          onPreserveForm: onPreserveForm,
          localScope: localScope,
          boundSymbols: boundSymbols,
        );
    }
  }

  CalcValue _evalCall(
    String name,
    List<CalcNode> positionalArgs,
    List<NamedArg> namedArgs,
    int offset, {
    required CalcValue Function(int index, int offset) resolveRef,
    required Set<String> referencedSymbols,
    required void Function() onPreserveForm,
    required Map<String, CalcValue> localScope,
    required Set<String> boundSymbols,
  }) {
    final inheritedBound = boundSymbols;
    CalcValue evalArg(
      CalcNode argNode, {
      Set<String> boundSymbols = const {},
    }) => _evalNode(
      argNode,
      resolveRef: resolveRef,
      referencedSymbols: referencedSymbols,
      onPreserveForm: onPreserveForm,
      localScope: localScope,
      boundSymbols: {...inheritedBound, ...boundSymbols},
    );

    // 1. User-defined function
    final userFn = env.functions[name];
    if (userFn != null) {
      referencedSymbols.add(name);
      final sig = userFn.toSignature(evalArg);
      final bound = ArgumentBinder.bind(
        name,
        sig,
        positionalArgs,
        namedArgs,
        evalArg,
        callOffset: offset,
      );
      final nextScope = <String, CalcValue>{
        ...localScope,
        for (final p in userFn.params)
          if (bound.raw(p.name) is CalcValue)
            p.name: bound.raw(p.name)! as CalcValue
          else if (bound.raw(p.name) case final raw?)
            p.name: raw is Expr ? ExprValue(raw) : InfoValue('$raw'),
      };
      return _evalNode(
        userFn.body,
        resolveRef: resolveRef,
        referencedSymbols: referencedSymbols,
        onPreserveForm: onPreserveForm,
        localScope: nextScope,
        boundSymbols: boundSymbols,
      );
    }

    // 2. Built-in command
    final cmd = registry.lookup(name);
    if (cmd != null) {
      if (cmd.preserveForm) onPreserveForm();
      final bound = ArgumentBinder.bind(
        name,
        cmd.signature,
        positionalArgs,
        namedArgs,
        evalArg,
        callOffset: offset,
      );
      return cmd.run(bound, this);
    }

    // 3. Built-in symbolic function (ExprSyntax) or symbolic VariableFunction
    if (namedArgs.isNotEmpty) {
      throw ArgumentBindingException(
        "Unknown function or command '$name' with named arguments",
        offset: offset,
      );
    }

    final argExprs = <Expr>[];
    for (final argNode in positionalArgs) {
      final val = evalArg(argNode, boundSymbols: boundSymbols);
      if (val is! ExprValue) {
        throw ArgumentBindingException(
          "Function '$name' expects symbolic expression arguments",
          offset: argNode.offset,
        );
      }
      argExprs.add(val.expr);
    }

    if (argExprs.length == 1 &&
        ExprSyntax.standardUnaryFunctions.containsKey(name)) {
      return ExprValue(ExprSyntax.standardUnaryFunctions[name]!(argExprs[0]));
    }
    if (argExprs.length == 2 &&
        ExprSyntax.standardBinaryFunctions.containsKey(name)) {
      return ExprValue(
        ExprSyntax.standardBinaryFunctions[name]!(argExprs[0], argExprs[1]),
      );
    }
    if (ExprSyntax.standardVariadicFunctions.containsKey(name)) {
      return ExprValue(ExprSyntax.standardVariadicFunctions[name]!(argExprs));
    }

    return ExprValue(VariableFunction(name, argExprs));
  }

  CalcValue _evalBinary(String op, CalcValue lv, CalcValue rv, int offset) {
    if (lv is ExprValue && rv is ExprValue) {
      final l = lv.expr;
      final r = rv.expr;
      return ExprValue(switch (op) {
        '+' => l + r,
        '-' => l - r,
        '*' => l * r,
        '/' => l / r,
        '^' => Pow(l, r),
        '=' => Equal(l, r),
        '!=' => NotEqual(l, r),
        '<' => LessThan(l, r),
        '<=' => LessEqual(l, r),
        '>' => GreaterThan(l, r),
        '>=' => GreaterEqual(l, r),
        _ => throw ArgumentBindingException(
          "Unknown operator '$op'",
          offset: offset,
        ),
      });
    }

    if (lv is MatrixValue && rv is MatrixValue) {
      return switch (op) {
        '+' => MatrixValue(lv.matrix + rv.matrix),
        '-' => MatrixValue(lv.matrix - rv.matrix),
        '*' => MatrixValue(lv.matrix * rv.matrix),
        _ => throw ArgumentBindingException(
          "Unsupported matrix operator '$op'",
          offset: offset,
        ),
      };
    }

    if (lv is MatrixValue && rv is ExprValue) {
      return switch (op) {
        '*' => MatrixValue(
          Matrix<Expr>.generate(
            lv.matrix.rowCount,
            lv.matrix.colCount,
            (r, c) => lv.matrix.getUnchecked(r, c) * rv.expr,
            type: exprDataType,
          ),
        ),
        '/' => MatrixValue(
          Matrix<Expr>.generate(
            lv.matrix.rowCount,
            lv.matrix.colCount,
            (r, c) => lv.matrix.getUnchecked(r, c) / rv.expr,
            type: exprDataType,
          ),
        ),
        '^' => () {
          if (rv.expr case IntegerNumber(asInt: final exp?)) {
            if (exp == -1) {
              final inv = lv.matrix.inverse();
              if (inv == null) {
                throw ArgumentBindingException(
                  'Matrix is singular and cannot be inverted',
                  offset: offset,
                );
              }
              return MatrixValue(inv);
            }
            if (exp >= 0) {
              var acc = Matrix<Expr>.identity(
                lv.matrix.rowCount,
                type: exprDataType,
              );
              for (var i = 0; i < exp; i++) {
                acc = acc * lv.matrix;
              }
              return MatrixValue(acc);
            }
          }
          throw ArgumentBindingException(
            'Matrix exponent must be an integer >= -1',
            offset: offset,
          );
        }(),
        _ => throw ArgumentBindingException(
          "Unsupported matrix-scalar operator '$op'",
          offset: offset,
        ),
      };
    }

    if (lv is ExprValue && rv is MatrixValue && op == '*') {
      return MatrixValue(
        Matrix<Expr>.generate(
          rv.matrix.rowCount,
          rv.matrix.colCount,
          (r, c) => lv.expr * rv.matrix.getUnchecked(r, c),
          type: exprDataType,
        ),
      );
    }

    if (lv is MatrixValue && rv is VectorValue && op == '*') {
      final m = lv.matrix;
      final v = rv.vector;
      if (m.colCount != v.length) {
        throw ArgumentBindingException(
          'Matrix columns (${m.colCount}) must match vector length (${v.length})',
          offset: offset,
        );
      }
      return VectorValue(
        Vector<Expr>.generate(m.rowCount, (r) {
          Expr sum = IntegerNumber.zero;
          for (var c = 0; c < m.colCount; c++) {
            sum = sum + m.getUnchecked(r, c) * v.getUnchecked(c);
          }
          return sum;
        }, type: exprDataType),
      );
    }

    if (lv is VectorValue && rv is VectorValue) {
      return switch (op) {
        '+' => VectorValue(lv.vector + rv.vector),
        '-' => VectorValue(lv.vector - rv.vector),
        '*' => ExprValue(
          [
            for (var i = 0; i < lv.vector.length; i++)
              lv.vector.getUnchecked(i) * rv.vector.getUnchecked(i),
          ].fold<Expr>(IntegerNumber.zero, (a, b) => a + b),
        ),
        _ => throw ArgumentBindingException(
          "Unsupported vector operator '$op'",
          offset: offset,
        ),
      };
    }

    if (lv is VectorValue && rv is ExprValue) {
      return switch (op) {
        '*' => VectorValue(
          Vector<Expr>.generate(
            lv.vector.length,
            (i) => lv.vector.getUnchecked(i) * rv.expr,
            type: exprDataType,
          ),
        ),
        '/' => VectorValue(
          Vector<Expr>.generate(
            lv.vector.length,
            (i) => lv.vector.getUnchecked(i) / rv.expr,
            type: exprDataType,
          ),
        ),
        _ => throw ArgumentBindingException(
          "Unsupported vector-scalar operator '$op'",
          offset: offset,
        ),
      };
    }

    if (lv is ExprValue && rv is VectorValue && op == '*') {
      return VectorValue(
        Vector<Expr>.generate(
          rv.vector.length,
          (i) => lv.expr * rv.vector.getUnchecked(i),
          type: exprDataType,
        ),
      );
    }

    throw ArgumentBindingException(
      "Cannot apply '$op' to '${lv.kind}' and '${rv.kind}'",
      offset: offset,
    );
  }
}
