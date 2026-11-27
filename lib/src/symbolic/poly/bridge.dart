import '../../polynomial/polynomial.dart';
import '../algebra/expand.dart';
import '../algebra/helpers.dart';
import '../ast.dart';
import '../type/expr_data_type.dart';
import 'univariate.dart';

/// Extracts a univariate polynomial over `Q[x]` in [variable] from [expr],
/// or returns `null` if [expr] has non-rational coefficients, other variables,
/// or non-polynomial operations.
PolyQ? exprToPolyQ(Expr expr, String variable, {bool expanded = false}) {
  final source = (!expanded && _hasExpandablePolyNode(expr, variable))
      ? expr.expand()
      : expr;
  final coeffMap = _extractRationalMap(source, variable);
  if (coeffMap == null) return null;
  if (coeffMap.isEmpty) return PolyQ.zero;
  var maxDeg = 0;
  for (final d in coeffMap.keys) {
    if (d > maxDeg) maxDeg = d;
  }
  return PolyQ([
    for (var i = 0; i <= maxDeg; i++) coeffMap[i] ?? IntegerNumber.zero,
  ]);
}

/// Converts a univariate [PolyQ] back to a canonically ordered symbolic [Expr].
Expr polyQToExpr(PolyQ poly, String variable) =>
    buildPolyExprFromRational(poly.coeffs, variable);

/// Converts a univariate [PolyZ] back to a canonically ordered symbolic [Expr].
Expr polyZToExpr(PolyZ poly, String variable) {
  if (poly.isZero) return IntegerNumber.zero;
  if (poly.isConstant) return IntegerNumber(poly.coeffs.first);
  final x = Variable(variable);
  final coeffs = poly.coeffs;
  final terms = <Expr>[];
  if (coeffs[0] != BigInt.zero) {
    terms.add(IntegerNumber(coeffs[0]));
  }
  if (coeffs.length > 1 && coeffs[1] != BigInt.zero) {
    final c = IntegerNumber(coeffs[1]);
    terms.add(c.isOne ? x : Mul.canonical([c, x], simplified: true));
  }
  for (var k = 2; k < coeffs.length; k++) {
    final raw = coeffs[k];
    if (raw == BigInt.zero) continue;
    final c = IntegerNumber(raw);
    final xk = Pow.canonical(x, IntegerNumber.of(k), simplified: true);
    terms.add(c.isOne ? xk : Mul.canonical([c, xk], simplified: true));
  }
  return switch (terms) {
    [] => IntegerNumber.zero,
    [final single] => single,
    _ => Add.canonical(terms, simplified: true),
  };
}

/// Builds canonical linear factor expression `q * x - p`.
Expr buildLinearFactorExpr(BigInt q, BigInt p, String variable) =>
    polyZToExpr(PolyZ([-p, q]), variable);

/// Builds canonical simplified [Expr] from ascending [RationalNumber]
/// coefficients `[c_0, c_1, ..., c_d]`.
Expr buildPolyExprFromRational(List<RationalNumber> coeffs, String variable) {
  if (coeffs.isEmpty) return IntegerNumber.zero;
  final x = Variable(variable);
  final terms = <Expr>[];
  if (!coeffs[0].isZero) {
    terms.add(coeffs[0]);
  }
  if (coeffs.length > 1 && !coeffs[1].isZero) {
    final c = coeffs[1];
    terms.add(c.isOne ? x : Mul.canonical([c, x], simplified: true));
  }
  for (var k = 2; k < coeffs.length; k++) {
    final c = coeffs[k];
    if (c.isZero) continue;
    final xk = Pow.canonical(x, IntegerNumber.of(k), simplified: true);
    terms.add(c.isOne ? xk : Mul.canonical([c, xk], simplified: true));
  }
  return switch (terms) {
    [] => IntegerNumber.zero,
    [final single] => single,
    _ => Add.canonical(terms, simplified: true),
  };
}

/// Bridges symbolic expression [expr] to `package:data` [Polynomial<Expr>] in
/// [variable] over [exprDataType], or `null` if not polynomial in [variable].
Polynomial<Expr>? exprToSymbolicPolynomial(Expr expr, String variable) {
  final map = extractPolynomialCoefficients(expr, variable);
  if (map == null) return null;
  final maxDeg = maxPolynomialDegree(map);
  if (maxDeg < 0) return Polynomial<Expr>.zero(type: exprDataType);
  return Polynomial<Expr>.fromCoefficients([
    for (var i = 0; i <= maxDeg; i++) map[i] ?? IntegerNumber.zero,
  ], type: exprDataType);
}

/// Converts a symbolic [Polynomial<Expr>] in [variable] back to a simplified
/// [Expr].
Expr symbolicPolynomialToExpr(Polynomial<Expr> poly, String variable) {
  if (poly.degree < 0) return IntegerNumber.zero;
  final coeffs = <int, Expr>{for (var i = 0; i <= poly.degree; i++) i: poly[i]};
  return buildPolynomialFromCoefficients(coeffs, variable);
}

Map<int, RationalNumber>? _extractRationalMap(Expr expr, String variable) {
  final coeffMap = <int, RationalNumber>{};
  bool visit(Expr node, RationalNumber scale) {
    switch (node) {
      case Add(:final terms):
        for (final t in terms) {
          if (!visit(t, scale)) return false;
        }
        return true;
      case final RationalNumber r:
        final prod = scale.mulRational(r);
        coeffMap[0] = (coeffMap[0] ?? IntegerNumber.zero).addRational(prod);
        return true;
      case Variable(:final name) when name == variable:
        coeffMap[1] = (coeffMap[1] ?? IntegerNumber.zero).addRational(scale);
        return true;
      case Pow(
            base: Variable(:final name),
            exponent: RationalNumber(asInt: final k?),
          )
          when name == variable && k >= 0:
        coeffMap[k] = (coeffMap[k] ?? IntegerNumber.zero).addRational(scale);
        return true;
      case Mul(:final factors):
        var factorCoeff = scale;
        var power = 0;
        for (final f in factors) {
          switch (f) {
            case final RationalNumber r:
              factorCoeff = factorCoeff.mulRational(r);
            case Variable(:final name) when name == variable:
              power += 1;
            case Pow(
                  base: Variable(:final name),
                  exponent: RationalNumber(asInt: final k?),
                )
                when name == variable && k >= 0:
              power += k;
            default:
              return false;
          }
        }
        coeffMap[power] = (coeffMap[power] ?? IntegerNumber.zero).addRational(
          factorCoeff,
        );
        return true;
      default:
        return false;
    }
  }

  if (!visit(expr, IntegerNumber.one)) return null;
  coeffMap.removeWhere((_, v) => v.isZero);
  return coeffMap;
}

bool _hasExpandablePolyNode(Expr expr, String variable) => expr.anyNode(
  (n) => switch (n) {
    Mul(:final factors) when n.dependsOn(variable) => factors.any(
      (f) => f is Add,
    ),
    Pow(:final base, exponent: IntegerNumber(asInt: final e?))
        when e > 0 && base is Add && base.dependsOn(variable) =>
      true,
    _ => false,
  },
);
