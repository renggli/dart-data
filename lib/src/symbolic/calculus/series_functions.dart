import 'dart:math' as math;

import 'package:more/math.dart';

import '../algebra/simplify.dart';
import '../assumptions.dart';
import '../ast.dart';
import '../compiler.dart';
import '../functions/fn.dart';
import '../oracle/sign.dart';
import 'differentiation.dart';
import 'series.dart';

PowerSeries expandSin(Expr inner, String variable, Expr point, int order) =>
    expandSinCos(inner, variable, point, order).sin;

PowerSeries expandCos(Expr inner, String variable, Expr point, int order) =>
    expandSinCos(inner, variable, point, order).cos;

({PowerSeries sin, PowerSeries cos}) expandSinCos(
  Expr inner,
  String variable,
  Expr point,
  int order,
) {
  final u = expandToPowerSeries(inner, variable, point, order);
  checkNoPole(u, 'sin/cos');
  return expandSinCosFromSeries(u);
}

({PowerSeries sin, PowerSeries cos}) expandSinCosFromSeries(PowerSeries u) {
  final variable = u.variable;
  final point = u.point;
  final order = u.order;
  final u0 = u.constantTerm;

  final s = <int, Expr>{};
  final c = <int, Expr>{};
  s[0] = IntegerNumber.zero;
  c[0] = IntegerNumber.one;

  for (var k = 1; k < order; k++) {
    Expr sumS = IntegerNumber.zero;
    Expr sumC = IntegerNumber.zero;
    for (var j = 1; j <= k; j++) {
      final uj = u.coefficients[j];
      if (uj != null && !PowerSeries.isZero(uj)) {
        final weight = (IntegerNumber.of(j) * uj).simplify();
        final cPrev = c[k - j] ?? IntegerNumber.zero;
        if (!PowerSeries.isZero(cPrev)) {
          sumS = (sumS + weight * cPrev).simplify();
        }
        final sPrev = s[k - j] ?? IntegerNumber.zero;
        if (!PowerSeries.isZero(sPrev)) {
          sumC = (sumC + weight * sPrev).simplify();
        }
      }
    }
    if (!PowerSeries.isZero(sumS)) {
      s[k] = (sumS / IntegerNumber.of(k)).simplify();
    }
    if (!PowerSeries.isZero(sumC)) {
      c[k] = (-(sumC / IntegerNumber.of(k))).simplify();
    }
  }

  final sinBase = PowerSeries(variable, point, s, order);
  final cosBase = PowerSeries(variable, point, c, order);

  if (PowerSeries.isZero(u0)) {
    return (sin: sinBase, cos: cosBase);
  }
  final sinVal = Fn.sin(u0).simplify();
  final cosVal = Fn.cos(u0).simplify();
  final sinFull = cosBase.scale(sinVal) + sinBase.scale(cosVal);
  final cosFull = cosBase.scale(cosVal) - sinBase.scale(sinVal);
  return (sin: sinFull, cos: cosFull);
}

({PowerSeries sinh, PowerSeries cosh}) expandSinhCosh(
  Expr inner,
  String variable,
  Expr point,
  int order,
) {
  final u = expandToPowerSeries(inner, variable, point, order);
  checkNoPole(u, 'sinh/cosh');
  return expandSinhCoshFromSeries(u);
}

({PowerSeries sinh, PowerSeries cosh}) expandSinhCoshFromSeries(PowerSeries u) {
  final expU = expandExpFromSeries(u);
  final expNegU = expandExpFromSeries(-u);
  return (
    sinh: (expU - expNegU).scale(FractionNumber.half),
    cosh: (expU + expNegU).scale(FractionNumber.half),
  );
}

PowerSeries expandSinh(Expr inner, String variable, Expr point, int order) =>
    expandSinhCosh(inner, variable, point, order).sinh;

PowerSeries expandCosh(Expr inner, String variable, Expr point, int order) =>
    expandSinhCosh(inner, variable, point, order).cosh;

