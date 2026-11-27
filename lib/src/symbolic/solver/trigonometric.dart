import 'dart:math' as math;

import '../algebra/exact_constants.dart';
import '../algebra/simplify.dart';
import '../assumptions.dart';
import '../ast.dart';
import '../functions/fn.dart';
import '../type/expr_data_type.dart';
import 'transcendental.dart';
import 'univariate.dart';

/// Inverts trigonometric sine `sin(arg) = c` for special and general angles.
List<Expr> invertSin(
  Expr arg,
  Expr c,
  String variable, {
  required Assumptions assumptions,
}) {
  if (isRealConstantOutOfRange(c, 1.0)) {
    return const [];
  }

  final angles = switch (c) {
    RealNumber() => () {
      final asinC = math.asin(c.value.clamp(-1.0, 1.0));
      final a1 = asinC >= 0 ? asinC : asinC + 2 * math.pi;
      final a2 = (math.pi - asinC) % (2 * math.pi);
      return [
        RealNumber(a1),
        if ((a1 - a2).abs() > 1e-12)
          RealNumber(a2 >= 0 ? a2 : a2 + 2 * math.pi),
      ];
    }(),
    RationalNumber(isZero: true) => [IntegerNumber.zero, Constant.pi],
    RationalNumber(isOne: true) => [_piFraction(1, 2)],
    RationalNumber(isNegativeOne: true) => [_piFraction(3, 2)],
    _ when isHalf(c) => [_piFraction(1, 6), _piFraction(5, 6)],
    _ when isNegativeHalf(c) => [_piFraction(7, 6), _piFraction(11, 6)],
    _ when isSqrt2Over2(c) => [_piFraction(1, 4), _piFraction(3, 4)],
    _ when isNegativeSqrt2Over2(c) => [_piFraction(5, 4), _piFraction(7, 4)],
    _ when isSqrt3Over2(c) => [_piFraction(1, 3), _piFraction(2, 3)],
    _ when isNegativeSqrt3Over2(c) => [_piFraction(4, 3), _piFraction(5, 3)],
    _ => [
      Fn.asin(c).simplify(assumptions: assumptions),
      (Constant.pi - Fn.asin(c)).simplify(assumptions: assumptions),
    ],
  };

  return _invertAngles(arg, angles, variable, assumptions: assumptions);
}

/// Inverts trigonometric cosine `cos(arg) = c` for special and general angles.
List<Expr> invertCos(
  Expr arg,
  Expr c,
  String variable, {
  required Assumptions assumptions,
}) {
  if (isRealConstantOutOfRange(c, 1.0)) {
    return const [];
  }

  final angles = switch (c) {
    RealNumber() => () {
      final acosC = math.acos(c.value.clamp(-1.0, 1.0));
      final a2 = (2 * math.pi - acosC) % (2 * math.pi);
      return [
        RealNumber(acosC),
        if ((acosC - a2).abs() > 1e-12)
          RealNumber(a2 >= 0 ? a2 : a2 + 2 * math.pi),
      ];
    }(),
    RationalNumber(isZero: true) => [_piFraction(1, 2), _piFraction(3, 2)],
    RationalNumber(isOne: true) => [IntegerNumber.zero],
    RationalNumber(isNegativeOne: true) => [Constant.pi],
    _ when isHalf(c) => [_piFraction(1, 3), _piFraction(5, 3)],
    _ when isNegativeHalf(c) => [_piFraction(2, 3), _piFraction(4, 3)],
    _ when isSqrt2Over2(c) => [_piFraction(1, 4), _piFraction(7, 4)],
    _ when isNegativeSqrt2Over2(c) => [_piFraction(3, 4), _piFraction(5, 4)],
    _ when isSqrt3Over2(c) => [_piFraction(1, 6), _piFraction(11, 6)],
    _ when isNegativeSqrt3Over2(c) => [_piFraction(5, 6), _piFraction(7, 6)],
    _ => [
      Fn.acos(c).simplify(assumptions: assumptions),
      ((IntegerNumber.two * Constant.pi) - Fn.acos(c)).simplify(
        assumptions: assumptions,
      ),
    ],
  };

  return _invertAngles(arg, angles, variable, assumptions: assumptions);
}

/// Inverts trigonometric tangent `tan(arg) = c` for special and general angles.
List<Expr> invertTan(
  Expr arg,
  Expr c,
  String variable, {
  required Assumptions assumptions,
}) {
  final angles = switch (c) {
    RealNumber() => () {
      final atanC = math.atan(c.value);
      final a1 = atanC >= 0 ? atanC : atanC + math.pi;
      final a2 = (a1 + math.pi) % (2 * math.pi);
      return [
        RealNumber(a1),
        if ((a1 - a2).abs() > 1e-12)
          RealNumber(a2 >= 0 ? a2 : a2 + 2 * math.pi),
      ];
    }(),
    RationalNumber(isZero: true) => [IntegerNumber.zero, Constant.pi],
    RationalNumber(isOne: true) => [_piFraction(1, 4), _piFraction(5, 4)],
    RationalNumber(isNegativeOne: true) => [
      _piFraction(3, 4),
      _piFraction(7, 4),
    ],
    _ when isSqrt3Over3(c) => [_piFraction(1, 6), _piFraction(7, 6)],
    _ when isNegativeSqrt3Over3(c) => [_piFraction(5, 6), _piFraction(11, 6)],
    _ when isSqrt3(c) => [_piFraction(1, 3), _piFraction(4, 3)],
    _ when isNegativeSqrt3(c) => [_piFraction(2, 3), _piFraction(5, 3)],
    _ => [
      Fn.atan(c).simplify(assumptions: assumptions),
      (Constant.pi + Fn.atan(c)).simplify(assumptions: assumptions),
    ],
  };

  return _invertAngles(arg, angles, variable, assumptions: assumptions);
}

