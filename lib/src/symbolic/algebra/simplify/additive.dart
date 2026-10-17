import '../../ast.dart';
import '../simplify.dart';
import '../term_accumulator.dart';

/// Simplifies an N-ary addition expression across [terms].
Expr simplifyAdd(List<Expr> terms) {
  if (terms.isEmpty) return IntegerNumber.zero;
  if (terms.length == 1) {
    final single = terms.first;
    if (single is! Add &&
        !(single is Mul &&
            single.factors.length == 2 &&
            single.factors[0] is Number &&
            (single.factors[0] as Number).isNegativeOne &&
            single.factors[1] is Add)) {
      return single;
    }
  }
  if (terms.length == 2) {
    final left = terms[0];
    final right = terms[1];
    if (left is Number && right is Number) {
      return left.add(right);
    }
  }

  final acc = MonomialAccumulator(simplify: simplifyExpr);
  for (final term in terms) {
    acc.add(term);
  }
  acc.reduceIdentities();
  return acc.build();
}

/// Simplifies a binary subtraction `left - right`.
Expr simplifySub(Expr left, Expr right) =>
    simplifyAdd([left, simplifyNeg(right)]);

/// Simplifies a unary negation `-[expr]`.
Expr simplifyNeg(Expr expr) {
  if (expr is Number) {
    return expr.neg();
  }
  if (expr is OrderTerm) {
    return expr;
  }
  if (expr is Add) {
    final acc = MonomialAccumulator(simplify: simplifyExpr);
    acc.add(expr, IntegerNumber.negativeOne);
    acc.reduceIdentities();
    return acc.build();
  }
  if (expr is Mul && expr.factors.isNotEmpty) {
    final first = expr.factors.first;
    if (first is Number) {
      final negFirst = first.neg();
      final rest = expr.factors.sublist(1);
      if (negFirst.isOne) {
        return rest.length == 1
            ? rest.first
            : Mul(rest, isSimplified: expr.isSimplified);
      }
      return Mul([negFirst, ...rest], isSimplified: expr.isSimplified);
    }
    return Mul([
      IntegerNumber.negativeOne,
      ...expr.factors,
    ], isSimplified: expr.isSimplified);
  }
  return Mul([
    IntegerNumber.negativeOne,
    expr,
  ], isSimplified: expr.isSimplified);
}
