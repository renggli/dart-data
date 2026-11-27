import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:more/number.dart' show Complex;

import '../../linear/vector.dart';
import '../../special/hypergeometric.dart' as special_hyper;
import '../ast.dart';
import 'bytecode.dart';
import 'evaluator_helpers.dart';

/// Unified flat-register bytecode virtual machine evaluator supporting real
/// (`double`), complex ([Complex]), [Vector], and vectorized tensor
/// ([Float64List]) execution over a compact 3-address `Int32List` program.
final class BytecodeEvaluator {
  /// Creates a flat-register bytecode evaluator for a compiled program.
  new({
    required this.variables,
    required this.code,
    Int32List? callArgs,
    this.specs = const [],
    this.nodes = const [],
    Float64List? constReal,
    Float64List? constComplex,
    required this.registerCount,
    this.cseCount = 0,
    required this.resultReg,
    this.hasComplexLiterals = false,
    this.isRealOutput = true,
    this.firstComplexLiteral,
  }) : callArgs = callArgs ?? _emptyInt32,
       _constReal = constReal ?? _emptyFloat64,
       _constComplex = constComplex ?? _emptyFloat64;

  static final _emptyInt32 = Int32List(0);
  static final _emptyFloat64 = Float64List(0);

  /// Ordered variable names bound to registers `0 .. variables.length - 1`.
  final List<String> variables;

  /// Flattened 4-word 3-address instruction stream (`[op, dst, a, b, ...]`).
  final Int32List code;

  /// Side table storing register indices for binary, variadic, and hypergeometric calls.
  final Int32List callArgs;

  /// Deduplicated [FunctionSpec] table indexed by `call1` / `call2` / `callN`.
  final List<FunctionSpec> specs;

  /// Embedded unevaluated AST nodes (e.g., [Integral], [Sum]) indexed by `evalNode`.
  final List<Expr> nodes;

  final Float64List _constReal;
  final Float64List _constComplex;

  /// Total number of virtual registers allocated for variables, constants, CSE,
  /// and temporaries.
  final int registerCount;

  /// Number of shared subtrees hoisted into CSE registers.
  final int cseCount;

  /// Register index holding the final evaluated expression result.
  final int resultReg;

  /// Whether the program contains non-real complex literals.
  final bool hasComplexLiterals;

  /// Whether the overall expression evaluates to a real value when all free
  /// variables are real.
  final bool isRealOutput;

  /// First non-real literal encountered during compilation, if any.
  final Expr? firstComplexLiteral;

  /// Number of 3-address instructions in [code].
  int get instructionCount => code.length >> 2;

  /// Number of scalar constants stored in the preloaded constant pool.
  int get constCount => _constReal.length;

  late final Float64List _realRegs = _allocRealRegs();
  late final Float64List _complexRegs = _allocComplexRegs();
  var _realBusy = false;
  var _complexBusy = false;
  final _innerPrograms = HashMap<Expr, BytecodeEvaluator>();
  var _innerCompileCount = 0;

  /// Number of inner expressions compiled lazily by this evaluator.
  @visibleForTesting
  int get innerCompileCount => _innerCompileCount;

  Float64List _allocRealRegs() {
    final regs = Float64List(registerCount);
    if (_constReal.isNotEmpty) {
      regs.setRange(
        variables.length,
        variables.length + _constReal.length,
        _constReal,
      );
    }
    return regs;
  }

  Float64List _allocComplexRegs() {
    final regs = Float64List(registerCount * 2);
    if (_constComplex.isNotEmpty) {
      regs.setRange(
        variables.length * 2,
        variables.length * 2 + _constComplex.length,
        _constComplex,
      );
    }
    return regs;
  }

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

