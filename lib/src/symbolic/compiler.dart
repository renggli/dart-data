import 'dart:math' as math;
import 'dart:typed_data';

import '../linear/vector.dart';
import 'ast.dart';
import 'simplifier.dart';

/// Extension providing zero-allocation high-throughput compilation of symbolic
/// expressions.
extension CompilerExtension on Expr {
  /// Compiles this expression into a fast native Dart function
  /// `double Function(double)`.
  ///
  /// Conceptually, this converts a symbolic formula into a standard Dart
  /// function that executes with maximum speed without AST dictionary lookups
  /// or tree traversals. Formally, it eliminates AST traversal overhead by
  /// synthesizing an inlined closure tree suitable for tight numerical inner
  /// loops (such as Monte Carlo simulations or ODE integrators).
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final f = (x * x + 1).toFunction1D('x');
  /// final y = f(3.0); // 10.0
  /// ```
  double Function(double x) toFunction1D(String varName) {
    final simplified = simplify();
    return _compileFast1D(simplified, varName);
  }

  /// Alias for [toFunction1D].
  double Function(double x) compile1D(String varName) => toFunction1D(varName);

  /// Compiles this expression into a fast vector evaluation closure
  /// `double Function(Vector<double>)`.
  ///
  /// Evaluates variables in the positional order defined by [varOrder].
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final y = Variable('y');
  /// final f = (x + 2 * y).toVectorFunction(['x', 'y']);
  /// final result = f(Vector.fromList([3.0, 4.0])); // 3 + 2(4) = 11.0
  /// ```
  double Function(Vector<double> vector) toVectorFunction(
    List<String> varOrder,
  ) {
    final simplified = simplify();
    final varIndices = {
      for (var i = 0; i < varOrder.length; i++) varOrder[i]: i,
    };
    return _buildVectorEvaluator(simplified, varIndices);
  }

  /// Compiles this expression into a multi-variable positional closure
  /// `double Function(List<double> args)`.
  ///
  /// Evaluates variables in the positional order defined by [varOrder].
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final y = Variable('y');
  /// final f = (x + 2 * y).compile(['x', 'y']);
  /// final result = f([3.0, 4.0]); // 3 + 2(4) = 11.0
  /// ```
  double Function(List<double> args) compile(List<String> varOrder) {
    final simplified = simplify();
    final varIndices = {
      for (var i = 0; i < varOrder.length; i++) varOrder[i]: i,
    };
    return _buildPositionalEvaluator(simplified, varIndices);
  }

  /// Compiles expression into a zero-allocation, vectorized loop over
  /// contiguous [Float64List] buffers.
  void Function(List<Float64List> inputs, Float64List output)
  compileTensorKernel(List<String> varOrder) {
    final simplified = simplify();
    final varIndices = {
      for (var i = 0; i < varOrder.length; i++) varOrder[i]: i,
    };
    final instructions = <_Instruction>[];
    _flattenToRpn(simplified, varIndices, instructions);
    final maxStack = _computeMaxStack(instructions);

    return (List<Float64List> inputs, Float64List output) {
      final len = output.length;
      final stack = Float64List(maxStack);
      final instrs = instructions;
      final numInstrs = instrs.length;

      for (var i = 0; i < len; i++) {
        var sp = 0;
        for (var pc = 0; pc < numInstrs; pc++) {
          final instr = instrs[pc];
          switch (instr.op) {
            case _Op.pushConst:
              stack[sp++] = instr.constValue;
            case _Op.loadVar:
              stack[sp++] = inputs[instr.varIndex][i];
            case _Op.add:
              final b = stack[--sp];
              final a = stack[--sp];
              stack[sp++] = a + b;
            case _Op.sub:
              final b = stack[--sp];
              final a = stack[--sp];
              stack[sp++] = a - b;
            case _Op.mul:
              final b = stack[--sp];
              final a = stack[--sp];
              stack[sp++] = a * b;
            case _Op.div:
              final b = stack[--sp];
              final a = stack[--sp];
              stack[sp++] = a / b;
            case _Op.pow:
              final b = stack[--sp];
              final a = stack[--sp];
              stack[sp++] = math.pow(a, b).toDouble();
            case _Op.neg:
              stack[sp - 1] = -stack[sp - 1];
            case _Op.sin:
              stack[sp - 1] = math.sin(stack[sp - 1]);
            case _Op.cos:
              stack[sp - 1] = math.cos(stack[sp - 1]);
            case _Op.exp:
              stack[sp - 1] = math.exp(stack[sp - 1]);
            case _Op.ln:
              stack[sp - 1] = math.log(stack[sp - 1]);
          }
        }
        output[i] = stack[0];
      }
    };
  }
}

