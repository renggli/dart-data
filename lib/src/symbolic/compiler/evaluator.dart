import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:more/math.dart';
import 'package:more/number.dart' show Complex;

import '../../linear/vector.dart';
import '../../special/bessel.dart' as special_bessel;
import '../../special/beta.dart' as special_beta;
import '../../special/binomial.dart' as special_binomial;
import '../../special/digamma.dart' as special_digamma;
import '../../special/elliptic.dart' as special_elliptic;
import '../../special/erf.dart' as special_erf;
import '../../special/exp_integral.dart' as special_exp_int;
import '../../special/factorial.dart' as special_factorial;
import '../../special/fresnel.dart' as special_fresnel;
import '../../special/gamma.dart' as special_gamma;
import '../../special/lambert_w.dart' as special_lambert;
import '../../special/polylog.dart' as special_polylog;
import '../../special/trig_integral.dart' as special_trig_int;
import '../../special/zeta.dart' as special_zeta;
import '../ast.dart';
import '../calculus/differentiation.dart';
import '../calculus/limit.dart';
import '../calculus/summation.dart';
import 'bytecode.dart';

/// Unified bytecode virtual machine evaluator supporting real (`double`),
/// complex ([Complex]), vector ([Vector]), and vectorized tensor
/// ([Float64List]) execution from a single compiled instruction stream.
final class BytecodeEvaluator {
  /// Creates a bytecode evaluator for a compiled instruction stream.
  new({
    required this.variables,
    required this.instructions,
    required this.maxStack,
    required this.registerCount,
    this.hasComplexLiterals = false,
    this.isRealOutput = true,
    this.firstComplexLiteral,
  });

  /// Ordered variable names bound to positional indices `0 .. variables.length - 1`.
  final List<String> variables;

  /// Compiled instruction stream.
  final List<Instruction> instructions;

  /// Maximum stack depth required during execution.
  final int maxStack;

  /// Number of Common Subexpression Elimination (CSE) registers allocated.
  final int registerCount;

  /// Whether the instruction stream contains non-real complex literals.
  final bool hasComplexLiterals;

  /// Whether the overall expression evaluates to a real value when all free
  /// variables are real.
  final bool isRealOutput;

  /// First non-real literal encountered during compilation, if any.
  final Expr? firstComplexLiteral;

  late final Float64List _realStack = Float64List(maxStack);
  late final Float64List _realRegs = Float64List(registerCount);
  late final List<Complex> _complexStack = List<Complex>.filled(
    maxStack,
    Complex.zero,
  );
  late final List<Complex> _complexRegs = List<Complex>.filled(
    registerCount,
    Complex.zero,
  );
  var _realBusy = false;
  var _complexBusy = false;
  final _innerPrograms = HashMap<Expr, BytecodeEvaluator>();
  var _innerCompileCount = 0;

  /// Number of inner expressions compiled lazily by this evaluator.
  @visibleForTesting
  int get innerCompileCount => _innerCompileCount;

  /// Asserts that this evaluator produces a real value when bound to a
  /// real-valued evaluation target.
  void checkRealSupported() {
    if (hasComplexLiterals && !isRealOutput) {
      throw UnsupportedError(
        'Expression contains complex literal $firstComplexLiteral; '
        'use complex evaluation instead.',
      );
    }
  }

  /// Evaluates a single-variable real expression at [x].
  double evaluate1D(double x) => _runReal((_) => x);

  /// Evaluates a multivariable real expression at positional [args].
  double evaluateList(List<double> args) => _runReal((idx) => args[idx]);

  /// Evaluates a multivariable real expression at [vector].
  double evaluateVector(Vector<double> vector) =>
      _runReal((idx) => vector[idx]);

  /// Evaluates a multivariable real expression using named bindings in [context].
  double evaluateMap(Map<String, double> context) => _runReal((idx) {
    final name = variables[idx];
    final val = context[name];
    if (val == null) {
      throw ArgumentError('Variable "$name" not provided in context');
    }
    return val;
  });

  /// Evaluates a single-variable complex expression at [x].
  Complex evaluateComplex1D(Complex x) => _runComplex((_) => x);

  /// Evaluates a multivariable complex expression at positional [args].
  Complex evaluateComplexList(List<Complex> args) =>
      _runComplex((idx) => args[idx]);

  /// Evaluates a multivariable complex expression using named bindings in [context].
  Complex evaluateComplexMap(Map<String, Complex> context) =>
      _runComplex((idx) {
        final name = variables[idx];
        final val = context[name];
        if (val == null) {
          throw ArgumentError('Variable "$name" not provided in context');
        }
        return val;
      });

