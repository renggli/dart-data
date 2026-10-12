import 'dart:math' as math;
import 'dart:typed_data';

import 'package:more/number.dart' show Complex;

import '../linear/vector.dart';
import 'algebra/simplify.dart';
import 'ast.dart';

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

  /// Compiles this expression into a fast complex native Dart function
  /// `Complex Function(Complex x)`.
  ///
  /// Conceptually, this converts a symbolic formula into a direct complex
  /// evaluation closure that executes with maximum throughput without AST
  /// dictionary lookups or tree traversals.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final f = (x * x + 1).toComplexFunction1D('x');
  /// final y = f(Complex(0, 1)); // i^2 + 1 = 0
  /// ```
  Complex Function(Complex x) toComplexFunction1D([String variable = 'x']) {
    final simplified = simplify();
    return _compileFastComplex1D(simplified, variable);
  }

  /// Compiles this expression into a high-speed dictionary-based complex closure
  /// `Complex Function(Map<String, Complex> context)`.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final y = Variable('y');
  /// final f = (x + y).compileComplex();
  /// final result = f({'x': Complex(1, 2), 'y': Complex(3, 4)}); // 4 + 6i
  /// ```
  Complex Function(Map<String, Complex> context) compileComplex() {
    final simplified = simplify();
    return _compileComplexEvaluator<Map<String, Complex>>(
      simplified,
      (name) =>
          (context) =>
              context[name] ??
              (throw ArgumentError('Variable "$name" not provided in context')),
    );
  }

  /// Compiles this expression into a fast vector evaluation closure
  /// `double Function(Vector<double>)`.
  ///
  /// Evaluates variables in the positional order defined by [varOrder].
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final y = Variable('y');
  /// final f = (x + y * 2).toVectorFunction(['x', 'y']);
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
  /// final f = (x + y * 2).compile(['x', 'y']);
  /// final result = f([3.0, 4.0]); // 3 + 2(4) = 11.0
  /// ```
  double Function(List<double> args) compile(List<String> varOrder) {
    final simplified = simplify();
    final varIndices = {
      for (var i = 0; i < varOrder.length; i++) varOrder[i]: i,
    };
    return _buildPositionalEvaluator(simplified, varIndices);
  }

  /// Compiles this expression into a zero-allocation, vectorized loop over
  /// contiguous [Float64List] buffers.
  ///
  /// Evaluates variables in the positional order defined by [varOrder].
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final kernel = (x * 2).compileTensorKernel(['x']);
  /// final input = Float64List.fromList([1.0, 2.0, 3.0]);
  /// final output = Float64List(3);
  /// kernel([input], output);
  /// ```
  void Function(List<Float64List> inputs, Float64List output)
  compileTensorKernel(List<String> varOrder) {
    final simplified = simplify();
    final varIndices = {
      for (var i = 0; i < varOrder.length; i++) varOrder[i]: i,
    };
    final instructions = <_Instruction>[];
    _flattenToRpn(simplified, varIndices, instructions);
    final maxStack = _computeMaxStack(instructions);
    final stack = Float64List(maxStack);
    final instrs = instructions;
    final numInstrs = instrs.length;

    return (List<Float64List> inputs, Float64List output) {
      final len = output.length;

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
            case _Op.tan:
              stack[sp - 1] = math.tan(stack[sp - 1]);
            case _Op.asin:
              stack[sp - 1] = math.asin(stack[sp - 1]);
            case _Op.acos:
              stack[sp - 1] = math.acos(stack[sp - 1]);
            case _Op.atan:
              stack[sp - 1] = math.atan(stack[sp - 1]);
            case _Op.sinh:
              final v = stack[sp - 1];
              stack[sp - 1] = (math.exp(v) - math.exp(-v)) / 2.0;
            case _Op.cosh:
              final v = stack[sp - 1];
              stack[sp - 1] = (math.exp(v) + math.exp(-v)) / 2.0;
            case _Op.tanh:
              final v = stack[sp - 1];
              if (v > 20.0) {
                stack[sp - 1] = 1.0;
              } else if (v < -20.0) {
                stack[sp - 1] = -1.0;
              } else {
                final e2 = math.exp(2.0 * v);
                stack[sp - 1] = (e2 - 1.0) / (e2 + 1.0);
              }
            case _Op.abs:
              stack[sp - 1] = stack[sp - 1].abs();
            case _Op.sqrt:
              stack[sp - 1] = math.sqrt(stack[sp - 1]);
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
) => _compileEvaluator<double>(
  expression,
  (name) => name == variableName ? (x) => x : (_) => 0.0,
);

double Function(List<double> args) _buildPositionalEvaluator(
  Expr expression,
  Map<String, int> indices,
) => _compileEvaluator<List<double>>(expression, (name) {
  final idx = indices[name] ?? (throw ArgumentError('Unbound variable: $name'));
  return (args) => args[idx];
});

double Function(Vector<double> args) _buildVectorEvaluator(
  Expr expression,
  Map<String, int> indices,
) => _compileEvaluator<Vector<double>>(expression, (name) {
  final idx = indices[name] ?? (throw ArgumentError('Unbound variable: $name'));
  return (args) => args[idx];
});

double Function(T) _compileEvaluator<T>(
  Expr expression,
  double Function(T) Function(String name) compileVar,
) {
  switch (expression) {
    case ConstantNumber(name: 'i'):
      throw UnsupportedError(
        'Expression contains imaginary constant "i"; use toComplexFunction1D instead.',
      );
    case ComplexNumber():
      throw UnsupportedError(
        'Expression contains ComplexNumber; use toComplexFunction1D instead.',
      );
    case Number(:final value):
      return (_) => value;
    case Variable(:final name):
      return compileVar(name);
    case Add(:final left, :final right):
      final fL = _compileEvaluator<T>(left, compileVar);
      final fR = _compileEvaluator<T>(right, compileVar);
      return (t) => fL(t) + fR(t);
    case Sub(:final left, :final right):
      final fL = _compileEvaluator<T>(left, compileVar);
      final fR = _compileEvaluator<T>(right, compileVar);
      return (t) => fL(t) - fR(t);
    case Mul(:final left, :final right):
      final fL = _compileEvaluator<T>(left, compileVar);
      final fR = _compileEvaluator<T>(right, compileVar);
      return (t) => fL(t) * fR(t);
    case Div(:final left, :final right):
      final fL = _compileEvaluator<T>(left, compileVar);
      final fR = _compileEvaluator<T>(right, compileVar);
      return (t) => fL(t) / fR(t);
    case Pow(
      :final base,
      exponent: RationalNumber(numerator: 1, denominator: 2) ||
          RealNumber(value: 0.5),
    ):
      final fB = _compileEvaluator<T>(base, compileVar);
      return (t) => math.sqrt(fB(t));
    case Pow(:final base, :final exponent):
      final fB = _compileEvaluator<T>(base, compileVar);
      final fE = _compileEvaluator<T>(exponent, compileVar);
      return (t) => math.pow(fB(t), fE(t)).toDouble();
    case Neg(:final expr):
      final fn = _compileEvaluator<T>(expr, compileVar);
      return (t) => -fn(t);
    case Sin(:final expr):
      final fn = _compileEvaluator<T>(expr, compileVar);
      return (t) => math.sin(fn(t));
    case Cos(:final expr):
      final fn = _compileEvaluator<T>(expr, compileVar);
      return (t) => math.cos(fn(t));
    case Exp(:final expr):
      final fn = _compileEvaluator<T>(expr, compileVar);
      return (t) => math.exp(fn(t));
    case Ln(:final expr):
      final fn = _compileEvaluator<T>(expr, compileVar);
      return (t) => math.log(fn(t));
    case Tan(:final expr):
      final fn = _compileEvaluator<T>(expr, compileVar);
      return (t) => math.tan(fn(t));
    case Asin(:final expr):
      final fn = _compileEvaluator<T>(expr, compileVar);
      return (t) => math.asin(fn(t));
    case Acos(:final expr):
      final fn = _compileEvaluator<T>(expr, compileVar);
      return (t) => math.acos(fn(t));
    case Atan(:final expr):
      final fn = _compileEvaluator<T>(expr, compileVar);
      return (t) => math.atan(fn(t));
    case Sinh(:final expr):
      final fn = _compileEvaluator<T>(expr, compileVar);
      return (t) {
        final v = fn(t);
        return (math.exp(v) - math.exp(-v)) / 2.0;
      };
    case Cosh(:final expr):
      final fn = _compileEvaluator<T>(expr, compileVar);
      return (t) {
        final v = fn(t);
        return (math.exp(v) + math.exp(-v)) / 2.0;
      };
    case Tanh(:final expr):
      final fn = _compileEvaluator<T>(expr, compileVar);
      return (t) {
        final v = fn(t);
        if (v > 20.0) return 1.0;
        if (v < -20.0) return -1.0;
        final e2 = math.exp(2.0 * v);
        return (e2 - 1.0) / (e2 + 1.0);
      };
    case Abs(:final expr):
      final fn = _compileEvaluator<T>(expr, compileVar);
      return (t) => fn(t).abs();
    case Log(:final base, :final expr):
      final fB = _compileEvaluator<T>(base, compileVar);
      final fE = _compileEvaluator<T>(expr, compileVar);
      return (t) => math.log(fE(t)) / math.log(fB(t));
  }
}

void _flattenToRpn(
  Expr expr,
  Map<String, int> varIndices,
  List<_Instruction> instructions,
) {
  switch (expr) {
    case ConstantNumber(name: 'i'):
      throw UnsupportedError(
        'compileTensorKernel does not support expressions with imaginary constant "i".',
      );
    case ComplexNumber():
      throw UnsupportedError(
        'compileTensorKernel does not support expressions with ComplexNumber.',
      );
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
    case Pow(
      :final base,
      exponent: RationalNumber(numerator: 1, denominator: 2) ||
          RealNumber(value: 0.5),
    ):
      _flattenToRpn(base, varIndices, instructions);
      instructions.add(const _Instruction.op(_Op.sqrt));
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
    case Tan(:final expr):
      _flattenToRpn(expr, varIndices, instructions);
      instructions.add(const _Instruction.op(_Op.tan));
    case Asin(:final expr):
      _flattenToRpn(expr, varIndices, instructions);
      instructions.add(const _Instruction.op(_Op.asin));
    case Acos(:final expr):
      _flattenToRpn(expr, varIndices, instructions);
      instructions.add(const _Instruction.op(_Op.acos));
    case Atan(:final expr):
      _flattenToRpn(expr, varIndices, instructions);
      instructions.add(const _Instruction.op(_Op.atan));
    case Sinh(:final expr):
      _flattenToRpn(expr, varIndices, instructions);
      instructions.add(const _Instruction.op(_Op.sinh));
    case Cosh(:final expr):
      _flattenToRpn(expr, varIndices, instructions);
      instructions.add(const _Instruction.op(_Op.cosh));
    case Tanh(:final expr):
      _flattenToRpn(expr, varIndices, instructions);
      instructions.add(const _Instruction.op(_Op.tanh));
    case Abs(:final expr):
      _flattenToRpn(expr, varIndices, instructions);
      instructions.add(const _Instruction.op(_Op.abs));
    case Log(:final base, :final expr):
      _flattenToRpn(expr, varIndices, instructions);
      instructions.add(const _Instruction.op(_Op.ln));
      _flattenToRpn(base, varIndices, instructions);
      instructions.add(const _Instruction.op(_Op.ln));
      instructions.add(const _Instruction.op(_Op.div));
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
      case _Op.neg ||
          _Op.sin ||
          _Op.cos ||
          _Op.exp ||
          _Op.ln ||
          _Op.tan ||
          _Op.asin ||
          _Op.acos ||
          _Op.atan ||
          _Op.sinh ||
          _Op.cosh ||
          _Op.tanh ||
          _Op.abs ||
          _Op.sqrt:
        break;
    }
    if (current > maxDepth) {
      maxDepth = current;
    }
  }
  return math.max(maxDepth, 1);
}

