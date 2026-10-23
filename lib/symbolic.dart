/// Symbolic mathematics, computer algebra, exact calculus, and equation solving.
///
/// Implements an Abstract Syntax Tree (AST) for exact mathematical expressions,
/// computer algebra manipulation (simplification, expansion, factoring), exact
/// calculus (differentiation, integration, limits, power series, summations),
/// equation solving, compiled numerical evaluation closures, and native
/// algebraic integration with matrices and vectors.
///
/// Expressions are constructed programmatically or parsed from mathematical
/// strings via [Expr.parse]. Numbers are maintained in an exact numeric tower
/// ([IntegerNumber], [FractionNumber], [RealNumber], [ComplexNumber]) backed by
/// an arbitrary-precision [Integer] type. Arithmetic follows a unified n-ary AST
/// ([Add], [Mul], [Pow]) with structural deduplication and cached hash codes.
///
/// ## Key Capabilities
///
/// - **Expression AST & Exact Numbers**: [Expr] base tree, [Variable],
///   [Constant] ([Constant.pi], [Constant.e], [Constant.infinity],
///   [Constant.undefined]), exact [IntegerNumber], [FractionNumber],
///   [RealNumber], [ComplexNumber] (including [ComplexNumber.i]), and
///   [Integer]. Mathematical string parsing via [Expr.parse] with [ExprSyntax].
/// - **Algebraic Simplification & Rewriting**: Canonical simplification
///   ([SimplifierExtension.simplify]) combining terms and extracting radicals
///   under [Assumptions], polynomial expansion ([ExpandExtension.expand]),
///   factorization ([FactorExtension.factor]), rational function cancellation
///   ([RationalFunctionExtension.cancel], [PolynomialDivisionResult]), and
///   trigonometric rewriting ([TrigRewriteExtension.rewrite],
///   [RewriteTarget], [TrigRewriteExtension.expandTrig],
///   [TrigRewriteExtension.simplifyTrig]).
/// - **Calculus**: Analytical differentiation to arbitrary order
///   ([DifferentiationExtension.derivative]), indefinite and definite
///   integration ([IntegrationExtension.integrate], [IntegrationBound]),
///   limits ([LimitExtension.limit]), Taylor and Maclaurin series expansions
///   ([SeriesExtension.series], [PowerSeries]), and symbolic summations
///   ([SummationExtension.sum]).
/// - **Equation & System Solving**: Univariate equation solving
///   ([SolverExtension.solve]) for polynomial, trigonometric, and
///   transcendental equations; multivariable polynomial system solving
///   ([SystemSolverExtension.solve], [PolynomialSystemMethod]) via
///   Gröbner bases and resultants.
/// - **Multivariable Calculus & Linear Algebra**: Gradient
///   ([MultivariableExtension.gradient]), Hessian
///   ([MultivariableExtension.hessian]), and Jacobian
///   ([MultivariableIterableExtension.jacobian]) returning first-class [Vector]
///   and [Matrix] structures; symbolic matrix operations
///   ([SymbolicMatrixExtension], [SymbolicVectorExtension],
///   [SymbolicEigenpair]), and algebraic field integration ([ExprDataType],
///   [ExprField], [exprDataType]).
/// - **Compilation & Approximation**: Fast compilation of symbolic expressions
///   to native Dart double and complex closures
///   ([CompilerExtension.toFunction1D],
///   [CompilerExtension.toComplexFunction1D],
///   [CompilerExtension.toVectorFunction],
///   [CompilerIterableExtension.toVectorFunction]) for high-speed numerical
///   pipelines, along with floating-point numeric approximation
///   ([ApproximationExtension.approximate]).
/// - **Textualization & Export**: Formatting symbolic expressions into standard
///   LaTeX math ([LatexExtension.toLatex]) and Presentation MathML
///   ([MathMlExtension.toMathMl]).
///
/// ## Example
///
/// ```dart
/// import 'package:data/symbolic.dart';
///
/// void main() {
///   // Parse an algebraic expression: f(x) = x^3 - 3*x + 1
///   final f = Expr.parse('x^3 - 3*x + 1');
///
///   // Exact symbolic differentiation: f'(x) = 3*x^2 - 3
///   final df = f.derivative('x').simplify();
///   print('Derivative: $df');
///
///   // Exact symbolic integration: integral of cos(x) dx = sin(x)
///   final integral = Expr.parse('cos(x)').integrate('x');
///   print('Integral: $integral');
///
///   // Solve algebraic equations: x^2 - 5*x + 6 = 0 -> {2, 3}
///   final roots = Expr.parse('x^2 - 5*x + 6').solve('x');
///   print('Roots: $roots');
///
///   // Compile to high-speed native numerical evaluation closure
///   final fn = f.toFunction1D('x');
///   print('f(2.0) = ${fn(2.0)}');
/// }
/// ```
library;

