import 'dart:math';

import 'package:more/number.dart' show Complex;

import 'utils.dart';

/// Returns an approximation of the error function `erf(x)`.
///
/// Measures the cumulative probability that a standard Gaussian random variable
/// falls within `[-x * sqrt(2), x * sqrt(2)]`, defined by
/// `erf(x) = (2 / √π) * ∫_0^x exp(-t^2) dt`. Evaluated via Cody's rational
/// Chebyshev minimax approximation.
///
/// See https://en.wikipedia.org/wiki/Error_function for details.
///
/// ```dart
/// final val = erf(1.0); // ~ 0.84270079
/// ```
double erf(num x) => _erfCore(x, complementary: false);

/// Returns the complex error function `erf(z) = (2 / √π) * ∫_0^z exp(-t^2) dt`.
///
/// See https://en.wikipedia.org/wiki/Error_function for details.
Complex erfComplex(Complex z) {
  if (z.isNaN) return Complex.nan;
  if (z == Complex.zero) return Complex.zero;
  if (z.b == 0.0) return Complex(erf(z.a.toDouble()));
  if (z.a == 0.0) return Complex(0.0, erfi(z.b.toDouble()));
  if (z.a < 0.0) return -erfComplex(-z);
  if (z.abs() >= 4.0 && z.a >= 0.5 * z.b.abs()) {
    return Complex.one - erfcComplex(z);
  }

  final z2 = -z * z;
  var sum = z;
  var term = z;
  for (var n = 1; n <= 250; n++) {
    term *= z2 / Complex(n);
    final add = term / Complex(2 * n + 1);
    sum += add;
    if (add.abs() <= 1e-16 * sum.abs()) break;
  }
  return const Complex(2.0 * invSqrtPi) * sum;
}

/// Returns the inverse error function `erf^-1(x)` on `(-1, 1)`.
///
/// See https://en.wikipedia.org/wiki/Error_function#Inverse_functions for
/// details.
///
/// ```dart
/// final x = erfInv(0.8427007929497149); // ~ 1.0
/// ```
double erfInv(num x) {
  if (x.isNaN || x < -1.0 || x > 1.0) return double.nan;
  if (x == -1.0) return double.negativeInfinity;
  if (x == 1.0) return double.infinity;
  if (x == 0) return x.toDouble();
  const x0 = 0.7;
  if (x < -x0) return -erfcInv(1.0 + x);
  if (x > x0) return erfcInv(1.0 - x);

  final z = (x * x).toDouble();
  var result = x * hornerRatio(z, _invA, _invB);
  for (var i = 0; i < 2; i++) {
    result -= (erf(result) - x) / (2.0 * invSqrtPi * exp(-result * result));
  }
  return result;
}

/// Returns the complementary error function `erfc(x) = 1 - erf(x)`.
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
  if (z.b == 0.0) return Complex(erfc(z.a.toDouble()));
  if (z.a < 0.0) return const Complex(2.0) - erfcComplex(-z);
  if (z.abs() < 4.0 || z.a < 0.5 * z.b.abs()) {
    return Complex.one - erfComplex(z);
  }

  final h = lentzCFComplex(z, (k) => Complex(0.5 * k), (_) => z);
  return (-z.square()).exp() * invSqrtPi * h;
}

/// Returns the inverse complementary error function `erfc^-1(x)` on `(0, 2)`.
///
/// See https://en.wikipedia.org/wiki/Error_function#Inverse_functions for
/// details.
double erfcInv(num x) {
  if (x.isNaN || x < 0.0 || x > 2.0) return double.nan;
  if (x == 0.0) return double.infinity;
  if (x == 2.0) return double.negativeInfinity;
  if (x == 1.0) return 0.0;

  final xVal = x.toDouble();
  if (xVal > 1.0) return -erfcInv(2.0 - xVal);

  var result = 0.0;
  if (xVal > 0.3) {
    final u = 1.0 - xVal;
    result = u * hornerRatio(u * u, _invA, _invB);
  } else {
    final z = sqrt(-log(xVal / 2.0));
    result = hornerRatio(z, _invC, _invD);
  }

  for (var i = 0; i < 3; i++) {
    final f = erfc(result) - xVal;
    final fPrime = -2.0 * invSqrtPi * exp(-result * result);
    if (fPrime == 0.0) break;
    final u = f / fPrime;
    final denom = 1.0 + result * u;
    result -= denom == 0.0 ? u : u / denom;
  }
  return result;
}

/// Returns the imaginary error function `erfi(x) = -i * erf(i * x) = (2 / √π) * ∫_0^x exp(t^2) dt`.
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

  final x2 = ax * ax;
  var sum = ax;
  var term = ax;
  for (var n = 1; n <= 1000; n++) {
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
const double _xBig = 26.543;

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
