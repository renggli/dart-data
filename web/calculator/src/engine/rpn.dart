import 'package:data/symbolic.dart';

import '../language/ast.dart';
import '../language/grammar.dart';
import '../model/environment.dart';
import '../model/session.dart';
import '../model/stack.dart';
import '../model/value.dart';
import 'commands.dart';
import 'evaluator.dart';

/// RPN stack interpreter operating over [RpnStack], [Session],
/// and [Environment].
final class RpnInterpreter {
  new({required this.stack, required this.evaluator});

  final RpnStack stack;
  final CalcEvaluator evaluator;

  Environment get environment => evaluator.environment;
  Session get session => evaluator.session;

  /// Executes an RPN command line (or empty-line `ENTER` = `DUP`).
  ///
  /// Returns an [ErrorValue] if a syntax or evaluation error occurs, or
  /// `null` on success. If an error occurs, the stack is atomically rolled
  /// back to its pre-execution state without losing arguments.
  ErrorValue? executeLine(String rawLine, {bool forceNumeric = false}) {
    final trimmed = rawLine.trim();
    if (trimmed.isEmpty) {
      final cp = stack.checkpoint();
      try {
        stack.dup();
        return null;
      } catch (e) {
        stack.restoreCheckpoint(cp);
        return ErrorValue(_cleanMsg(e));
      }
    }

    final cp = stack.checkpoint();
    try {
      final grammar = CalcGrammar(
        implicitMultiplication: environment.settings.implicitMultiplication,
      );
      final tokens = grammar.parseRpnTokens(trimmed);
      for (final token in tokens) {
        _executeToken(token);
      }
      if (forceNumeric && !stack.isEmpty) {
        _runNamedCommand('approx');
      }
      return null;
    } on CalcParseException catch (e) {
      stack.restoreCheckpoint(cp);
      return ErrorValue(
        e.message,
        offset: e.offset,
        suggestion: e.suggestion,
        source: rawLine,
      );
    } catch (e) {
      stack.restoreCheckpoint(cp);
      return ErrorValue(_cleanMsg(e), source: rawLine);
    }
  }

  /// Executes a single RPN command or soft-key action by name (`+`, `-`, `*`,
  /// `/`, `^`, `NEG`, `INV`, `DUP`, `DROP`, `SWAP`, `OVER`, `ROT`, `PICK`,
  /// `ROLL`, `DEPTH`, `CLEAR`, `LASTARG`, `UNDO`, `REDO`, `STO`, `RCL`,
  /// `→NUM`, `→Q`, or any canonical command from [CommandRegistry]).
  ///
  /// Atomically rolls back stack state if evaluation throws an error.
  ErrorValue? executeCommand(String rawCommand) {
    final cp = stack.checkpoint();
    try {
      _runNamedCommand(rawCommand);
      return null;
    } catch (e) {
      stack.restoreCheckpoint(cp);
      return ErrorValue(_cleanMsg(e));
    }
  }

  void _executeToken(RpnToken token) {
    switch (token) {
      case RpnPushNodeToken(:final node, :final rawText):
        // In HP48 RPN, a quoted identifier like 'x' or 'a' pushes the raw
        // symbolic Variable('a') without substituting an assigned variable so
        // `'a' STO` and `'x' diff` work even when `a` or `x` has a bound value.
        if (node case SymbolNode(:final name)) {
          final stdConst = ExprSyntax.standardConstants[name];
          final val = ExprValue(stdConst ?? Variable(name));
          _pushResult(val, inputText: "'$rawText'", isLiteralPush: true);
          return;
        }
        final val = evaluator.evalNode(node);
        final simplified = _postProcessValue(val);
        _pushResult(simplified, inputText: rawText, isLiteralPush: true);

      case RpnCommandToken(:final name):
        _runNamedCommand(name);
    }
  }

