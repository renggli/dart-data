import 'dart:math' as math;

import 'package:more/math.dart';
import 'package:more/number.dart' show Complex;

import '../../special/binomial.dart' as special_binomial;
import '../../special/factorial.dart' as special_factorial;
import '../../special/gamma.dart' as special_gamma;
import '../ast.dart';
import 'special_specs.dart';

/// Computes `(ln|Gamma(z)|, sgn Gamma(z))` for real [z].
({double logAbs, int sign}) logAbsGammaWithSign(double z) {
  if (!z.isFinite) {
    return z == double.infinity
        ? (logAbs: double.infinity, sign: 1)
        : (logAbs: double.nan, sign: 0);
  }
  if (z <= 0.0 && z == z.roundToDouble()) {
    return (logAbs: double.infinity, sign: 0);
  }
  if (z > 0.0) {
    return (logAbs: special_gamma.gammaLn(z), sign: 1);
  }
  final r = z - 2.0 * (z / 2.0).roundToDouble();
  final s = math.sin(math.pi * r);
  if (s == 0.0) return (logAbs: double.infinity, sign: 0);
  final logAbs =
      math.log(math.pi) - math.log(s.abs()) - special_gamma.gammaLn(1.0 - z);
  return (logAbs: logAbs, sign: s > 0.0 ? 1 : -1);
}

/// Computes `(ln|C(n, k)|, sgn C(n, k))` for real [n] and [k].
({double logAbs, int sign}) logAbsBinomialWithSign(double n, double k) {
  if (!n.isFinite || !k.isFinite) return (logAbs: double.nan, sign: 0);
  if (k == k.roundToDouble() && k < 0.0) {
    return (logAbs: double.negativeInfinity, sign: 0);
  }
  if (n == n.roundToDouble() && k == k.roundToDouble() && n >= 0.0 && k > n) {
    return (logAbs: double.negativeInfinity, sign: 0);
  }
  if (k == 0.0) return (logAbs: 0.0, sign: 1);
  if (n >= 0.0 && k >= 0.0 && k <= n) {
    return (logAbs: special_binomial.binomialLn(n, k), sign: 1);
  }
  if (n <= -1.0 && k == k.roundToDouble() && k >= 0.0) {
    final logAbs = special_binomial.binomialLn(-n + k - 1.0, k);
    final isOdd = (k - 2.0 * (k / 2.0).floorToDouble()) != 0.0;
    return (logAbs: logAbs, sign: isOdd ? -1 : 1);
  }
  final numG = logAbsGammaWithSign(n + 1.0);
  final den1G = logAbsGammaWithSign(k + 1.0);
  final den2G = logAbsGammaWithSign(n - k + 1.0);
  if (numG.logAbs.isNaN || den1G.logAbs.isNaN || den2G.logAbs.isNaN) {
    return (logAbs: double.nan, sign: 0);
  }
  if (numG.sign == 0) return (logAbs: double.nan, sign: 0);
  if (den1G.sign == 0 || den2G.sign == 0) {
    return (logAbs: double.negativeInfinity, sign: 0);
  }
  return (
    logAbs: numG.logAbs - den1G.logAbs - den2G.logAbs,
    sign: numG.sign * den1G.sign * den2G.sign,
  );
}

/// Evaluates `binomial(n, k)` in real arithmetic including negative [n].
double evalRealBinomial(double n, double k) {
  if (!n.isFinite || !k.isFinite) return double.nan;
  if (k == k.roundToDouble() && k < 0.0) return 0.0;
  if (n == n.roundToDouble() && k == k.roundToDouble() && n >= 0.0 && k > n) {
    return 0.0;
  }
  if (k == 0.0) return 1.0;
  if (n >= 0.0 && k >= 0.0 && k <= n) {
    return special_binomial.binomial(n, k);
  }
  if (n <= -1.0 && k == k.roundToDouble() && k >= 0.0) {
    final absVal = special_binomial.binomial(-n + k - 1.0, k);
    final isOdd = (k - 2.0 * (k / 2.0).floorToDouble()) != 0.0;
    return isOdd ? -absVal : absVal;
  }
  final (:logAbs, :sign) = logAbsBinomialWithSign(n, k);
  if (logAbs.isNaN) return double.nan;
  if (sign == 0) return 0.0;
  return sign * math.exp(logAbs);
}