  /// Evaluates this program across contiguous [Float64List] [inputs], writing
  /// results into [output].
  void evaluateTensor(List<Float64List> inputs, Float64List output) {
    checkRealSupported();
    final expectedInputs = variables.length;
    if (inputs.length != expectedInputs) {
      throw ArgumentError(
        'Expected $expectedInputs input buffers, got ${inputs.length}',
      );
    }
    final len = output.length;
    for (var j = 0; j < expectedInputs; j++) {
      if (inputs[j].length < len) {
        throw ArgumentError(
          'Input buffer $j has length ${inputs[j].length}, less than output length $len',
        );
      }
    }
    for (var i = 0; i < len; i++) {
      output[i] = _runReal((idx) => inputs[idx][i]);
    }
  }

  double _runReal(double Function(int varIndex) loadVar) {
    if (hasComplexLiterals) {
      final res = _runComplex((idx) => Complex(loadVar(idx)));
      if (res.b == 0.0 || (res.b.abs() <= 1e-15 * (res.a.abs() + 1.0))) {
        return res.a.toDouble();
      }
      if (res.isNaN) {
        return double.nan;
      }
      throw UnsupportedError(
        'Expression evaluated to complex value $res; use complex evaluation instead.',
      );
    }
    final reentrant = _realBusy;
    if (!reentrant) _realBusy = true;
    final stack = reentrant ? Float64List(maxStack) : _realStack;
    final regs = reentrant ? Float64List(registerCount) : _realRegs;
    final instrs = instructions;
    final numInstrs = instrs.length;
    var sp = 0;
    var pc = 0;

    try {
      while (pc < numInstrs) {
        final instr = instrs[pc++];
        switch (instr.op) {
          case Op.pushConst:
            stack[sp++] = instr.realValue;
          case Op.loadVar:
            stack[sp++] = loadVar(instr.index);
          case Op.storeReg:
            regs[instr.index] = stack[sp - 1];
          case Op.loadReg:
            stack[sp++] = regs[instr.index];
          case Op.jump:
            pc = instr.index;
          case Op.jumpIfFalse:
            final cond = stack[--sp];
            if (cond == 0.0 || cond.isNaN) {
              pc = instr.index;
            }
          case Op.evalNode:
            final ctx = <String, double>{
              for (var i = 0; i < variables.length; i++)
                variables[i]: loadVar(i),
            };
            stack[sp++] = _evalNodeReal(instr.node!, ctx, _compileInner);
          case Op.add:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = a + b;
          case Op.sub:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = a - b;
          case Op.mul:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = a * b;
          case Op.div:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = a / b;
          case Op.pow:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = _realPow(a, b, instr.index);
          case Op.neg:
            stack[sp - 1] = -stack[sp - 1];
          case Op.sin:
            stack[sp - 1] = math.sin(stack[sp - 1]);
          case Op.cos:
            stack[sp - 1] = math.cos(stack[sp - 1]);
          case Op.exp:
            stack[sp - 1] = math.exp(stack[sp - 1]);
          case Op.ln:
            stack[sp - 1] = math.log(stack[sp - 1]);
          case Op.tan:
            stack[sp - 1] = math.tan(stack[sp - 1]);
          case Op.asin:
            stack[sp - 1] = math.asin(stack[sp - 1]);
          case Op.acos:
            stack[sp - 1] = math.acos(stack[sp - 1]);
          case Op.atan:
            stack[sp - 1] = math.atan(stack[sp - 1]);
          case Op.atan2:
            final x = stack[--sp];
            final y = stack[--sp];
            stack[sp++] = math.atan2(y, x);
          case Op.sinh:
            stack[sp - 1] = stack[sp - 1].sinh();
          case Op.cosh:
            stack[sp - 1] = stack[sp - 1].cosh();
          case Op.tanh:
            stack[sp - 1] = stack[sp - 1].tanh();
          case Op.abs:
            stack[sp - 1] = stack[sp - 1].abs();
          case Op.sqrt:
            stack[sp - 1] = math.sqrt(stack[sp - 1]);
          case Op.lambertW0:
            stack[sp - 1] = special_lambert.lambertW(stack[sp - 1]);
          case Op.lambertW1:
            stack[sp - 1] = special_lambert.lambertW(stack[sp - 1], branch: -1);
          case Op.erf:
            stack[sp - 1] = special_erf.erf(stack[sp - 1]);
          case Op.erfc:
            stack[sp - 1] = special_erf.erfc(stack[sp - 1]);
          case Op.gamma:
            stack[sp - 1] = special_gamma.gamma(stack[sp - 1]);
          case Op.zeta:
            stack[sp - 1] = special_zeta.zeta(stack[sp - 1]);
          case Op.digamma:
            stack[sp - 1] = special_digamma.digamma(stack[sp - 1]);
          case Op.polygamma:
            final x = stack[--sp];
            final m = stack[--sp];
            stack[sp++] = special_digamma.polygamma(m.toInt(), x);
          case Op.besselJ:
            final x = stack[--sp];
            final nu = stack[--sp];
            stack[sp++] = special_bessel.besselJ(nu, x);
          case Op.besselY:
            final x = stack[--sp];
            final nu = stack[--sp];
            stack[sp++] = special_bessel.besselY(nu, x);
          case Op.besselI:
            final x = stack[--sp];
            final nu = stack[--sp];
            stack[sp++] = special_bessel.besselI(nu, x);
          case Op.besselK:
            final x = stack[--sp];
            final nu = stack[--sp];
            stack[sp++] = special_bessel.besselK(nu, x);
          case Op.ellipticK:
            stack[sp - 1] = special_elliptic.ellipticK(stack[sp - 1]);
          case Op.ellipticE:
            stack[sp - 1] = special_elliptic.ellipticE(stack[sp - 1]);
          case Op.erfi:
            stack[sp - 1] = special_erf.erfi(stack[sp - 1]);
          case Op.fresnelS:
            stack[sp - 1] = special_fresnel.fresnelS(stack[sp - 1]);
          case Op.fresnelC:
            stack[sp - 1] = special_fresnel.fresnelC(stack[sp - 1]);
          case Op.expIntegralEi:
            stack[sp - 1] = special_exp_int.expIntegral(stack[sp - 1]);
          case Op.logIntegralLi:
            stack[sp - 1] = special_exp_int.logIntegral(stack[sp - 1]);
          case Op.sinIntegralSi:
            stack[sp - 1] = special_trig_int.sinIntegral(stack[sp - 1]);
          case Op.cosIntegralCi:
            stack[sp - 1] = special_trig_int.cosIntegral(stack[sp - 1]);
          case Op.sinhIntegralShi:
            stack[sp - 1] = special_trig_int.sinhIntegral(stack[sp - 1]);
          case Op.coshIntegralChi:
            stack[sp - 1] = special_trig_int.coshIntegral(stack[sp - 1]);
          case Op.upperGamma:
            final x = stack[--sp];
            final s = stack[--sp];
            stack[sp++] = special_gamma.upperGamma(s, x);
          case Op.lowerGamma:
            final x = stack[--sp];
            final s = stack[--sp];
            stack[sp++] = special_gamma.lowerGamma(s, x);
          case Op.polylog:
            final z = stack[--sp];
            final s = stack[--sp];
            stack[sp++] = special_polylog.polylog(s, z);
          case Op.ellipticF:
            final k = stack[--sp];
            final phi = stack[--sp];
            stack[sp++] = special_elliptic.ellipticF(phi, k);
          case Op.ellipticEIncomplete:
            final k = stack[--sp];
            final phi = stack[--sp];
            stack[sp++] = special_elliptic.ellipticE(k, phi: phi);
          case Op.ellipticPi:
            final k = stack[--sp];
            final phi = stack[--sp];
            final n = stack[--sp];
            stack[sp++] = special_elliptic.ellipticPi(n, k, phi: phi);
          case Op.beta:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = special_beta.beta(a, b);
          case Op.factorial:
            final v = stack[sp - 1];
            stack[sp - 1] = special_gamma.gamma(v + 1.0);
          case Op.binomial:
            final k = stack[--sp];
            final n = stack[--sp];
            stack[sp++] = evalRealBinomial(n, k);
          case Op.floor:
            final v = stack[sp - 1];
            stack[sp - 1] = v.isFinite ? v.floorToDouble() : v;
          case Op.ceil:
            final v = stack[sp - 1];
            stack[sp - 1] = v.isFinite ? v.ceilToDouble() : v;
          case Op.round:
            final v = stack[sp - 1];
            stack[sp - 1] = v.isFinite ? v.roundToDouble() : v;
          case Op.sign:
            final v = stack[sp - 1];
            stack[sp - 1] = v.isNaN
                ? double.nan
                : (v == 0.0 ? 0.0 : (v > 0.0 ? 1.0 : -1.0));
          case Op.mod:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = (a.isNaN || b.isNaN || b == 0.0)
                ? double.nan
                : a - b * (a / b).floorToDouble();
          case Op.re || Op.conj:
            break;
          case Op.im:
            stack[sp - 1] = 0.0;
          case Op.arg:
            final v = stack[sp - 1];
            stack[sp - 1] = v < 0.0 ? math.pi : 0.0;
          case Op.asinh:
            stack[sp - 1] = stack[sp - 1].asinh();
          case Op.acosh:
            stack[sp - 1] = stack[sp - 1].acosh();
          case Op.atanh:
            stack[sp - 1] = stack[sp - 1].atanh();
          case Op.lt:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = a < b ? 1.0 : 0.0;
          case Op.le:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = a <= b ? 1.0 : 0.0;
          case Op.gt:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = a > b ? 1.0 : 0.0;
          case Op.ge:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = a >= b ? 1.0 : 0.0;
          case Op.eq:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = a == b ? 1.0 : 0.0;
          case Op.ne:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = a != b ? 1.0 : 0.0;
        }
      }
      final result = stack[0];
      if (result.isNaN) {
        var anyVarNaN = false;
        for (var i = 0; i < variables.length; i++) {
          if (loadVar(i).isNaN) {
            anyVarNaN = true;
            break;
          }
        }
        if (!anyVarNaN) {
          if (!reentrant) _realBusy = false;
          final complexRes = _runComplex((idx) => Complex(loadVar(idx)));
          if (!complexRes.isNaN &&
              complexRes.b.abs() <= 1e-15 * (complexRes.a.abs() + 1.0)) {
            return complexRes.a.toDouble();
          }
          return double.nan;
        }
      }
      return result;
    } finally {
      if (!reentrant) _realBusy = false;
    }
  }

