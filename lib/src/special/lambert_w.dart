import 'dart:math';

import 'package:more/number.dart' show Complex;

import 'utils.dart';

/// Returns the real Lambert W function `W_branch(z)`.
///
/// Solves `w * exp(w) = z` for `w`. Supports the principal branch `W_0(z)`
/// (`branch: 0`, defined for `z >= -1/e`) and the secondary real branch
/// `W_{-1}(z)` (`branch: -1`, defined for `-1/e <= z < 0`).
///
/// Throws an [ArgumentError] if [branch] is not `0` or `-1`.
///
/// See https://en.wikipedia.org/wiki/Lambert_W_function for details.
///
/// ```dart
/// final w0 = lambertW(0.0); // 0.0
/// final w1 = lambertW(-0.1, branch: -1); // ~ -3.577152063957297
/// ```
double lambertW(num z, {int branch = 0}) => switch (branch) {
  0 => _lambertW0(z),
  -1 => _lambertW1(z),
  _ => throw ArgumentError.value(branch, 'branch', 'Branch must be 0 or -1'),
};

/// Returns the complex Lambert W function `W_branch(z)`.
///
/// Supports `branch: 0` (principal branch) and `branch: -1`.
///
/// See https://en.wikipedia.org/wiki/Lambert_W_function for details.
Complex lambertWComplex(Complex z, {int branch = 0}) {
  if (branch != 0 && branch != -1) {
    throw ArgumentError.value(branch, 'branch', 'Branch must be 0 or -1');
  }
  if (z.isNaN) return Complex.nan;
  if (z.a == 0.0 && z.b == 0.0) {
    return branch == 0 ? Complex.zero : const Complex(double.negativeInfinity);
  }
  if (branch == 0 && z.b == 0.0 && z.a >= -invE) {
    return Complex(_lambertW0(z.a.toDouble()));
  }
  if (branch == -1 && z.b == 0.0 && z.a >= -invE && z.a < 0.0) {
    return Complex(_lambertW1(z.a.toDouble()));
  }

  var w = switch (branch) {
    0 => () {
      if ((z + invE).abs() < 0.3) {
        final p = ((z * e + 1) * 2).sqrt();
        return p - 1 - p.square() / 3.0 + p * p.square() * (11.0 / 72.0);
      }
      if (z.a >= 0.0 && z.abs() < 1.5) return z / (z + 1);
      final lz = z.log();
      return lz - lz.log();
    }(),
    _ => () {
      final lz = z.log() - const Complex(0.0, 2.0 * pi);
      return lz - (-lz).log();
    }(),
  };

  for (var i = 0; i < 30; i++) {
    final ew = w.exp();
    final f = w * ew - z;
    if (f.abs() <= 1e-15 * (1.0 + w.abs()) * ew.abs()) break;
    final w1 = w + 1;
    if (w1.abs() < 1e-15) break;
    final denom = ew * w1 - (w + 2) * f / (w1 * 2);
    if (denom.abs() == 0.0) break;
    final step = f / denom;
    w -= step;
    if (step.abs() <= 1e-15 * (1.0 + w.abs())) break;
  }
  return w;
}

double _lambertW0(num z) {
  if (z.isNaN || z < -invE - 1e-15) {
    return double.nan;
  }
  if ((z + invE).abs() <= 1e-15) return -1.0;
  if (z == 0.0) return 0.0;
  if (z.isInfinite) return double.infinity;
  final zd = z.toDouble();
  var wVal = 0.0;
  if (zd < -0.3) {
    final pVal = sqrt(2.0 * (e * zd + 1.0));
    wVal =
        -1.0 +
        pVal -
        (1.0 / 3.0) * pVal * pVal +
        (11.0 / 72.0) * pVal * pVal * pVal;
  } else if (zd < e) {
    wVal = zd / (1.0 + zd * (1.0 + zd * (0.5 - zd / 6.0)));
  } else {
    final lz = log(zd);
    final llz = log(lz);
    wVal = lz - llz + llz / lz;
  }
  if (wVal > 100.0) {
    final lz = log(zd);
    for (var i = 0; i < 20; i++) {
      final r = wVal + log(wVal) - lz;
      final w1 = wVal + 1.0;
      final step = (r * wVal / w1) / (1.0 - r / (2.0 * w1 * w1));
      wVal -= step;
      if (step.abs() <= 1e-15 * wVal) break;
    }
    return wVal;
  }
  return _lambertWHalley(zd, wVal);
}

double _lambertW1(num z) {
  if (z.isNaN || z < -invE - 1e-15 || z >= 0.0) {
    return double.nan;
  }
  if ((z + invE).abs() <= 1e-15) return -1.0;
  final zd = z.toDouble();
  var wVal = -1.0;
  if (zd < -0.3) {
    final pVal = -sqrt(2.0 * (e * zd + 1.0));
    wVal =
        -1.0 +
        pVal -
        (1.0 / 3.0) * pVal * pVal +
        (11.0 / 72.0) * pVal * pVal * pVal;
  } else {
    final lz = log(-zd);
    final llz = log(-lz);
    wVal = lz - llz + llz / lz;
  }
  if (wVal < -100.0) {
    final lnNegZ = log(-zd);
    for (var i = 0; i < 20; i++) {
      final r = wVal + log(-wVal) - lnNegZ;
      final w1 = wVal + 1.0;
      final step = (r * wVal / w1) / (1.0 - r / (2.0 * w1 * w1));
      wVal -= step;
      if (step.abs() <= 1e-15 * wVal.abs()) break;
    }
    return wVal;
  }
  return _lambertWHalley(zd, wVal);
}

double _lambertWHalley(double zd, double wVal) {
  for (var i = 0; i < 25; i++) {
    final ew = exp(wVal);
    if (ew == 0.0 || !ew.isFinite) break;
    final fVal = wVal * ew - zd;
    if (fVal.abs() < 1.0e-15 * (1.0 + wVal.abs()) * ew) break;
    final w1 = wVal + 1.0;
    if (w1.abs() < 1.0e-15) break;
    final denom = ew * w1 - (wVal + 2.0) * fVal / (2.0 * w1);
    if (denom == 0.0 || !denom.isFinite) break;
    final step = fVal / denom;
    wVal -= step;
    if (step.abs() < 1.0e-15 * (1.0 + wVal.abs())) break;
  }
  return wVal;
}
