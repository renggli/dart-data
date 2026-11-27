import 'package:more/number.dart' show Complex;

import '../../special/bessel.dart' as special_bessel;
import '../../special/beta.dart' as special_beta;
import '../../special/digamma.dart' as special_digamma;
import '../../special/elliptic.dart' as special_elliptic;
import '../../special/erf.dart' as special_erf;
import '../../special/exp_integral.dart' as special_exp_int;
import '../../special/fresnel.dart' as special_fresnel;
import '../../special/gamma.dart' as special_gamma;
import '../../special/hypergeometric.dart' as special_hyper;
import '../../special/lambert_w.dart' as special_lambert;
import '../../special/polylog.dart' as special_polylog;
import '../../special/trig_integral.dart' as special_trig_int;
import '../../special/zeta.dart' as special_zeta;
import '../algebra/simplify.dart';
import '../ast.dart';
import 'elementary_specs.dart';

/// Spec for `erf(z)`.
const erfSpec = UnaryFunctionSpec(
  id: FunctionId.erf,
  name: 'erf',
  params: ['z'],
  doc: 'Error function',
  category: FunctionCategory.special,
  parity: FunctionParity.odd,
  evalReal: special_erf.erf,
  evalComplex: special_erf.erfComplex,
  derivativeRule: _diffErf,
);

/// Spec for `erfc(z)`.
const erfcSpec = UnaryFunctionSpec(
  id: FunctionId.erfc,
  name: 'erfc',
  params: ['z'],
  doc: 'Complementary error function',
  category: FunctionCategory.special,
  evalReal: special_erf.erfc,
  evalComplex: special_erf.erfcComplex,
  derivativeRule: _diffErfc,
);

/// Spec for `erfi(z)`.
const erfiSpec = UnaryFunctionSpec(
  id: FunctionId.erfi,
  name: 'erfi',
  params: ['z'],
  doc: 'Imaginary error function',
  category: FunctionCategory.special,
  parity: FunctionParity.odd,
  evalReal: special_erf.erfi,
  evalComplex: special_erf.erfiComplex,
  derivativeRule: _diffErfi,
);

/// Spec for `fresnelS(z)`.
const fresnelSSpec = UnaryFunctionSpec(
  id: FunctionId.fresnelS,
  name: 'fresnelS',
  params: ['z'],
  doc: 'Fresnel sine integral S(z)',
  category: FunctionCategory.special,
  parity: FunctionParity.odd,
  latexName: 'S',
  mathMlName: 'S',
  evalReal: special_fresnel.fresnelS,
  evalComplex: special_fresnel.fresnelSComplex,
  derivativeRule: _diffFresnelS,
);

/// Spec for `fresnelC(z)`.
const fresnelCSpec = UnaryFunctionSpec(
  id: FunctionId.fresnelC,
  name: 'fresnelC',
  params: ['z'],
  doc: 'Fresnel cosine integral C(z)',
  category: FunctionCategory.special,
  parity: FunctionParity.odd,
  latexName: 'C',
  mathMlName: 'C',
  evalReal: special_fresnel.fresnelC,
  evalComplex: special_fresnel.fresnelCComplex,
  derivativeRule: _diffFresnelC,
);

/// Spec for `Ei(x)`.
const eiSpec = UnaryFunctionSpec(
  id: FunctionId.ei,
  name: 'Ei',
  params: ['x'],
  doc: 'Exponential integral Ei(x)',
  category: FunctionCategory.special,
  evalReal: special_exp_int.expIntegral,
  evalComplex: special_exp_int.expIntegralComplex,
  derivativeRule: _diffEi,
);

/// Spec for `expIntegralE(n, x)`.
const expIntegralESpec = BinaryFunctionSpec(
  id: FunctionId.expIntegralE,
  name: 'expIntegralE',
  params: ['n', 'x'],
  doc: 'Generalized exponential integral E_n(x)',
  category: FunctionCategory.special,
  evalReal: special_exp_int.expIntegralE,
  evalComplex: special_exp_int.expIntegralEComplex,
  derivativeRule: _diffExpIntegralE,
  customLatex: _latexExpIntegralE,
  customMathMl: _mathMlExpIntegralE,
);

/// Spec for `li(x)`.
const liSpec = UnaryFunctionSpec(
  id: FunctionId.li,
  name: 'li',
  params: ['x'],
  doc: 'Logarithmic integral li(x)',
  category: FunctionCategory.special,
  evalReal: special_exp_int.logIntegral,
  evalComplex: special_exp_int.logIntegralComplex,
  derivativeRule: _diffLi,
);

/// Spec for `Si(x)`.
const siSpec = UnaryFunctionSpec(
  id: FunctionId.si,
  name: 'Si',
  params: ['x'],
  doc: 'Sine integral Si(x)',
  category: FunctionCategory.special,
  parity: FunctionParity.odd,
  evalReal: special_trig_int.sinIntegral,
  evalComplex: special_trig_int.sinIntegralComplex,
  derivativeRule: _diffSi,
);

