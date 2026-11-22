import 'dart:math';

import 'package:more/number.dart' show Complex;

import 'digamma.dart';
import 'factorial.dart';
import 'gamma.dart';

/// Returns the confluent hypergeometric function `1F1(a; b; z)` (also known
/// as Kummer's function `M(a, b, z)`).
///
/// See https://en.wikipedia.org/wiki/Confluent_hypergeometric_function for
/// details.
double hypergeometric1F1(num a, num b, num z) {
  if (a.isNaN || b.isNaN || z.isNaN) {
    return double.nan;
  }
  final ad = a.toDouble();
  final bd = b.toDouble();
  final zd = z.toDouble();
  if (zd.isInfinite) {
    return double.nan;
  }
  final isANonPosInt = ad.isFinite && ad <= 0.0 && ad.roundToDouble() == ad;
  final isBNonPosInt = bd.isFinite && bd <= 0.0 && bd.roundToDouble() == bd;
  if (isANonPosInt) {
    final n = (-ad).round();
    if (isBNonPosInt && (-bd).round() < n) {
      return double.nan;
    }
    if (zd == 0.0 || n == 0) return 1.0;
    var sum = 1.0;
    var term = 1.0;
    for (var stepIdx = 1; stepIdx <= n; stepIdx++) {
      term *= (ad + stepIdx - 1) / (bd + stepIdx - 1) * zd / stepIdx;
      sum += term;
    }
    return sum;
  }
  if (isBNonPosInt) {
    return double.nan;
  }
  if (zd == 0.0) return 1.0;
  if (zd < 0.0) {
    if (zd < -100.0) {
      final bMinusA = bd - ad;
      if (bMinusA <= 0.0 && bMinusA.roundToDouble() == bMinusA) {
        if (zd <= -710.0) return 0.0;
        return exp(zd) * hypergeometric1F1(bMinusA, bd, -zd);
      }
      // Asymptotic expansion for z -> -infinity:
      // 1F1(a, b, z) ~ Gamma(b) / Gamma(b - a) * (-z)^(-a) * Sum_n (a)_n (1 + a - b)_n / (n! (-z)^n)
      final invNegZ = 1.0 / (-zd);
      var term = 1.0;
      var sum = 1.0;
      for (var n = 1; n <= 100; n++) {
        term *= (ad + n - 1) * (1.0 + ad - bd + n - 1) * invNegZ / n;
        sum += term;
        if (term.abs() < 1e-15 * sum.abs()) break;
      }
      final gammaRatio = gamma(bd) / gamma(bMinusA);
      return gammaRatio * pow(-zd, -ad) * sum;
    }
    // Kummer's first transformation: 1F1(a, b, z) = exp(z) * 1F1(b - a, b, -z)
    return exp(zd) * hypergeometric1F1(bd - ad, bd, -zd);
  }
  var sum = 1.0;
  var term = 1.0;
  for (var stepIdx = 1; stepIdx <= 1500; stepIdx++) {
    term *= (ad + stepIdx - 1) / (bd + stepIdx - 1) * zd / stepIdx;
    sum += term;
    if (term.abs() < 1.0e-15 * sum.abs()) {
      break;
    }
  }
  return sum;
}

/// Returns the complex confluent hypergeometric function `1F1(a; b; z)`.
///
/// See https://en.wikipedia.org/wiki/Confluent_hypergeometric_function for
/// details.
Complex hypergeometric1F1Complex(Complex a, Complex b, Complex z) {
  if (a.isNaN || b.isNaN || z.isNaN) {
    return Complex.nan;
  }
  final isANonPosInt = _isComplexNonPosInt(a);
  final isBNonPosInt = _isComplexNonPosInt(b);
  if (isANonPosInt) {
    final n = (-a.a).round();
    if (isBNonPosInt && (-b.a).round() < n) {
      return Complex.nan;
    }
    if ((z.a == 0.0 && z.b == 0.0) || n == 0) return Complex.one;
    var sum = Complex.one;
    var term = Complex.one;
    for (var k = 1; k <= n; k++) {
      term *= (a + Complex(k - 1)) / (b + Complex(k - 1)) * z / Complex(k);
      sum += term;
    }
    return sum;
  }
  if (isBNonPosInt) {
    return Complex.nan;
  }
  if (z.a == 0.0 && z.b == 0.0) return Complex.one;
  if (z.a < 0.0) {
    return z.exp() * hypergeometric1F1Complex(b - a, b, -z);
  }
  var sum = Complex.one;
  var term = Complex.one;
  for (var k = 1; k <= 1500; k++) {
    term *= (a + Complex(k - 1)) / (b + Complex(k - 1)) * z / Complex(k);
    sum += term;
    if (term.abs() < 1e-15 * sum.abs()) break;
  }
  return sum;
}

