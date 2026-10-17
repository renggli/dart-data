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

/// Recursively checks whether [expr] explicitly references a non-real complex number.
bool containsImaginary(Expr expr) =>
    expr.anyNode((node) => node is ComplexNumber && !node.isReal);

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
  if (n == 0) return IntegerNumber.zero;
  final isNeg = n < 0;
  var rem = n.abs();
  if (rem == 1) return IntegerNumber.of(n);

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

  final factorNodes = <Expr>[
    if (isNeg) IntegerNumber.negativeOne,
    for (final entry in factors.entries)
      if (entry.value == 1)
        IntegerNumber.of(entry.key)
      else
        Pow(IntegerNumber.of(entry.key), IntegerNumber.of(entry.value)),
  ];
  if (factorNodes.isEmpty) return IntegerNumber.of(n);
  if (factorNodes.length == 1) return factorNodes.first;
  return Mul(factorNodes);
}

/// Factors an expression, factoring irreducible polynomials or integers into prime powers.
Expr factorExpr(Expr expr) {
  final factored = expr.factor();
  if (factored is IntegerNumber &&
      !factored.value.isBig &&
      factored.value.abs() > Integer.one) {
    return factorIntegerExpr(factored.value.toInt());
  }

  // Also check if simplifying the expression yields an integer
  final simp = expr.simplify();
  if (simp is IntegerNumber &&
      !simp.value.isBig &&
      simp.value.abs() > Integer.one) {
    return factorIntegerExpr(simp.value.toInt());
  }

  return factored;
}
