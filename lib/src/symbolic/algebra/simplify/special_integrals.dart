import '../../../special/elliptic.dart' as special_elliptic;
import '../../../special/erf.dart' as special_erf;
import '../../../special/exp_integral.dart' as special_exp_int;
import '../../../special/fresnel.dart' as special_fresnel;
import '../../../special/gamma.dart' as special_gamma;
import '../../../special/hypergeometric.dart' as special_hyper;
import '../../../special/polylog.dart' as special_polylog;
import '../../../special/trig_integral.dart' as special_trig_int;
import '../../assumptions.dart';
import '../../ast.dart';
import '../../functions/fn.dart';
import '../simplify.dart';
import 'additive.dart';
import 'multiplicative.dart';
import 'power.dart';
import 'special.dart'
    show
        complexToExpr,
        isFloatComplex,
        isFloatComplexPair,
        simplifyGamma,
        simplifyZeta,
        toComplex;
import 'transcendental.dart';

Expr simplifyEllipticK(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (isFloatComplex(expr)) {
    return complexToExpr(special_elliptic.ellipticKComplex(toComplex(expr)));
  }
  if (expr == IntegerNumber.zero) {
    return simplifyMul([
      FractionNumber.half,
      Constant.pi,
    ], assumptions: assumptions);
  }
  if (expr is RealNumber) {
    return RealNumber.fromDouble(special_elliptic.ellipticK(expr.value));
  }
  return Fn.ellipticK(expr);
}

/// Simplifies a complete or incomplete elliptic integral of the second kind
/// `ellipticE(k)` or `ellipticE(phi, k)`.
Expr simplifyEllipticE(
  Expr expr, {
  Expr? amplitude,
  required Assumptions assumptions,
}) {
  if (expr == Constant.undefined || amplitude == Constant.undefined) {
    return Constant.undefined;
  }
  if (amplitude != null) {
    if (isFloatComplexPair(amplitude, expr)) {
      return complexToExpr(
        special_elliptic.ellipticEComplex(
          toComplex(expr),
          phi: toComplex(amplitude),
        ),
      );
    }
    if (amplitude == IntegerNumber.zero) return IntegerNumber.zero;
    if (expr == IntegerNumber.zero) return amplitude;
    if (amplitude ==
        simplifyMul([
          FractionNumber.half,
          Constant.pi,
        ], assumptions: assumptions)) {
      return simplifyEllipticE(expr, assumptions: assumptions);
    }
    if (amplitude is RealNumeric &&
        expr is RealNumeric &&
        (amplitude is RealNumber || expr is RealNumber)) {
      return RealNumber.fromDouble(
        special_elliptic.ellipticE(expr.toDouble(), phi: amplitude.toDouble()),
      );
    }
    return Fn.ellipticE(amplitude, expr);
  }
  if (isFloatComplex(expr)) {
    return complexToExpr(special_elliptic.ellipticEComplex(toComplex(expr)));
  }
  if (expr == IntegerNumber.zero) {
    return simplifyMul([
      FractionNumber.half,
      Constant.pi,
    ], assumptions: assumptions);
  }
  if (expr == IntegerNumber.one) {
    return IntegerNumber.one;
  }
  if (expr is RealNumber) {
    return RealNumber.fromDouble(special_elliptic.ellipticE(expr.value));
  }
  return Fn.ellipticE(expr);
}

/// Simplifies an imaginary error function `erfi(x)`.
Expr simplifyErfi(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (isFloatComplex(expr)) {
    return complexToExpr(special_erf.erfiComplex(toComplex(expr)));
  }
  if (expr == IntegerNumber.zero) return IntegerNumber.zero;
  if (expr is RealNumber) {
    return RealNumber.fromDouble(special_erf.erfi(expr.value));
  }
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(
      simplifyErfi(posExpr, assumptions: assumptions),
      assumptions: assumptions,
    );
  }
  return Fn.erfi(expr);
}

