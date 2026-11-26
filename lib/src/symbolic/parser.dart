import 'package:petitparser/petitparser.dart';

import '../linear/matrix.dart';
import '../linear/vector.dart';
import 'algebra/orthogonal.dart';
import 'ast.dart';
import 'number/integer.dart';
import 'type/expr_data_type.dart';

/// Metadata describing a built-in symbolic function in [ExprSyntax].
final class ExprFunctionInfo {
  /// Creates metadata for a built-in symbolic function.
  const new({
    required this.name,
    required this.params,
    required this.doc,
    this.aliases = const [],
    this.category = 'elementary',
  });

  /// Canonical function name.
  final String name;

  /// Parameter names or signature descriptors (e.g. `['x']`, `['n', 'x']`).
  final List<String> params;

  /// Concise human-readable description of the function.
  final String doc;

  /// Alternative accepted names or case variants.
  final List<String> aliases;

  /// Logical category (e.g. `'elementary'`, `'trig'`, `'special'`,
  /// `'orthogonal'`, `'calculus'`, `'number'`).
  final String category;
}

/// Extensible case-sensitive syntax and parser for mathematical [Expr] strings.
///
/// Identifiers are any character sequence that does not start with a digit and
/// contains no whitespace or mathematical operator/delimiter symbols (`+`, `-`,
/// `*`, `/`, `^`, `(`, `)`, `[`, `]`, `{`, `}`, `,`, `;`, `:`, `.`, `=`, `<`,
/// `>`, `!`, `&`, `|`, `~`, `?`, `@`, `#`, `$`, `%`, `\`, `'`, `"`, `` ` ``).
///
/// Unbound identifiers without arguments resolve to [Variable], and unbound
/// identifiers with arguments resolve to [VariableFunction].
///
/// ```dart
/// final syntax = ExprSyntax(
///   constants: {'important': IntegerNumber.of(42)},
///   unaryFunctions: {'half': (a) => a / IntegerNumber.two},
/// );
/// final expr = syntax.parse('half(important) + f(x)');
/// ```
class ExprSyntax {
  /// Creates a syntax combining the standard mathematical constants and
  /// functions with any custom [constants], [unaryFunctions],
  /// [binaryFunctions], and [variadicFunctions].
  new({
    Map<String, Expr> constants = const {},
    Map<String, Expr Function(Expr)> unaryFunctions = const {},
    Map<String, Expr Function(Expr, Expr)> binaryFunctions = const {},
    Map<String, Expr Function(List<Expr>)> variadicFunctions = const {},
    bool implicitMultiplication = false,
  }) : this.empty(
         constants: {...standardConstants, ...constants},
         unaryFunctions: {...standardUnaryFunctions, ...unaryFunctions},
         binaryFunctions: {...standardBinaryFunctions, ...binaryFunctions},
         variadicFunctions: {
           ...standardVariadicFunctions,
           ...variadicFunctions,
         },
         implicitMultiplication: implicitMultiplication,
       );

  /// Creates a syntax containing only the specified [constants],
  /// [unaryFunctions], [binaryFunctions], and [variadicFunctions].
  new empty({
    Map<String, Expr> constants = const {},
    Map<String, Expr Function(Expr)> unaryFunctions = const {},
    Map<String, Expr Function(Expr, Expr)> binaryFunctions = const {},
    Map<String, Expr Function(List<Expr>)> variadicFunctions = const {},
    this.implicitMultiplication = false,
  }) : constants = Map.unmodifiable(constants),
       unaryFunctions = Map.unmodifiable(unaryFunctions),
       binaryFunctions = Map.unmodifiable(binaryFunctions),
       variadicFunctions = Map.unmodifiable(variadicFunctions);

  /// Standard symbolic syntax with built-in constants and functions.
  static final ExprSyntax standard = ExprSyntax();

  /// Standard mathematical constants.
  static final Map<String, Expr> standardConstants = Map.unmodifiable(
    <String, Expr>{
      'pi': Constant.pi,
      'π': Constant.pi,
      'e': Constant.e,
      'i': ComplexNumber.i,
      'infinity': Constant.infinity,
      '∞': Constant.infinity,
      'undefined': Constant.undefined,
    },
  );

