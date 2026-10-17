import '../../ast.dart';
import '../simplify.dart';
import '../term_accumulator.dart';

/// Simplifies an N-ary addition expression across [terms].
Expr simplifyAdd(List<Expr> terms) {
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
Expr simplifyNeg(Expr expr) => switch (expr) {
  final Number n => n.neg(),
  OrderTerm() => expr,
  Add() => () {
    final acc = MonomialAccumulator(simplify: simplifyExpr);
    acc.add(expr, IntegerNumber.negativeOne);
    acc.reduceIdentities();
    return acc.build();
  }(),
  Mul(factors: [final Number first, ...final rest], :final isSimplified) => () {
    final negFirst = first.neg();
    if (negFirst.isOne) {
      return switch (rest) {
        [final single] => single,
        _ => Mul(rest, isSimplified: isSimplified),
      };
    }
    return Mul([negFirst, ...rest], isSimplified: isSimplified);
  }(),
  Mul(factors: [_, ...], :final isSimplified) => Mul([
    IntegerNumber.negativeOne,
    ...expr.factors,
  ], isSimplified: isSimplified),
  _ => Mul([IntegerNumber.negativeOne, expr], isSimplified: expr.isSimplified),
};
