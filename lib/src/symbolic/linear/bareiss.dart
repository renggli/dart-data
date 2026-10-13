import 'dart:math' as math;

import 'package:more/number.dart' show Fraction;

import '../../linear/matrix.dart';
import '../algebra/expand.dart';
import '../algebra/factor.dart';
import '../algebra/factor/fraction.dart';
import '../algebra/factor/multivariate.dart';
import '../algebra/simplify.dart';
import '../ast.dart';

/// Computational engine for fraction-free symbolic matrix determinants using the
/// Bareiss algorithm.
class BareissEngine {
  /// Const constructor.
  const new();

  /// Computes the exact symbolic determinant of square [matrix].
  ///
  /// Throws [ArgumentError] if [matrix] is not square.
  Expr determinant(Matrix<Expr> matrix) {
    if (!matrix.isSquare) {
      throw ArgumentError(
        'Matrix must be square to compute determinant, got '
        '${matrix.rowCount} x ${matrix.colCount}.',
      );
    }

    final n = matrix.rowCount;
    if (n == 0) return RationalNumber.one;
    if (n == 1) return matrix.getUnchecked(0, 0).simplify();
    if (n == 2) {
      final a = matrix.getUnchecked(0, 0);
      final b = matrix.getUnchecked(0, 1);
      final c = matrix.getUnchecked(1, 0);
      final d = matrix.getUnchecked(1, 1);
      return (a * d - b * c).expand().simplify();
    }

    // Working mutable grid of expressions.
    final m = matrix.toNestedList();
    var sign = 1;
    Expr pPrev = RationalNumber.one;

    for (var k = 0; k < n - 1; k++) {
      // 1. Fraction-free row pivoting if pivot candidate vanishes.
      var pivot = m[k][k];
      if (_isExprZero(pivot)) {
        var swapRow = -1;
        for (var r = k + 1; r < n; r++) {
          if (!_isExprZero(m[r][k])) {
            swapRow = r;
            break;
          }
        }
        if (swapRow == -1) {
          // Column is linearly deficient; determinant is zero.
          return RationalNumber.zero;
        }

        // Swap row k and swapRow.
        final temp = m[k];
        m[k] = m[swapRow];
        m[swapRow] = temp;
        sign = -sign;
        pivot = m[k][k];
      }

      // 2. Sylvester elimination step.
      for (var i = k + 1; i < n; i++) {
        for (var j = k + 1; j < n; j++) {
          final num = (m[k][k] * m[i][j] - m[i][k] * m[k][j])
              .expand()
              .simplify();
          m[i][j] = _exactDivide(num, pPrev);
        }
      }

      // 3. Update previous pivot invariant for next step.
      pPrev = pivot;
    }

    final det = m[n - 1][n - 1];
    return sign == 1 ? det.simplify() : (-det).simplify();
  }

  /// Divides [num] by [den] with guaranteed zero remainder.
  static Expr _exactDivide(Expr num, Expr den) {
    if (den == RationalNumber.one) return num;
    if (den == RationalNumber.negativeOne) return (-num).expand().simplify();
    if (_isExprZero(num)) return RationalNumber.zero;

    // Fast-path: direct simplification
    final direct = (num / den).simplify();
    if (!_hasDiv(direct)) return direct;

    // Factored cancellation path
    final cancelled = cancelFactoredFraction(
      num.factor(),
      den.factor(),
    ).expand().simplify();
    if (!_hasDiv(cancelled)) return cancelled;

    // Sequential factor division: if den factors into multiple factors, divide sequentially
    final denFactors = _collectFactors(den.factor());
    if (denFactors.length > 1) {
      var current = num;
      var allClean = true;
      for (final f in denFactors) {
        current = _exactDivide(current, f);
        if (_hasDiv(current)) {
          allClean = false;
          break;
        }
      }
      if (allClean && !_hasDiv(current)) return current.expand().simplify();
    }

    // Monomial division path: if den is a monomial, divide additive terms
    if (isMonomial(den) || den is Variable || den is Number) {
      final expanded = num.expand();
      final terms = <Expr>[];
      collectAdditiveTerms(expanded, 1, terms);
      if (terms.isNotEmpty) {
        var quotientSum = RationalNumber.zero as Expr;
        var allDivided = true;
        for (final t in terms) {
          try {
            final q = divideMonomial(t, den);
            quotientSum = quotientSum + q;
          } catch (_) {
            allDivided = false;
            break;
          }
        }
        if (allDivided) {
          final res = quotientSum.expand().simplify();
          if (!_hasDiv(res)) return res;
        }
      }
    }

    // Polynomial long division path (univariate or multivariate)
    final polyDiv = _polynomialLongDivide(num, den);
    if (polyDiv != null && !_hasDiv(polyDiv)) {
      return polyDiv;
    }

    return direct;
  }

