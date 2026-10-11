/// Univariate polynomial algebra, calculus, root isolation, rational functions,
/// and orthogonal polynomial families.
///
/// Implements arithmetic in the polynomial ring `$K\[x\]$` over any
/// mathematical field, along with exact differentiation, indefinite
/// integration, root isolation, and specialized evaluation schemes for
/// orthogonal polynomials.
///
/// ## Core Features
///
/// - **Polynomial Ring Operations**: Exact addition, subtraction,
///   multiplication, Euclidean polynomial long division (`/`, `%`), and
///   greatest common divisor (GCD).
/// - **Fast Evaluation**: Efficient $\mathcal{O}(n)$ Horner's rule via
///   [Polynomial.evaluate].
/// - **Calculus**: Analytical derivatives ([Polynomial.differentiate]) and
///   anti-derivatives ([Polynomial.integrate]).
/// - **Root Finding**: Finds all real and complex roots of polynomials using
///   companion matrix eigenvalues via [Polynomial.roots].
/// - **Rational Functions**: [RationalFunction] represents quotients
///   $P(x) / Q(x)$ with exact simplification and evaluation.
/// - **Orthogonal Polynomials**: [Polynomial.chebyshevT],
///   [Polynomial.chebyshevU], [Polynomial.legendreP], [Polynomial.hermiteH],
///   [Polynomial.hermiteHe], and [Polynomial.laguerreL] with stable
///   $\mathcal{O}(n)$ Clenshaw recurrence evaluation ([clenshawEvaluate]).
///
/// ## Example
///
/// ```dart
/// import 'package:data/polynomial.dart';
///
/// void main() {
///   // Create polynomial p(x) = x^2 - 4
///   final p = Polynomial<double>.fromCoefficients([-4.0, 0.0, 1.0]);
///
///   // Differentiate: p'(x) = 2x
///   final dp = p.differentiate();
///   print('Derivative: $dp');
///
///   // Evaluate at x = 3: p(3) = 9 - 4 = 5
///   print('p(3) = ${p.evaluate(3.0)}');
///
///   // Find roots: x = -2, 2
///   print('Roots: ${p.roots}');
/// }
/// ```
library;

import 'src/polynomial/orthogonal.dart' hide laguerreL;
import 'src/polynomial/polynomial.dart';
import 'src/polynomial/rational.dart';

export 'src/polynomial/impl/compressed_polynomial.dart';
export 'src/polynomial/impl/dense_polynomial.dart';
export 'src/polynomial/orthogonal.dart' hide laguerreL;
export 'src/polynomial/polynomial.dart';
export 'src/polynomial/rational.dart';
