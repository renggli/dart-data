import 'dart:math' as math;

import 'package:more/number.dart' show Complex, Fraction;

import '../assumptions.dart';
import '../ast.dart';
import '../compiler.dart';
import '../compiler/evaluator_helpers.dart';
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
    final target = bindings.isEmpty
        ? this
        : _substituteBindings(this, bindings);
    return _approximateNode(target).simplify();
  }

  /// Replaces floating-point [RealNumber] leaves with their best rational
  /// approximations ([IntegerNumber] or [FractionNumber]) via continued
  /// fractions bounded by [maxDenominator] and [tolerance].
  ///
  /// ```dart
  /// RealNumber(0.3333333333333333).rationalize(); // 1 / 3
  /// ```
  Expr rationalize({int maxDenominator = 1000000, double tolerance = 1e-12}) {
    if (maxDenominator < 1) {
      throw ArgumentError.value(
        maxDenominator,
        'maxDenominator',
        'Must be >= 1',
      );
    }
    if (tolerance.isNaN || tolerance < 0.0) {
      throw ArgumentError.value(tolerance, 'tolerance', 'Must be >= 0');
    }
    return _rationalizeNode(this, maxDenominator, tolerance).simplify();
  }
}

Expr _substituteBindings(Expr expr, Map<String, Expr> bindings) {
  if (bindings.length == 1) {
    final entry = bindings.entries.first;
    return expr.substitute(entry.key, entry.value);
  }
  return switch (expr) {
    Variable(:final name) => bindings[name] ?? expr,
    Add() ||
    Mul() ||
    Pow() ||
    Call() => expr.mapChildren((child) => _substituteBindings(child, bindings)),
    _ => () {
      var res = expr;
      for (final MapEntry(:key, :value) in bindings.entries) {
        if (!res.freeVariables.any(
          (v) => v != key && bindings.containsKey(v),
        )) {
          res = res.substitute(key, value);
        }
      }
      if (identical(res, expr)) {
        for (final MapEntry(:key, :value) in bindings.entries) {
          res = res.substitute(key, value);
        }
      }
      return res;
    }(),
  };
}

Expr _approximateNode(Expr node) => switch (node) {
  RationalNumber() => RealNumber.fromDouble(node.toDouble()),
  RealNumber() => node,
  ComplexNumber(:final real, :final imaginary) => _complexToExpr(
    Complex(real.toDouble(), imaginary.toDouble()),
  ),
  Constant() => _approximateConstant(node),
  Variable() || OrderTerm() => node,
  Add(:final terms) => Add.of(terms.map(_approximateNode)).simplify(),
  Mul() => _approximateMul(node),
  Pow(:final base, :final exponent) => () {
    if (base is RationalNumber && exponent is FractionNumber) {
      final folded = base.powNumber(exponent);
      if (folded != null) return _approximateNode(folded);
    }
    return _approximatePow(_approximateNode(base), _approximateNode(exponent));
  }(),
  Call() => _approximateCall(node),
  Relational() ||
  Piecewise() ||
  Derivative() ||
  Limit() ||
  Sum() ||
  Product() => node.mapChildren(_approximateNode),
  Integral() => () {
    final rebuilt = node.mapChildren(_approximateNode) as Integral;
    if (rebuilt.isDefinite && rebuilt.freeVariables.isEmpty) {
      final val = rebuilt.evaluate();
      if (!val.isNaN) return RealNumber.fromDouble(val);
    }
    return rebuilt.simplify();
  }(),
  RootSum() => () {
    final rebuilt = node.mapChildren(_approximateNode) as RootSum;
    if (rebuilt.freeVariables.isEmpty) {
      final z = rebuilt.evaluateComplex();
      if (z.a.isFinite && z.b.isFinite) {
        if (z.b.abs() <= 1e-9 * math.max(1.0, z.a.abs())) {
          return RealNumber.fromDouble(z.a.toDouble());
        }
        return _complexToExpr(z);
      }
    }
    return rebuilt.simplify();
  }(),
};

Expr _approximateMul(Mul node) {
  final simplified = node.simplify();
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
      switch (base) {
        case Call(id: FunctionId.gamma, args: [final arg]):
          final approxArg = _approximateNode(arg);
          if (approxArg is RealNumeric) {
            final g = logAbsGammaWithSign(approxArg.toDouble());
            if (!g.logAbs.isNaN && g.sign != 0) {
              entry = g;
            }
          }
        case Call(id: FunctionId.factorial, args: [final arg]):
          final approxArg = _approximateNode(arg);
          if (approxArg is RealNumeric) {
            final g = logAbsGammaWithSign(approxArg.toDouble() + 1.0);
            if (!g.logAbs.isNaN && g.sign != 0) {
              entry = g;
            }
          }
        case Call(id: FunctionId.binomial, args: [final left, final right]):
          final approxN = _approximateNode(left);
          final approxK = _approximateNode(right);
          if (approxN is RealNumeric && approxK is RealNumeric) {
            final b = logAbsBinomialWithSign(
              approxN.toDouble(),
              approxK.toDouble(),
            );
            if (!b.logAbs.isNaN && (b.sign != 0 || e > 0)) {
              entry = b;
            }
          }
        default:
          break;
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

  return Mul.of(sourceFactors.map(_approximateNode)).simplify();
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
        return _complexToExpr(Pow.of(base, exponent).evaluateComplex());
      }
    }
    if (base.isZero && exponent is RealNumeric && exponent.isNegative) {
      return Constant.undefined;
    }
    final folded = base.powNumber(exponent);
    if (folded != null) return folded;
  }
  return Pow.of(base, exponent).simplify();
}

Expr _approximateCall(Call node) {
  final approxArgs = [for (final arg in node.args) _approximateNode(arg)];
  final rebuilt = Call(node.spec, approxArgs);
  if (node.id == FunctionId.tuple || node.id == FunctionId.symbolic) {
    return rebuilt;
  }
  if (approxArgs.every((arg) => arg is Number) ||
      rebuilt.freeVariables.isEmpty) {
    final hasComplex = rebuilt.anyNode((n) => n is ComplexNumber);
    if (!hasComplex && approxArgs.every((arg) => arg is RealNumeric)) {
      final realVal = rebuilt.evaluate();
      if (!realVal.isNaN) {
        return RealNumber.fromDouble(realVal);
      }
    }
    if (node.id != FunctionId.min &&
        node.id != FunctionId.max &&
        node.id != FunctionId.gcd &&
        node.id != FunctionId.lcm) {
      return _complexToExpr(rebuilt.evaluateComplex());
    }
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
