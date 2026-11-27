part of '../ast.dart';

/// Dense identifier enum for all built-in mathematical functions, discrete
/// operations, structural tuples, and symbolic uninterpreted calls.
enum FunctionId {
  // Trigonometric & inverse trigonometric
  cos,
  ln,
  sin,
  tan,
  asin,
  acos,
  atan,
  atan2,

  // Hyperbolic & inverse hyperbolic
  sinh,
  cosh,
  tanh,
  asinh,
  acosh,
  atanh,

  // Elementary
  abs,

  // Complex projections
  re,
  im,
  arg,
  conj,

  // Discrete & combinatorics
  factorial,
  binomial,
  floor,
  ceil,
  round,
  sign,
  mod,
  min,
  max,
  gcd,
  lcm,
  tuple,

  // Error, Fresnel, and integral functions
  erf,
  erfc,
  erfi,
  fresnelS,
  fresnelC,
  ei,
  expIntegralE,
  li,
  si,
  ci,
  shi,
  chi,

  // Gamma, Beta, Zeta, and Polylogarithm families
  gamma,
  upperGamma,
  lowerGamma,
  logGamma,
  digamma,
  polygamma,
  zeta,
  beta,
  polylog,

  // Bessel functions
  besselJ,
  besselY,
  besselI,
  besselK,

  // Elliptic integrals
  ellipticK,
  ellipticE,
  ellipticF,
  ellipticPi,

  // Hypergeometric & Appell families
  hypergeometric,
  appellF1,

  // Lambert W
  lambertW,

  // Arbitrary uninterpreted symbolic function `f(x_1, ..., x_n)`
  symbolic,
}

/// High-level mathematical category for a [FunctionSpec].
enum FunctionCategory {
  elementary,
  trig,
  hyperbolic,
  complex,
  number,
  special,
  structural,
  symbolic,
}

/// Parity symmetry of a univariate mathematical function.
enum FunctionParity { none, even, odd }

/// Callback evaluating a unary function in real arithmetic.
typedef RealUnaryEval = double Function(double x);

/// Callback evaluating a unary function in complex arithmetic.
typedef ComplexUnaryEval = Complex Function(Complex z);

/// Callback evaluating a binary function in real arithmetic.
typedef RealBinaryEval = double Function(double a, double b);

/// Callback evaluating a binary function in complex arithmetic.
typedef ComplexBinaryEval = Complex Function(Complex a, Complex b);

/// Callback evaluating a ternary function in real arithmetic.
typedef RealTernaryEval = double Function(double a, double b, double c);

/// Callback evaluating a ternary function in complex arithmetic.
typedef ComplexTernaryEval = Complex Function(Complex a, Complex b, Complex c);

/// Callback evaluating an n-ary function in real arithmetic.
typedef RealVariadicEval = double Function(List<double> args);

/// Callback evaluating an n-ary function in complex arithmetic.
typedef ComplexVariadicEval = Complex Function(List<Complex> args);

/// Callback computing the derivative of a [Call] with arguments [args] with
/// respect to [variable], given recursive differentiation [diff] and
/// optional domain context [isComplexVar].
typedef FunctionDerivativeRule = Expr? Function(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
});

/// Callback formatting a child [expr] into text with precedence [parentPrec].
typedef TextChildFormatter = String Function(
  Expr expr,
  int parentPrec,
  int decimalPlaces,
);

/// Callback formatting a child [expr] into LaTeX or MathML.
typedef RichChildFormatter = String Function(Expr expr, int decimalPlaces);

/// Custom plain-text formatter for a [FunctionSpec].
typedef FunctionTextFormatter = String Function(
  List<Expr> args,
  int decimalPlaces,
  TextChildFormatter formatChild,
);

/// Custom LaTeX formatter for a [FunctionSpec].
typedef FunctionLatexFormatter = String Function(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
);

/// Custom MathML formatter for a [FunctionSpec].
typedef FunctionMathMlFormatter = String Function(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
);

/// Descriptor and callable constructor for a symbolic or built-in function.
sealed class FunctionSpec {
  /// Base const constructor for function descriptors.
  const new({
    required this.id,
    required this.name,
    required this.params,
    required this.doc,
    this.category = FunctionCategory.elementary,
    this.parity = FunctionParity.none,
    this.minArity = 1,
    this.maxArity = 1,
    this.latexName,
    this.mathMlName,
    this.derivativeRule,
    this.customText,
    this.customLatex,
    this.customMathMl,
  });

  /// Creates an uninterpreted symbolic function descriptor `name(args...)`.
  const factory symbolic(String name) = SymbolicFunctionSpec;

  /// Dense built-in function identifier (or [FunctionId.symbolic]).
  final FunctionId id;

  /// Canonical textual function name.
  final String name;

  /// Parameter signature labels for documentation and autocomplete hints.
  final List<String> params;

  /// Concise mathematical description.
  final String doc;

  /// Category for UI grouping and simplification guards.
  final FunctionCategory category;

