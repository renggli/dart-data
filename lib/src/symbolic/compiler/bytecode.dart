import 'dart:typed_data';

import 'package:more/number.dart' show Complex;

import '../ast.dart';
import 'evaluator.dart';

/// Compact operation codes for the flat 3-address register virtual machine.
enum Op {
  /// Copies a register value: `regs[dst] = regs[a]`.
  move,

  /// Addition: `regs[dst] = regs[a] + regs[b]`.
  add,

  /// Subtraction: `regs[dst] = regs[a] - regs[b]`.
  sub,

  /// Multiplication: `regs[dst] = regs[a] * regs[b]`.
  mul,

  /// Division: `regs[dst] = regs[a] / regs[b]`.
  div,

  /// General exponentiation: `regs[dst] = pow(regs[a], regs[b])`.
  pow,

  /// Integer exponentiation by squaring: `regs[dst] = pow(regs[a], b)` (`|b| <= 64`).
  powInt,

  /// Odd-denominator real negative-base odd-numerator root: `-pow(-base, exp)`.
  powOddRootOdd,

  /// Odd-denominator real negative-base even-numerator root: `pow(-base, exp)`.
  powOddRootEven,

  /// Unary negation: `regs[dst] = -regs[a]`.
  neg,

  /// Square root: `regs[dst] = sqrt(regs[a])`.
  sqrt,

  /// Sine: `regs[dst] = sin(regs[a])`.
  sin,

  /// Cosine: `regs[dst] = cos(regs[a])`.
  cos,

  /// Tangent: `regs[dst] = tan(regs[a])`.
  tan,

  /// Natural exponential: `regs[dst] = exp(regs[a])`.
  exp,

  /// Natural logarithm: `regs[dst] = ln(regs[a])`.
  ln,

  /// Absolute value / complex modulus: `regs[dst] = |regs[a]|`.
  abs,

  /// Relational less-than: `regs[dst] = regs[a] < regs[b] ? 1.0 : 0.0`.
  relLt,

  /// Relational less-than-or-equal: `regs[dst] = regs[a] <= regs[b] ? 1.0 : 0.0`.
  relLe,

  /// Relational greater-than: `regs[dst] = regs[a] > regs[b] ? 1.0 : 0.0`.
  relGt,

  /// Relational greater-than-or-equal: `regs[dst] = regs[a] >= regs[b] ? 1.0 : 0.0`.
  relGe,

  /// Relational equal: `regs[dst] = regs[a] == regs[b] ? 1.0 : 0.0`.
  relEq,

  /// Relational not-equal: `regs[dst] = regs[a] != regs[b] ? 1.0 : 0.0`.
  relNe,

  /// Unconditional branch to instruction word offset `dst`.
  jump,

  /// Branches to word offset `dst` when `regs[a]` is `0.0` or `NaN`.
  jumpIfFalse,

  /// Unary [FunctionSpec] call: `regs[dst] = specs[b].eval(regs[a])`.
  call1,

  /// Binary [FunctionSpec] call: `a` = offset in `callArgs` `[r0, r1]`, `b` = `specIdx`.
  call2,

  /// Variadic/ternary [FunctionSpec] call: `a` = offset in `callArgs`, `b` = `(argc << 16) | specIdx`.
  callN,

  /// Generalized hypergeometric `pFq`: `a` = offset in `callArgs`, `b` = `(p << 8) | q`.
  hypergeometric,

  /// Evaluates embedded AST node `nodes[a]` -> `regs[dst]`.
  evalNode,
}

