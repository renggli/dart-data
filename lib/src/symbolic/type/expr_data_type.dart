import 'package:more/printer.dart' show Printer, StandardPrinter;

import '../../linear/matrix.dart';
import '../../linear/vector.dart';
import '../../type/data_type.dart';
import '../../type/models/equality.dart';
import '../../type/models/field.dart';
import '../algebra/expand.dart';
import '../algebra/factor.dart';
import '../algebra/factor/fraction.dart';
import '../algebra/simplify.dart';
import '../ast.dart';
import '../compiler.dart';
import '../functions/fn.dart';
import '../oracle/zero_equivalence.dart' as oracle;

/// Canonical singleton instance of [ExprDataType].
const ExprDataType exprDataType = ExprDataType();

/// Data type descriptor for symbolic mathematical expressions ([Expr]).
///
/// Underpins symbolic vectors ([Vector]) and matrices ([Matrix]) with exact
/// algebraic field axioms ([ExprField]), total structural ordering
/// ([compareStructural]), and automatic algebraic simplification.
final class ExprDataType extends DataType<Expr> {
  /// Const constructor for [ExprDataType].
  const new();

  /// Canonical singleton instance.
  static const ExprDataType instance = exprDataType;

  @override
  String get name => 'expr';

  @override
  Expr get defaultValue => IntegerNumber.zero;

  @override
  bool get isNullable => false;

  @override
  Equality<Expr> get equality => const ExprEquality();

  @override
  Field<Expr> get field => ExprField.instance;

  @override
  int comparator(Expr a, Expr b) => compareStructural(a, b);

  @override
  Expr cast(Object? value) => Expr.tryWrap(value) ?? super.cast(value);

  @override
  Printer<Expr> get printer => const StandardPrinter<Expr>();

  @override
  String toString() => 'DataType.$name';
}

/// Structural and algebraic equality relation for [Expr].
final class ExprEquality extends NaturalEquality<Expr> {
  /// Const constructor for [ExprEquality].
  const new();

  @override
  bool isEqual(Expr a, Expr b) => a == b;

  @override
  bool isClose(Expr a, Expr b, double epsilon) {
    if (epsilon.isNaN || epsilon < 0) return false;
    if (a == b) return true;
    final diff = (a - b).expand().simplify();
    return switch (diff) {
      IntegerNumber(isZero: true) => true,
      final RealNumeric r => r.toDouble().abs() <= epsilon,
      final ComplexNumber c => c.toComplex().abs() <= epsilon,
      _ when diff.freeVariables.isEmpty => _evalClose(diff, epsilon),
      _ => false,
    };
  }

  @override
  int hash(Expr a) => a.hashCode;

  static bool _evalClose(Expr diff, double epsilon) {
    try {
      return diff.evaluateComplex(const {}).abs() <= epsilon;
    } on ArgumentError {
      return false;
    } on UnsupportedError {
      return false;
    } on StateError {
      return false;
    }
  }
}

/// Exact algebraic field and extended functions over symbolic expressions.
final class ExprField extends ExtendedField<Expr> {
  /// Const constructor for [ExprField].
  const new();

  /// Canonical singleton instance.
  static const ExprField instance = ExprField();

  @override
  Expr get additiveIdentity => IntegerNumber.zero;

  @override
  Expr get multiplicativeIdentity => IntegerNumber.one;

  @override
  Expr add(Expr a, Expr b) {
    final res = (a + b).simplify();
    return res is Add ? res.expand().simplify() : res;
  }

  @override
  Expr sub(Expr a, Expr b) {
    final res = (a - b).simplify();
    return res is Add ? res.expand().simplify() : res;
  }

  @override
  Expr mul(Expr a, Expr b) => (a * b).simplify();

  @override
  Expr div(Expr a, Expr b) {
    final direct = (a / b).simplify();
    final hasNegPow = direct.anyNode(
      (node) => switch (node) {
        Pow(exponent: RealNumeric(isNegative: true)) => true,
        _ => false,
      },
    );
    if (!hasNegPow) return direct;
    final expandedA = a.expand().simplify();
    final expandedB = b.expand().simplify();
    return cancelFactoredFraction(
      expandedA.factor(),
      expandedB.factor(),
    ).simplify();
  }

  @override
  Expr neg(Expr a) => (-a).simplify();

  @override
  Expr inv(Expr a) => (IntegerNumber.one / a).simplify();

  @override
  Expr scale(Expr a, num factor) => factor is int
      ? (a * IntegerNumber.of(factor)).simplify()
      : (a * RealNumber.fromDouble(factor.toDouble())).simplify();

  @override
  Expr pow(Expr base, Expr exponent) => Pow.of(base, exponent).simplify();

  @override
  Expr abs(Expr a) => Fn.abs(a).simplify();

  @override
  double norm(Expr a) {
    try {
      return a.evaluate(const {}).abs();
    } on ArgumentError {
      return _complexNorm(a);
    } on UnsupportedError {
      return _complexNorm(a);
    } on StateError {
      return _complexNorm(a);
    }
  }

  static double _complexNorm(Expr a) {
    try {
      return a.evaluateComplex(const {}).abs();
    } on ArgumentError {
      // Rethrow as UnsupportedError below.
    } on UnsupportedError {
      // Rethrow as UnsupportedError below.
    } on StateError {
      // Rethrow as UnsupportedError below.
    }
    throw UnsupportedError(
      'Cannot compute numeric norm for symbolic expression with unresolved variables: $a',
    );
  }

  @override
  Expr sqrt(Expr a) => Pow.of(a, FractionNumber.half).simplify();

  @override
  Expr exp(Expr a) => Pow.of(Constant.e, a).simplify();

  @override
  Expr log(Expr a) => Fn.ln(a).simplify();

  @override
  Expr conjugate(Expr a) => Fn.conj(a).simplify();

  @override
  Expr get infinity => Constant.infinity;

  @override
  Expr get negativeInfinity => _negativeInfinity;

  static final _negativeInfinity = -Constant.infinity;

  @override
  Expr get nan => Constant.undefined;

  /// Checks whether [a] symbolically simplifies to zero.
  bool isZero(Expr a) => isZeroExpr(a);
}

/// Checks whether a symbolic expression [expr] simplifies or evaluates to zero.
bool isZeroExpr(Expr expr) => oracle.isZeroExpr(expr);