/// Spec for `Ci(x)`.
const ciSpec = UnaryFunctionSpec(
  id: FunctionId.ci,
  name: 'Ci',
  params: ['x'],
  doc: 'Cosine integral Ci(x)',
  category: FunctionCategory.special,
  evalReal: special_trig_int.cosIntegral,
  evalComplex: special_trig_int.cosIntegralComplex,
  derivativeRule: _diffCi,
);

/// Spec for `Shi(x)`.
const shiSpec = UnaryFunctionSpec(
  id: FunctionId.shi,
  name: 'Shi',
  params: ['x'],
  doc: 'Hyperbolic sine integral Shi(x)',
  category: FunctionCategory.special,
  parity: FunctionParity.odd,
  evalReal: special_trig_int.sinhIntegral,
  evalComplex: special_trig_int.sinhIntegralComplex,
  derivativeRule: _diffShi,
);

/// Spec for `Chi(x)`.
const chiSpec = UnaryFunctionSpec(
  id: FunctionId.chi,
  name: 'Chi',
  params: ['x'],
  doc: 'Hyperbolic cosine integral Chi(x)',
  category: FunctionCategory.special,
  evalReal: special_trig_int.coshIntegral,
  evalComplex: special_trig_int.coshIntegralComplex,
  derivativeRule: _diffChi,
);

/// Spec for `gamma(z)`.
const gammaSpec = UnaryFunctionSpec(
  id: FunctionId.gamma,
  name: 'gamma',
  params: ['z'],
  doc: 'Euler gamma function',
  category: FunctionCategory.special,
  latexName: r'\Gamma',
  mathMlName: 'Γ',
  evalReal: special_gamma.gamma,
  evalComplex: special_gamma.gammaComplex,
  derivativeRule: _diffGamma,
);

/// Spec for `upperGamma(s, x)`.
const upperGammaSpec = BinaryFunctionSpec(
  id: FunctionId.upperGamma,
  name: 'upperGamma',
  params: ['s', 'x'],
  doc: 'Upper incomplete gamma function',
  category: FunctionCategory.special,
  latexName: r'\Gamma',
  mathMlName: 'Γ',
  evalReal: special_gamma.upperGamma,
  evalComplex: special_gamma.upperGammaComplex,
  derivativeRule: _diffUpperGamma,
);

/// Spec for `lowerGamma(s, x)`.
const lowerGammaSpec = BinaryFunctionSpec(
  id: FunctionId.lowerGamma,
  name: 'lowerGamma',
  params: ['s', 'x'],
  doc: 'Lower incomplete gamma function',
  category: FunctionCategory.special,
  latexName: r'\gamma',
  mathMlName: 'γ',
  evalReal: special_gamma.lowerGamma,
  evalComplex: special_gamma.lowerGammaComplex,
  derivativeRule: _diffLowerGamma,
);

/// Spec for `logGamma(z)`.
const logGammaSpec = UnaryFunctionSpec(
  id: FunctionId.logGamma,
  name: 'logGamma',
  params: ['z'],
  doc: 'Natural logarithm of the gamma function',
  category: FunctionCategory.special,
  latexName: r'\ln\Gamma',
  evalReal: _evalRealLogGamma,
  evalComplex: _evalComplexLogGamma,
  derivativeRule: _diffLogGamma,
  customMathMl: _mathMlLogGamma,
);

/// Spec for `digamma(z)`.
const digammaSpec = UnaryFunctionSpec(
  id: FunctionId.digamma,
  name: 'digamma',
  params: ['z'],
  doc: 'Digamma function psi(z)',
  category: FunctionCategory.special,
  latexName: r'\psi',
  mathMlName: 'ψ',
  evalReal: special_digamma.digamma,
  evalComplex: special_digamma.digammaComplex,
  derivativeRule: _diffDigamma,
);

/// Spec for `polygamma(n, z)`.
const polygammaSpec = BinaryFunctionSpec(
  id: FunctionId.polygamma,
  name: 'polygamma',
  params: ['n', 'z'],
  doc: 'Polygamma function psi^(n)(z)',
  category: FunctionCategory.special,
  evalReal: _evalRealPolygamma,
  evalComplex: _evalComplexPolygamma,
  derivativeRule: _diffPolygamma,
  customLatex: _latexPolygamma,
  customMathMl: _mathMlPolygamma,
);

/// Spec for `zeta(s)` and `zeta(s, a)`.
const zetaSpec = OptionalBinaryFunctionSpec(
  id: FunctionId.zeta,
  name: 'zeta',
  params: ['s', '[a]'],
  doc: 'Riemann or Hurwitz zeta function',
  category: FunctionCategory.special,
  latexName: r'\zeta',
  mathMlName: 'ζ',
  evalReal: _evalRealZeta,
  evalComplex: _evalComplexZeta,
  derivativeRule: _diffZeta,
);

