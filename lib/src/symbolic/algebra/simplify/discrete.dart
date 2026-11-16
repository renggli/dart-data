import '../../assumptions.dart';
import '../../ast.dart';
import '../../calculus/differentiation.dart';
import '../../compiler.dart';
import '../../number/integer.dart';
import '../simplify.dart';
import '../structural_order.dart';
import 'additive.dart';
import 'domain.dart';
import 'transcendental.dart';

/// Simplifies a sine expression $\sin(expr)$.
Expr simplifyRelational(
  RelationalExpr expr, {
  Assumptions assumptions = Assumptions.none,
}) {
  final left = expr.left.simplify(assumptions: assumptions);
  final right = expr.right.simplify(assumptions: assumptions);
  final vL = realScalarValue(left);
  final vR = realScalarValue(right);
  if (vL != null && vR != null) {
    final matched = switch (expr) {
      LessThan() => vL < vR,
      LessEqual() => vL <= vR,
      GreaterThan() => vL > vR,
      GreaterEqual() => vL >= vR,
      Equal() => vL == vR,
      NotEqual() => vL != vR,
    };
    return matched ? IntegerNumber.one : IntegerNumber.zero;
  }
  return switch (expr) {
    LessThan() => LessThan(left, right, isSimplified: true),
    LessEqual() => LessEqual(left, right, isSimplified: true),
    GreaterThan() => GreaterThan(left, right, isSimplified: true),
    GreaterEqual() => GreaterEqual(left, right, isSimplified: true),
    Equal() => Equal(left, right, isSimplified: true),
    NotEqual() => NotEqual(left, right, isSimplified: true),
  };
}

/// Simplifies a piecewise expression.
Expr simplifyPiecewise(
  Piecewise expr, {
  Assumptions assumptions = Assumptions.none,
}) {
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
      return Piecewise(
        simplifiedBranches,
        otherwise: sExpr,
        isSimplified: true,
      );
    }
    final relCond = sCond is RelationalExpr ? sCond : relation;
    simplifiedBranches.add((relation: relCond, expr: sExpr));
  }
  final sOtherwise = expr.otherwise?.simplify(assumptions: assumptions);
  if (simplifiedBranches.isEmpty) {
    return sOtherwise ?? IntegerNumber.zero;
  }
  return Piecewise(
    simplifiedBranches,
    otherwise: sOtherwise,
    isSimplified: true,
  );
}

/// Simplifies a symbolic [Integral] node.
Expr simplifyIntegral(
  Expr integrand,
  String variable, {
  Expr? lower,
  Expr? upper,
  Assumptions assumptions = Assumptions.none,
}) {
  final sIntegrand = integrand.simplify(assumptions: assumptions);
  if (sIntegrand is Number && sIntegrand.isZero) {
    return IntegerNumber.zero;
  }
  final sLower = lower?.simplify(assumptions: assumptions);
  final sUpper = upper?.simplify(assumptions: assumptions);
  if (sLower != null && sUpper != null && sLower == sUpper) {
    return IntegerNumber.zero;
  }
  return Integral(
    sIntegrand,
    variable,
    lower: sLower,
    upper: sUpper,
    isSimplified: true,
  );
}

/// Simplifies a symbolic [Derivative] node.
Expr simplifyDerivative(
  Expr expr,
  String variable, {
  int order = 1,
  Expr? point,
  Assumptions assumptions = Assumptions.none,
}) {
  final sExpr = expr.simplify(assumptions: assumptions);
  final sPoint = point?.simplify(assumptions: assumptions);
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
    return Derivative(
      sExpr,
      variable,
      order: order,
      point: sPoint,
      isSimplified: true,
    );
  }
  if (sExpr
      case Derivative(
        expr: final inner,
        variable: final innerVar,
        order: final innerOrder,
        point: null,
      )
      when innerVar == variable) {
    return Derivative(
      inner,
      variable,
      order: innerOrder + order,
      isSimplified: true,
    );
  }
  return Derivative(sExpr, variable, order: order, isSimplified: true);
}

/// Simplifies a symbolic [Limit] node.
Expr simplifyLimit(
  Expr expr,
  String variable,
  Expr point, {
  LimitDirection direction = LimitDirection.both,
  Assumptions assumptions = Assumptions.none,
}) {
  final sExpr = expr.simplify(assumptions: assumptions);
  final sPoint = point.simplify(assumptions: assumptions);
  if (!sExpr.dependsOn(variable)) {
    return sExpr;
  }
  return Limit(
    sExpr,
    variable,
    sPoint,
    direction: direction,
    isSimplified: true,
  );
}