/// Extension providing compilation of collections of symbolic expressions.
extension CompilerIterableExtension on Iterable<Expr> {
  /// Compiles multiple expressions into a vector-valued closure
  /// `Vector<double> Function(Vector<double>)`.
  ///
  /// Evaluates variables in the positional order defined by [varOrder].
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final y = Variable('y');
  /// final system = [x + y, x - y].toVectorFunction(['x', 'y']);
  /// final res = system(Vector.fromList([3.0, 1.0])); // [4.0, 2.0]
  /// ```
  Vector<double> Function(Vector<double> vector) toVectorFunction(
    List<String> varOrder,
  ) {
    final evaluators = [
      for (final expr in this) expr.toVectorFunction(varOrder),
    ];
    return (Vector<double> v) =>
        Vector.generate(evaluators.length, (i) => evaluators[i](v));
  }
}

double Function(double x) _compileFast1D(
  Expr expression,
  String variableName,
) => switch (expression) {
  Number(value: final val) => (_) => val,
  Variable(name: final name) => name == variableName ? (x) => x : (_) => 0.0,
  Add(left: final left, right: final right) => () {
    final fL = _compileFast1D(left, variableName),
        fR = _compileFast1D(right, variableName);
    return (double x) => fL(x) + fR(x);
  }(),
  Sub(left: final left, right: final right) => () {
    final fL = _compileFast1D(left, variableName),
        fR = _compileFast1D(right, variableName);
    return (double x) => fL(x) - fR(x);
  }(),
  Mul(left: final left, right: final right) => () {
    final fL = _compileFast1D(left, variableName),
        fR = _compileFast1D(right, variableName);
    return (double x) => fL(x) * fR(x);
  }(),
  Div(left: final left, right: final right) => () {
    final fL = _compileFast1D(left, variableName),
        fR = _compileFast1D(right, variableName);
    return (double x) => fL(x) / fR(x);
  }(),
  Pow(base: final base, exponent: final exp) => () {
    final fB = _compileFast1D(base, variableName),
        fE = _compileFast1D(exp, variableName);
    return (double x) => math.pow(fB(x), fE(x)).toDouble();
  }(),
  Neg(expr: final inner) => () {
    final fn = _compileFast1D(inner, variableName);
    return (double x) => -fn(x);
  }(),
  Sin(expr: final inner) => () {
    final fn = _compileFast1D(inner, variableName);
    return (double x) => math.sin(fn(x));
  }(),
  Cos(expr: final inner) => () {
    final fn = _compileFast1D(inner, variableName);
    return (double x) => math.cos(fn(x));
  }(),
  Exp(expr: final inner) => () {
    final fn = _compileFast1D(inner, variableName);
    return (double x) => math.exp(fn(x));
  }(),
  Ln(expr: final inner) => () {
    final fn = _compileFast1D(inner, variableName);
    return (double x) => math.log(fn(x));
  }(),
};