/// Spec for `beta(a, b)`.
const betaSpec = BinaryFunctionSpec(
  id: FunctionId.beta,
  name: 'beta',
  params: ['a', 'b'],
  doc: 'Euler beta function B(a, b)',
  category: FunctionCategory.special,
  latexName: r'\operatorname{B}',
  mathMlName: 'B',
  evalReal: special_beta.beta,
  evalComplex: special_beta.betaComplex,
  derivativeRule: _diffBeta,
);

/// Spec for `polylog(s, z)`.
const polylogSpec = BinaryFunctionSpec(
  id: FunctionId.polylog,
  name: 'polylog',
  params: ['s', 'z'],
  doc: 'Polylogarithm Li_s(z)',
  category: FunctionCategory.special,
  evalReal: special_polylog.polylog,
  evalComplex: special_polylog.polylogComplex,
  derivativeRule: _diffPolylog,
  customLatex: _latexPolylog,
  customMathMl: _mathMlPolylog,
);

/// Spec for `besselJ(n, z)`.
const besselJSpec = BinaryFunctionSpec(
  id: FunctionId.besselJ,
  name: 'besselJ',
  params: ['n', 'z'],
  doc: 'Bessel function of the first kind J_n(z)',
  category: FunctionCategory.special,
  evalReal: special_bessel.besselJ,
  evalComplex: special_bessel.besselJComplex,
  derivativeRule: _diffBesselJ,
  customLatex: _latexBesselJ,
  customMathMl: _mathMlBesselJ,
);

/// Spec for `besselY(n, z)`.
const besselYSpec = BinaryFunctionSpec(
  id: FunctionId.besselY,
  name: 'besselY',
  params: ['n', 'z'],
  doc: 'Bessel function of the second kind Y_n(z)',
  category: FunctionCategory.special,
  evalReal: special_bessel.besselY,
  evalComplex: special_bessel.besselYComplex,
  derivativeRule: _diffBesselY,
  customLatex: _latexBesselY,
  customMathMl: _mathMlBesselY,
);

/// Spec for `besselI(n, z)`.
const besselISpec = BinaryFunctionSpec(
  id: FunctionId.besselI,
  name: 'besselI',
  params: ['n', 'z'],
  doc: 'Modified Bessel function of the first kind I_n(z)',
  category: FunctionCategory.special,
  evalReal: special_bessel.besselI,
  evalComplex: special_bessel.besselIComplex,
  derivativeRule: _diffBesselI,
  customLatex: _latexBesselI,
  customMathMl: _mathMlBesselI,
);

/// Spec for `besselK(n, z)`.
const besselKSpec = BinaryFunctionSpec(
  id: FunctionId.besselK,
  name: 'besselK',
  params: ['n', 'z'],
  doc: 'Modified Bessel function of the second kind K_n(z)',
  category: FunctionCategory.special,
  evalReal: special_bessel.besselK,
  evalComplex: special_bessel.besselKComplex,
  derivativeRule: _diffBesselK,
  customLatex: _latexBesselK,
  customMathMl: _mathMlBesselK,
);

/// Spec for `ellipticK(k)`.
const ellipticKSpec = UnaryFunctionSpec(
  id: FunctionId.ellipticK,
  name: 'ellipticK',
  params: ['k'],
  doc: 'Complete elliptic integral of the first kind K(k)',
  category: FunctionCategory.special,
  latexName: 'K',
  mathMlName: 'K',
  evalReal: special_elliptic.ellipticK,
  evalComplex: special_elliptic.ellipticKComplex,
  derivativeRule: _diffEllipticK,
);

/// Spec for `ellipticE(k)` or `ellipticE(phi, k)`.
const ellipticESpec = OptionalBinaryFunctionSpec(
  id: FunctionId.ellipticE,
  name: 'ellipticE',
  params: ['phi_or_k', '[k]'],
  doc: 'Complete or incomplete elliptic integral of the second kind',
  category: FunctionCategory.special,
  latexName: 'E',
  mathMlName: 'E',
  evalReal: _evalRealEllipticE,
  evalComplex: _evalComplexEllipticE,
  derivativeRule: _diffEllipticE,
);

/// Spec for `ellipticF(phi, k)`.
const ellipticFSpec = BinaryFunctionSpec(
  id: FunctionId.ellipticF,
  name: 'ellipticF',
  params: ['phi', 'k'],
  doc: 'Incomplete elliptic integral of the first kind F(phi, k)',
  category: FunctionCategory.special,
  latexName: 'F',
  mathMlName: 'F',
  evalReal: special_elliptic.ellipticF,
  evalComplex: special_elliptic.ellipticFComplex,
  derivativeRule: _diffEllipticF,
);