  /// Formats the compiled register program into human-readable instructions.
  List<String> disassemble() {
    final lines = <String>[];
    String regLabel(int r) =>
        r < variables.length ? 'r$r(${variables[r]})' : 'r$r';

    for (var pc = 0; pc < code.length; pc += 4) {
      final idx = pc >> 2;
      final op = Op.values[code[pc]];
      final dst = code[pc + 1];
      final a = code[pc + 2];
      final b = code[pc + 3];
      final opStr = op.name.padRight(14);
      final body = switch (op) {
        Op.jump => '-> #${dst >> 2}',
        Op.jumpIfFalse => '${regLabel(a)} -> #${dst >> 2}',
        Op.move ||
        Op.neg ||
        Op.sqrt ||
        Op.sin ||
        Op.cos ||
        Op.tan ||
        Op.exp ||
        Op.ln ||
        Op.abs => '${regLabel(dst)}, ${regLabel(a)}',
        Op.powInt => '${regLabel(dst)}, ${regLabel(a)}, $b',
        Op.call1 => '${regLabel(dst)}, ${specs[b].name}(${regLabel(a)})',
        Op.call2 =>
          '${regLabel(dst)}, ${specs[b].name}(${regLabel(callArgs[a])}, ${regLabel(callArgs[a + 1])})',
        Op.callN => () {
          final argc = b >>> 16;
          final spec = specs[b & 0xFFFF];
          final argList = [
            for (var k = 0; k < argc; k++) regLabel(callArgs[a + k]),
          ].join(', ');
          return '${regLabel(dst)}, ${spec.name}($argList)';
        }(),
        Op.hypergeometric => '${regLabel(dst)}, p=${b >> 8}, q=${b & 0xFF}',
        Op.evalNode => '${regLabel(dst)}, ${nodes[a]}',
        _ => '${regLabel(dst)}, ${regLabel(a)}, ${regLabel(b)}',
      };
      lines.add('${idx.toString().padLeft(3)}: $opStr $body');
    }
    return lines;
  }

  /// Evaluates a single-variable real expression at [x].
  double evaluate1D(double x) {
    if (variables.length > 1) {
      throw StateError(
        'evaluate1D requires at most 1 variable, got ${variables.length}',
      );
    }
    final reentrant = _realBusy;
    if (!reentrant) _realBusy = true;
    final regs = reentrant ? _allocRealRegs() : _realRegs;
    try {
      if (variables.isNotEmpty) regs[0] = x;
      return _evalRealRegs(regs);
    } finally {
      if (!reentrant) _realBusy = false;
    }
  }

  /// Evaluates a multivariable real expression at positional [args].
  double evaluateList(List<double> args) {
    final reentrant = _realBusy;
    if (!reentrant) _realBusy = true;
    final regs = reentrant ? _allocRealRegs() : _realRegs;
    try {
      for (var i = 0; i < variables.length; i++) {
        regs[i] = args[i];
      }
      return _evalRealRegs(regs);
    } finally {
      if (!reentrant) _realBusy = false;
    }
  }

  /// Evaluates a multivariable real expression at [vector].
  double evaluateVector(Vector<double> vector) {
    final reentrant = _realBusy;
    if (!reentrant) _realBusy = true;
    final regs = reentrant ? _allocRealRegs() : _realRegs;
    try {
      for (var i = 0; i < variables.length; i++) {
        regs[i] = vector[i];
      }
      return _evalRealRegs(regs);
    } finally {
      if (!reentrant) _realBusy = false;
    }
  }

  /// Evaluates a multivariable real expression using named bindings in [context].
  double evaluateMap(Map<String, double> context) {
    final reentrant = _realBusy;
    if (!reentrant) _realBusy = true;
    final regs = reentrant ? _allocRealRegs() : _realRegs;
    try {
      for (var i = 0; i < variables.length; i++) {
        final name = variables[i];
        final val = context[name];
        if (val == null) {
          throw ArgumentError('Variable "$name" not provided in context');
        }
        regs[i] = val;
      }
      return _evalRealRegs(regs);
    } finally {
      if (!reentrant) _realBusy = false;
    }
  }

