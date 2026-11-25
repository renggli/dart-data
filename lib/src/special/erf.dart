import 'dart:math';

import 'package:more/number.dart' show Complex;

import 'utils.dart';

/// Returns the error function `erf(x) = (2 / √π) * ∫_0^x exp(-t^2) dt`.
///
/// Evaluated via Cody's rational Chebyshev minimax approximation. Returns `-1.0`
/// at `-∞`, `1.0` at `+∞`, and `double.nan` for `NaN`.
///
/// See https://en.wikipedia.org/wiki/Error_function for details.
///
/// ```dart
/// final val = erf(1.0); // ~ 0.84270079
/// ```
double erf(num x) => _erfCore(x, complementary: false);

/// Returns the complex error function `erf(z) = (2 / √π) * ∫_0^z exp(-t^2) dt`.
///
/// Uses Cody's minimax approximation on the real axis, [erfi] on the imaginary
/// axis, Salzer's windowed series (A&S 7.1.29) when `|z| < 4` or
/// `Re(z) < 0.5 * |Im(z)|`, and the continued fraction for [erfcComplex]
/// elsewhere in the right half-plane.
///
/// See https://en.wikipedia.org/wiki/Error_function for details.
Complex erfComplex(Complex z) {
  if (z.isNaN) return Complex.nan;
  if (z.b == 0.0) {
    if (z.a == double.infinity) return Complex.one;
    if (z.a == double.negativeInfinity) return const Complex(-1.0);
    return Complex(erf(z.a.toDouble()));
  }
  if (!z.a.isFinite || !z.b.isFinite) return Complex.nan;
  if (z.a == 0.0) return Complex(0.0, erfi(z.b.toDouble()));
  if (z.a < 0.0) return -erfComplex(-z);
  if (z.abs() >= 4.0 && z.a >= 0.5 * z.b.abs()) {
    return Complex.one - erfcComplex(z);
  }
  return _erfSalzerComplex(z.a.toDouble(), z.b.toDouble());
}

/// Returns the inverse error function `erf^-1(p)` on `[-1, 1]`.
///
/// Returns `-∞` at `-1`, `+∞` at `+1`, and `double.nan` outside `[-1, 1]`.
///
/// See https://en.wikipedia.org/wiki/Error_function#Inverse_functions for
/// details.
///
/// ```dart
/// final x = erfInv(0.8427007929497149); // ~ 1.0
/// ```
double erfInv(num p) {
  if (p.isNaN || p < -1.0 || p > 1.0) return double.nan;
  if (p == -1.0) return double.negativeInfinity;
  if (p == 1.0) return double.infinity;
  if (p == 0.0) return 0.0;
  final pd = p.toDouble();
  const x0 = 0.7;
  if (pd < -x0) return -erfcInv(1.0 + pd);
  if (pd > x0) return erfcInv(1.0 - pd);

  var result = pd * hornerRatio(pd * pd, _invA, _invB);
  for (var i = 0; i < 4; i++) {
    final f = erf(result) - pd;
    final fPrime = 2.0 * invSqrtPi * exp(-result * result);
    final u = f / fPrime;
    final denom = 1.0 + result * u;
    final step = denom == 0.0 ? u : u / denom;
    result -= step;
    if (step.abs() <= 1e-15 * result.abs()) break;
  }
  return result;
}

/// Returns the complementary error function `erfc(x) = 1 - erf(x)`.
///
/// Maintains full relative precision into the deep tail (`x > 0`) without
/// catastrophic cancellation.
///
/// See https://en.wikipedia.org/wiki/Error_function#Complementary_error_function
/// for details.
double erfc(num x) => _erfCore(x, complementary: true);

/// Returns the complex complementary error function `erfc(z) = 1 - erf(z)`.
///
/// See https://en.wikipedia.org/wiki/Error_function#Complementary_error_function
/// for details.
Complex erfcComplex(Complex z) {
  if (z.isNaN) return Complex.nan;
  if (z.b == 0.0) {
    if (z.a == double.infinity) return Complex.zero;
    if (z.a == double.negativeInfinity) return const Complex(2.0);
    return Complex(erfc(z.a.toDouble()));
  }
  if (!z.a.isFinite || !z.b.isFinite) return Complex.nan;
  if (z.a < 0.0) return const Complex(2.0) - erfcComplex(-z);
  if (z.abs() < 4.0 || z.a < 0.5 * z.b.abs()) {
    return Complex.one - erfComplex(z);
  }

  final h = lentzCFComplex(z, (k) => Complex(0.5 * k), (_) => z);
  return (-z.square()).exp() * invSqrtPi * h;
}

