import 'dart:math' as math;

import 'package:more/number.dart' show Complex;

import '../ast.dart';
import 'evaluator.dart';

/// Opcodes for the symbolic stack-and-register virtual machine.
enum Op {
  /// Pushes a constant scalar onto the stack.
  pushConst,

  /// Loads a positional variable onto the stack.
  loadVar,

  /// Stores the top-of-stack value into a CSE register without popping.
  storeReg,

  /// Pushes a previously computed CSE register value onto the stack.
  loadReg,

  /// Unconditional jump to target instruction index.
  jump,

  /// Pops condition; jumps to target instruction index if false (`0.0` or `NaN`).
  jumpIfFalse,

  /// Evaluates an embedded AST node (such as a definite [Integral]).
  evalNode,

  /// Binary addition (`a + b`).
  add,

  /// Binary subtraction (`a - b`).
  sub,

  /// Binary multiplication (`a * b`).
  mul,

  /// Binary division (`a / b`).
  div,

  /// Binary exponentiation (`a ^ b`).
  pow,

  /// Unary negation (`-a`).
  neg,

  /// Sine (`sin(a)`).
  sin,

  /// Cosine (`cos(a)`).
  cos,

  /// Natural exponential (`exp(a)`).
  exp,

  /// Natural logarithm (`ln(a)`).
  ln,

  /// Tangent (`tan(a)`).
  tan,

  /// Arcsine (`asin(a)`).
  asin,

  /// Arccosine (`acos(a)`).
  acos,

  /// Arctangent (`atan(a)`).
  atan,

  /// Hyperbolic sine (`sinh(a)`).
  sinh,

  /// Hyperbolic cosine (`cosh(a)`).
  cosh,

  /// Hyperbolic tangent (`tanh(a)`).
  tanh,

  /// Absolute value / modulus (`|a|`).
  abs,

  /// Square root (`sqrt(a)`).
  sqrt,

  /// Principal branch Lambert W (`W_0(a)`).
  lambertW0,

  /// Lower branch Lambert W (`W_{-1}(a)`).
  lambertW1,

  /// Error function (`erf(a)`).
  erf,

  /// Complementary error function (`erfc(a)`).
  erfc,

  /// Gamma function (`Gamma(a)`).
  gamma,

  /// Beta function (`B(a, b)`).
  beta,

  /// Inverse hyperbolic sine (`asinh(a)`).
  asinh,

  /// Inverse hyperbolic cosine (`acosh(a)`).
  acosh,

  /// Inverse hyperbolic tangent (`atanh(a)`).
  atanh,

  /// Strict less-than (`a < b`).
  lt,

  /// Less-than-or-equal (`a <= b`).
  le,

  /// Strict greater-than (`a > b`).
  gt,

  /// Greater-than-or-equal (`a >= b`).
  ge,

  /// Equality (`a == b`).
  eq,
}

/// A single instruction in a compiled [BytecodeEvaluator] program.
final class Instruction {
  const new _(
    this.op, {
    this.realValue = 0.0,
    this.complexValue = Complex.zero,
    this.index = 0,
    this.node,
  });

  /// Creates a constant-push instruction for a real scalar [value].
  new pushReal(double value)
    : this._(Op.pushConst, realValue: value, complexValue: Complex(value));

  /// Creates a constant-push instruction for a complex scalar [value].
  new pushComplex(Complex value)
    : this._(
        Op.pushConst,
        realValue: value.b == 0.0 ? value.a.toDouble() : double.nan,
        complexValue: value,
      );

  /// Creates a variable-load instruction for positional index [varIndex].
  const new loadVar(int varIndex) : this._(Op.loadVar, index: varIndex);

  /// Creates a CSE register-store instruction for [regIndex].
  const new storeReg(int regIndex) : this._(Op.storeReg, index: regIndex);

  /// Creates a CSE register-load instruction for [regIndex].
  const new loadReg(int regIndex) : this._(Op.loadReg, index: regIndex);

  /// Creates an unconditional jump instruction to [targetPc].
  const new jump(int targetPc) : this._(Op.jump, index: targetPc);

  /// Creates a conditional jump-if-false instruction to [targetPc].
  const new jumpIfFalse(int targetPc) : this._(Op.jumpIfFalse, index: targetPc);

  /// Creates an AST node fallback evaluation instruction for [node].
  const new evalNode(Expr node) : this._(Op.evalNode, node: node);

  /// Creates a zero-operand stack instruction for [op].
  const new op(Op op) : this._(op);

  /// The operation code.
  final Op op;

  /// Real scalar constant payload for [Op.pushConst].
  final double realValue;

  /// Complex scalar constant payload for [Op.pushConst].
  final Complex complexValue;

  /// Variable index, register index, or jump target program counter.
  final int index;

  /// Embedded expression node for [Op.evalNode].
  final Expr? node;
}

