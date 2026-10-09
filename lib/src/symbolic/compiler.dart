import 'dart:math' as math;
import 'dart:typed_data';

import 'ast.dart';

/// Extension providing zero-allocation high-throughput compilation of symbolic expressions.
extension ExprCompiler on Expr {
  /// Compiles into a direct [double Function(double)] with ZERO AST walking or Map overhead.
  double Function(double x) compile1D(String varName) {
    final s = simplify();
    return _compileFast1D(s, varName);
  }

  static double Function(double x) _compileFast1D(Expr e, String v) =>
      switch (e) {
        Constant(value: final val) => (_) => val,
        Variable(name: final n) => n == v ? (x) => x : (_) => 0.0,
        Add(left: final l, right: final r) => () {
          final fL = _compileFast1D(l, v), fR = _compileFast1D(r, v);
          return (double x) => fL(x) + fR(x);
        }(),
        Sub(left: final l, right: final r) => () {
          final fL = _compileFast1D(l, v), fR = _compileFast1D(r, v);
          return (double x) => fL(x) - fR(x);
        }(),
        Mul(left: final l, right: final r) => () {
          final fL = _compileFast1D(l, v), fR = _compileFast1D(r, v);
          return (double x) => fL(x) * fR(x);
        }(),
        Div(left: final l, right: final r) => () {
          final fL = _compileFast1D(l, v), fR = _compileFast1D(r, v);
          return (double x) => fL(x) / fR(x);
        }(),
        Pow(base: final b, exponent: final exp) => () {
          final fB = _compileFast1D(b, v), fE = _compileFast1D(exp, v);
          return (double x) => math.pow(fB(x), fE(x)).toDouble();
        }(),
        Neg(expr: final inner) => () {
          final f = _compileFast1D(inner, v);
          return (double x) => -f(x);
        }(),
        Sin(expr: final inner) => () {
          final f = _compileFast1D(inner, v);
          return (double x) => math.sin(f(x));
        }(),
        Cos(expr: final inner) => () {
          final f = _compileFast1D(inner, v);
          return (double x) => math.cos(f(x));
        }(),
        Exp(expr: final inner) => () {
          final f = _compileFast1D(inner, v);
          return (double x) => math.exp(f(x));
        }(),
        Ln(expr: final inner) => () {
          final f = _compileFast1D(inner, v);
          return (double x) => math.log(f(x));
        }(),
      };

  /// Compiles into a multi-variable positional closure [double Function(List<double> args)].
  double Function(List<double> args) compile(List<String> varOrder) {
    final s = simplify();
    final varIndices = {
      for (var i = 0; i < varOrder.length; i++) varOrder[i]: i,
    };
    return _buildPositionalEvaluator(s, varIndices);
  }

  /// Compiles expression into a zero-allocation, vectorized loop over contiguous [Float64List] buffers.
  void Function(List<Float64List> inputs, Float64List output)
  compileTensorKernel(List<String> varOrder) {
    final s = simplify();
    final varIndices = {
      for (var i = 0; i < varOrder.length; i++) varOrder[i]: i,
    };
    final evaluator = _buildPositionalEvaluator(s, varIndices);

    return (List<Float64List> inputs, Float64List output) {
      final len = output.length;
      final argCount = inputs.length;
      final currentArgs = List<double>.filled(argCount, 0.0);

      // Single contiguous loop - zero Map lookups, zero object allocations
      for (var i = 0; i < len; i++) {
        for (var a = 0; a < argCount; a++) {
          currentArgs[a] = inputs[a][i];
        }
        output[i] = evaluator(currentArgs);
      }
    };
  }

  static double Function(List<double> args) _buildPositionalEvaluator(
    Expr e,
    Map<String, int> indices,
  ) => switch (e) {
    Constant(value: final val) => (_) => val,
    Variable(name: final n) => () {
      final idx = indices[n] ?? (throw ArgumentError('Unbound variable: $n'));
      return (List<double> args) => args[idx];
    }(),
    Add(left: final l, right: final r) => () {
      final fL = _buildPositionalEvaluator(l, indices),
          fR = _buildPositionalEvaluator(r, indices);
      return (List<double> args) => fL(args) + fR(args);
    }(),
    Sub(left: final l, right: final r) => () {
      final fL = _buildPositionalEvaluator(l, indices),
          fR = _buildPositionalEvaluator(r, indices);
      return (List<double> args) => fL(args) - fR(args);
    }(),
    Mul(left: final l, right: final r) => () {
      final fL = _buildPositionalEvaluator(l, indices),
          fR = _buildPositionalEvaluator(r, indices);
      return (List<double> args) => fL(args) * fR(args);
    }(),
    Div(left: final l, right: final r) => () {
      final fL = _buildPositionalEvaluator(l, indices),
          fR = _buildPositionalEvaluator(r, indices);
      return (List<double> args) => fL(args) / fR(args);
    }(),
    Pow(base: final b, exponent: final exp) => () {
      final fB = _buildPositionalEvaluator(b, indices),
          fE = _buildPositionalEvaluator(exp, indices);
      return (List<double> args) => math.pow(fB(args), fE(args)).toDouble();
    }(),
    Neg(expr: final inner) => () {
      final f = _buildPositionalEvaluator(inner, indices);
      return (List<double> args) => -f(args);
    }(),
    Sin(expr: final inner) => () {
      final f = _buildPositionalEvaluator(inner, indices);
      return (List<double> args) => math.sin(f(args));
    }(),
    Cos(expr: final inner) => () {
      final f = _buildPositionalEvaluator(inner, indices);
      return (List<double> args) => math.cos(f(args));
    }(),
    Exp(expr: final inner) => () {
      final f = _buildPositionalEvaluator(inner, indices);
      return (List<double> args) => math.exp(f(args));
    }(),
    Ln(expr: final inner) => () {
      final f = _buildPositionalEvaluator(inner, indices);
      return (List<double> args) => math.log(f(args));
    }(),
  };
}
