import '../ast.dart';
import '../number/integer.dart';

/// Strips a leading negative sign from [term] for subtraction reconstruction in
/// additive sums (`a + (-b) -> a - b`), returning the positive remainder or
/// `null` if [term] does not start with a negative factor.
Expr? stripLeadingNegative(Expr term) => switch (term) {
  final RealNumeric n when n.isNegative => n.neg(),
  ComplexNumber(real: RealNumeric(isZero: true), :final imaginary)
      when imaginary.isNegative =>
    ComplexNumber.of(IntegerNumber.zero, imaginary.neg()),
  Mul(factors: [final RealNumeric first, ...final rest])
      when first.isNegative =>
    switch ((first.neg(), rest)) {
      (RealNumeric(isOne: true), [final single]) => single,
      (RealNumeric(isOne: true), _) => Mul(rest),
      (final posFirst, _) => Mul([posFirst, ...rest]),
    },
  Mul(
    factors: [
      ComplexNumber(real: RealNumeric(isZero: true), :final imaginary),
      ...final rest,
    ],
  )
      when imaginary.isNegative =>
    Mul([ComplexNumber.of(IntegerNumber.zero, imaginary.neg()), ...rest]),
  _ => null,
};

/// Partitions multiplicative [factors] into an overall sign flag, numerator
/// factors, and denominator factors for 2D fraction formatting (`\frac`, `<mfrac>`).
({bool isNegative, List<Expr> numerator, List<Expr> denominator})
partitionMulFraction(List<Expr> factors) {
  var isNegative = false;
  final numFactors = <Expr>[];
  final denFactors = <Expr>[];

  for (final f in factors) {
    switch (f) {
      case FractionNumber(
        isNegative: final fracNeg,
        :final numerator,
        :final denominator,
      ):
        if (fracNeg) {
          isNegative = !isNegative;
        }
        final absNum = numerator.abs();
        if (!absNum.isOne) {
          numFactors.add(IntegerNumber(absNum));
        }
        denFactors.add(IntegerNumber(denominator));
      case Pow(:final base, exponent: final IntegerNumber exp)
          when exp.isNegative:
        denFactors.add(exp.isNegativeOne ? base : Pow(base, exp.neg()));
      default:
        numFactors.add(f);
    }
  }

  if (denFactors.isNotEmpty) {
    if (numFactors case [final RealNumeric first, ...] when first.isNegative) {
      isNegative = !isNegative;
      final posFirst = first.neg();
      if (posFirst.isOne) {
        numFactors.removeAt(0);
      } else {
        numFactors[0] = posFirst;
      }
    }
  }

  return (
    isNegative: isNegative,
    numerator: numFactors,
    denominator: denFactors,
  );
}

/// Matches positive integer powers ($k \ge 2$) of standard elementary functions
/// ($\sin^k(x)$, $\cos^k(x)$, $\tan^k(x)$, $\sinh^k(x)$, $\cosh^k(x)$, $\tanh^k(x)$, $\ln^k(x)$).
({String name, String latexCmd, Expr argument})? matchFunctionPower(
  Expr base,
  Expr exponent,
) {
  if (exponent is! IntegerNumber || exponent.value < Integer.two) {
    return null;
  }
  return switch (base) {
    Sin(:final expr) => (name: 'sin', latexCmd: r'\sin', argument: expr),
    Cos(:final expr) => (name: 'cos', latexCmd: r'\cos', argument: expr),
    Tan(:final expr) => (name: 'tan', latexCmd: r'\tan', argument: expr),
    Sinh(:final expr) => (name: 'sinh', latexCmd: r'\sinh', argument: expr),
    Cosh(:final expr) => (name: 'cosh', latexCmd: r'\cosh', argument: expr),
    Tanh(:final expr) => (name: 'tanh', latexCmd: r'\tanh', argument: expr),
    Ln(:final expr) => (name: 'ln', latexCmd: r'\ln', argument: expr),
    _ => null,
  };
}