/// Returns the inverse complementary error function `erfc^-1(p)` on `[0, 2]`.
///
/// Returns `+∞` at `0`, `-∞` at `2`, `0.0` at `1`, and `double.nan` outside
/// `[0, 2]`.
///
/// See https://en.wikipedia.org/wiki/Error_function#Inverse_functions for
/// details.
double erfcInv(num p) {
  if (p.isNaN || p < 0.0 || p > 2.0) return double.nan;
  if (p == 0.0) return double.infinity;
  if (p == 2.0) return double.negativeInfinity;
  if (p == 1.0) return 0.0;

  final xVal = p.toDouble();
  if (xVal > 1.0) return -erfcInv(2.0 - xVal);

  var result = 0.0;
  if (xVal > 0.3) {
    final u = 1.0 - xVal;
    result = u * hornerRatio(u * u, _invA, _invB);
  } else if (xVal >= 1e-4) {
    final z = sqrt(-log(0.5 * xVal));
    result = hornerRatio(z, _invC, _invD);
  } else {
    final t = -log(sqrtPi * xVal);
    result = sqrt(t - 0.5 * log(t));
  }

  for (var i = 0; i < 8; i++) {
    final f = erfc(result) - xVal;
    final fPrime = -2.0 * invSqrtPi * exp(-result * result);
    if (fPrime == 0.0) break;
    final u = f / fPrime;
    final denom = 1.0 + result * u;
    final step = denom == 0.0 ? u : u / denom;
    result -= step;
    if (step.abs() <= 1e-15 * result.abs()) break;
  }
  return result;
}

/// Returns the imaginary error function
/// `erfi(x) = -i * erf(i * x) = (2 / √π) * ∫_0^x exp(t^2) dt`.
///
/// Returns `±∞` for `|x| > 26.7` or `±∞`, and `double.nan` for `NaN`.
///
/// See https://en.wikipedia.org/wiki/Error_function#Imaginary_error_function
/// for details.
double erfi(num x) {
  if (x.isNaN) return double.nan;
  final xd = x.toDouble();
  if (xd == 0.0) return 0.0;
  if (xd.isInfinite) return xd;
  final sign = xd < 0.0 ? -1.0 : 1.0;
  final ax = xd.abs();
  if (ax > 26.7) return sign * double.infinity;

  if (ax >= 7.0) {
    final inv2x2 = 0.5 / (ax * ax);
    var term = 1.0;
    var sum = 1.0;
    for (var k = 1; k <= 40; k++) {
      final next = term * (2 * k - 1) * inv2x2;
      if (next >= term) break;
      term = next;
      sum += term;
      if (term <= 1e-16 * sum) break;
    }
    final halfX2 = 0.5 * ax * ax;
    final eHalf = exp(halfX2);
    return sign * eHalf * (eHalf * (invSqrtPi / ax) * sum);
  }

  final x2 = ax * ax;
  var sum = ax;
  var term = ax;
  for (var n = 1; n <= 200; n++) {
    term *= x2 / n;
    final add = term / (2 * n + 1);
    sum += add;
    if (add <= 1e-16 * sum) break;
  }
  return sign * (2.0 * invSqrtPi) * sum;
}

/// Returns the complex imaginary error function `erfi(z) = -i * erf(i * z)`.
///
/// See https://en.wikipedia.org/wiki/Error_function#Imaginary_error_function
/// for details.
Complex erfiComplex(Complex z) =>
    const Complex(0.0, -1.0) * erfComplex(Complex.i * z);

/// Evaluates `erf(x + i*y)` for `x >= 0` via Salzer's series (A&S 7.1.29),
/// summing the Gaussian peak around `n0 = round(2 * |y|)` to prevent overflow.
Complex _erfSalzerComplex(double x, double y) {
  final c2 = cos(2.0 * x * y);
  final s2 = sin(2.0 * x * y);
  final ex2 = exp(-x * x);
  var re = erf(x);
  double im;
  if (x < 1e-4) {
    final sxy = sin(x * y);
    re += x == 0.0 ? 0.0 : ex2 * (sxy * sxy) / (pi * x);
    im = ex2 * (x == 0.0 ? y / pi : s2 / (2.0 * pi * x));
  } else {
    re += ex2 / (2.0 * pi * x) * (1.0 - c2);
    im = ex2 / (2.0 * pi * x) * s2;
  }
  const scale = 2.0 / pi;
  for (var n = 1; n < 20; n++) {
    final e0 = exp(-0.25 * n * n - x * x);
    if (e0 == 0.0) break;
    re += scale * e0 / (n * n + 4.0 * x * x) * (2.0 * x);
  }
  final ay = y.abs();
  final sy = y >= 0.0 ? 1.0 : -1.0;
  final n0 = (2.0 * ay).round();
  final lo = max(1, n0 - 16);
  final hi = n0 + 16;
  for (var n = lo; n <= hi; n++) {
    final den = n * n + 4.0 * x * x;
    final diff = n - 2.0 * ay;
    final sum = n + 2.0 * ay;
    final ep = 0.5 * exp(-0.25 * diff * diff + ay * ay - x * x);
    final em = 0.5 * exp(-0.25 * sum * sum + ay * ay - x * x);
    final ch = ep + em;
    final sh = ep - em;
    re += scale / den * (-2.0 * x * ch * c2 + n * sh * s2 * sy);
    im += scale / den * (2.0 * x * ch * s2 + n * sh * c2 * sy);
  }
  return Complex(re, im);
}