PowerSeries expandAtan(Expr inner, String variable, Expr point, int order) {
  final u = expandToPowerSeries(inner, variable, point, order);
  checkNoPole(u, 'atan');
  final u0 = u.constantTerm;
  final uPrime = u.derivative();
  final denom =
      PowerSeries(variable, point, {0: IntegerNumber.one}, order) + (u * u);
  final deriv = uPrime / denom;
  final constant = Fn.atan(u0).simplify();
  return deriv.integrate(constant: constant);
}

PowerSeries expandAsin(Expr inner, String variable, Expr point, int order) {
  final u = expandToPowerSeries(inner, variable, point, order);
  checkNoPole(u, 'asin');
  final u0 = u.constantTerm;
  final uPrime = u.derivative();
  final oneMinusU2 =
      PowerSeries(variable, point, {0: IntegerNumber.one}, order) - (u * u);
  if (PowerSeries.isZero(oneMinusU2.constantTerm)) {
    throw UnsupportedError('Branch point singularity');
  }
  final invSqrt = oneMinusU2.pow(FractionNumber.negativeHalf);
  final deriv = uPrime * invSqrt;
  final constant = Fn.asin(u0).simplify();
  return deriv.integrate(constant: constant);
}

PowerSeries expandPow(
  Expr base,
  Expr exponent,
  String variable,
  Expr point,
  int order, [
  Assumptions assumptions = Assumptions.none,
]) {
  if (!exponent.dependsOn(variable)) {
    final expSimp = exponent.simplify(assumptions: assumptions);
    var probeOrder = math.max(order, 4);
    var sBase = expandToPowerSeries(
      base,
      variable,
      point,
      probeOrder,
      assumptions,
    );
    while (sBase.coefficients.isEmpty && probeOrder < math.max(order, 4) + 64) {
      probeOrder *= 2;
      sBase = expandToPowerSeries(
        base,
        variable,
        point,
        probeOrder,
        assumptions,
      );
    }
    if (sBase.coefficients.isNotEmpty) {
      final m = sBase.valuation;
      if (expSimp case IntegerNumber(asInt: final intExp?)) {
        if (intExp < 0) {
          final k = -intExp;
          if (m > 0) {
            final requiredOrder = math.max(m + 1, order + (k + 1) * m);
            if (requiredOrder > sBase.order) {
              sBase = expandToPowerSeries(
                base,
                variable,
                point,
                requiredOrder,
                assumptions,
              );
            }
          }
        } else if (intExp > 1 && m < 0) {
          final requiredOrder = order + (intExp - 1) * (-m);
          if (requiredOrder > sBase.order) {
            sBase = expandToPowerSeries(
              base,
              variable,
              point,
              requiredOrder,
              assumptions,
            );
          }
        }
      } else if (expSimp is FractionNumber && m != 0) {
        final prod = BigInt.from(m) * expSimp.numerator;
        if (prod % expSimp.denominator == BigInt.zero) {
          final newM = (prod ~/ expSimp.denominator).toInt();
          final requiredOrder = math.max(m + 1, m + (order - newM));
          if (requiredOrder > sBase.order) {
            sBase = expandToPowerSeries(
              base,
              variable,
              point,
              requiredOrder,
              assumptions,
            );
          }
        }
      }
    }
    final res = sBase.pow(expSimp);
    if (res.order > order) {
      return PowerSeries(variable, point, res.coefficients, order);
    }
    return res;
  }
  return expandExp(exponent * Fn.ln(base), variable, point, order, assumptions);
}

PowerSeries expandAbs(
  Expr inner,
  String variable,
  Expr point,
  int order, [
  Assumptions assumptions = Assumptions.none,
]) {
  final sInner = expandToPowerSeries(
    inner,
    variable,
    point,
    order,
    assumptions,
  );
  checkNoPole(sInner, 'abs');
  final c0 = sInner.constantTerm;
  if (c0 is RealNumeric) {
    if (c0.sign > 0) return sInner;
    if (c0.sign < 0) return -sInner;
  }
  if (isPositiveExpr(c0, assumptions: assumptions)) return sInner;
  if (isNegativeExpr(c0, assumptions: assumptions)) return -sInner;
  if (!c0.dependsOn(variable) && c0.freeVariables.isEmpty) {
    try {
      final val = c0.evaluate();
      if (val > 0) return sInner;
      if (val < 0) return -sInner;
    } on UnsupportedError {
      // Fall through
    } on ArgumentError {
      // Fall through
    } on StateError {
      // Fall through
    }
  }
  throw UnsupportedError('abs is non-differentiable at zero');
}

