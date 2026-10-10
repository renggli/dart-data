import 'dart:math' as math;
import 'dart:typed_data';

import 'ast.dart';

/// Extension providing zero-allocation high-throughput compilation of symbolic expressions.
extension ExprCompiler on Expr {
  /// Compiles into a direct [double Function(double)] with ZERO AST walking or Map overhead.
  double Function(double x) compile1D(String varName) {
    final simplified = simplify();
    return _compileFast1D(simplified, varName);
  }

  /// Compiles into a multi-variable positional closure [double Function(List<double> args)].
  double Function(List<double> args) compile(List<String> varOrder) {
    final simplified = simplify();
    final varIndices = {
      for (var i = 0; i < varOrder.length; i++) varOrder[i]: i,
    };
    return _buildPositionalEvaluator(simplified, varIndices);
  }

  /// Compiles expression into a zero-allocation, vectorized loop over contiguous [Float64List] buffers.
  void Function(List<Float64List> inputs, Float64List output)
  compileTensorKernel(List<String> varOrder) {
    final simplified = simplify();
    final varIndices = {
      for (var i = 0; i < varOrder.length; i++) varOrder[i]: i,
    };
    final evaluator = _buildPositionalEvaluator(simplified, varIndices);

    return (List<Float64List> inputs, Float64List output) {
      final len = output.length;
      final argCount = inputs.length;
      final currentArgs = List<double>.filled(argCount, 0.0);

      // Single contiguous loop - zero Map lookups, zero object allocations
      for (var i = 0; i < len; i++) {
        for (var argIdx = 0; argIdx < argCount; argIdx++) {
          currentArgs[argIdx] = inputs[argIdx][i];
        }
        output[i] = evaluator(currentArgs);
      }
    };
  }

  static double Function(double x) _compileFast1D(
    Expr expression,
    String variableName,
  ) => switch (expression) {
    Constant(value: final val) => (_) => val,
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

  static double Function(List<double> args) _buildPositionalEvaluator(
    Expr expression,
    Map<String, int> indices,
  ) => switch (expression) {
    Constant(value: final val) => (_) => val,
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
}
