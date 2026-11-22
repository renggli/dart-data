import 'dart:math' as math;

import 'package:more/number.dart' show Complex, Fraction;

import '../assumptions.dart';
import '../ast.dart';
import '../compiler.dart';
import '../compiler/evaluator.dart';
import 'simplify.dart';
import 'simplify/multiplicative.dart';
import 'term_accumulator.dart';

/// Numeric approximation and rationalization operations on [Expr].
extension ApproximationExtension on Expr {
  /// Recursively converts all exact numbers ([IntegerNumber], [FractionNumber])
  /// and mathematical [Constant]s (`pi`, `e`) into floating-point [RealNumber]
  /// (or floating-point [ComplexNumber]) values and folds all constant
  /// subtrees, while preserving free [Variable]s symbolically.
  ///
  /// Optional [bindings] are substituted before approximation.
  ///
  /// ```dart
  /// (Constant.pi / 4 + const Variable('x')).approximate();
  /// // 0.7853981633974483 + x
  /// ```
  Expr approximate([Map<String, Expr> bindings = const {}]) {
    var target = this;
    for (final MapEntry(:key, :value) in bindings.entries) {
      target = target.substitute(key, value);
    }
    return _approximateNode(target).simplify();
  }

  /// Replaces floating-point [RealNumber] leaves with their best rational
  /// approximations ([IntegerNumber] or [FractionNumber]) via continued
  /// fractions bounded by [maxDenominator] and [tolerance].
  ///
  /// ```dart
  /// RealNumber(0.3333333333333333).rationalize(); // 1 / 3
  /// ```
  Expr rationalize({int maxDenominator = 1000000, double tolerance = 1e-12}) =>
      _rationalizeNode(this, maxDenominator, tolerance).simplify();
}

Expr _approximateNode(Expr node) => switch (node) {
  RationalNumber() => RealNumber.fromDouble(node.toDouble()),
  RealNumber() => node,
  ComplexNumber(:final real, :final imaginary) => ComplexNumber.of(
    RealNumber(real.toDouble()),
    RealNumber(imaginary.toDouble()),
  ),
  Constant() => _approximateConstant(node),
  Variable() || OrderTerm() => node,
  Add(:final terms) => Add(terms.map(_approximateNode).toList()).simplify(),
  Mul() => _approximateMul(node),
  Pow(:final base, :final exponent) => _approximatePow(
    _approximateNode(base),
    _approximateNode(exponent),
  ),
  UnaryExpr(:final expr) => _approximateUnary(node, _approximateNode(expr)),
  RelationalExpr() ||
  Piecewise() ||
  Derivative() ||
  Limit() ||
  Sum() ||
  Product() ||
  VariableFunction() => node.mapChildren(_approximateNode),
  Integral() => () {
    final rebuilt = node.mapChildren(_approximateNode) as Integral;
    if (rebuilt.isDefinite && rebuilt.freeVariables.isEmpty) {
      final val = rebuilt.evaluate();
      if (!val.isNaN) return RealNumber.fromDouble(val);
    }
    return rebuilt.simplify();
  }(),
  BinaryExpr() => _approximateBinary(node),
  EllipticPi() => () {
    final rebuilt = node.mapChildren(_approximateNode) as EllipticPi;
    if (rebuilt.freeVariables.isEmpty) {
      if (rebuilt.characteristic is ComplexNumber ||
          rebuilt.amplitude is ComplexNumber ||
          rebuilt.modulus is ComplexNumber) {
        return _complexToExpr(rebuilt.evaluateComplex());
      }
      final realVal = rebuilt.evaluate();
      if (!realVal.isNaN) return RealNumber.fromDouble(realVal);
      return _complexToExpr(rebuilt.evaluateComplex());
    }
    return rebuilt.simplify();
  }(),
};