RationalNumber _lambertWMaclaurinCoeff(int k) {
  final numBig = BigInt.from(k).pow(k - 1);
  final denBig = BigInt.from(k).factorial();
  final g = numBig.gcd(denBig);
  var numRed = numBig ~/ g;
  final denRed = denBig ~/ g;
  if ((k - 1).isOdd) {
    numRed = -numRed;
  }
  return RationalNumber.of(numRed, denRed);
}

PowerSeries expandLambertW(Expr inner, String variable, Expr point, int order) {
  final u = expandToPowerSeries(inner, variable, point, order);
  checkNoPole(u, 'lambertw');
  final c0 = u.constantTerm.simplify();
  if (c0 == (-Pow.of(Constant.e, IntegerNumber.negativeOne)).simplify()) {
    throw UnsupportedError('LambertW branch point at -1/e');
  }
  if (!PowerSeries.isZero(c0)) {
    return expandTaylorSeries(Fn.lambertW(inner), variable, point, order);
  }
  if (u.coefficients.isEmpty) {
    return PowerSeries(variable, point, const {}, order);
  }
  var res = PowerSeries(variable, point, const {}, order);
  var uPow = PowerSeries(variable, point, {0: IntegerNumber.one}, order);
  final val = u.valuation;
  for (var k = 1; k * val < order; k++) {
    uPow = uPow * u;
    final ck = _lambertWMaclaurinCoeff(k);
    res = res + uPow.scale(ck);
  }
  return res;
}

PowerSeries expandErf(Expr inner, String variable, Expr point, int order) {
  final u = expandToPowerSeries(inner, variable, point, order);
  checkNoPole(u, 'erf');
  final u0 = u.constantTerm;
  final uPrime = u.derivative();
  final expNegU2 = expandExpFromSeries(-(u * u));
  final factor = IntegerNumber.two / Pow.of(Constant.pi, FractionNumber.half);
  final deriv = (uPrime * expNegU2).scale(factor);
  final constant = Fn.erf(u0).simplify();
  return deriv.integrate(constant: constant);
}

PowerSeries expandErfi(Expr inner, String variable, Expr point, int order) {
  final u = expandToPowerSeries(inner, variable, point, order);
  checkNoPole(u, 'erfi');
  final u0 = u.constantTerm;
  final uPrime = u.derivative();
  final expU2 = expandExpFromSeries(u * u);
  final factor = IntegerNumber.two / Pow.of(Constant.pi, FractionNumber.half);
  final deriv = (uPrime * expU2).scale(factor);
  final constant = Fn.erfi(u0).simplify();
  return deriv.integrate(constant: constant);
}

PowerSeries expandFresnelS(Expr inner, String variable, Expr point, int order) {
  final u = expandToPowerSeries(inner, variable, point, order);
  checkNoPole(u, 'fresnelS');
  final u0 = u.constantTerm;
  final uPrime = u.derivative();
  final arg = (u * u).scale(Constant.pi * FractionNumber.half);
  final sinArg = expandSinCosFromSeries(arg).sin;
  final deriv = uPrime * sinArg;
  final constant = Fn.fresnelS(u0).simplify();
  return deriv.integrate(constant: constant);
}

PowerSeries expandFresnelC(Expr inner, String variable, Expr point, int order) {
  final u = expandToPowerSeries(inner, variable, point, order);
  checkNoPole(u, 'fresnelC');
  final u0 = u.constantTerm;
  final uPrime = u.derivative();
  final arg = (u * u).scale(Constant.pi * FractionNumber.half);
  final cosArg = expandSinCosFromSeries(arg).cos;
  final deriv = uPrime * cosArg;
  final constant = Fn.fresnelC(u0).simplify();
  return deriv.integrate(constant: constant);
}

PowerSeries expandSinIntegralSi(
  Expr inner,
  String variable,
  Expr point,
  int order,
) => expandHyperbolicOrTrigIntegral(
  inner,
  variable,
  point,
  order,
  name: 'Si',
  alternating: true,
  evaluateAt: (u0) => Fn.si(u0).simplify(),
  numeratorSeries: (u) => expandSinCosFromSeries(u).sin,
);