  /// Standard 1-argument mathematical functions.
  static final Map<String, Expr Function(Expr)> standardUnaryFunctions =
      Map.unmodifiable(<String, Expr Function(Expr)>{
        'sin': Sin.new,
        'cos': Cos.new,
        'tan': Tan.new,
        'sec': (a) => Pow(Cos(a), IntegerNumber.negativeOne),
        'csc': (a) => Pow(Sin(a), IntegerNumber.negativeOne),
        'cot': (a) => Cos(a) / Sin(a),
        'asin': Asin.new,
        'arcsin': Asin.new,
        'acos': Acos.new,
        'arccos': Acos.new,
        'atan': Atan.new,
        'arctan': Atan.new,
        'asec': (a) => Acos(Pow(a, IntegerNumber.negativeOne)),
        'arcsec': (a) => Acos(Pow(a, IntegerNumber.negativeOne)),
        'acsc': (a) => Asin(Pow(a, IntegerNumber.negativeOne)),
        'arccsc': (a) => Asin(Pow(a, IntegerNumber.negativeOne)),
        'acot': (a) => Atan(Pow(a, IntegerNumber.negativeOne)),
        'arccot': (a) => Atan(Pow(a, IntegerNumber.negativeOne)),
        'sinh': Sinh.new,
        'cosh': Cosh.new,
        'tanh': Tanh.new,
        'sech': (a) => Pow(Cosh(a), IntegerNumber.negativeOne),
        'csch': (a) => Pow(Sinh(a), IntegerNumber.negativeOne),
        'coth': (a) => Cosh(a) / Sinh(a),
        'asinh': Asinh.new,
        'arcsinh': Asinh.new,
        'acosh': Acosh.new,
        'arccosh': Acosh.new,
        'atanh': Atanh.new,
        'arctanh': Atanh.new,
        'asech': (a) => Acosh(Pow(a, IntegerNumber.negativeOne)),
        'arcsech': (a) => Acosh(Pow(a, IntegerNumber.negativeOne)),
        'acsch': (a) => Asinh(Pow(a, IntegerNumber.negativeOne)),
        'arccsch': (a) => Asinh(Pow(a, IntegerNumber.negativeOne)),
        'acoth': (a) => Atanh(Pow(a, IntegerNumber.negativeOne)),
        'arccoth': (a) => Atanh(Pow(a, IntegerNumber.negativeOne)),
        'abs': Abs.new,
        'sqrt': (a) => Pow(a, FractionNumber.half),
        'exp': (a) {
          final p = Pow(Constant.e, a);
          _isExpFunction[p] = true;
          return p;
        },
        'ln': Ln.new,
        'log': Ln.new,
        'log2': (a) => Ln(a) / Ln(IntegerNumber.two),
        'log10': (a) => Ln(a) / Ln(IntegerNumber.of(10)),
        'erf': Erf.new,
        'erfc': Erfc.new,
        'erfi': Erfi.new,
        'Erfi': Erfi.new,
        'fresnels': FresnelS.new,
        'fresnelS': FresnelS.new,
        'FresnelS': FresnelS.new,
        'fresnelc': FresnelC.new,
        'fresnelC': FresnelC.new,
        'FresnelC': FresnelC.new,
        'Ei': ExpIntegral.new,
        'ei': ExpIntegral.new,
        'expIntegralEi': ExpIntegral.new,
        'ExpIntegral': ExpIntegral.new,
        'li': LogIntegral.new,
        'Li': LogIntegral.new,
        'logIntegralLi': LogIntegral.new,
        'LogIntegral': LogIntegral.new,
        'Si': SinIntegral.new,
        'si': SinIntegral.new,
        'sinIntegralSi': SinIntegral.new,
        'SinIntegral': SinIntegral.new,
        'Ci': CosIntegral.new,
        'ci': CosIntegral.new,
        'cosIntegralCi': CosIntegral.new,
        'CosIntegral': CosIntegral.new,
        'Shi': SinhIntegral.new,
        'shi': SinhIntegral.new,
        'sinhIntegralShi': SinhIntegral.new,
        'SinhIntegral': SinhIntegral.new,
        'Chi': CoshIntegral.new,
        'chi': CoshIntegral.new,
        'coshIntegralChi': CoshIntegral.new,
        'CoshIntegral': CoshIntegral.new,
        'gamma': Gamma.new,
        'logGamma': LogGamma.new,
        'loggamma': LogGamma.new,
        'LogGamma': LogGamma.new,
        'lgamma': LogGamma.new,
        'gammaLn': LogGamma.new,
        'cbrt': (x) => Pow(x, FractionNumber.third),
        'zeta': Zeta.new,
        'Zeta': Zeta.new,
        'digamma': Digamma.new,
        'psi': Digamma.new,
        'elliptick': EllipticK.new,
        'ellipticK': EllipticK.new,
        'EllipticK': EllipticK.new,
        'elliptic_k': EllipticK.new,
        'elliptice': EllipticE.new,
        'ellipticE': EllipticE.new,
        'EllipticE': EllipticE.new,
        'elliptic_e': EllipticE.new,
        'besselj0': (x) => BesselJ(IntegerNumber.zero, x),
        'besselj1': (x) => BesselJ(IntegerNumber.one, x),
        'bessely0': (x) => BesselY(IntegerNumber.zero, x),
        'bessely1': (x) => BesselY(IntegerNumber.one, x),
        'factorial': Factorial.new,
        'floor': Floor.new,
        'ceil': Ceil.new,
        'round': Round.new,
        'sign': Sign.new,
        'sgn': Sign.new,
        're': Re.new,
        'im': Im.new,
        'arg': Arg.new,
        'conj': Conjugate.new,
        'conjugate': Conjugate.new,
        'lambertW': LambertW.new,
        'lambertw': LambertW.new,
        'LambertW': LambertW.new,
        'W': LambertW.new,
        'w': LambertW.new,
      });

  /// Standard 2-argument mathematical functions.
  static final Map<String, Expr Function(Expr, Expr)> standardBinaryFunctions =
      Map.unmodifiable(<String, Expr Function(Expr, Expr)>{
        'pow': Pow.new,
        'log': (a, b) => Ln(b) / Ln(a),
        'root': (a, b) => Pow(a, IntegerNumber.one / b),
        'beta': Beta.new,
        'polygamma': Polygamma.new,
        'Polygamma': Polygamma.new,
        'PolyGamma': Polygamma.new,
        'besselj': BesselJ.new,
        'besselJ': BesselJ.new,
        'BesselJ': BesselJ.new,
        'bessely': BesselY.new,
        'besselY': BesselY.new,
        'BesselY': BesselY.new,
        'besseli': BesselI.new,
        'besselI': BesselI.new,
        'BesselI': BesselI.new,
        'besselk': BesselK.new,
        'besselK': BesselK.new,
        'BesselK': BesselK.new,
        'uppergamma': UpperGamma.new,
        'upperGamma': UpperGamma.new,
        'UpperGamma': UpperGamma.new,
        'lowergamma': LowerGamma.new,
        'lowerGamma': LowerGamma.new,
        'LowerGamma': LowerGamma.new,
        'polylog': Polylog.new,
        'Polylog': Polylog.new,
        'Li': Polylog.new,
        'elliptic_f': EllipticF.new,
        'ellipticF': EllipticF.new,
        'EllipticF': EllipticF.new,
        'elliptic_e': (phi, k) => EllipticE(k, amplitude: phi),
        'elliptice': (phi, k) => EllipticE(k, amplitude: phi),
        'ellipticE': (phi, k) => EllipticE(k, amplitude: phi),
        'EllipticE': (phi, k) => EllipticE(k, amplitude: phi),
        'atan2': Atan2.new,
        'Atan2': Atan2.new,
        'zeta': (s, a) => Zeta(s, shift: a),
        'Zeta': (s, a) => Zeta(s, shift: a),
        'expint': ExpIntegralE.new,
        'expIntegralE': ExpIntegralE.new,
        'ExpIntegralE': ExpIntegralE.new,
        'binomial': Binomial.new,
        'nCr': Binomial.new,
        'mod': Mod.new,
        'lambertW': _parseLambertWBinary,
        'lambertw': _parseLambertWBinary,
        'LambertW': _parseLambertWBinary,
        'W': _parseLambertWBinary,
        'w': _parseLambertWBinary,
        'chebyshevT': (n, x) =>
            _parseOrthogonal('chebyshevT', n, x, chebyshevT),
        'chebyshevU': (n, x) =>
            _parseOrthogonal('chebyshevU', n, x, chebyshevU),
        'legendreP': (n, x) => _parseOrthogonal('legendreP', n, x, legendreP),
        'hermiteH': (n, x) => _parseOrthogonal('hermiteH', n, x, hermiteH),
        'hermiteHe': (n, x) => _parseOrthogonal('hermiteHe', n, x, hermiteHe),
      });