/// Spec for `factorial(n)`.
const factorialSpec = UnaryFunctionSpec(
  id: FunctionId.factorial,
  name: 'factorial',
  params: ['n'],
  doc: 'Factorial n!',
  category: FunctionCategory.number,
  evalReal: _evalRealFactorial,
  evalComplex: special_factorial.factorialComplex,
  unaryDerivative: _dfFactorial,
  customText: _textFactorial,
  customLatex: _latexFactorial,
  customMathMl: _mathMlFactorial,
);

/// Spec for `binomial(n, k)`.
const binomialSpec = BinaryFunctionSpec(
  id: FunctionId.binomial,
  name: 'binomial',
  params: ['n', 'k'],
  doc: 'Binomial coefficient C(n, k)',
  category: FunctionCategory.number,
  evalReal: evalRealBinomial,
  evalComplex: special_binomial.binomialComplex,
  derivativeRule: _diffBinomial,
  customLatex: _latexBinomial,
  customMathMl: _mathMlBinomial,
);

/// Spec for `floor(x)`.
const floorSpec = UnaryFunctionSpec(
  id: FunctionId.floor,
  name: 'floor',
  doc: 'Greatest integer <= x',
  category: FunctionCategory.number,
  evalReal: _evalRealFloor,
  evalComplex: _evalComplexFloor,
  unaryDerivative: _dfZero,
  customLatex: _latexFloor,
  customMathMl: _mathMlFloor,
);

/// Spec for `ceil(x)`.
const ceilSpec = UnaryFunctionSpec(
  id: FunctionId.ceil,
  name: 'ceil',
  doc: 'Smallest integer >= x',
  category: FunctionCategory.number,
  evalReal: _evalRealCeil,
  evalComplex: _evalComplexCeil,
  unaryDerivative: _dfZero,
  customLatex: _latexCeil,
  customMathMl: _mathMlCeil,
);

/// Spec for `round(x)`.
const roundSpec = UnaryFunctionSpec(
  id: FunctionId.round,
  name: 'round',
  doc: 'Nearest integer to x',
  category: FunctionCategory.number,
  evalReal: _evalRealRound,
  evalComplex: _evalComplexRound,
  unaryDerivative: _dfZero,
);

/// Spec for `sign(x)`.
const signSpec = UnaryFunctionSpec(
  id: FunctionId.sign,
  name: 'sign',
  doc: 'Signum (-1, 0, or 1)',
  category: FunctionCategory.number,
  parity: FunctionParity.odd,
  latexName: r'\operatorname{sgn}',
  mathMlName: 'sgn',
  evalReal: _evalRealSign,
  evalComplex: _evalComplexSign,
  unaryDerivative: _dfZero,
);

/// Spec for `mod(a, b)`.
const modSpec = BinaryFunctionSpec(
  id: FunctionId.mod,
  name: 'mod',
  params: ['a', 'b'],
  doc: 'Modulo remainder a mod b',
  category: FunctionCategory.number,
  evalReal: _evalRealMod,
  evalComplex: _evalComplexMod,
  derivativeRule: _diffMod,
  customLatex: _latexMod,
  customMathMl: _mathMlMod,
);

/// Spec for `min(a_1, ..., a_n)`.
const minSpec = VariadicFunctionSpec(
  id: FunctionId.min,
  name: 'min',
  params: ['a', 'b', '...'],
  doc: 'Minimum of arguments',
  category: FunctionCategory.number,
  minArity: 1,
  latexName: r'\min',
  evalReal: _evalRealMin,
  evalComplex: _unsupportedComplexVariadic,
  derivativeRule: _diffMin,
  customLatex: _latexMin,
);

