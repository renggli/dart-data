import '../../ast.dart';
import '../../poly/bridge.dart';
import '../../poly/factor.dart' as poly_factor;
import '../../poly/univariate.dart';

/// Extracts univariate rational polynomial coefficients for [variable] from [expr].
PolyQ? extractPoly(Expr expr, String variable) => exprToPolyQ(expr, variable);

/// Factors univariate rational polynomial [poly] in [variable].
Expr factorUnivariatePoly(PolyQ poly, String variable) =>
    poly_factor.factorPolyQToExpr(poly, variable);

/// Factors quadratic `a * x^2 + c`.
Map<Expr, int> factorQuadraticInX(BigInt a, BigInt c, String variable) =>
    poly_factor.factorQuadraticInX(a, c, variable);

/// Merges factor multiplicities from [source] into [target].
void mergeFactorsInto(Map<Expr, int> target, Map<Expr, int> source) {
  for (final MapEntry(:key, :value) in source.entries) {
    target[key] = (target[key] ?? 0) + value;
  }
}

/// Performs synthetic division of [coeffs] by linear factor `q * x - p`.
List<BigInt>? syntheticDivide(List<BigInt> coeffs, BigInt p, BigInt q) =>
    poly_factor.syntheticDivide(coeffs, p, q);

/// Builds linear factor `q * x - p` in canonical simplified order.
Expr buildLinearFactor(BigInt q, BigInt p, String variable) =>
    buildLinearFactorExpr(q, p, variable);

/// Builds expression from polynomial integer [coeffs] in canonical simplified order.
Expr buildPolyExpr(List<BigInt> coeffs, String variable) =>
    polyZToExpr(PolyZ(coeffs), variable);

/// Builds expression from rational polynomial [coeffs] in canonical simplified order.
Expr buildPolyExprFromRational(List<RationalNumber> coeffs, String variable) =>
    polyQToExpr(PolyQ(coeffs), variable);

/// Computes exact integer cube root of [n] if perfect cube, or `null`.
BigInt? integerCbrt(BigInt n) => poly_factor.integerCbrt(n);

/// Computes positive integer divisors of [n].
List<BigInt> divisors(BigInt n) => poly_factor.divisors(n);