  Complex _runComplex(Complex Function(int varIndex) loadVar) {
    final reentrant = _complexBusy;
    if (!reentrant) _complexBusy = true;
    final stack = reentrant
        ? List<Complex>.filled(maxStack, Complex.zero)
        : _complexStack;
    final regs = reentrant
        ? List<Complex>.filled(registerCount, Complex.zero)
        : _complexRegs;
    final instrs = instructions;
    final numInstrs = instrs.length;
    var sp = 0;
    var pc = 0;

    try {
      while (pc < numInstrs) {
        final instr = instrs[pc++];
        switch (instr.op) {
          case Op.pushConst:
            stack[sp++] = instr.complexValue;
          case Op.loadVar:
            stack[sp++] = loadVar(instr.index);
          case Op.storeReg:
            regs[instr.index] = stack[sp - 1];
          case Op.loadReg:
            stack[sp++] = regs[instr.index];
          case Op.jump:
            pc = instr.index;
          case Op.jumpIfFalse:
            final cond = stack[--sp];
            if (cond.a == 0.0 || cond.a.isNaN) {
              pc = instr.index;
            }
          case Op.evalNode:
            if (instr.node case Integral(isDefinite: true) || Derivative()) {
              var allReal = true;
              final realCtx = <String, double>{};
              for (var i = 0; i < variables.length; i++) {
                final z = loadVar(i);
                if (z.b != 0.0) {
                  allReal = false;
                  break;
                }
                realCtx[variables[i]] = z.a.toDouble();
              }
              stack[sp++] = allReal
                  ? Complex(_evalNodeReal(instr.node!, realCtx, _compileInner))
                  : Complex.nan;
            } else {
              stack[sp++] = Complex.nan;
            }
          case Op.add:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = a + b;
          case Op.sub:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = a - b;
          case Op.mul:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = a * b;
          case Op.div:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = b == Complex.zero && a.b == 0.0 && a.a != 0.0
                ? Complex(a.a / 0.0)
                : a / b;
          case Op.pow:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = _complexPow(a, b);
          case Op.neg:
            stack[sp - 1] = -stack[sp - 1];
          case Op.sin:
            stack[sp - 1] = stack[sp - 1].sin();
          case Op.cos:
            stack[sp - 1] = stack[sp - 1].cos();
          case Op.exp:
            stack[sp - 1] = stack[sp - 1].exp();
          case Op.ln:
            stack[sp - 1] = stack[sp - 1].log();
          case Op.tan:
            stack[sp - 1] = stack[sp - 1].tan();
          case Op.asin:
            stack[sp - 1] = stack[sp - 1].asin();
          case Op.acos:
            stack[sp - 1] = stack[sp - 1].acos();
          case Op.atan:
            stack[sp - 1] = stack[sp - 1].atan();
          case Op.atan2:
            final zX = stack[--sp];
            final zY = stack[--sp];
            if (zX.b == 0.0 && zY.b == 0.0) {
              stack[sp++] = Complex(
                math.atan2(zY.a.toDouble(), zX.a.toDouble()),
              );
            } else {
              stack[sp++] =
                  -Complex.i *
                  ((zX + Complex.i * zY) / (zX * zX + zY * zY).sqrt()).log();
            }
          case Op.sinh:
            stack[sp - 1] = stack[sp - 1].sinh();
          case Op.cosh:
            stack[sp - 1] = stack[sp - 1].cosh();
          case Op.tanh:
            stack[sp - 1] = stack[sp - 1].tanh();
          case Op.abs:
            stack[sp - 1] = Complex(stack[sp - 1].abs());
          case Op.sqrt:
            stack[sp - 1] = stack[sp - 1].sqrt();
          case Op.lambertW0:
            stack[sp - 1] = special_lambert.lambertWComplex(stack[sp - 1]);
          case Op.lambertW1:
            stack[sp - 1] = special_lambert.lambertWComplex(
              stack[sp - 1],
              branch: -1,
            );
          case Op.erf:
            stack[sp - 1] = special_erf.erfComplex(stack[sp - 1]);
          case Op.erfc:
            stack[sp - 1] = special_erf.erfcComplex(stack[sp - 1]);
          case Op.gamma:
            stack[sp - 1] = special_gamma.gammaComplex(stack[sp - 1]);
          case Op.zeta:
            stack[sp - 1] = special_zeta.zetaComplex(stack[sp - 1]);
          case Op.digamma:
            stack[sp - 1] = special_digamma.digammaComplex(stack[sp - 1]);
          case Op.polygamma:
            final zX = stack[--sp];
            final zM = stack[--sp];
            if (zM.b != 0.0 || zM.a != zM.a.roundToDouble()) {
              throw UnsupportedError(
                'Complex Polygamma order must be a real integer',
              );
            }
            stack[sp++] = special_digamma.polygammaComplex(zM.a.toInt(), zX);
          case Op.besselJ:
            final zX = stack[--sp];
            final zNu = stack[--sp];
            stack[sp++] = special_bessel.besselJComplex(zNu, zX);
          case Op.besselY:
            final zX = stack[--sp];
            final zNu = stack[--sp];
            stack[sp++] = special_bessel.besselYComplex(zNu, zX);
          case Op.besselI:
            final zX = stack[--sp];
            final zNu = stack[--sp];
            stack[sp++] = special_bessel.besselIComplex(zNu, zX);
          case Op.besselK:
            final zX = stack[--sp];
            final zNu = stack[--sp];
            stack[sp++] = special_bessel.besselKComplex(zNu, zX);
          case Op.ellipticK:
            stack[sp - 1] = special_elliptic.ellipticKComplex(stack[sp - 1]);
          case Op.ellipticE:
            stack[sp - 1] = special_elliptic.ellipticEComplex(stack[sp - 1]);
          case Op.erfi:
            stack[sp - 1] = special_erf.erfiComplex(stack[sp - 1]);
          case Op.fresnelS:
            stack[sp - 1] = special_fresnel.fresnelSComplex(stack[sp - 1]);
          case Op.fresnelC:
            stack[sp - 1] = special_fresnel.fresnelCComplex(stack[sp - 1]);
          case Op.expIntegralEi:
            stack[sp - 1] = special_exp_int.expIntegralComplex(stack[sp - 1]);
          case Op.logIntegralLi:
            stack[sp - 1] = special_exp_int.logIntegralComplex(stack[sp - 1]);
          case Op.sinIntegralSi:
            stack[sp - 1] = special_trig_int.sinIntegralComplex(stack[sp - 1]);
          case Op.cosIntegralCi:
            stack[sp - 1] = special_trig_int.cosIntegralComplex(stack[sp - 1]);
          case Op.sinhIntegralShi:
            stack[sp - 1] = special_trig_int.sinhIntegralComplex(stack[sp - 1]);
          case Op.coshIntegralChi:
            stack[sp - 1] = special_trig_int.coshIntegralComplex(stack[sp - 1]);
          case Op.upperGamma:
            final zX = stack[--sp];
            final zS = stack[--sp];
            stack[sp++] = special_gamma.upperGammaComplex(zS, zX);
          case Op.lowerGamma:
            final zX = stack[--sp];
            final zS = stack[--sp];
            stack[sp++] = special_gamma.lowerGammaComplex(zS, zX);
          case Op.polylog:
            final zArg = stack[--sp];
            final zOrder = stack[--sp];
            stack[sp++] = special_polylog.polylogComplex(zOrder, zArg);
          case Op.ellipticF:
            final zK = stack[--sp];
            final zPhi = stack[--sp];
            stack[sp++] = special_elliptic.ellipticFComplex(zPhi, zK);
          case Op.ellipticEIncomplete:
            final zK = stack[--sp];
            final zPhi = stack[--sp];
            stack[sp++] = special_elliptic.ellipticEComplex(zK, phi: zPhi);
          case Op.ellipticPi:
            final zK = stack[--sp];
            final zPhi = stack[--sp];
            final zN = stack[--sp];
            stack[sp++] = special_elliptic.ellipticPiComplex(zN, zK, phi: zPhi);
          case Op.beta:
            final zB = stack[--sp];
            final zA = stack[--sp];
            stack[sp++] = special_beta.betaComplex(zA, zB);
          case Op.factorial:
            stack[sp - 1] = special_factorial.factorialComplex(stack[sp - 1]);
          case Op.binomial:
            final zK = stack[--sp];
            final zN = stack[--sp];
            stack[sp++] = special_binomial.binomialComplex(zN, zK);
          case Op.floor:
            final z = stack[sp - 1];
            if (z.b != 0.0) {
              throw UnsupportedError(
                'Complex Floor evaluation is only supported on R',
              );
            }
            final v = z.a.toDouble();
            stack[sp - 1] = Complex(v.isFinite ? v.floorToDouble() : v);
          case Op.ceil:
            final z = stack[sp - 1];
            if (z.b != 0.0) {
              throw UnsupportedError(
                'Complex Ceil evaluation is only supported on R',
              );
            }
            final v = z.a.toDouble();
            stack[sp - 1] = Complex(v.isFinite ? v.ceilToDouble() : v);
          case Op.round:
            final z = stack[sp - 1];
            if (z.b != 0.0) {
              throw UnsupportedError(
                'Complex Round evaluation is only supported on R',
              );
            }
            final v = z.a.toDouble();
            stack[sp - 1] = Complex(v.isFinite ? v.roundToDouble() : v);
          case Op.sign:
            final z = stack[sp - 1];
            if (z == Complex.zero) {
              stack[sp - 1] = Complex.zero;
            } else if (z.b == 0.0) {
              final v = z.a.toDouble();
              stack[sp - 1] = Complex(
                v.isNaN
                    ? double.nan
                    : (v == 0.0 ? 0.0 : (v > 0.0 ? 1.0 : -1.0)),
              );
            } else {
              final r = z.abs();
              stack[sp - 1] = r == 0.0 || r.isNaN
                  ? Complex.nan
                  : z / Complex(r);
            }
          case Op.mod:
            final zB = stack[--sp];
            final zA = stack[--sp];
            if (zA.b != 0.0 || zB.b != 0.0) {
              throw UnsupportedError(
                'Complex Mod evaluation is only supported on R',
              );
            }
            final a = zA.a.toDouble();
            final b = zB.a.toDouble();
            stack[sp++] = Complex(
              (a.isNaN || b.isNaN || b == 0.0)
                  ? double.nan
                  : a - b * (a / b).floorToDouble(),
            );
          case Op.re:
            stack[sp - 1] = Complex(stack[sp - 1].real);
          case Op.im:
            stack[sp - 1] = Complex(stack[sp - 1].imaginary);
          case Op.arg:
            stack[sp - 1] = Complex(stack[sp - 1].arg());
          case Op.conj:
            stack[sp - 1] = stack[sp - 1].conjugate();
          case Op.asinh:
            stack[sp - 1] = stack[sp - 1].asinh();
          case Op.acosh:
            stack[sp - 1] = stack[sp - 1].acosh();
          case Op.atanh:
            stack[sp - 1] = stack[sp - 1].atanh();
          case Op.lt:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = (_isEffectivelyReal(a) && _isEffectivelyReal(b))
                ? (a.a < b.a ? Complex.one : Complex.zero)
                : Complex.nan;
          case Op.le:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = (_isEffectivelyReal(a) && _isEffectivelyReal(b))
                ? (a.a <= b.a ? Complex.one : Complex.zero)
                : Complex.nan;
          case Op.gt:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = (_isEffectivelyReal(a) && _isEffectivelyReal(b))
                ? (a.a > b.a ? Complex.one : Complex.zero)
                : Complex.nan;
          case Op.ge:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = (_isEffectivelyReal(a) && _isEffectivelyReal(b))
                ? (a.a >= b.a ? Complex.one : Complex.zero)
                : Complex.nan;
          case Op.eq:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = a == b ? Complex.one : Complex.zero;
          case Op.ne:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = a != b ? Complex.one : Complex.zero;
        }
      }
      return stack[0];
    } finally {
      if (!reentrant) _complexBusy = false;
    }
  }