  /// Standard variadic mathematical functions.
  static final Map<String, Expr Function(List<Expr>)>
  standardVariadicFunctions = Map.unmodifiable(
    <String, Expr Function(List<Expr>)>{
      'piecewise': _parsePiecewiseArgs,
      'Piecewise': _parsePiecewiseArgs,
      'elliptic_pi': _parseEllipticPiArgs,
      'ellipticPi': _parseEllipticPiArgs,
      'EllipticPi': _parseEllipticPiArgs,
      'hyper': _parseHypergeometricArgs,
      'hypergeometric': _parseHypergeometricArgs,
      'Hypergeometric': _parseHypergeometricArgs,
      'appellF1': _parseAppellF1Args,
      'appellf1': _parseAppellF1Args,
      'AppellF1': _parseAppellF1Args,
      'tuple': Tuple.new,
      'min': Min.new,
      'Min': Min.new,
      'max': Max.new,
      'Max': Max.new,
      'integrate': _parseIntegralArgs,
      'integral': _parseIntegralArgs,
      'diff': _parseDerivativeArgs,
      'derivative': _parseDerivativeArgs,
      'limit': _parseLimitArgs,
      'sum': _parseSumArgs,
      'product': _parseProductArgs,
      'rootsum': _parseRootSumArgs,
      'RootSum': _parseRootSumArgs,
      'gcd': Gcd.new,
      'lcm': Lcm.new,
      'O': _parseOrderTermArgs,
      'laguerreL': _parseLaguerreLArgs,
    },
  );

