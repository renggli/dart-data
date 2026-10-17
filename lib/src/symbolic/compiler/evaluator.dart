import 'dart:math' as math;
import 'dart:typed_data';

import 'package:more/number.dart' show Complex;

import '../../linear/vector.dart';
import '../../special/beta.dart' as special_beta;
import '../../special/erf.dart' as special_erf;
import '../../special/gamma.dart' as special_gamma;
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

  /// Asserts that this evaluator contains no non-real constants when bound to
  /// a real-valued evaluation target.
  void checkRealSupported() {
    if (hasComplexLiterals) {
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
          stack[sp++] = instr.node!.evaluate(ctx);
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
          stack[sp++] = _realPow(a, b);
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
          final v = stack[sp - 1];
          stack[sp - 1] = v.abs() < 1e-5
              ? v + (v * v * v) / 6.0
              : (math.exp(v) - math.exp(-v)) / 2.0;
        case Op.cosh:
          final v = stack[sp - 1];
          stack[sp - 1] = (math.exp(v) + math.exp(-v)) / 2.0;
        case Op.tanh:
          final v = stack[sp - 1];
          if (v > 20.0) {
            stack[sp - 1] = 1.0;
          } else if (v < -20.0) {
            stack[sp - 1] = -1.0;
          } else {
            final e2 = math.exp(2.0 * v);
            stack[sp - 1] = (e2 - 1.0) / (e2 + 1.0);
          }
        case Op.abs:
          stack[sp - 1] = stack[sp - 1].abs();
        case Op.sqrt:
          stack[sp - 1] = math.sqrt(stack[sp - 1]);
        case Op.lambertW0:
          stack[sp - 1] = evaluateLambertWReal(stack[sp - 1], branch: 0);
        case Op.lambertW1:
          stack[sp - 1] = evaluateLambertWReal(stack[sp - 1], branch: -1);
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
        case Op.asinh:
          final v = stack[sp - 1];
          stack[sp - 1] = math.log(v + math.sqrt(v * v + 1.0));
        case Op.acosh:
          final v = stack[sp - 1];
          stack[sp - 1] = v < 1.0
              ? double.nan
              : math.log(v + math.sqrt(v - 1.0) * math.sqrt(v + 1.0));
        case Op.atanh:
          final v = stack[sp - 1];
          stack[sp - 1] = (v < -1.0 || v > 1.0)
              ? double.nan
              : (v == 1.0
                    ? double.infinity
                    : (v == -1.0
                          ? double.negativeInfinity
                          : 0.5 * math.log((1.0 + v) / (1.0 - v))));
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
          final ctx = <String, Complex>{
            for (var i = 0; i < variables.length; i++) variables[i]: loadVar(i),
          };
          stack[sp++] = instr.node!.evaluateComplex(ctx);
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
          stack[sp - 1] = Complex(
            evaluateLambertWReal(z.a.toDouble(), branch: 0),
          );
        case Op.lambertW1:
          final z = stack[sp - 1];
          if (z.b != 0.0) {
            throw UnsupportedError(
              'Complex LambertW evaluation is only supported on R',
            );
          }
          stack[sp - 1] = Complex(
            evaluateLambertWReal(z.a.toDouble(), branch: -1),
          );
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
        case Op.asinh:
          final z = stack[sp - 1];
          stack[sp - 1] = (z + (z * z + Complex.one).sqrt()).log();
        case Op.acosh:
          final z = stack[sp - 1];
          stack[sp - 1] =
              (z + (z + Complex.one).sqrt() * (z - Complex.one).sqrt()).log();
        case Op.atanh:
          final z = stack[sp - 1];
          stack[sp - 1] =
              ((Complex.one + z) / (Complex.one - z)).log() *
              const Complex(0.5);
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
      }
    }
    return stack[0];
  }
}

double _realPow(double base, double exponent) =>
    math.pow(base, exponent).toDouble();

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