  /// Evaluates a single-variable complex expression at [x].
  Complex evaluateComplex1D(Complex x) {
    if (variables.length > 1) {
      throw StateError(
        'evaluateComplex1D requires at most 1 variable, got ${variables.length}',
      );
    }
    final reentrant = _complexBusy;
    if (!reentrant) _complexBusy = true;
    final cregs = reentrant ? _allocComplexRegs() : _complexRegs;
    try {
      if (variables.isNotEmpty) {
        cregs[0] = x.a.toDouble();
        cregs[1] = x.b.toDouble();
      }
      return _execComplex(cregs);
    } finally {
      if (!reentrant) _complexBusy = false;
    }
  }

  /// Evaluates a multivariable complex expression at positional [args].
  Complex evaluateComplexList(List<Complex> args) {
    final reentrant = _complexBusy;
    if (!reentrant) _complexBusy = true;
    final cregs = reentrant ? _allocComplexRegs() : _complexRegs;
    try {
      for (var i = 0; i < variables.length; i++) {
        final z = args[i];
        cregs[i << 1] = z.a.toDouble();
        cregs[(i << 1) + 1] = z.b.toDouble();
      }
      return _execComplex(cregs);
    } finally {
      if (!reentrant) _complexBusy = false;
    }
  }

  /// Evaluates a multivariable complex expression using named bindings in [context].
  Complex evaluateComplexMap(Map<String, Complex> context) {
    final reentrant = _complexBusy;
    if (!reentrant) _complexBusy = true;
    final cregs = reentrant ? _allocComplexRegs() : _complexRegs;
    try {
      for (var i = 0; i < variables.length; i++) {
        final name = variables[i];
        final val = context[name];
        if (val == null) {
          throw ArgumentError('Variable "$name" not provided in context');
        }
        cregs[i << 1] = val.a.toDouble();
        cregs[(i << 1) + 1] = val.b.toDouble();
      }
      return _execComplex(cregs);
    } finally {
      if (!reentrant) _complexBusy = false;
    }
  }

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

