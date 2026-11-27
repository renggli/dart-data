import '../../assumptions.dart';
import '../../ast.dart';
import '../../calculus/differentiation.dart';
import '../../compiler.dart';
import '../../functions/fn.dart';
import '../../oracle/domain_oracle.dart' show Sign;
import '../../oracle/sign.dart';
import '../simplify.dart';
import 'additive.dart';
import 'transcendental.dart';

/// Simplifies a relational expression.
Expr simplifyRelational(Relational expr, {required Assumptions assumptions}) {
  final left = expr.left.simplify(assumptions: assumptions);
  final right = expr.right.simplify(assumptions: assumptions);
  if (left is RealNumeric && right is RealNumeric) {
    final cmp = left.compareTo(right);
    final matched = switch (expr.op) {
      RelOp.lessThan => cmp < 0,
      RelOp.lessEqual => cmp <= 0,
      RelOp.greaterThan => cmp > 0,
      RelOp.greaterEqual => cmp >= 0,
      RelOp.equal => cmp == 0,
      RelOp.notEqual => cmp != 0,
    };
    return matched ? IntegerNumber.one : IntegerNumber.zero;
  }
  final vL = realScalarValue(left);
  final vR = realScalarValue(right);
  if (vL != null && vR != null) {
    final matched = switch (expr.op) {
      RelOp.lessThan => vL < vR,
      RelOp.lessEqual => vL <= vR,
      RelOp.greaterThan => vL > vR,
      RelOp.greaterEqual => vL >= vR,
      RelOp.equal => vL == vR,
      RelOp.notEqual => vL != vR,
    };
    return matched ? IntegerNumber.one : IntegerNumber.zero;
  }
  if (left != Constant.undefined &&
      right != Constant.undefined &&
      isProvenReal(left, assumptions) &&
      isProvenReal(right, assumptions)) {
    final diffSign = inferSign(left - right, assumptions: assumptions);
    final decided = switch ((expr.op, diffSign)) {
      (RelOp.lessThan, Sign.negative) => true,
      (RelOp.lessThan, Sign.zero || Sign.positive || Sign.nonNegative) => false,
      (RelOp.lessEqual, Sign.negative || Sign.zero || Sign.nonPositive) => true,
      (RelOp.lessEqual, Sign.positive) => false,
      (RelOp.greaterThan, Sign.positive) => true,
      (RelOp.greaterThan, Sign.zero || Sign.negative || Sign.nonPositive) =>
        false,
      (RelOp.greaterEqual, Sign.positive || Sign.zero || Sign.nonNegative) =>
        true,
      (RelOp.greaterEqual, Sign.negative) => false,
      (RelOp.equal, Sign.zero) => true,
      (RelOp.equal, Sign.negative || Sign.positive || Sign.nonZero) => false,
      (RelOp.notEqual, Sign.negative || Sign.positive || Sign.nonZero) => true,
      (RelOp.notEqual, Sign.zero) => false,
      _ => null,
    };
    if (decided != null) {
      return decided ? IntegerNumber.one : IntegerNumber.zero;
    }
  }
  return Relational(expr.op, left, right);
}

/// Simplifies a piecewise expression.
Expr simplifyPiecewise(Piecewise expr, {required Assumptions assumptions}) {
  final simplifiedBranches = <PiecewiseBranch>[];
  for (final (:relation, expr: branchExpr) in expr.branches) {
    final sCond = relation.simplify(assumptions: assumptions);
    if (sCond is Number && sCond.isZero) {
      continue;
    }
    final sExpr = branchExpr.simplify(assumptions: assumptions);
    if (sCond is Number && sCond.isOne) {
      if (simplifiedBranches.isEmpty) {
        return sExpr;
      }
      return Piecewise(simplifiedBranches, otherwise: sExpr);
    }
    final relCond = sCond is Relational ? sCond : relation;
    simplifiedBranches.add((relation: relCond, expr: sExpr));
  }
  final sOtherwise = expr.otherwise?.simplify(assumptions: assumptions);
  if (simplifiedBranches.isEmpty) {
    return sOtherwise ?? IntegerNumber.zero;
  }
  return Piecewise(simplifiedBranches, otherwise: sOtherwise);
}