/// Compiles [simplified] into a [BytecodeEvaluator] over [variables],
/// applying DAG Common Subexpression Elimination (CSE) when [optimize] is `true`.
BytecodeEvaluator compileToBytecode(
  Expr simplified,
  List<String> variables, {
  bool optimize = true,
  bool allowDynamicVars = false,
}) {
  final varOrder = List<String>.of(variables);
  final varIndices = <String, int>{
    for (var i = 0; i < varOrder.length; i++) varOrder[i]: i,
  };

  final regMap = <Expr, int>{};
  if (optimize) {
    final counts = <Expr, int>{};
    void countSubtrees(Expr node) {
      if (_isCompositeCandidate(node)) {
        final prev = counts[node] ?? 0;
        counts[node] = prev + 1;
        if (prev > 0) {
          // Do not traverse children again when a shared composite node is hit;
          // its entire subtree will be evaluated once and loaded from a register.
          return;
        }
      }
      _forEachChild(node, countSubtrees);
    }

    countSubtrees(simplified);
    for (final entry in counts.entries) {
      if (entry.value >= 2) {
        regMap[entry.key] = regMap.length;
      }
    }
  }

  final instructions = <Instruction>[];
  final emittedRegs = <int>{};
  var hasComplexLiterals = false;
  Expr? firstComplexLiteral;

  void emit(Expr expr) {
    final regIdx = regMap[expr];
    if (regIdx != null && emittedRegs.contains(regIdx)) {
      instructions.add(Instruction.loadReg(regIdx));
      return;
    }

    switch (expr) {
      case Constant(isReal: false, :final value):
        hasComplexLiterals = true;
        firstComplexLiteral ??= expr;
        instructions.add(Instruction.pushComplex(value));
      case Constant(:final value):
        instructions.add(Instruction.pushReal(value.a.toDouble()));
      case ComplexNumber():
        hasComplexLiterals = true;
        firstComplexLiteral ??= expr;
        instructions.add(Instruction.pushComplex(expr.toComplex()));
      case RealNumeric():
        instructions.add(Instruction.pushReal(expr.toDouble()));
      case Variable(:final name):
        var idx = varIndices[name];
        if (idx == null) {
          if (allowDynamicVars) {
            idx = varOrder.length;
            varOrder.add(name);
            varIndices[name] = idx;
          } else {
            throw ArgumentError('Unbound variable: "$name"');
          }
        }
        instructions.add(Instruction.loadVar(idx));
      case Add(:final terms):
        if (terms.isEmpty) {
          instructions.add(Instruction.pushReal(0.0));
        } else {
          emit(terms[0]);
          for (var i = 1; i < terms.length; i++) {
            emit(terms[i]);
            instructions.add(const Instruction.op(Op.add));
          }
        }
      case Mul(:final factors):
        if (factors.isEmpty) {
          instructions.add(Instruction.pushReal(1.0));
        } else if (factors.length == 2 &&
            factors[0] == IntegerNumber.negativeOne) {
          emit(factors[1]);
          instructions.add(const Instruction.op(Op.neg));
        } else {
          emit(factors[0]);
          for (var i = 1; i < factors.length; i++) {
            emit(factors[i]);
            instructions.add(const Instruction.op(Op.mul));
          }
        }
      case Pow(base: Constant.e, :final exponent):
        emit(exponent);
        instructions.add(const Instruction.op(Op.exp));
      case Pow(:final base, :final exponent)
          when exponent == FractionNumber.half ||
              exponent == const RealNumber(0.5):
        emit(base);
        instructions.add(const Instruction.op(Op.sqrt));
      case Pow(:final base, exponent: IntegerNumber(isNegativeOne: true)):
        instructions.add(Instruction.pushReal(1.0));
        emit(base);
        instructions.add(const Instruction.op(Op.div));
      case Pow(:final base, :final exponent):
        emit(base);
        emit(exponent);
        instructions.add(const Instruction.op(Op.pow));
      case Sin(:final expr):
        emit(expr);
        instructions.add(const Instruction.op(Op.sin));
      case Cos(:final expr):
        emit(expr);
        instructions.add(const Instruction.op(Op.cos));
      case Ln(:final expr):
        emit(expr);
        instructions.add(const Instruction.op(Op.ln));
      case Tan(:final expr):
        emit(expr);
        instructions.add(const Instruction.op(Op.tan));
      case Asin(:final expr):
        emit(expr);
        instructions.add(const Instruction.op(Op.asin));
      case Acos(:final expr):
        emit(expr);
        instructions.add(const Instruction.op(Op.acos));
      case Atan(:final expr):
        emit(expr);
        instructions.add(const Instruction.op(Op.atan));
      case Sinh(:final expr):
        emit(expr);
        instructions.add(const Instruction.op(Op.sinh));
      case Cosh(:final expr):
        emit(expr);
        instructions.add(const Instruction.op(Op.cosh));
      case Tanh(:final expr):
        emit(expr);
        instructions.add(const Instruction.op(Op.tanh));
      case Abs(:final expr):
        emit(expr);
        instructions.add(const Instruction.op(Op.abs));
      case LambertW(:final expr, :final branch):
        emit(expr);
        instructions.add(
          Instruction.op(branch == 0 ? Op.lambertW0 : Op.lambertW1),
        );
      case Erf(:final expr):
        emit(expr);
        instructions.add(const Instruction.op(Op.erf));
      case Erfc(:final expr):
        emit(expr);
        instructions.add(const Instruction.op(Op.erfc));
      case Gamma(:final expr):
        emit(expr);
        instructions.add(const Instruction.op(Op.gamma));
      case Beta(:final left, :final right):
        emit(left);
        emit(right);
        instructions.add(const Instruction.op(Op.beta));
      case Asinh(:final expr):
        emit(expr);
        instructions.add(const Instruction.op(Op.asinh));
      case Acosh(:final expr):
        emit(expr);
        instructions.add(const Instruction.op(Op.acosh));
      case Atanh(:final expr):
        emit(expr);
        instructions.add(const Instruction.op(Op.atanh));
      case LessThan(:final left, :final right):
        emit(left);
        emit(right);
        instructions.add(const Instruction.op(Op.lt));
      case LessEqual(:final left, :final right):
        emit(left);
        emit(right);
        instructions.add(const Instruction.op(Op.le));
      case GreaterThan(:final left, :final right):
        emit(left);
        emit(right);
        instructions.add(const Instruction.op(Op.gt));
      case GreaterEqual(:final left, :final right):
        emit(left);
        emit(right);
        instructions.add(const Instruction.op(Op.ge));
      case Equal(:final left, :final right):
        emit(left);
        emit(right);
        instructions.add(const Instruction.op(Op.eq));
      case Piecewise(:final branches, :final otherwise):
        final endJumps = <int>[];
        for (final (cond, branchExpr) in branches) {
          emit(cond);
          final jFalseIdx = instructions.length;
          instructions.add(const Instruction.jumpIfFalse(0));
          emit(branchExpr);
          endJumps.add(instructions.length);
          instructions.add(const Instruction.jump(0));
          instructions[jFalseIdx] = Instruction.jumpIfFalse(
            instructions.length,
          );
        }
        if (otherwise != null) {
          emit(otherwise);
        } else {
          instructions.add(Instruction.pushReal(double.nan));
        }
        final endPc = instructions.length;
        for (final jmpIdx in endJumps) {
          instructions[jmpIdx] = Instruction.jump(endPc);
        }
      case Integral():
        for (final freeVar in expr.freeVariables) {
          if (!varIndices.containsKey(freeVar)) {
            if (allowDynamicVars) {
              final idx = varOrder.length;
              varOrder.add(freeVar);
              varIndices[freeVar] = idx;
            } else {
              throw ArgumentError('Unbound variable: "$freeVar"');
            }
          }
        }
        instructions.add(Instruction.evalNode(expr));
      case OrderTerm():
        instructions.add(Instruction.pushReal(0.0));
    }

    if (regIdx != null) {
      instructions.add(Instruction.storeReg(regIdx));
      emittedRegs.add(regIdx);
    }
  }

  emit(simplified);

  return BytecodeEvaluator(
    variables: List.unmodifiable(varOrder),
    instructions: List.unmodifiable(instructions),
    maxStack: _computeMaxStack(instructions),
    registerCount: regMap.length,
    hasComplexLiterals: hasComplexLiterals,
    firstComplexLiteral: firstComplexLiteral,
  );
}