/// Returns the Gauss hypergeometric function `2F1(a, b; c; z)`.
///
/// Handles transformations for `z < -1` and `z ≈ 1` to ensure rapid
/// convergence.
///
/// See https://en.wikipedia.org/wiki/Hypergeometric_function for details.
double hypergeometric2F1(num a, num b, num c, num z) {
  if (a.isNaN || b.isNaN || c.isNaN || z.isNaN) {
    return double.nan;
  }
  final ad = a.toDouble();
  final bd = b.toDouble();
  final cd = c.toDouble();
  final zd = z.toDouble();
  final isANonPosInt = ad.isFinite && ad <= 0.0 && ad.roundToDouble() == ad;
  final isBNonPosInt = bd.isFinite && bd <= 0.0 && bd.roundToDouble() == bd;
  final isCNonPosInt = cd.isFinite && cd <= 0.0 && cd.roundToDouble() == cd;
  if (isANonPosInt || isBNonPosInt) {
    final int n;
    if (isANonPosInt && isBNonPosInt) {
      n = min((-ad).round(), (-bd).round());
    } else if (isANonPosInt) {
      n = (-ad).round();
    } else {
      n = (-bd).round();
    }
    if (isCNonPosInt && (-cd).round() < n) {
      return double.nan;
    }
    if (zd == 0.0 || n == 0) return 1.0;
    var sum = 1.0;
    var term = 1.0;
    for (var stepIdx = 1; stepIdx <= n; stepIdx++) {
      term *=
          (ad + stepIdx - 1) *
          (bd + stepIdx - 1) /
          (cd + stepIdx - 1) *
          zd /
          stepIdx;
      sum += term;
    }
    return sum;
  }
  if (isCNonPosInt) {
    return double.nan;
  }
  if (zd == 0.0) return 1.0;
  if (zd > 1.0) {
    return double.nan;
  }
  if (zd < -0.5) {
    if (zd == double.negativeInfinity) {
      if (ad == 0.0 || bd == 0.0) return 1.0;
      final f1 = hypergeometric2F1(ad, cd - bd, cd, 1.0);
      if (ad > 0.0) {
        return f1.isFinite ? 0.0 : double.nan;
      } else {
        return f1 == 0.0
            ? 0.0
            : (f1 > 0 ? double.infinity : double.negativeInfinity);
      }
    }
    final wVal = zd / (zd - 1.0);
    return pow(1.0 - zd, -ad) * hypergeometric2F1(ad, cd - bd, cd, wVal);
  }
  if (zd == 1.0) {
    final diff = cd - ad - bd;
    if (diff <= 0.0) {
      return double.infinity;
    }
    if (_isNonPosInt(cd - ad) || _isNonPosInt(cd - bd)) {
      return 0.0;
    }
    return gamma(cd) * gamma(diff) / (gamma(cd - ad) * gamma(cd - bd));
  }
  if (zd >= 0.9) {
    final diff = cd - ad - bd;
    if (diff.isFinite && diff.roundToDouble() == diff) {
      final m = diff.round();
      if (m < 0) {
        return pow(1.0 - zd, diff) *
            hypergeometric2F1(cd - ad, cd - bd, cd, zd);
      }
      return _hypergeometric2F1Logarithmic(ad, bd, cd, m, zd);
    }
    final term1 = (_isNonPosInt(cd - ad) || _isNonPosInt(cd - bd))
        ? 0.0
        : gamma(cd) *
              gamma(diff) /
              (gamma(cd - ad) * gamma(cd - bd)) *
              hypergeometric2F1(ad, bd, ad + bd - cd + 1.0, 1.0 - zd);
    final term2 =
        gamma(cd) *
        gamma(-diff) /
        (gamma(ad) * gamma(bd)) *
        pow(1.0 - zd, diff) *
        hypergeometric2F1(cd - ad, cd - bd, cd - ad - bd + 1.0, 1.0 - zd);
    return term1 + term2;
  }
  return _hypergeometric2F1Direct(ad, bd, cd, zd);
}