/// Compiles [simplified] into a flat register [BytecodeEvaluator] over
/// [variables], applying DAG Common Subexpression Elimination (CSE) when
/// [optimize] is `true`.
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

  final counts = <Expr, int>{};
  void scan(Expr node) {
    if (optimize && _isCompositeCandidate(node)) {
      final prev = counts[node] ?? 0;
      counts[node] = prev + 1;
      if (prev > 0) return;
    }
    switch (node) {
      case Variable(:final name):
        if (!varIndices.containsKey(name)) {
          if (allowDynamicVars) {
            varIndices[name] = varOrder.length;
            varOrder.add(name);
          } else {
            throw ArgumentError('Unbound variable: "$name"');
          }
        }
      case Call(id: FunctionId.hypergeometric, :final args):
        final upper =
            args[0] is Call && (args[0] as Call).id == FunctionId.tuple
            ? (args[0] as Call).args
            : [args[0]];
        final lower =
            args[1] is Call && (args[1] as Call).id == FunctionId.tuple
            ? (args[1] as Call).args
            : [args[1]];
        for (final u in upper) {
          scan(u);
        }
        for (final l in lower) {
          scan(l);
        }
        scan(args[2]);
        return;
      case Call(id: FunctionId.tuple):
        throw UnsupportedError(
          'Cannot compile symbolic Tuple to scalar bytecode',
        );
      case Call(id: FunctionId.symbolic, :final name):
        throw UnsupportedError(
          'Cannot compile unbound function "$name" to numeric bytecode',
        );
      case Integral(:final lower, :final upper)
          when allowDynamicVars && (lower == null || upper == null):
        return;
      case Integral() ||
          Derivative() ||
          Limit() ||
          Sum() ||
          Product() ||
          RootSum():
        for (final freeVar in node.freeVariables) {
          if (!varIndices.containsKey(freeVar)) {
            if (allowDynamicVars) {
              varIndices[freeVar] = varOrder.length;
              varOrder.add(freeVar);
            } else {
              throw ArgumentError('Unbound variable: "$freeVar"');
            }
          }
        }
        return;
      default:
        break;
    }
    _forEachChild(node, scan);
  }

  scan(simplified);
  final varCount = varOrder.length;

  final cseCandidates = <Expr, int>{};
  if (optimize) {
    for (final entry in counts.entries) {
      if (entry.value >= 2) {
        cseCandidates[entry.key] = varCount + cseCandidates.length;
      }
    }
  }
  final cseCount = cseCandidates.length;
  final tempBase = varCount + cseCount;
  var nextTemp = tempBase;
  var maxTempEnd = tempBase;

  int allocTemp() {
    final r = nextTemp++;
    if (nextTemp > maxTempEnd) maxTempEnd = nextTemp;
    return r;
  }

  // Negative tags (-1 - k) denote constant pool entries during lowering, and
  // are relocated to [varCount .. varCount + constCount - 1] once emission ends.
  final constMap = <_ConstKey, int>{};
  final constReal = <double>[];
  final constComplex = <double>[];

  int internConst(double reReal, double cmpRe, double cmpIm) {
    final key = _ConstKey(reReal, cmpRe, cmpIm);
    final existing = constMap[key];
    if (existing != null) return existing;
    final idx = constReal.length;
    constReal.add(reReal);
    constComplex.add(cmpRe);
    constComplex.add(cmpIm);
    final tag = -1 - idx;
    constMap[key] = tag;
    return tag;
  }

  int realConstReg(double v) => internConst(v, v, 0.0);

  final specs = <FunctionSpec>[];
  final specMap = <FunctionSpec, int>{};
  int internSpec(FunctionSpec spec) => specMap.putIfAbsent(spec, () {
    final idx = specs.length;
    specs.add(spec);
    return idx;
  });

  final nodes = <Expr>[];
  final rawCode = <int>[];
  final rawCallArgs = <int>[];
  final emittedCse = <int>{};
  var hasComplexLiterals = false;
  Expr? firstComplexLiteral;

  void emitInstr(Op op, int dst, int a, int b) {
    rawCode
      ..add(op.index)
      ..add(dst)
      ..add(a)
      ..add(b);
  }

  int pushCallArgs(List<int> args) {
    final start = rawCallArgs.length;
    rawCallArgs.addAll(args);
    return start;
  }

  int resolveDst(int? preferred, Expr? cseNode) {
    if (cseNode != null) return cseCandidates[cseNode]!;
    return preferred ?? allocTemp();
  }

  late int Function(Expr, {int? target}) emit;

  int emitIntoNew(Expr expr) => emit(expr);

  int emitBinaryOp(Op op, Expr left, Expr right, int dst) {
    final ra = emitIntoNew(left);
    final rb = emitIntoNew(right);
    emitInstr(op, dst, ra, rb);
    return dst;
  }

  int emitPow(Expr base, Expr exponent, int dst) {
    if (base == Constant.e) {
      final re = emitIntoNew(exponent);
      emitInstr(Op.exp, dst, re, 0);
      return dst;
    }
    if (exponent == FractionNumber.half || exponent == const RealNumber(0.5)) {
      final rb = emitIntoNew(base);
      emitInstr(Op.sqrt, dst, rb, 0);
      return dst;
    }
    if (exponent is IntegerNumber) {
      if (exponent.isZero) return realConstReg(1.0);
      if (exponent.isOne) return emit(base, target: dst);
      if (exponent.isNegativeOne) {
        final c1 = realConstReg(1.0);
        final rb = emitIntoNew(base);
        emitInstr(Op.div, dst, c1, rb);
        return dst;
      }
      if (exponent.asInt case final e? when e.abs() <= 64) {
        final rb = emitIntoNew(base);
        emitInstr(Op.powInt, dst, rb, e);
        return dst;
      }
    }
    if (exponent case FractionNumber(:final numerator, :final denominator)
        when denominator.isOdd) {
      final rb = emitIntoNew(base);
      final re = emitIntoNew(exponent);
      emitInstr(
        numerator.isOdd ? Op.powOddRootOdd : Op.powOddRootEven,
        dst,
        rb,
        re,
      );
      return dst;
    }
    return emitBinaryOp(Op.pow, base, exponent, dst);
  }

  int emitCall(Call expr, int dst) {
    final spec = expr.spec;
    final args = expr.args;
    switch (spec.id) {
      case FunctionId.sin:
        emitInstr(Op.sin, dst, emitIntoNew(args[0]), 0);
        return dst;
      case FunctionId.cos:
        emitInstr(Op.cos, dst, emitIntoNew(args[0]), 0);
        return dst;
      case FunctionId.tan:
        emitInstr(Op.tan, dst, emitIntoNew(args[0]), 0);
        return dst;
      case FunctionId.ln:
        emitInstr(Op.ln, dst, emitIntoNew(args[0]), 0);
        return dst;
      case FunctionId.abs:
        emitInstr(Op.abs, dst, emitIntoNew(args[0]), 0);
        return dst;
      case FunctionId.hypergeometric:
        final upper =
            args[0] is Call && (args[0] as Call).id == FunctionId.tuple
            ? (args[0] as Call).args
            : [args[0]];
        final lower =
            args[1] is Call && (args[1] as Call).id == FunctionId.tuple
            ? (args[1] as Call).args
            : [args[1]];
        final regs = <int>[
          for (final u in upper) emitIntoNew(u),
          for (final l in lower) emitIntoNew(l),
          emitIntoNew(args[2]),
        ];
        final argStart = pushCallArgs(regs);
        emitInstr(
          Op.hypergeometric,
          dst,
          argStart,
          (upper.length << 8) | lower.length,
        );
        return dst;
      default:
        final specIdx = internSpec(spec);
        if (args.length == 1) {
          emitInstr(Op.call1, dst, emitIntoNew(args[0]), specIdx);
          return dst;
        }
        if (args.length == 2) {
          final r0 = emitIntoNew(args[0]);
          final r1 = emitIntoNew(args[1]);
          final argStart = pushCallArgs([r0, r1]);
          emitInstr(Op.call2, dst, argStart, specIdx);
          return dst;
        }
        final argRegs = [for (final a in args) emitIntoNew(a)];
        final argStart = pushCallArgs(argRegs);
        emitInstr(Op.callN, dst, argStart, (argRegs.length << 16) | specIdx);
        return dst;
    }
  }

  emit = (Expr expr, {int? target}) {
    final cseReg = cseCandidates[expr];
    if (cseReg != null && emittedCse.contains(cseReg)) {
      if (target != null && target != cseReg) {
        emitInstr(Op.move, target, cseReg, 0);
        return target;
      }
      return cseReg;
    }

    int finishLeaf(int leafReg) {
      if (cseReg != null) {
        emitInstr(Op.move, cseReg, leafReg, 0);
        emittedCse.add(cseReg);
        if (target != null && target != cseReg) {
          emitInstr(Op.move, target, cseReg, 0);
          return target;
        }
        return cseReg;
      }
      if (target != null && target != leafReg) {
        emitInstr(Op.move, target, leafReg, 0);
        return target;
      }
      return leafReg;
    }

    int finishComposite(int outReg) {
      if (cseReg != null) {
        emittedCse.add(cseReg);
        if (target != null && target != cseReg) {
          emitInstr(Op.move, target, cseReg, 0);
          return target;
        }
        return cseReg;
      }
      return outReg;
    }

    switch (expr) {
      case Constant(value: Complex(:final b)) when !b.isNaN && b != 0.0:
        hasComplexLiterals = true;
        firstComplexLiteral ??= expr;
        return finishLeaf(
          internConst(double.nan, expr.value.a.toDouble(), b.toDouble()),
        );
      case Constant(:final value):
        final a = value.a.toDouble();
        return finishLeaf(internConst(a, a, 0.0));
      case ComplexNumber():
        hasComplexLiterals = true;
        firstComplexLiteral ??= expr;
        final z = expr.toComplex();
        final re = z.a.toDouble();
        final im = z.b.toDouble();
        return finishLeaf(internConst(im == 0.0 ? re : double.nan, re, im));
      case RealNumeric():
        return finishLeaf(realConstReg(expr.toDouble()));
      case Variable(:final name):
        return finishLeaf(varIndices[name]!);
      case OrderTerm():
        return finishLeaf(realConstReg(0.0));
      case Add(terms: []):
        return finishLeaf(realConstReg(0.0));
      case Add(terms: [final single]):
        return finishLeaf(emit(single));
      case Add(:final terms):
        final dst = resolveDst(target, cseReg != null ? expr : null);
        var acc = emitIntoNew(terms.first);
        for (var i = 1; i < terms.length; i++) {
          final isLast = i == terms.length - 1;
          final out = isLast ? dst : allocTemp();
          final term = terms[i];
          if (term case Mul(
            factors: [IntegerNumber(isNegativeOne: true), final negInner],
          )) {
            final rhs = emitIntoNew(negInner);
            emitInstr(Op.sub, out, acc, rhs);
          } else {
            final rhs = emitIntoNew(term);
            emitInstr(Op.add, out, acc, rhs);
          }
          acc = out;
        }
        return finishComposite(acc);
      case Mul(factors: []):
        return finishLeaf(realConstReg(1.0));
      case Mul(factors: [final single]):
        return finishLeaf(emit(single));
      case Mul(factors: [IntegerNumber(isNegativeOne: true), final operand]):
        final dst = resolveDst(target, cseReg != null ? expr : null);
        final rOp = emitIntoNew(operand);
        emitInstr(Op.neg, dst, rOp, 0);
        return finishComposite(dst);
      case Mul(:final factors):
        final dst = resolveDst(target, cseReg != null ? expr : null);
        var acc = emitIntoNew(factors.first);
        for (var i = 1; i < factors.length; i++) {
          final isLast = i == factors.length - 1;
          final out = isLast ? dst : allocTemp();
          final rhs = emitIntoNew(factors[i]);
          emitInstr(Op.mul, out, acc, rhs);
          acc = out;
        }
        return finishComposite(acc);
      case Pow():
        final dst = resolveDst(target, cseReg != null ? expr : null);
        final out = emitPow(expr.base, expr.exponent, dst);
        return out == dst ? finishComposite(dst) : finishLeaf(out);
      case Call():
        final dst = resolveDst(target, cseReg != null ? expr : null);
        emitCall(expr, dst);
        return finishComposite(dst);
      case Relational(:final op, :final left, :final right):
        final dst = resolveDst(target, cseReg != null ? expr : null);
        emitBinaryOp(
          switch (op) {
            RelOp.lessThan => Op.relLt,
            RelOp.lessEqual => Op.relLe,
            RelOp.greaterThan => Op.relGt,
            RelOp.greaterEqual => Op.relGe,
            RelOp.equal => Op.relEq,
            RelOp.notEqual => Op.relNe,
          },
          left,
          right,
          dst,
        );
        return finishComposite(dst);
      case Piecewise(:final branches, :final otherwise):
        final outReg = resolveDst(target, cseReg != null ? expr : null);
        final endJumps = <int>[];
        final initialCse = Set<int>.of(emittedCse);
        final branchCse = <Set<int>>[];
        final branchTempBase = nextTemp;

        for (final (:relation, expr: body) in branches) {
          nextTemp = branchTempBase;
          final condReg = emitIntoNew(relation);
          final jFalseIdx = rawCode.length;
          emitInstr(Op.jumpIfFalse, 0, condReg, 0);

          final preBranchCse = Set<int>.of(emittedCse);
          final branchTempIn = nextTemp;
          emit(body, target: outReg);
          nextTemp = branchTempIn;
          branchCse.add(Set<int>.of(emittedCse));
          emittedCse
            ..clear()
            ..addAll(preBranchCse);

          endJumps.add(rawCode.length);
          emitInstr(Op.jump, 0, 0, 0);
          rawCode[jFalseIdx + 1] = rawCode.length;
        }

        nextTemp = branchTempBase;
        if (otherwise != null) {
          final preOtherwiseCse = Set<int>.of(emittedCse);
          emit(otherwise, target: outReg);
          branchCse.add(Set<int>.of(emittedCse));
          emittedCse
            ..clear()
            ..addAll(preOtherwiseCse);
        } else {
          branchCse.add(Set<int>.of(emittedCse));
          final nanReg = internConst(double.nan, double.nan, double.nan);
          emitInstr(Op.move, outReg, nanReg, 0);
        }
        nextTemp = branchTempBase;

        final endPc = rawCode.length;
        for (final jmpWord in endJumps) {
          rawCode[jmpWord + 1] = endPc;
        }

        emittedCse.clear();
        if (branchCse.isNotEmpty) {
          final common = branchCse.first.toSet();
          for (final regs in branchCse.skip(1)) {
            common.retainAll(regs);
          }
          emittedCse.addAll(common);
        } else {
          emittedCse.addAll(initialCse);
        }
        return finishComposite(outReg);
      case Integral(:final lower, :final upper)
          when lower == null || upper == null:
        return finishLeaf(internConst(double.nan, double.nan, double.nan));
      case Integral() ||
          Derivative() ||
          Limit() ||
          Sum() ||
          Product() ||
          RootSum():
        final dst = resolveDst(target, cseReg != null ? expr : null);
        final nodeIdx = nodes.length;
        nodes.add(expr);
        emitInstr(Op.evalNode, dst, nodeIdx, 0);
        return finishComposite(dst);
    }
  };

  final rawResultReg = emit(simplified);
  final constCount = constReal.length;
  final usedCseCount = emittedCse.length;

  int remapReg(int r) {
    if (r < 0) return varCount + (-1 - r);
    if (r < varCount) return r;
    return r + constCount;
  }

  for (var pc = 0; pc < rawCode.length; pc += 4) {
    final op = Op.values[rawCode[pc]];
    switch (op) {
      case Op.jump:
        break;
      case Op.jumpIfFalse:
        rawCode[pc + 2] = remapReg(rawCode[pc + 2]);
      case Op.move ||
          Op.neg ||
          Op.sqrt ||
          Op.sin ||
          Op.cos ||
          Op.tan ||
          Op.exp ||
          Op.ln ||
          Op.abs ||
          Op.powInt ||
          Op.call1 ||
          Op.evalNode:
        rawCode[pc + 1] = remapReg(rawCode[pc + 1]);
        if (op != Op.evalNode) {
          rawCode[pc + 2] = remapReg(rawCode[pc + 2]);
        }
      case Op.call2 || Op.callN || Op.hypergeometric:
        rawCode[pc + 1] = remapReg(rawCode[pc + 1]);
      case Op.add ||
          Op.sub ||
          Op.mul ||
          Op.div ||
          Op.pow ||
          Op.powOddRootOdd ||
          Op.powOddRootEven ||
          Op.relLt ||
          Op.relLe ||
          Op.relGt ||
          Op.relGe ||
          Op.relEq ||
          Op.relNe:
        rawCode[pc + 1] = remapReg(rawCode[pc + 1]);
        rawCode[pc + 2] = remapReg(rawCode[pc + 2]);
        rawCode[pc + 3] = remapReg(rawCode[pc + 3]);
    }
  }

  for (var i = 0; i < rawCallArgs.length; i++) {
    rawCallArgs[i] = remapReg(rawCallArgs[i]);
  }

  final resultReg = remapReg(rawResultReg);
  final registerCount = maxTempEnd + constCount;

  return BytecodeEvaluator(
    variables: List.unmodifiable(varOrder),
    code: Int32List.fromList(rawCode),
    callArgs: Int32List.fromList(rawCallArgs),
    specs: List.unmodifiable(specs),
    nodes: List.unmodifiable(nodes),
    constReal: Float64List.fromList(constReal),
    constComplex: Float64List.fromList(constComplex),
    registerCount: registerCount < 1 ? 1 : registerCount,
    cseCount: usedCseCount,
    resultReg: resultReg,
    hasComplexLiterals: hasComplexLiterals,
    isRealOutput:
        !hasComplexLiterals ||
        simplified.isReal ||
        simplified == Constant.infinity ||
        simplified == Constant.undefined,
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
    case Pow(:final base, :final exponent):
      visit(base);
      visit(exponent);
    case Call(id: FunctionId.hypergeometric, :final args):
      if (args[0] case Call(id: FunctionId.tuple, args: final uArgs)) {
        for (final u in uArgs) {
          visit(u);
        }
      } else {
        visit(args[0]);
      }
      if (args[1] case Call(id: FunctionId.tuple, args: final lArgs)) {
        for (final l in lArgs) {
          visit(l);
        }
      } else {
        visit(args[1]);
      }
      visit(args[2]);
    case Call(:final args):
      for (final a in args) {
        visit(a);
      }
    case Relational(:final left, :final right):
      visit(left);
      visit(right);
    case Piecewise(:final branches, :final otherwise):
      for (final (:relation, :expr) in branches) {
        visit(relation);
        visit(expr);
      }
      if (otherwise != null) visit(otherwise);
    case Integral() ||
        Derivative() ||
        Limit() ||
        Sum() ||
        Product() ||
        RootSum() ||
        Number() ||
        Constant() ||
        Variable() ||
        OrderTerm():
      break;
  }
}

final class _ConstKey {
  const new(this.real, this.cmpRe, this.cmpIm);

  final double real;
  final double cmpRe;
  final double cmpIm;

  static bool _sameDouble(double a, double b) =>
      (a.isNaN && b.isNaN) || (a == b && a.isNegative == b.isNegative);

  static int _hashDouble(double v) => v.isNaN ? 0x7ff80000 : v.hashCode;

  @override
  bool operator ==(Object other) =>
      other is _ConstKey &&
      _sameDouble(real, other.real) &&
      _sameDouble(cmpRe, other.cmpRe) &&
      _sameDouble(cmpIm, other.cmpIm);

  @override
  int get hashCode =>
      Object.hash(_hashDouble(real), _hashDouble(cmpRe), _hashDouble(cmpIm));
}