PowerSeries expandSinhIntegralShi(
  Expr inner,
  String variable,
  Expr point,
  int order,
) => expandHyperbolicOrTrigIntegral(
  inner,
  variable,
  point,
  order,
  name: 'Shi',
  alternating: false,
  evaluateAt: (u0) => Fn.shi(u0).simplify(),
  numeratorSeries: (u) => expandSinhCoshFromSeries(u).sinh,
);

PowerSeries expandHyperbolicOrTrigIntegral(
  Expr inner,
  String variable,
  Expr point,
  int order, {
  required String name,
  required bool alternating,
  required Expr Function(Expr) evaluateAt,
  required PowerSeries Function(PowerSeries) numeratorSeries,
}) {
  final u = expandToPowerSeries(inner, variable, point, order);
  checkNoPole(u, name);
  final u0 = u.constantTerm;
  if (!PowerSeries.isZero(u0)) {
    final uPrime = u.derivative();
    final deriv = uPrime * (numeratorSeries(u) / u);
    return deriv.integrate(constant: evaluateAt(u0));
  }
  if (u.coefficients.isEmpty) {
    return PowerSeries(variable, point, const {}, order);
  }
  final m = u.valuation;
  var result = PowerSeries(variable, point, const {}, order);
  var power = u;
  final uSquared = u * u;
  var fact = BigInt.one;
  for (var k = 0; (2 * k + 1) * m < order; k++) {
    final n = 2 * k + 1;
    if (k > 0) {
      fact *= BigInt.from(2 * k) * BigInt.from(n);
      power = power * uSquared;
    }
    final denom = IntegerNumber(BigInt.from(n) * fact);
    final coeff =
        (alternating && k.isOdd
                ? -IntegerNumber.one / denom
                : IntegerNumber.one / denom)
            .simplify();
    result = result + power.scale(coeff);
  }
  return result;
}

PowerSeries expandPolylog(
  Expr expr,
  Expr s,
  Expr inner,
  String variable,
  Expr point,
  int order,
) {
  if (!s.dependsOn(variable)) {
    final u = expandToPowerSeries(inner, variable, point, order);
    checkNoPole(u, 'polylog');
    if (PowerSeries.isZero(u.constantTerm)) {
      if (u.coefficients.isEmpty) {
        return PowerSeries(variable, point, const {}, order);
      }
      final m = u.valuation;
      var result = PowerSeries(variable, point, const {}, order);
      var power = u;
      for (var k = 1; k * m < order; k++) {
        if (k > 1) {
          power = power * u;
        }
        final coeff = Pow.of(IntegerNumber.of(k), -s).simplify();
        result = result + power.scale(coeff);
      }
      return result;
    }
  }
  return expandTaylorSeries(expr, variable, point, order);
}

PowerSeries expandEllipticK(
  Expr expr,
  Expr inner,
  String variable,
  Expr point,
  int order,
) => expandCompleteElliptic(
  expr,
  inner,
  variable,
  point,
  order,
  isSecondKind: false,
);

PowerSeries expandEllipticE(
  Expr expr,
  Expr inner,
  String variable,
  Expr point,
  int order,
) => expandCompleteElliptic(
  expr,
  inner,
  variable,
  point,
  order,
  isSecondKind: true,
);

PowerSeries expandCompleteElliptic(
  Expr expr,
  Expr inner,
  String variable,
  Expr point,
  int order, {
  required bool isSecondKind,
}) {
  final u = expandToPowerSeries(inner, variable, point, order);
  checkNoPole(u, isSecondKind ? 'ellipticE' : 'ellipticK');
  if (!PowerSeries.isZero(u.constantTerm)) {
    return expandTaylorSeries(expr, variable, point, order);
  }
  final piHalf = (Constant.pi * FractionNumber.half).simplify();
  var result = PowerSeries(variable, point, {0: piHalf}, order);
  if (u.coefficients.isEmpty) {
    return result;
  }
  final u2 = u * u;
  if (u2.coefficients.isEmpty) {
    return result;
  }
  final m2 = u2.valuation;
  var power = PowerSeries(variable, point, {0: IntegerNumber.one}, order);
  var sqCoeff = IntegerNumber.one as Expr;
  for (var n = 1; n * m2 < order; n++) {
    power = power * u2;
    final ratio = IntegerNumber.of(2 * n - 1) / IntegerNumber.of(2 * n);
    sqCoeff = (sqCoeff * ratio * ratio).simplify();
    final termCoeff = isSecondKind
        ? (piHalf * sqCoeff / IntegerNumber.of(1 - 2 * n)).simplify()
        : (piHalf * sqCoeff).simplify();
    result = result + power.scale(termCoeff);
  }
  return result;
}

