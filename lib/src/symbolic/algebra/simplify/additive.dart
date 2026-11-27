import '../../assumptions.dart';
import '../../ast.dart';
import '../simplify.dart';
import '../term_accumulator.dart';

/// Simplifies an N-ary addition expression across [terms].
Expr simplifyAdd(
  List<Expr> terms, {
  required Assumptions assumptions,
  Expr Function(Expr)? simplify,
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
    case [final RationalNumber r, final other] when _isSimplePolyTerm(other):
      if (r.isZero) return other;
      return Add.canonical(
        [r, other],
        simplified:
            identical(assumptions, Assumptions.none) || assumptions.isEmpty,
      );
    case [final other, final RationalNumber r] when _isSimplePolyTerm(other):
      if (r.isZero) return other;
      return Add.canonical(
        [r, other],
        simplified:
            identical(assumptions, Assumptions.none) || assumptions.isEmpty,
      );
  }

  final acc = MonomialAccumulator(
    simplify: simplify ?? (e) => simplifyExpr(e, assumptions: assumptions),
    assumptions: assumptions,
  );
  for (final term in terms) {
    acc.add(term);
  }
  acc.reduceIdentities();
  return acc.build();
}

bool _isSimplePolyTerm(Expr e) => switch (e) {
  Variable() => true,
  Pow(base: Variable(), exponent: IntegerNumber(asInt: final n?)) => n >= 2,
  _ => false,
};

/// Simplifies a binary subtraction `left - right`.
Expr simplifySub(Expr left, Expr right, {required Assumptions assumptions}) =>
    simplifyAdd([
      left,
      simplifyNeg(right, assumptions: assumptions),
    ], assumptions: assumptions);

/// Simplifies a unary negation `-[expr]`.
Expr simplifyNeg(Expr expr, {required Assumptions assumptions}) =>
    switch (expr) {
      final Number n => n.neg(),
      OrderTerm() => expr,
      Add() => () {
        final acc = MonomialAccumulator(
          simplify: (e) => simplifyExpr(e, assumptions: assumptions),
          assumptions: assumptions,
        );
        acc.add(expr, IntegerNumber.negativeOne);
        acc.reduceIdentities();
        return acc.build();
      }(),
      _ => MonomialAccumulator.negateMonomial(expr),
    };
