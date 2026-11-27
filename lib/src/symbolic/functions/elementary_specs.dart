import 'dart:math' as math;

import 'package:more/math.dart';
import 'package:more/number.dart' show Complex;

import '../ast.dart';

/// Shared helper normalizing negative zero in [Complex] branch-cut inputs.
Complex normalizeComplexZero(Complex z) =>
    Complex(z.a == 0.0 ? 0.0 : z.a, z.b == 0.0 ? 0.0 : z.b);

/// Spec for `sin(x)`.
const sinSpec = UnaryFunctionSpec(
  id: FunctionId.sin,
  name: 'sin',
  doc: 'Sine of x (radians)',
  category: FunctionCategory.trig,
  parity: FunctionParity.odd,
  latexName: r'\sin',
  evalReal: math.sin,
  evalComplex: _complexSin,
  unaryDerivative: _dfSin,
);

/// Spec for `cos(x)`.
const cosSpec = UnaryFunctionSpec(
  id: FunctionId.cos,
  name: 'cos',
  doc: 'Cosine of x (radians)',
  category: FunctionCategory.trig,
  parity: FunctionParity.even,
  latexName: r'\cos',
  evalReal: math.cos,
  evalComplex: _complexCos,
  unaryDerivative: _dfCos,
);

/// Spec for `tan(x)`.
const tanSpec = UnaryFunctionSpec(
  id: FunctionId.tan,
  name: 'tan',
  doc: 'Tangent of x (radians)',
  category: FunctionCategory.trig,
  parity: FunctionParity.odd,
  latexName: r'\tan',
  evalReal: math.tan,
  evalComplex: _complexTan,
  unaryDerivative: _dfTan,
);

/// Spec for `asin(x)`.
const asinSpec = UnaryFunctionSpec(
  id: FunctionId.asin,
  name: 'asin',
  doc: 'Inverse sine (arcsine)',
  category: FunctionCategory.trig,
  parity: FunctionParity.odd,
  latexName: r'\arcsin',
  mathMlName: 'arcsin',
  evalReal: math.asin,
  evalComplex: _complexAsin,
  unaryDerivative: _dfAsin,
);

/// Spec for `acos(x)`.
const acosSpec = UnaryFunctionSpec(
  id: FunctionId.acos,
  name: 'acos',
  doc: 'Inverse cosine (arccosine)',
  category: FunctionCategory.trig,
  latexName: r'\arccos',
  mathMlName: 'arccos',
  evalReal: math.acos,
  evalComplex: _complexAcos,
  unaryDerivative: _dfAcos,
);

/// Spec for `atan(x)`.
const atanSpec = UnaryFunctionSpec(
  id: FunctionId.atan,
  name: 'atan',
  doc: 'Inverse tangent (arctangent)',
  category: FunctionCategory.trig,
  parity: FunctionParity.odd,
  latexName: r'\arctan',
  mathMlName: 'arctan',
  evalReal: math.atan,
  evalComplex: _complexAtan,
  unaryDerivative: _dfAtan,
);

/// Spec for `atan2(y, x)`.
const atan2Spec = BinaryFunctionSpec(
  id: FunctionId.atan2,
  name: 'atan2',
  params: ['y', 'x'],
  doc: 'Two-argument arctangent of y / x',
  category: FunctionCategory.trig,
  evalReal: math.atan2,
  evalComplex: _complexAtan2,
  derivativeRule: _diffAtan2,
);

/// Spec for `sinh(x)`.
const sinhSpec = UnaryFunctionSpec(
  id: FunctionId.sinh,
  name: 'sinh',
  doc: 'Hyperbolic sine',
  category: FunctionCategory.hyperbolic,
  parity: FunctionParity.odd,
  latexName: r'\sinh',
  evalReal: _realSinh,
  evalComplex: _complexSinh,
  unaryDerivative: _dfSinh,
);

/// Spec for `cosh(x)`.
const coshSpec = UnaryFunctionSpec(
  id: FunctionId.cosh,
  name: 'cosh',
  doc: 'Hyperbolic cosine',
  category: FunctionCategory.hyperbolic,
  parity: FunctionParity.even,
  latexName: r'\cosh',
  evalReal: _realCosh,
  evalComplex: _complexCosh,
  unaryDerivative: _dfCosh,
);

/// Spec for `tanh(x)`.
const tanhSpec = UnaryFunctionSpec(
  id: FunctionId.tanh,
  name: 'tanh',
  doc: 'Hyperbolic tangent',
  category: FunctionCategory.hyperbolic,
  parity: FunctionParity.odd,
  latexName: r'\tanh',
  evalReal: _realTanh,
  evalComplex: _complexTanh,
  unaryDerivative: _dfTanh,
);