  void _runNamedCommand(String rawName) {
    final upper = rawName.toUpperCase().trim();
    final lower = rawName.toLowerCase().trim();

    // 0. Parameterized stack commands (e.g., '3 ROLL', '2 DROP', '4 PICK')
    final rollMatch = RegExp(r'^(\d+)\s+ROLL$').firstMatch(upper);
    if (rollMatch != null) {
      final n = int.parse(rollMatch.group(1)!);
      stack.roll(n);
      return;
    }
    final pickMatch = RegExp(r'^(\d+)\s+PICK$').firstMatch(upper);
    if (pickMatch != null) {
      final n = int.parse(pickMatch.group(1)!);
      stack.pick(n);
      return;
    }
    final dropMatch = RegExp(r'^(\d+)\s+DROP$').firstMatch(upper);
    if (dropMatch != null) {
      final n = int.parse(dropMatch.group(1)!);
      stack.dropLevel(n);
      return;
    }

    // 1. Immediate arithmetic operators
    switch (upper) {
      case '+':
        _applyBinaryOp(CalcBinaryOp.add, '+');
        return;
      case '-':
        _applyBinaryOp(CalcBinaryOp.sub, '-');
        return;
      case '*':
        _applyBinaryOp(CalcBinaryOp.mul, '*');
        return;
      case '/':
        _applyBinaryOp(CalcBinaryOp.div, '/');
        return;
      case '^' || 'ˆ' || '\u0302' || '‸' || '＾':
        _applyBinaryOp(CalcBinaryOp.pow, '^');
        return;
      case '²' || '³' || '⁴':
        final exp = switch (upper) {
          '²' => IntegerNumber.two,
          '³' => IntegerNumber.of(3),
          _ => IntegerNumber.of(4),
        };
        final arg = stack.popArgs(1).first;
        final res = evaluator.applyBinaryOp(
          CalcBinaryOp.pow,
          arg.value,
          ExprValue(exp),
        );
        _cleanupPoppedLiterals([arg]);
        _pushResult(
          _postProcessValue(res),
          inputText: '${arg.value.toCanonicalText()}^$exp',
        );
        return;
      case '!':
        final arg = stack.popArgs(1).first;
        final res = evaluator.applyUnaryOp(CalcUnaryOp.factorial, arg.value);
        _cleanupPoppedLiterals([arg]);
        _pushResult(
          _postProcessValue(res),
          inputText: '(${arg.value.toCanonicalText()})!',
        );
        return;
      case 'NEG' || '±':
        final arg = stack.popArgs(1).first;
        final res = evaluator.applyUnaryOp(CalcUnaryOp.negate, arg.value);
        _cleanupPoppedLiterals([arg]);
        _pushResult(
          _postProcessValue(res),
          inputText: '-(${arg.value.toCanonicalText()})',
        );
        return;
      // 2. Stack manipulation commands
      case 'ENTER' || 'DUP' || 'DUPLICATE':
        stack.dup();
        return;
      case 'DROP':
        stack.drop();
        return;
      case 'SWAP':
        stack.swap();
        return;
      case 'OVER':
        stack.over();
        return;
      case 'ROT' || 'ROTATE':
        stack.rot();
        return;
      case 'PICK':
        stack.pick();
        return;
      case 'ROLL':
        stack.roll();
        return;
      case 'DEPTH':
        final cell = session.addResult(
          input: 'DEPTH',
          value: ExprValue(IntegerNumber.of(stack.depth)),
          recordHistory: false,
        );
        stack.push(StackItem(resultId: cell.id, value: cell.value));
        return;
      case 'CLEAR':
        stack.clear();
        return;
      // 3. Variable store / recall: `2: value  1: 'name'  STO`
      case 'STO' || 'STORE':
        final args = stack.popArgs(2);
        final val = args[0].value;
        final target = args[1].value;
        final varName = _extractSymbolName(target, 'STO');
        _cleanupPoppedLiterals(args);
        environment.setVariable(varName, val);
        session.addResult(
          input: '$varName := ${val.toCanonicalText()}',
          value: val,
          assignedSymbol: varName,
          recordHistory: true,
        );
        return;
      case 'RCL' || 'RECALL':
        final popped = stack.popArgs(1).first;
        final varName = _extractSymbolName(popped.value, 'RCL');
        _cleanupPoppedLiterals([popped]);
        final recalled =
            environment.getVariable(varName) ?? ExprValue(Variable(varName));
        _pushResult(recalled, inputText: varName);
        return;
      case 'DELETE':
        final popped = stack.popArgs(1).first;
        final varName = _extractSymbolName(popped.value, 'DELETE');
        _cleanupPoppedLiterals([popped]);
        environment.clearSymbol(varName);
        session.markDependentsStale(changedSymbols: {varName});
        return;
      case 'DEF∫' || 'DEFINT':
        // 4-argument definite integral from stack: 4: expr, 3: var, 2: a, 1: b
        _runRegistryCommand(CommandRegistry.byName['integrate']!, 4);
        return;
    }

    // 4. Built-in constants (`pi`, `e`, `i`, `infinity`)
    if (ExprSyntax.standardConstants.containsKey(rawName)) {
      final c = ExprSyntax.standardConstants[rawName]!;
      _pushResult(ExprValue(c), inputText: rawName, isLiteralPush: true);
      return;
    }

    // 5. CommandRegistry lookup (by canonical name or RPN label)
    final cmd =
        CommandRegistry.byName[lower] ??
        CommandRegistry.all
            .where(
              (c) =>
                  c.rpnLabel.toUpperCase() == upper ||
                  c.name.toUpperCase() == upper,
            )
            .firstOrNull;
    if (cmd != null) {
      _runRegistryCommand(cmd, cmd.rpnArity);
      return;
    }

    // 6. Standard unary / binary math functions (`sin`, `cos`, `sqrt`, `exp`, `ln`, ...)
    if (ExprSyntax.standardUnaryFunctions.containsKey(lower)) {
      final arg = stack.popArgs(1).first;
      final res = evaluator.evalNode(
        CallNode(lower, [_valueToNode(arg.value)]),
      );
      _cleanupPoppedLiterals([arg]);
      _pushResult(
        _postProcessValue(res),
        inputText: '$lower(${arg.value.toCanonicalText()})',
      );
      return;
    }
    if (ExprSyntax.standardBinaryFunctions.containsKey(lower)) {
      final args = stack.popArgs(2);
      final res = evaluator.evalNode(
        CallNode(lower, [
          _valueToNode(args[0].value),
          _valueToNode(args[1].value),
        ]),
      );
      _cleanupPoppedLiterals(args);
      _pushResult(
        _postProcessValue(res),
        inputText:
            '$lower(${args[0].value.toCanonicalText()}, ${args[1].value.toCanonicalText()})',
      );
      return;
    }

    // 7. User-defined function
    final userFn = environment.getFunction(rawName);
    if (userFn != null) {
      final args = stack.popArgs(userFn.params.length);
      final exprArgs = [
        for (final a in args)
          if (a.value is ExprValue)
            (a.value as ExprValue).expr
          else
            throw ArgumentError(
              'User function ${userFn.name} expects scalar expressions.',
            ),
      ];
      final res = ExprValue(userFn.apply(exprArgs));
      _cleanupPoppedLiterals(args);
      _pushResult(
        _postProcessValue(res),
        inputText:
            '${userFn.name}(${args.map((a) => a.value.toCanonicalText()).join(', ')})',
      );
      return;
    }

    // 8. Assigned variable or free symbolic variable push
    final boundVar = environment.getVariable(rawName);
    if (boundVar != null) {
      _pushResult(boundVar, inputText: rawName, isLiteralPush: true);
      return;
    }
    _pushResult(
      ExprValue(Variable(rawName)),
      inputText: rawName,
      isLiteralPush: true,
    );
  }