  /// Metadata for all standard built-in symbolic functions.
  static final List<ExprFunctionInfo>
  standardFunctions = List.unmodifiable(const <ExprFunctionInfo>[
    // Elementary
    ExprFunctionInfo(
      name: 'abs',
      params: ['x'],
      doc: 'Absolute value or complex modulus',
    ),
    ExprFunctionInfo(name: 'sqrt', params: ['x'], doc: 'Principal square root'),
    ExprFunctionInfo(name: 'cbrt', params: ['x'], doc: 'Principal cube root'),
    ExprFunctionInfo(
      name: 'root',
      params: ['x', 'n'],
      doc: 'Principal n-th root of x',
    ),
    ExprFunctionInfo(name: 'pow', params: ['x', 'y'], doc: 'Power x^y'),
    ExprFunctionInfo(
      name: 'exp',
      params: ['x'],
      doc: 'Natural exponential e^x',
    ),
    ExprFunctionInfo(
      name: 'ln',
      params: ['x'],
      doc: 'Natural logarithm',
      aliases: ['log'],
    ),
    ExprFunctionInfo(
      name: 'log',
      params: ['base', 'x'],
      doc: 'Logarithm of x to the given base',
    ),
    ExprFunctionInfo(name: 'log2', params: ['x'], doc: 'Base-2 logarithm'),
    ExprFunctionInfo(name: 'log10', params: ['x'], doc: 'Base-10 logarithm'),

    // Trigonometric
    ExprFunctionInfo(
      name: 'sin',
      params: ['x'],
      doc: 'Sine of x (radians)',
      category: 'trig',
    ),
    ExprFunctionInfo(
      name: 'cos',
      params: ['x'],
      doc: 'Cosine of x (radians)',
      category: 'trig',
    ),
    ExprFunctionInfo(
      name: 'tan',
      params: ['x'],
      doc: 'Tangent of x (radians)',
      category: 'trig',
    ),
    ExprFunctionInfo(
      name: 'sec',
      params: ['x'],
      doc: 'Secant 1/cos(x)',
      category: 'trig',
    ),
    ExprFunctionInfo(
      name: 'csc',
      params: ['x'],
      doc: 'Cosecant 1/sin(x)',
      category: 'trig',
    ),
    ExprFunctionInfo(
      name: 'cot',
      params: ['x'],
      doc: 'Cotangent cos(x)/sin(x)',
      category: 'trig',
    ),
    ExprFunctionInfo(
      name: 'asin',
      params: ['x'],
      doc: 'Inverse sine (arcsine)',
      aliases: ['arcsin'],
      category: 'trig',
    ),
    ExprFunctionInfo(
      name: 'acos',
      params: ['x'],
      doc: 'Inverse cosine (arccosine)',
      aliases: ['arccos'],
      category: 'trig',
    ),
    ExprFunctionInfo(
      name: 'atan',
      params: ['x'],
      doc: 'Inverse tangent (arctangent)',
      aliases: ['arctan'],
      category: 'trig',
    ),
    ExprFunctionInfo(
      name: 'atan2',
      params: ['y', 'x'],
      doc: 'Two-argument arctangent of y/x',
      aliases: ['Atan2'],
      category: 'trig',
    ),
    ExprFunctionInfo(
      name: 'asec',
      params: ['x'],
      doc: 'Inverse secant',
      aliases: ['arcsec'],
      category: 'trig',
    ),
    ExprFunctionInfo(
      name: 'acsc',
      params: ['x'],
      doc: 'Inverse cosecant',
      aliases: ['arccsc'],
      category: 'trig',
    ),
    ExprFunctionInfo(
      name: 'acot',
      params: ['x'],
      doc: 'Inverse cotangent',
      aliases: ['arccot'],
      category: 'trig',
    ),

    // Hyperbolic
    ExprFunctionInfo(
      name: 'sinh',
      params: ['x'],
      doc: 'Hyperbolic sine',
      category: 'hyperbolic',
    ),
    ExprFunctionInfo(
      name: 'cosh',
      params: ['x'],
      doc: 'Hyperbolic cosine',
      category: 'hyperbolic',
    ),
    ExprFunctionInfo(
      name: 'tanh',
      params: ['x'],
      doc: 'Hyperbolic tangent',
      category: 'hyperbolic',
    ),
    ExprFunctionInfo(
      name: 'sech',
      params: ['x'],
      doc: 'Hyperbolic secant',
      category: 'hyperbolic',
    ),
    ExprFunctionInfo(
      name: 'csch',
      params: ['x'],
      doc: 'Hyperbolic cosecant',
      category: 'hyperbolic',
    ),
    ExprFunctionInfo(
      name: 'coth',
      params: ['x'],
      doc: 'Hyperbolic cotangent',
      category: 'hyperbolic',
    ),
    ExprFunctionInfo(
      name: 'asinh',
      params: ['x'],
      doc: 'Inverse hyperbolic sine',
      aliases: ['arcsinh'],
      category: 'hyperbolic',
    ),
    ExprFunctionInfo(
      name: 'acosh',
      params: ['x'],
      doc: 'Inverse hyperbolic cosine',
      aliases: ['arccosh'],
      category: 'hyperbolic',
    ),
    ExprFunctionInfo(
      name: 'atanh',
      params: ['x'],
      doc: 'Inverse hyperbolic tangent',
      aliases: ['arctanh'],
      category: 'hyperbolic',
    ),
    ExprFunctionInfo(
      name: 'asech',
      params: ['x'],
      doc: 'Inverse hyperbolic secant',
      aliases: ['arcsech'],
      category: 'hyperbolic',
    ),
    ExprFunctionInfo(
      name: 'acsch',
      params: ['x'],
      doc: 'Inverse hyperbolic cosecant',
      aliases: ['arccsch'],
      category: 'hyperbolic',
    ),
    ExprFunctionInfo(
      name: 'acoth',
      params: ['x'],
      doc: 'Inverse hyperbolic cotangent',
      aliases: ['arccoth'],
      category: 'hyperbolic',
    ),

    // Number & Combinatorics
    ExprFunctionInfo(
      name: 'factorial',
      params: ['n'],
      doc: 'Factorial n!',
      category: 'number',
    ),
    ExprFunctionInfo(
      name: 'binomial',
      params: ['n', 'k'],
      doc: 'Binomial coefficient C(n, k)',
      aliases: ['nCr'],
      category: 'number',
    ),
    ExprFunctionInfo(
      name: 'floor',
      params: ['x'],
      doc: 'Greatest integer <= x',
      category: 'number',
    ),
    ExprFunctionInfo(
      name: 'ceil',
      params: ['x'],
      doc: 'Smallest integer >= x',
      category: 'number',
    ),
    ExprFunctionInfo(
      name: 'round',
      params: ['x'],
      doc: 'Nearest integer to x',
      category: 'number',
    ),
    ExprFunctionInfo(
      name: 'sign',
      params: ['x'],
      doc: 'Signum (-1, 0, or 1)',
      aliases: ['sgn'],
      category: 'number',
    ),
    ExprFunctionInfo(
      name: 'mod',
      params: ['a', 'b'],
      doc: 'Modulo remainder a mod b',
      category: 'number',
    ),
    ExprFunctionInfo(
      name: 'gcd',
      params: ['a', 'b', '...'],
      doc: 'Greatest common divisor',
      category: 'number',
    ),
    ExprFunctionInfo(
      name: 'lcm',
      params: ['a', 'b', '...'],
      doc: 'Least common multiple',
      category: 'number',
    ),
    ExprFunctionInfo(
      name: 'min',
      params: ['a', 'b', '...'],
      doc: 'Minimum of arguments',
      aliases: ['Min'],
      category: 'number',
    ),
    ExprFunctionInfo(
      name: 'max',
      params: ['a', 'b', '...'],
      doc: 'Maximum of arguments',
      aliases: ['Max'],
      category: 'number',
    ),

    // Complex
    ExprFunctionInfo(
      name: 're',
      params: ['z'],
      doc: 'Real part of z',
      category: 'complex',
    ),
    ExprFunctionInfo(
      name: 'im',
      params: ['z'],
      doc: 'Imaginary part of z',
      category: 'complex',
    ),
    ExprFunctionInfo(
      name: 'arg',
      params: ['z'],
      doc: 'Principal argument (phase angle) of z',
      category: 'complex',
    ),
    ExprFunctionInfo(
      name: 'conj',
      params: ['z'],
      doc: 'Complex conjugate of z',
      aliases: ['conjugate'],
      category: 'complex',
    ),

    // Special Functions
    ExprFunctionInfo(
      name: 'gamma',
      params: ['z'],
      doc: 'Euler gamma function',
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'beta',
      params: ['a', 'b'],
      doc: 'Euler beta function B(a, b)',
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'upperGamma',
      params: ['s', 'x'],
      doc: 'Upper incomplete gamma function',
      aliases: ['uppergamma', 'UpperGamma'],
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'lowerGamma',
      params: ['s', 'x'],
      doc: 'Lower incomplete gamma function',
      aliases: ['lowergamma', 'LowerGamma'],
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'digamma',
      params: ['z'],
      doc: 'Digamma function psi(z)',
      aliases: ['psi'],
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'polygamma',
      params: ['n', 'z'],
      doc: 'Polygamma function psi^(n)(z)',
      aliases: ['Polygamma', 'PolyGamma'],
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'logGamma',
      params: ['z'],
      doc: 'Natural logarithm of the gamma function ln(Gamma(z))',
      aliases: ['loggamma', 'LogGamma', 'lgamma', 'gammaLn'],
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'zeta',
      params: ['s', '[a]'],
      doc: 'Riemann or Hurwitz zeta function',
      aliases: ['Zeta'],
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'polylog',
      params: ['s', 'z'],
      doc: 'Polylogarithm Li_s(z)',
      aliases: ['Polylog', 'Li'],
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'erf',
      params: ['z'],
      doc: 'Error function',
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'erfc',
      params: ['z'],
      doc: 'Complementary error function',
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'erfi',
      params: ['z'],
      doc: 'Imaginary error function',
      aliases: ['Erfi'],
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'fresnelS',
      params: ['z'],
      doc: 'Fresnel sine integral S(z)',
      aliases: ['fresnels', 'FresnelS'],
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'fresnelC',
      params: ['z'],
      doc: 'Fresnel cosine integral C(z)',
      aliases: ['fresnelc', 'FresnelC'],
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'expIntegralEi',
      params: ['x'],
      doc: 'Exponential integral Ei(x)',
      aliases: ['Ei', 'ei', 'ExpIntegral'],
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'expIntegralE',
      params: ['n', 'x'],
      doc: 'Generalized exponential integral E_n(x)',
      aliases: ['expint', 'ExpIntegralE'],
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'logIntegralLi',
      params: ['x'],
      doc: 'Logarithmic integral li(x)',
      aliases: ['li', 'Li', 'LogIntegral'],
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'sinIntegralSi',
      params: ['x'],
      doc: 'Sine integral Si(x)',
      aliases: ['Si', 'si', 'SinIntegral'],
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'cosIntegralCi',
      params: ['x'],
      doc: 'Cosine integral Ci(x)',
      aliases: ['Ci', 'ci', 'CosIntegral'],
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'sinhIntegralShi',
      params: ['x'],
      doc: 'Hyperbolic sine integral Shi(x)',
      aliases: ['Shi', 'shi', 'SinhIntegral'],
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'coshIntegralChi',
      params: ['x'],
      doc: 'Hyperbolic cosine integral Chi(x)',
      aliases: ['Chi', 'chi', 'CoshIntegral'],
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'lambertW',
      params: ['z', '[k]'],
      doc: 'Lambert W function (principal branch or k = -1)',
      aliases: ['lambertw', 'LambertW', 'W', 'w'],
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'besselJ',
      params: ['n', 'z'],
      doc: 'Bessel function of the first kind J_n(z)',
      aliases: ['besselj', 'BesselJ'],
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'besselY',
      params: ['n', 'z'],
      doc: 'Bessel function of the second kind Y_n(z)',
      aliases: ['bessely', 'BesselY'],
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'besselI',
      params: ['n', 'z'],
      doc: 'Modified Bessel function of the first kind I_n(z)',
      aliases: ['besseli', 'BesselI'],
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'besselK',
      params: ['n', 'z'],
      doc: 'Modified Bessel function of the second kind K_n(z)',
      aliases: ['besselk', 'BesselK'],
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'besselj0',
      params: ['z'],
      doc: 'Bessel function J_0(z)',
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'besselj1',
      params: ['z'],
      doc: 'Bessel function J_1(z)',
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'bessely0',
      params: ['z'],
      doc: 'Bessel function Y_0(z)',
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'bessely1',
      params: ['z'],
      doc: 'Bessel function Y_1(z)',
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'ellipticK',
      params: ['k'],
      doc: 'Complete elliptic integral of the first kind K(k)',
      aliases: ['elliptick', 'elliptic_k'],
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'ellipticE',
      params: ['phi_or_k', '[k]'],
      doc: 'Complete or incomplete elliptic integral of the second kind',
      aliases: ['elliptice', 'elliptic_e', 'EllipticE'],
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'ellipticF',
      params: ['phi', 'k'],
      doc: 'Incomplete elliptic integral of the first kind F(phi, k)',
      aliases: ['elliptic_f', 'EllipticF'],
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'ellipticPi',
      params: ['n', '[phi]', 'k'],
      doc: 'Elliptic integral of the third kind',
      aliases: ['elliptic_pi', 'EllipticPi'],
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'hypergeometric',
      params: ['upper', 'lower', 'z'],
      doc: 'Generalized hypergeometric function pFq',
      aliases: ['hyper', 'Hypergeometric'],
      category: 'special',
    ),
    ExprFunctionInfo(
      name: 'appellF1',
      params: ['a', 'b1', 'b2', 'c', 'x', 'y'],
      doc: 'Appell hypergeometric function F_1(a; b1, b2; c; x, y)',
      aliases: ['appellf1', 'AppellF1'],
      category: 'special',
    ),

    // Orthogonal Polynomials
    ExprFunctionInfo(
      name: 'chebyshevT',
      params: ['n', 'x'],
      doc: 'Chebyshev polynomial of the first kind T_n(x)',
      category: 'orthogonal',
    ),
    ExprFunctionInfo(
      name: 'chebyshevU',
      params: ['n', 'x'],
      doc: 'Chebyshev polynomial of the second kind U_n(x)',
      category: 'orthogonal',
    ),
    ExprFunctionInfo(
      name: 'legendreP',
      params: ['n', 'x'],
      doc: 'Legendre polynomial P_n(x)',
      category: 'orthogonal',
    ),
    ExprFunctionInfo(
      name: 'hermiteH',
      params: ['n', 'x'],
      doc: 'Physicists\' Hermite polynomial H_n(x)',
      category: 'orthogonal',
    ),
    ExprFunctionInfo(
      name: 'hermiteHe',
      params: ['n', 'x'],
      doc: 'Probabilists\' Hermite polynomial He_n(x)',
      category: 'orthogonal',
    ),
    ExprFunctionInfo(
      name: 'laguerreL',
      params: ['n', 'x', '[alpha]'],
      doc: 'Generalized Laguerre polynomial L_n^(alpha)(x)',
      category: 'orthogonal',
    ),

    // Structural & Calculus AST Forms
    ExprFunctionInfo(
      name: 'piecewise',
      params: ['cond1', 'expr1', '...', '[otherwise]'],
      doc: 'Piecewise-defined expression',
      aliases: ['Piecewise'],
      category: 'calculus',
    ),
    ExprFunctionInfo(
      name: 'O',
      params: ['term'],
      doc: 'Big-O asymptotic order term',
      category: 'calculus',
    ),
    ExprFunctionInfo(
      name: 'tuple',
      params: ['a', '...'],
      doc: 'Ordered tuple of expressions',
      category: 'calculus',
    ),
    ExprFunctionInfo(
      name: 'rootsum',
      params: ['polynomial', 'variable', 'body'],
      doc: 'Sum of body over all complex roots of polynomial(variable) = 0',
      aliases: ['RootSum'],
      category: 'calculus',
    ),
  ]);

