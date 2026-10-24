part of '../ast.dart';

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
      (syntax ?? ExprSyntax.standard).parse(input);

  /// Attempts to parse an algebraic expression from [input], returning `null`
  /// if parsing fails.
  static Expr? tryParse(String input, {ExprSyntax? syntax}) =>
      (syntax ?? ExprSyntax.standard).tryParse(input);

  /// Converts [value] into a symbolic [Expr].
  ///
  /// Accepts an existing [Expr], machine `int`, [BigInt], [Integer],
  /// [Fraction], IEEE-754 `double`, [Complex], or [String] (variable name or expression).
  ///
  /// Throws an [ArgumentError] if [value] cannot be converted to an [Expr].
  factory wrap(Object? value) =>
      Expr.tryWrap(value) ??
      (throw ArgumentError.value(
        value,
        'value',
        'Cannot convert to symbolic expression',
      ));

  /// Converts [value] into a symbolic [Expr], or returns `null` if [value]
  /// cannot be converted.
  ///
  /// Accepts an existing [Expr], machine `int`, [BigInt], [Integer],
  /// [Fraction], IEEE-754 `double`, [Complex], or [String] (variable name or expression).
  static Expr? tryWrap(Object? value) {
    if (value is Expr) return value;
    if (value is int && value.isFinite) {
      return IntegerNumber(Integer.from(value));
    }
    if (value is BigInt) {
      return IntegerNumber(Integer.big(value));
    }
    if (value is Fraction) {
      return RationalNumber.fromFraction(value);
    }
    if (value is double) {
      return RealNumber.fromDouble(value);
    }
    if (value is int) {
      return RealNumber.fromDouble(value.toDouble());
    }
    if (value is Complex) {
      final a = value.a;
      final b = value.b;
      if (b == 0) {
        return a.isFinite ? _wrapNum(a) : RealNumber.fromDouble(a.toDouble());
      }
      final real = a.isFinite
          ? _wrapNum(a)
          : RealNumber.fromDouble(a.toDouble());
      final imag = b.isFinite
          ? _wrapNum(b)
          : RealNumber.fromDouble(b.toDouble());
      if (real is RealNumeric && imag is RealNumeric) {
        return ComplexNumber.of(real, imag);
      }
      if (imag is Number && imag.isZero) return real;
      return real + imag * ComplexNumber.i;
    }
    if (value is String) {
      return Expr.tryParse(value);
    }
    return null;
  }

  /// Whether this expression node is already in canonical simplified form.
  bool get isSimplified;

  /// Returns the set of all free variable names appearing in this expression.
  ///
  /// Accumulates variables in a single shared [Set] in $O(N)$ time without
  /// allocating intermediate sets at each interior node.
  Set<String> get freeVariables {
    final result = <String>{};
    _collectFreeVariables(result);
    return result;
  }

  void _collectFreeVariables(Set<String> target) {}

  /// Whether this expression contains [variable] as a free variable.
  bool dependsOn(String variable) => false;

  /// Whether this expression is real-valued when all free variables are real.
  bool get isReal => _isRealSubtree(this);

  /// Returns a new expression with every occurrence of [variable] replaced by [replacement].
  Expr substitute(String variable, Expr replacement) => this;

  /// Applies [transform] to all direct child [Expr] nodes of this expression,
  /// returning a reconstructed node of the same type, or `this` for leaf nodes.
  Expr mapChildren(Expr Function(Expr) transform) => this;

  /// Returns `true` if [predicate] holds for this node or any descendant node
  /// in this expression subtree.
  bool anyNode(bool Function(Expr) predicate) => predicate(this);

  /// Symbolic addition: `this + other`.
  ///
  /// Accepts an [Expr], `num` (`int` or `double`), [BigInt], [Integer],
  /// [Complex], or `String` (variable name). Flattens unsimplified [Add]
  /// operands in exact input order.
  Expr operator +(Object other) {
    final rhs = Expr.wrap(other);
    if ((this, rhs) case (
      final RealNumeric real,
      ComplexNumber(real: IntegerNumber(isZero: true), :final imaginary),
    )) {
      return ComplexNumber.of(real, imaginary);
    }
    return Add([
      if (this case Add(:final terms, isSimplified: false)) ...terms else this,
      if (rhs case Add(:final terms, isSimplified: false)) ...terms else rhs,
    ]);
  }

  /// Symbolic subtraction: `this - other`, represented as `this + (-other)`.
  ///
  /// Accepts an [Expr], `num` (`int` or `double`), [BigInt], [Integer],
  /// [Complex], or `String` (variable name).
  Expr operator -(Object other) => this + (-Expr.wrap(other));

  /// Symbolic multiplication: `this * other`.
  ///
  /// Accepts an [Expr], `num` (`int` or `double`), [BigInt], [Integer],
  /// [Complex], or `String` (variable name). Flattens unsimplified [Mul]
  /// operands in exact input order.
  Expr operator *(Object other) {
    final rhs = Expr.wrap(other);
    if ((this, rhs) case (
      final RealNumeric scale,
      ComplexNumber(real: IntegerNumber(isZero: true), :final imaginary),
    )) {
      if (scale.mul(imaginary) case final RealNumeric prod) {
        return ComplexNumber.of(IntegerNumber.zero, prod);
      }
    }
    final isRhsUnaryNeg = switch (rhs) {
      Mul(factors: [IntegerNumber.negativeOne, _]) => true,
      _ => false,
    };
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
    final rhs = Expr.wrap(other);
    if ((this, rhs) case (final RationalNumber a, final RationalNumber b)
        when !b.isZero) {
      return a.divRational(b);
    }
    if (this is IntegerNumber && (this as IntegerNumber).isOne) {
      return Pow(rhs, IntegerNumber.negativeOne);
    }
    return this * Pow(rhs, IntegerNumber.negativeOne);
  }

  /// Symbolic unary negation: `-this`.
  Expr operator -() => switch (this) {
    final Number n => n.neg(),
    Mul(factors: [final Number n, ...final rest]) => switch (n.neg()) {
      Number(isOne: true) => switch (rest) {
        [final single] => single,
        _ => Mul(rest),
      },
      final negFirst => Mul([negFirst, ...rest]),
    },
    Mul(factors: final factors && [_, ...]) => Mul([
      IntegerNumber.negativeOne,
      ...factors,
    ]),
    _ => Mul([IntegerNumber.negativeOne, this]),
  };

  /// Symbolic exponentiation: $\text{this}^{\text{exponent}}$.
  ///
  /// Accepts an [Expr], `num` (`int` or `double`), [BigInt], [Integer],
  /// [Complex], or `String` (variable name).
  Expr pow(Object exponent) => Pow(this, Expr.wrap(exponent));

  @override
  String toString() => format();

  static Expr _wrapNum(num value) {
    if (!value.isFinite) {
      return RealNumber.fromDouble(value.toDouble());
    }
    if (value is int) {
      return IntegerNumber(Integer.from(value));
    }
    if (value == value.truncateToDouble() && value.abs() < 9007199254740992.0) {
      return IntegerNumber(Integer.from(value.toInt()));
    }
    return RealNumber.fromDouble(value.toDouble());
  }

  static bool _isRealSubtree(Expr node) => switch (node) {
    ComplexNumber(:final imaginary) => imaginary.isZero,
    Constant(:final value) => value.b == 0.0 || value.isNaN,
    Abs() || Re() || Im() || Arg() => true,
    RealNumeric() || Variable() || OrderTerm() => true,
    Add(:final terms) => terms.every(_isRealSubtree),
    Mul(:final factors) => factors.every(_isRealSubtree),
    Pow(:final base, :final exponent) =>
      _isRealSubtree(base) &&
          (exponent is IntegerNumber ||
              (base is RealNumeric && !base.isNegative) ||
              base is Abs),
    Ln(:final expr) =>
      _isRealSubtree(expr) &&
          !(expr is RealNumeric && (expr.isNegative || expr.isZero)),
    Asin(:final expr) || Acos(:final expr) =>
      _isRealSubtree(expr) &&
          !(expr is RealNumeric && expr.toDouble().abs() > 1.0),
    Acosh(:final expr) =>
      _isRealSubtree(expr) && !(expr is RealNumeric && expr.toDouble() < 1.0),
    Atanh(:final expr) =>
      _isRealSubtree(expr) &&
          !(expr is RealNumeric && expr.toDouble().abs() >= 1.0),
    BinaryExpr(:final left, :final right) =>
      _isRealSubtree(left) && _isRealSubtree(right),
    UnaryExpr(:final expr) => _isRealSubtree(expr),
    Piecewise(:final branches, :final otherwise) =>
      branches.every(
            (b) => _isRealSubtree(b.relation) && _isRealSubtree(b.expr),
          ) &&
          (otherwise == null || _isRealSubtree(otherwise)),
    Integral(:final integrand, :final lower, :final upper) =>
      _isRealSubtree(integrand) &&
          (lower == null || _isRealSubtree(lower)) &&
          (upper == null || _isRealSubtree(upper)),
    Derivative(:final expr, :final point) =>
      _isRealSubtree(expr) && (point == null || _isRealSubtree(point)),
    Limit(:final expr, :final point) =>
      _isRealSubtree(expr) && _isRealSubtree(point),
    Sum(:final expr, :final lower, :final upper) ||
    Product(
      :final expr,
      :final lower,
      :final upper,
    ) => _isRealSubtree(expr) && _isRealSubtree(lower) && _isRealSubtree(upper),
    VariableFunction(:final arguments) => arguments.every(_isRealSubtree),
  };
}

String _freshBoundVariable(String base, Set<String> used) {
  var candidate = '${base}_1';
  var counter = 1;
  while (used.contains(candidate)) {
    counter++;
    candidate = '${base}_$counter';
  }
  return candidate;
}