  void _applyBinaryOp(CalcBinaryOp op, String opSymbol) {
    final args = stack.popArgs(2);
    final res = evaluator.applyBinaryOp(op, args[0].value, args[1].value);
    _cleanupPoppedLiterals(args);
    _pushResult(
      _postProcessValue(res),
      inputText:
          '${args[0].value.toCanonicalText()} $opSymbol ${args[1].value.toCanonicalText()}',
    );
  }

  void _runRegistryCommand(Command cmd, int arity) {
    var effectiveArity = arity;
    var insertZeroPoint = false;

    switch (cmd.name) {
      case 'solve' || 'diff' || 'apart' || 'collect' || 'charpoly':
        if (stack.depth >= 2 && _looksLikeVariable(stack.level(1).value)) {
          effectiveArity = 2;
        } else {
          effectiveArity = 1;
        }
      case 'integrate':
        if (arity == 4) {
          // Explicit DEF∫ (4-arg or 3-arg definite integral)
          if (stack.depth >= 4 && _looksLikeVariable(stack.level(3).value)) {
            effectiveArity = 4;
          } else if (stack.depth >= 3) {
            effectiveArity = 3;
          } else {
            effectiveArity = 4;
          }
        } else if (stack.depth >= 4 &&
            _looksLikeVariable(stack.level(3).value)) {
          effectiveArity = 4;
        } else if (stack.depth >= 2 &&
            _looksLikeVariable(stack.level(1).value)) {
          effectiveArity = 2;
        } else {
          effectiveArity = 1;
        }
      case 'taylor' || 'series':
        if (stack.depth >= 4 && _looksLikeVariable(stack.level(3).value)) {
          effectiveArity = 4;
        } else if (stack.depth >= 3 &&
            _looksLikeVariable(stack.level(2).value)) {
          effectiveArity = 3;
          insertZeroPoint = true;
        } else if (stack.depth >= 2 &&
            _looksLikeInteger(stack.level(1).value) &&
            stack.level(2).value is ExprValue &&
            (stack.level(2).value as ExprValue).expr.freeVariables.isNotEmpty) {
          effectiveArity = 2;
        } else {
          effectiveArity = 1;
        }
      case 'limit':
        if (stack.depth >= 4 && _looksLikeVariable(stack.level(3).value)) {
          effectiveArity = 4;
        } else if (stack.depth >= 3 &&
            _looksLikeVariable(stack.level(2).value)) {
          effectiveArity = 3;
        } else if (stack.depth >= 2 &&
            _looksLikeVariable(stack.level(1).value)) {
          effectiveArity = 2;
        } else {
          effectiveArity = 1;
        }
      case 'gradient' || 'hessian' || 'jacobian':
        if (stack.depth >= 2 &&
            (stack.level(1).value is VectorValue ||
                stack.level(1).value is ListValue)) {
          effectiveArity = 2;
        } else {
          effectiveArity = 1;
        }
      case 'zeros':
        if (stack.depth >= 2 &&
            _looksLikeInteger(stack.level(1).value) &&
            _looksLikeInteger(stack.level(2).value)) {
          effectiveArity = 2;
        } else {
          effectiveArity = 1;
        }
      default:
        break;
    }

    final popped = stack.popArgs(effectiveArity);
    final callArgs = [for (final item in popped) item.value];
    if (insertZeroPoint) {
      callArgs.insert(2, const ExprValue(IntegerNumber.zero));
    }

    final res = cmd.run(
      callArgs,
      EvaluatorContext(environment: environment, session: session),
    );
    _cleanupPoppedLiterals(popped);
    final processed = _postProcessValue(res);
    if (processed is InfoValue &&
        (cmd.name == 'clear' || cmd.name == 'clearall')) {
      return;
    }
    _pushResult(
      processed,
      inputText:
          '${cmd.name}(${callArgs.map((a) => a.toCanonicalText()).join(', ')})',
    );
  }

