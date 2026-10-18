import 'package:more/number.dart' show Complex;
import 'package:more/printer.dart' show Printer, StandardPrinter;

import '../../linear/matrix.dart';
import '../../linear/vector.dart';
import '../../type/data_type.dart';
import '../../type/models/equality.dart';
import '../../type/models/field.dart';
import '../algebra/approximate.dart';
import '../algebra/expand.dart';
import '../algebra/factor.dart';
import '../algebra/factor/fraction.dart';
import '../algebra/simplify.dart';
import '../algebra/structural_order.dart';
import '../ast.dart';

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
  Expr cast(dynamic value) => switch (value) {
    final Expr expr => expr,
    final int n when n.isFinite => IntegerNumber.of(n),
    final BigInt b => IntegerNumber(Integer.big(b)),
    Complex(:final a, b: == 0) => cast(a),
    Complex(:final a, :final b) => switch ((cast(a), cast(b))) {
      (final RealNumeric re, final RealNumeric im) => ComplexNumber.of(re, im),
      (final re, final im) => (re + im * ComplexNumber.i).simplify(),
    },
    final num n => RealNumber.fromDouble(n.toDouble()),
    final String s => Expr.tryParse(s) ?? super.cast(s),
    _ => super.cast(value),
  };

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
    } on Object {
      return false;
    }
  }
}

/// Exact algebraic field and extended functions over symbolic expressions.
final class ExprField implements ExtendedField<Expr> {
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
  Expr scale(Expr a, num factor) {
    if (factor is int) {
      return (a * IntegerNumber.of(factor)).simplify();
    }
    final d = factor.toDouble();
    if (d.isFinite &&
        d == d.truncateToDouble() &&
        d.abs() <= Integer.maxSafe.toDouble()) {
      return (a * IntegerNumber.of(d.toInt())).simplify();
    }
    if (RealNumber.fromDouble(d).rationalize(maxDenominator: 64)
        case final RationalNumber rat
        when (rat.toDouble() - d).abs() <= 1e-12) {
      return (a * rat).simplify();
    }
    return (a * RealNumber.fromDouble(d)).simplify();
  }

  @override
  Expr pow(Expr base, Expr exponent) => Pow(base, exponent).simplify();

  @override
  Expr abs(Expr a) => Abs(a).simplify();

  @override
  double norm(Expr a) {
    try {
      return a.evaluate(const {}).abs();
    } on Object {
      try {
        return a.evaluateComplex(const {}).abs();
      } on Object {
        throw UnsupportedError(
          'Cannot compute numeric norm for symbolic expression with unresolved variables: $a',
        );
      }
    }
  }

  @override
  Expr sqrt(Expr a) => Pow(a, FractionNumber.half).simplify();

  @override
  Expr exp(Expr a) => Pow(Constant.e, a).simplify();

  @override
  Expr log(Expr a) => Ln(a).simplify();

  @override
  Expr conjugate(Expr a) => Conjugate(a).simplify();

  @override
  Expr mod(Expr a, Expr b) => unsupportedOperation('mod');

  @override
  Expr division(Expr a, Expr b) => unsupportedOperation('division');

  @override
  Expr remainder(Expr a, Expr b) => unsupportedOperation('remainder');

  @override
  Expr modPow(Expr base, Expr exponent, Expr modulus) =>
      unsupportedOperation('modPow');

  @override
  Expr modInverse(Expr base, Expr modulus) =>
      unsupportedOperation('modInverse');

  @override
  Expr gcd(Expr a, Expr b) => unsupportedOperation('gcd');

  @override
  Expr get infinity => Constant.infinity;

  @override
  Expr get negativeInfinity => Mul(const [
    IntegerNumber.negativeOne,
    Constant.infinity,
  ], isSimplified: true);

  @override
  Expr get nan => Constant.undefined;

  /// Checks whether [a] symbolically simplifies to zero.
  bool isZero(Expr a) =>
      a == IntegerNumber.zero ||
      (a is Number && a.isZero) ||
      a.simplify() == IntegerNumber.zero;
}
