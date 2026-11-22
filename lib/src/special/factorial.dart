import 'package:more/number.dart' show Complex;

import 'gamma.dart';

/// Returns the factorial `n! = Γ(n + 1)` for non-negative real values.
///
/// Extends the discrete factorial to all non-negative real numbers via the
/// [gamma] function.
///
/// See https://en.wikipedia.org/wiki/Factorial for details.
///
/// ```dart
/// print(factorial(5)); // 120.0
/// ```
double factorial(num value) =>
    value.isNaN || value < 0.0 ? double.nan : gamma(1.0 + value);

/// Returns the complex factorial `z! = Γ(z + 1)`.
///
/// See https://en.wikipedia.org/wiki/Factorial for details.
Complex factorialComplex(Complex z) => gammaComplex(z + Complex.one);

/// Returns the natural logarithm of the factorial `ln(n!) = ln(Γ(n + 1))`.
///
/// See https://en.wikipedia.org/wiki/Factorial for details.
double factorialLn(num value) =>
    value.isNaN || value < 0.0 ? double.nan : gammaLn(1.0 + value);