/// Spec for `asinh(x)`.
const asinhSpec = UnaryFunctionSpec(
  id: FunctionId.asinh,
  name: 'asinh',
  doc: 'Inverse hyperbolic sine',
  category: FunctionCategory.hyperbolic,
  parity: FunctionParity.odd,
  latexName: r'\operatorname{arsinh}',
  mathMlName: 'arsinh',
  evalReal: _realAsinh,
  evalComplex: _complexAsinh,
  unaryDerivative: _dfAsinh,
);

/// Spec for `acosh(x)`.
const acoshSpec = UnaryFunctionSpec(
  id: FunctionId.acosh,
  name: 'acosh',
  doc: 'Inverse hyperbolic cosine',
  category: FunctionCategory.hyperbolic,
  latexName: r'\operatorname{arcosh}',
  mathMlName: 'arcosh',
  evalReal: _realAcosh,
  evalComplex: _complexAcosh,
  unaryDerivative: _dfAcosh,
);

/// Spec for `atanh(x)`.
const atanhSpec = UnaryFunctionSpec(
  id: FunctionId.atanh,
  name: 'atanh',
  doc: 'Inverse hyperbolic tangent',
  category: FunctionCategory.hyperbolic,
  parity: FunctionParity.odd,
  latexName: r'\operatorname{artanh}',
  mathMlName: 'artanh',
  evalReal: _realAtanh,
  evalComplex: _complexAtanh,
  unaryDerivative: _dfAtanh,
);

/// Spec for `abs(x)`.
const absSpec = UnaryFunctionSpec(
  id: FunctionId.abs,
  name: 'abs',
  params: ['x'],
  doc: 'Absolute value or complex modulus',
  category: FunctionCategory.elementary,
  parity: FunctionParity.even,
  evalReal: _realAbs,
  evalComplex: _complexAbs,
  derivativeRule: _diffAbs,
  customLatex: _latexAbs,
  customMathMl: _mathMlAbs,
);

/// Spec for `ln(x)`.
const lnSpec = UnaryFunctionSpec(
  id: FunctionId.ln,
  name: 'ln',
  params: ['x'],
  doc: 'Natural logarithm',
  category: FunctionCategory.elementary,
  latexName: r'\ln',
  evalReal: math.log,
  evalComplex: _complexLn,
  derivativeRule: _diffLn,
);

/// Spec for `re(z)`.
const reSpec = UnaryFunctionSpec(
  id: FunctionId.re,
  name: 're',
  params: ['z'],
  doc: 'Real part of z',
  category: FunctionCategory.complex,
  latexName: r'\operatorname{Re}',
  mathMlName: 'Re',
  evalReal: _realIdentity,
  evalComplex: _complexRe,
  derivativeRule: _diffRe,
);

/// Spec for `im(z)`.
const imSpec = UnaryFunctionSpec(
  id: FunctionId.im,
  name: 'im',
  params: ['z'],
  doc: 'Imaginary part of z',
  category: FunctionCategory.complex,
  latexName: r'\operatorname{Im}',
  mathMlName: 'Im',
  evalReal: _realIm,
  evalComplex: _complexIm,
  derivativeRule: _diffIm,
);

/// Spec for `arg(z)`.
const argSpec = UnaryFunctionSpec(
  id: FunctionId.arg,
  name: 'arg',
  params: ['z'],
  doc: 'Principal argument (phase angle) of z',
  category: FunctionCategory.complex,
  latexName: r'\arg',
  evalReal: _realArg,
  evalComplex: _complexArg,
);

/// Spec for `conj(z)`.
const conjSpec = UnaryFunctionSpec(
  id: FunctionId.conj,
  name: 'conj',
  params: ['z'],
  doc: 'Complex conjugate of z',
  category: FunctionCategory.complex,
  evalReal: _realIdentity,
  evalComplex: _complexConj,
  derivativeRule: _diffConj,
  customLatex: _latexConj,
  customMathMl: _mathMlConj,
);

double _realSinh(double x) => x.sinh();
double _realCosh(double x) => x.cosh();
double _realTanh(double x) => x.tanh();
double _realAsinh(double x) => x.asinh();
double _realAcosh(double x) => x.acosh();
double _realAtanh(double x) => x.atanh();
double _realAbs(double x) => x.abs();
double _realIdentity(double x) => x;
double _realIm(double x) => x.isNaN ? double.nan : 0.0;
double _realArg(double x) => x.isNaN ? double.nan : (x < 0.0 ? math.pi : 0.0);

Complex _complexSin(Complex z) => z.sin();
Complex _complexCos(Complex z) => z.cos();
Complex _complexTan(Complex z) => z.tan();
Complex _complexAsin(Complex z) => normalizeComplexZero(z).asin();
Complex _complexAcos(Complex z) => normalizeComplexZero(z).acos();
Complex _complexAtan(Complex z) => normalizeComplexZero(z).atan();
Complex _complexAtan2(Complex y, Complex x) {
  if (x.b == 0.0 && y.b == 0.0) {
    return Complex(math.atan2(y.a.toDouble(), x.a.toDouble()));
  }
  return -Complex.i * ((x + Complex.i * y) / (x * x + y * y).sqrt()).log();
}