  void _cleanupPoppedLiterals(List<StackItem> popped) {
    for (final item in popped) {
      if (item.isLiteralPush &&
          !stack.items.any((s) => s.resultId == item.resultId)) {
        session.removeUnreferencedCell(item.resultId);
      }
    }
  }

  void _pushResult(
    CalcValue value, {
    required String inputText,
    bool isLiteralPush = false,
  }) {
    final cell = session.addResult(
      input: inputText,
      value: value,
      recordHistory: true,
    );
    stack.push(
      StackItem(resultId: cell.id, value: value, isLiteralPush: isLiteralPush),
    );
  }

  CalcValue _postProcessValue(CalcValue value) {
    final settings = environment.settings;
    var cur = value;
    if (settings.autoSimplify) {
      cur = switch (cur) {
        ExprValue(:final expr) => ExprValue(
          expr.simplify(assumptions: settings.assumptions),
        ),
        VectorValue(:final vector) => VectorValue(vector.simplify()),
        MatrixValue(:final matrix) => MatrixValue(matrix.simplify()),
        _ => cur,
      };
    }
    if (settings.approxMode) {
      cur = switch (cur) {
        ExprValue(:final expr) => ExprValue(expr.approximate()),
        VectorValue(:final vector) => VectorValue(vector.approximate()),
        MatrixValue(:final matrix) => MatrixValue(matrix.approximate()),
        _ => cur,
      };
    }
    return cur;
  }

  static bool _looksLikeVariable(CalcValue v) =>
      v is ExprValue && v.expr is Variable;

  static bool _looksLikeInteger(CalcValue v) =>
      v is ExprValue && v.expr is IntegerNumber;

  static String _extractSymbolName(CalcValue v, String op) {
    if (v case ExprValue(expr: Variable(:final name))) return name;
    throw ArgumentError('$op expects a variable name (e.g. \'a\') on level 1.');
  }

  static CalcNode _valueToNode(CalcValue v) => switch (v) {
    ExprValue(:final expr) => ExprLeafNode(expr),
    VectorValue(:final vector) => VectorLiteralNode([
      for (var i = 0; i < vector.length; i++)
        ExprLeafNode(vector.getUnchecked(i)),
    ]),
    MatrixValue(:final matrix) => MatrixLiteralNode([
      for (var r = 0; r < matrix.rowCount; r++)
        [
          for (var c = 0; c < matrix.colCount; c++)
            ExprLeafNode(matrix.getUnchecked(r, c)),
        ],
    ]),
    _ => const ExprLeafNode(IntegerNumber.zero),
  };

  static String _cleanMsg(Object error) {
    final s = error.toString();
    for (final p in const [
      'Bad state: ',
      'Invalid argument(s): ',
      'Unsupported operation: ',
    ]) {
      if (s.startsWith(p)) return s.substring(p.length);
    }
    return s;
  }
}