  /// Even/odd parity symmetry for unary functions.
  final FunctionParity parity;

  /// Minimum positional argument count.
  final int minArity;

  /// Maximum positional argument count (`-1` for unbounded variadic).
  final int maxArity;

  /// Optional LaTeX operator template prefix.
  final String? latexName;

  /// Optional MathML `<mi>` identifier text (defaults to [name]).
  final String? mathMlName;

  /// Exact symbolic differentiation rule (`null` falls back to unevaluated
  /// [Derivative]).
  final FunctionDerivativeRule? derivativeRule;

  /// Optional custom plain-text formatter.
  final FunctionTextFormatter? customText;

  /// Optional custom LaTeX formatter.
  final FunctionLatexFormatter? customLatex;

  /// Optional custom MathML formatter.
  final FunctionMathMlFormatter? customMathMl;

  /// Whether this function belongs to special, discrete, or uninterpreted
  /// classes rather than elementary analytic functions.
  bool get isSpecial =>
      category == FunctionCategory.special ||
      category == FunctionCategory.number ||
      category == FunctionCategory.symbolic;

  /// Evaluates this function in real arithmetic on scalar [args].
  double evaluateReal(List<double> args);

  /// Evaluates this function in complex arithmetic on scalar [args].
  Complex evaluateComplex(List<Complex> args);

  /// Validates [args] arity and constructs a [Call] node.
  Call buildCall(List<Expr> args) {
    if (args.length < minArity || (maxArity >= 0 && args.length > maxArity)) {
      throw ArgumentError(
        '$name requires '
        '${maxArity < 0 ? 'at least $minArity' : (minArity == maxArity ? '$minArity' : '$minArity..$maxArity')} '
        'argument(s), got ${args.length}',
      );
    }
    return Call(this, args);
  }

  /// Formats a [Call] with [args] to plain text.
  String formatText(
    List<Expr> args,
    int decimalPlaces,
    TextChildFormatter formatChild,
  ) {
    if (customText case final custom?) {
      return custom(args, decimalPlaces, formatChild);
    }
    return '$name(${args.map((a) => formatChild(a, 0, decimalPlaces)).join(', ')})';
  }

  /// Formats a [Call] with [args] to LaTeX.
  String formatLatex(
    List<Expr> args,
    int decimalPlaces,
    RichChildFormatter formatChild,
    RichChildFormatter formatPowBase,
  ) {
    if (customLatex case final custom?) {
      return custom(args, decimalPlaces, formatChild, formatPowBase);
    }
    final op = latexName ?? '\\operatorname{$name}';
    return '$op(${args.map((a) => formatChild(a, decimalPlaces)).join(', ')})';
  }

  /// Formats a [Call] with [args] to MathML.
  String formatMathMl(
    List<Expr> args,
    int decimalPlaces,
    RichChildFormatter formatChild,
    RichChildFormatter formatPowBase,
  ) {
    if (customMathMl case final custom?) {
      return custom(args, decimalPlaces, formatChild, formatPowBase);
    }
    final mi = mathMlName ?? name;
    final joined = args
        .map((a) => formatChild(a, decimalPlaces))
        .join('<mo>,</mo>');
    return '<mrow><mi>$mi</mi><mo>(</mo>$joined<mo>)</mo></mrow>';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FunctionSpec && id == other.id && name == other.name);

  @override
  int get hashCode => Object.hash(id, name);
}

/// Callable 1-argument built-in function descriptor.
final class UnaryFunctionSpec extends FunctionSpec {
  /// Creates a unary [FunctionSpec].
  const new({
    required super.id,
    required super.name,
    required super.params,
    required super.doc,
    super.category,
    super.parity,
    super.latexName,
    super.mathMlName,
    required this.evalReal,
    required this.evalComplex,
    super.derivativeRule,
    super.customText,
    super.customLatex,
    super.customMathMl,
  }) : super(minArity: 1, maxArity: 1);

  /// Real-valued scalar evaluator.
  final RealUnaryEval evalReal;

  /// Complex-valued scalar evaluator.
  final ComplexUnaryEval evalComplex;

  /// Constructs `Call(this, [arg])`.
  Call call(Expr arg) => Call(this, [arg]);

  @override
  double evaluateReal(List<double> args) => evalReal(args[0]);

  @override
  Complex evaluateComplex(List<Complex> args) => evalComplex(args[0]);
}

/// Callable 2-argument built-in function descriptor.
final class BinaryFunctionSpec extends FunctionSpec {
  /// Creates a binary [FunctionSpec].
  const new({
    required super.id,
    required super.name,
    required super.params,
    required super.doc,
    super.category,
    super.latexName,
    super.mathMlName,
    required this.evalReal,
    required this.evalComplex,
    super.derivativeRule,
    super.customText,
    super.customLatex,
    super.customMathMl,
  }) : super(minArity: 2, maxArity: 2);

  /// Real-valued scalar evaluator.
  final RealBinaryEval evalReal;

