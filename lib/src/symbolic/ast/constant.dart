part of '../ast.dart';

/// Named mathematical constant (such as `pi`, `e`, `infinity`, or `undefined`).
///
/// Named constants are opaque symbolic entities during algebraic manipulation,
/// providing their numerical [value] during evaluation or approximation.
final class Constant extends Expr {
  /// Creates a named mathematical constant with [name] and numerical [value].
  const new(this.name, this.value, {String? latex, String? mathMl})
    : latex = latex ?? name,
      mathMl = mathMl ?? '<mi>$name</mi>';

  /// Archimedes' constant `pi ≈ 3.141592653589793`.
  static const pi = Constant(
    'pi',
    Complex(math.pi),
    latex: r'\pi',
    mathMl: '<mi>π</mi>',
  );

  /// Euler's number `e ≈ 2.718281828459045`.
  static const e = Constant('e', Complex(math.e));

  /// Positive infinity `+infinity`.
  static const infinity = Constant(
    'infinity',
    Complex(double.infinity),
    latex: r'\infty',
    mathMl: '<mi>∞</mi>',
  );

  /// Indeterminate / undefined mathematical result (e.g. `0 / 0`, `oo - oo`).
  static const undefined = Constant(
    'undefined',
    Complex.nan,
    latex: r'\text{undefined}',
    mathMl: '<mtext>undefined</mtext>',
  );

  /// Symbolic identifier of the constant.
  final String name;

  /// Numerical value of the constant.
  final Complex value;

  /// LaTeX representation of this constant.
  final String latex;

  /// MathML representation of this constant.
  final String mathMl;

  @override
  int get flags =>
      ((!value.isNaN && value.b != 0.0) ? kFlagHasComplex : 0) |
      kFlagSimplified;

  @override
  int get nodeCount => 1;

  @override
  int get structuralTag => 1;

  /// Whether this constant is strictly real-valued (`Im(value) = 0`).
  @override
  bool get isReal => !value.isNaN && !value.isInfinite && value.b == 0.0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Constant &&
          name == other.name &&
          (value == other.value || (value.isNaN && other.value.isNaN)) &&
          latex == other.latex &&
          mathMl == other.mathMl);

  @override
  int get hashCode =>
      Object.hash(Constant, name, value.isNaN ? 0 : value, latex, mathMl);
}