/// Spec for `ellipticPi(n, phi, k)`.
const ellipticPiSpec = TernaryFunctionSpec(
  id: FunctionId.ellipticPi,
  name: 'ellipticPi',
  params: ['n', 'phi', 'k'],
  doc: 'Incomplete elliptic integral of the third kind Pi(n; phi | k)',
  category: FunctionCategory.special,
  evalReal: _evalRealEllipticPi,
  evalComplex: _evalComplexEllipticPi,
  derivativeRule: _diffEllipticPi,
  customLatex: _latexEllipticPi,
  customMathMl: _mathMlEllipticPi,
);

/// Spec for `hypergeometric(upperTuple, lowerTuple, z)`.
const hypergeometricSpec = TernaryFunctionSpec(
  id: FunctionId.hypergeometric,
  name: 'hypergeometric',
  params: ['upper', 'lower', 'z'],
  doc: 'Generalized hypergeometric function pFq',
  category: FunctionCategory.special,
  evalReal: _unsupportedRealHyper,
  evalComplex: _unsupportedComplexHyper,
  derivativeRule: _diffHypergeometric,
  customLatex: _latexHypergeometric,
  customMathMl: _mathMlHypergeometric,
);

/// Spec for `appellF1(a, b1, b2, c, x, y)`.
const appellF1Spec = VariadicFunctionSpec(
  id: FunctionId.appellF1,
  name: 'appellF1',
  params: ['a', 'b1', 'b2', 'c', 'x', 'y'],
  doc: 'Appell hypergeometric function F_1(a; b1, b2; c; x, y)',
  category: FunctionCategory.special,
  minArity: 6,
  maxArity: 6,
  evalReal: _evalRealAppellF1,
  evalComplex: _evalComplexAppellF1,
  derivativeRule: _diffAppellF1,
  customLatex: _latexAppellF1,
  customMathMl: _mathMlAppellF1,
);

/// Spec for `lambertW(z, [k])`.
const lambertWSpec = OptionalBinaryFunctionSpec(
  id: FunctionId.lambertW,
  name: 'lambertW',
  params: ['z', '[k]'],
  doc: 'Lambert W function (principal branch or k = -1)',
  category: FunctionCategory.special,
  evalReal: _evalRealLambertW,
  evalComplex: _evalComplexLambertW,
  derivativeRule: _diffLambertW,
  customLatex: _latexLambertW,
  customMathMl: _mathMlLambertW,
);

double _evalRealLogGamma(double x) =>
    x <= 0.0 ? double.nan : special_gamma.gammaLn(x);

Complex _evalComplexLogGamma(Complex z) =>
    special_gamma.gammaLnComplex(normalizeComplexZero(z));

double _evalRealPolygamma(double m, double x) {
  if (!m.isFinite || m < 0.0 || m != m.roundToDouble()) return double.nan;
  return special_digamma.polygamma(m.toInt(), x);
}

Complex _evalComplexPolygamma(Complex zM, Complex zX) {
  if (zM.isNaN || zX.isNaN) return Complex.nan;
  if (!zM.isFinite ||
      zM.b != 0.0 ||
      zM.a < 0.0 ||
      zM.a != zM.a.roundToDouble()) {
    throw UnsupportedError(
      'Complex Polygamma order must be a non-negative real integer',
    );
  }
  return special_digamma.polygammaComplex(zM.a.toInt(), zX);
}

double _evalRealZeta(List<double> args) => args.length == 1
    ? special_zeta.zeta(args[0])
    : special_zeta.hurwitzZeta(args[0], args[1]);

Complex _evalComplexZeta(List<Complex> args) => args.length == 1
    ? special_zeta.zetaComplex(args[0])
    : special_zeta.hurwitzZetaComplex(args[0], args[1]);

double _evalRealEllipticE(List<double> args) => args.length == 1
    ? special_elliptic.ellipticE(args[0])
    : special_elliptic.ellipticE(args[1], phi: args[0]);

Complex _evalComplexEllipticE(List<Complex> args) => args.length == 1
    ? special_elliptic.ellipticEComplex(args[0])
    : special_elliptic.ellipticEComplex(args[1], phi: args[0]);

double _evalRealEllipticPi(double n, double phi, double k) =>
    special_elliptic.ellipticPi(n, k, phi: phi);

Complex _evalComplexEllipticPi(Complex n, Complex phi, Complex k) =>
    special_elliptic.ellipticPiComplex(n, k, phi: phi);

double _unsupportedRealHyper(double a, double b, double c) =>
    throw UnsupportedError('hypergeometric requires tuple parameters');

Complex _unsupportedComplexHyper(Complex a, Complex b, Complex c) =>
    throw UnsupportedError('hypergeometric requires tuple parameters');