/// Simplifies a symbolic [Integral] node.
Expr simplifyIntegral(
  Expr integrand,
  String variable, {
  Expr? lower,
  Expr? upper,
  required Assumptions assumptions,
}) {
  final sIntegrand = integrand.simplify(assumptions: assumptions);
  if (sIntegrand == Constant.undefined) {
    return Constant.undefined;
  }
  if (sIntegrand is Number && sIntegrand.isZero) {
    return IntegerNumber.zero;
  }
  final sLower = lower?.simplify(assumptions: assumptions);
  final sUpper = upper?.simplify(assumptions: assumptions);
  if (sLower == Constant.undefined || sUpper == Constant.undefined) {
    return Constant.undefined;
  }
  if (sLower != null && sUpper != null && sLower == sUpper) {
    return IntegerNumber.zero;
  }
  return Integral(sIntegrand, variable, lower: sLower, upper: sUpper);
}

/// Simplifies a symbolic [Derivative] node.
Expr simplifyDerivative(
  Expr expr,
  String variable, {
  int order = 1,
  Expr? point,
  required Assumptions assumptions,
}) {
  final sExpr = expr.simplify(assumptions: assumptions);
  final sPoint = point?.simplify(assumptions: assumptions);
  if (sExpr == Constant.undefined || sPoint == Constant.undefined) {
    return Constant.undefined;
  }
  if (!sExpr.dependsOn(variable)) {
    return IntegerNumber.zero;
  }
  if (sPoint != null) {
    final derived = sExpr.derivative(
      variable,
      order: order,
      assumptions: assumptions,
    );
    if (!derived.anyNode(
      (node) =>
          node is Derivative && node.variable == variable && node.point == null,
    )) {
      return derived
          .substitute(variable, sPoint)
          .simplify(assumptions: assumptions);
    }
    return Derivative(sExpr, variable, order: order, point: sPoint);
  }
  if (sExpr
      case Derivative(
        expr: final inner,
        variable: final innerVar,
        order: final innerOrder,
        point: null,
      )
      when innerVar == variable) {
    return Derivative(inner, variable, order: innerOrder + order);
  }
  return Derivative(sExpr, variable, order: order);
}

/// Simplifies a symbolic [Limit] node.
Expr simplifyLimit(
  Expr expr,
  String variable,
  Expr point, {
  LimitDirection direction = LimitDirection.both,
  required Assumptions assumptions,
}) {
  final sExpr = expr.simplify(assumptions: assumptions);
  final sPoint = point.simplify(assumptions: assumptions);
  if (!sExpr.dependsOn(variable)) {
    return sExpr;
  }
  return Limit(sExpr, variable, sPoint, direction: direction);
}

/// Simplifies a floor expression `floor(x)`.
Expr simplifyFloor(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (isIntegerExpr(expr, assumptions: assumptions)) return expr;
  switch (expr) {
    case FractionNumber(:final numerator, :final denominator):
      final q = numerator ~/ denominator;
      return IntegerNumber(
        numerator.isNegative && numerator % denominator != BigInt.zero
            ? q - BigInt.one
            : q,
      );
    case RealNumber(:final value):
      return RealNumber.fromDouble(value.floorToDouble());
    default:
      if (expr.freeVariables.isEmpty && isProvenReal(expr, assumptions)) {
        try {
          final v = expr.evaluate();
          if (v.isFinite) {
            if (expr.anyNode((n) => n is RealNumber)) {
              return RealNumber.fromDouble(v.floorToDouble());
            }
            if ((v - v.roundToDouble()).abs() > 1e-12 &&
                v.abs() < 4503599627370496.0) {
              return IntegerNumber.of(v.floor());
            }
          }
        } on ArgumentError {
          // Keep symbolic
        } on UnsupportedError {
          // Keep symbolic
        }
      }
      return Fn.floor(expr);
  }
}

/// Simplifies a ceiling expression `ceil(x)`.
Expr simplifyCeil(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (isIntegerExpr(expr, assumptions: assumptions)) return expr;
  switch (expr) {
    case FractionNumber(:final numerator, :final denominator):
      final q = numerator ~/ denominator;
      return IntegerNumber(
        !numerator.isNegative && numerator % denominator != BigInt.zero
            ? q + BigInt.one
            : q,
      );
    case RealNumber(:final value):
      return RealNumber.fromDouble(value.ceilToDouble());
    default:
      if (expr.freeVariables.isEmpty && isProvenReal(expr, assumptions)) {
        try {
          final v = expr.evaluate();
          if (v.isFinite) {
            if (expr.anyNode((n) => n is RealNumber)) {
              return RealNumber.fromDouble(v.ceilToDouble());
            }
            if ((v - v.roundToDouble()).abs() > 1e-12 &&
                v.abs() < 4503599627370496.0) {
              return IntegerNumber.of(v.ceil());
            }
          }
        } on ArgumentError {
          // Keep symbolic
        } on UnsupportedError {
          // Keep symbolic
        }
      }
      return Fn.ceil(expr);
  }
}