  /// Registered named constants.
  final Map<String, Expr> constants;

  /// Registered 1-argument functions.
  final Map<String, Expr Function(Expr)> unaryFunctions;

  /// Registered 2-argument functions.
  final Map<String, Expr Function(Expr, Expr)> binaryFunctions;

  /// Registered variadic functions.
  final Map<String, Expr Function(List<Expr>)> variadicFunctions;

  /// Whether juxtaposition (`2x`, `3(x + 1)`, `(a + b)(c + d)`) is parsed as
  /// multiplication.
  final bool implicitMultiplication;

  /// Parser for identifier tokens without whitespace trimming.
  static final Parser<String> identifierTokenParser =
      _buildIdentifierTokenParser();

  /// Parser for number literal tokens without whitespace trimming.
  static final Parser<Expr> numberTokenParser = _buildNumberTokenParser();

  /// Underlying anchored PetitParser [Parser] for [Expr] strings.
  late final Parser<Expr> parser = _expressionParser.end();

  /// Parses [input] into an [Expr], throwing [FormatException] on syntax error.
  Expr parse(String input) => switch (parser.parse(input)) {
    Success(:final value) => value,
    Failure(:final message, :final position) => throw FormatException(
      message,
      input,
      position,
    ),
  };

  /// Parses [input] into an [Expr], or returns `null` if [input] is invalid.
  Expr? tryParse(String input) {
    try {
      return switch (parser.parse(input)) {
        Success(:final value) => value,
        Failure() => null,
      };
    } on FormatException {
      return null;
    }
  }

  /// Parses a bracketed vector literal `[a, b, c]` into a symbolic [Vector],
  /// throwing [FormatException] on syntax error.
  Vector<Expr> parseVector(String input) =>
      switch (_vectorParser.parse(input)) {
        Success(:final value) => value,
        Failure(:final message, :final position) => throw FormatException(
          message,
          input,
          position,
        ),
      };

  /// Parses a bracketed vector literal `[a, b, c]` into a symbolic [Vector],
  /// or returns `null` if [input] is invalid.
  Vector<Expr>? tryParseVector(String input) {
    try {
      return switch (_vectorParser.parse(input)) {
        Success(:final value) => value,
        Failure() => null,
      };
    } on FormatException {
      return null;
    }
  }

  /// Parses a nested bracketed matrix literal `[[a, b], [c, d]]` into a
  /// symbolic [Matrix], throwing [FormatException] on syntax error or ragged rows.
  Matrix<Expr> parseMatrix(String input) =>
      switch (_matrixParser.parse(input)) {
        Success(:final value) => value,
        Failure(:final message, :final position) => throw FormatException(
          message,
          input,
          position,
        ),
      };

  /// Parses a nested bracketed matrix literal `[[a, b], [c, d]]` into a
  /// symbolic [Matrix], or returns `null` if [input] is invalid.
  Matrix<Expr>? tryParseMatrix(String input) {
    try {
      return switch (_matrixParser.parse(input)) {
        Success(:final value) => value,
        Failure() => null,
      };
    } on FormatException {
      return null;
    }
  }