PowerSeries expandAsinh(Expr inner, String variable, Expr point, int order) {
  final u = expandToPowerSeries(inner, variable, point, order);
  checkNoPole(u, 'asinh');
  final u0 = u.constantTerm;
  final uPrime = u.derivative();
  final onePlusU2 =
      PowerSeries(variable, point, {0: IntegerNumber.one}, order) + (u * u);
  final invSqrt = onePlusU2.pow(FractionNumber.negativeHalf);
  final deriv = uPrime * invSqrt;
  final constant = Fn.asinh(u0).simplify();
  return deriv.integrate(constant: constant);
}

PowerSeries expandAcosh(Expr inner, String variable, Expr point, int order) {
  final u = expandToPowerSeries(inner, variable, point, order);
  checkNoPole(u, 'acosh');
  final u0 = u.constantTerm;
  if (!u0.dependsOn(variable)) {
    if (u0.freeVariables.isEmpty) {
      final v = tryEvaluateReal(u0);
      if (v != null && v <= 1.0) {
        throw UnsupportedError(
          'Acosh series requires inner constant term > 1 (got $u0)',
        );
      }
    }
  }
  final uPrime = u.derivative();
  final u2MinusOne =
      (u * u) - PowerSeries(variable, point, {0: IntegerNumber.one}, order);
  if (PowerSeries.isZero(u2MinusOne.constantTerm)) {
    throw UnsupportedError('Branch point singularity');
  }
  final invSqrt = u2MinusOne.pow(FractionNumber.negativeHalf);
  final deriv = uPrime * invSqrt;
  final constant = Fn.acosh(u0).simplify();
  return deriv.integrate(constant: constant);
}

PowerSeries expandAtanh(Expr inner, String variable, Expr point, int order) {
  final u = expandToPowerSeries(inner, variable, point, order);
  checkNoPole(u, 'atanh');
  final u0 = u.constantTerm;
  final uPrime = u.derivative();
  final oneMinusU2 =
      PowerSeries(variable, point, {0: IntegerNumber.one}, order) - (u * u);
  if (PowerSeries.isZero(oneMinusU2.constantTerm)) {
    throw UnsupportedError('Branch point singularity');
  }
  final deriv = uPrime / oneMinusU2;
  final constant = Fn.atanh(u0).simplify();
  return deriv.integrate(constant: constant);
}

PowerSeries expandPiecewise(
  List<PiecewiseBranch> branches,
  Expr? otherwise,
  String variable,
  Expr point,
  int order,
) {
  if (!point.dependsOn(variable)) {
    final ptVal = tryEvaluateReal(point);
    if (ptVal != null) {
      final eps = math.max(1e-7, ptVal.abs() * 1e-7);
      for (final (:relation, :expr) in branches) {
        final atPt = trySymbolicOp(() => relation.evaluate({variable: ptVal}));
        final leftVal = trySymbolicOp(
          () => relation.evaluate({variable: ptVal - eps}),
        );
        final rightVal = trySymbolicOp(
          () => relation.evaluate({variable: ptVal + eps}),
        );
        if (atPt == null || leftVal == null || rightVal == null) {
          throw UnsupportedError(
            'Power series expansion not supported for Piecewise at $point',
          );
        }
        if (atPt != leftVal || atPt != rightVal) {
          throw UnsupportedError(
            'Piecewise expression is not analytic at boundary point $point',
          );
        }
        if (atPt == 1.0) {
          return expandToPowerSeries(expr, variable, point, order);
        }
      }
      if (otherwise != null) {
        return expandToPowerSeries(otherwise, variable, point, order);
      }
    }
  }
  throw UnsupportedError(
    'Power series expansion not supported for Piecewise at $point',
  );
}

