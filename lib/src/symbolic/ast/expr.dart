part of '../ast.dart';

/// Mathematical constant $\pi \approx 3.141592653589793$ as a symbolic [Expr].
const pi = ConstantNumber.pi;

/// Mathematical constant $e \approx 2.718281828459045$ as a symbolic [Expr].
const e = ConstantNumber.e;

/// Imaginary unit constant $i = \sqrt{-1}$ as a symbolic [Expr].
const i = ConstantNumber.i;

/// Sealed base class representing an algebraic expression abstract syntax tree
/// (AST) node.
///
/// In algebra and calculus, an expression combines constants, variables,
/// operators, and mathematical functions (such as $2x + 1$ or $\sin(x)$).
/// Expressions can be constructed and evaluated numerically for specific
/// variable assignments, or manipulated symbolically for exact differentiation,
/// indefinite integration, equation solving, simplification, and JIT
/// compilation.
///
/// ```dart
/// final x = Variable('x');
/// final expr = x * x + x * 2 + 1;
/// final val = expr.evaluate({'x': 3.0}); // 3^2 + 2(3) + 1 = 16.0
/// ```
sealed class Expr {
  /// Abstract const constructor for expression nodes.
  const new();

  /// Parses a mathematical expression from [input] into an [Expr] tree.
  ///
  /// Supports numbers (integers, floating-point, scientific notation), mathematical
  /// constants ([pi], [e], [i]), variables, basic arithmetic (`+`, `-`, `*`, `/`, `^`),
  /// unary operators (`+`, `-`), functions ([Sin], [Cos], [Exp], [Ln], `log`, `sqrt`, `pow`, `root`),
  /// and parentheses.
  ///
  /// Throws a [FormatException] if [input] cannot be parsed.
  ///
  /// ```dart
  /// final f = Expr.parse('sin(pi * x) + 2 * x');
  /// print(f.evaluate({'x': 0.5}));
  /// ```
  static Expr parse(String input) => parseExpression(input);

  /// Tries to parse a mathematical expression from [input], returning `null` on
  /// syntax error.
  ///
  /// ```dart
  /// final expr = Expr.tryParse('2 * x + 1');
  /// ```
  static Expr? tryParse(String input) => tryParseExpression(input);

  /// Whether this expression depends on [name].
  bool dependsOn(String name);

  /// Populates [target] with all unique variable names appearing in this expression.
  void collectFreeVariables(Set<String> target);

  /// All unique variable names appearing in this expression.
  Set<String> get freeVariables {
    final result = <String>{};
    collectFreeVariables(result);
    return result;
  }

  ///Substitutes occurrences of [variable] with [replacement].
  Expr substitute(String variable, Expr replacement);

  /// Applies [transform] to all direct child expressions of this node, returning
  /// `this` when all children remain identical.
  Expr mapChildren(Expr Function(Expr child) transform) => this;

  /// Returns `true` if [predicate] holds for this expression or any of its
  /// descendant expressions.
  bool anyNode(bool Function(Expr node) predicate) => predicate(this);

  /// Evaluates this expression using the variable values in [context].
  double evaluate(Map<String, double> context);

  /// Evaluates this expression using complex variable assignments in [context].
  ///
  /// Supports full complex evaluation across all arithmetic, power,
  /// trigonometric, hyperbolic, exponential, logarithmic, and absolute value nodes.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final expr = x * x + 1;
  /// final result = expr.evaluateComplex({'x': Complex(0, 1)}); // 0.0
  /// ```
  Complex evaluateComplex([Map<String, Complex> context = const {}]) =>
      _evaluateComplex(this, context);

  /// Returns a copy of this expression with all asymptotic [OrderTerm] nodes removed.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final series = 1 + x + OrderTerm('x', 2);
  /// final poly = series.removeOrder(); // 1 + x
  /// ```
  Expr removeOrder() => _removeOrder(this);

  /// Adds this expression to [other].
  Expr operator +(Object other) => Add(this, _wrap(other));

  /// Subtracts [other] from this expression.
  Expr operator -(Object other) => Sub(this, _wrap(other));

  /// Multiplies this expression by [other].
  Expr operator *(Object other) => Mul(this, _wrap(other));

  /// Divides this expression by [other].
  Expr operator /(Object other) => Div(this, _wrap(other));

  /// Negates this expression.
  Expr operator -() => Neg(this);

  /// Raises this expression to the power of [exponent].
  Expr pow(Object exponent) => Pow(this, _wrap(exponent));

  @override
  String toString() => formatExpr(this);

  static Expr _wrap(Object value) {
    if (value is Expr) return value;
    if (value is int) return RationalNumber(value);
    if (value is Fraction) return RationalNumber.fraction(value);
    if (value is Complex) {
      if (value.b == 0) return _wrap(value.a);
      final imPart = value.b == 1
          ? ConstantNumber.i
          : value.b == -1
          ? const Neg(ConstantNumber.i)
          : Mul(_wrap(value.b), ConstantNumber.i);
      if (value.a == 0) return imPart;
      return Add(_wrap(value.a), imPart);
    }
    if (value is num) return RealNumber(value.toDouble());
    throw ArgumentError.value(
      value,
      'value',
      'Cannot convert to symbolic Expr',
    );
  }
}