double Function(List<double> args) _buildPositionalEvaluator(
  Expr expression,
  Map<String, int> indices,
) => switch (expression) {
  Number(value: final val) => (_) => val,
  Variable(name: final name) => () {
    final idx =
        indices[name] ?? (throw ArgumentError('Unbound variable: $name'));
    return (List<double> args) => args[idx];
  }(),
  Add(left: final left, right: final right) => () {
    final fL = _buildPositionalEvaluator(left, indices),
        fR = _buildPositionalEvaluator(right, indices);
    return (List<double> args) => fL(args) + fR(args);
  }(),
  Sub(left: final left, right: final right) => () {
    final fL = _buildPositionalEvaluator(left, indices),
        fR = _buildPositionalEvaluator(right, indices);
    return (List<double> args) => fL(args) - fR(args);
  }(),
  Mul(left: final left, right: final right) => () {
    final fL = _buildPositionalEvaluator(left, indices),
        fR = _buildPositionalEvaluator(right, indices);
    return (List<double> args) => fL(args) * fR(args);
  }(),
  Div(left: final left, right: final right) => () {
    final fL = _buildPositionalEvaluator(left, indices),
        fR = _buildPositionalEvaluator(right, indices);
    return (List<double> args) => fL(args) / fR(args);
  }(),
  Pow(base: final base, exponent: final exp) => () {
    final fB = _buildPositionalEvaluator(base, indices),
        fE = _buildPositionalEvaluator(exp, indices);
    return (List<double> args) => math.pow(fB(args), fE(args)).toDouble();
  }(),
  Neg(expr: final inner) => () {
    final fn = _buildPositionalEvaluator(inner, indices);
    return (List<double> args) => -fn(args);
  }(),
  Sin(expr: final inner) => () {
    final fn = _buildPositionalEvaluator(inner, indices);
    return (List<double> args) => math.sin(fn(args));
  }(),
  Cos(expr: final inner) => () {
    final fn = _buildPositionalEvaluator(inner, indices);
    return (List<double> args) => math.cos(fn(args));
  }(),
  Exp(expr: final inner) => () {
    final fn = _buildPositionalEvaluator(inner, indices);
    return (List<double> args) => math.exp(fn(args));
  }(),
  Ln(expr: final inner) => () {
    final fn = _buildPositionalEvaluator(inner, indices);
    return (List<double> args) => math.log(fn(args));
  }(),
};

double Function(Vector<double> args) _buildVectorEvaluator(
  Expr expression,
  Map<String, int> indices,
) => switch (expression) {
  Number(value: final val) => (_) => val,
  Variable(name: final name) => () {
    final idx =
        indices[name] ?? (throw ArgumentError('Unbound variable: $name'));
    return (Vector<double> args) => args[idx];
  }(),
  Add(left: final left, right: final right) => () {
    final fL = _buildVectorEvaluator(left, indices),
        fR = _buildVectorEvaluator(right, indices);
    return (Vector<double> args) => fL(args) + fR(args);
  }(),
  Sub(left: final left, right: final right) => () {
    final fL = _buildVectorEvaluator(left, indices),
        fR = _buildVectorEvaluator(right, indices);
    return (Vector<double> args) => fL(args) - fR(args);
  }(),
  Mul(left: final left, right: final right) => () {
    final fL = _buildVectorEvaluator(left, indices),
        fR = _buildVectorEvaluator(right, indices);
    return (Vector<double> args) => fL(args) * fR(args);
  }(),
  Div(left: final left, right: final right) => () {
    final fL = _buildVectorEvaluator(left, indices),
        fR = _buildVectorEvaluator(right, indices);
    return (Vector<double> args) => fL(args) / fR(args);
  }(),
  Pow(base: final base, exponent: final exp) => () {
    final fB = _buildVectorEvaluator(base, indices),
        fE = _buildVectorEvaluator(exp, indices);
    return (Vector<double> args) => math.pow(fB(args), fE(args)).toDouble();
  }(),
  Neg(expr: final inner) => () {
    final fn = _buildVectorEvaluator(inner, indices);
    return (Vector<double> args) => -fn(args);
  }(),
  Sin(expr: final inner) => () {
    final fn = _buildVectorEvaluator(inner, indices);
    return (Vector<double> args) => math.sin(fn(args));
  }(),
  Cos(expr: final inner) => () {
    final fn = _buildVectorEvaluator(inner, indices);
    return (Vector<double> args) => math.cos(fn(args));
  }(),
  Exp(expr: final inner) => () {
    final fn = _buildVectorEvaluator(inner, indices);
    return (Vector<double> args) => math.exp(fn(args));
  }(),
  Ln(expr: final inner) => () {
    final fn = _buildVectorEvaluator(inner, indices);
    return (Vector<double> args) => math.log(fn(args));
  }(),
};