double _erfCore(num x, {required bool complementary}) {
  if (x.isNaN) return double.nan;
  final xVal = x.toDouble();
  final y = xVal.abs();

  if (y <= _thresh) {
    final ysq = y > _xSmall ? y * y : 0.0;
    var xnum = _aCoeffs[4] * ysq;
    var xden = ysq;
    for (var i = 0; i < 3; i++) {
      xnum = (xnum + _aCoeffs[i]) * ysq;
      xden = (xden + _bCoeffs[i]) * ysq;
    }
    final erfVal = xVal * (xnum + _aCoeffs[3]) / (xden + _bCoeffs[3]);
    return complementary ? 1.0 - erfVal : erfVal;
  }

  if (y <= 4.0) {
    var xnum = _cCoeffs[8] * y;
    var xden = y;
    for (var i = 0; i < 7; i++) {
      xnum = (xnum + _cCoeffs[i]) * y;
      xden = (xden + _dCoeffs[i]) * y;
    }
    var res = (xnum + _cCoeffs[7]) / (xden + _dCoeffs[7]);
    final ysq = (y * 16.0).floorToDouble() / 16.0;
    final del = (y - ysq) * (y + ysq);
    res = exp(-ysq * ysq) * exp(-del) * res;
    if (complementary) {
      return xVal.isNegative ? 2.0 - res : res;
    }
    final erfVal = (0.5 - res) + 0.5;
    return xVal.isNegative ? -erfVal : erfVal;
  }

  if (y >= _xBig) {
    if (complementary) return xVal.isNegative ? 2.0 : 0.0;
    return xVal.isNegative ? -1.0 : 1.0;
  }

  final ysq = 1.0 / (y * y);
  var xnum = _pCoeffs[5] * ysq;
  var xden = ysq;
  for (var i = 0; i < 4; i++) {
    xnum = (xnum + _pCoeffs[i]) * ysq;
    xden = (xden + _qCoeffs[i]) * ysq;
  }
  var res = ysq * (xnum + _pCoeffs[4]) / (xden + _qCoeffs[4]);
  res = (invSqrtPi - res) / y;
  final ysqInt = (y * 16.0).floorToDouble() / 16.0;
  final del = (y - ysqInt) * (y + ysqInt);
  res = exp(-ysqInt * ysqInt) * exp(-del) * res;
  if (complementary) {
    return xVal.isNegative ? 2.0 - res : res;
  }
  final erfVal = (0.5 - res) + 0.5;
  return xVal.isNegative ? -erfVal : erfVal;
}

const double _thresh = 0.46875;
const double _xSmall = 1.11e-16;
const double _xBig = 27.3;

const List<double> _invA = [
  0.886226899,
  -1.645349621,
  0.914624893,
  -0.140543331,
];

const List<double> _invB = [
  1.0,
  -2.118377725,
  1.442710462,
  -0.329097515,
  0.012229801,
];

const List<double> _invC = [
  -1.970840454,
  -1.624906493,
  3.429567803,
  1.641345311,
];

const List<double> _invD = [1.0, 3.543889200, 1.637067800];

const List<double> _aCoeffs = [
  3.16112374387056560e0,
  1.13864154151050156e2,
  3.77485237685302021e2,
  3.20937758913846947e3,
  1.85777706184603153e-1,
];

const List<double> _bCoeffs = [
  2.36012909523441209e1,
  2.44024637934444173e2,
  1.28261652607737228e3,
  2.84423683343917062e3,
];

const List<double> _cCoeffs = [
  5.64188496988670089e-1,
  8.88314979438837594e0,
  6.61191906371416295e1,
  2.98635138197400131e2,
  8.81952221241769090e2,
  1.71204761263407058e3,
  2.05107837782607147e3,
  1.23033935479799725e3,
  2.15311535474403846e-8,
];

const List<double> _dCoeffs = [
  1.57449261107098347e1,
  1.17693950891312499e2,
  5.37181101862009858e2,
  1.62138957456669019e3,
  3.29079923573345963e3,
  4.36261909014324716e3,
  3.43936767414372164e3,
  1.23033935480374942e3,
];

const List<double> _pCoeffs = [
  3.05326634961232344e-1,
  3.60344899949804439e-1,
  1.25781726111229246e-1,
  1.60837851487422766e-2,
  6.58749161529837803e-4,
  1.63153871373020978e-2,
];

const List<double> _qCoeffs = [
  2.56852019228982242e0,
  1.87295284992346047e0,
  5.27905102951428412e-1,
  6.05183413124413191e-2,
  2.33520497626869185e-3,
];