/// Simplifies a Fresnel sine integral `fresnelS(x)`.
Expr simplifyFresnelS(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (isFloatComplex(expr)) {
    return complexToExpr(special_fresnel.fresnelSComplex(toComplex(expr)));
  }
  if (expr == IntegerNumber.zero) return IntegerNumber.zero;
  if (expr is RealNumber) {
    return RealNumber.fromDouble(special_fresnel.fresnelS(expr.value));
  }
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(
      simplifyFresnelS(posExpr, assumptions: assumptions),
      assumptions: assumptions,
    );
  }
  return Fn.fresnelS(expr);
}

/// Simplifies a Fresnel cosine integral `fresnelC(x)`.
Expr simplifyFresnelC(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (isFloatComplex(expr)) {
    return complexToExpr(special_fresnel.fresnelCComplex(toComplex(expr)));
  }
  if (expr == IntegerNumber.zero) return IntegerNumber.zero;
  if (expr is RealNumber) {
    return RealNumber.fromDouble(special_fresnel.fresnelC(expr.value));
  }
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(
      simplifyFresnelC(posExpr, assumptions: assumptions),
      assumptions: assumptions,
    );
  }
  return Fn.fresnelC(expr);
}

/// Simplifies an exponential integral `Ei(x)`.
Expr simplifyExpIntegralEi(Expr expr) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr == IntegerNumber.zero) {
    return Mul.of([IntegerNumber.negativeOne, Constant.infinity]);
  }
  if (expr == Constant.infinity) return Constant.infinity;
  if (expr case Mul(
    factors: [IntegerNumber(isNegativeOne: true), Constant.infinity],
  )) {
    return IntegerNumber.zero;
  }
  if (isFloatComplex(expr)) {
    return complexToExpr(special_exp_int.expIntegralComplex(toComplex(expr)));
  }
  if (expr is RealNumber) {
    return RealNumber.fromDouble(special_exp_int.expIntegral(expr.value));
  }
  return Fn.ei(expr);
}

/// Simplifies a logarithmic integral `li(x)`.
Expr simplifyLogIntegralLi(Expr expr) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (isFloatComplex(expr)) {
    return complexToExpr(special_exp_int.logIntegralComplex(toComplex(expr)));
  }
  if (expr == IntegerNumber.zero) return IntegerNumber.zero;
  if (expr == IntegerNumber.one) {
    return Mul.of([IntegerNumber.negativeOne, Constant.infinity]);
  }
  if (expr is RealNumber) {
    return RealNumber.fromDouble(special_exp_int.logIntegral(expr.value));
  }
  return Fn.li(expr);
}

/// Simplifies a sine integral `Si(x)`.
Expr simplifySinIntegralSi(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (isFloatComplex(expr)) {
    return complexToExpr(special_trig_int.sinIntegralComplex(toComplex(expr)));
  }
  if (expr == IntegerNumber.zero) return IntegerNumber.zero;
  if (expr is RealNumber) {
    return RealNumber.fromDouble(special_trig_int.sinIntegral(expr.value));
  }
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(
      simplifySinIntegralSi(posExpr, assumptions: assumptions),
      assumptions: assumptions,
    );
  }
  return Fn.si(expr);
}

/// Simplifies a cosine integral `Ci(x)`.
Expr simplifyCosIntegralCi(Expr expr) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (isFloatComplex(expr)) {
    return complexToExpr(special_trig_int.cosIntegralComplex(toComplex(expr)));
  }
  if (expr is RealNumber) {
    return RealNumber.fromDouble(special_trig_int.cosIntegral(expr.value));
  }
  return Fn.ci(expr);
}