/// Simplifies a factorial expression $n!$.
Expr simplifyFloor(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (isIntegerExpr(expr, assumptions: assumptions)) return expr;
  switch (expr) {
    case FractionNumber(:final numerator, :final denominator):
      final q = numerator ~/ denominator;
      return IntegerNumber(
        numerator.isNegative && !(numerator % denominator).isZero
            ? q - Integer.one
            : q,
      );
    case RealNumber(:final value):
      return RealNumber.fromDouble(value.floorToDouble());
    default:
      if (expr.freeVariables.isEmpty) {
        try {
          final v = expr.evaluate();
          if (v.isFinite) {
            if (expr.anyNode((n) => n is RealNumber)) {
              return RealNumber.fromDouble(v.floorToDouble());
            }
            if ((v - v.roundToDouble()).abs() > 1e-12) {
              return IntegerNumber(Integer.from(v.floor()));
            }
          }
        } on Object {
          // Keep symbolic
        }
      }
      return Floor(expr, isSimplified: true);
  }
}

/// Simplifies a ceiling expression $\lceil x \rceil$.
Expr simplifyCeil(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (isIntegerExpr(expr, assumptions: assumptions)) return expr;
  switch (expr) {
    case FractionNumber(:final numerator, :final denominator):
      final q = numerator ~/ denominator;
      return IntegerNumber(
        !numerator.isNegative && !(numerator % denominator).isZero
            ? q + Integer.one
            : q,
      );
    case RealNumber(:final value):
      return RealNumber.fromDouble(value.ceilToDouble());
    default:
      if (expr.freeVariables.isEmpty) {
        try {
          final v = expr.evaluate();
          if (v.isFinite) {
            if (expr.anyNode((n) => n is RealNumber)) {
              return RealNumber.fromDouble(v.ceilToDouble());
            }
            if ((v - v.roundToDouble()).abs() > 1e-12) {
              return IntegerNumber(Integer.from(v.ceil()));
            }
          }
        } on Object {
          // Keep symbolic
        }
      }
      return Ceil(expr, isSimplified: true);
  }
}

/// Simplifies a rounding expression $\operatorname{round}(x)$.
Expr simplifyRound(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (isIntegerExpr(expr, assumptions: assumptions)) return expr;
  switch (expr) {
    case FractionNumber(:final numerator, :final denominator):
      final absNum = numerator.abs();
      final q2 = denominator * Integer.two;
      final rounded = (absNum * Integer.two + denominator) ~/ q2;
      return IntegerNumber(numerator.isNegative ? -rounded : rounded);
    case RealNumber(:final value):
      return RealNumber.fromDouble(value.roundToDouble());
    default:
      if (expr.freeVariables.isEmpty) {
        try {
          final v = expr.evaluate();
          if (v.isFinite) {
            if (expr.anyNode((n) => n is RealNumber)) {
              return RealNumber.fromDouble(v.roundToDouble());
            }
            if (((v - v.floorToDouble()).abs() - 0.5).abs() > 1e-12) {
              return IntegerNumber(Integer.from(v.round()));
            }
          }
        } on Object {
          // Keep symbolic
        }
      }
      return Round(expr, isSimplified: true);
  }
}

/// Simplifies a signum expression $\operatorname{sgn}(x)$.
Expr simplifySign(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    if (expr.value.isNaN) return Constant.undefined;
    return RealNumber.fromDouble(expr.sign.toDouble());
  }
  if (expr is RationalNumber) {
    return IntegerNumber.of(expr.sign);
  }
  if (expr case Variable(:final name)
      when assumptions.domainOf(name) == VariableDomain.positive) {
    return IntegerNumber.one;
  }
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(simplifySign(posExpr, assumptions: assumptions));
  }
  if (expr.freeVariables.isEmpty && isProvenReal(expr, assumptions)) {
    try {
      final v = expr.evaluate();
      if (v.isFinite) {
        final s = v == 0.0 ? 0 : (v > 0.0 ? 1 : -1);
        return expr.anyNode((n) => n is RealNumber)
            ? RealNumber.fromDouble(s.toDouble())
            : IntegerNumber.of(s);
      }
    } on Object {
      // Keep symbolic
    }
  }
  return Sign(expr, isSimplified: true);
}

/// Simplifies a modulo expression $a \bmod b$.
Expr simplifyMod(
  Expr left,
  Expr right, {
  Assumptions assumptions = Assumptions.none,
}) {
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
  return Mod(left, right, isSimplified: true);
}

/// Simplifies a real-part expression $\Re(z)$.
