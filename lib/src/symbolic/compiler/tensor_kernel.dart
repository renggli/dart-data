import 'dart:math' as math;
import 'dart:typed_data';

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
  final stack = Float64List(maxStack);
  final instrs = instructions;
  final numInstrs = instrs.length;

  return (List<Float64List> inputs, Float64List output) {
    final len = output.length;

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
            stack[sp - 1] = (math.exp(v) - math.exp(-v)) / 2.0;
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
            stack[sp - 1] = evaluateLambertW(stack[sp - 1], 0);
          case Op.lambertW1:
            stack[sp - 1] = evaluateLambertW(stack[sp - 1], -1);
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
    case ComplexNumber(:final imaginary) when imaginary != 0.0:
    case ConstantNumber(name: 'i'):
      throw UnsupportedError(
        'compileTensorKernel does not support expressions with imaginary constant "i".',
      );
    case Number(:final value):
      instructions.add(Instruction.pushConst(value));
    case Variable(:final name):
      final idx = varIndices[name];
      if (idx == null) {
        throw ArgumentError('Unbound variable: $name');
      }
      instructions.add(Instruction.loadVar(idx));
    case Add(:final left, :final right):
      flattenToRpn(left, varIndices, instructions);
      flattenToRpn(right, varIndices, instructions);
      instructions.add(const Instruction.op(Op.add));
    case Sub(:final left, :final right):
      flattenToRpn(left, varIndices, instructions);
      flattenToRpn(right, varIndices, instructions);
      instructions.add(const Instruction.op(Op.sub));
    case Mul(:final left, :final right):
      flattenToRpn(left, varIndices, instructions);
      flattenToRpn(right, varIndices, instructions);
      instructions.add(const Instruction.op(Op.mul));
    case Div(:final left, :final right):
      flattenToRpn(left, varIndices, instructions);
      flattenToRpn(right, varIndices, instructions);
      instructions.add(const Instruction.op(Op.div));
    case Pow(
      :final base,
      exponent: RationalNumber(numerator: 1, denominator: 2) ||
          RealNumber(value: 0.5),
    ):
      flattenToRpn(base, varIndices, instructions);
      instructions.add(const Instruction.op(Op.sqrt));
    case Pow(:final base, :final exponent):
      flattenToRpn(base, varIndices, instructions);
      flattenToRpn(exponent, varIndices, instructions);
      instructions.add(const Instruction.op(Op.pow));
    case Neg(:final expr):
      flattenToRpn(expr, varIndices, instructions);
      instructions.add(const Instruction.op(Op.neg));
    case Sin(:final expr):
      flattenToRpn(expr, varIndices, instructions);
      instructions.add(const Instruction.op(Op.sin));
    case Cos(:final expr):
      flattenToRpn(expr, varIndices, instructions);
      instructions.add(const Instruction.op(Op.cos));
    case Exp(:final expr):
      flattenToRpn(expr, varIndices, instructions);
      instructions.add(const Instruction.op(Op.exp));
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
    case Erf() ||
        Erfc() ||
        Gamma() ||
        Beta() ||
        Asinh() ||
        Acosh() ||
        Atanh() ||
        RelationalExpr() ||
        Piecewise():
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
      case Op.add || Op.sub || Op.mul || Op.div || Op.pow:
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
          Op.lambertW1:
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