/// Simplifies a hyperbolic sine integral `Shi(x)`.
Expr simplifySinhIntegralShi(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (isFloatComplex(expr)) {
    return complexToExpr(special_trig_int.sinhIntegralComplex(toComplex(expr)));
  }
  if (expr == IntegerNumber.zero) return IntegerNumber.zero;
  if (expr is RealNumber) {
    return RealNumber.fromDouble(special_trig_int.sinhIntegral(expr.value));
  }
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(
      simplifySinhIntegralShi(posExpr, assumptions: assumptions),
      assumptions: assumptions,
    );
  }
  return Fn.shi(expr);
}

/// Simplifies a hyperbolic cosine integral `Chi(x)`.
Expr simplifyCoshIntegralChi(Expr expr) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (isFloatComplex(expr)) {
    return complexToExpr(special_trig_int.coshIntegralComplex(toComplex(expr)));
  }
  if (expr is RealNumber) {
    return RealNumber.fromDouble(special_trig_int.coshIntegral(expr.value));
  }
  return Fn.chi(expr);
}

/// Simplifies an upper incomplete gamma function `upperGamma(s, x)`.
Expr simplifyUpperGamma(Expr s, Expr x, {required Assumptions assumptions}) {
  if (s == Constant.undefined || x == Constant.undefined) {
    return Constant.undefined;
  }
  if (isFloatComplexPair(s, x)) {
    return complexToExpr(
      special_gamma.upperGammaComplex(toComplex(s), toComplex(x)),
    );
  }
  if (x == IntegerNumber.zero && s is RealNumeric && s.sign > 0) {
    return simplifyGamma(s, assumptions: assumptions);
  }
  if (s == IntegerNumber.one) {
    return simplifyPow(
      Constant.e,
      simplifyNeg(x, assumptions: assumptions),
      assumptions: assumptions,
    );
  }
  if (s is RealNumeric &&
      x is RealNumeric &&
      (s is RealNumber || x is RealNumber)) {
    return RealNumber.fromDouble(
      special_gamma.upperGamma(s.toDouble(), x.toDouble()),
    );
  }
  return Fn.upperGamma(s, x);
}

/// Simplifies a lower incomplete gamma function `lowerGamma(s, x)`.
Expr simplifyLowerGamma(Expr s, Expr x, {required Assumptions assumptions}) {
  if (s == Constant.undefined || x == Constant.undefined) {
    return Constant.undefined;
  }
  if (isFloatComplexPair(s, x)) {
    return complexToExpr(
      special_gamma.lowerGammaComplex(toComplex(s), toComplex(x)),
    );
  }
  if (x == IntegerNumber.zero && s is RealNumeric && s.sign > 0) {
    return IntegerNumber.zero;
  }
  if (s == IntegerNumber.one) {
    return simplifyAdd([
      IntegerNumber.one,
      simplifyNeg(
        simplifyPow(
          Constant.e,
          simplifyNeg(x, assumptions: assumptions),
          assumptions: assumptions,
        ),
        assumptions: assumptions,
      ),
    ], assumptions: assumptions);
  }
  if (s is RealNumeric &&
      x is RealNumeric &&
      (s is RealNumber || x is RealNumber)) {
    return RealNumber.fromDouble(
      special_gamma.lowerGamma(s.toDouble(), x.toDouble()),
    );
  }
  return Fn.lowerGamma(s, x);
}

