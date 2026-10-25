import 'package:data/symbolic.dart';

import '../language/ast.dart';
import '../language/grammar.dart';
import '../model/environment.dart';
import '../model/session.dart';
import '../model/stack.dart';
import '../model/value.dart';
import 'commands.dart';
import 'evaluator.dart';

/// HP48-style RPN stack interpreter operating over [RpnStack], [Session],
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
          _pushResult(val, inputText: "'$rawText'");
          return;
        }
        final val = evaluator.evalNode(node);
        final simplified = _postProcessValue(val);
        _pushResult(simplified, inputText: rawText);

      case RpnCommandToken(:final name):
        _runNamedCommand(name);
    }
  }

  void _runNamedCommand(String rawName) {
    final upper = rawName.toUpperCase();
    final lower = rawName.toLowerCase();

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
        _pushResult(
          _postProcessValue(res),
          inputText: '${arg.value.toCanonicalText()}^$exp',
          recordUndo: false,
        );
        return;
      case '!':
        final arg = stack.popArgs(1).first;
        final res = evaluator.applyUnaryOp(CalcUnaryOp.factorial, arg.value);
        _pushResult(_postProcessValue(res), inputText: '!', recordUndo: false);
        return;
      case 'NEG' || 'CHS' || '±':
        final arg = stack.popArgs(1).first;
        final res = evaluator.applyUnaryOp(CalcUnaryOp.negate, arg.value);
        _pushResult(
          _postProcessValue(res),
          inputText: 'NEG',
          recordUndo: false,
        );
        return;
      // 2. Stack manipulation commands
      case 'ENTER' || 'DUP':
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
      case 'ROT':
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
      case 'LASTARG':
        stack.recallLastArgs();
        return;
      case 'UNDO':
        stack.undo();
        return;
      case 'REDO':
        stack.redo();
        return;
      // 3. Variable store / recall: `2: value  1: 'name'  STO`
      case 'STO':
        final args = stack.popArgs(2);
        final val = args[0].value;
        final target = args[1].value;
        final varName = _extractSymbolName(target, 'STO');
        environment.setVariable(varName, val);
        session.markDependentsStale(changedSymbols: {varName});
        return;
      case 'RCL':
        final top = stack.popArgs(1).first.value;
        final varName = _extractSymbolName(top, 'RCL');
        final recalled =
            environment.getVariable(varName) ?? ExprValue(Variable(varName));
        _pushResult(recalled, inputText: 'RCL($varName)', recordUndo: false);
        return;
      case '→NUM' || '->NUM' || 'NUM':
        _runRegistryCommand(CommandRegistry.byName['approx']!, 1);
        return;
      case '→Q' || '->Q':
        _runRegistryCommand(CommandRegistry.byName['exact']!, 1);
        return;
      case 'DEF∫' || 'DEFINT':
        // 4-argument definite integral from stack: 4: expr, 3: var, 2: a, 1: b
        _runRegistryCommand(CommandRegistry.byName['integrate']!, 4);
        return;
    }

    // 4. Built-in constants (`pi`, `e`, `i`, `infinity`)
    if (ExprSyntax.standardConstants.containsKey(rawName)) {
      final c = ExprSyntax.standardConstants[rawName]!;
      _pushResult(ExprValue(c), inputText: rawName);
      return;
    }

    // 5. CommandRegistry lookup (including RPN label aliases)
    final cmd =
        CommandRegistry.byName[lower] ??
        CommandRegistry.all
            .where((c) => c.rpnLabel.toUpperCase() == upper)
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
      _pushResult(
        _postProcessValue(res),
        inputText: '$lower(${arg.value.toCanonicalText()})',
        recordUndo: false,
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
      _pushResult(
        _postProcessValue(res),
        inputText: '$lower(...)',
        recordUndo: false,
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
      _pushResult(
        _postProcessValue(res),
        inputText: '${userFn.name}(...)',
        recordUndo: false,
      );
      return;
    }

    // 8. Assigned variable or free symbolic variable push
    final boundVar = environment.getVariable(rawName);
    if (boundVar != null) {
      _pushResult(boundVar, inputText: rawName);
      return;
    }
    _pushResult(ExprValue(Variable(rawName)), inputText: rawName);
  }

  void _applyBinaryOp(CalcBinaryOp op, String opSymbol) {
    final args = stack.popArgs(2);
    final res = evaluator.applyBinaryOp(op, args[0].value, args[1].value);
    _pushResult(
      _postProcessValue(res),
      inputText:
          '${args[0].value.toCanonicalText()} $opSymbol ${args[1].value.toCanonicalText()}',
      recordUndo: false,
    );
  }

  void _runRegistryCommand(Command cmd, int arity) {
    // Special HP48 argument order handling for taylor/series:
    // If stack has 3 arguments and level 2 is a Variable ('x') and level 1 is an integer (order),
    // treat as taylor(expr, 'x', 0, order) so 3-arg HP48 entry works alongside 4-arg entry.
    var effectiveArity = arity;
    var insertZeroPoint = false;
    if ((cmd.name == 'taylor' || cmd.name == 'series') &&
        stack.depth >= 3 &&
        (stack.depth < 4 || !_looksLikeVariable(stack.level(3).value)) &&
        _looksLikeVariable(stack.level(2).value)) {
      effectiveArity = 3;
      insertZeroPoint = true;
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
    final processed = _postProcessValue(res);
    if (processed is InfoValue &&
        (cmd.name == 'clear' || cmd.name == 'clearall')) {
      return;
    }
    _pushResult(
      processed,
      inputText:
          '${cmd.name}(${callArgs.map((a) => a.toCanonicalText()).join(', ')})',
      recordUndo: false,
    );
  }

  void _pushResult(
    CalcValue value, {
    required String inputText,
    bool recordUndo = true,
  }) {
    final cell = session.addResult(
      input: inputText,
      value: value,
      recordHistory: true,
    );
    stack.push(
      StackItem(resultId: cell.id, value: value),
      recordUndo: recordUndo,
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