  static Expr? _polynomialLongDivide(Expr num, Expr den) {
    final vars = den.freeVariables.toList();
    if (vars.isEmpty) {
      final res = (num / den).expand().simplify();
      return _hasDiv(res) ? null : res;
    }

    // Rank candidate variables
    final candidates = <(String, int, int, Expr)>[];
    for (final v in vars) {
      final dCoeffs = _extractCoefficients(den, v);
      if (dCoeffs.isEmpty) continue;
      final m = dCoeffs.keys.reduce(math.max);
      if (m <= 0) continue;
      final dm = dCoeffs[m]!;
      var score = 40;
      if (dm == RationalNumber.one || dm == RationalNumber.negativeOne) {
        score = 100;
      } else if (dm is RationalNumber) {
        score = 80;
      } else if (dm is Number) {
        score = 60;
      }
      score -= m;
      candidates.add((v, score, m, dm));
    }

    candidates.sort((a, b) => b.$2.compareTo(a.$2));

    for (final (v, _, m, dm) in candidates) {
      final res = _divideByVariable(num, den, v, m, dm);
      if (res != null && !_hasDiv(res)) {
        return res;
      }
    }

    return null;
  }

  static Expr? _divideByVariable(Expr num, Expr den, String v, int m, Expr dm) {
    var remainder = num.expand().simplify();
    var quotient = RationalNumber.zero as Expr;

    var nCoeffs = _extractCoefficients(remainder, v);

    while (!_isExprZero(remainder)) {
      if (nCoeffs.isEmpty) break;
      final k = nCoeffs.keys.reduce(math.max);
      if (k < m) {
        return null;
      }
      final nk = nCoeffs[k]!;

      final Expr qc;
      if (dm == RationalNumber.one) {
        qc = nk;
      } else if (dm == RationalNumber.negativeOne) {
        qc = (-nk).expand().simplify();
      } else if (dm is RationalNumber) {
        qc = (nk * RationalNumber.fraction(Fraction.one / dm.toFraction()))
            .expand()
            .simplify();
      } else {
        qc = _exactDivide(nk, dm);
        if (_hasDiv(qc)) return null;
      }

      final p = k - m;
      final qTerm = p == 0
          ? qc
          : (p == 1 ? qc * Variable(v) : qc * Variable(v).pow(p));

      quotient = (quotient + qTerm).expand().simplify();
      remainder = (remainder - (qTerm * den)).expand().simplify();
      nCoeffs = _extractCoefficients(remainder, v);
    }

    if (_isExprZero(remainder)) {
      return quotient.expand().simplify();
    }
    return null;
  }

  static Map<int, Expr> _extractCoefficients(Expr expr, String v) {
    final expanded = expr.expand().simplify();
    if (_isExprZero(expanded)) return const {};
    final terms = <Expr>[];
    collectAdditiveTerms(expanded, 1, terms);
    final map = <int, Expr>{};
    for (final term in terms) {
      final (deg, coeff) = _termDegreeAndCoeff(term, v);
      map[deg] = (map[deg] ?? RationalNumber.zero) + coeff;
    }
    final result = <int, Expr>{};
    for (final entry in map.entries) {
      final c = entry.value.expand().simplify();
      if (!_isExprZero(c)) {
        result[entry.key] = c;
      }
    }
    return result;
  }

  static (int, Expr) _termDegreeAndCoeff(Expr term, String v) {
    if (term is Variable && term.name == v) {
      return (1, RationalNumber.one);
    }
    if (term is Pow &&
        term.exponent is RationalNumber &&
        (term.exponent as RationalNumber).isInteger) {
      final exp = (term.exponent as RationalNumber).numerator;
      if (exp > 0) {
        if (term.base is Variable && (term.base as Variable).name == v) {
          return (exp, RationalNumber.one);
        }
        if (term.base is Mul) {
          final mul = term.base as Mul;
          final partL = exp == 1 ? mul.left : Pow(mul.left, term.exponent);
          final partR = exp == 1 ? mul.right : Pow(mul.right, term.exponent);
          final (degL, coeffL) = _termDegreeAndCoeff(partL, v);
          final (degR, coeffR) = _termDegreeAndCoeff(partR, v);
          return (degL + degR, (coeffL * coeffR).simplify());
        }
      }
    }
    if (!term.dependsOn(v)) {
      return (0, term);
    }
    if (term is Neg) {
      final (deg, coeff) = _termDegreeAndCoeff(term.expr, v);
      return (deg, (-coeff).simplify());
    }
    if (term is Mul) {
      final (degL, coeffL) = _termDegreeAndCoeff(term.left, v);
      final (degR, coeffR) = _termDegreeAndCoeff(term.right, v);
      return (degL + degR, (coeffL * coeffR).simplify());
    }
    return (0, term);
  }

  static List<Expr> _collectFactors(Expr expr) => switch (expr) {
    Mul(:final left, :final right) => [
      ..._collectFactors(left),
      ..._collectFactors(right),
    ],
    Pow(
      :final base,
      exponent: RationalNumber(isInteger: true, :final numerator),
    )
        when numerator > 0 =>
      List.filled(numerator, base),
    _ => [expr],
  };

  static bool _hasDiv(Expr e) => switch (e) {
    Div() => true,
    UnaryExpr(:final expr) => _hasDiv(expr),
    BinaryExpr(:final left, :final right) => _hasDiv(left) || _hasDiv(right),
    _ => false,
  };

  static bool _isExprZero(Expr expr) {
    if (expr == RationalNumber.zero) return true;
    if (expr is Number && expr.isZero) return true;
    final s = expr.expand().simplify();
    return switch (s) {
      RationalNumber(isZero: true) => true,
      RealNumber(value: 0.0) => true,
      ComplexNumber(real: 0.0, imaginary: 0.0) => true,
      _ => false,
    };
  }
}
