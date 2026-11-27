import '../assumptions.dart';
import '../ast.dart';
import 'domain_oracle.dart';

/// Evaluates [expr] to a floating-point real number if it is constant and real,
/// or returns `null`.
double? tryStaticRealValue(Expr expr) =>
    DomainOracle(Assumptions.none).tryStaticRealValue(expr);

/// Infers the qualitative [Sign] of [expr] under [assumptions].
Sign inferSign(Expr expr, {Assumptions assumptions = Assumptions.none}) =>
    DomainOracle(assumptions).signOf(expr);

/// Returns `true` if [expr] is known to be strictly positive under [assumptions].
bool isPositive(Expr expr, {Assumptions assumptions = Assumptions.none}) =>
    DomainOracle(assumptions).isPositive(expr);

/// Returns `true` if [expr] is known to be strictly negative under [assumptions].
bool isNegative(Expr expr, {Assumptions assumptions = Assumptions.none}) =>
    DomainOracle(assumptions).isNegative(expr);

/// Returns `true` if [expr] is known to be non-negative (`>= 0`).
bool isNonNegative(Expr expr, {Assumptions assumptions = Assumptions.none}) =>
    DomainOracle(assumptions).isNonNegative(expr);

/// Returns `true` if [expr] is known to be non-positive (`<= 0`).
bool isNonPositive(Expr expr, {Assumptions assumptions = Assumptions.none}) =>
    DomainOracle(assumptions).isNonPositive(expr);

/// Returns `true` if [expr] is known to be non-zero (`!= 0`).
bool isNonZero(Expr expr, {Assumptions assumptions = Assumptions.none}) =>
    DomainOracle(assumptions).isNonZero(expr);

/// Returns `true` if [expr] is syntactically integer-valued under [assumptions].
bool isIntegerValue(Expr expr, {Assumptions assumptions = Assumptions.none}) =>
    DomainOracle(assumptions).isInteger(expr);

/// Returns `true` if [expr] is provably an even integer under [assumptions].
bool isEvenInteger(Expr expr, {Assumptions assumptions = Assumptions.none}) =>
    DomainOracle(assumptions).isEvenInteger(expr);

/// Returns `true` if [expr] is provably an odd integer under [assumptions].
bool isOddInteger(Expr expr, {Assumptions assumptions = Assumptions.none}) =>
    DomainOracle(assumptions).isOddInteger(expr);

/// Returns `true` if [expr] is known to be real-valued under [assumptions].
bool isRealValue(Expr expr, {Assumptions assumptions = Assumptions.none}) =>
    DomainOracle(assumptions).isReal(expr);