    final reentrant = _realBusy;
    if (!reentrant) _realBusy = true;
    final regs = reentrant ? _allocRealRegs() : _realRegs;
    try {
      if (hasComplexLiterals) {
        for (var i = 0; i < len; i++) {
          for (var v = 0; v < expectedInputs; v++) {
            regs[v] = inputs[v][i];
          }
          output[i] = _evalRealRegs(regs);
        }
      } else {
        for (var i = 0; i < len; i++) {
          for (var v = 0; v < expectedInputs; v++) {
            regs[v] = inputs[v][i];
          }
          final res = _execReal(regs);
          output[i] = res.isNaN ? _evalRealRegs(regs) : res;
        }
      }
    } finally {
      if (!reentrant) _realBusy = false;
    }
  }

  double _evalRealRegs(Float64List regs) {
    if (hasComplexLiterals) {
      return _evalComplexFromRealRegs(regs);
    }
    final result = _execReal(regs);
    if (result.isNaN) {
      for (var i = 0; i < variables.length; i++) {
        if (regs[i].isNaN) return result;
      }
      try {
        return _evalComplexFromRealRegs(regs);
      } on UnsupportedError {
        return double.nan;
      }
    }
    return result;
  }

  double _evalComplexFromRealRegs(Float64List regs) {
    final reentrant = _complexBusy;
    if (!reentrant) _complexBusy = true;
    final cregs = reentrant ? _allocComplexRegs() : _complexRegs;
    try {
      for (var i = 0; i < variables.length; i++) {
        cregs[i << 1] = regs[i];
        cregs[(i << 1) + 1] = 0.0;
      }
      final res = _execComplex(cregs);
      if (res.b == 0.0 || res.b.abs() <= 1e-15 * (res.a.abs() + 1.0)) {
        return res.a.toDouble();
      }
      if (res.isNaN) return double.nan;
      throw UnsupportedError(
        'Expression evaluated to complex value $res; use complex evaluation instead.',
      );
    } finally {
      if (!reentrant) _complexBusy = false;
    }
  }

  double _execReal(Float64List regs) {
    final c = code;
    final n = c.length;
    var pc = 0;
    while (pc < n) {
      final op = Op.values[c[pc]];
      final dst = c[pc + 1];
      final a = c[pc + 2];
      final b = c[pc + 3];
      pc += 4;
      switch (op) {
        case Op.move:
          regs[dst] = regs[a];
        case Op.add:
          regs[dst] = regs[a] + regs[b];
        case Op.sub:
          regs[dst] = regs[a] - regs[b];
        case Op.mul:
          regs[dst] = regs[a] * regs[b];
        case Op.div:
          regs[dst] = regs[a] / regs[b];
        case Op.pow:
          regs[dst] = realPow(regs[a], regs[b]);
        case Op.powInt:
          regs[dst] = _realPowInt(regs[a], b);
        case Op.powOddRootOdd:
          regs[dst] = realPow(regs[a], regs[b], 1);
        case Op.powOddRootEven:
          regs[dst] = realPow(regs[a], regs[b], 2);
        case Op.neg:
          regs[dst] = -regs[a];
        case Op.sqrt:
          regs[dst] = math.sqrt(regs[a]);
        case Op.sin:
          regs[dst] = math.sin(regs[a]);
        case Op.cos:
          regs[dst] = math.cos(regs[a]);
        case Op.tan:
          regs[dst] = math.tan(regs[a]);
        case Op.exp:
          regs[dst] = math.exp(regs[a]);
        case Op.ln:
          regs[dst] = math.log(regs[a]);
        case Op.abs:
          regs[dst] = regs[a].abs();
        case Op.relLt:
          final ra = regs[a], rb = regs[b];
          regs[dst] = (ra.isNaN || rb.isNaN)
              ? double.nan
              : (ra < rb ? 1.0 : 0.0);
        case Op.relLe:
          final ra = regs[a], rb = regs[b];
          regs[dst] = (ra.isNaN || rb.isNaN)
              ? double.nan
              : (ra <= rb ? 1.0 : 0.0);
        case Op.relGt:
          final ra = regs[a], rb = regs[b];
          regs[dst] = (ra.isNaN || rb.isNaN)
              ? double.nan
              : (ra > rb ? 1.0 : 0.0);
        case Op.relGe:
          final ra = regs[a], rb = regs[b];
          regs[dst] = (ra.isNaN || rb.isNaN)
              ? double.nan
              : (ra >= rb ? 1.0 : 0.0);
        case Op.relEq:
          regs[dst] = regs[a] == regs[b] ? 1.0 : 0.0;
        case Op.relNe:
          regs[dst] = regs[a] != regs[b] ? 1.0 : 0.0;
        case Op.jump:
          pc = dst;
        case Op.jumpIfFalse:
          final cond = regs[a];
          if (cond == 0.0 || cond.isNaN) pc = dst;
        case Op.call1:
          final spec = specs[b];
          final v = regs[a];
          regs[dst] = switch (spec) {
            UnaryFunctionSpec(:final evalReal) => evalReal(v),
            _ => spec.evaluateReal([v]),
          };
        case Op.call2:
          final spec = specs[b];
          final v0 = regs[callArgs[a]];
          final v1 = regs[callArgs[a + 1]];
          regs[dst] = switch (spec) {
            BinaryFunctionSpec(:final evalReal) => evalReal(v0, v1),
            _ => spec.evaluateReal([v0, v1]),
          };
        case Op.callN:
          final argc = b >>> 16;
          final spec = specs[b & 0xFFFF];
          final buf = [for (var k = 0; k < argc; k++) regs[callArgs[a + k]]];
          regs[dst] = spec.evaluateReal(buf);
        case Op.hypergeometric:
          final p = b >> 8;
          final q = b & 0xFF;
          final upper = [for (var k = 0; k < p; k++) regs[callArgs[a + k]]];
          final lower = [for (var k = 0; k < q; k++) regs[callArgs[a + p + k]]];
          final z = regs[callArgs[a + p + q]];
          regs[dst] = special_hyper.hypergeometricPFQ(upper, lower, z);
        case Op.evalNode:
          final ctx = <String, double>{
            for (var i = 0; i < variables.length; i++) variables[i]: regs[i],
          };
          regs[dst] = evalNodeReal(nodes[a], ctx, _compileInner);
      }
    }
    return regs[resultReg];
  }

  Complex _execComplex(Float64List cregs) {
    final c = code;
    final n = c.length;
    var pc = 0;
    while (pc < n) {
      final op = Op.values[c[pc]];
      final dst = c[pc + 1];
      final a = c[pc + 2];
      final b = c[pc + 3];
      pc += 4;
      final di = dst << 1;
      final ai = a << 1;
      switch (op) {
        case Op.move:
          cregs[di] = cregs[ai];
          cregs[di + 1] = cregs[ai + 1];
        case Op.add:
          final bi = b << 1;
          cregs[di] = cregs[ai] + cregs[bi];
          cregs[di + 1] = cregs[ai + 1] + cregs[bi + 1];
        case Op.sub:
          final bi = b << 1;
          cregs[di] = cregs[ai] - cregs[bi];
          cregs[di + 1] = cregs[ai + 1] - cregs[bi + 1];
        case Op.mul:
          final bi = b << 1;
          final ar = cregs[ai], aim = cregs[ai + 1];
          final br = cregs[bi], bim = cregs[bi + 1];
          cregs[di] = ar * br - aim * bim;
          cregs[di + 1] = ar * bim + aim * br;
        case Op.div:
          final bi = b << 1;
          final ar = cregs[ai], aim = cregs[ai + 1];
          final br = cregs[bi], bim = cregs[bi + 1];
          if (br == 0.0 && bim == 0.0 && aim == 0.0 && ar != 0.0) {
            cregs[di] = _normZero(ar / 0.0);
            cregs[di + 1] = 0.0;
          } else if (aim == 0.0 && bim == 0.0) {
            cregs[di] = _normZero(ar / br);
            cregs[di + 1] = 0.0;
          } else {
            _complexDiv(cregs, di, ar, aim, br, bim);
          }
        case Op.pow || Op.powOddRootOdd || Op.powOddRootEven:
          final bi = b << 1;
          final res = complexPow(
            Complex(cregs[ai], cregs[ai + 1]),
            Complex(cregs[bi], cregs[bi + 1]),
          );
          cregs[di] = res.a.toDouble();
          cregs[di + 1] = res.b.toDouble();
        case Op.powInt:
          _complexPowInt(cregs, di, cregs[ai], cregs[ai + 1], b);
        case Op.neg:
          final ar = cregs[ai], aim = cregs[ai + 1];
          cregs[di] = ar == 0.0 ? 0.0 : -ar;
          cregs[di + 1] = aim == 0.0 ? 0.0 : -aim;
        case Op.sqrt:
          final res = Complex(
            _normZero(cregs[ai]),
            _normZero(cregs[ai + 1]),
          ).sqrt();
          cregs[di] = res.a.toDouble();
          cregs[di + 1] = res.b.toDouble();
        case Op.sin:
          final res = Complex(cregs[ai], cregs[ai + 1]).sin();
          cregs[di] = res.a.toDouble();
          cregs[di + 1] = res.b.toDouble();
        case Op.cos:
          final res = Complex(cregs[ai], cregs[ai + 1]).cos();
          cregs[di] = res.a.toDouble();
          cregs[di + 1] = res.b.toDouble();
        case Op.tan:
          final res = Complex(cregs[ai], cregs[ai + 1]).tan();
          cregs[di] = res.a.toDouble();
          cregs[di + 1] = res.b.toDouble();
        case Op.exp:
          final res = Complex(cregs[ai], cregs[ai + 1]).exp();
          cregs[di] = res.a.toDouble();
          cregs[di + 1] = res.b.toDouble();
        case Op.ln:
          final res = Complex(
            _normZero(cregs[ai]),
            _normZero(cregs[ai + 1]),
          ).log();
          cregs[di] = res.a.toDouble();
          cregs[di + 1] = res.b.toDouble();
        case Op.abs:
          cregs[di] = _complexAbs(cregs[ai], cregs[ai + 1]);
          cregs[di + 1] = 0.0;
        case Op.relLt || Op.relLe || Op.relGt || Op.relGe:
          final bi = b << 1;
          final za = Complex(cregs[ai], cregs[ai + 1]);
          final zb = Complex(cregs[bi], cregs[bi + 1]);
          if (isEffectivelyReal(za) && isEffectivelyReal(zb)) {
            final cond = switch (op) {
              Op.relLt => za.a < zb.a,
              Op.relLe => za.a <= zb.a,
              Op.relGt => za.a > zb.a,
              _ => za.a >= zb.a,
            };
            cregs[di] = cond ? 1.0 : 0.0;
            cregs[di + 1] = 0.0;
          } else {
            cregs[di] = double.nan;
            cregs[di + 1] = double.nan;
          }
        case Op.relEq || Op.relNe:
          final bi = b << 1;
          final eq = cregs[ai] == cregs[bi] && cregs[ai + 1] == cregs[bi + 1];
          cregs[di] = (op == Op.relEq ? eq : !eq) ? 1.0 : 0.0;
          cregs[di + 1] = 0.0;
        case Op.jump:
          pc = dst;
        case Op.jumpIfFalse:
          final condR = cregs[ai];
          if (condR == 0.0 || condR.isNaN) pc = dst;
        case Op.call1:
          final spec = specs[b];
          final z = Complex(cregs[ai], cregs[ai + 1]);
          final res = switch (spec) {
            UnaryFunctionSpec(:final evalComplex) => evalComplex(z),
            _ => spec.evaluateComplex([z]),
          };
          cregs[di] = res.a.toDouble();
          cregs[di + 1] = res.b.toDouble();
        case Op.call2:
          final spec = specs[b];
          final i0 = callArgs[a] << 1;
          final i1 = callArgs[a + 1] << 1;
          final z0 = Complex(cregs[i0], cregs[i0 + 1]);
          final z1 = Complex(cregs[i1], cregs[i1 + 1]);
          final res = switch (spec) {
            BinaryFunctionSpec(:final evalComplex) => evalComplex(z0, z1),
            _ => spec.evaluateComplex([z0, z1]),
          };
          cregs[di] = res.a.toDouble();
          cregs[di + 1] = res.b.toDouble();
        case Op.callN:
          final argc = b >>> 16;
          final spec = specs[b & 0xFFFF];
          final buf = [
            for (var k = 0; k < argc; k++)
              Complex(
                cregs[callArgs[a + k] << 1],
                cregs[(callArgs[a + k] << 1) + 1],
              ),
          ];
          final res = spec.evaluateComplex(buf);
          cregs[di] = res.a.toDouble();
          cregs[di + 1] = res.b.toDouble();
        case Op.hypergeometric:
          final p = b >> 8;
          final q = b & 0xFF;
          final upper = [
            for (var k = 0; k < p; k++)
              Complex(
                cregs[callArgs[a + k] << 1],
                cregs[(callArgs[a + k] << 1) + 1],
              ),
          ];
          final lower = [
            for (var k = 0; k < q; k++)
              Complex(
                cregs[callArgs[a + p + k] << 1],
                cregs[(callArgs[a + p + k] << 1) + 1],
              ),
          ];
          final zi = callArgs[a + p + q] << 1;
          final res = special_hyper.hypergeometricPFQComplex(
            upper,
            lower,
            Complex(cregs[zi], cregs[zi + 1]),
          );
          cregs[di] = res.a.toDouble();
          cregs[di + 1] = res.b.toDouble();
        case Op.evalNode:
          final node = nodes[a];
          if (node case final RootSum rootSum) {
            final complexCtx = <String, Complex>{
              for (var i = 0; i < variables.length; i++)
                variables[i]: Complex(cregs[i << 1], cregs[(i << 1) + 1]),
            };
            final res = evalRootSumComplex(rootSum, complexCtx, _compileInner);
            cregs[di] = res.a.toDouble();
            cregs[di + 1] = res.b.toDouble();
          } else if (node
              case Integral(isDefinite: true) ||
                  Derivative() ||
                  Limit() ||
                  Sum() ||
                  Product()) {
            var allReal = true;
            final realCtx = <String, double>{};
            for (var i = 0; i < variables.length; i++) {
              final bim = cregs[(i << 1) + 1];
              if (bim != 0.0) {
                allReal = false;
                break;
              }
              realCtx[variables[i]] = cregs[i << 1];
            }
            if (allReal) {
              cregs[di] = evalNodeReal(node, realCtx, _compileInner);
              cregs[di + 1] = 0.0;
            } else {
              cregs[di] = double.nan;
              cregs[di + 1] = double.nan;
            }
          } else {
            cregs[di] = double.nan;
            cregs[di + 1] = double.nan;
          }
      }
    }
    final ri = resultReg << 1;
    return Complex(cregs[ri], cregs[ri + 1]);
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

double _normZero(double v) => v == 0.0 ? 0.0 : v;

double _realPowInt(double base, int exp) {
  if (exp == 0) return 1.0;
  var cur = base;
  var m = exp.abs();
  var res = 1.0;
  while (m > 0) {
    if (m.isOdd) res *= cur;
    m >>= 1;
    if (m > 0) cur *= cur;
  }
  return exp < 0 ? 1.0 / res : res;
}

double _complexAbs(double ar, double aim) {
  if (ar.isNaN || aim.isNaN) return double.nan;
  final x = ar.abs();
  final y = aim.abs();
  if (x.isInfinite || y.isInfinite) return double.infinity;
  if (x == 0.0) return y;
  if (y == 0.0) return x;
  if (x >= y) {
    final t = y / x;
    return x * math.sqrt(1.0 + t * t);
  }
  final t = x / y;
  return y * math.sqrt(1.0 + t * t);
}

void _complexDiv(
  Float64List cregs,
  int di,
  double ar,
  double aim,
  double br,
  double bim,
) {
  if (br.abs() >= bim.abs()) {
    final t = bim / br;
    final d = br + t * bim;
    cregs[di] = _normZero((ar + aim * t) / d);
    cregs[di + 1] = _normZero((aim - ar * t) / d);
  } else {
    final t = br / bim;
    final d = bim + t * br;
    cregs[di] = _normZero((ar * t + aim) / d);
    cregs[di + 1] = _normZero((aim * t - ar) / d);
  }
}

void _complexPowInt(Float64List cregs, int di, double br, double bim, int exp) {
  final nb = _normZero(br);
  final ni = _normZero(bim);
  if (exp == 0) {
    cregs[di] = 1.0;
    cregs[di + 1] = 0.0;
    return;
  }
  if (nb == 0.0 && ni == 0.0) {
    if (exp > 0) {
      cregs[di] = 0.0;
      cregs[di + 1] = 0.0;
    } else {
      cregs[di] = double.infinity;
      cregs[di + 1] = 0.0;
    }
    return;
  }
  var curR = nb;
  var curI = ni;
  if (exp < 0) {
    _complexDiv(cregs, di, 1.0, 0.0, nb, ni);
    curR = cregs[di];
    curI = cregs[di + 1];
  }
  var resR = 1.0;
  var resI = 0.0;
  var m = exp.abs();
  while (m > 0) {
    if (m.isOdd) {
      final nr = resR * curR - resI * curI;
      resI = resR * curI + resI * curR;
      resR = nr;
    }
    m >>= 1;
    if (m > 0) {
      final nr = curR * curR - curI * curI;
      curI = 2.0 * curR * curI;
      curR = nr;
    }
  }
  cregs[di] = _normZero(resR);
  cregs[di + 1] = _normZero(resI);
}