/// Spec for `max(a_1, ..., a_n)`.
const maxSpec = VariadicFunctionSpec(
  id: FunctionId.max,
  name: 'max',
  params: ['a', 'b', '...'],
  doc: 'Maximum of arguments',
  category: FunctionCategory.number,
  minArity: 1,
  latexName: r'\max',
  evalReal: _evalRealMax,
  evalComplex: _unsupportedComplexVariadic,
  derivativeRule: _diffMax,
  customLatex: _latexMax,
);

/// Spec for `gcd(a_1, ..., a_n)`.
const gcdSpec = VariadicFunctionSpec(
  id: FunctionId.gcd,
  name: 'gcd',
  params: ['a', 'b', '...'],
  doc: 'Greatest common divisor',
  category: FunctionCategory.number,
  minArity: 1,
  latexName: r'\gcd',
  evalReal: _evalRealGcd,
  evalComplex: _unsupportedComplexVariadic,
  customLatex: _latexGcd,
);

/// Spec for `lcm(a_1, ..., a_n)`.
const lcmSpec = VariadicFunctionSpec(
  id: FunctionId.lcm,
  name: 'lcm',
  params: ['a', 'b', '...'],
  doc: 'Least common multiple',
  category: FunctionCategory.number,
  minArity: 1,
  evalReal: _evalRealLcm,
  evalComplex: _unsupportedComplexVariadic,
  customLatex: _latexLcm,
);

/// Spec for `tuple(a_1, ..., a_n)`.
const tupleSpec = VariadicFunctionSpec(
  id: FunctionId.tuple,
  name: 'tuple',
  params: ['a', '...'],
  doc: 'Ordered tuple of expressions',
  category: FunctionCategory.structural,
  minArity: 0,
  evalReal: _unsupportedRealTuple,
  evalComplex: _unsupportedComplexTuple,
  derivativeRule: _diffTuple,
  customText: _textTuple,
  customLatex: _latexTuple,
  customMathMl: _mathMlTuple,
);

double _evalRealFactorial(double x) => special_gamma.gamma(x + 1.0);
double _evalRealFloor(double x) => x.isFinite ? x.floorToDouble() : x;
double _evalRealCeil(double x) => x.isFinite ? x.ceilToDouble() : x;
double _evalRealRound(double x) => x.isFinite ? x.roundToDouble() : x;
double _evalRealSign(double x) =>
    x.isNaN ? double.nan : (x == 0.0 ? 0.0 : (x > 0.0 ? 1.0 : -1.0));

double _evalRealMod(double a, double b) {
  if (a.isNaN || b.isNaN || b == 0.0 || a.isInfinite) return double.nan;
  if (b.isInfinite) return (a == 0.0 || (a > 0.0) == (b > 0.0)) ? a : b;
  return a - b * (a / b).floorToDouble();
}

double _evalRealMin(List<double> args) {
  var m = args[0];
  for (var i = 1; i < args.length; i++) {
    m = math.min(m, args[i]);
  }
  return m;
}

double _evalRealMax(List<double> args) {
  var m = args[0];
  for (var i = 1; i < args.length; i++) {
    m = math.max(m, args[i]);
  }
  return m;
}

bool _isSafeIntDouble(double v) =>
    v.isFinite && v.abs() <= 9007199254740991.0 && v == v.roundToDouble();

double _evalRealGcd(List<double> args) {
  if (!_isSafeIntDouble(args[0])) return double.nan;
  var g = args[0].round().abs();
  for (var i = 1; i < args.length; i++) {
    if (!_isSafeIntDouble(args[i])) return double.nan;
    g = g.gcd(args[i].round().abs());
  }
  return g.toDouble();
}