double _evalRealAppellF1(List<double> args) => special_hyper.appellF1(
  args[0],
  args[1],
  args[2],
  args[3],
  args[4],
  args[5],
);

Complex _evalComplexAppellF1(List<Complex> args) => special_hyper
    .appellF1Complex(args[0], args[1], args[2], args[3], args[4], args[5]);

double _evalRealLambertW(List<double> args) {
  final branch = args.length > 1 ? args[1].round() : 0;
  return branch == 0
      ? special_lambert.lambertW(args[0])
      : special_lambert.lambertW(args[0], branch: branch);
}

Complex _evalComplexLambertW(List<Complex> args) {
  final branch = args.length > 1 ? args[1].a.round() : 0;
  return branch == 0
      ? special_lambert.lambertWComplex(args[0])
      : special_lambert.lambertWComplex(args[0], branch: branch);
}

Expr _diffErf(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) =>
    (IntegerNumber.two / Pow.of(Constant.pi, FractionNumber.half)) *
    Pow.of(Constant.e, -Pow.of(args[0], IntegerNumber.two)) *
    diff(args[0]);

Expr _diffErfc(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) =>
    (IntegerNumber.of(-2) / Pow.of(Constant.pi, FractionNumber.half)) *
    Pow.of(Constant.e, -Pow.of(args[0], IntegerNumber.two)) *
    diff(args[0]);

Expr _diffErfi(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) =>
    (IntegerNumber.two / Pow.of(Constant.pi, FractionNumber.half)) *
    Pow.of(Constant.e, Pow.of(args[0], IntegerNumber.two)) *
    diff(args[0]);

Expr _diffFresnelS(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) =>
    sinSpec(
      Constant.pi * Pow.of(args[0], IntegerNumber.two) / IntegerNumber.two,
    ) *
    diff(args[0]);

Expr _diffFresnelC(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) =>
    cosSpec(
      Constant.pi * Pow.of(args[0], IntegerNumber.two) / IntegerNumber.two,
    ) *
    diff(args[0]);

Expr _diffEi(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) => (Pow.of(Constant.e, args[0]) / args[0]) * diff(args[0]);

Expr? _diffExpIntegralE(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) {
  final n = args[0];
  final x = args[1];
  if (n.dependsOn(variable)) return null;
  return -expIntegralESpec(n - IntegerNumber.one, x) * diff(x);
}

Expr _diffLi(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) => diff(args[0]) / lnSpec(args[0]);

Expr _diffSi(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) => (sinSpec(args[0]) / args[0]) * diff(args[0]);

Expr _diffCi(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) => (cosSpec(args[0]) / args[0]) * diff(args[0]);

Expr _diffShi(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) => (sinhSpec(args[0]) / args[0]) * diff(args[0]);

Expr _diffChi(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) => (coshSpec(args[0]) / args[0]) * diff(args[0]);

Expr _diffGamma(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) => gammaSpec(args[0]) * digammaSpec(args[0]) * diff(args[0]);

Expr _diffDigamma(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) => polygammaSpec(IntegerNumber.one, args[0]) * diff(args[0]);

Expr _diffLogGamma(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) => digammaSpec(args[0]) * diff(args[0]);

Expr? _diffPolygamma(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) {
  if (args[0].dependsOn(variable)) return null;
  return polygammaSpec(args[0] + IntegerNumber.one, args[1]) * diff(args[1]);
}

Expr? _diffZeta(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) {
  if (args.length < 2 || args[0].dependsOn(variable)) return null;
  return -args[0] *
      zetaSpec(args[0] + IntegerNumber.one, args[1]) *
      diff(args[1]);
}

Expr _diffBeta(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) {
  final a = args[0];
  final b = args[1];
  return betaSpec(a, b) *
      (diff(a) * (digammaSpec(a) - digammaSpec(a + b)) +
          diff(b) * (digammaSpec(b) - digammaSpec(a + b)));
}

Expr? _diffUpperGamma(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) {
  final s = args[0];
  final x = args[1];
  if (s.dependsOn(variable)) return null;
  return -Pow.of(x, s - IntegerNumber.one) * Pow.of(Constant.e, -x) * diff(x);
}

Expr? _diffLowerGamma(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) {
  final s = args[0];
  final x = args[1];
  if (s.dependsOn(variable)) return null;
  return Pow.of(x, s - IntegerNumber.one) * Pow.of(Constant.e, -x) * diff(x);
}

Expr? _diffPolylog(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) {
  final s = args[0];
  final z = args[1];
  if (s.dependsOn(variable)) return null;
  return s == IntegerNumber.one
      ? diff(z) / (IntegerNumber.one - z)
      : (polylogSpec(s - IntegerNumber.one, z) * diff(z)) / z;
}

