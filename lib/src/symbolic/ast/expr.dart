part of '../ast.dart';

/// Bitmask flags packed onto every [Expr] node for O(1) structural queries.
const int kFlagHasVariable = 1 << 0;
const int kFlagHasReal = 1 << 1;
const int kFlagHasComplex = 1 << 2;
const int kFlagHasSpecial = 1 << 3;
const int kFlagHasBinder = 1 << 4;
const int kFlagHasOrder = 1 << 5;
const int kFlagHasRelational = 1 << 6;

/// Root of the symbolic expression Abstract Syntax Tree (AST).
///
/// All mathematical expressions are represented as immutable trees of [Expr]
/// nodes. Arithmetic nodes ([Add], [Mul], [Pow]) canonicalize immediately on
/// construction.
sealed class Expr {
  /// Base const constructor for all AST nodes.
  const new();

  /// Parses an algebraic expression from [input] string.
  ///
  /// Throws a [FormatException] if [input] is not a valid mathematical
  /// expression.
  factory parse(String input, {ExprSyntax? syntax}) =>
      (syntax ?? ExprSyntax.standard).parse(input);

  /// Attempts to parse an algebraic expression from [input], returning `null`
  /// if parsing fails.
  static Expr? tryParse(String input, {ExprSyntax? syntax}) =>
      (syntax ?? ExprSyntax.standard).tryParse(input);