/// Whether the explicit multiplication dot (`\cdot`, `&#x22c5;`) can be omitted
/// in favor of a thin space between adjacent factors [left] and [right].
bool canOmitMulDot(Expr left, Expr right) {
  final r = leftmostMulFactor(right);
  if (startsWithNegative(r)) return false;
  if (!needsMulRightParens(right) && startsWithNumber(r)) return false;
  if (r is Pow && r.exponent == IntegerNumber.negativeOne) return false;
  return true;
}

/// Whether [expr] begins with a negative sign when formatted.
bool startsWithNegative(Expr expr) => switch (expr) {
  RealNumeric(:final isNegative) => isNegative,
  ComplexNumber(:final real, :final imaginary) =>
    real.isZero ? imaginary.isNegative : real.isNegative,
  Mul(factors: [final first, ...]) => startsWithNegative(first),
  _ => false,
};

/// Whether [expr] begins with a numeric digit when formatted.
bool startsWithNumber(Expr expr) => switch (expr) {
  RealNumeric() => true,
  ComplexNumber(:final real, :final imaginary) =>
    !real.isZero || !imaginary.isOne,
  Pow(:final base, :final exponent) =>
    base != Constant.e &&
        !(exponent is RationalNumber &&
            exponent.numerator == Integer.one &&
            exponent.denominator >= Integer.two) &&
        startsWithNumber(base),
  _ => false,
};

/// Returns the leftmost leaf factor of a product [expr].
Expr leftmostMulFactor(Expr expr) => switch (expr) {
  Mul(factors: [final first, ...]) => leftmostMulFactor(first),
  _ => expr,
};

/// Whether [right] requires parentheses when appearing after a binary `-` sign.
bool needsSubRightParens(Expr right) => switch (right) {
  Add() || Mod() || RelationalExpr() => true,
  ComplexNumber(:final real) when !real.isZero => true,
  _ when startsWithNegative(right) => true,
  _ => false,
};

/// Whether [left] requires parentheses as the first factor of a product.
bool needsMulLeftParens(Expr left) => switch (left) {
  Add() || Mod() || RelationalExpr() => true,
  ComplexNumber(:final real) when !real.isZero => true,
  _ => false,
};

/// Whether [right] requires parentheses as a subsequent factor of a product.
bool needsMulRightParens(Expr right) => switch (right) {
  Add() || Mod() || RelationalExpr() => true,
  ComplexNumber(:final real) when !real.isZero => true,
  _ when startsWithNegative(right) => true,
  _ => false,
};

/// Whether [base] requires parentheses when raised to an exponent.
bool needsPowBaseParens(Expr base) => switch (base) {
  Add() ||
  Mul() ||
  Mod() ||
  RelationalExpr() ||
  FractionNumber() ||
  RealNumeric(isNegative: true) => true,
  ComplexNumber(:final real, :final imaginary)
      when !real.isZero || !imaginary.isOne =>
    true,
  Pow(:final exponent) when exponent == IntegerNumber.negativeOne => true,
  _ => false,
};

/// Whether [expr] requires parentheses when preceded by a unary `-` sign.
bool needsNegOperandParens(Expr expr) => switch (expr) {
  Add() || Mod() || RelationalExpr() => true,
  ComplexNumber(:final real) when !real.isZero => true,
  _ when startsWithNegative(expr) => true,
  _ => false,
};

/// Formats a finite floating-point [value] to [decimalPlaces], trimming
/// redundant trailing zeros while preserving at least one decimal digit for
/// integer-valued doubles (e.g. `2.0`).
String formatDouble(double value, int decimalPlaces) {
  final fixed = value.toStringAsFixed(decimalPlaces);
  if (fixed.contains('.')) {
    var end = fixed.length;
    while (end > 0 && fixed[end - 1] == '0') {
      end--;
    }
    if (end > 0 && fixed[end - 1] == '.') {
      final withZero = '${fixed.substring(0, end)}0';
      return withZero == '-0.0' ? '0.0' : withZero;
    }
    final trimmed = fixed.substring(0, end);
    return trimmed == '-0.0' ? '0.0' : trimmed;
  }
  return fixed == '-0' ? '0' : fixed;
}
