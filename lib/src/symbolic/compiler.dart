import 'dart:typed_data';

import 'package:more/number.dart' show Complex;

import '../linear/vector.dart';
import 'algebra/simplify.dart';
import 'assumptions.dart';
import 'ast.dart';
import 'compiler/bytecode.dart';
import 'compiler/evaluator.dart';

/// Extension providing zero-allocation high-throughput bytecode compilation of
/// symbolic expressions.
extension CompilerExtension on Expr {
  /// Evaluates this expression to a `double` given variable bindings in [context].
  ///
  /// Throws an [ArgumentError] if any free variable in this expression is
  /// missing from [context], or an [UnsupportedError] if the expression is
  /// complex-valued.
  ///
  /// ```dart
  /// final expr = Expr.parse('x^2 + 2*x + 1');
  /// final val = expr.evaluate({'x': 3.0}); // 16.0
  /// ```
  double evaluate([Map<String, double> context = const {}]) =>
      compileToBytecode(
        this,
        const [],
        optimize: false,
        allowDynamicVars: true,
      ).evaluateMap(context);

  /// Evaluates this expression in the complex domain $\mathbb{C}$ given complex
  /// variable bindings in [context].
  ///
  /// Throws an [ArgumentError] if any free variable in this expression is
  /// missing from [context].
  ///
  /// ```dart
  /// final z = const Variable('x') + 2 * i;
  /// final val = z.evaluateComplex({'x': const Complex(3, 1)}); // Complex(3, 3)
  /// ```
  Complex evaluateComplex([Map<String, Complex> context = const {}]) =>
      compileToBytecode(
        this,
        const [],
        optimize: false,
        allowDynamicVars: true,
      ).evaluateComplexMap(context);

  /// Compiles this expression into a fast native Dart function
  /// `double Function(double)`.
  ///
  /// Conceptually, this converts a symbolic formula into a standard Dart
  /// function that executes with maximum speed without AST dictionary lookups
  /// or tree traversals. Formally, it compiles the expression to an RPN
  /// register-and-stack bytecode stream with Common Subexpression Elimination
  /// when [optimize] is `true`.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final f = (x * x + 1).toFunction1D('x');
  /// final y = f(3.0); // 10.0
  /// ```
  double Function(double x) toFunction1D(
    String varName, {
    bool optimize = true,
    Assumptions assumptions = Assumptions.none,
  }) {
    final evaluator = _compileBytecode(
      variables: [varName],
      optimize: optimize,
      assumptions: assumptions,
    )..checkRealSupported();
    return evaluator.evaluate1D;
  }

  /// Compiles this expression into a fast complex native Dart function
  /// `Complex Function(Complex x)`.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final f = (x * x + 1).toComplexFunction1D('x');
  /// final y = f(Complex(0, 1)); // i^2 + 1 = 0
  /// ```
  Complex Function(Complex x) toComplexFunction1D([
    String variable = 'x',
    bool optimize = true,
  ]) {
    final evaluator = _compileBytecode(
      variables: [variable],
      optimize: optimize,
      assumptions: Assumptions(domains: {variable: VariableDomain.complex}),
    );
    return evaluator.evaluateComplex1D;
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
  Complex Function(Map<String, Complex> context) compileComplex({
    bool optimize = true,
  }) {
    final evaluator = _compileBytecode(
      optimize: optimize,
      assumptions: Assumptions.complex,
    );
    return evaluator.evaluateComplexMap;
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
    List<String> varOrder, {
    bool optimize = true,
  }) {
    final evaluator = _compileBytecode(variables: varOrder, optimize: optimize)
      ..checkRealSupported();
    return evaluator.evaluateVector;
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
  double Function(List<double> args) compile(
    List<String> varOrder, {
    bool optimize = true,
  }) {
    final evaluator = _compileBytecode(variables: varOrder, optimize: optimize)
      ..checkRealSupported();
    return evaluator.evaluateList;
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
  compileTensorKernel(List<String> varOrder, {bool optimize = true}) {
    final evaluator = _compileBytecode(variables: varOrder, optimize: optimize)
      ..checkRealSupported();
    return evaluator.evaluateTensor;
  }

  BytecodeEvaluator _compileBytecode({
    List<String>? variables,
    bool optimize = true,
    Assumptions assumptions = Assumptions.none,
  }) {
    final simplified = simplify(assumptions: assumptions);
    final varList = variables ?? (simplified.freeVariables.toList()..sort());
    return compileToBytecode(
      simplified,
      varList,
      optimize: optimize,
      allowDynamicVars: variables == null,
    );
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
    List<String> varOrder, {
    bool optimize = true,
  }) {
    final evaluators = [
      for (final expr in this)
        expr.toVectorFunction(varOrder, optimize: optimize),
    ];
    return (Vector<double> v) =>
        Vector.generate(evaluators.length, (i) => evaluators[i](v));
  }
}