double _evalRealLcm(List<double> args) {
  if (!_isSafeIntDouble(args[0])) return double.nan;
  var l = args[0].round().abs();
  for (var i = 1; i < args.length; i++) {
    if (!_isSafeIntDouble(args[i])) return double.nan;
    l = l.lcm(args[i].round().abs());
  }
  return l.toDouble();
}

Complex _evalComplexRealOp(Complex z, String name, double Function(double) fn) {
  if (z.b != 0.0) {
    throw UnsupportedError('Complex $name evaluation is only supported on R');
  }
  final v = z.a.toDouble();
  return Complex(v.isFinite ? fn(v) : v);
}

Complex _evalComplexFloor(Complex z) =>
    _evalComplexRealOp(z, 'Floor', (v) => v.floorToDouble());
Complex _evalComplexCeil(Complex z) =>
    _evalComplexRealOp(z, 'Ceil', (v) => v.ceilToDouble());
Complex _evalComplexRound(Complex z) =>
    _evalComplexRealOp(z, 'Round', (v) => v.roundToDouble());

Complex _evalComplexSign(Complex z) {
  if (z == Complex.zero) return Complex.zero;
  if (z.b == 0.0) return Complex(_evalRealSign(z.a.toDouble()));
  final r = z.abs();
  return r == 0.0 || r.isNaN ? Complex.nan : z / Complex(r);
}

Complex _evalComplexMod(Complex zA, Complex zB) {
  if (zA.b != 0.0 || zB.b != 0.0) {
    throw UnsupportedError('Complex Mod evaluation is only supported on R');
  }
  return Complex(_evalRealMod(zA.a.toDouble(), zB.a.toDouble()));
}

Complex _unsupportedComplexVariadic(List<Complex> args) =>
    throw UnsupportedError(
      'Complex Min/Max/Gcd/Lcm evaluation is only supported on R',
    );

double _unsupportedRealTuple(List<double> args) =>
    throw UnsupportedError('Cannot evaluate Tuple numerically as scalar');

Complex _unsupportedComplexTuple(List<Complex> args) =>
    throw UnsupportedError('Cannot evaluate Tuple numerically as scalar');

Expr _dfFactorial(Expr u) =>
    factorialSpec(u) * digammaSpec(u + IntegerNumber.one);

Expr _diffBinomial(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) {
  final left = args[0];
  final right = args[1];
  if (right case IntegerNumber(asInt: final k?) when k >= 0 && k <= 20) {
    if (k == 0) return IntegerNumber.zero;
    final factors = <Expr>[
      for (var j = 0; j < k; j++)
        (j == 0 ? left : left - IntegerNumber.of(j)) / IntegerNumber.of(j + 1),
    ];
    return diff(Mul.of(factors));
  }
  final dn = diff(left);
  final dk = diff(right);
  final psiNK1 = polygammaSpec(
    IntegerNumber.zero,
    left - right + IntegerNumber.one,
  );
  final terms = <Expr>[];
  if (dn != IntegerNumber.zero) {
    final psiN1 = polygammaSpec(IntegerNumber.zero, left + IntegerNumber.one);
    terms.add((psiN1 - psiNK1) * dn);
  }
  if (dk != IntegerNumber.zero) {
    final psiK1 = polygammaSpec(IntegerNumber.zero, right + IntegerNumber.one);
    terms.add(-(psiK1 - psiNK1) * dk);
  }
  if (terms.isEmpty) return IntegerNumber.zero;
  return binomialSpec(left, right) * Add.of(terms);
}

Expr _dfZero(Expr u) => IntegerNumber.zero;

Expr? _diffMod(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) => args[1].dependsOn(variable) ? null : diff(args[0]);

Expr? _diffMin(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) {
  if (args.length != 2) return null;
  final a = args[0];
  final b = args[1];
  final da = diff(a);
  final db = diff(b);
  return FractionNumber.half * ((da + db) - signSpec(a - b) * (da - db));
}

