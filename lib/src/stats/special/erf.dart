import 'dart:math';

import 'package:more/math.dart';

/// Returns an approximation of the error function, for details see
/// https://en.wikipedia.org/wiki/Error_function.
///
/// This uses a Chebyshev fitting formula from Numerical Recipes, 6.2.
double erf(num x) {
  const p = [
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
  final t = 1.0 / (1.0 + 0.5 * x.abs());
  final e = -x * x + p.polynomial(t);
  final r = t * exp(e);
  return x.isNegative ? r - 1.0 : 1.0 - r;
}

/// Returns the complementary error function.
double erfc(num x) => 1.0 - erf(x);

/// Returns the inverse error function.
double erfinv(num x) {
  if (x <= -1.0) {
    return double.negativeInfinity;
  } else if (x >= 1.0) {
    return double.infinity;
  } else {
    const x0 = 0.7;
    const a = [0.886226899, -1.645349621, 0.914624893, -0.140543331];
    const b = [-2.118377725, 1.442710462, -0.329097515, 0.012229801];
    const c = [-1.970840454, -1.624906493, 3.429567803, 1.641345311];
    const d = [3.543889200, 1.637067800];
    var r = 0.0;
    if (x < -x0) {
      final z = sqrt(-log((1.0 + x) / 2.0));
      r = -(((c[3] * z + c[2]) * z + c[1]) * z + c[0]) /
          ((d[1] * z + d[0]) * z + 1.0);
    } else if (x < x0) {
      final z = x * x;
      r = x *
          (((a[3] * z + a[2]) * z + a[1]) * z + a[0]) /
          ((((b[3] * z + b[3]) * z + b[1]) * z + b[0]) * z + 1.0);
    } else {
      final z = sqrt(-log((1.0 - x) / 2.0));
      r = (((c[3] * z + c[2]) * z + c[1]) * z + c[0]) /
          ((d[1] * z + d[0]) * z + 1.0);
    }
    for (var i = 0; i < 2; i++) {
      r -= (erf(r) - x) / (2.0 / sqrt(pi) * exp(-r * r));
    }
    return r;
  }
}

/// Returns the inverse complementary error function.
double erfcinv(num x) => -erfinv(x - 1.0);