Expr _approximateMul(Mul node) {
  final simplified = node.isSimplified ? node : node.simplify();
  if (simplified != Constant.undefined && simplified is! Mul) {
    return _approximateNode(simplified);
  }
  final sourceFactors = simplified is Mul ? simplified.factors : node.factors;

  final logEntries = <({double logAbs, int sign, int exp})>[];
  final otherFactors = <Expr>[];
  var hasNegativeExp = false;

  for (final factor in sourceFactors) {
    final (base, expExpr) = decomposeFactor(factor);
    if (expExpr case IntegerNumber(asInt: final e?) when e != 0) {
      ({double logAbs, int sign})? entry;
      if (base is Gamma) {
        final approxArg = _approximateNode(base.expr);
        if (approxArg is RealNumeric) {
          final g = logAbsGammaWithSign(approxArg.toDouble());
          if (!g.logAbs.isNaN && g.sign != 0) {
            entry = g;
          }
        }
      } else if (base is Factorial) {
        final approxArg = _approximateNode(base.expr);
        if (approxArg is RealNumeric) {
          final g = logAbsGammaWithSign(approxArg.toDouble() + 1.0);
          if (!g.logAbs.isNaN && g.sign != 0) {
            entry = g;
          }
        }
      } else if (base is Binomial) {
        final approxN = _approximateNode(base.left);
        final approxK = _approximateNode(base.right);
        if (approxN is RealNumeric && approxK is RealNumeric) {
          final b = logAbsBinomialWithSign(
            approxN.toDouble(),
            approxK.toDouble(),
          );
          if (!b.logAbs.isNaN && (b.sign != 0 || e > 0)) {
            entry = b;
          }
        }
      }
      if (entry != null) {
        if (e < 0) hasNegativeExp = true;
        logEntries.add((logAbs: entry.logAbs, sign: entry.sign, exp: e));
        continue;
      }
    }
    otherFactors.add(factor);
  }

  if (logEntries.length >= 2 && hasNegativeExp) {
    var totalLog = 0.0;
    var totalSign = 1;
    for (final entry in logEntries) {
      if (entry.sign == 0) {
        totalSign = 0;
        break;
      }
      totalLog += entry.exp * entry.logAbs;
      if (entry.exp.isOdd) {
        totalSign *= entry.sign;
      }
    }
    final combined = totalSign == 0
        ? const RealNumber(0.0)
        : RealNumber.fromDouble(totalSign * math.exp(totalLog));
    return simplifyMul([
      combined,
      ...otherFactors.map(_approximateNode),
    ], assumptions: Assumptions.none);
  }

  if (simplified == Constant.undefined) {
    return Constant.undefined;
  }

  return Mul(sourceFactors.map(_approximateNode).toList()).simplify();
}

Expr _approximateConstant(Constant c) {
  if (c == Constant.infinity || c == Constant.undefined) return c;
  return _complexToExpr(c.value);
}

Expr _complexToExpr(Complex c) {
  if (c.isNaN) return Constant.undefined;
  final re = c.a.toDouble();
  final im = c.b.toDouble();
  if (im == 0.0) {
    return RealNumber.fromDouble(re);
  }
  if (!re.isFinite || !im.isFinite) {
    return Constant.undefined;
  }
  return ComplexNumber.of(RealNumber(re), RealNumber(im));
}

Expr _approximatePow(Expr base, Expr exponent) {
  if (base is Number && exponent is Number) {
    if (base is RealNumeric && exponent is RealNumeric) {
      final b = base.toDouble();
      final e = exponent.toDouble();
      if (b < 0 && e != e.truncateToDouble()) {
        return _complexToExpr(Pow(base, exponent).evaluateComplex());
      }
    }
    if (base.isZero && exponent is RealNumeric && exponent.isNegative) {
      return Constant.undefined;
    }
    final folded = base.powNumber(exponent);
    if (folded != null) return folded;
  }
  return Pow(base, exponent).simplify();
}

Expr _approximateUnary(UnaryExpr node, Expr approxChild) {
  final rebuilt = node.mapChildren((_) => approxChild);
  if (approxChild is Number) {
    if (approxChild is RealNumeric) {
      final realVal = rebuilt.evaluate();
      if (!realVal.isNaN) {
        return RealNumber.fromDouble(realVal);
      }
    }
    return _complexToExpr(rebuilt.evaluateComplex());
  }
  return rebuilt.simplify();
}

Expr _approximateBinary(BinaryExpr node) {
  final approxLeft = _approximateNode(node.left);
  final approxRight = _approximateNode(node.right);
  final rebuilt = node.mapChildren(
    (child) => identical(child, node.left) ? approxLeft : approxRight,
  );
  if (approxLeft is Number && approxRight is Number) {
    if (approxLeft is RealNumeric && approxRight is RealNumeric) {
      final realVal = rebuilt.evaluate();
      if (!realVal.isNaN) {
        return RealNumber.fromDouble(realVal);
      }
    }
    return _complexToExpr(rebuilt.evaluateComplex());
  }
  return rebuilt.simplify();
}

Expr _rationalizeNode(Expr expr, int maxDenominator, double tolerance) =>
    switch (expr) {
      RealNumber(:final value) => _doubleToRational(
        value,
        maxDenominator,
        tolerance,
      ),
      ComplexNumber(:final real, :final imaginary) => ComplexNumber.of(
        _rationalizeRealNumeric(real, maxDenominator, tolerance),
        _rationalizeRealNumeric(imaginary, maxDenominator, tolerance),
      ),
      RationalNumber() || Constant() || Variable() || OrderTerm() => expr,
      _ => expr.mapChildren(
        (child) => _rationalizeNode(child, maxDenominator, tolerance),
      ),
    };

RealNumeric _rationalizeRealNumeric(
  RealNumeric value,
  int maxDenominator,
  double tolerance,
) => switch (value) {
  RationalNumber() => value,
  RealNumber(:final value) => _doubleToRational(
    value,
    maxDenominator,
    tolerance,
  ),
};

RationalNumber _doubleToRational(
  double x,
  int maxDenominator,
  double tolerance,
) {
  if (x == 0.0) return IntegerNumber.zero;
  final scaledTolerance = tolerance * (x.abs() > 1.0 ? x.abs() : 1.0);
  final fraction = Fraction.fromDouble(
    x,
    maxDenominator: maxDenominator,
    absoluteError: scaledTolerance,
  );
  return RationalNumber(fraction.numerator, fraction.denominator);
}