PowerSeries expandSign(Expr inner, String variable, Expr point, int order) {
  final sInner = expandToPowerSeries(inner, variable, point, order);
  checkNoPole(sInner, 'sign');
  final c0 = sInner.constantTerm;
  if (PowerSeries.isZero(c0) ||
      (c0.freeVariables.isEmpty && tryEvaluateReal(c0) == 0.0)) {
    throw UnsupportedError('Sign is non-differentiable at zero');
  }
  return PowerSeries(variable, point, {0: Fn.sign(c0).simplify()}, order);
}

PowerSeries expandFloor(Expr inner, String variable, Expr point, int order) {
  final sInner = expandToPowerSeries(inner, variable, point, order);
  checkNoPole(sInner, 'floor');
  final c0 = sInner.constantTerm;
  final v = c0.freeVariables.isEmpty ? tryEvaluateReal(c0) : null;
  if (c0 is IntegerNumber || (v != null && v == v.floorToDouble())) {
    throw UnsupportedError('Floor is discontinuous at integers');
  }
  return PowerSeries(variable, point, {0: Fn.floor(c0).simplify()}, order);
}

PowerSeries expandCeil(Expr inner, String variable, Expr point, int order) {
  final sInner = expandToPowerSeries(inner, variable, point, order);
  checkNoPole(sInner, 'ceil');
  final c0 = sInner.constantTerm;
  final v = c0.freeVariables.isEmpty ? tryEvaluateReal(c0) : null;
  if (c0 is IntegerNumber || (v != null && v == v.ceilToDouble())) {
    throw UnsupportedError('Ceil is discontinuous at integers');
  }
  return PowerSeries(variable, point, {0: Fn.ceil(c0).simplify()}, order);
}

PowerSeries expandRound(Expr inner, String variable, Expr point, int order) {
  final sInner = expandToPowerSeries(inner, variable, point, order);
  checkNoPole(sInner, 'round');
  final c0 = sInner.constantTerm;
  final v = c0.freeVariables.isEmpty ? tryEvaluateReal(c0) : null;
  if (v != null && (v - 0.5) == (v - 0.5).floorToDouble()) {
    throw UnsupportedError('Round is discontinuous at half-integers');
  }
  return PowerSeries(variable, point, {0: Fn.round(c0).simplify()}, order);
}

PowerSeries expandTaylorSeries(
  Expr expr,
  String variable,
  Expr point,
  int order, {
  void Function(Expr atPoint)? checkSingularity,
}) {
  final coeffs = <int, Expr>{};
  var currentDeriv = expr;
  var currentFact = BigInt.one;

  for (var k = 0; k < order; k++) {
    if (k > 0) {
      currentFact *= BigInt.from(k);
    }
    final atPoint = currentDeriv.substitute(variable, point).simplify();
    if (k == 0 && checkSingularity != null) {
      checkSingularity(atPoint);
    }
    if (atPoint == Constant.undefined) {
      throw UnsupportedError('Function is non-analytic or undefined at $point');
    }
    if (!PowerSeries.isZero(atPoint)) {
      final coeff = (atPoint / IntegerNumber(currentFact)).simplify();
      if (!PowerSeries.isZero(coeff)) {
        coeffs[k] = coeff;
      }
    }
    if (k < order - 1) {
      currentDeriv = currentDeriv.derivative(variable).simplify();
    }
  }
  return PowerSeries(variable, point, coeffs, order);
}

void _checkNonPositiveIntPole(
  Expr inner,
  String variable,
  Expr point,
  String fnName,
) {
  final u0 = inner.substitute(variable, point).simplify();
  if (u0 is IntegerNumber && u0.value <= BigInt.zero) {
    throw UnsupportedError('$fnName has poles at non-positive integers ($u0)');
  }
  final val = u0.freeVariables.isEmpty ? tryEvaluateReal(u0) : null;
  if (val != null && val <= 0.0 && val == val.floorToDouble()) {
    throw UnsupportedError('$fnName has poles at non-positive integers ($val)');
  }
}