  BytecodeEvaluator _compileInner(Expr expr) =>
      _innerPrograms.putIfAbsent(expr, () {
        _innerCompileCount++;
        return compileToBytecode(
          expr,
          const [],
          optimize: false,
          allowDynamicVars: true,
        );
      });
}

/// Evaluates the real binomial coefficient $\binom{n}{k}$ without intermediate
/// gamma overflow.
double evalRealBinomial(double n, double k) {
  if (n.isNaN || k.isNaN) return double.nan;
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

/// Computes $(\ln|\Gamma(z)|, \operatorname{sgn}\Gamma(z))$ for real [z].
///
/// Returns `sign == 0` and `logAbs == double.infinity` at non-positive integer
/// poles, or `logAbs == double.nan` for `NaN`.
({double logAbs, int sign}) logAbsGammaWithSign(double z) {
  if (z.isNaN) return (logAbs: double.nan, sign: 0);
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

/// Computes $(\ln|\binom{n}{k}|, \operatorname{sgn}\binom{n}{k})$ for real
/// [n] and [k].
({double logAbs, int sign}) logAbsBinomialWithSign(double n, double k) {
  if (n.isNaN || k.isNaN) return (logAbs: double.nan, sign: 0);
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
  if (numG.sign == 0) {
    return (logAbs: double.nan, sign: 0);
  }
  if (den1G.sign == 0 || den2G.sign == 0) {
    return (logAbs: double.negativeInfinity, sign: 0);
  }
  return (
    logAbs: numG.logAbs - den1G.logAbs - den2G.logAbs,
    sign: numG.sign * den1G.sign * den2G.sign,
  );
}

bool _isEffectivelyReal(Complex z) =>
    !z.isNaN && z.b.abs() <= 1e-15 * (z.a.abs() + 1.0);

double _evalNodeReal(
  Expr node,
  Map<String, double> context,
  BytecodeEvaluator Function(Expr) compileInner,
) {
  if (node case Integral(
    :final integrand,
    :final variable,
    :final lower?,
    :final upper?,
  )) {
    final a = compileInner(lower).evaluateMap(context);
    final b = compileInner(upper).evaluateMap(context);
    if (a.isNaN || b.isNaN) return double.nan;
    if (a == b) return 0.0;
    final integrandEval = compileInner(integrand);
    final localContext = Map<String, double>.of(context);
    return _quadratureDefinite(
      (x) {
        localContext[variable] = x;
        return integrandEval.evaluateMap(localContext);
      },
      a,
      b,
    );
  }
  if (node case Derivative(
    :final expr,
    :final variable,
    :final order,
    :final point,
  )) {
    var substituted = expr;
    for (final MapEntry(:key, :value) in context.entries) {
      if (key != variable) {
        substituted = substituted.substitute(key, Expr.wrap(value));
      }
    }
    final d = substituted.derivative(variable, order: order);
    final evalPt = point != null
        ? compileInner(point).evaluateMap(context)
        : context[variable];
    if (evalPt == null || evalPt.isNaN) return double.nan;
    final evalContext = Map<String, double>.of(context)..[variable] = evalPt;
    if (!d.anyNode((n) => n is Derivative)) {
      return compileInner(d).evaluateMap(evalContext);
    }
    return _numericDerivativeReal(
      compileInner(substituted),
      variable,
      evalContext,
      evalPt,
      order,
    );
  }
  if (node case Limit(
    :final expr,
    :final variable,
    :final point,
    :final direction,
  )) {
    var substituted = expr;
    for (final MapEntry(:key, :value) in context.entries) {
      if (key != variable) {
        substituted = substituted.substitute(key, Expr.wrap(value));
      }
    }
    final ptVal = compileInner(point).evaluateMap(context);
    if (ptVal.isNaN) return double.nan;
    final ptExpr = Expr.wrap(ptVal);
    final lim = substituted.limit(variable, ptExpr, direction: direction);
    return compileInner(lim).evaluateMap(context);
  }
  if (node case Sum(:final expr, :final variable, :final lower, :final upper)) {
    final a = compileInner(lower).evaluateMap(context);
    final b = compileInner(upper).evaluateMap(context);
    if (a.isNaN || b.isNaN) return double.nan;
    if (b < a) return 0.0;
    if (a.isFinite &&
        b.isFinite &&
        a == a.roundToDouble() &&
        b == b.roundToDouble() &&
        (b - a) <= 100000) {
      final start = a.round();
      final end = b.round();
      final eval = compileInner(expr);
      final localCtx = Map<String, double>.of(context);
      var total = 0.0;
      for (var k = start; k <= end; k++) {
        localCtx[variable] = k.toDouble();
        total += eval.evaluateMap(localCtx);
      }
      return total;
    }
    final s = expr.sum(variable, Expr.wrap(a), Expr.wrap(b));
    if (s is! Sum) {
      return compileInner(s).evaluateMap(context);
    }
    return double.nan;
  }
  if (node case Product(
    :final expr,
    :final variable,
    :final lower,
    :final upper,
  )) {
    final a = compileInner(lower).evaluateMap(context);
    final b = compileInner(upper).evaluateMap(context);
    if (a.isNaN || b.isNaN) return double.nan;
    if (b < a) return 1.0;
    if (a.isFinite &&
        b.isFinite &&
        a == a.roundToDouble() &&
        b == b.roundToDouble() &&
        (b - a) <= 100000) {
      final start = a.round();
      final end = b.round();
      final eval = compileInner(expr);
      final localCtx = Map<String, double>.of(context);
      var total = 1.0;
      for (var k = start; k <= end; k++) {
        localCtx[variable] = k.toDouble();
        total *= eval.evaluateMap(localCtx);
      }
      return total;
    }
    final p = expr.product(variable, Expr.wrap(a), Expr.wrap(b));
    if (p is! Product) {
      return compileInner(p).evaluateMap(context);
    }
    return double.nan;
  }
  return double.nan;
}

double _quadratureDefinite(double Function(double) f, double a, double b) {
  if (b < a) {
    return -_quadratureDefinite(f, b, a);
  }
  if (a == double.negativeInfinity && b == double.infinity) {
    return _gaussLegendre16(
      (t) {
        final denom = 1.0 - t * t;
        if (denom == 0.0) return 0.0;
        final x = t / denom;
        final dx = (1.0 + t * t) / (denom * denom);
        return f(x) * dx;
      },
      -1.0,
      1.0,
    );
  }
  if (a.isFinite && b == double.infinity) {
    return _gaussLegendre16(
      (t) {
        if (t >= 1.0) return 0.0;
        final d = 1.0 - t;
        final x = a + t / d;
        final dx = 1.0 / (d * d);
        return f(x) * dx;
      },
      0.0,
      1.0,
    );
  }
  if (a == double.negativeInfinity && b.isFinite) {
    return _gaussLegendre16(
      (t) {
        if (t >= 1.0) return 0.0;
        final d = 1.0 - t;
        final x = b - t / d;
        final dx = 1.0 / (d * d);
        return f(x) * dx;
      },
      0.0,
      1.0,
    );
  }
  return _gaussLegendre16(f, a, b);
}

const _glNodes8 = <double>[
  0.09501250983763744,
  0.2816035507792589,
  0.45801677765722737,
  0.6178762444026438,
  0.755404408355003,
  0.8656312023878318,
  0.9445750230732326,
  0.9894009349916499,
];

const _glWeights8 = <double>[
  0.1894506104550685,
  0.18260341504492358,
  0.16915651939500254,
  0.14959598881657674,
  0.12462897125553388,
  0.09515851168249279,
  0.062253523938647894,
  0.027152459411754096,
];

double _gaussLegendre16(double Function(double) f, double a, double b) {
  final half = 0.5 * (b - a);
  final mid = 0.5 * (a + b);
  var sum = 0.0;
  for (var i = 0; i < 8; i++) {
    final dx = half * _glNodes8[i];
    final y1 = f(mid - dx);
    final y2 = f(mid + dx);
    sum +=
        _glWeights8[i] * ((y1.isFinite ? y1 : 0.0) + (y2.isFinite ? y2 : 0.0));
  }
  return half * sum;
}

double _realPow(double base, double exponent, [int oddRootMode = 0]) {
  if (oddRootMode != 0 && base < 0.0) {
    final mag = math.pow(-base, exponent).toDouble();
    return oddRootMode == 1 ? -mag : mag;
  }
  return math.pow(base, exponent).toDouble();
}

Complex _complexPow(Complex base, Complex exponent) {
  if (exponent == Complex.zero) return Complex.one;
  if (base == Complex.zero) {
    if (exponent.a > 0) return Complex.zero;
    if (exponent.a < 0 && exponent.b == 0.0) {
      return const Complex(double.infinity);
    }
    return Complex.nan;
  }
  if (exponent.b == 0.0 &&
      exponent.a == exponent.a.roundToDouble() &&
      exponent.a.abs() <= 64) {
    final n = exponent.a.round();
    if (n == 1) return base;
    if (n == 2) return base * base;
    if (n == -1) return Complex.one / base;
    var result = Complex.one;
    var cur = n < 0 ? Complex.one / base : base;
    var m = n.abs();
    while (m > 0) {
      if (m.isOdd) result *= cur;
      cur *= cur;
      m >>= 1;
    }
    return result;
  }
  return base.pow(exponent);
}

double _numericDerivativeReal(
  BytecodeEvaluator eval,
  String variable,
  Map<String, double> context,
  double x,
  int order,
) {
  if (order <= 0) {
    context[variable] = x;
    return eval.evaluateMap(context);
  }
  if (order == 1) {
    final h = 1.0e-5 * math.max(1.0, x.abs());
    context[variable] = x + 2.0 * h;
    final fp2 = eval.evaluateMap(context);
    context[variable] = x + h;
    final fp1 = eval.evaluateMap(context);
    context[variable] = x - h;
    final fm1 = eval.evaluateMap(context);
    context[variable] = x - 2.0 * h;
    final fm2 = eval.evaluateMap(context);
    return (-fp2 + 8.0 * fp1 - 8.0 * fm1 + fm2) / (12.0 * h);
  }
  final h = 1.0e-3 * math.max(1.0, x.abs());
  final fPlus = _numericDerivativeReal(
    eval,
    variable,
    context,
    x + h,
    order - 1,
  );
  final fMinus = _numericDerivativeReal(
    eval,
    variable,
    context,
    x - h,
    order - 1,
  );
  return (fPlus - fMinus) / (2.0 * h);
}