  /// Complex-valued scalar evaluator.
  final ComplexBinaryEval evalComplex;

  /// Constructs `Call(this, [left, right])`.
  Call call(Expr left, Expr right) => Call(this, [left, right]);

  @override
  double evaluateReal(List<double> args) => evalReal(args[0], args[1]);

  @override
  Complex evaluateComplex(List<Complex> args) => evalComplex(args[0], args[1]);
}

/// Callable 1-or-2-argument built-in function descriptor (such as `zeta`,
/// `ellipticE`, `lambertW`).
final class OptionalBinaryFunctionSpec extends FunctionSpec {
  /// Creates a 1-or-2-argument [FunctionSpec].
  const new({
    required super.id,
    required super.name,
    required super.params,
    required super.doc,
    super.category,
    super.parity,
    super.latexName,
    super.mathMlName,
    required this.evalReal,
    required this.evalComplex,
    super.derivativeRule,
    super.customText,
    super.customLatex,
    super.customMathMl,
  }) : super(minArity: 1, maxArity: 2);

  /// Real-valued scalar evaluator.
  final RealVariadicEval evalReal;

  /// Complex-valued scalar evaluator.
  final ComplexVariadicEval evalComplex;

  /// Constructs `Call(this, [first])` or `Call(this, [first, second])`.
  Call call(Expr first, [Expr? second]) =>
      second == null ? Call(this, [first]) : Call(this, [first, second]);

  @override
  double evaluateReal(List<double> args) => evalReal(args);

  @override
  Complex evaluateComplex(List<Complex> args) => evalComplex(args);
}

/// Callable 3-argument built-in function descriptor (such as `ellipticPi`,
/// `hypergeometric`).
final class TernaryFunctionSpec extends FunctionSpec {
  /// Creates a 3-argument [FunctionSpec].
  const new({
    required super.id,
    required super.name,
    required super.params,
    required super.doc,
    super.category,
    super.latexName,
    super.mathMlName,
    required this.evalReal,
    required this.evalComplex,
    super.derivativeRule,
    super.customText,
    super.customLatex,
    super.customMathMl,
  }) : super(minArity: 3, maxArity: 3);

  /// Real-valued scalar evaluator.
  final RealTernaryEval evalReal;

  /// Complex-valued scalar evaluator.
  final ComplexTernaryEval evalComplex;

  /// Constructs `Call(this, [a, b, c])`.
  Call call(Expr a, Expr b, Expr c) => Call(this, [a, b, c]);

  @override
  double evaluateReal(List<double> args) => evalReal(args[0], args[1], args[2]);

  @override
  Complex evaluateComplex(List<Complex> args) =>
      evalComplex(args[0], args[1], args[2]);
}

/// Callable variadic built-in function descriptor.
final class VariadicFunctionSpec extends FunctionSpec {
  /// Creates a variadic [FunctionSpec].
  const new({
    required super.id,
    required super.name,
    required super.params,
    required super.doc,
    super.category,
    super.parity,
    super.minArity = 0,
    super.maxArity = -1,
    super.latexName,
    super.mathMlName,
    required this.evalReal,
    required this.evalComplex,
    super.derivativeRule,
    super.customText,
    super.customLatex,
    super.customMathMl,
  });

  /// Real-valued n-ary evaluator.
  final RealVariadicEval evalReal;

  /// Complex-valued n-ary evaluator.
  final ComplexVariadicEval evalComplex;

  /// Constructs `Call(this, args)` validating arity.
  Call call(List<Expr> args) => buildCall(args);

  @override
  double evaluateReal(List<double> args) => evalReal(args);

  @override
  Complex evaluateComplex(List<Complex> args) => evalComplex(args);
}

/// Uninterpreted symbolic function descriptor `name(args...)`.
final class SymbolicFunctionSpec extends FunctionSpec {
  /// Creates an uninterpreted symbolic function descriptor with [name].
  const new(String name)
    : super(
        id: FunctionId.symbolic,
        name: name,
        params: const ['...'],
        doc: 'Symbolic function',
        category: FunctionCategory.symbolic,
        minArity: 0,
        maxArity: -1,
      );

  /// Constructs `Call(this, args)`.
  Call call(List<Expr> args) => Call(this, args);

  @override
  double evaluateReal(List<double> args) =>
      throw UnsupportedError('Cannot numerically evaluate symbolic $name');

  @override
  Complex evaluateComplex(List<Complex> args) =>
      throw UnsupportedError('Cannot numerically evaluate symbolic $name');

  @override
  String formatLatex(
    List<Expr> args,
    int decimalPlaces,
    RichChildFormatter formatChild,
    RichChildFormatter formatPowBase,
  ) {
    final escaped = name.replaceAll('_', r'\_');
    final op = escaped.length == 1 ? escaped : '\\operatorname{$escaped}';
    return '$op(${args.map((a) => formatChild(a, decimalPlaces)).join(', ')})';
  }
}
