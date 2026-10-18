import 'dart:math' as math;
import 'dart:typed_data';

import 'package:more/math.dart';
import 'package:more/number.dart' show Complex;

import '../../linear/vector.dart';
import '../../special/beta.dart' as special_beta;
import '../../special/erf.dart' as special_erf;
import '../../special/gamma.dart' as special_gamma;
import '../../special/lambert_w.dart' as special_lambert;
import '../ast.dart';
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
    checkRealSupported();
    return _runReal((_) => x);
  }

  /// Evaluates a multivariable real expression at positional [args].
  double evaluateList(List<double> args) {
    checkRealSupported();
    return _runReal((idx) => args[idx]);
  }

  /// Evaluates a multivariable real expression at [vector].
  double evaluateVector(Vector<double> vector) {
    checkRealSupported();
    return _runReal((idx) => vector[idx]);
  }

  /// Evaluates a multivariable real expression using named bindings in [context].
  double evaluateMap(Map<String, double> context) {
    checkRealSupported();
    return _runReal((idx) {
      final name = variables[idx];
      final val = context[name];
      if (val == null) {
        throw ArgumentError('Variable "$name" not provided in context');
      }
      return val;
    });
  }

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
      return _runComplex((idx) => Complex(loadVar(idx))).a.toDouble();
    }
    final stack = _realStack;
    final regs = _realRegs;
    final instrs = instructions;
    final numInstrs = instrs.length;
    var sp = 0;
    var pc = 0;

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
            for (var i = 0; i < variables.length; i++) variables[i]: loadVar(i),
          };
          stack[sp++] = _evalNodeReal(instr.node!, ctx);
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
          stack[sp - 1] = special_lambert.lambertW0(stack[sp - 1]);
        case Op.lambertW1:
          stack[sp - 1] = special_lambert.lambertW1(stack[sp - 1]);
        case Op.erf:
          stack[sp - 1] = special_erf.erf(stack[sp - 1]);
        case Op.erfc:
          stack[sp - 1] = special_erf.erfc(stack[sp - 1]);
        case Op.gamma:
          final v = stack[sp - 1];
          if (v <= 0.0 && v == v.roundToDouble()) {
            throw ArgumentError('Gamma pole at non-positive integer $v');
          }
          stack[sp - 1] = special_gamma.gamma(v);
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
          stack[sp++] = _evalRealBinomial(n, k);
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
          stack[sp - 1] = stack[sp - 1].isNaN ? double.nan : 0.0;
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
    return stack[0];
  }

  Complex _runComplex(Complex Function(int varIndex) loadVar) {
    final stack = _complexStack;
    final regs = _complexRegs;
    final instrs = instructions;
    final numInstrs = instrs.length;
    var sp = 0;
    var pc = 0;

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
          if (instr.node case Integral(isDefinite: true)) {
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
                ? Complex(_evalNodeReal(instr.node!, realCtx))
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
          final z = stack[sp - 1];
          if (z.b != 0.0) {
            throw UnsupportedError(
              'Complex LambertW evaluation is only supported on R',
            );
          }
          stack[sp - 1] = Complex(special_lambert.lambertW0(z.a.toDouble()));
        case Op.lambertW1:
          final z = stack[sp - 1];
          if (z.b != 0.0) {
            throw UnsupportedError(
              'Complex LambertW evaluation is only supported on R',
            );
          }
          stack[sp - 1] = Complex(special_lambert.lambertW1(z.a.toDouble()));
        case Op.erf:
          final z = stack[sp - 1];
          if (z.b != 0.0) {
            throw UnsupportedError(
              'Complex Erf evaluation is only supported on R',
            );
          }
          stack[sp - 1] = Complex(special_erf.erf(z.a.toDouble()));
        case Op.erfc:
          final z = stack[sp - 1];
          if (z.b != 0.0) {
            throw UnsupportedError(
              'Complex Erfc evaluation is only supported on R',
            );
          }
          stack[sp - 1] = Complex(special_erf.erfc(z.a.toDouble()));
        case Op.gamma:
          final z = stack[sp - 1];
          if (z.b != 0.0) {
            throw UnsupportedError(
              'Complex Gamma evaluation is only supported on R',
            );
          }
          stack[sp - 1] = Complex(special_gamma.gamma(z.a.toDouble()));
        case Op.beta:
          final zB = stack[--sp];
          final zA = stack[--sp];
          if (zA.b != 0.0 || zB.b != 0.0) {
            throw UnsupportedError(
              'Complex Beta evaluation is only supported on R',
            );
          }
          stack[sp++] = Complex(
            special_beta.beta(zA.a.toDouble(), zB.a.toDouble()),
          );
        case Op.factorial:
          final z = stack[sp - 1];
          if (z.b != 0.0) {
            throw UnsupportedError(
              'Complex Factorial evaluation is only supported on R',
            );
          }
          stack[sp - 1] = Complex(special_gamma.gamma(z.a.toDouble() + 1.0));
        case Op.binomial:
          final zK = stack[--sp];
          final zN = stack[--sp];
          if (zN.b != 0.0 || zK.b != 0.0) {
            throw UnsupportedError(
              'Complex Binomial evaluation is only supported on R',
            );
          }
          stack[sp++] = Complex(
            _evalRealBinomial(zN.a.toDouble(), zK.a.toDouble()),
          );
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
              v.isNaN ? double.nan : (v == 0.0 ? 0.0 : (v > 0.0 ? 1.0 : -1.0)),
            );
          } else {
            final r = z.abs();
            stack[sp - 1] = r == 0.0 || r.isNaN ? Complex.nan : z / Complex(r);
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
          stack[sp++] = a.a < b.a ? Complex.one : Complex.zero;
        case Op.le:
          final b = stack[--sp];
          final a = stack[--sp];
          stack[sp++] = a.a <= b.a ? Complex.one : Complex.zero;
        case Op.gt:
          final b = stack[--sp];
          final a = stack[--sp];
          stack[sp++] = a.a > b.a ? Complex.one : Complex.zero;
        case Op.ge:
          final b = stack[--sp];
          final a = stack[--sp];
          stack[sp++] = a.a >= b.a ? Complex.one : Complex.zero;
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
  }
}

double _evalRealBinomial(double n, double k) {
  if (n.isNaN || k.isNaN) return double.nan;
  if (k == k.roundToDouble() && k < 0.0) return 0.0;
  if (n == n.roundToDouble() && k == k.roundToDouble() && n >= 0.0 && k > n) {
    return 0.0;
  }
  return special_gamma.gamma(n + 1.0) /
      (special_gamma.gamma(k + 1.0) * special_gamma.gamma(n - k + 1.0));
}

double _evalNodeReal(Expr node, Map<String, double> context) {
  if (node case Integral(
    :final integrand,
    :final variable,
    :final lower?,
    :final upper?,
  )) {
    final a = compileToBytecode(
      lower,
      const [],
      optimize: false,
      allowDynamicVars: true,
    ).evaluateMap(context);
    final b = compileToBytecode(
      upper,
      const [],
      optimize: false,
      allowDynamicVars: true,
    ).evaluateMap(context);
    if (a.isNaN || b.isNaN) return double.nan;
    if (a == b) return 0.0;
    final integrandEval = compileToBytecode(
      integrand,
      const [],
      optimize: false,
      allowDynamicVars: true,
    );
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
