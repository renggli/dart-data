part of '../ast.dart';

/// Top-level convenience constant for the imaginary unit $i = \sqrt{-1}$.
///
/// Alias for [ComplexNumber.i].
///
/// ```dart
/// final z = const Variable('x') + 2 * i;
/// ```
const i = ComplexNumber.i;

/// Root of the symbolic expression Abstract Syntax Tree (AST).
///
/// All mathematical expressions are represented as immutable trees of [Expr]
/// nodes. Expressions can be constructed programmatically using constructors
/// and overloaded arithmetic operators (`+`, `-`, `*`, `/`, `pow`), or parsed
/// from mathematical strings via [Expr.parse].
sealed class Expr {
  /// Base const constructor for all AST nodes.
  const new();

  /// Parses an algebraic expression from [input] string.
  ///
  /// Throws a [FormatException] if [input] is not a valid mathematical expression.
  factory parse(String input, {ExprSyntax? syntax}) =>
      Parser.parse(input, syntax: syntax);

  /// Attempts to parse an algebraic expression from [input], returning `null`
  /// if parsing fails.
  static Expr? tryParse(String input, {ExprSyntax? syntax}) =>
      Parser.tryParse(input, syntax: syntax);

  /// Whether this expression node is already in canonical simplified form.
  bool get isSimplified => false;

  /// Evaluates this expression to a `double` given variable bindings in [context].
  ///
  /// Throws an [ArgumentError] if any free variable in this expression is missing
  /// from [context].
  double evaluate([Map<String, double> context = const {}]);

  /// Returns the set of all free variable names appearing in this expression.
  ///
  /// Accumulates variables in a single shared [Set] via [collectFreeVariables]
  /// in $O(N)$ time without allocating intermediate sets at each interior node.
  Set<String> get freeVariables {
    final result = <String>{};
    collectFreeVariables(result);
    return result;
  }

  /// Accumulates all free variable names appearing in this subtree into [target].
  void collectFreeVariables(Set<String> target);

  /// Whether this expression contains [variable] as a free variable.
  bool dependsOn(String variable);

  /// Whether this expression is real-valued (contains no complex numbers with
  /// non-zero imaginary parts).
  bool get isReal =>
      !anyNode((node) => node is ComplexNumber && !node.imaginary.isZero);

  /// Returns a new expression with every occurrence of [variable] replaced by [replacement].
  Expr substitute(String variable, Expr replacement);

  /// Applies [transform] to all direct child [Expr] nodes of this expression,
  /// returning a reconstructed node of the same type, or `this` for leaf nodes.
  Expr mapChildren(Expr Function(Expr) transform);

  /// Returns `true` if [predicate] holds for this node or any descendant node
  /// in this expression subtree.
  bool anyNode(bool Function(Expr) predicate);

  /// Symbolic addition: `this + other`.
  ///
  /// Accepts an [Expr], `num` (`int` or `double`), [BigInt], [Integer],
  /// [Complex], or `String` (variable name). Flattens unsimplified [Add]
  /// operands in exact input order.
  Expr operator +(Object other) {
    final rhs = _wrap(other);
    return Add([
      if (this case Add(:final terms, isSimplified: false)) ...terms else this,
      if (rhs case Add(:final terms, isSimplified: false)) ...terms else rhs,
    ]);
  }

  /// Symbolic subtraction: `this - other`, represented as `this + (-other)`.
  ///
  /// Accepts an [Expr], `num` (`int` or `double`), [BigInt], [Integer],
  /// [Complex], or `String` (variable name).
  Expr operator -(Object other) => this + (-_wrap(other));

  /// Symbolic multiplication: `this * other`.
  ///
  /// Accepts an [Expr], `num` (`int` or `double`), [BigInt], [Integer],
  /// [Complex], or `String` (variable name). Flattens unsimplified [Mul]
  /// operands in exact input order.
  Expr operator *(Object other) {
    final rhs = _wrap(other);
    final isRhsUnaryNeg =
        rhs is Mul &&
        rhs.factors.length == 2 &&
        rhs.factors.first == IntegerNumber.negativeOne;
    return Mul([
      if (this case Mul(:final factors, isSimplified: false))
        ...factors
      else
        this,
      if (rhs case Mul(:final factors, isSimplified: false) when !isRhsUnaryNeg)
        ...factors
      else
        rhs,
    ]);
  }

  /// Symbolic division: `this / other`.
  ///
  /// When both operands are exact [RationalNumber]s and the divisor is
  /// non-zero, returns the reduced [RationalNumber] quotient directly;
  /// otherwise returns `this * Pow(other, -1)`.
  Expr operator /(Object other) {
    final rhs = _wrap(other);
    if (this is RationalNumber && rhs is RationalNumber && !rhs.isZero) {
      return (this as RationalNumber).divRational(rhs);
    }
    return this * Pow(rhs, IntegerNumber.negativeOne);
  }

  /// Symbolic unary negation: `-this`.
  Expr operator -() {
    if (this is Number) {
      return (this as Number).neg();
    }
    if (this case Mul(:final factors) when factors.isNotEmpty) {
      if (factors.first case final Number n) {
        final negFirst = n.neg();
        if (negFirst.isOne) {
          return factors.length == 2 ? factors[1] : Mul(factors.sublist(1));
        }
        return Mul([negFirst, ...factors.skip(1)]);
      }
      return Mul([IntegerNumber.negativeOne, ...factors]);
    }
    return Mul([IntegerNumber.negativeOne, this]);
  }

  /// Symbolic exponentiation: $\text{this}^{\text{exponent}}$.
  ///
  /// Accepts an [Expr], `num` (`int` or `double`), [BigInt], [Integer],
  /// [Complex], or `String` (variable name).
  Expr pow(Object exponent) => Pow(this, _wrap(exponent));

  @override
  String toString() => formatExpr(this);

  static Expr _wrap(Object value) => switch (value) {
    Expr() => value,
    int() => IntegerNumber(Integer.from(value)),
    BigInt() => IntegerNumber(Integer.big(value)),
    double() => RealNumber.fromDouble(value),
    Complex(:final a, :final b) => _wrapComplex(a, b),
    String() => Variable(value),
    _ => throw ArgumentError.value(
      value,
      'value',
      'Cannot convert to symbolic expression',
    ),
  };

  static Expr _wrapComplex(num a, num b) {
    final real = _wrapNum(a);
    final imag = _wrapNum(b);
    if (real is RealNumeric && imag is RealNumeric) {
      return ComplexNumber.of(real, imag);
    }
    if (imag is Number && imag.isZero) {
      return real;
    }
    return real + imag * ComplexNumber.i;
  }

  static Expr _wrapNum(num value) {
    if (value is int) {
      return IntegerNumber(Integer(value));
    }
    if (value == value.truncateToDouble() &&
        value.isFinite &&
        value.abs() < 9007199254740992.0) {
      return IntegerNumber(Integer(value.toInt()));
    }
    return RealNumber.fromDouble(value.toDouble());
  }
}
