import 'dart:typed_data';

import 'package:more/number.dart' show Complex;

import '../linear/vector.dart';
import 'algebra/simplify.dart';
import 'ast.dart';
import 'compiler/fast_eval.dart';
import 'compiler/tensor_kernel.dart';
import 'compiler/vector_eval.dart';

export 'compiler/fast_eval.dart';
export 'compiler/tensor_kernel.dart';
export 'compiler/vector_eval.dart';

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
    return compileFast1D(simplified, varName);
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
    return compileFastComplex1D(simplified, variable);
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
    return compileComplexContext(simplified);
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
    return buildVectorEvaluator(simplified, varIndices);
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
    return buildPositionalEvaluator(simplified, varIndices);
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
    return buildTensorKernel(simplified, varOrder);
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