/// Solves homogeneous or constant-shifted quadratic trigonometric equations
/// `a * sin^2(u) + b * sin(u) * cos(u) + c * cos^2(u) + d = 0`.
List<Expr>? solveQuadraticTrig(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
}) {
  final terms = expr is Add ? expr.terms : [expr];
  Expr? u;
  var a = IntegerNumber.zero as Expr;
  var b = IntegerNumber.zero as Expr;
  var c = IntegerNumber.zero as Expr;
  var d = IntegerNumber.zero as Expr;

  bool matchArg(Expr arg) {
    if (!arg.dependsOn(variable)) return false;
    u ??= arg;
    return u == arg;
  }

  for (final term in terms) {
    if (!term.dependsOn(variable)) {
      d = (d + term).simplify(assumptions: assumptions);
      continue;
    }

    final factors = term is Mul ? term.factors : [term];
    final constFactors = <Expr>[];
    var sinPow = 0;
    var cosPow = 0;

    for (final factor in factors) {
      if (!factor.dependsOn(variable)) {
        constFactors.add(factor);
        continue;
      }
      if (factor case Call(id: FunctionId.sin, args: [final inner])
          when matchArg(inner)) {
        sinPow += 1;
      } else if (factor case Call(id: FunctionId.cos, args: [final inner])
          when matchArg(inner)) {
        cosPow += 1;
      } else if (factor
          case Pow(
            base: Call(id: FunctionId.sin, args: [final inner]),
            exponent: IntegerNumber(asInt: 2),
          )
          when matchArg(inner)) {
        sinPow += 2;
      } else if (factor
          case Pow(
            base: Call(id: FunctionId.cos, args: [final inner]),
            exponent: IntegerNumber(asInt: 2),
          )
          when matchArg(inner)) {
        cosPow += 2;
      } else {
        return null;
      }
    }

    if (sinPow + cosPow != 2) return null;
    final coeff = switch (constFactors) {
      [] => IntegerNumber.one,
      [final single] => single,
      _ => Mul.of(constFactors).simplify(assumptions: assumptions),
    };
    if (sinPow == 2) {
      a = (a + coeff).simplify(assumptions: assumptions);
    } else if (cosPow == 2) {
      c = (c + coeff).simplify(assumptions: assumptions);
    } else {
      b = (b + coeff).simplify(assumptions: assumptions);
    }
  }

  final arg = u;
  if (arg == null) return null;

  final bigA = (a + d).simplify(assumptions: assumptions);
  final bigB = b.simplify(assumptions: assumptions);
  final bigC = (c + d).simplify(assumptions: assumptions);

  if (isZeroExpr(bigA) && isZeroExpr(bigB) && isZeroExpr(bigC)) {
    return null;
  }

  final roots = <Expr>[];
  if (isZeroExpr(bigA)) {
    roots.addAll(
      invertCos(arg, IntegerNumber.zero, variable, assumptions: assumptions),
    );
    if (!isZeroExpr(bigB)) {
      roots.addAll(
        invertTan(
          arg,
          (-bigC / bigB).simplify(assumptions: assumptions),
          variable,
          assumptions: assumptions,
        ),
      );
    }
  } else {
    var tName = '__tan_t';
    while (tName == variable ||
        arg.dependsOn(tName) ||
        bigA.dependsOn(tName) ||
        bigB.dependsOn(tName) ||
        bigC.dependsOn(tName)) {
      tName = '_$tName';
    }
    final tVar = Variable(tName);
    final quad = (bigA * Pow.of(tVar, IntegerNumber.two) + bigB * tVar + bigC)
        .simplify(assumptions: assumptions);
    final tRoots = solveEquation(quad, tName, assumptions: assumptions);
    for (final tRoot in tRoots) {
      roots.addAll(invertTan(arg, tRoot, variable, assumptions: assumptions));
    }
  }
  return deduplicateRoots(roots, assumptions: assumptions);
}

Expr _piFraction(int num, int den) =>
    (RationalNumber(num, den) * Constant.pi).simplify();

List<Expr> _invertAngles(
  Expr arg,
  List<Expr> angles,
  String variable, {
  required Assumptions assumptions,
}) => deduplicateRoots([
  for (final angle in angles)
    ...(invertEquation(arg, angle, variable, assumptions: assumptions) ??
        solveEquation(
          (arg - angle).simplify(assumptions: assumptions),
          variable,
          assumptions: assumptions,
        )),
], assumptions: assumptions);