Expr? _diffBesselJ(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) {
  final n = args[0];
  final x = args[1];
  if (n.dependsOn(variable)) return null;
  return n == IntegerNumber.zero
      ? -besselJSpec(IntegerNumber.one, x) * diff(x)
      : FractionNumber.half *
            (besselJSpec(n - IntegerNumber.one, x) -
                besselJSpec(n + IntegerNumber.one, x)) *
            diff(x);
}

Expr? _diffBesselY(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) {
  final n = args[0];
  final x = args[1];
  if (n.dependsOn(variable)) return null;
  return n == IntegerNumber.zero
      ? -besselYSpec(IntegerNumber.one, x) * diff(x)
      : FractionNumber.half *
            (besselYSpec(n - IntegerNumber.one, x) -
                besselYSpec(n + IntegerNumber.one, x)) *
            diff(x);
}

Expr? _diffBesselI(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) {
  final n = args[0];
  final x = args[1];
  if (n.dependsOn(variable)) return null;
  return n == IntegerNumber.zero
      ? besselISpec(IntegerNumber.one, x) * diff(x)
      : FractionNumber.half *
            (besselISpec(n - IntegerNumber.one, x) +
                besselISpec(n + IntegerNumber.one, x)) *
            diff(x);
}

Expr? _diffBesselK(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) {
  final n = args[0];
  final x = args[1];
  if (n.dependsOn(variable)) return null;
  return n == IntegerNumber.zero
      ? -besselKSpec(IntegerNumber.one, x) * diff(x)
      : FractionNumber.negativeHalf *
            (besselKSpec(n - IntegerNumber.one, x) +
                besselKSpec(n + IntegerNumber.one, x)) *
            diff(x);
}

Expr _diffEllipticK(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) {
  final k = args[0];
  final oneMinusK2 = IntegerNumber.one - Pow.of(k, IntegerNumber.two);
  return ((ellipticESpec(k) - oneMinusK2 * ellipticKSpec(k)) /
          (k * oneMinusK2)) *
      diff(k);
}

Expr _diffEllipticE(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) {
  if (args.length == 1) {
    final k = args[0];
    return ((ellipticESpec(k) - ellipticKSpec(k)) / k) * diff(k);
  }
  final phi = args[0];
  final k = args[1];
  final terms = <Expr>[];
  if (phi.dependsOn(variable)) {
    final delta =
        IntegerNumber.one -
        Pow.of(k, IntegerNumber.two) * Pow.of(sinSpec(phi), IntegerNumber.two);
    terms.add(Pow.of(delta, FractionNumber.half) * diff(phi));
  }
  if (k.dependsOn(variable)) {
    final dEdk = (ellipticESpec(phi, k) - ellipticFSpec(phi, k)) / k;
    terms.add(dEdk * diff(k));
  }
  return Add.of(terms);
}

Expr _diffEllipticF(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) {
  final phi = args[0];
  final k = args[1];
  final delta =
      IntegerNumber.one -
      Pow.of(k, IntegerNumber.two) * Pow.of(sinSpec(phi), IntegerNumber.two);
  final terms = <Expr>[];
  if (phi.dependsOn(variable)) {
    terms.add(diff(phi) * Pow.of(delta, FractionNumber.negativeHalf));
  }
  if (k.dependsOn(variable)) {
    final oneMinusK2 = IntegerNumber.one - Pow.of(k, IntegerNumber.two);
    final dFdk =
        (ellipticESpec(phi, k) -
            oneMinusK2 * ellipticFSpec(phi, k) -
            Pow.of(k, IntegerNumber.two) *
                sinSpec(phi) *
                cosSpec(phi) *
                Pow.of(delta, FractionNumber.negativeHalf)) /
        (k * oneMinusK2);
    terms.add(dFdk * diff(k));
  }
  return Add.of(terms);
}

Expr _diffEllipticPi(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) {
  final n = args[0];
  final phi = args[1];
  final k = args[2];
  final terms = <Expr>[];
  final sinPhi = sinSpec(phi);
  final sin2Phi = Pow.of(sinPhi, IntegerNumber.two);
  final k2 = Pow.of(k, IntegerNumber.two);
  final delta = IntegerNumber.one - k2 * sin2Phi;
  final oneMinusNSin2 = IntegerNumber.one - n * sin2Phi;
  if (phi.dependsOn(variable)) {
    final dPidPhi =
        Pow.of(oneMinusNSin2, IntegerNumber.negativeOne) *
        Pow.of(delta, FractionNumber.negativeHalf);
    terms.add(dPidPhi * diff(phi));
  }
  if (k.dependsOn(variable)) {
    final k2Minus1 = k2 - IntegerNumber.one;
    final dPidK =
        (k / (n - k2)) *
        (ellipticESpec(phi, k) / k2Minus1 +
            ellipticPiSpec(n, phi, k) -
            (k2 * sinPhi * cosSpec(phi)) /
                (k2Minus1 * Pow.of(delta, FractionNumber.half)));
    terms.add(dPidK * diff(k));
  }
  if (n.dependsOn(variable)) {
    final dPidN =
        (ellipticESpec(phi, k) +
            ((k2 - n) / n) * ellipticFSpec(phi, k) +
            ((Pow.of(n, IntegerNumber.two) - k2) / n) *
                ellipticPiSpec(n, phi, k) -
            (n * sinPhi * cosSpec(phi) * Pow.of(delta, FractionNumber.half)) /
                oneMinusNSin2) /
        (IntegerNumber.two * (k2 - n) * (n - IntegerNumber.one));
    terms.add(dPidN * diff(n));
  }
  return Add.of(terms);
}

