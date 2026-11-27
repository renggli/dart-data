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

/// Returns `true` if [expr] is known to be real-valued under [assumptions].
bool isProvenReal(Expr expr, Assumptions assumptions) => switch (expr) {
  RealNumeric() => true,
  ComplexNumber(:final imaginary) => imaginary.isZero,
  Constant(:final isReal) => isReal,
  Variable(:final name) => assumptions.isReal(name),
  _ => DomainOracle(assumptions).isReal(expr),
};

/// Returns `true` if [expr] is known to be strictly negative under [assumptions].
bool isNegativeExpr(Expr expr, {required Assumptions assumptions}) =>
    switch (expr) {
      RealNumeric(:final isNegative) => isNegative,
      ComplexNumber(:final real, :final imaginary) =>
        imaginary.isZero && real.isNegative,
      Constant(:final isReal, :final value) =>
        isReal && value.b == 0.0 && value.a < 0.0,
      _ => DomainOracle(assumptions).isNegative(expr),
    };

/// Returns `true` if [expr] is known to be strictly positive under [assumptions].
bool isPositiveExpr(Expr expr, {required Assumptions assumptions}) =>
    switch (expr) {
      RealNumeric(:final isNegative, :final isZero) => !isNegative && !isZero,
      ComplexNumber(:final real, :final imaginary) =>
        imaginary.isZero && !real.isNegative && !real.isZero,
      Constant(:final isReal, :final value) =>
        isReal && value.b == 0.0 && value.a > 0.0,
      _ => DomainOracle(assumptions).isPositive(expr),
    };

/// Returns `true` if [expr] is syntactically non-negative under [assumptions].
bool isNonNegativeExpr(Expr expr, {required Assumptions assumptions}) =>
    switch (expr) {
      RealNumeric(:final isNegative) => !isNegative,
      ComplexNumber(:final real, :final imaginary) =>
        imaginary.isZero && !real.isNegative,
      Constant(:final isReal, :final value) =>
        isReal && value.b == 0.0 && value.a >= 0.0,
      _ => DomainOracle(assumptions).isNonNegative(expr),
    };

/// Returns `true` if [expr] is syntactically non-positive under [assumptions].
bool isNonPositiveExpr(Expr expr, {required Assumptions assumptions}) =>
    switch (expr) {
      RealNumeric(:final isNegative, :final isZero) => isNegative || isZero,
      ComplexNumber(:final real, :final imaginary) =>
        imaginary.isZero && (real.isNegative || real.isZero),
      Constant(:final isReal, :final value) =>
        isReal && value.b == 0.0 && value.a <= 0.0,
      _ => DomainOracle(assumptions).isNonPositive(expr),
    };

/// Returns `true` if [expr] is syntactically integer-valued under [assumptions].
bool isIntegerExpr(Expr expr, {required Assumptions assumptions}) =>
    switch (expr) {
      IntegerNumber() => true,
      FractionNumber() ||
      RealNumber() ||
      ComplexNumber() ||
      Constant() => false,
      Variable(:final name) => assumptions.isInteger(name),
      _ => DomainOracle(assumptions).isInteger(expr),
    };

/// Returns `true` if [expr] is an even integer expression under [assumptions].
bool isEvenIntegerExpr(Expr expr, {required Assumptions assumptions}) =>
    switch (expr) {
      IntegerNumber(:final value) => value.isEven,
      FractionNumber() ||
      RealNumber() ||
      ComplexNumber() ||
      Constant() => false,
      Variable(:final name) => assumptions.isEven(name),
      _ => DomainOracle(assumptions).isEvenInteger(expr),
    };
