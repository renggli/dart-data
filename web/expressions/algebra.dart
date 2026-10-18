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

/// Factors an expression, factoring polynomials or rational numbers into prime powers.
Expr factorExpr(Expr expr, {Assumptions assumptions = Assumptions.none}) =>
    expr.simplify(assumptions: assumptions).factor(assumptions: assumptions);