/// Returns the complex Gauss hypergeometric function `2F1(a, b; c; z)`.
///
/// See https://en.wikipedia.org/wiki/Hypergeometric_function for details.
Complex hypergeometric2F1Complex(Complex a, Complex b, Complex c, Complex z) {
  if (a.isNaN || b.isNaN || c.isNaN || z.isNaN) {
    return Complex.nan;
  }
  final isANonPosInt = _isComplexNonPosInt(a);
  final isBNonPosInt = _isComplexNonPosInt(b);
  final isCNonPosInt = _isComplexNonPosInt(c);
  if (isANonPosInt || isBNonPosInt) {
    final int n;
    if (isANonPosInt && isBNonPosInt) {
      n = min((-a.a).round(), (-b.a).round());
    } else if (isANonPosInt) {
      n = (-a.a).round();
    } else {
      n = (-b.a).round();
    }
    if (isCNonPosInt && (-c.a).round() < n) {
      return Complex.nan;
    }
    if ((z.a == 0.0 && z.b == 0.0) || n == 0) return Complex.one;
    var sum = Complex.one;
    var term = Complex.one;
    for (var k = 1; k <= n; k++) {
      term *=
          (a + Complex(k - 1)) *
          (b + Complex(k - 1)) /
          (c + Complex(k - 1)) *
          z /
          Complex(k);
      sum += term;
    }
    return sum;
  }
  if (isCNonPosInt) {
    return Complex.nan;
  }
  if (z.a == 0.0 && z.b == 0.0) return Complex.one;
  if (z.abs() >= 0.8) {
    final w = z / (z - Complex.one);
    if (w.abs() < 0.8) {
      return (Complex.one - z).pow(-a) *
          hypergeometric2F1Complex(a, c - b, c, w);
    }
    final oneMinusZ = Complex.one - z;
    if (oneMinusZ.abs() < 0.8) {
      final diff = c - a - b;
      if (diff.b != 0.0 || diff.a != diff.a.roundToDouble()) {
        final t1 = (_isComplexNonPosInt(c - a) || _isComplexNonPosInt(c - b))
            ? Complex.zero
            : gammaComplex(c) *
                  gammaComplex(diff) /
                  (gammaComplex(c - a) * gammaComplex(c - b)) *
                  hypergeometric2F1Complex(
                    a,
                    b,
                    a + b - c + Complex.one,
                    oneMinusZ,
                  );
        final t2 = (_isComplexNonPosInt(a) || _isComplexNonPosInt(b))
            ? Complex.zero
            : gammaComplex(c) *
                  gammaComplex(-diff) /
                  (gammaComplex(a) * gammaComplex(b)) *
                  oneMinusZ.pow(diff) *
                  hypergeometric2F1Complex(
                    c - a,
                    c - b,
                    c - a - b + Complex.one,
                    oneMinusZ,
                  );
        return t1 + t2;
      }
    }
    if (z.abs() > 1.25) {
      final abDiff = a - b;
      if (abDiff.b != 0.0 || abDiff.a != abDiff.a.roundToDouble()) {
        final invZ = z.reciprocal();
        final negZ = -z;
        final t1 = (_isComplexNonPosInt(b) || _isComplexNonPosInt(c - a))
            ? Complex.zero
            : gammaComplex(c) *
                  gammaComplex(-abDiff) /
                  (gammaComplex(b) * gammaComplex(c - a)) *
                  negZ.pow(-a) *
                  hypergeometric2F1Complex(
                    a,
                    a - c + Complex.one,
                    abDiff + Complex.one,
                    invZ,
                  );
        final t2 = (_isComplexNonPosInt(a) || _isComplexNonPosInt(c - b))
            ? Complex.zero
            : gammaComplex(c) *
                  gammaComplex(abDiff) /
                  (gammaComplex(a) * gammaComplex(c - b)) *
                  negZ.pow(-b) *
                  hypergeometric2F1Complex(
                    b,
                    b - c + Complex.one,
                    -abDiff + Complex.one,
                    invZ,
                  );
        return t1 + t2;
      }
    }
  }
  var sum = Complex.one;
  var term = Complex.one;
  for (var k = 1; k <= 1500; k++) {
    term *=
        (a + Complex(k - 1)) *
        (b + Complex(k - 1)) /
        (c + Complex(k - 1)) *
        z /
        Complex(k);
    sum += term;
    if (term.abs() < 1e-15 * sum.abs()) break;
  }
  return sum;
}

/// Evaluates the generalized hypergeometric function `pFq(a; b; z)`.
///
/// See https://en.wikipedia.org/wiki/Generalized_hypergeometric_function for
/// details.
double hypergeometricPFQ(List<num> a, List<num> b, num z) {
  if (z.isNaN || a.any((v) => v.isNaN) || b.any((v) => v.isNaN)) {
    return double.nan;
  }
  if (a.isEmpty && b.isEmpty) return exp(z.toDouble());
  if (a.length == 1 && b.isEmpty) {
    return pow(1.0 - z.toDouble(), -a[0].toDouble()).toDouble();
  }
  if (a.length == 2 && b.length == 1) {
    return hypergeometric2F1(a[0], a[1], b[0], z);
  }
  if (a.length == 1 && b.length == 1) {
    return hypergeometric1F1(a[0], b[0], z);
  }
  final zd = z.toDouble();
  if (zd == 0.0) return 1.0;
  var sum = 1.0;
  var term = 1.0;
  for (var k = 0; k < 400; k++) {
    var numProd = 1.0;
    for (final ai in a) {
      numProd *= ai.toDouble() + k;
    }
    if (numProd == 0.0) break;
    var denProd = (k + 1).toDouble();
    for (final bj in b) {
      final denom = bj.toDouble() + k;
      if (denom == 0.0) return double.nan;
      denProd *= denom;
    }
    term *= numProd * zd / denProd;
    sum += term;
    if (term.abs() <= 1e-15 * sum.abs()) break;
  }
  return sum;
}