  static final _isExpFunction = Expando<bool>();

  static const String _mathSymbols =
      '+-*/^ˆ\u0302‸＾()[]{},;:.=<>!&|~?@#\$%\\\'"`´¨˜−–×·÷≤≥≠²³⁴√';

  late final Parser<String> _identifierParser = identifierTokenParser.trim();
  late final Parser<Expr> _numberParser = numberTokenParser.trim();
  late final Parser<Expr> _expressionParser = _buildExprParser();

  late final Parser<Vector<Expr>> _vectorElementParser =
      _buildBracketedExprList().map(
        (elements) => Vector<Expr>.fromList(elements, type: exprDataType),
      );
  late final Parser<Vector<Expr>> _vectorParser = _vectorElementParser.end();

  late final Parser<Matrix<Expr>> _matrixElementParser =
      _buildBracketedExprList()
          .plusSeparated(char(',').trim())
          .map((list) => list.elements)
          .skip(before: char('[').trim(), after: char(']').trim())
          .map(_createMatrix);
  late final Parser<Matrix<Expr>> _matrixParser = _matrixElementParser.end();

  Parser<List<Expr>> _buildBracketedExprList() => _expressionParser
      .starSeparated(char(',').trim())
      .map((list) => list.elements)
      .skip(before: char('[').trim(), after: char(']').trim());

  static Parser<String> _buildIdentifierTokenParser() {
    final symbol = anyOf(_mathSymbols);
    final identifierStart = <Parser<String>>[
      whitespace(),
      digit(),
      symbol,
    ].toChoiceParser().neg(message: 'identifier expected');
    final identifierCont = <Parser<String>>[
      whitespace(),
      symbol,
    ].toChoiceParser().neg();
    return seq2(
      identifierStart,
      identifierCont.starString(),
    ).flatten(message: 'identifier expected');
  }

  static Parser<Expr> _buildNumberTokenParser() {
    final digits = digit().plusString();
    final fractional = seq2(char('.'), digit().starString());
    final exponent = seq3(anyOf('eE'), anyOf('+-').optional(), digits);
    return <Parser<Object>>[
      seq3(digits, fractional.optional(), exponent.optional()),
      seq3(char('.'), digits, exponent.optional()),
    ].toChoiceParser().flatten(message: 'number expected').map(_createNumber);
  }

  Parser<Expr> _buildExprParser() {
    final builder = ExpressionBuilder<Expr>();

    builder
      // Numbers
      ..primitive(_numberParser)
      // Constants, variables, and functions
      ..primitive(
        seq2(
          _identifierParser,
          builder.loopback
              .plusSeparated(char(',').trim())
              .map((list) => list.elements)
              .skip(before: char('(').trim(), after: char(')').trim())
              .optional(),
        ).map2(_createBinding),
      )
      ..primitive(
        builder.loopback
            .starSeparated(char(',').trim())
            .map((list) => Tuple(list.elements))
            .skip(before: char('[').trim(), after: char(']').trim()),
      );

    // Parentheses (highest precedence wrapper)
    builder.group().wrapper(
      char('(').trim(),
      char(')').trim(),
      (_, value, _) => value,
    );

    // Postfix factorial (!, not followed by =)
    builder.group().postfix(
      seq2(char('!'), char('=').not()).trim(),
      (a, _) => Factorial(a),
    );

    // Exponentiation (right-associative)
    final caretOp = <Parser<String>>[
      string('**'),
      anyOf('^ˆ\u0302‸＾'),
    ].toChoiceParser().trim();
    final unarySignList = anyOf('+-').trim().plus();
    builder.group()
      ..right(
        seq2(
          caretOp,
          unarySignList,
        ).map2((_, signs) => signs.where((s) => s == '-').length.isOdd),
        (a, isOddNeg, b) => Pow(a, isOddNeg ? _rawNeg(b) : b),
      )
      ..right(caretOp, (a, _, b) => Pow(a, b));

    // Unary prefix operators (+, -)
    builder.group()
      ..prefix(char('+').trim(), (_, a) => a)
      ..prefix(char('-').trim(), (_, a) => _rawNeg(a));

    // Multiplicative operators (*, /, and optional implicit juxtaposition)
    final mulGroup = builder.group()
      ..left(char('*').trim(), (a, _, b) => _rawMul(a, b))
      ..left(char('/').trim(), (a, _, b) => _rawDiv(a, b));
    if (implicitMultiplication) {
      // Negative lookahead prevents implicit multiplication from consuming a
      // leading '+' or '-' as a unary prefix on the right operand (so 'a - b'
      // remains subtraction, not 'a * (-b)'), or splitting malformed numbers.
      mulGroup.left(
        anyOf('+-*/^ˆ\u0302‸＾)=<>!,;:].').trim().not(),
        (a, _, b) => _rawMul(a, b),
      );
    }

    // Additive operators (+, -, left-associative)
    builder.group()
      ..left(char('+').trim(), (a, _, b) => _rawAdd(a, b))
      ..left(char('-').trim(), (a, _, b) => _rawSub(a, b));

    // Relational operators (<=, >=, !=, <, >, ==, =)
    builder.group()
      ..left(string('<=').trim(), (a, _, b) => LessEqual(a, b))
      ..left(string('>=').trim(), (a, _, b) => GreaterEqual(a, b))
      ..left(string('!=').trim(), (a, _, b) => NotEqual(a, b))
      ..left(char('<').trim(), (a, _, b) => LessThan(a, b))
      ..left(char('>').trim(), (a, _, b) => GreaterThan(a, b))
      ..left(
        <Parser<String>>[string('=='), char('=')].toChoiceParser().trim(),
        (a, _, b) => Equal(a, b),
      );

    return resolve(builder.build());
  }

  static Matrix<Expr> _createMatrix(List<List<Expr>> rows) {
    final cols = rows.first.length;
    for (var r = 1; r < rows.length; r++) {
      if (rows[r].length != cols) {
        throw FormatException(
          'Inconsistent matrix row lengths: row 0 has $cols columns, '
          'row $r has ${rows[r].length}',
        );
      }
    }
    return Matrix<Expr>.fromRows(rows, type: exprDataType);
  }

  Expr _createBinding(String name, List<Expr>? arguments) {
    if (arguments == null) return constants[name] ?? Variable(name);
    if (arguments.length == 1) {
      if (unaryFunctions[name] case final fn?) return fn(arguments[0]);
    } else if (arguments.length == 2) {
      if (binaryFunctions[name] case final fn?) {
        return fn(arguments[0], arguments[1]);
      }
    }
    if (variadicFunctions[name] case final fn?) return fn(arguments);
    return VariableFunction(name, arguments);
  }

