import 'dart:math' as math;
import 'dart:typed_data';

import '../../special/beta.dart' as special_beta;
import '../../special/erf.dart' as special_erf;
import '../../special/gamma.dart' as special_gamma;
import '../ast.dart';

/// Compiles [simplified] expression into a vectorized tensor kernel over [varOrder].
void Function(List<Float64List> inputs, Float64List output) buildTensorKernel(
  Expr simplified,
  List<String> varOrder,
) {
  final varIndices = {for (var i = 0; i < varOrder.length; i++) varOrder[i]: i};
  final instructions = <Instruction>[];
  flattenToRpn(simplified, varIndices, instructions);
  final maxStack = computeMaxStack(instructions);
  final instrs = instructions;
  final numInstrs = instrs.length;
  final expectedInputs = varOrder.length;

  return (List<Float64List> inputs, Float64List output) {
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
    final stack = Float64List(maxStack);

    for (var i = 0; i < len; i++) {
      var sp = 0;
      for (var pc = 0; pc < numInstrs; pc++) {
        final instr = instrs[pc];
        switch (instr.op) {
          case Op.pushConst:
            stack[sp++] = instr.constValue;
          case Op.loadVar:
            stack[sp++] = inputs[instr.varIndex][i];
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
            stack[sp++] = math.pow(a, b).toDouble();
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
      output[i] = stack[0];
    }
  };
}

/// Flattens [expr] into RPN instruction bytecode.
void flattenToRpn(
  Expr expr,
  Map<String, int> varIndices,
  List<Instruction> instructions,
) {
  switch (expr) {
    case Constant(isReal: false, :final name):
      throw UnsupportedError(
        'compileTensorKernel does not support expressions with imaginary constant "$name".',
      );
    case Constant(:final value):
      instructions.add(Instruction.pushConst(value.a.toDouble()));
    case ComplexNumber():
      throw UnsupportedError(
        'compileTensorKernel does not support complex numbers: $expr.',
      );
    case RealNumeric():
      instructions.add(Instruction.pushConst(expr.toDouble()));
    case Variable(:final name):
      final idx = varIndices[name];
      if (idx == null) {
        throw ArgumentError('Unbound variable: $name');
      }
      instructions.add(Instruction.loadVar(idx));
    case Add(:final terms):
      if (terms.isEmpty) {
        instructions.add(const Instruction.pushConst(0.0));
        return;
      }
      flattenToRpn(terms[0], varIndices, instructions);
      for (var i = 1; i < terms.length; i++) {
        flattenToRpn(terms[i], varIndices, instructions);
        instructions.add(const Instruction.op(Op.add));
      }
    case Mul(:final factors):
      if (factors.isEmpty) {
        instructions.add(const Instruction.pushConst(1.0));
        return;
      }
      if (factors.length == 2 && factors[0] == IntegerNumber.negativeOne) {
        flattenToRpn(factors[1], varIndices, instructions);
        instructions.add(const Instruction.op(Op.neg));
        return;
      }
      flattenToRpn(factors[0], varIndices, instructions);
      for (var i = 1; i < factors.length; i++) {
        flattenToRpn(factors[i], varIndices, instructions);
        instructions.add(const Instruction.op(Op.mul));
      }
    case Pow(base: Constant.e, :final exponent):
      flattenToRpn(exponent, varIndices, instructions);
      instructions.add(const Instruction.op(Op.exp));
    case Pow(:final base, :final exponent)
        when exponent == FractionNumber.half ||
            exponent == const RealNumber(0.5):
      flattenToRpn(base, varIndices, instructions);
      instructions.add(const Instruction.op(Op.sqrt));
    case Pow(:final base, exponent: IntegerNumber(isNegativeOne: true)):
      instructions.add(const Instruction.pushConst(1.0));
      flattenToRpn(base, varIndices, instructions);
      instructions.add(const Instruction.op(Op.div));
    case Pow(:final base, :final exponent):
      flattenToRpn(base, varIndices, instructions);
      flattenToRpn(exponent, varIndices, instructions);
      instructions.add(const Instruction.op(Op.pow));
    case Sin(:final expr):
      flattenToRpn(expr, varIndices, instructions);
      instructions.add(const Instruction.op(Op.sin));
    case Cos(:final expr):
      flattenToRpn(expr, varIndices, instructions);
      instructions.add(const Instruction.op(Op.cos));
    case Ln(:final expr):
      flattenToRpn(expr, varIndices, instructions);
      instructions.add(const Instruction.op(Op.ln));
    case Tan(:final expr):
      flattenToRpn(expr, varIndices, instructions);
      instructions.add(const Instruction.op(Op.tan));
    case Asin(:final expr):
      flattenToRpn(expr, varIndices, instructions);
      instructions.add(const Instruction.op(Op.asin));
    case Acos(:final expr):
      flattenToRpn(expr, varIndices, instructions);
      instructions.add(const Instruction.op(Op.acos));
    case Atan(:final expr):
      flattenToRpn(expr, varIndices, instructions);
      instructions.add(const Instruction.op(Op.atan));
    case Sinh(:final expr):
      flattenToRpn(expr, varIndices, instructions);
      instructions.add(const Instruction.op(Op.sinh));
    case Cosh(:final expr):
      flattenToRpn(expr, varIndices, instructions);
      instructions.add(const Instruction.op(Op.cosh));
    case Tanh(:final expr):
      flattenToRpn(expr, varIndices, instructions);
      instructions.add(const Instruction.op(Op.tanh));
    case Abs(:final expr):
      flattenToRpn(expr, varIndices, instructions);
      instructions.add(const Instruction.op(Op.abs));
    case LambertW(:final expr, :final branch):
      flattenToRpn(expr, varIndices, instructions);
      instructions.add(
        Instruction.op(branch == 0 ? Op.lambertW0 : Op.lambertW1),
      );
    case Erf(:final expr):
      flattenToRpn(expr, varIndices, instructions);
      instructions.add(const Instruction.op(Op.erf));
    case Erfc(:final expr):
      flattenToRpn(expr, varIndices, instructions);
      instructions.add(const Instruction.op(Op.erfc));
    case Gamma(:final expr):
      flattenToRpn(expr, varIndices, instructions);
      instructions.add(const Instruction.op(Op.gamma));
    case Beta(:final left, :final right):
      flattenToRpn(left, varIndices, instructions);
      flattenToRpn(right, varIndices, instructions);
      instructions.add(const Instruction.op(Op.beta));
    case Asinh(:final expr):
      flattenToRpn(expr, varIndices, instructions);
      instructions.add(const Instruction.op(Op.asinh));
    case Acosh(:final expr):
      flattenToRpn(expr, varIndices, instructions);
      instructions.add(const Instruction.op(Op.acosh));
    case Atanh(:final expr):
      flattenToRpn(expr, varIndices, instructions);
      instructions.add(const Instruction.op(Op.atanh));
    case LessThan(:final left, :final right):
      flattenToRpn(left, varIndices, instructions);
      flattenToRpn(right, varIndices, instructions);
      instructions.add(const Instruction.op(Op.lt));
    case LessEqual(:final left, :final right):
      flattenToRpn(left, varIndices, instructions);
      flattenToRpn(right, varIndices, instructions);
      instructions.add(const Instruction.op(Op.le));
    case GreaterThan(:final left, :final right):
      flattenToRpn(left, varIndices, instructions);
      flattenToRpn(right, varIndices, instructions);
      instructions.add(const Instruction.op(Op.gt));
    case GreaterEqual(:final left, :final right):
      flattenToRpn(left, varIndices, instructions);
      flattenToRpn(right, varIndices, instructions);
      instructions.add(const Instruction.op(Op.ge));
    case Equal(:final left, :final right):
      flattenToRpn(left, varIndices, instructions);
      flattenToRpn(right, varIndices, instructions);
      instructions.add(const Instruction.op(Op.eq));
    case Piecewise():
      throw UnsupportedError(
        'compileTensorKernel does not support ${expr.runtimeType}.',
      );
    case OrderTerm():
      instructions.add(const Instruction.pushConst(0.0));
  }
}

/// Computes the maximum stack depth needed to evaluate [instructions].
int computeMaxStack(List<Instruction> instructions) {
  var current = 0;
  var maxDepth = 0;
  for (final instr in instructions) {
    switch (instr.op) {
      case Op.pushConst || Op.loadVar:
        current++;
      case Op.add ||
          Op.sub ||
          Op.mul ||
          Op.div ||
          Op.pow ||
          Op.beta ||
          Op.lt ||
          Op.le ||
          Op.gt ||
          Op.ge ||
          Op.eq:
        current--;
      case Op.neg ||
          Op.sin ||
          Op.cos ||
          Op.exp ||
          Op.ln ||
          Op.tan ||
          Op.asin ||
          Op.acos ||
          Op.atan ||
          Op.sinh ||
          Op.cosh ||
          Op.tanh ||
          Op.abs ||
          Op.sqrt ||
          Op.lambertW0 ||
          Op.lambertW1 ||
          Op.erf ||
          Op.erfc ||
          Op.gamma ||
          Op.asinh ||
          Op.acosh ||
          Op.atanh:
        break;
    }
    if (current > maxDepth) {
      maxDepth = current;
    }
  }
  return math.max(maxDepth, 1);
}

/// Opcodes for stack bytecode virtual machine.
enum Op {
  pushConst,
  loadVar,
  add,
  sub,
  mul,
  div,
  pow,
  neg,
  sin,
  cos,
  exp,
  ln,
  tan,
  asin,
  acos,
  atan,
  sinh,
  cosh,
  tanh,
  abs,
  sqrt,
  lambertW0,
  lambertW1,
  erf,
  erfc,
  gamma,
  beta,
  asinh,
  acosh,
  atanh,
  lt,
  le,
  gt,
  ge,
  eq,
}

/// A compact stack VM instruction.
final class Instruction {
  const new _(this.op, this.constValue, this.varIndex);
  const new pushConst(double val) : this._(Op.pushConst, val, 0);
  const new loadVar(int idx) : this._(Op.loadVar, 0.0, idx);
  const new op(Op op) : this._(op, 0.0, 0);

  final Op op;
  final double constValue;
  final int varIndex;
}