PowerSeries expandGamma(Expr inner, String variable, Expr point, int order) =>
    expandTaylorSeries(
      Fn.gamma(inner),
      variable,
      point,
      order,
      checkSingularity: (_) =>
          _checkNonPositiveIntPole(inner, variable, point, 'Gamma'),
    );

PowerSeries expandDigamma(Expr inner, String variable, Expr point, int order) =>
    expandTaylorSeries(
      Fn.digamma(inner),
      variable,
      point,
      order,
      checkSingularity: (_) =>
          _checkNonPositiveIntPole(inner, variable, point, 'Digamma'),
    );

PowerSeries expandPolygamma(
  Expr m,
  Expr inner,
  String variable,
  Expr point,
  int order,
) => expandTaylorSeries(
  Fn.polygamma(m, inner),
  variable,
  point,
  order,
  checkSingularity: (_) =>
      _checkNonPositiveIntPole(inner, variable, point, 'Polygamma'),
);

PowerSeries expandZeta(Expr inner, String variable, Expr point, int order) {
  void checkZetaPole(Expr atPoint) {
    final u0 = inner.substitute(variable, point).simplify();
    if (u0 == IntegerNumber.one ||
        (u0.freeVariables.isEmpty && tryEvaluateReal(u0) == 1.0)) {
      throw UnsupportedError('Zeta has a pole at 1');
    }
  }

  return expandTaylorSeries(
    Fn.zeta(inner),
    variable,
    point,
    order,
    checkSingularity: checkZetaPole,
  );
}

PowerSeries expandBessel(
  Expr nu,
  Expr inner,
  String variable,
  Expr point,
  int order, {
  required bool isModified,
}) {
  final fnName = isModified ? 'besselI' : 'besselJ';
  void checkBesselSingularity(Expr atPoint) {
    final u0 = inner.substitute(variable, point).simplify();
    final nuVal = nu.freeVariables.isEmpty ? tryEvaluateReal(nu) : null;
    final isNuInt =
        nu is IntegerNumber ||
        (nuVal != null && nuVal == nuVal.floorToDouble());
    if (PowerSeries.isZero(u0) && !isNuInt) {
      throw UnsupportedError(
        '$fnName has a branch point at zero for non-integer orders',
      );
    }
  }

  return expandTaylorSeries(
    isModified ? Fn.besselI(nu, inner) : Fn.besselJ(nu, inner),
    variable,
    point,
    order,
    checkSingularity: checkBesselSingularity,
  );
}

PowerSeries expandBeta(
  Expr left,
  Expr right,
  String variable,
  Expr point,
  int order,
) {
  void checkBetaPole(Expr atPoint) {
    for (final arg in [left, right]) {
      final vExpr = arg.substitute(variable, point).simplify();
      if (vExpr is IntegerNumber && (vExpr.isZero || vExpr.isNegative)) {
        throw UnsupportedError(
          'Beta has a pole at non-positive integer $vExpr',
        );
      }
    }
  }

  return expandTaylorSeries(
    Fn.beta(left, right),
    variable,
    point,
    order,
    checkSingularity: checkBetaPole,
  );
}

PowerSeries expandBinomial(
  Expr left,
  Expr right,
  String variable,
  Expr point,
  int order,
) {
  if (right case IntegerNumber(asInt: final k?) when k >= 0 && k <= 20) {
    if (k == 0) {
      return PowerSeries(variable, point, {0: IntegerNumber.one}, order);
    }
    var acc = expandToPowerSeries(left, variable, point, order);
    for (var j = 1; j < k; j++) {
      final factor = expandToPowerSeries(
        (left - IntegerNumber.of(j)).simplify(),
        variable,
        point,
        order,
      );
      acc = acc * factor;
    }
    final invFact = RationalNumber.of(BigInt.one, BigInt.from(k).factorial());
    return acc.scale(invFact);
  }
  final gammaExpr =
      (Fn.gamma(left + IntegerNumber.one) /
              (Fn.gamma(right + IntegerNumber.one) *
                  Fn.gamma(left - right + IntegerNumber.one)))
          .simplify();
  return expandTaylorSeries(gammaExpr, variable, point, order);
}
