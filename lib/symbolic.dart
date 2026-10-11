/// Symbolic mathematics engine for exact algebraic expressions, analytical
/// calculus, and code compilation.
///
/// Enables manipulating mathematical expressions symbolically rather than
/// numerically. Computes exact derivatives, finds anti-derivatives, solves
/// algebraic systems, and compiles symbolic expressions into zero-allocation
/// Dart closures for high-speed numerical evaluation.
///
/// ## Key Capabilities
///
/// - **Symbolic Expressions ([Expr])**: Build trees of variables ([Variable]),
///   constants ([Constant]), and mathematical functions like [Sin], [Cos],
///   [Exp], and [Ln].
/// - **Analytical Calculus**: Exact differentiation
///   ([DifferentiationExtension.derivative], [DifferentiationExtension.diff])
///   with product, quotient, and chain rules; multivariate gradients
///   ([MultivariableExtension.gradient]), Hessians
///   ([MultivariableExtension.hessian]), and Jacobians
///   ([MultivariableIterableExtension.jacobian]); symbolic integration
///   ([IntegrationExtension.integrate]); linear form matching
///   ([LinearFormExtension.matchLinear]); and Taylor series expansion
///   ([TaylorExtension.taylorSeries]).
/// - **Algebraic Simplification**: Canonical rule-based simplifier
///   ([SimplifierExtension.simplify]) applying identity properties
///   ($x + 0 \to x$, $x \times 1 \to x$, $x^0 \to 1$), constant folding, and
///   power/logarithm simplifications.
/// - **Equation Solving**: [SolverExtension.solve] for single univariate
///   equations and [SystemSolverExtension.solveSystem] for linear equation
///   systems.
/// - **High-Performance JIT Compilation**: [CompilerExtension.toFunction1D],
///   [CompilerExtension.toVectorFunction], [CompilerExtension.compile], and
///   [CompilerExtension.compileTensorKernel] convert symbolic expressions into
///   direct Dart functions operating on primitive double arguments or typed
///   [Float64List] buffers with zero AST walking overhead.
/// - **LaTeX Output**: [LatexExtension.toLatex] converts expressions into
///   publication-grade mathematical LaTeX markup.
///
/// ## Example
///
/// ```dart
/// import 'package:data/symbolic.dart';
///
/// void main() {
///   const x = Variable('x');
///   final f = x.pow(3) + x * 2; // f(x) = x^3 + 2x
///
///   // Compute exact derivative: f'(x) = 3x^2 + 2
///   final df = f.diff('x').simplify();
///   print('Derivative: $df');
///   print('LaTeX: ${df.toLatex()}');
///
///   // Compile to high-speed numerical function
///   final fn = df.compile1D('x');
///   print('f\'(2.0) = ${fn(2.0)}'); // 3*(4) + 2 = 14.0
/// }
/// ```
library;

import 'dart:typed_data';

import 'src/symbolic/ast.dart';
import 'src/symbolic/calculus/differentiation.dart';
import 'src/symbolic/calculus/integration.dart';
import 'src/symbolic/calculus/linear_form.dart';
import 'src/symbolic/calculus/multivariable.dart';
import 'src/symbolic/calculus/taylor.dart';
import 'src/symbolic/compiler.dart';
import 'src/symbolic/latex.dart';
import 'src/symbolic/simplifier.dart';
import 'src/symbolic/solver.dart';

export 'src/symbolic/ast.dart';
export 'src/symbolic/calculus/differentiation.dart';
export 'src/symbolic/calculus/integration.dart';
export 'src/symbolic/calculus/linear_form.dart';
export 'src/symbolic/calculus/multivariable.dart';
export 'src/symbolic/calculus/taylor.dart';
export 'src/symbolic/compiler.dart';
export 'src/symbolic/latex.dart';
export 'src/symbolic/simplifier.dart';
export 'src/symbolic/solver.dart';