/// Simplifies a polylogarithm `polylog(s, z)`.
Expr simplifyPolylog(Expr s, Expr z, {required Assumptions assumptions}) {
  if (s == Constant.undefined || z == Constant.undefined) {
    return Constant.undefined;
  }
  if (isFloatComplexPair(s, z)) {
    return complexToExpr(
      special_polylog.polylogComplex(toComplex(s), toComplex(z)),
    );
  }
  if (z == IntegerNumber.zero) return IntegerNumber.zero;
  if (s == IntegerNumber.one) {
    return simplifyNeg(
      simplifyLn(
        simplifyAdd([
          IntegerNumber.one,
          simplifyNeg(z, assumptions: assumptions),
        ], assumptions: assumptions),
        assumptions: assumptions,
      ),
      assumptions: assumptions,
    );
  }
  if (s == IntegerNumber.zero) {
    return simplifyDiv(
      z,
      simplifyAdd([
        IntegerNumber.one,
        simplifyNeg(z, assumptions: assumptions),
      ], assumptions: assumptions),
      assumptions: assumptions,
    );
  }
  if (z == IntegerNumber.one && s is RealNumeric && s.toDouble() > 1.0) {
    return simplifyZeta(s);
  }
  if (z == IntegerNumber.negativeOne &&
      s is RealNumeric &&
      s.toDouble() > 1.0) {
    final zetaVal = simplifyZeta(s);
    if (zetaVal is! Call || zetaVal.id != FunctionId.zeta) {
      return simplifyMul([
        simplifyAdd([
          simplifyPow(
            IntegerNumber.two,
            simplifyAdd([
              IntegerNumber.one,
              simplifyNeg(s, assumptions: assumptions),
            ], assumptions: assumptions),
            assumptions: assumptions,
          ),
          IntegerNumber.negativeOne,
        ], assumptions: assumptions),
        zetaVal,
      ], assumptions: assumptions);
    }
  }
  if (s is RealNumeric &&
      z is RealNumeric &&
      (s is RealNumber || z is RealNumber)) {
    return RealNumber.fromDouble(
      special_polylog.polylog(s.toDouble(), z.toDouble()),
    );
  }
  return Fn.polylog(s, z);
}

/// Simplifies an incomplete elliptic integral of the first kind `ellipticF(phi, k)`.
Expr simplifyEllipticF(Expr phi, Expr k, {required Assumptions assumptions}) {
  if (phi == Constant.undefined || k == Constant.undefined) {
    return Constant.undefined;
  }
  if (isFloatComplexPair(phi, k)) {
    return complexToExpr(
      special_elliptic.ellipticFComplex(toComplex(phi), toComplex(k)),
    );
  }
  if (phi == IntegerNumber.zero) return IntegerNumber.zero;
  if (k == IntegerNumber.zero) return phi;
  if (phi ==
      simplifyMul([
        FractionNumber.half,
        Constant.pi,
      ], assumptions: assumptions)) {
    return simplifyEllipticK(k, assumptions: assumptions);
  }
  if (phi is RealNumeric &&
      k is RealNumeric &&
      (phi is RealNumber || k is RealNumber)) {
    return RealNumber.fromDouble(
      special_elliptic.ellipticF(phi.toDouble(), k.toDouble()),
    );
  }
  return Fn.ellipticF(phi, k);
}

/// Simplifies an incomplete elliptic integral of the second kind `ellipticE(phi, k)`.
/// Simplifies an incomplete elliptic integral of the third kind `Pi(n; phi | k)`.
Expr simplifyEllipticPi(
  Expr n,
  Expr phi,
  Expr k, {
  required Assumptions assumptions,
}) {
  if (n == Constant.undefined ||
      phi == Constant.undefined ||
      k == Constant.undefined) {
    return Constant.undefined;
  }
  if (phi == IntegerNumber.zero) return IntegerNumber.zero;
  if (n == IntegerNumber.zero) {
    return simplifyEllipticF(phi, k, assumptions: assumptions);
  }
  if (isFloatComplex(n) || isFloatComplex(phi) || isFloatComplex(k)) {
    if ((n is RealNumeric || isFloatComplex(n)) &&
        (phi is RealNumeric || isFloatComplex(phi)) &&
        (k is RealNumeric || isFloatComplex(k))) {
      return complexToExpr(
        special_elliptic.ellipticPiComplex(
          toComplex(n),
          toComplex(k),
          phi: toComplex(phi),
        ),
      );
    }
  }
  if (n is RealNumeric &&
      phi is RealNumeric &&
      k is RealNumeric &&
      (n is RealNumber || phi is RealNumber || k is RealNumber)) {
    final val = special_elliptic.ellipticPi(
      n.toDouble(),
      k.toDouble(),
      phi: phi.toDouble(),
    );
    if (!val.isNaN) return RealNumber.fromDouble(val);
    return complexToExpr(
      special_elliptic.ellipticPiComplex(
        toComplex(n),
        toComplex(k),
        phi: toComplex(phi),
      ),
    );
  }
  return Fn.ellipticPi(n, phi, k);
}

