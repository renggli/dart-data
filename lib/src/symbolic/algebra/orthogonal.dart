import '../ast.dart';
import 'expand.dart';

/// Constructs the $n$-th Chebyshev polynomial of the first kind $T_n(x)$
/// as a symbolic [Expr].
///
/// Generated via the three-term recurrence relation:
/// $$T_0(x) = 1, \quad T_1(x) = x, \quad T_{k+1}(x) = 2x T_k(x) - T_{k-1}(x)$$
///
/// ```dart
/// final t3 = chebyshevT(3); // 4*x^3 - 3*x
/// ```
Expr chebyshevT(int n, [Expr x = const Variable('x')]) {
  RangeError.checkNotNegative(n, 'n');
  if (n == 0) return IntegerNumber.one;
  if (n == 1) return x;
  var p0 = IntegerNumber.one as Expr;
  var p1 = x;
  for (var k = 1; k < n; k++) {
    final next = (IntegerNumber.two * x * p1 - p0).expand();
    p0 = p1;
    p1 = next;
  }
  return p1;
}

/// Constructs the $n$-th Chebyshev polynomial of the second kind $U_n(x)$
/// as a symbolic [Expr].
///
/// Generated via the three-term recurrence relation:
/// $$U_0(x) = 1, \quad U_1(x) = 2x, \quad U_{k+1}(x) = 2x U_k(x) - U_{k-1}(x)$$
///
/// ```dart
/// final u2 = chebyshevU(2); // 4*x^2 - 1
/// ```
Expr chebyshevU(int n, [Expr x = const Variable('x')]) {
  RangeError.checkNotNegative(n, 'n');
  if (n == 0) return IntegerNumber.one;
  final twoX = (IntegerNumber.two * x).expand();
  if (n == 1) return twoX;
  var p0 = IntegerNumber.one as Expr;
  var p1 = twoX;
  for (var k = 1; k < n; k++) {
    final next = (twoX * p1 - p0).expand();
    p0 = p1;
    p1 = next;
  }
  return p1;
}

/// Constructs the $n$-th Legendre polynomial $P_n(x)$ as a symbolic [Expr].
///
/// Generated via Bonnet's recurrence relation:
/// $$(k+1)P_{k+1}(x) = (2k+1)x P_k(x) - k P_{k-1}(x)$$
///
/// ```dart
/// final p2 = legendreP(2); // (3*x^2 - 1)/2
/// ```
Expr legendreP(int n, [Expr x = const Variable('x')]) {
  RangeError.checkNotNegative(n, 'n');
  if (n == 0) return IntegerNumber.one;
  if (n == 1) return x;
  var p0 = IntegerNumber.one as Expr;
  var p1 = x;
  for (var k = 1; k < n; k++) {
    final next =
        ((IntegerNumber.of(2 * k + 1) * x * p1 - IntegerNumber.of(k) * p0) /
                IntegerNumber.of(k + 1))
            .expand();
    p0 = p1;
    p1 = next;
  }
  return p1;
}

/// Constructs the $n$-th physicists' Hermite polynomial $H_n(x)$ as a symbolic [Expr].
///
/// Generated via the recurrence relation:
/// $$H_0(x) = 1, \quad H_1(x) = 2x, \quad H_{k+1}(x) = 2x H_k(x) - 2k H_{k-1}(x)$$
///
/// ```dart
/// final h3 = hermiteH(3); // 8*x^3 - 12*x
/// ```
Expr hermiteH(int n, [Expr x = const Variable('x')]) {
  RangeError.checkNotNegative(n, 'n');
  if (n == 0) return IntegerNumber.one;
  final twoX = (IntegerNumber.two * x).expand();
  if (n == 1) return twoX;
  var p0 = IntegerNumber.one as Expr;
  var p1 = twoX;
  for (var k = 1; k < n; k++) {
    final next = (twoX * p1 - IntegerNumber.of(2 * k) * p0).expand();
    p0 = p1;
    p1 = next;
  }
  return p1;
}

/// Constructs the $n$-th probabilists' Hermite polynomial $He_n(x)$ as a symbolic [Expr].
///
/// Generated via the recurrence relation:
/// $$He_0(x) = 1, \quad He_1(x) = x, \quad He_{k+1}(x) = x He_k(x) - k He_{k-1}(x)$$
///
/// ```dart
/// final he3 = hermiteHe(3); // x^3 - 3*x
/// ```
Expr hermiteHe(int n, [Expr x = const Variable('x')]) {
  RangeError.checkNotNegative(n, 'n');
  if (n == 0) return IntegerNumber.one;
  if (n == 1) return x;
  var p0 = IntegerNumber.one as Expr;
  var p1 = x;
  for (var k = 1; k < n; k++) {
    final next = (x * p1 - IntegerNumber.of(k) * p0).expand();
    p0 = p1;
    p1 = next;
  }
  return p1;
}

/// Constructs the generalized Laguerre polynomial $L_n^{(\alpha)}(x)$ of degree [n]
/// with parameter [alpha] (defaulting to 0) as a symbolic [Expr].
///
/// Generated via the recurrence relation:
/// $$(k+1)L_{k+1}^{(\alpha)}(x) = (2k + 1 + \alpha - x)L_k^{(\alpha)}(x) - (k + \alpha)L_{k-1}^{(\alpha)}(x)$$
///
/// ```dart
/// final l2 = laguerreL(2); // x^2 / 2 - 2*x + 1
/// ```
Expr laguerreL(
  int n, [
  Expr x = const Variable('x'),
  Expr alpha = IntegerNumber.zero,
]) {
  RangeError.checkNotNegative(n, 'n');
  if (n == 0) return IntegerNumber.one;
  final l1Init = (IntegerNumber.one + alpha - x).expand();
  if (n == 1) return l1Init;
  var p0 = IntegerNumber.one as Expr;
  var p1 = l1Init;
  for (var k = 1; k < n; k++) {
    final kExp = IntegerNumber.of(k);
    final next =
        (((IntegerNumber.of(2 * k + 1) + alpha - x) * p1 -
                    (kExp + alpha) * p0) /
                IntegerNumber.of(k + 1))
            .expand();
    p0 = p1;
    p1 = next;
  }
  return p1;
}
