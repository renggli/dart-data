import 'dart:math' as math;

import '../ast.dart';

/// Deterministic structural tag for ordering [Expr] nodes across AST variants.
///
/// Follows the canonical hierarchy:
/// `Number < Constant < Variable < Unary < Pow < Mul < Add < ... < OrderTerm`.
int nodeTag(Expr expr) => switch (expr) {
  Number() => 0,
  Constant() => 1,
  Variable() => 2,
  Cos() => 3,
  Ln() => 4,
  Sin() => 5,
  Tan() => 6,
  Asin() => 7,
  Acos() => 8,
  Atan() => 9,
  Sinh() => 10,
  Cosh() => 11,
  Tanh() => 12,
  Asinh() => 13,
  Acosh() => 14,
  Atanh() => 15,
  Abs() => 16,
  Pow() => 17,
  Mul() => 18,
  Add() => 19,
  LambertW() => 20,
  Erf() => 21,
  Erfc() => 22,
  Gamma() => 23,
  Beta() => 24,
  LessThan() => 25,
  LessEqual() => 26,
  GreaterThan() => 27,
  GreaterEqual() => 28,
  Equal() => 29,
  NotEqual() => 30,
  Piecewise() => 31,
  Integral() => 32,
  OrderTerm() => 33,
  VariableFunction() => 34,
};

/// Total structural ordering comparator over all [Expr] AST nodes.
///
/// Guarantees reflexivity (`compareStructural(a, a) == 0`), antisymmetry
/// (`compareStructural(a, b) == -compareStructural(b, a)`), transitivity,
/// and compatibility with `==` (`compareStructural(a, b) == 0` iff `a == b`).
int compareStructural(Expr a, Expr b) {
  if (identical(a, b)) return 0;

  final tagA = nodeTag(a);
  final tagB = nodeTag(b);
  if (tagA != tagB) return tagA.compareTo(tagB);

  return switch ((a, b)) {
    (final Number na, final Number nb) => _compareNumber(na, nb),
    (final Constant ca, final Constant cb) => _compareConstant(ca, cb),
    (final Variable va, final Variable vb) => () {
      final cmpName = va.name.compareTo(vb.name);
      if (cmpName != 0) return cmpName;
      return va.domain.index.compareTo(vb.domain.index);
    }(),
    (final VariableFunction fa, final VariableFunction fb) => () {
      final cmpName = fa.name.compareTo(fb.name);
      if (cmpName != 0) return cmpName;
      return _compareList(fa.arguments, fb.arguments);
    }(),
    (final LambertW la, final LambertW lb) => () {
      final cmpBranch = la.branch.compareTo(lb.branch);
      if (cmpBranch != 0) return cmpBranch;
      return compareStructural(la.expr, lb.expr);
    }(),
    (final UnaryExpr ua, final UnaryExpr ub) => compareStructural(
      ua.expr,
      ub.expr,
    ),
    (final BinaryExpr ba, final BinaryExpr bb) => () {
      final cmpLeft = compareStructural(ba.left, bb.left);
      if (cmpLeft != 0) return cmpLeft;
      return compareStructural(ba.right, bb.right);
    }(),
    (final Add aa, final Add ab) => _compareList(aa.terms, ab.terms),
    (final Mul ma, final Mul mb) => _compareList(ma.factors, mb.factors),
    (final Integral ia, final Integral ib) => () {
      final cmpVar = ia.variable.compareTo(ib.variable);
      if (cmpVar != 0) return cmpVar;
      final cmpInt = compareStructural(ia.integrand, ib.integrand);
      if (cmpInt != 0) return cmpInt;
      return switch ((ia.lower, ib.lower, ia.upper, ib.upper)) {
        (null, null, _, _) => 0,
        (null, _, _, _) => -1,
        (_, null, _, _) => 1,
        (final lowA?, final lowB?, final upA?, final upB?) => () {
          final cmpLow = compareStructural(lowA, lowB);
          return cmpLow != 0 ? cmpLow : compareStructural(upA, upB);
        }(),
        _ => 0,
      };
    }(),
    (final OrderTerm oa, final OrderTerm ob) => () {
      final cmpVar = oa.variable.compareTo(ob.variable);
      if (cmpVar != 0) return cmpVar;
      final cmpOrd = oa.order.compareTo(ob.order);
      if (cmpOrd != 0) return cmpOrd;
      return compareStructural(oa.point, ob.point);
    }(),
    (final Piecewise pa, final Piecewise pb) => () {
      final cmpLen = pa.branches.length.compareTo(pb.branches.length);
      if (cmpLen != 0) return cmpLen;
      for (var i = 0; i < pa.branches.length; i++) {
        final cmpCond = compareStructural(
          pa.branches[i].relation,
          pb.branches[i].relation,
        );
        if (cmpCond != 0) return cmpCond;
        final cmpVal = compareStructural(
          pa.branches[i].expr,
          pb.branches[i].expr,
        );
        if (cmpVal != 0) return cmpVal;
      }
      return switch ((pa.otherwise, pb.otherwise)) {
        (null, null) => 0,
        (null, _) => -1,
        (_, null) => 1,
        (final otherA?, final otherB?) => compareStructural(otherA, otherB),
      };
    }(),
    _ => 0,
  };
}

int _compareList(List<Expr> listA, List<Expr> listB) {
  final minLen = math.min(listA.length, listB.length);
  for (var i = 0; i < minLen; i++) {
    final cmp = compareStructural(listA[i], listB[i]);
    if (cmp != 0) return cmp;
  }
  return listA.length.compareTo(listB.length);
}

int _compareNumber(Number a, Number b) => switch ((a, b)) {
  (final RealNumeric ra, final RealNumeric rb) => ra.compareTo(rb),
  (RealNumeric(), ComplexNumber()) => -1,
  (ComplexNumber(), RealNumeric()) => 1,
  (final ComplexNumber ca, final ComplexNumber cb) => () {
    final cmpReal = ca.real.compareTo(cb.real);
    return cmpReal != 0 ? cmpReal : ca.imaginary.compareTo(cb.imaginary);
  }(),
};

int _compareConstant(Constant a, Constant b) {
  final cmpName = a.name.compareTo(b.name);
  if (cmpName != 0) return cmpName;
  final cmpReal = _compareDoubleWithNaN(
    a.value.a.toDouble(),
    b.value.a.toDouble(),
  );
  if (cmpReal != 0) return cmpReal;
  final cmpImag = _compareDoubleWithNaN(
    a.value.b.toDouble(),
    b.value.b.toDouble(),
  );
  if (cmpImag != 0) return cmpImag;
  final cmpLatex = a.latex.compareTo(b.latex);
  if (cmpLatex != 0) return cmpLatex;
  return a.mathMl.compareTo(b.mathMl);
}

int _compareDoubleWithNaN(double a, double b) {
  final nanA = a.isNaN;
  final nanB = b.isNaN;
  if (nanA && nanB) return 0;
  if (nanA) return 1;
  if (nanB) return -1;
  return a.compareTo(b);
}

/// Extracts the numerical `double` value if [expr] is a [RealNumeric],
/// or `null` otherwise.
double? realScalarValue(Expr expr) =>
    expr is RealNumeric ? expr.toDouble() : null;