Expr? _diffMax(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) {
  if (args.length != 2) return null;
  final a = args[0];
  final b = args[1];
  final da = diff(a);
  final db = diff(b);
  return FractionNumber.half * ((da + db) + signSpec(a - b) * (da - db));
}

Expr _diffTuple(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) => tupleSpec([for (final a in args) diff(a)]);

String _textFactorial(
  List<Expr> args,
  int decimalPlaces,
  TextChildFormatter formatChild,
) {
  final inner = args[0];
  return inner is Call && inner.id == FunctionId.factorial
      ? '(${formatChild(inner, 0, decimalPlaces)})!'
      : '${formatChild(inner, 5, decimalPlaces)}!';
}

String _latexFactorial(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) => '${formatPowBase(args[0], decimalPlaces)}!';

String _mathMlFactorial(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) => '<mrow>${formatPowBase(args[0], decimalPlaces)}<mo>!</mo></mrow>';

String _latexBinomial(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) =>
    '\\binom{${formatChild(args[0], decimalPlaces)}}{${formatChild(args[1], decimalPlaces)}}';

String _mathMlBinomial(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) =>
    '<mrow><mo>(</mo><mfrac linethickness="0">${formatChild(args[0], decimalPlaces)}${formatChild(args[1], decimalPlaces)}</mfrac><mo>)</mo></mrow>';

String _latexFloor(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) => '\\lfloor ${formatChild(args[0], decimalPlaces)} \\rfloor';

String _mathMlFloor(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) =>
    '<mrow><mo>&#x230A;</mo>${formatChild(args[0], decimalPlaces)}<mo>&#x230B;</mo></mrow>';

String _latexCeil(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) => '\\lceil ${formatChild(args[0], decimalPlaces)} \\rceil';

String _mathMlCeil(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) =>
    '<mrow><mo>&#x2308;</mo>${formatChild(args[0], decimalPlaces)}<mo>&#x2309;</mo></mrow>';

String _latexMod(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) {
  String wrap(Expr e) {
    final s = formatChild(e, decimalPlaces);
    return (e is Add || e is Relational) ? r'\left(' + s + r'\right)' : s;
  }

  return '${wrap(args[0])} \\bmod ${wrap(args[1])}';
}

String _mathMlMod(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) {
  String wrap(Expr e) {
    final s = formatChild(e, decimalPlaces);
    return (e is Add || e is Relational)
        ? '<mrow><mo>(</mo>$s<mo>)</mo></mrow>'
        : s;
  }

  return '<mrow>${wrap(args[0])}<mo>mod</mo>${wrap(args[1])}</mrow>';
}

String _formatBracedLatex(
  String op,
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
) =>
    '$op\\left(${args.map((a) => formatChild(a, decimalPlaces)).join(', ')}\\right)';

String _latexMin(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) => _formatBracedLatex(r'\min', args, decimalPlaces, formatChild);

String _latexMax(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) => _formatBracedLatex(r'\max', args, decimalPlaces, formatChild);

String _latexGcd(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) => _formatBracedLatex(r'\gcd', args, decimalPlaces, formatChild);

String _latexLcm(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) =>
    _formatBracedLatex(r'\operatorname{lcm}', args, decimalPlaces, formatChild);

String _textTuple(
  List<Expr> args,
  int decimalPlaces,
  TextChildFormatter formatChild,
) => '[${args.map((a) => formatChild(a, 0, decimalPlaces)).join(', ')}]';

String _latexTuple(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) =>
    '\\left[${args.map((a) => formatChild(a, decimalPlaces)).join(', ')}\\right]';

String _mathMlTuple(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) =>
    '<mrow><mo>[</mo>${args.map((a) => formatChild(a, decimalPlaces)).join('<mo>,</mo>')}<mo>]</mo></mrow>';