/// Simplifies a generalized exponential integral `E_n(z)`.
Expr simplifyExpIntegralE(Expr n, Expr z) {
  if (n == Constant.undefined || z == Constant.undefined) {
    return Constant.undefined;
  }
  if (n is Number && n.isZero) {
    return (Pow.of(Constant.e, -z) / z).simplify();
  }
  if (z is Number && z.isZero) {
    if (n is RationalNumber && n.compareTo(IntegerNumber.one) > 0) {
      return (IntegerNumber.one / (n - IntegerNumber.one)).simplify();
    }
    if (n is RealNumeric && n.toDouble() <= 1.0) {
      return Constant.undefined;
    }
  }
  if (n is Number && z is Number && (n is RealNumber || z is RealNumber)) {
    if (n is ComplexNumber || z is ComplexNumber) {
      return complexToExpr(
        special_exp_int.expIntegralEComplex(toComplex(n), toComplex(z)),
      );
    }
    final val = special_exp_int.expIntegralE(
      (n as RealNumeric).toDouble(),
      (z as RealNumeric).toDouble(),
    );
    if (!val.isNaN) return RealNumber.fromDouble(val);
    return complexToExpr(
      special_exp_int.expIntegralEComplex(toComplex(n), toComplex(z)),
    );
  }
  return Fn.expIntegralE(n, z);
}

/// Simplifies a generalized hypergeometric function `pFq(upper; lower; z)`.
Expr simplifyHypergeometric(List<Expr> upper, List<Expr> lower, Expr z) {
  if (z == Constant.undefined ||
      upper.any((e) => e == Constant.undefined) ||
      lower.any((e) => e == Constant.undefined)) {
    return Constant.undefined;
  }
  if (z is Number && z.isZero) return IntegerNumber.one;
  if (upper.any((e) => e is Number && e.isZero)) {
    if (lower.any((e) => e is IntegerNumber && (e.isNegative || e.isZero))) {
      return Constant.undefined;
    }
    return IntegerNumber.one;
  }

  // Cancel identical upper and lower parameters (skipping non-positive integer poles).
  final remUpper = <Expr>[];
  final remLower = List<Expr>.from(lower);
  for (final u in upper) {
    final isPole = u is IntegerNumber && (u.isNegative || u.isZero);
    final idx = isPole ? -1 : remLower.indexOf(u);
    if (idx != -1) {
      remLower.removeAt(idx);
    } else {
      remUpper.add(u);
    }
  }

  if (remUpper.isEmpty && remLower.isEmpty) {
    return Pow.of(Constant.e, z).simplify();
  }
  if (remUpper.length == 1 && remLower.isEmpty) {
    return Pow.of(IntegerNumber.one - z, -remUpper.first).simplify();
  }

  if (z is Number &&
      remUpper.every((e) => e is Number) &&
      remLower.every((e) => e is Number) &&
      (z is RealNumber ||
          remUpper.any((e) => e is RealNumber) ||
          remLower.any((e) => e is RealNumber))) {
    if (z is ComplexNumber ||
        remUpper.any((e) => e is ComplexNumber) ||
        remLower.any((e) => e is ComplexNumber)) {
      return complexToExpr(
        special_hyper.hypergeometricPFQComplex(
          remUpper.map(toComplex).toList(),
          remLower.map(toComplex).toList(),
          toComplex(z),
        ),
      );
    }
    final val = special_hyper.hypergeometricPFQ(
      remUpper.map((e) => (e as RealNumeric).toDouble()).toList(),
      remLower.map((e) => (e as RealNumeric).toDouble()).toList(),
      (z as RealNumeric).toDouble(),
    );
    if (!val.isNaN) return RealNumber.fromDouble(val);
  }

  return Fn.hypergeometric(Fn.tuple(remUpper), Fn.tuple(remLower), z);
}