import 'src/linear/matrix.dart';
import 'src/linear/vector.dart';
import 'src/symbolic/algebra/approximate.dart';
import 'src/symbolic/algebra/expand.dart';
import 'src/symbolic/algebra/factor.dart';
import 'src/symbolic/algebra/rational.dart';
import 'src/symbolic/algebra/simplify.dart';
import 'src/symbolic/algebra/trig.dart';
import 'src/symbolic/assumptions.dart';
import 'src/symbolic/ast.dart';
import 'src/symbolic/calculus/differentiation.dart';
import 'src/symbolic/calculus/integration.dart';
import 'src/symbolic/calculus/limit.dart';
import 'src/symbolic/calculus/multivariable.dart';
import 'src/symbolic/calculus/series.dart';
import 'src/symbolic/calculus/summation.dart';
import 'src/symbolic/compiler.dart';
import 'src/symbolic/linear/matrix.dart';
import 'src/symbolic/number/integer.dart';
import 'src/symbolic/parser.dart';
import 'src/symbolic/solver/polynomial_system.dart';
import 'src/symbolic/solver/system.dart';
import 'src/symbolic/solver/univariate.dart';
import 'src/symbolic/textualization/latex.dart';
import 'src/symbolic/textualization/mathml.dart';
import 'src/symbolic/type/expr_data_type.dart';

export 'src/symbolic/algebra/approximate.dart' show ApproximationExtension;
export 'src/symbolic/algebra/expand.dart' show ExpandExtension;
export 'src/symbolic/algebra/factor.dart' show FactorExtension;
export 'src/symbolic/algebra/rational.dart'
    show PolynomialDivisionResult, RationalFunctionExtension;
export 'src/symbolic/algebra/simplify.dart' show SimplifierExtension;
export 'src/symbolic/algebra/trig.dart'
    show RewriteTarget, TrigRewriteExtension;
export 'src/symbolic/assumptions.dart' show Assumptions;
export 'src/symbolic/ast.dart';
export 'src/symbolic/calculus/differentiation.dart'
    show DifferentiationExtension;
export 'src/symbolic/calculus/integration.dart'
    show IntegrationBound, IntegrationExtension;
export 'src/symbolic/calculus/limit.dart' show LimitExtension;
export 'src/symbolic/calculus/multivariable.dart'
    show MultivariableExtension, MultivariableIterableExtension;
export 'src/symbolic/calculus/series.dart'
    show PowerSeries, SeriesExtension, SymbolicPolynomialFactory;
export 'src/symbolic/calculus/summation.dart' show SummationExtension;
export 'src/symbolic/compiler.dart'
    show CompilerExtension, CompilerIterableExtension;
export 'src/symbolic/linear/matrix.dart'
    show SymbolicEigenpair, SymbolicMatrixExtension, SymbolicVectorExtension;
export 'src/symbolic/number/integer.dart' show Integer;
export 'src/symbolic/parser.dart' show ExprSyntax;
export 'src/symbolic/solver/polynomial_system.dart' show PolynomialSystemMethod;
export 'src/symbolic/solver/system.dart' show SystemSolverExtension;
export 'src/symbolic/solver/univariate.dart' show SolverExtension;
export 'src/symbolic/textualization/latex.dart' show LatexExtension;
export 'src/symbolic/textualization/mathml.dart' show MathMlExtension;
export 'src/symbolic/type/expr_data_type.dart'
    show ExprDataType, ExprField, exprDataType;