Expr? _diffHypergeometric(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) {
  final upper = _unpackTuple(args[0]);
  final lower = _unpackTuple(args[1]);
  final z = args[2];
  if (upper.any((e) => e.dependsOn(variable)) ||
      lower.any((e) => e.dependsOn(variable))) {
    return null;
  }
  final numProd = Mul.of(upper);
  final denProd = Mul.of(lower);
  final nextUpper = Call(
    const VariadicFunctionSpec(
      id: FunctionId.tuple,
      name: 'tuple',
      params: ['a', '...'],
      doc: '',
      category: FunctionCategory.structural,
      evalReal: _unusedTupleReal,
      evalComplex: _unusedTupleComplex,
    ),
    [for (final u in upper) u + IntegerNumber.one],
  );
  final nextLower = Call(nextUpper.spec, [
    for (final l in lower) l + IntegerNumber.one,
  ]);
  return (numProd / denProd) *
      hypergeometricSpec(nextUpper, nextLower, z) *
      diff(z);
}

double _unusedTupleReal(List<double> args) => double.nan;
Complex _unusedTupleComplex(List<Complex> args) => Complex.nan;

List<Expr> _unpackTuple(Expr e) =>
    e is Call && e.id == FunctionId.tuple ? e.args : [e];

Expr? _diffAppellF1(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) {
  final a = args[0];
  final b1 = args[1];
  final b2 = args[2];
  final c = args[3];
  final x = args[4];
  final y = args[5];
  if (a.dependsOn(variable) ||
      b1.dependsOn(variable) ||
      b2.dependsOn(variable) ||
      c.dependsOn(variable)) {
    return null;
  }
  final dx = diff(x);
  final dy = diff(y);
  if ((c - a - IntegerNumber.one).simplify() == IntegerNumber.zero &&
      !(x is Number && x.isZero) &&
      !(y is Number && y.isZero)) {
    final propDiff = (dx * y - dy * x).simplify();
    if (propDiff == IntegerNumber.zero) {
      return (dx / x) *
          a *
          (Pow.of(IntegerNumber.one - x, -b1) *
                  Pow.of(IntegerNumber.one - y, -b2) -
              appellF1Spec([a, b1, b2, c, x, y]));
    }
  }
  return (a * b1 / c) *
          appellF1Spec([
            a + IntegerNumber.one,
            b1 + IntegerNumber.one,
            b2,
            c + IntegerNumber.one,
            x,
            y,
          ]) *
          dx +
      (a * b2 / c) *
          appellF1Spec([
            a + IntegerNumber.one,
            b1,
            b2 + IntegerNumber.one,
            c + IntegerNumber.one,
            x,
            y,
          ]) *
          dy;
}

Expr _diffLambertW(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) {
  final z = args[0];
  final w = args.length > 1 ? lambertWSpec(z, args[1]) : lambertWSpec(z);
  return diff(z) / (Pow.of(Constant.e, w) * (IntegerNumber.one + w));
}

String _formatSubscriptLatex(
  String symbol,
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
) =>
    '${symbol}_{${formatChild(args[0], decimalPlaces)}}(${formatChild(args[1], decimalPlaces)})';

String _formatSubscriptMathMl(
  String symbol,
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
) =>
    '<mrow><msub><mi>$symbol</mi>${formatChild(args[0], decimalPlaces)}</msub><mo>(</mo>${formatChild(args[1], decimalPlaces)}<mo>)</mo></mrow>';

String _latexExpIntegralE(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) => _formatSubscriptLatex('E', args, decimalPlaces, formatChild);

String _mathMlExpIntegralE(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) => _formatSubscriptMathMl('E', args, decimalPlaces, formatChild);

String _latexPolylog(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) => _formatSubscriptLatex(
  r'\operatorname{Li}',
  args,
  decimalPlaces,
  formatChild,
);

String _mathMlPolylog(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) => _formatSubscriptMathMl('Li', args, decimalPlaces, formatChild);

String _latexBesselJ(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) => _formatSubscriptLatex('J', args, decimalPlaces, formatChild);