/// Simplifies a rounding expression `round(x)`.
Expr simplifyRound(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (isIntegerExpr(expr, assumptions: assumptions)) return expr;
  switch (expr) {
    case FractionNumber(:final numerator, :final denominator):
      final absNum = numerator.abs();
      final q2 = denominator * BigInt.two;
      final rounded = (absNum * BigInt.two + denominator) ~/ q2;
      return IntegerNumber(numerator.isNegative ? -rounded : rounded);
    case RealNumber(:final value):
      return RealNumber.fromDouble(value.roundToDouble());
    default:
      if (expr.freeVariables.isEmpty && isProvenReal(expr, assumptions)) {
        try {
          final v = expr.evaluate();
          if (v.isFinite) {
            if (expr.anyNode((n) => n is RealNumber)) {
              return RealNumber.fromDouble(v.roundToDouble());
            }
            if (((v - v.floorToDouble()).abs() - 0.5).abs() > 1e-12 &&
                v.abs() < 4503599627370496.0) {
              return IntegerNumber.of(v.round());
            }
          }
        } on ArgumentError {
          // Keep symbolic
        } on UnsupportedError {
          // Keep symbolic
        }
      }
      return Fn.round(expr);
  }
}

/// Simplifies a signum expression `sign(x)`.
Expr simplifySign(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    if (expr.value.isNaN) return Constant.undefined;
    return RealNumber.fromDouble(expr.sign.toDouble());
  }
  if (expr is RationalNumber) {
    return IntegerNumber.of(expr.sign);
  }
  if (isPositive(expr, assumptions: assumptions)) {
    return expr.hasReal ? const RealNumber(1.0) : IntegerNumber.one;
  }
  if (isNegative(expr, assumptions: assumptions)) {
    return expr.hasReal ? const RealNumber(-1.0) : IntegerNumber.negativeOne;
  }
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(
      simplifySign(posExpr, assumptions: assumptions),
      assumptions: assumptions,
    );
  }
  if (expr.freeVariables.isEmpty && isProvenReal(expr, assumptions)) {
    try {
      final v = expr.evaluate();
      if (v.isFinite) {
        final hasReal = expr.anyNode((n) => n is RealNumber);
        if (!hasReal && v.abs() <= 1e-12) {
          return Fn.sign(expr);
        }
        final s = v == 0.0 ? 0 : (v > 0.0 ? 1 : -1);
        return hasReal
            ? RealNumber.fromDouble(s.toDouble())
            : IntegerNumber.of(s);
      }
    } on ArgumentError {
      // Keep symbolic
    } on UnsupportedError {
      // Keep symbolic
    }
  }
  return Fn.sign(expr);
}

/// Simplifies a modulo expression `mod(a, b)`.
Expr simplifyMod(Expr left, Expr right, {required Assumptions assumptions}) {
  if (left == Constant.undefined || right == Constant.undefined) {
    return Constant.undefined;
  }
  if (right is Number && right.isZero) {
    return Constant.undefined;
  }
  if (left is Number && left.isZero) {
    return left is RealNumber || right is RealNumber
        ? const RealNumber(0.0)
        : IntegerNumber.zero;
  }
  if (right is Number &&
      right.isOne &&
      isIntegerExpr(left, assumptions: assumptions)) {
    return right is RealNumber ? const RealNumber(0.0) : IntegerNumber.zero;
  }
  if (left is RationalNumber && right is RationalNumber) {
    final q = simplifyFloor(
      left.divRational(right),
      assumptions: assumptions,
    ) as IntegerNumber;
    return left.subRational(right.mulRational(q));
  }
  if (left is RealNumeric && right is RealNumeric) {
    final a = left.toDouble();
    final b = right.toDouble();
    return RealNumber.fromDouble(a - b * (a / b).floorToDouble());
  }
  return Fn.mod(left, right);
}
