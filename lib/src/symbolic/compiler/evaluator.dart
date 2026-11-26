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
import '../../special/hypergeometric.dart' as special_hyper;
import '../../special/lambert_w.dart' as special_lambert;
import '../../special/polylog.dart' as special_polylog;
import '../../special/trig_integral.dart' as special_trig_int;
import '../../special/zeta.dart' as special_zeta;
import '../ast.dart';
import 'bytecode.dart';
import 'evaluator_helpers.dart';

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
  double evaluate1D(double x) {
    if (variables.length > 1) {
      throw StateError(
        'evaluate1D requires at most 1 variable, got ${variables.length}',
      );
    }
    return _runReal((_) => x);
  }

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
  Complex evaluateComplex1D(Complex x) {
    if (variables.length > 1) {
      throw StateError(
        'evaluateComplex1D requires at most 1 variable, got ${variables.length}',
      );
    }
    return _runComplex((_) => x);
  }

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
    if (hasComplexLiterals || _realBusy) {
      for (var i = 0; i < len; i++) {
        output[i] = _runReal((idx) => inputs[idx][i]);
      }
      return;
    }
    _realBusy = true;
    final stack = _realStack;
    final instrs = instructions;
    final numInstrs = instrs.length;
    try {
      for (var i = 0; i < len; i++) {
        var sp = 0;
        var pc = 0;
        while (pc < numInstrs) {
          final instr = instrs[pc++];
          if (instr.op == Op.pushConst) {
            stack[sp++] = instr.realValue;
          } else if (instr.op == Op.loadVar) {
            stack[sp++] = inputs[instr.index][i];
          } else {
            sp--;
            // Fall back cleanly to general executor if non-trivial ops appear.
            pc = 0;
            sp = -1;
            break;
          }
        }
        if (sp < 0) {
          _realBusy = false;
          for (var j = i; j < len; j++) {
            output[j] = _runReal((idx) => inputs[idx][j]);
          }
          return;
        }
        output[i] = stack[0];
      }
    } finally {
      _realBusy = false;
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
            stack[sp++] = evalNodeReal(instr.node!, ctx, _compileInner);
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
            stack[sp++] = realPow(a, b, instr.index);
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
          case Op.logGamma:
            final x = stack[sp - 1];
            stack[sp - 1] = x <= 0.0 ? double.nan : special_gamma.gammaLn(x);
          case Op.polygamma:
            final x = stack[--sp];
            final m = stack[--sp];
            if (!m.isFinite || m < 0.0 || m != m.roundToDouble()) {
              stack[sp++] = double.nan;
            } else {
              stack[sp++] = special_digamma.polygamma(m.toInt(), x);
            }
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
          case Op.hurwitzZeta:
            final a = stack[--sp];
            final s = stack[--sp];
            stack[sp++] = special_zeta.hurwitzZeta(s, a);
          case Op.expIntegralE:
            final z = stack[--sp];
            final n = stack[--sp];
            stack[sp++] = special_exp_int.expIntegralE(n, z);
          case Op.hypergeometric:
            final p = instr.index >> 8;
            final q = instr.index & 0xff;
            final z = stack[--sp];
            final lower = List<double>.filled(q, 0.0);
            for (var i = q - 1; i >= 0; i--) {
              lower[i] = stack[--sp];
            }
            final upper = List<double>.filled(p, 0.0);
            for (var i = p - 1; i >= 0; i--) {
              upper[i] = stack[--sp];
            }
            stack[sp++] = special_hyper.hypergeometricPFQ(upper, lower, z);
          case Op.appellF1:
            final y = stack[--sp];
            final x = stack[--sp];
            final c = stack[--sp];
            final b2 = stack[--sp];
            final b1 = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = special_hyper.appellF1(a, b1, b2, c, x, y);
          case Op.min:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = math.min(a, b);
          case Op.max:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = math.max(a, b);
          case Op.gcd:
            final b = stack[--sp];
            final a = stack[--sp];
            if (!a.isFinite ||
                !b.isFinite ||
                a.abs() > 9007199254740991.0 ||
                b.abs() > 9007199254740991.0 ||
                a != a.roundToDouble() ||
                b != b.roundToDouble()) {
              stack[sp++] = double.nan;
            } else {
              stack[sp++] = a.round().abs().gcd(b.round().abs()).toDouble();
            }
          case Op.lcm:
            final b = stack[--sp];
            final a = stack[--sp];
            if (!a.isFinite ||
                !b.isFinite ||
                a.abs() > 9007199254740991.0 ||
                b.abs() > 9007199254740991.0 ||
                a != a.roundToDouble() ||
                b != b.roundToDouble()) {
              stack[sp++] = double.nan;
            } else {
              stack[sp++] = a.round().abs().lcm(b.round().abs()).toDouble();
            }
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
            if (a.isNaN || b.isNaN || b == 0.0 || a.isInfinite) {
              stack[sp++] = double.nan;
            } else if (b.isInfinite) {
              stack[sp++] = (a == 0.0 || (a > 0.0) == (b > 0.0)) ? a : b;
            } else {
              stack[sp++] = a - b * (a / b).floorToDouble();
            }
          case Op.re || Op.conj:
            break;
          case Op.im:
            final v = stack[sp - 1];
            stack[sp - 1] = v.isNaN ? double.nan : 0.0;
          case Op.arg:
            final v = stack[sp - 1];
            stack[sp - 1] = v.isNaN ? double.nan : (v < 0.0 ? math.pi : 0.0);
          case Op.asinh:
            stack[sp - 1] = stack[sp - 1].asinh();
          case Op.acosh:
            stack[sp - 1] = stack[sp - 1].acosh();
          case Op.atanh:
            stack[sp - 1] = stack[sp - 1].atanh();
          case Op.lt:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = (a.isNaN || b.isNaN)
                ? double.nan
                : (a < b ? 1.0 : 0.0);
          case Op.le:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = (a.isNaN || b.isNaN)
                ? double.nan
                : (a <= b ? 1.0 : 0.0);
          case Op.gt:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = (a.isNaN || b.isNaN)
                ? double.nan
                : (a > b ? 1.0 : 0.0);
          case Op.ge:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = (a.isNaN || b.isNaN)
                ? double.nan
                : (a >= b ? 1.0 : 0.0);
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
          try {
            final complexRes = _runComplex((idx) => Complex(loadVar(idx)));
            if (!complexRes.isNaN &&
                complexRes.b.abs() <= 1e-15 * (complexRes.a.abs() + 1.0)) {
              return complexRes.a.toDouble();
            }
          } on UnsupportedError {
            return double.nan;
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
            if (instr.node case final RootSum rootSum) {
              final complexCtx = <String, Complex>{
                for (var i = 0; i < variables.length; i++)
                  variables[i]: loadVar(i),
              };
              stack[sp++] = evalRootSumComplex(
                rootSum,
                complexCtx,
                _compileInner,
              );
            } else if (instr.node
                case Integral(isDefinite: true) ||
                    Derivative() ||
                    Limit() ||
                    Sum() ||
                    Product()) {
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
                  ? Complex(evalNodeReal(instr.node!, realCtx, _compileInner))
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
            stack[sp++] = normalizeComplexZero(
              b == Complex.zero && a.b == 0.0 && a.a != 0.0
                  ? Complex(a.a / 0.0)
                  : a / b,
            );
          case Op.pow:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = complexPow(a, b);
          case Op.neg:
            stack[sp - 1] = normalizeComplexZero(-stack[sp - 1]);
          case Op.sin:
            stack[sp - 1] = stack[sp - 1].sin();
          case Op.cos:
            stack[sp - 1] = stack[sp - 1].cos();
          case Op.exp:
            stack[sp - 1] = stack[sp - 1].exp();
          case Op.ln:
            stack[sp - 1] = normalizeComplexZero(stack[sp - 1]).log();
          case Op.tan:
            stack[sp - 1] = stack[sp - 1].tan();
          case Op.asin:
            stack[sp - 1] = normalizeComplexZero(stack[sp - 1]).asin();
          case Op.acos:
            stack[sp - 1] = normalizeComplexZero(stack[sp - 1]).acos();
          case Op.atan:
            stack[sp - 1] = normalizeComplexZero(stack[sp - 1]).atan();
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
            stack[sp - 1] = normalizeComplexZero(stack[sp - 1]).sqrt();
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
          case Op.logGamma:
            stack[sp - 1] = special_gamma.gammaLnComplex(
              normalizeComplexZero(stack[sp - 1]),
            );
          case Op.polygamma:
            final zX = stack[--sp];
            final zM = stack[--sp];
            if (zM.isNaN || zX.isNaN) {
              stack[sp++] = Complex.nan;
            } else if (!zM.isFinite ||
                zM.b != 0.0 ||
                zM.a < 0.0 ||
                zM.a != zM.a.roundToDouble()) {
              throw UnsupportedError(
                'Complex Polygamma order must be a non-negative real integer',
              );
            } else {
              stack[sp++] = special_digamma.polygammaComplex(zM.a.toInt(), zX);
            }
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
          case Op.hurwitzZeta:
            final zA = stack[--sp];
            final zS = stack[--sp];
            stack[sp++] = special_zeta.hurwitzZetaComplex(zS, zA);
          case Op.expIntegralE:
            final zArg = stack[--sp];
            final zN = stack[--sp];
            stack[sp++] = special_exp_int.expIntegralEComplex(zN, zArg);
          case Op.hypergeometric:
            final p = instr.index >> 8;
            final q = instr.index & 0xff;
            final zArg = stack[--sp];
            final lower = List<Complex>.filled(q, Complex.zero);
            for (var i = q - 1; i >= 0; i--) {
              lower[i] = stack[--sp];
            }
            final upper = List<Complex>.filled(p, Complex.zero);
            for (var i = p - 1; i >= 0; i--) {
              upper[i] = stack[--sp];
            }
            stack[sp++] = special_hyper.hypergeometricPFQComplex(
              upper,
              lower,
              zArg,
            );
          case Op.appellF1:
            final zY = stack[--sp];
            final zX = stack[--sp];
            final zC = stack[--sp];
            final zB2 = stack[--sp];
            final zB1 = stack[--sp];
            final zA = stack[--sp];
            stack[sp++] = special_hyper.appellF1Complex(
              zA,
              zB1,
              zB2,
              zC,
              zX,
              zY,
            );
          case Op.min || Op.max || Op.gcd || Op.lcm:
            throw UnsupportedError(
              'Complex Min/Max/Gcd/Lcm evaluation is only supported on R',
            );
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
            if (a.isNaN || b.isNaN || b == 0.0 || a.isInfinite) {
              stack[sp++] = Complex.nan;
            } else if (b.isInfinite) {
              stack[sp++] = Complex(
                (a == 0.0 || (a > 0.0) == (b > 0.0)) ? a : b,
              );
            } else {
              stack[sp++] = Complex(a - b * (a / b).floorToDouble());
            }
          case Op.re:
            stack[sp - 1] = Complex(stack[sp - 1].real);
          case Op.im:
            stack[sp - 1] = Complex(stack[sp - 1].imaginary);
          case Op.arg:
            stack[sp - 1] = Complex(stack[sp - 1].arg());
          case Op.conj:
            stack[sp - 1] = stack[sp - 1].conjugate();
          case Op.asinh:
            stack[sp - 1] = normalizeComplexZero(stack[sp - 1]).asinh();
          case Op.acosh:
            stack[sp - 1] = normalizeComplexZero(stack[sp - 1]).acosh();
          case Op.atanh:
            stack[sp - 1] = normalizeComplexZero(stack[sp - 1]).atanh();
          case Op.lt:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = (isEffectivelyReal(a) && isEffectivelyReal(b))
                ? (a.a < b.a ? Complex.one : Complex.zero)
                : Complex.nan;
          case Op.le:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = (isEffectivelyReal(a) && isEffectivelyReal(b))
                ? (a.a <= b.a ? Complex.one : Complex.zero)
                : Complex.nan;
          case Op.gt:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = (isEffectivelyReal(a) && isEffectivelyReal(b))
                ? (a.a > b.a ? Complex.one : Complex.zero)
                : Complex.nan;
          case Op.ge:
            final b = stack[--sp];
            final a = stack[--sp];
            stack[sp++] = (isEffectivelyReal(a) && isEffectivelyReal(b))
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
          optimize: true,
          allowDynamicVars: true,
        );
      });
}