bool _isCompositeCandidate(Expr node) => switch (node) {
  Number() || Constant() || Variable() || OrderTerm() || Piecewise() => false,
  _ => true,
};

void _forEachChild(Expr node, void Function(Expr) visit) {
  switch (node) {
    case Add(:final terms):
      for (final t in terms) {
        visit(t);
      }
    case Mul(:final factors):
      for (final f in factors) {
        visit(f);
      }
    case BinaryExpr(:final left, :final right):
      visit(left);
      visit(right);
    case UnaryExpr(:final expr):
      visit(expr);
    case Piecewise(:final branches, :final otherwise):
      for (final (cond, val) in branches) {
        visit(cond);
        visit(val);
      }
      if (otherwise != null) visit(otherwise);
    case Integral(:final integrand, :final lower, :final upper):
      visit(integrand);
      if (lower != null) visit(lower);
      if (upper != null) visit(upper);
    case Number() || Constant() || Variable() || OrderTerm():
      break;
  }
}

int _computeMaxStack(List<Instruction> instructions) {
  var current = 0;
  var maxDepth = 0;
  for (final instr in instructions) {
    switch (instr.op) {
      case Op.pushConst || Op.loadVar || Op.loadReg || Op.evalNode:
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
          Op.eq ||
          Op.jumpIfFalse:
        current = math.max(0, current - 1);
      case Op.storeReg ||
          Op.jump ||
          Op.neg ||
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
  return math.max(maxDepth + 2, 2);
}
