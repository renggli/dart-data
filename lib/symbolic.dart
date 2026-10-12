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
///   numbers ([Number], [RationalNumber], [RealNumber], [ConstantNumber],
///   [pi], [e]), and mathematical functions like [Sin], [Cos], [Tan], [Asin],
///   [Acos], [Atan], [Sinh], [Cosh], [Tanh], [Abs], [Sqrt], [Exp], [Ln], and
///   [Log].
/// - **Expression Parsing**: Parse mathematical formulas from text with PetitParser
///   using [Expr.parse] or [Expr.tryParse].
/// - **Analytical Calculus**: Exact differentiation
///   ([DifferentiationExtension.derivative])
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
/// - **LaTeX & MathML Output**: [LatexExtension.toLatex] converts expressions into
///   publication-grade mathematical LaTeX markup; [MathMlExtension.toMathMl]
///   formats expressions into standard W3C MathML markup for direct browser
///   rendering.
/// - **String Formatting**: [formatExpr] and [Expr.toString] serialize
///   expressions with minimal parentheses according to standard operator
///   precedence and associativity rules.
///
/// ## Example
///
/// ```dart
/// import 'package:data/symbolic.dart';
///
/// void main() {
///   final f = Expr.parse('x^3 + 2 * x');
///
///   // Compute exact derivative: f'(x) = 3x^2 + 2
///   final df = f.derivative('x').simplify();
///   print('Derivative: $df');
///   print('LaTeX: ${df.toLatex()}');
///
///   // Compile to high-speed numerical function
///   final fn = df.toFunction1D('x');
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
import 'src/symbolic/simplifier.dart';
import 'src/symbolic/solver.dart';
import 'src/symbolic/textualization/latex.dart';
import 'src/symbolic/textualization/mathml.dart';
import 'src/symbolic/textualization/string.dart';

export 'src/symbolic/ast.dart';
export 'src/symbolic/calculus/differentiation.dart';
export 'src/symbolic/calculus/integration.dart';
export 'src/symbolic/calculus/linear_form.dart';
export 'src/symbolic/calculus/multivariable.dart';
export 'src/symbolic/calculus/taylor.dart';
export 'src/symbolic/compiler.dart';
export 'src/symbolic/simplifier.dart';
export 'src/symbolic/solver.dart';
export 'src/symbolic/textualization/latex.dart';
export 'src/symbolic/textualization/mathml.dart';
export 'src/symbolic/textualization/string.dart';