/// Simplifies an Appell hypergeometric function `F_1(a; b1, b2; c; x, y)`.
Expr simplifyAppellF1(
  Expr a,
  Expr b1,
  Expr b2,
  Expr c,
  Expr x,
  Expr y, {
  Assumptions assumptions = Assumptions.none,
}) {
  if (a == Constant.undefined ||
      b1 == Constant.undefined ||
      b2 == Constant.undefined ||
      c == Constant.undefined ||
      x == Constant.undefined ||
      y == Constant.undefined) {
    return Constant.undefined;
  }
  if (c case IntegerNumber(:final isZero, :final isNegative)
      when isZero || isNegative) {
    if (a is! IntegerNumber || !a.isNegative || a.value < c.value) {
      return Constant.undefined;
    }
  }
  if (a is Number && a.isZero) return IntegerNumber.one;
  if ((x is Number && x.isZero) || (b1 is Number && b1.isZero)) {
    return simplifyHypergeometric([a, b2], [c], y);
  }
  if ((y is Number && y.isZero) || (b2 is Number && b2.isZero)) {
    return simplifyHypergeometric([a, b1], [c], x);
  }
  if (x == y) {
    return simplifyHypergeometric(
      [
        a,
        simplifyAdd([b1, b2], assumptions: assumptions),
      ],
      [c],
      x,
    );
  }
  if (a == c) {
    final oneMinusX = simplifyAdd([
      IntegerNumber.one,
      simplifyNeg(x, assumptions: assumptions),
    ], assumptions: assumptions);
    final oneMinusY = simplifyAdd([
      IntegerNumber.one,
      simplifyNeg(y, assumptions: assumptions),
    ], assumptions: assumptions);
    return simplifyMul([
      simplifyPow(
        oneMinusX,
        simplifyNeg(b1, assumptions: assumptions),
        assumptions: assumptions,
      ),
      simplifyPow(
        oneMinusY,
        simplifyNeg(b2, assumptions: assumptions),
        assumptions: assumptions,
      ),
    ], assumptions: assumptions);
  }
  if (a is Number &&
      b1 is Number &&
      b2 is Number &&
      c is Number &&
      x is Number &&
      y is Number &&
      (a is RealNumber ||
          b1 is RealNumber ||
          b2 is RealNumber ||
          c is RealNumber ||
          x is RealNumber ||
          y is RealNumber)) {
    if (a is ComplexNumber ||
        b1 is ComplexNumber ||
        b2 is ComplexNumber ||
        c is ComplexNumber ||
        x is ComplexNumber ||
        y is ComplexNumber) {
      return complexToExpr(
        special_hyper.appellF1Complex(
          toComplex(a),
          toComplex(b1),
          toComplex(b2),
          toComplex(c),
          toComplex(x),
          toComplex(y),
        ),
      );
    }
    final val = special_hyper.appellF1(
      (a as RealNumeric).toDouble(),
      (b1 as RealNumeric).toDouble(),
      (b2 as RealNumeric).toDouble(),
      (c as RealNumeric).toDouble(),
      (x as RealNumeric).toDouble(),
      (y as RealNumeric).toDouble(),
    );
    if (!val.isNaN) return RealNumber.fromDouble(val);
    return complexToExpr(
      special_hyper.appellF1Complex(
        toComplex(a),
        toComplex(b1),
        toComplex(b2),
        toComplex(c),
        toComplex(x),
        toComplex(y),
      ),
    );
  }
  return Fn.appellF1([a, b1, b2, c, x, y]);
}
