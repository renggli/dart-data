import '../ast.dart';
import 'simplify.dart';

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
  Mul(:final factors) => Mul(factors.map(_approximateNode).toList()).simplify(),
  Pow(:final base, :final exponent) => _approximatePow(
    _approximateNode(base),
    _approximateNode(exponent),
  ),
  UnaryExpr(:final expr) => _approximateUnary(node, _approximateNode(expr)),
  RelationalExpr() ||
  Piecewise() ||
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
};

Expr _approximateConstant(Constant c) {
  if (c == Constant.infinity || c == Constant.undefined) return c;
  final val = c.value;
  if (val.isNaN) return Constant.undefined;
  final re = val.a.toDouble();
  final im = val.b.toDouble();
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
        final c = Pow(base, exponent).evaluateComplex();
        final re = c.a.toDouble();
        final im = c.b.toDouble();
        if (c.isNaN || !re.isFinite || !im.isFinite) {
          return Constant.undefined;
        }
        return ComplexNumber.of(RealNumber(re), RealNumber(im));
      }
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
    final complexVal = rebuilt.evaluateComplex();
    if (complexVal.isNaN) return Constant.undefined;
    final re = complexVal.a.toDouble();
    final im = complexVal.b.toDouble();
    if (im == 0.0) {
      return RealNumber.fromDouble(re);
    }
    if (!re.isFinite || !im.isFinite) {
      return Constant.undefined;
    }
    return ComplexNumber.of(RealNumber(re), RealNumber(im));
  }
  return rebuilt.simplify();
}

Expr _approximateBinary(BinaryExpr node) {
  final approxLeft = _approximateNode(node.left);
  final approxRight = _approximateNode(node.right);
  final rebuilt = node.mapChildren(
    (child) => identical(child, node.left) ? approxLeft : approxRight,
  );
  if (approxLeft is RealNumeric && approxRight is RealNumeric) {
    final realVal = rebuilt.evaluate();
    return realVal.isNaN ? Constant.undefined : RealNumber.fromDouble(realVal);
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
  final sign = x < 0 ? -1 : 1;
  final target = x.abs();

  var hPrev = 0;
  var kPrev = 1;
  var hCurr = 1;
  var kCurr = 0;
  var rem = target;

  for (var step = 0; step < 64; step++) {
    final a = rem.floor();
    final hNext = a * hCurr + hPrev;
    final kNext = a * kCurr + kPrev;

    if (kNext > maxDenominator && kCurr > 0) {
      break;
    }

    hPrev = hCurr;
    kPrev = kCurr;
    hCurr = hNext;
    kCurr = kNext;

    final approx = hCurr / kCurr;
    if ((approx - target).abs() <= tolerance * (target > 1.0 ? target : 1.0)) {
      break;
    }

    final frac = rem - a;
    if (frac <= 1e-15) break;
    rem = 1.0 / frac;
  }

  return RationalNumber.of(Integer(sign * hCurr), Integer(kCurr));
}
