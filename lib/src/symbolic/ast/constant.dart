part of '../ast.dart';

/// Named mathematical constant (such as $\pi$, $e$, $\infty$, or `undefined`).
///
/// Named constants are opaque symbolic entities during algebraic manipulation
/// (they do not fold into floating-point approximations during simplification),
/// while providing their numerical [value] during evaluation or compilation.
final class Constant extends Expr {
  /// Creates a named mathematical constant with [name] and numerical [value].
  const new(this.name, this.value, {String? latex, String? mathMl})
    : latex = latex ?? name,
      mathMl = mathMl ?? '<mi>$name</mi>';

  /// Archimedes' constant $\pi \approx 3.141592653589793$.
  static const pi = Constant(
    'pi',
    Complex(math.pi),
    latex: r'\pi',
    mathMl: '<mi>π</mi>',
  );

  /// Euler's number $e \approx 2.718281828459045$.
  static const e = Constant('e', Complex(math.e));

  /// Positive infinity $+\infty$.
  static const infinity = Constant(
    'infinity',
    Complex(double.infinity),
    latex: r'\infty',
    mathMl: '<mi>∞</mi>',
  );

  /// Indeterminate / undefined mathematical result (such as $0 / 0$ or $\infty - \infty$).
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
  bool get isSimplified => true;

  /// Whether this constant is strictly real-valued ($\Im(\text{value}) = 0$).
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
