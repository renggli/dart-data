import 'dart:math' as math;

import 'ast.dart';

/// Canonical algebraic simplifier performing constant folding and identity reductions.
class Simplifier {
  const new _();

  static Expr add(Expr left, Expr right) {
    if (left is Constant && right is Constant) {
      return Constant(left.value + right.value);
    }
    if (left is Constant && left.value == 0.0) return right;
    if (right is Constant && right.value == 0.0) return left;
    return Add(left, right);
  }

  static Expr sub(Expr left, Expr right) {
    if (left is Constant && right is Constant) {
      return Constant(left.value - right.value);
    }
    if (right is Constant && right.value == 0.0) return left;
    if (left == right) return const Constant(0.0);
    return Sub(left, right);
  }

  static Expr mul(Expr left, Expr right) {
    if (left is Constant && right is Constant) {
      return Constant(left.value * right.value);
    }
    if ((left is Constant && left.value == 0.0) ||
        (right is Constant && right.value == 0.0)) {
      return const Constant(0.0);
    }
    if (left is Constant && left.value == 1.0) return right;
    if (right is Constant && right.value == 1.0) return left;
    if (left is Constant && left.value == -1.0) return Neg(right);
    if (right is Constant && right.value == -1.0) return Neg(left);
    return Mul(left, right);
  }

  static Expr div(Expr left, Expr right) {
    if (left is Constant && right is Constant) {
      if (right.value == 0.0) {
        throw UnsupportedError('Division by zero in simplification');
      }
      return Constant(left.value / right.value);
    }
    if (left is Constant && left.value == 0.0) return const Constant(0.0);
    if (right is Constant && right.value == 1.0) return left;
    if (left == right) return const Constant(1.0);
    return Div(left, right);
  }

  static Expr pow(Expr base, Expr exponent) {
    if (base is Constant && exponent is Constant) {
      return Constant(math.pow(base.value, exponent.value).toDouble());
    }
    if (exponent is Constant && exponent.value == 0.0) {
      return const Constant(1.0);
    }
    if (exponent is Constant && exponent.value == 1.0) return base;
    if (base is Constant && base.value == 0.0) return const Constant(0.0);
    if (base is Constant && base.value == 1.0) return const Constant(1.0);
    return Pow(base, exponent);
  }

  static Expr neg(Expr expr) {
    if (expr is Constant) return Constant(-expr.value);
    if (expr is Neg) return expr.expr;
    return Neg(expr);
  }

  static Expr sin(Expr expr) {
    if (expr is Constant) return Constant(math.sin(expr.value));
    return Sin(expr);
  }

  static Expr cos(Expr expr) {
    if (expr is Constant) return Constant(math.cos(expr.value));
    return Cos(expr);
  }

  static Expr exp(Expr expr) {
    if (expr is Constant) return Constant(math.exp(expr.value));
    return Exp(expr);
  }

  static Expr ln(Expr expr) {
    if (expr is Constant) {
      if (expr.value <= 0.0) {
        throw ArgumentError(
          'Natural logarithm domain error: ${expr.value} <= 0',
        );
      }
      return Constant(math.log(expr.value));
    }
    return Ln(expr);
  }
}