/// Evaluates the complex generalized hypergeometric function `pFq(a; b; z)`.
///
/// See https://en.wikipedia.org/wiki/Generalized_hypergeometric_function for
/// details.
Complex hypergeometricPFQComplex(List<Complex> a, List<Complex> b, Complex z) {
  if (z.isNaN || a.any((v) => v.isNaN) || b.any((v) => v.isNaN)) {
    return Complex.nan;
  }
  if (a.isEmpty && b.isEmpty) return z.exp();
  if (a.length == 1 && b.isEmpty) return (Complex.one - z).pow(-a[0]);
  if (a.length == 2 && b.length == 1) {
    return hypergeometric2F1Complex(a[0], a[1], b[0], z);
  }
  if (a.length == 1 && b.length == 1) {
    return hypergeometric1F1Complex(a[0], b[0], z);
  }
  if (z == Complex.zero) return Complex.one;
  var sum = Complex.one;
  var term = Complex.one;
  for (var k = 0; k < 400; k++) {
    var numProd = Complex.one;
    for (final ai in a) {
      numProd *= ai + k.toDouble();
    }
    if (numProd == Complex.zero) break;
    var denProd = Complex(k + 1);
    for (final bj in b) {
      final denom = bj + k.toDouble();
      if (denom == Complex.zero) return Complex.nan;
      denProd *= denom;
    }
    term *= numProd * z / denProd;
    sum += term;
    if (term.abs() <= 1e-15 * sum.abs()) break;
  }
  return sum;
}

bool _isNonPosInt(double x) => x.isFinite && x <= 0.0 && x.roundToDouble() == x;

bool _isComplexNonPosInt(Complex z) =>
    z.b == 0.0 && z.a.isFinite && z.a <= 0.0 && z.a == z.a.roundToDouble();

double _hypergeometric2F1Logarithmic(
  double a,
  double b,
  double cVal,
  int m,
  double z,
) {
  final oneMinusZ = 1.0 - z;
  var finiteSum = 0.0;
  if (m > 0) {
    var poly = 1.0;
    var term = 1.0;
    for (var n = 1; n < m; n++) {
      term *= (a + n - 1) * (b + n - 1) / (n * (n - m)) * oneMinusZ;
      poly += term;
    }
    final finitePrefactor = (a + m > 0 && b + m > 0 && cVal > 0)
        ? exp(gammaLn(m) + gammaLn(cVal) - gammaLn(a + m) - gammaLn(b + m))
        : gamma(m) * gamma(cVal) / (gamma(a + m) * gamma(b + m));
    finiteSum = finitePrefactor * poly;
  }
  final gammaRatio = (a > 0 && b > 0 && cVal > 0)
      ? exp(gammaLn(cVal) - gammaLn(a) - gammaLn(b))
      : gamma(cVal) / (gamma(a) * gamma(b));
  final infPrefactor = (m.isEven ? -1.0 : 1.0) * gammaRatio * pow(oneMinusZ, m);
  final lnOneMinusZ = log(oneMinusZ);
  var coeff = 1.0 / factorial(m);
  var psiN1 = digamma(1.0);
  var psiNM1 = digamma(m + 1.0);
  var psiA = digamma(a + m);
  var psiB = digamma(b + m);
  var infSum = coeff * (lnOneMinusZ - psiN1 - psiNM1 + psiA + psiB);
  for (var n = 0; n < 2000; n++) {
    final n1 = n + 1;
    final nm1 = n + m + 1;
    final amn = a + m + n;
    final bmn = b + m + n;
    coeff *= amn * bmn / (n1 * nm1) * oneMinusZ;
    psiN1 += 1.0 / n1;
    psiNM1 += 1.0 / nm1;
    psiA += 1.0 / amn;
    psiB += 1.0 / bmn;
    final term = coeff * (lnOneMinusZ - psiN1 - psiNM1 + psiA + psiB);
    infSum += term;
    if (term.abs() < 1.0e-15 * infSum.abs()) {
      break;
    }
  }
  return finiteSum + infPrefactor * infSum;
}

double _hypergeometric2F1Direct(double a, double b, double c, double z) {
  var sum = 1.0;
  var term = 1.0;
  for (var stepIdx = 1; stepIdx <= 2000; stepIdx++) {
    term *=
        (a + stepIdx - 1) * (b + stepIdx - 1) / (c + stepIdx - 1) * z / stepIdx;
    sum += term;
    if (term.abs() < 1.0e-15 * sum.abs()) {
      break;
    }
  }
  return sum;
}