  static Expr _rawAdd(Expr a, Expr b) {
    if (a is ComplexNumber || b is ComplexNumber) {
      return Add([
        if (a case Add(:final terms, isSimplified: false)) ...terms else a,
        if (b case Add(:final terms, isSimplified: false)) ...terms else b,
      ]);
    }
    return a + b;
  }

  static Expr _rawSub(Expr a, Expr b) => _rawAdd(a, _rawNeg(b));

  static Expr _rawNeg(Expr a) =>
      a is ComplexNumber ? Mul([IntegerNumber.negativeOne, a]) : -a;

  static Expr _rawMul(Expr a, Expr b) {
    if (a is ComplexNumber || b is ComplexNumber) {
      return Mul([
        if (a case Mul(:final factors, isSimplified: false)) ...factors else a,
        if (b case Mul(:final factors, isSimplified: false)) ...factors else b,
      ]);
    }
    return a * b;
  }

  static Expr _rawDiv(Expr a, Expr b) {
    if (a is ComplexNumber || b is ComplexNumber) {
      if (a is IntegerNumber && a.isOne) {
        return Pow(b, IntegerNumber.negativeOne);
      }
      return _rawMul(a, Pow(b, IntegerNumber.negativeOne));
    }
    return a / b;
  }

  static Expr _createNumber(String value) {
    if (value.contains('.') || value.contains('e') || value.contains('E')) {
      return RealNumber.fromDouble(double.parse(value));
    }
    return IntegerNumber(Integer.parse(value));
  }

  static Expr _parseLambertWBinary(Expr a, Expr b) {
    if (b case IntegerNumber(asInt: final int branch && (0 || -1))) {
      return LambertW(a, branch: branch);
    }
    throw FormatException('LambertW branch must be 0 or -1, got: $b');
  }

  static Expr _parseOrderTerm(Expr arg) {
    if (arg is IntegerNumber && arg.isOne) return const OrderTerm('x', 0);
    final (Expr baseExpr, int order) = switch (arg) {
      Pow(:final base, exponent: IntegerNumber(asInt: final n?)) => (base, n),
      _ => (arg, 1),
    };
    return switch (baseExpr) {
      Variable(:final name) => OrderTerm(name, order),
      Pow(
        base: Variable(:final name),
        exponent: IntegerNumber(asInt: final m?),
      ) =>
        OrderTerm(name, m * order),
      Add(terms: [Variable(:final name), final shift]) => OrderTerm(
        name,
        order,
        point: -shift,
      ),
      Add(
        terms: [
          final shift,
          Mul(
            factors: [
              IntegerNumber(isNegativeOne: true),
              Variable(:final name),
            ],
          ),
        ],
      ) ||
      Add(
        terms: [
          Mul(
            factors: [
              IntegerNumber(isNegativeOne: true),
              Variable(:final name),
            ],
          ),
          final shift,
        ],
      ) => OrderTerm(name, order, point: shift),
      _ => throw FormatException('Invalid OrderTerm syntax: O($arg)'),
    };
  }

  static Expr _parseOrderTermArgs(List<Expr> args) => switch (args) {
    [final arg] => _parseOrderTerm(arg),
    [Variable(:final name), IntegerNumber(asInt: final n?)] => OrderTerm(
      name,
      n,
    ),
    [Variable(:final name), IntegerNumber(asInt: final n?), final point] =>
      OrderTerm(name, n, point: point),
    _ => throw FormatException(
      'Invalid OrderTerm syntax: O(${args.join(', ')})',
    ),
  };

  static Expr _parsePiecewiseArgs(List<Expr> args) {
    if (args.length < 2) {
      throw const FormatException(
        'piecewise requires at least 2 arguments (condition, expr)',
      );
    }
    final branches = <PiecewiseBranch>[];
    final pairCount = args.length ~/ 2;
    for (var i = 0; i < pairCount; i++) {
      final cond = args[2 * i];
      final val = args[2 * i + 1];
      if (cond is! RelationalExpr) {
        throw FormatException(
          'piecewise condition at argument ${2 * i + 1} must be a relational comparison, got: $cond',
        );
      }
      branches.add((relation: cond, expr: val));
    }
    final otherwise = args.length.isOdd ? args.last : null;
    return Piecewise(branches, otherwise: otherwise);
  }

  static Expr _parseIntegralArgs(List<Expr> args) {
    if (args case [final integrand, final v]) {
      final vName = _asVariableName(v);
      if (vName != null) {
        return Integral(_unbindConstant(integrand, v, vName), vName);
      }
      throw FormatException(
        'integrate second argument must be a variable identifier, got: $v',
      );
    }
    if (args case [final integrand, final v, final lower, final upper]) {
      final vName = _asVariableName(v);
      if (vName != null) {
        return Integral(
          _unbindConstant(integrand, v, vName),
          vName,
          lower: lower,
          upper: upper,
        );
      }
      throw FormatException(
        'integrate second argument must be a variable identifier, got: $v',
      );
    }
    throw FormatException(
      'integrate requires 2 or 4 arguments, got ${args.length}',
    );
  }

  static Expr _parseDerivativeArgs(List<Expr> args) {
    if (args case [final expr, final v]) {
      final vName = _asVariableName(v);
      if (vName != null) {
        return Derivative(_unbindConstant(expr, v, vName), vName);
      }
      throw FormatException(
        'diff second argument must be a variable identifier, got: $v',
      );
    }
    if (args case [final expr, final v, final orderExpr]) {
      final vName = _asVariableName(v);
      if (vName == null) {
        throw FormatException(
          'diff second argument must be a variable identifier, got: $v',
        );
      }
      if (orderExpr case IntegerNumber(asInt: final order?) when order >= 1) {
        return Derivative(_unbindConstant(expr, v, vName), vName, order: order);
      }
      throw FormatException(
        'diff order must be a positive integer, got: $orderExpr',
      );
    }
    if (args case [final expr, final v, final orderExpr, final point]) {
      final vName = _asVariableName(v);
      if (vName == null) {
        throw FormatException(
          'diff second argument must be a variable identifier, got: $v',
        );
      }
      if (orderExpr case IntegerNumber(asInt: final order?) when order >= 1) {
        return Derivative(
          _unbindConstant(expr, v, vName),
          vName,
          order: order,
          point: point,
        );
      }
      throw FormatException(
        'diff order must be a positive integer, got: $orderExpr',
      );
    }
    throw FormatException(
      'diff requires 2, 3, or 4 arguments, got ${args.length}',
    );
  }

