part of '../ast.dart';

/// Total structural ordering comparator over all [Expr] AST nodes.
///
/// Guarantees reflexivity (`compareStructural(a, a) == 0`), antisymmetry
/// (`compareStructural(a, b) == -compareStructural(b, a)`), transitivity,
/// and compatibility with `==` (`compareStructural(a, b) == 0` iff `a == b`).
int compareStructural(Expr a, Expr b) {
  if (identical(a, b)) return 0;

  final tagA = a.structuralTag;
  final tagB = b.structuralTag;
  if (tagA != tagB) return tagA.compareTo(tagB);

  return switch ((a, b)) {
    (final Number na, final Number nb) => _compareNumber(na, nb),
    (final Constant ca, final Constant cb) => _compareConstant(ca, cb),
    (final Variable va, final Variable vb) => va.name.compareTo(vb.name),
    (final Call ca, final Call cb) => () {
      if (ca.id == FunctionId.symbolic) {
        final cmpName = ca.name.compareTo(cb.name);
        if (cmpName != 0) return cmpName;
      }
      return _compareExprList(ca.args, cb.args);
    }(),
    (final Pow pa, final Pow pb) => () {
      final cmpBase = compareStructural(pa.base, pb.base);
      return cmpBase != 0
          ? cmpBase
          : compareStructural(pa.exponent, pb.exponent);
    }(),
    (final Mul ma, final Mul mb) => _compareExprList(ma.factors, mb.factors),
    (final Add aa, final Add ab) => _compareExprList(aa.terms, ab.terms),
    (final Relational ra, final Relational rb) => () {
      final cmpLeft = compareStructural(ra.left, rb.left);
      return cmpLeft != 0 ? cmpLeft : compareStructural(ra.right, rb.right);
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
      return _compareNullableExpr(pa.otherwise, pb.otherwise);
    }(),
    (final Derivative da, final Derivative db) => () {
      final cmpVar = da.variable.compareTo(db.variable);
      if (cmpVar != 0) return cmpVar;
      final cmpOrd = da.order.compareTo(db.order);
      if (cmpOrd != 0) return cmpOrd;
      final cmpExpr = compareStructural(da.expr, db.expr);
      return cmpExpr != 0 ? cmpExpr : _compareNullableExpr(da.point, db.point);
    }(),
    (final Integral ia, final Integral ib) => () {
      final cmpVar = ia.variable.compareTo(ib.variable);
      if (cmpVar != 0) return cmpVar;
      final cmpInt = compareStructural(ia.integrand, ib.integrand);
      if (cmpInt != 0) return cmpInt;
      final cmpLow = _compareNullableExpr(ia.lower, ib.lower);
      return cmpLow != 0 ? cmpLow : _compareNullableExpr(ia.upper, ib.upper);
    }(),
    (final Limit la, final Limit lb) => () {
      final cmpVar = la.variable.compareTo(lb.variable);
      if (cmpVar != 0) return cmpVar;
      final cmpDir = la.direction.index.compareTo(lb.direction.index);
      if (cmpDir != 0) return cmpDir;
      final cmpPt = compareStructural(la.point, lb.point);
      return cmpPt != 0 ? cmpPt : compareStructural(la.expr, lb.expr);
    }(),
    (final Sum sa, final Sum sb) => () {
      final cmpVar = sa.variable.compareTo(sb.variable);
      if (cmpVar != 0) return cmpVar;
      final cmpLow = compareStructural(sa.lower, sb.lower);
      if (cmpLow != 0) return cmpLow;
      final cmpUp = compareStructural(sa.upper, sb.upper);
      return cmpUp != 0 ? cmpUp : compareStructural(sa.expr, sb.expr);
    }(),
    (final Product pa, final Product pb) => () {
      final cmpVar = pa.variable.compareTo(pb.variable);
      if (cmpVar != 0) return cmpVar;
      final cmpLow = compareStructural(pa.lower, pb.lower);
      if (cmpLow != 0) return cmpLow;
      final cmpUp = compareStructural(pa.upper, pb.upper);
      return cmpUp != 0 ? cmpUp : compareStructural(pa.expr, pb.expr);
    }(),
    (final RootSum ra, final RootSum rb) => () {
      final cmpVar = ra.variable.compareTo(rb.variable);
      if (cmpVar != 0) return cmpVar;
      final cmpPoly = compareStructural(ra.polynomial, rb.polynomial);
      return cmpPoly != 0 ? cmpPoly : compareStructural(ra.body, rb.body);
    }(),
    (final OrderTerm oa, final OrderTerm ob) => () {
      final cmpVar = oa.variable.compareTo(ob.variable);
      if (cmpVar != 0) return cmpVar;
      final cmpOrd = oa.order.compareTo(ob.order);
      return cmpOrd != 0 ? cmpOrd : compareStructural(oa.point, ob.point);
    }(),
    _ => 0,
  };
}

/// Extracts the numerical `double` value if [expr] is a [RealNumeric],
/// or `null` otherwise.
double? realScalarValue(Expr expr) =>
    expr is RealNumeric ? expr.toDouble() : null;

int _compareExprList(List<Expr> listA, List<Expr> listB) {
  final minLen = math.min(listA.length, listB.length);
  for (var i = 0; i < minLen; i++) {
    final cmp = compareStructural(listA[i], listB[i]);
    if (cmp != 0) return cmp;
  }
  return listA.length.compareTo(listB.length);
}

int _compareNumber(Number a, Number b) => switch ((a, b)) {
  (final RealNumeric ra, final RealNumeric rb) => _compareRealNumericStructural(
    ra,
    rb,
  ),
  (RealNumeric(), ComplexNumber()) => -1,
  (ComplexNumber(), RealNumeric()) => 1,
  (final ComplexNumber ca, final ComplexNumber cb) => () {
    final cmpReal = _compareRealNumericStructural(ca.real, cb.real);
    return cmpReal != 0
        ? cmpReal
        : _compareRealNumericStructural(ca.imaginary, cb.imaginary);
  }(),
};

int _compareRealNumericStructural(RealNumeric a, RealNumeric b) {
  final cmp = a.compareTo(b);
  if (cmp != 0) return cmp;
  if (a is RationalNumber && b is RealNumber) return -1;
  if (a is RealNumber && b is RationalNumber) return 1;
  return 0;
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

int _compareNullableExpr(Expr? a, Expr? b) => switch ((a, b)) {
  (null, null) => 0,
  (null, _) => -1,
  (_, null) => 1,
  (final xa?, final xb?) => compareStructural(xa, xb),
};