enum _Op {
  pushConst,
  loadVar,
  add,
  sub,
  mul,
  div,
  pow,
  neg,
  sin,
  cos,
  exp,
  ln,
  tan,
  asin,
  acos,
  atan,
  sinh,
  cosh,
  tanh,
  abs,
  sqrt,
}

final class _Instruction {
  const new _(this.op, this.constValue, this.varIndex);
  const new pushConst(double val) : this._(_Op.pushConst, val, 0);
  const new loadVar(int idx) : this._(_Op.loadVar, 0.0, idx);
  const new op(_Op op) : this._(op, 0.0, 0);

  final _Op op;
  final double constValue;
  final int varIndex;
}

Complex Function(Complex x) _compileFastComplex1D(
  Expr expression,
  String variableName,
) => _compileComplexEvaluator<Complex>(
  expression,
  (name) => name == variableName ? (x) => x : (_) => Complex.zero,
);

Complex Function(T) _compileComplexEvaluator<T>(
  Expr expression,
  Complex Function(T) Function(String name) compileVar,
) {
  switch (expression) {
    case Variable(:final name):
      return compileVar(name);
    case Number():
      final c = expression.complexValue;
      return (_) => c;
    case Add(:final left, :final right):
      final fL = _compileComplexEvaluator<T>(left, compileVar);
      final fR = _compileComplexEvaluator<T>(right, compileVar);
      return (t) => fL(t) + fR(t);
    case Sub(:final left, :final right):
      final fL = _compileComplexEvaluator<T>(left, compileVar);
      final fR = _compileComplexEvaluator<T>(right, compileVar);
      return (t) => fL(t) - fR(t);
    case Mul(:final left, :final right):
      final fL = _compileComplexEvaluator<T>(left, compileVar);
      final fR = _compileComplexEvaluator<T>(right, compileVar);
      return (t) => fL(t) * fR(t);
    case Div(:final left, :final right):
      final fL = _compileComplexEvaluator<T>(left, compileVar);
      final fR = _compileComplexEvaluator<T>(right, compileVar);
      return (t) => fL(t) / fR(t);
    case Pow(:final base, :final exponent):
      final fB = _compileComplexEvaluator<T>(base, compileVar);
      final fE = _compileComplexEvaluator<T>(exponent, compileVar);
      return (t) => _complexPow(fB(t), fE(t));
    case Neg(:final expr):
      final fn = _compileComplexEvaluator<T>(expr, compileVar);
      return (t) => -fn(t);
    case Sin(:final expr):
      final fn = _compileComplexEvaluator<T>(expr, compileVar);
      return (t) => fn(t).sin();
    case Cos(:final expr):
      final fn = _compileComplexEvaluator<T>(expr, compileVar);
      return (t) => fn(t).cos();
    case Tan(:final expr):
      final fn = _compileComplexEvaluator<T>(expr, compileVar);
      return (t) => fn(t).tan();
    case Asin(:final expr):
      final fn = _compileComplexEvaluator<T>(expr, compileVar);
      return (t) => fn(t).asin();
    case Acos(:final expr):
      final fn = _compileComplexEvaluator<T>(expr, compileVar);
      return (t) => fn(t).acos();
    case Atan(:final expr):
      final fn = _compileComplexEvaluator<T>(expr, compileVar);
      return (t) => fn(t).atan();
    case Sinh(:final expr):
      final fn = _compileComplexEvaluator<T>(expr, compileVar);
      return (t) => fn(t).sinh();
    case Cosh(:final expr):
      final fn = _compileComplexEvaluator<T>(expr, compileVar);
      return (t) => fn(t).cosh();
    case Tanh(:final expr):
      final fn = _compileComplexEvaluator<T>(expr, compileVar);
      return (t) => fn(t).tanh();
    case Exp(:final expr):
      final fn = _compileComplexEvaluator<T>(expr, compileVar);
      return (t) => fn(t).exp();
    case Ln(:final expr):
      final fn = _compileComplexEvaluator<T>(expr, compileVar);
      return (t) => fn(t).log();
    case Log(:final base, :final expr):
      final fB = _compileComplexEvaluator<T>(base, compileVar);
      final fE = _compileComplexEvaluator<T>(expr, compileVar);
      return (t) => fE(t).log() / fB(t).log();
    case Abs(:final expr):
      final fn = _compileComplexEvaluator<T>(expr, compileVar);
      return (t) => Complex(fn(t).abs(), 0);
  }
}

Complex _complexPow(Complex base, Complex exponent) {
  if (base.a == 0 && base.b == 0) {
    if (exponent.a == 0 && exponent.b == 0) return Complex.one;
    if (exponent.a > 0) return Complex.zero;
    if (exponent.a < 0) {
      return exponent.b == 0
          ? const Complex(double.infinity, 0.0)
          : const Complex(double.infinity, double.nan);
    }
    return Complex.nan;
  }
  return base.pow(exponent);
}
