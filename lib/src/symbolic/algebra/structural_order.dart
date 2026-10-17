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
  Piecewise() => 30,
  Integral() => 31,
  OrderTerm() => 32,
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
      if (ia.lower == null && ib.lower == null) return 0;
      if (ia.lower == null) return -1;
      if (ib.lower == null) return 1;
      final cmpLow = compareStructural(ia.lower!, ib.lower!);
      if (cmpLow != 0) return cmpLow;
      return compareStructural(ia.upper!, ib.upper!);
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
        final cmpCond = compareStructural(pa.branches[i].$1, pb.branches[i].$1);
        if (cmpCond != 0) return cmpCond;
        final cmpVal = compareStructural(pa.branches[i].$2, pb.branches[i].$2);
        if (cmpVal != 0) return cmpVal;
      }
      if (pa.otherwise == null && pb.otherwise == null) return 0;
      if (pa.otherwise == null) return -1;
      if (pb.otherwise == null) return 1;
      return compareStructural(pa.otherwise!, pb.otherwise!);
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

int _compareNumber(Number a, Number b) {
  if (a is RealNumeric && b is RealNumeric) {
    return a.compareTo(b);
  }
  if (a is RealNumeric && b is ComplexNumber) return -1;
  if (a is ComplexNumber && b is RealNumeric) return 1;
  final ca = a as ComplexNumber;
  final cb = b as ComplexNumber;
  final cmpReal = ca.real.compareTo(cb.real);
  if (cmpReal != 0) return cmpReal;
  return ca.imaginary.compareTo(cb.imaginary);
}

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