void _flattenToRpn(
  Expr expr,
  Map<String, int> varIndices,
  List<_Instruction> instructions,
) {
  switch (expr) {
    case Number(:final value):
      instructions.add(_Instruction.pushConst(value));
    case Variable(:final name):
      final idx = varIndices[name];
      if (idx == null) {
        throw ArgumentError('Unbound variable: $name');
      }
      instructions.add(_Instruction.loadVar(idx));
    case Add(:final left, :final right):
      _flattenToRpn(left, varIndices, instructions);
      _flattenToRpn(right, varIndices, instructions);
      instructions.add(const _Instruction.op(_Op.add));
    case Sub(:final left, :final right):
      _flattenToRpn(left, varIndices, instructions);
      _flattenToRpn(right, varIndices, instructions);
      instructions.add(const _Instruction.op(_Op.sub));
    case Mul(:final left, :final right):
      _flattenToRpn(left, varIndices, instructions);
      _flattenToRpn(right, varIndices, instructions);
      instructions.add(const _Instruction.op(_Op.mul));
    case Div(:final left, :final right):
      _flattenToRpn(left, varIndices, instructions);
      _flattenToRpn(right, varIndices, instructions);
      instructions.add(const _Instruction.op(_Op.div));
    case Pow(:final base, :final exponent):
      _flattenToRpn(base, varIndices, instructions);
      _flattenToRpn(exponent, varIndices, instructions);
      instructions.add(const _Instruction.op(_Op.pow));
    case Neg(:final expr):
      _flattenToRpn(expr, varIndices, instructions);
      instructions.add(const _Instruction.op(_Op.neg));
    case Sin(:final expr):
      _flattenToRpn(expr, varIndices, instructions);
      instructions.add(const _Instruction.op(_Op.sin));
    case Cos(:final expr):
      _flattenToRpn(expr, varIndices, instructions);
      instructions.add(const _Instruction.op(_Op.cos));
    case Exp(:final expr):
      _flattenToRpn(expr, varIndices, instructions);
      instructions.add(const _Instruction.op(_Op.exp));
    case Ln(:final expr):
      _flattenToRpn(expr, varIndices, instructions);
      instructions.add(const _Instruction.op(_Op.ln));
  }
}

int _computeMaxStack(List<_Instruction> instructions) {
  var current = 0;
  var maxDepth = 0;
  for (final instr in instructions) {
    switch (instr.op) {
      case _Op.pushConst || _Op.loadVar:
        current++;
      case _Op.add || _Op.sub || _Op.mul || _Op.div || _Op.pow:
        current--;
      case _Op.neg || _Op.sin || _Op.cos || _Op.exp || _Op.ln:
        break;
    }
    if (current > maxDepth) {
      maxDepth = current;
    }
  }
  return math.max(maxDepth, 1);
}

enum _Op { pushConst, loadVar, add, sub, mul, div, pow, neg, sin, cos, exp, ln }

final class _Instruction {
  const new _(this.op, this.constValue, this.varIndex);
  const new pushConst(double val) : this._(_Op.pushConst, val, 0);
  const new loadVar(int idx) : this._(_Op.loadVar, 0.0, idx);
  const new op(_Op op) : this._(op, 0.0, 0);

  final _Op op;
  final double constValue;
  final int varIndex;
}
