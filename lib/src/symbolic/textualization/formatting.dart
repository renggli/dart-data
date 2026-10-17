import '../ast.dart';

/// Strips a leading negative sign from [term] for subtraction reconstruction in
/// additive sums (`a + (-b) -> a - b`), returning the positive remainder or
/// `null` if [term] does not start with a negative factor.
Expr? stripLeadingNegative(Expr term) {
  if (term is RealNumeric && term.isNegative) {
    return term.neg();
  }
  if (term is ComplexNumber && term.real.isZero && term.imaginary.isNegative) {
    return ComplexNumber.of(IntegerNumber.zero, term.imaginary.neg());
  }
  if (term is Mul && term.factors.isNotEmpty) {
    final first = term.factors.first;
    if (first is RealNumeric && first.isNegative) {
      final posFirst = first.neg();
      if (posFirst.isOne) {
        return term.factors.length == 2
            ? term.factors[1]
            : Mul(term.factors.sublist(1));
      }
      return Mul([posFirst, ...term.factors.skip(1)]);
    }
    if (first is ComplexNumber &&
        first.real.isZero &&
        first.imaginary.isNegative) {
      final posFirst = ComplexNumber.of(
        IntegerNumber.zero,
        first.imaginary.neg(),
      );
      return Mul([posFirst, ...term.factors.skip(1)]);
    }
  }
  return null;
}

/// Partitions multiplicative [factors] into an overall sign flag, numerator
/// factors, and denominator factors for 2D fraction formatting (`\frac`, `<mfrac>`).
({bool isNegative, List<Expr> numerator, List<Expr> denominator})
partitionMulFraction(List<Expr> factors) {
  var isNegative = false;
  final numFactors = <Expr>[];
  final denFactors = <Expr>[];

  for (final f in factors) {
    if (f is FractionNumber) {
      if (f.isNegative) {
        isNegative = !isNegative;
      }
      final absNum = f.numerator.abs();
      if (!absNum.isOne) {
        numFactors.add(IntegerNumber(absNum));
      }
      denFactors.add(IntegerNumber(f.denominator));
      continue;
    }
    if (f is Pow && f.exponent is IntegerNumber) {
      final exp = f.exponent as IntegerNumber;
      if (exp.isNegative) {
        denFactors.add(exp.isNegativeOne ? f.base : Pow(f.base, exp.neg()));
        continue;
      }
    }
    numFactors.add(f);
  }

  if (denFactors.isNotEmpty &&
      numFactors.isNotEmpty &&
      numFactors.first is RealNumeric &&
      (numFactors.first as RealNumeric).isNegative) {
    isNegative = !isNegative;
    final posFirst = (numFactors.first as RealNumeric).neg();
    if (posFirst.isOne) {
      numFactors.removeAt(0);
    } else {
      numFactors[0] = posFirst;
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
  Mul(:final factors) when factors.isNotEmpty => startsWithNegative(
    factors.first,
  ),
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
Expr leftmostMulFactor(Expr expr) => expr is Mul && expr.factors.isNotEmpty
    ? leftmostMulFactor(expr.factors.first)
    : expr;

/// Whether [right] requires parentheses when appearing after a binary `-` sign.
bool needsSubRightParens(Expr right) => switch (right) {
  Add() => true,
  ComplexNumber(:final real) when !real.isZero => true,
  _ when startsWithNegative(right) => true,
  _ => false,
};

/// Whether [left] requires parentheses as the first factor of a product.
bool needsMulLeftParens(Expr left) => switch (left) {
  Add() => true,
  ComplexNumber(:final real) when !real.isZero => true,
  _ => false,
};

/// Whether [right] requires parentheses as a subsequent factor of a product.
bool needsMulRightParens(Expr right) => switch (right) {
  Add() => true,
  ComplexNumber(:final real) when !real.isZero => true,
  _ when startsWithNegative(right) => true,
  _ => false,
};

/// Whether [base] requires parentheses when raised to an exponent.
bool needsPowBaseParens(Expr base) => switch (base) {
  Add() || Mul() || FractionNumber() || RealNumeric(isNegative: true) => true,
  ComplexNumber(:final real, :final imaginary)
      when !real.isZero || !imaginary.isOne =>
    true,
  Pow(:final exponent) when exponent == IntegerNumber.negativeOne => true,
  _ => false,
};

/// Whether [expr] requires parentheses when preceded by a unary `-` sign.
bool needsNegOperandParens(Expr expr) => switch (expr) {
  Add() => true,
  ComplexNumber(:final real) when !real.isZero => true,
  _ when startsWithNegative(expr) => true,
  _ => false,
};
