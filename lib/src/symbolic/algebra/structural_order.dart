import 'package:more/number.dart' show Fraction;

import '../ast.dart';

/// Compares two additive terms [baseA] with [coeffA] and [baseB] with [coeffB]
/// for canonical term ordering.
///
/// Terms are ordered by:
/// 1. Descending [termDegree] (higher-degree terms appear first).
/// 2. Positive coefficients before negative coefficients.
/// 3. Primary variable symbol name alphabetically.
/// 4. Structural comparison ([compareStructural]) for tie-breaking.
int compareTerms(Expr baseA, Fraction coeffA, Expr baseB, Fraction coeffB) {
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
int compareStructural(Expr a, Expr b) {
  if (identical(a, b)) return 0;
  final tagA = nodeTag(a);
  final tagB = nodeTag(b);
  if (tagA != tagB) return tagA.compareTo(tagB);

  return switch (a) {
    RationalNumber() => compareRational(a, b as RationalNumber),
    RealNumber(:final value) => value.compareTo((b as RealNumber).value),
    ConstantNumber(:final name) => switch (name.compareTo(
      (b as ConstantNumber).name,
    )) {
      0 => (a.isReal && b.isReal) ? a.value.compareTo(b.value) : 0,
      final cmp => cmp,
    },
    ComplexNumber(:final complex) => switch (complex.a.compareTo(
      (b as ComplexNumber).complex.a,
    )) {
      0 => complex.b.compareTo(b.complex.b),
      final cmp => cmp,
    },
    Variable(:final name) => name.compareTo((b as Variable).name),
    UnaryExpr(:final expr) => compareStructural(expr, (b as UnaryExpr).expr),
    BinaryExpr(:final left, :final right) => switch (compareStructural(
      left,
      (b as BinaryExpr).left,
    )) {
      0 => compareStructural(right, b.right),
      final cmp => cmp,
    },
  };
}

/// Compares two [RationalNumber] instances by cross-multiplication.
int compareRational(RationalNumber a, RationalNumber b) {
  if (a.numerator == b.numerator && a.denominator == b.denominator) {
    return 0;
  }
  final delta = a.numerator * b.denominator - b.numerator * a.denominator;
  if (delta < 0) return -1;
  if (delta > 0) return 1;
  return a.denominator.compareTo(b.denominator);
}

/// Maps an [Expr] node to a fixed canonical integer tag representing its AST
/// class.
int nodeTag(Expr expr) => switch (expr) {
  RationalNumber() => 0,
  RealNumber() => 1,
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
  Log() => 18,
  Pow() => 20,
  Mul() => 21,
  Div() => 22,
  Add() => 23,
  Sub() => 24,
  ComplexNumber() => 25,
};
