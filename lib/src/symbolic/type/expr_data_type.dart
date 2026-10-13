import 'package:more/number.dart' show Complex, Fraction;
import 'package:more/printer.dart' show Printer, StandardPrinter;

import '../../linear/matrix.dart';
import '../../linear/vector.dart';
import '../../type/data_type.dart';
import '../../type/models/equality.dart';
import '../../type/models/field.dart';
import '../algebra/expand.dart';
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
  Expr get defaultValue => RationalNumber.zero;

  @override
  bool get isNullable => false;

  @override
  Equality<Expr> get equality => const ExprEquality();

  @override
  Field<Expr> get field => ExprField.instance;

  @override
  int comparator(Expr a, Expr b) => compareStructural(a, b);

  @override
  Expr cast(dynamic value) {
    if (value is Expr) {
      return value;
    } else if (value is int) {
      return RationalNumber(value);
    } else if (value is Fraction) {
      return RationalNumber.fraction(value);
    } else if (value is Complex) {
      return value.b == 0 ? cast(value.a) : ComplexNumber.fromComplex(value);
    } else if (value is num) {
      return RealNumber(value.toDouble());
    } else if (value is BigInt) {
      return RationalNumber(value.toInt());
    } else if (value is String) {
      return Expr.tryParse(value) ?? super.cast(value);
    }
    return super.cast(value);
  }

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
    if (diff == RationalNumber.zero) return true;
    if (diff is Number && diff.isReal) {
      return diff.value.abs() <= epsilon;
    }
    return false;
  }

  @override
  int hash(Expr a) => a.hashCode;
}

/// Exact algebraic field and extended functions over symbolic expressions.
final class ExprField implements ExtendedField<Expr> {
  /// Const constructor for [ExprField].
  const new();

  /// Canonical singleton instance.
  static const ExprField instance = ExprField();

  @override
  Expr get additiveIdentity => RationalNumber.zero;

  @override
  Expr get multiplicativeIdentity => RationalNumber.one;

  @override
  Expr add(Expr a, Expr b) => (a + b).simplify();

  @override
  Expr sub(Expr a, Expr b) => (a - b).simplify();

  @override
  Expr mul(Expr a, Expr b) {
    if (a is Variable && b is Variable && a.name.compareTo(b.name) > 0) {
      return (b * a).simplify();
    }
    return (a * b).simplify();
  }

  @override
  Expr div(Expr a, Expr b) => (a / b).simplify();

  @override
  Expr neg(Expr a) => (-a).simplify();

  @override
  Expr inv(Expr a) => (RationalNumber.one / a).simplify();

  @override
  Expr scale(Expr a, num factor) =>
      Mul(a, RationalNumber.fromDouble(factor)).simplify();

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
  Expr sqrt(Expr a) => Pow(a, const RationalNumber(1, 2)).simplify();

  @override
  Expr exp(Expr a) => Exp(a).simplify();

  @override
  Expr log(Expr a) => Ln(a).simplify();

  @override
  Expr conjugate(Expr a) => _conjugate(a).simplify();

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
  Expr get infinity => ConstantNumber.infinity;

  @override
  Expr get negativeInfinity => const Neg(ConstantNumber.infinity);

  @override
  Expr get nan => const RealNumber(double.nan);

  /// Checks whether [a] symbolically simplifies to zero.
  bool isZero(Expr a) =>
      a == RationalNumber.zero ||
      (a is Number && a.isZero) ||
      a.simplify() == RationalNumber.zero;

  static Expr _conjugate(Expr expr) => switch (expr) {
    ComplexNumber(:final real, :final imaginary) => ComplexNumber(
      real,
      -imaginary,
    ),
    ConstantNumber(name: 'i') => const Neg(ComplexNumber.i),
    Number() || Variable() => expr,
    Neg(:final expr) => Neg(_conjugate(expr)),
    Sin(:final expr) => Sin(_conjugate(expr)),
    Cos(:final expr) => Cos(_conjugate(expr)),
    Tan(:final expr) => Tan(_conjugate(expr)),
    Asin(:final expr) => Asin(_conjugate(expr)),
    Acos(:final expr) => Acos(_conjugate(expr)),
    Atan(:final expr) => Atan(_conjugate(expr)),
    Sinh(:final expr) => Sinh(_conjugate(expr)),
    Cosh(:final expr) => Cosh(_conjugate(expr)),
    Tanh(:final expr) => Tanh(_conjugate(expr)),
    Exp(:final expr) => Exp(_conjugate(expr)),
    Ln(:final expr) => Ln(_conjugate(expr)),
    Abs(:final expr) => Abs(_conjugate(expr)),
    Add(:final left, :final right) => Add(_conjugate(left), _conjugate(right)),
    Sub(:final left, :final right) => Sub(_conjugate(left), _conjugate(right)),
    Mul(:final left, :final right) => Mul(_conjugate(left), _conjugate(right)),
    Div(:final left, :final right) => Div(_conjugate(left), _conjugate(right)),
    Pow(:final left, :final right) => Pow(_conjugate(left), _conjugate(right)),
    OrderTerm() => expr,
  };
}
