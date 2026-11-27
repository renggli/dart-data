import '../algebra/expand.dart';
import '../algebra/rational.dart';
import '../algebra/simplify.dart';
import '../assumptions.dart';
import '../ast.dart';
import '../compiler.dart';
import 'sign.dart';

/// Three-valued truth result returned by the symbolic zero-equivalence oracle.
enum Truth {
  /// Provably true (`expr == 0`).
  yes,

  /// Provably false (`expr != 0`).
  no,

  /// Undetermined within bounded algebraic/numeric checks.
  unknown,
}

/// Tests whether [expr] is identically zero under [assumptions].
///
/// Combines O(1) structural/sign checks, canonical simplification, polynomial
/// expansion, rational aggregation (`together`), and optional numeric sampling
/// when [numericDisproof] is enabled.
Truth testZero(
  Expr expr, {
  Assumptions assumptions = Assumptions.none,
  bool numericDisproof = false,
}) {
  if (expr is Number) return expr.isZero ? Truth.yes : Truth.no;
  if (expr == Constant.undefined) return Truth.unknown;
  if (isNonZero(expr, assumptions: assumptions)) return Truth.no;

  final s = expr.simplify(assumptions: assumptions);
  if (s is Number) return s.isZero ? Truth.yes : Truth.no;
  if (isNonZero(s, assumptions: assumptions)) return Truth.no;

  final exp = s
      .expand(assumptions: assumptions)
      .simplify(assumptions: assumptions);
  if (exp is Number) return exp.isZero ? Truth.yes : Truth.no;
  if (isNonZero(exp, assumptions: assumptions)) return Truth.no;

  final comb = s
      .together(assumptions: assumptions)
      .simplify(assumptions: assumptions);
  if (comb is Number) return comb.isZero ? Truth.yes : Truth.no;

  if (!s.hasVariable && s.hasReal) {
    try {
      final c = s.evaluateComplex();
      if (c.a.isFinite && c.b.isFinite) {
        if (c.a.abs() < 1e-10 && c.b.abs() < 1e-10) return Truth.yes;
        if (c.a.abs() > 1e-6 || c.b.abs() > 1e-6) return Truth.no;
      }
    } on ArgumentError {
      // Ignored.
    } on UnsupportedError {
      // Ignored.
    }
  }

  if (numericDisproof && s.hasVariable) {
    final disproved = _disproveNumerically(s);
    if (disproved) return Truth.no;
  }

  return Truth.unknown;
}

/// Returns `true` if [expr] provably simplifies to zero under [assumptions].
bool isZeroExpr(Expr expr, {Assumptions assumptions = Assumptions.none}) =>
    testZero(expr, assumptions: assumptions) == Truth.yes;

/// Returns `true` if [a] and [b] are provably symbolically equal under
/// [assumptions].
bool areEquivalent(
  Expr a,
  Expr b, {
  Assumptions assumptions = Assumptions.none,
}) => isZeroExpr(a - b, assumptions: assumptions);

bool _disproveNumerically(Expr expr) {
  final vars = expr.freeVariables.toList()..sort();
  if (vars.length > 6) return false;
  const baseProbes = [0.37, 1.13, 2.41];
  for (var p = 0; p < baseProbes.length; p++) {
    final env = <String, double>{
      for (var i = 0; i < vars.length; i++) vars[i]: baseProbes[p] + i * 0.19,
    };
    try {
      final val = expr.evaluate(env);
      if (val.isFinite && val.abs() > 1e-6) {
        return true;
      }
    } on ArgumentError {
      // Sample outside domain; ignore.
    } on UnsupportedError {
      // Complex intermediate; ignore.
    }
  }
  return false;
}