String _mathMlBesselJ(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) => _formatSubscriptMathMl('J', args, decimalPlaces, formatChild);

String _latexBesselY(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) => _formatSubscriptLatex('Y', args, decimalPlaces, formatChild);

String _mathMlBesselY(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) => _formatSubscriptMathMl('Y', args, decimalPlaces, formatChild);

String _latexBesselI(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) => _formatSubscriptLatex('I', args, decimalPlaces, formatChild);

String _mathMlBesselI(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) => _formatSubscriptMathMl('I', args, decimalPlaces, formatChild);

String _latexBesselK(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) => _formatSubscriptLatex('K', args, decimalPlaces, formatChild);

String _mathMlBesselK(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) => _formatSubscriptMathMl('K', args, decimalPlaces, formatChild);

String _mathMlLogGamma(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) =>
    '<mrow><mi>ln</mi><mo>&#x2061;</mo><mi>Γ</mi><mo>(</mo>${formatChild(args[0], decimalPlaces)}<mo>)</mo></mrow>';

String _latexPolygamma(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) =>
    '\\psi^{(${formatChild(args[0], decimalPlaces)})}(${formatChild(args[1], decimalPlaces)})';

String _mathMlPolygamma(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) =>
    '<mrow><msup><mi>ψ</mi><mrow><mo>(</mo>${formatChild(args[0], decimalPlaces)}<mo>)</mo></mrow></msup><mo>(</mo>${formatChild(args[1], decimalPlaces)}<mo>)</mo></mrow>';

String _latexEllipticPi(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) =>
    '\\Pi(${formatChild(args[0], decimalPlaces)}; ${formatChild(args[1], decimalPlaces)} \\mid ${formatChild(args[2], decimalPlaces)})';

String _mathMlEllipticPi(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) =>
    '<mrow><mi>Π</mi><mo>(</mo>${formatChild(args[0], decimalPlaces)}<mo>;</mo>${formatChild(args[1], decimalPlaces)}<mo>|</mo>${formatChild(args[2], decimalPlaces)}<mo>)</mo></mrow>';

String _latexHypergeometric(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) {
  final upper = _unpackTuple(args[0]);
  final lower = _unpackTuple(args[1]);
  final z = args[2];
  return '{}_{${upper.length}}F_{${lower.length}}\\left(${upper.map((e) => formatChild(e, decimalPlaces)).join(', ')}; ${lower.map((e) => formatChild(e, decimalPlaces)).join(', ')}; ${formatChild(z, decimalPlaces)}\\right)';
}

String _mathMlHypergeometric(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) {
  final upper = _unpackTuple(args[0]);
  final lower = _unpackTuple(args[1]);
  final z = args[2];
  return '<mrow><mmultiscripts><mi>F</mi><mn>${lower.length}</mn><none/><mprescripts/><mn>${upper.length}</mn><none/></mmultiscripts><mo>(</mo>${upper.map((e) => formatChild(e, decimalPlaces)).join('<mo>,</mo>')}<mo>;</mo>${lower.map((e) => formatChild(e, decimalPlaces)).join('<mo>,</mo>')}<mo>;</mo>${formatChild(z, decimalPlaces)}<mo>)</mo></mrow>';
}

String _latexAppellF1(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) =>
    'F_1\\left(${formatChild(args[0], decimalPlaces)}; ${formatChild(args[1], decimalPlaces)}, ${formatChild(args[2], decimalPlaces)}; ${formatChild(args[3], decimalPlaces)}; ${formatChild(args[4], decimalPlaces)}, ${formatChild(args[5], decimalPlaces)}\\right)';

String _mathMlAppellF1(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) =>
    '<mrow><msub><mi>F</mi><mn>1</mn></msub><mo>(</mo>${formatChild(args[0], decimalPlaces)}<mo>;</mo>${formatChild(args[1], decimalPlaces)}<mo>,</mo>${formatChild(args[2], decimalPlaces)}<mo>;</mo>${formatChild(args[3], decimalPlaces)}<mo>;</mo>${formatChild(args[4], decimalPlaces)}<mo>,</mo>${formatChild(args[5], decimalPlaces)}<mo>)</mo></mrow>';

String _latexLambertW(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) => args.length < 2
    ? 'W(${formatChild(args[0], decimalPlaces)})'
    : 'W_{${formatChild(args[1], decimalPlaces)}}(${formatChild(args[0], decimalPlaces)})';

String _mathMlLambertW(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) => args.length < 2
    ? '<mrow><mi>W</mi><mo>(</mo>${formatChild(args[0], decimalPlaces)}<mo>)</mo></mrow>'
    : '<mrow><msub><mi>W</mi>${formatChild(args[1], decimalPlaces)}</msub><mo>(</mo>${formatChild(args[0], decimalPlaces)}<mo>)</mo></mrow>';
