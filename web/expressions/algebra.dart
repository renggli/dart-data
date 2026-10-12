import 'package:data/symbolic.dart';
import 'package:more/number.dart' show Complex;

/// Formats numeric values, handling NaN, Infinities, and negative zero.
String formatRealNumber(num value, {int precision = 4}) {
  if (value.isNaN) return 'Undefined';
  if (value.isInfinite) return value.isNegative ? '-∞' : '∞';
  if (value == 0 || value.abs() < 1e-12) return '0';
  if (value % 1 == 0 && value.abs() < 1e12) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(precision);
}

/// Recursively checks whether [expr] explicitly references the imaginary unit constant `i`.
bool containsImaginary(Expr expr) => switch (expr) {
  ConstantNumber(name: 'i') => true,
  UnaryExpr(:final expr) => containsImaginary(expr),
  BinaryExpr(:final left, :final right) =>
    containsImaginary(left) || containsImaginary(right),
  _ => false,
};

/// Formats a complex number [c] into standard mathematical notation (e.g. `1 + 2i`, `-i`, `4.50`).
String formatComplex(Complex c, {int precision = 4}) {
  if (c.a.isNaN || c.b.isNaN) return 'Undefined';
  if (c.b.abs() < 1e-9) {
    return formatRealNumber(c.a, precision: precision);
  }
  if (c.a.abs() < 1e-9) {
    if ((c.b - 1).abs() < 1e-9) return 'i';
    if ((c.b + 1).abs() < 1e-9) return '-i';
    return '${formatRealNumber(c.b, precision: precision)}i';
  }
  final sign = c.b >= 0 ? '+' : '-';
  final bPart = (c.b.abs() - 1).abs() < 1e-9
      ? 'i'
      : '${formatRealNumber(c.b.abs(), precision: precision)}i';
  return '${formatRealNumber(c.a, precision: precision)} $sign $bPart';
}

/// Factors an integer into a prime power product expression (e.g. 60 -> 2^2 * 3 * 5).
Expr factorIntegerExpr(int n) {
  if (n == 0) return RationalNumber.zero;
  final isNeg = n < 0;
  var rem = n.abs();
  if (rem == 1) return RationalNumber(n);

  final factors = <int, int>{};
  var d = 2;
  while (d * d <= rem) {
    while (rem % d == 0) {
      factors[d] = (factors[d] ?? 0) + 1;
      rem ~/= d;
    }
    d += (d == 2) ? 1 : 2;
  }
  if (rem > 1) {
    factors[rem] = (factors[rem] ?? 0) + 1;
  }

  Expr? result;
  for (final entry in factors.entries) {
    final prime = RationalNumber(entry.key);
    final count = entry.value;
    final term = count == 1 ? prime : Pow(prime, RationalNumber(count));
    result = result == null ? term : Mul(result, term);
  }
  if (result == null) return RationalNumber(n);
  return isNeg ? Neg(result) : result;
}

/// Factors an expression, factoring irreducible polynomials or integers into prime powers.
Expr factorExpr(Expr expr) {
  final factored = expr.factor();
  if (factored is RationalNumber &&
      factored.isInteger &&
      factored.numerator.abs() > 1) {
    return factorIntegerExpr(factored.numerator);
  }
  if (factored is Neg && factored.expr is RationalNumber) {
    final inner = factored.expr as RationalNumber;
    if (inner.isInteger && inner.numerator.abs() > 1) {
      return Neg(factorIntegerExpr(inner.numerator));
    }
  }

  // Also check if simplifying the expression yields an integer
  final simp = expr.simplify();
  if (simp is RationalNumber && simp.isInteger && simp.numerator.abs() > 1) {
    return factorIntegerExpr(simp.numerator);
  }
  if (simp is Neg && simp.expr is RationalNumber) {
    final inner = simp.expr as RationalNumber;
    if (inner.isInteger && inner.numerator.abs() > 1) {
      return Neg(factorIntegerExpr(inner.numerator));
    }
  }

  return factored;
}