  /// Converts [value] into a symbolic [Expr].
  ///
  /// Accepts an existing [Expr], machine `int`, [BigInt], [Fraction], IEEE-754
  /// `double`, [Complex], or [String] (expression to parse).
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
  static Expr? tryWrap(Object? value) {
    if (value is Expr) return value;
    if (value is int && value.isFinite) {
      return IntegerNumber.of(value);
    }
    if (value is BigInt) {
      return IntegerNumber(value);
    }
    if (value is Fraction) {
      return RationalNumber.fromFraction(value);
    }
    if (value is double) {
      return RealNumber.fromDouble(value);
    }
    if (value is Complex) {
      final a = value.a;
      final b = value.b;
      if (a.isNaN || b.isNaN) return Constant.undefined;
      if (b == 0 && b is int) {
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

  /// Packed structural bitmask (`kFlag*` constants).
  int get flags;

  /// Total AST node count in this subtree.
  int get nodeCount;

  /// Deterministic structural category tag used by [compareStructural].
  int get structuralTag;

  /// Whether this subtree contains any symbolic [Variable] node.
  bool get hasVariable => (flags & kFlagHasVariable) != 0;

  /// Whether this subtree contains any IEEE-754 floating-point [RealNumber].
  bool get hasReal => (flags & kFlagHasReal) != 0;

  /// Whether this subtree contains any non-real [ComplexNumber].
  bool get hasComplex => (flags & kFlagHasComplex) != 0;

  /// Whether this subtree contains any non-elementary/special/discrete [Call].
  bool get hasSpecial => (flags & kFlagHasSpecial) != 0;

  /// Whether this subtree contains any [BinderExpr].
  bool get hasBinder => (flags & kFlagHasBinder) != 0;

  /// Whether this subtree contains any [OrderTerm].
  bool get hasOrder => (flags & kFlagHasOrder) != 0;

  /// Whether this subtree contains any [Relational] or [Piecewise].
  bool get hasRelational => (flags & kFlagHasRelational) != 0;

  /// Returns the set of all free variable names appearing in this expression.
  Set<String> get freeVariables => const {};

  /// Whether this expression contains [variable] as a free variable.
  bool dependsOn(String variable) =>
      hasVariable && freeVariables.contains(variable);

  /// Whether this expression is real-valued when all free variables are real.
  bool get isReal => _isRealSubtree(this);

  /// Returns a new expression with every occurrence of [variable] replaced by
  /// [replacement].
  Expr substitute(String variable, Expr replacement) => dependsOn(variable)
      ? mapChildren((c) => c.substitute(variable, replacement))
      : this;

  /// Applies [transform] to all direct child [Expr] nodes of this expression,
  /// returning a reconstructed canonical node, or `this` for leaf nodes.
  Expr mapChildren(Expr Function(Expr) transform) => this;

  /// Returns `true` if [predicate] holds for this node or any descendant node
  /// in this expression subtree.
  bool anyNode(bool Function(Expr) predicate) => predicate(this);

  /// Canonical symbolic addition: `this + other`.
  Expr operator +(Object other) => Add.of([this, Expr.wrap(other)]);

  /// Canonical symbolic subtraction: `this - other`.
  Expr operator -(Object other) => Add.of([this, -Expr.wrap(other)]);

  /// Canonical symbolic multiplication: `this * other`.
  Expr operator *(Object other) => Mul.of([this, Expr.wrap(other)]);

  /// Canonical symbolic division: `this / other`.
  Expr operator /(Object other) {
    final rhs = Expr.wrap(other);
    if (this case final RationalNumber a) {
      if (rhs case final RationalNumber b when !b.isZero) {
        return a.divRational(b);
      }
    }
    if (this case final ComplexNumber a) {
      if (rhs case final RealNumeric b when !b.isZero) return a.div(b);
      if (rhs case final ComplexNumber b when !b.isZero) return a.div(b);
    }
    if (this case final RealNumeric a) {
      if (rhs case final ComplexNumber b when !b.isZero) return a.div(b);
    }
    return Mul.of([this, Pow.of(rhs, IntegerNumber.negativeOne)]);
  }

  /// Canonical symbolic unary negation: `-this`.
  Expr operator -() => switch (this) {
    final Number n => n.neg(),
    Add(:final terms) => Add.of([for (final t in terms) -t]),
    Mul(:final factors) => Mul.of([IntegerNumber.negativeOne, ...factors]),
    _ => Mul._([IntegerNumber.negativeOne, this]),
  };

  /// Canonical symbolic exponentiation: `this^exponent`.
  Expr pow(Object exponent) => Pow.of(this, Expr.wrap(exponent));

  @override
  String toString() => format();

  static Expr _wrapNum(num value) => value is int
      ? IntegerNumber.of(value)
      : RealNumber.fromDouble(value.toDouble());

  static bool _isRealBoundOrPoint(Expr node) =>
      node == Constant.infinity ||
      node == -Constant.infinity ||
      _isRealSubtree(node);

  static bool _isRealSubtree(Expr node) => switch (node) {
    ComplexNumber(:final imaginary) => imaginary.isZero,
    Constant(:final isReal) => isReal,
    RealNumeric() || Variable() || OrderTerm() => true,
    Add(:final terms) => !node.hasComplex || terms.every(_isRealSubtree),
    Mul(:final factors) => !node.hasComplex || factors.every(_isRealSubtree),
    Pow(:final base, :final exponent) =>
      _isRealSubtree(base) &&
          _isRealSubtree(exponent) &&
          (exponent is IntegerNumber ||
              (base is RealNumeric && !base.isNegative) ||
              (base is Constant && base.isReal && base.value.a > 0.0) ||
              base is Call && base.id == FunctionId.abs),
    Call(:final id, :final args) => switch (id) {
      FunctionId.abs ||
      FunctionId.re ||
      FunctionId.im ||
      FunctionId.arg => !node.anyNode((n) => n == Constant.undefined),
      FunctionId.ln || FunctionId.li || FunctionId.ci || FunctionId.chi =>
        _isRealSubtree(args[0]) &&
            !(args[0] is RealNumeric &&
                ((args[0] as RealNumeric).isNegative ||
                    (args[0] as RealNumeric).isZero)) &&
            !(args[0] is Constant &&
                ((args[0] as Constant).value.b != 0.0 ||
                    (args[0] as Constant).value.a <= 0.0)),
      FunctionId.asin || FunctionId.acos =>
        _isRealSubtree(args[0]) &&
            !(args[0] is RealNumeric &&
                (args[0] as RealNumeric).toDouble().abs() > 1.0) &&
            !(args[0] is Constant &&
                ((args[0] as Constant).value.b != 0.0 ||
                    (args[0] as Constant).value.a.abs() > 1.0)),
      FunctionId.acosh =>
        _isRealSubtree(args[0]) &&
            !(args[0] is RealNumeric &&
                (args[0] as RealNumeric).toDouble() < 1.0) &&
            !(args[0] is Constant &&
                ((args[0] as Constant).value.b != 0.0 ||
                    (args[0] as Constant).value.a < 1.0)),
      FunctionId.atanh =>
        _isRealSubtree(args[0]) &&
            !(args[0] is RealNumeric &&
                (args[0] as RealNumeric).toDouble().abs() >= 1.0) &&
            !(args[0] is Constant &&
                ((args[0] as Constant).value.b != 0.0 ||
                    (args[0] as Constant).value.a.abs() >= 1.0)),
      FunctionId.lambertW => _isLambertWReal(args),
      FunctionId.polylog =>
        _isRealSubtree(args[0]) &&
            _isRealSubtree(args[1]) &&
            !(args[1] is RealNumeric &&
                (args[1] as RealNumeric).toDouble() > 1.0) &&
            !(args[1] is Constant &&
                ((args[1] as Constant).value.b != 0.0 ||
                    (args[1] as Constant).value.a > 1.0)),
      _ => args.every(_isRealSubtree),
    },
    Relational(:final left, :final right) =>
      _isRealSubtree(left) && _isRealSubtree(right),
    Piecewise(:final branches, :final otherwise) =>
      branches.every(
            (b) => _isRealSubtree(b.relation) && _isRealSubtree(b.expr),
          ) &&
          (otherwise == null || _isRealSubtree(otherwise)),
    Integral(:final integrand, :final lower, :final upper) =>
      _isRealSubtree(integrand) &&
          (lower == null || _isRealBoundOrPoint(lower)) &&
          (upper == null || _isRealBoundOrPoint(upper)),
    Derivative(:final expr, :final point) =>
      _isRealSubtree(expr) && (point == null || _isRealBoundOrPoint(point)),
    Limit(:final expr, :final point) =>
      _isRealSubtree(expr) && _isRealBoundOrPoint(point),
    Sum(:final expr, :final lower, :final upper) ||
    Product(:final expr, :final lower, :final upper) =>
      _isRealSubtree(expr) &&
          _isRealBoundOrPoint(lower) &&
          _isRealBoundOrPoint(upper),
    RootSum(:final polynomial, :final body) =>
      _isRealSubtree(polynomial) && _isRealSubtree(body),
  };

  static bool _isLambertWReal(List<Expr> args) {
    final arg = args[0];
    if (!_isRealSubtree(arg)) return false;
    final branch = args.length > 1 && args[1] is IntegerNumber
        ? (args[1] as IntegerNumber).asInt
        : 0;
    return switch (branch) {
      0 =>
        !(arg is RealNumeric && arg.toDouble() < -1.0 / math.e) &&
            !(arg is Constant &&
                (arg.value.b != 0.0 || arg.value.a < -1.0 / math.e)),
      -1 =>
        !(arg is RealNumeric &&
                (arg.toDouble() < -1.0 / math.e || arg.toDouble() >= 0.0)) &&
            !(arg is Constant &&
                (arg.value.b != 0.0 ||
                    arg.value.a < -1.0 / math.e ||
                    arg.value.a >= 0.0)),
      _ => false,
    };
  }
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
