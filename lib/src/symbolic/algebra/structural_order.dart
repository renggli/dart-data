import 'package:more/number.dart' show Fraction;

import '../ast.dart';

/// Categorizes [expr] into a deterministic term tier for canonical term ordering:
/// 1. Variable polynomial terms (degree > 0 or with free variables, without `i`).
/// 2. Pure real numbers and rational constants.
/// 3. Real transcendental constants ([ConstantNumber.e], [ConstantNumber.pi]) and real constant expressions.
/// 4. Imaginary terms containing the imaginary unit `i`.
int termTier(Expr expr) {
  if (expr.freeVariables.isNotEmpty) return 1;
  if (expr is RationalNumber || expr is RealNumber) return 2;
  if (expr is ComplexNumber && expr.imaginary == 0.0) return 2;
  if (containsImaginaryUnit(expr)) return 4;
  return 3;
}

/// Tests whether [expr] contains the imaginary unit [ComplexNumber.i].
bool containsImaginaryUnit(Expr expr) => switch (expr) {
  ComplexNumber(:final imaginary) => imaginary != 0.0,
  ConstantNumber(:final name) => name == 'i',
  UnaryExpr(:final expr) => containsImaginaryUnit(expr),
  BinaryExpr(:final left, :final right) =>
    containsImaginaryUnit(left) || containsImaginaryUnit(right),
  _ => false,
};

/// Compares two additive terms [baseA] with [coeffA] and [baseB] with [coeffB]
/// for canonical term ordering.
///
/// Terms are ordered by:
/// 1. Term tier via [termTier] (variable terms first, rational constants,
///    real transcendental constants, and imaginary terms containing `i` strictly at the end).
/// 2. Descending [termDegree] (higher-degree terms appear first).
/// 3. Positive coefficients before negative coefficients.
/// 4. Primary variable symbol name alphabetically.
/// 5. Structural comparison ([compareStructural]) for tie-breaking.
int compareTerms(Expr baseA, Fraction coeffA, Expr baseB, Fraction coeffB) {
  final tierA = termTier(baseA);
  final tierB = termTier(baseB);
  if (tierA != tierB) {
    return tierA.compareTo(tierB);
  }
  final degA = termDegree(baseA);
  final degB = termDegree(baseB);
  if (degA != degB) {
    return degB.compareTo(degA); // Descending degree
  }
  final signA = coeffA > Fraction.zero ? 1 : -1;
  final signB = coeffB > Fraction.zero ? 1 : -1;
  if (signA != signB) {
    return signB.compareTo(signA); // Positive terms first
  }
  final imagA = containsImaginaryUnit(baseA);
  final imagB = containsImaginaryUnit(baseB);
  if (imagA != imagB) {
    return imagA ? 1 : -1; // Real terms before imaginary terms
  }
  final symA = primarySymbol(baseA);
  final symB = primarySymbol(baseB);
  final cmp = symA.compareTo(symB);
  if (cmp != 0) return cmp;
  if (symA.isNotEmpty) {
    final symDegA = symbolDegree(baseA, symA);
    final symDegB = symbolDegree(baseB, symB);
    if (symDegA != symDegB) {
      return symDegB.compareTo(symDegA); // Descending degree of primary symbol
    }
  }
  return compareStructural(baseA, baseB);
}

/// Computes the effective polynomial degree of [expr] with respect to a specific
/// [symbol] name.
double symbolDegree(Expr expr, String symbol) => switch (expr) {
  Variable(:final name) => name == symbol ? 1.0 : 0.0,
  Pow(
    base: Variable(:final name),
    exponent: Number(isReal: true, :final value),
  ) =>
    name == symbol ? value : 0.0,
  Pow(
    base: Variable(:final name),
    exponent: Neg(expr: Number(isReal: true, :final value)),
  ) =>
    name == symbol ? -value : 0.0,
  Mul(left: final l, right: final r) =>
    symbolDegree(l, symbol) + symbolDegree(r, symbol),
  Neg(:final expr) => symbolDegree(expr, symbol),
  _ => 0.0,
};

/// Computes the effective polynomial degree of [expr] with respect to its
/// variables.
///
/// Returns `1.0` for single variables, the exponent for power terms with
/// numeric exponents, the sum of factor degrees for multiplications, and
/// `0.0` for constants or non-polynomial sub-expressions.
double termDegree(Expr expr) => switch (expr) {
  Variable() => 1.0,
  Pow(base: Variable(), exponent: Number(isReal: true, :final value)) => value,
  Pow(
    base: Variable(),
    exponent: Neg(expr: Number(isReal: true, :final value)),
  ) =>
    -value,
  Mul(left: final l, right: final r) => termDegree(l) + termDegree(r),
  Neg(:final expr) => termDegree(expr),
  Number() => 0.0,
  _ => 0.0,
};

