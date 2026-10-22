import '../../assumptions.dart';
import '../../ast.dart';
import '../simplify.dart';
import '../term_accumulator.dart';

/// Simplifies an N-ary addition expression across [terms].
Expr simplifyAdd(
  List<Expr> terms, {
  Assumptions assumptions = Assumptions.none,
}) {
  switch (terms) {
    case []:
      return IntegerNumber.zero;
    case [Add()] || [Mul(factors: [Number(isNegativeOne: true), Add()])]:
      break;
    case [final single]:
      return single;
    case [final Number left, final Number right]:
      return left.add(right);
  }

  final acc = MonomialAccumulator(
    simplify: (e) => simplifyExpr(e, assumptions: assumptions),
    assumptions: assumptions,
  );
  for (final term in terms) {
    acc.add(term);
  }
  acc.reduceIdentities();
  return acc.build();
}

/// Simplifies a binary subtraction `left - right`.
Expr simplifySub(
  Expr left,
  Expr right, {
  Assumptions assumptions = Assumptions.none,
}) => simplifyAdd([left, simplifyNeg(right)], assumptions: assumptions);

/// Simplifies a unary negation `-[expr]`.
Expr simplifyNeg(Expr expr) => switch (expr) {
  final Number n => n.neg(),
  OrderTerm() => expr,
  Add() => () {
    final acc = MonomialAccumulator(simplify: simplifyExpr);
    acc.add(expr, IntegerNumber.negativeOne);
    acc.reduceIdentities();
    return acc.build();
  }(),
  _ => MonomialAccumulator.negateMonomial(expr),
};