  static Expr _parseLimitArgs(List<Expr> args) {
    if (args case [final expr, final v, final point]) {
      final vName = _asVariableName(v);
      if (vName != null) {
        return Limit(_unbindConstant(expr, v, vName), vName, point);
      }
      throw FormatException(
        'limit second argument must be a variable identifier, got: $v',
      );
    }
    if (args case [final expr, final v, final point, final dirExpr]) {
      final vName = _asVariableName(v);
      if (vName != null) {
        return Limit(
          _unbindConstant(expr, v, vName),
          vName,
          point,
          direction: _parseLimitDirection(dirExpr),
        );
      }
      throw FormatException(
        'limit second argument must be a variable identifier, got: $v',
      );
    }
    throw FormatException(
      'limit requires 3 or 4 arguments, got ${args.length}',
    );
  }

  static LimitDirection _parseLimitDirection(Expr dirExpr) => switch (dirExpr) {
    IntegerNumber(isZero: true) ||
    Variable(name: 'both') => LimitDirection.both,
    IntegerNumber(isOne: true) ||
    Variable(name: 'fromAbove' || 'right') => LimitDirection.fromAbove,
    IntegerNumber(isNegativeOne: true) ||
    Variable(name: 'fromBelow' || 'left') => LimitDirection.fromBelow,
    _ => throw FormatException(
      'Invalid limit direction: $dirExpr (expected -1, 0, 1, fromBelow, both, or fromAbove)',
    ),
  };

  static Expr _parseSumArgs(List<Expr> args) {
    if (args case [final expr, final v, final lower, final upper]) {
      final vName = _asVariableName(v);
      if (vName != null) {
        return Sum(_unbindConstant(expr, v, vName), vName, lower, upper);
      }
      throw FormatException(
        'sum second argument must be a variable identifier, got: $v',
      );
    }
    throw FormatException('sum requires 4 arguments, got ${args.length}');
  }

  static Expr _parseProductArgs(List<Expr> args) {
    if (args case [final expr, final v, final lower, final upper]) {
      final vName = _asVariableName(v);
      if (vName != null) {
        return Product(_unbindConstant(expr, v, vName), vName, lower, upper);
      }
      throw FormatException(
        'product second argument must be a variable identifier, got: $v',
      );
    }
    throw FormatException('product requires 4 arguments, got ${args.length}');
  }

  static Expr _parseRootSumArgs(List<Expr> args) {
    if (args case [final polynomial, final v, final body]) {
      final vName = _asVariableName(v);
      if (vName != null) {
        return RootSum(
          _unbindConstant(polynomial, v, vName),
          vName,
          _unbindConstant(body, v, vName),
        );
      }
      throw FormatException(
        'rootsum second argument must be a variable identifier, got: $v',
      );
    }
    throw FormatException('rootsum requires 3 arguments, got ${args.length}');
  }

  static Expr _unbindConstant(Expr expr, Expr varToken, String varName) {
    if (varToken is Variable) return expr;
    Expr visit(Expr node) {
      if (node == varToken) return Variable(varName);
      if (varName == 'i' && node is ComplexNumber) {
        final imagExpr = switch (node.imaginary) {
          IntegerNumber(isOne: true) => Variable(varName),
          IntegerNumber(isNegativeOne: true) => -Variable(varName),
          _ => node.imaginary * Variable(varName),
        };
        return node.real.isZero ? imagExpr : node.real + imagExpr;
      }
      if (varName == 'e' && node is Pow && node.base == Constant.e) {
        if (_isExpFunction[node] == true) {
          final res = Pow(Constant.e, visit(node.exponent));
          _isExpFunction[res] = true;
          return res;
        }
        return Pow(visit(node.base), visit(node.exponent));
      }
      if (node
          case Integral(
            :final integrand,
            :final variable,
            lower: final low?,
            upper: final up?,
          )
          when variable == varName) {
        return Integral(
          integrand,
          variable,
          lower: visit(low),
          upper: visit(up),
        );
      }
      if (node
          case Derivative(
            :final expr,
            :final variable,
            :final order,
            point: final pt?,
          )
          when variable == varName) {
        return Derivative(expr, variable, order: order, point: visit(pt));
      }
      if (node is Limit && node.variable == varName) {
        return Limit(
          node.expr,
          node.variable,
          visit(node.point),
          direction: node.direction,
        );
      }
      if (node is Sum && node.variable == varName) {
        return Sum(
          node.expr,
          node.variable,
          visit(node.lower),
          visit(node.upper),
        );
      }
      if (node is Product && node.variable == varName) {
        return Product(
          node.expr,
          node.variable,
          visit(node.lower),
          visit(node.upper),
        );
      }
      if (node is RootSum && node.variable == varName) {
        return node;
      }
      return node.mapChildren(visit);
    }

    return visit(expr);
  }

  static String? _asVariableName(Expr expr) => switch (expr) {
    Variable(:final name) => name,
    ComplexNumber(:final real, :final imaginary)
        when real.isZero && imaginary.isOne =>
      'i',
    Constant.e => 'e',
    Constant.pi => 'pi',
    _ => null,
  };

  static Expr _parseEllipticPiArgs(List<Expr> args) => switch (args) {
    [final n, final k] => EllipticPi(n, FractionNumber.half * Constant.pi, k),
    [final n, final phi, final k] => EllipticPi(n, phi, k),
    _ => throw const FormatException('elliptic_pi requires 2 or 3 arguments'),
  };

  static Expr _parseHypergeometricArgs(List<Expr> args) {
    if (args.length != 3) {
      throw FormatException(
        'hypergeometric requires 3 arguments, got ${args.length}',
      );
    }
    List<Expr> unpack(Expr e) => switch (e) {
      Tuple(:final args) => args,
      _ => [e],
    };
    return Hypergeometric(unpack(args[0]), unpack(args[1]), args[2]);
  }

  static Expr _parseAppellF1Args(List<Expr> args) {
    if (args.length != 6) {
      throw FormatException(
        'appellF1 requires 6 arguments, got ${args.length}',
      );
    }
    return AppellF1(args[0], args[1], args[2], args[3], args[4], args[5]);
  }

  static Expr _parseOrthogonal(
    String name,
    Expr nExpr,
    Expr x,
    Expr Function(int, Expr) builder,
  ) {
    if (nExpr case IntegerNumber(asInt: final n?) when n >= 0) {
      return builder(n, x);
    }
    throw FormatException(
      '$name degree must be a non-negative integer, got: $nExpr',
    );
  }

  static Expr _parseLaguerreLArgs(List<Expr> args) => switch (args) {
    [final nExpr, final x] => _parseOrthogonal(
      'laguerreL',
      nExpr,
      x,
      laguerreL,
    ),
    [final nExpr, final x, final alpha] => switch (nExpr) {
      IntegerNumber(asInt: final n?) when n >= 0 => laguerreL(n, x, alpha),
      _ => throw FormatException(
        'laguerreL degree must be a non-negative integer, got: $nExpr',
      ),
    },
    _ => throw FormatException(
      'laguerreL requires 2 or 3 arguments, got ${args.length}',
    ),
  };
}