Complex _complexSinh(Complex z) => z.sinh();
Complex _complexCosh(Complex z) => z.cosh();
Complex _complexTanh(Complex z) => z.tanh();
Complex _complexAsinh(Complex z) => normalizeComplexZero(z).asinh();
Complex _complexAcosh(Complex z) => normalizeComplexZero(z).acosh();
Complex _complexAtanh(Complex z) => normalizeComplexZero(z).atanh();
Complex _complexAbs(Complex z) => Complex(z.abs());
Complex _complexLn(Complex z) => normalizeComplexZero(z).log();
Complex _complexRe(Complex z) => Complex(z.real);
Complex _complexIm(Complex z) => Complex(z.imaginary);
Complex _complexArg(Complex z) => Complex(z.arg());
Complex _complexConj(Complex z) => z.conjugate();

Expr _dfSin(Expr u) => cosSpec(u);
Expr _dfCos(Expr u) => -sinSpec(u);
Expr _dfTan(Expr u) => Pow.of(cosSpec(u), IntegerNumber.of(-2));
Expr _dfAsin(Expr u) => Pow.of(
  IntegerNumber.one - Pow.of(u, IntegerNumber.two),
  FractionNumber.negativeHalf,
);
Expr _dfAcos(Expr u) => -Pow.of(
  IntegerNumber.one - Pow.of(u, IntegerNumber.two),
  FractionNumber.negativeHalf,
);
Expr _dfAtan(Expr u) => Pow.of(
  IntegerNumber.one + Pow.of(u, IntegerNumber.two),
  IntegerNumber.negativeOne,
);

Expr _diffAtan2(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) {
  final y = args[0];
  final x = args[1];
  return (x * diff(y) - y * diff(x)) /
      (Pow.of(x, IntegerNumber.two) + Pow.of(y, IntegerNumber.two));
}

Expr _dfSinh(Expr u) => coshSpec(u);
Expr _dfCosh(Expr u) => sinhSpec(u);
Expr _dfTanh(Expr u) => Pow.of(coshSpec(u), IntegerNumber.of(-2));
Expr _dfAsinh(Expr u) => Pow.of(
  Pow.of(u, IntegerNumber.two) + IntegerNumber.one,
  FractionNumber.negativeHalf,
);
Expr _dfAcosh(Expr u) =>
    Pow.of(u - IntegerNumber.one, FractionNumber.negativeHalf) *
    Pow.of(u + IntegerNumber.one, FractionNumber.negativeHalf);
Expr _dfAtanh(Expr u) => Pow.of(
  IntegerNumber.one - Pow.of(u, IntegerNumber.two),
  IntegerNumber.negativeOne,
);

Expr _diffAbs(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) => (args[0] / absSpec(args[0])) * diff(args[0]);

Expr _diffLn(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) {
  final inner = args[0];
  if (!isComplexVar) {
    final unwrapped = _unwrapLogAbsFactors(inner);
    if (unwrapped != null) {
      return diff(unwrapped) / unwrapped;
    }
  }
  return diff(inner) / inner;
}

Expr? _unwrapLogAbsFactors(Expr expr) {
  if (expr is Call && expr.id == FunctionId.abs) return expr.args[0];
  if (expr case Pow(
    base: Call(id: FunctionId.abs, args: [final inner]),
    :final exponent,
  )) {
    return Pow.of(inner, exponent);
  }
  if (expr is Mul) {
    var changed = false;
    final factors = <Expr>[
      for (final f in expr.factors)
        if (_unwrapLogAbsFactors(f) case final unwrapped?)
          () {
            changed = true;
            return unwrapped;
          }()
        else
          f,
    ];
    if (changed) return Mul.of(factors);
  }
  return null;
}

Expr? _diffRe(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) => isComplexVar ? null : reSpec(diff(args[0]));

Expr? _diffIm(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) => isComplexVar ? null : imSpec(diff(args[0]));

Expr? _diffConj(
  List<Expr> args,
  String variable,
  Expr Function(Expr) diff, {
  required bool isComplexVar,
}) => isComplexVar ? null : conjSpec(diff(args[0]));

String _latexAbs(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) => '\\left|${formatChild(args[0], decimalPlaces)}\\right|';

String _mathMlAbs(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) => '<mrow><mo>|</mo>${formatChild(args[0], decimalPlaces)}<mo>|</mo></mrow>';

String _latexConj(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) => '\\overline{${formatChild(args[0], decimalPlaces)}}';

String _mathMlConj(
  List<Expr> args,
  int decimalPlaces,
  RichChildFormatter formatChild,
  RichChildFormatter formatPowBase,
) =>
    '<mover><mrow>${formatChild(args[0], decimalPlaces)}</mrow><mo>&#x00AF;</mo></mover>';