/// Extracts the primary variable or constant name from [expr] for alphabetical
/// sorting.
String primarySymbol(Expr expr) => switch (expr) {
  Variable(:final name) => name,
  ConstantNumber(:final name) => name,
  Pow(base: final b) => primarySymbol(b),
  Neg(:final expr) => primarySymbol(expr),
  UnaryExpr(:final expr) => primarySymbol(expr),
  BinaryExpr(:final left, :final right) => switch (primarySymbol(left)) {
    '' => primarySymbol(right),
    final s => s,
  },
  _ => '',
};

/// Defines a strict total ordering between two arbitrary expressions [a] and [b].
///
/// Invariants:
/// - Reflexivity: `compareStructural(a, a) == 0`.
/// - Antisymmetry: `compareStructural(a, b) == -compareStructural(b, a)`.
/// - Transitivity: if `compareStructural(a, b) < 0` and
///   `compareStructural(b, c) < 0`, then `compareStructural(a, c) < 0`.
///
/// ```dart
/// final x = Variable('x');
/// final cmp = compareStructural(const RationalNumber(1), x);
/// ```
int compareStructural(Expr a, Expr b) {
  if (identical(a, b)) return 0;
  final tagA = nodeTag(a);
  final tagB = nodeTag(b);
  if (tagA != tagB) return tagA.compareTo(tagB);

  return switch (a) {
    RationalNumber() => compareRational(a, b as RationalNumber),
    RealNumber(:final value) => value.compareTo((b as RealNumber).value),
    ComplexNumber(:final real, :final imaginary) => switch (real.compareTo(
      (b as ComplexNumber).real,
    )) {
      0 => imaginary.compareTo(b.imaginary),
      final cmp => cmp,
    },
    ConstantNumber(:final name) => switch (name.compareTo(
      (b as ConstantNumber).name,
    )) {
      0 => (a.isReal && b.isReal) ? a.value.compareTo(b.value) : 0,
      final cmp => cmp,
    },
    Variable(:final name) => name.compareTo((b as Variable).name),
    LambertW(:final expr, :final branch) => switch (branch.compareTo(
      (b as LambertW).branch,
    )) {
      0 => compareStructural(expr, b.expr),
      final cmp => cmp,
    },
    Piecewise(:final branches, :final otherwise) => () {
      final bPiece = b as Piecewise;
      final lenCmp = branches.length.compareTo(bPiece.branches.length);
      if (lenCmp != 0) return lenCmp;
      for (var i = 0; i < branches.length; i++) {
        final condCmp = compareStructural(
          branches[i].$1,
          bPiece.branches[i].$1,
        );
        if (condCmp != 0) return condCmp;
        final exprCmp = compareStructural(
          branches[i].$2,
          bPiece.branches[i].$2,
        );
        if (exprCmp != 0) return exprCmp;
      }
      if (otherwise == null && bPiece.otherwise == null) return 0;
      if (otherwise == null) return -1;
      if (bPiece.otherwise == null) return 1;
      return compareStructural(otherwise, bPiece.otherwise!);
    }(),
    UnaryExpr(:final expr) => compareStructural(expr, (b as UnaryExpr).expr),
    BinaryExpr(:final left, :final right) => switch (compareStructural(
      left,
      (b as BinaryExpr).left,
    )) {
      0 => compareStructural(right, b.right),
      final cmp => cmp,
    },
    OrderTerm(:final variable, :final order, :final point) => switch (variable
        .compareTo((b as OrderTerm).variable)) {
      0 => switch (order.compareTo(b.order)) {
        0 => compareStructural(point, b.point),
        final cmp => cmp,
      },
      final cmp => cmp,
    },
  };
}

/// Compares two [RationalNumber] instances by cross-multiplication.
int compareRational(RationalNumber a, RationalNumber b) {
  if (a.numerator == b.numerator && a.denominator == b.denominator) {
    return 0;
  }
  final cmp = (BigInt.from(a.numerator) * BigInt.from(b.denominator)).compareTo(
    BigInt.from(b.numerator) * BigInt.from(a.denominator),
  );
  if (cmp != 0) return cmp;
  return a.denominator.compareTo(b.denominator);
}

/// Maps an [Expr] node to a fixed canonical integer tag representing its AST
/// class.
int nodeTag(Expr expr) => switch (expr) {
  RationalNumber() => 0,
  RealNumber() => 1,
  ComplexNumber() => 18,
  ConstantNumber() => 2,
  Variable() => 3,
  Neg() => 4,
  Cos() => 5,
  Exp() => 6,
  Ln() => 7,
  Sin() => 8,
  Tan() => 9,
  Asin() => 10,
  Acos() => 11,
  Atan() => 12,
  Sinh() => 13,
  Cosh() => 14,
  Tanh() => 15,
  Abs() => 16,
  LambertW() => 17,
  Erf() => 19,
  Pow() => 20,
  Mul() => 21,
  Div() => 22,
  Add() => 23,
  Sub() => 24,
  OrderTerm() => 25,
  Erfc() => 26,
  Gamma() => 27,
  Beta() => 28,
  Asinh() => 29,
  Acosh() => 30,
  Atanh() => 31,
  LessThan() => 32,
  LessEqual() => 33,
  GreaterThan() => 34,
  GreaterEqual() => 35,
  Equal() => 36,
  Piecewise() => 37,
};
