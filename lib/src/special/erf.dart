import 'dart:math';

import 'package:more/math.dart';

/// Returns an approximation of the error function, for details see
/// https://en.wikipedia.org/wiki/Error_function.
///
/// This uses a Chebyshev fitting formula from Numerical Recipes, 6.2.
///
/// ```dart
/// print(erf(1));  // 0.8427007929497149
/// ```
double erf(num x) {
  if (x == 0) return x.toDouble();
  final tVal = 1.0 / (1.0 + 0.5 * x.abs());
  final exponent = -x * x + _erfChebyshev.polynomial(tVal);
  final result = tVal * exp(exponent);
  return x.isNegative ? result - 1.0 : 1.0 - result;
}

/// Returns the inverse error function.
double erfInv(num x) {
  if (x < -1.0 || x > 1.0) {
    return double.nan;
  } else if (x == -1.0) {
    return double.negativeInfinity;
  } else if (x == 1.0) {
    return double.infinity;
  } else if (x == 0) {
    return x.toDouble();
  } else {
    const x0 = 0.7;
    const coeffsA = [0.886226899, -1.645349621, 0.914624893, -0.140543331];
    const coeffsB = [-2.118377725, 1.442710462, -0.329097515, 0.012229801];
    const coeffsC = [-1.970840454, -1.624906493, 3.429567803, 1.641345311];
    const coeffsD = [3.543889200, 1.637067800];
    var result = 0.0;
    if (x < -x0) {
      final z = sqrt(-log((1.0 + x) / 2.0));
      result =
          -(((coeffsC[3] * z + coeffsC[2]) * z + coeffsC[1]) * z + coeffsC[0]) /
          ((coeffsD[1] * z + coeffsD[0]) * z + 1.0);
    } else if (x < x0) {
      final z = x * x;
      result =
          x *
          (((coeffsA[3] * z + coeffsA[2]) * z + coeffsA[1]) * z + coeffsA[0]) /
          ((((coeffsB[3] * z + coeffsB[2]) * z + coeffsB[1]) * z + coeffsB[0]) *
                  z +
              1.0);
    } else {
      final z = sqrt(-log((1.0 - x) / 2.0));
      result =
          (((coeffsC[3] * z + coeffsC[2]) * z + coeffsC[1]) * z + coeffsC[0]) /
          ((coeffsD[1] * z + coeffsD[0]) * z + 1.0);
    }
    for (var i = 0; i < 2; i++) {
      result -= (erf(result) - x) / (2.0 / sqrt(pi) * exp(-result * result));
    }
    return result;
  }
}

/// Returns the complementary error function.
double erfc(num x) {
  if (x.isNaN) return double.nan;
  if (x == 0) return 1.0;
  final tVal = 1.0 / (1.0 + 0.5 * x.abs());
  final exponent = -x * x + _erfChebyshev.polynomial(tVal);
  final result = tVal * exp(exponent);
  return x.isNegative ? 2.0 - result : result;
}

/// Returns the inverse complementary error function.
double erfcInv(num x) => -erfInv(x - 1.0);

const _erfChebyshev = [
  -1.26551223,
  1.00002368,
  0.37409196,
  0.09678418,
  -0.18628806,
  0.27886807,
  -1.13520398,
  1.48851587,
  -0.82215223,
  0.17087277,
];
