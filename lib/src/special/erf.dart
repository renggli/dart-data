import 'dart:math';

/// Returns an approximation of the error function $\operatorname{erf}(x)$.
///
/// Conceptually, the error function measures the cumulative probability that a
/// random variable from a standard Gaussian distribution falls within a central
/// interval between $-x \sqrt{2}$ and $x \sqrt{2}$. Formally, this calculates
/// the integral
/// $\operatorname{erf}(x) = \frac{2}{\sqrt{\pi}} \int_0^x e^{-t^2} dt$ using
/// Cody's rational Chebyshev minimax approximation with near machine precision.
///
/// See https://en.wikipedia.org/wiki/Error_function for details.
///
/// ```dart
/// final val = erf(1.0); // ~ 0.84270079
/// ```
double erf(num x) {
  if (x.isNaN) return double.nan;
  final xVal = x.toDouble();
  final y = xVal.abs();
  if (y <= _thresh) {
    var ysq = 0.0;
    if (y > _xSmall) ysq = y * y;
    var xnum = _aCoeffs[4] * ysq;
    var xden = ysq;
    for (var i = 0; i < 3; i++) {
      xnum = (xnum + _aCoeffs[i]) * ysq;
      xden = (xden + _bCoeffs[i]) * ysq;
    }
    return xVal * (xnum + _aCoeffs[3]) / (xden + _bCoeffs[3]);
  } else if (y <= 4.0) {
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
    res = (0.5 - res) + 0.5;
    return xVal.isNegative ? -res : res;
  } else {
    if (y >= _xBig) {
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
    res = (_sqrPi - res) / y;
    final ysqInt = (y * 16.0).floorToDouble() / 16.0;
    final del = (y - ysqInt) * (y + ysqInt);
    res = exp(-ysqInt * ysqInt) * exp(-del) * res;
    res = (0.5 - res) + 0.5;
    return xVal.isNegative ? -res : res;
  }
}

/// Returns the inverse error function $\operatorname{erf}^{-1}(x)$.
///
/// Conceptually, this reverses the error function: given a target central
/// probability, it computes the corresponding coordinate boundary cutoff point.
/// Formally, this computes the inverse bijective map
/// $\operatorname{erf}^{-1}: (-1, 1) \to \mathbb{R}$.
///
/// ```dart
/// final x = erfInv(0.8427007929497149); // ~ 1.0
/// ```
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
  final xVal = x.toDouble();
  final y = xVal.abs();
  if (y <= _thresh) {
    var ysq = 0.0;
    if (y > _xSmall) ysq = y * y;
    var xnum = _aCoeffs[4] * ysq;
    var xden = ysq;
    for (var i = 0; i < 3; i++) {
      xnum = (xnum + _aCoeffs[i]) * ysq;
      xden = (xden + _bCoeffs[i]) * ysq;
    }
    final erfVal = xVal * (xnum + _aCoeffs[3]) / (xden + _bCoeffs[3]);
    return 1.0 - erfVal;
  } else if (y <= 4.0) {
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
    if (xVal.isNegative) {
      return 2.0 - res;
    }
    return res;
  } else {
    if (y >= _xBig) {
      if (xVal.isNegative) return 2.0;
      return 0.0;
    }
    final ysq = 1.0 / (y * y);
    var xnum = _pCoeffs[5] * ysq;
    var xden = ysq;
    for (var i = 0; i < 4; i++) {
      xnum = (xnum + _pCoeffs[i]) * ysq;
      xden = (xden + _qCoeffs[i]) * ysq;
    }
    var res = ysq * (xnum + _pCoeffs[4]) / (xden + _qCoeffs[4]);
    res = (_sqrPi - res) / y;
    final ysqInt = (y * 16.0).floorToDouble() / 16.0;
    final del = (y - ysqInt) * (y + ysqInt);
    res = exp(-ysqInt * ysqInt) * exp(-del) * res;
    if (xVal.isNegative) {
      return 2.0 - res;
    }
    return res;
  }
}

/// Returns the inverse complementary error function.
double erfcInv(num x) => -erfInv(x - 1.0);

const _sqrPi = 0.56418958354775628695;
const _thresh = 0.46875;
const _xSmall = 1.11e-16;
const _xBig = 26.543;

const _aCoeffs = [
  3.16112374387056560e0,
  1.13864154151050156e2,
  3.77485237685302021e2,
  3.20937758913846947e3,
  1.85777706184603153e-1,
];

const _bCoeffs = [
  2.36012909523441209e1,
  2.44024637934444173e2,
  1.28261652607737228e3,
  2.84423683343917062e3,
];

const _cCoeffs = [
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

const _dCoeffs = [
  1.57449261107098347e1,
  1.17693950891312499e2,
  5.37181101862009858e2,
  1.62138957456669019e3,
  3.29079923573345963e3,
  4.36261909014324716e3,
  3.43936767414372164e3,
  1.23033935480374942e3,
];

const _pCoeffs = [
  3.05326634961232344e-1,
  3.60344899949804439e-1,
  1.25781726111229246e-1,
  1.60837851487422766e-2,
  6.58749161529837803e-4,
  1.63153871373020978e-2,
];

const _qCoeffs = [
  2.56852019228982242e0,
  1.87295284992346047e0,
  5.27905102951428412e-1,
  6.05183413124413191e-2,
  2.33520497626869185e-3,
];
