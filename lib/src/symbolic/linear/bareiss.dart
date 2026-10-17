import 'dart:math' as math;

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
    if (n == 0) return IntegerNumber.one;
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
    Expr pPrev = IntegerNumber.one;

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
          return IntegerNumber.zero;
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
    if (den == IntegerNumber.one) return num;
    if (den == IntegerNumber.negativeOne) return (-num).expand().simplify();
    if (_isExprZero(num)) return IntegerNumber.zero;

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
    if (isMonomial(den) ||
        den is Variable ||
        den is Number ||
        den is Constant) {
      final expanded = num.expand();
      final terms = <Expr>[];
      collectAdditiveTerms(expanded, 1, terms);
      if (terms.isNotEmpty) {
        var quotientSum = IntegerNumber.zero as Expr;
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
      if (dm == IntegerNumber.one || dm == IntegerNumber.negativeOne) {
        score = 100;
      } else if (dm is RationalNumber) {
        score = 80;
      } else if (dm is Number || dm is Constant) {
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
    var quotient = IntegerNumber.zero as Expr;

    var nCoeffs = _extractCoefficients(remainder, v);

    while (!_isExprZero(remainder)) {
      if (nCoeffs.isEmpty) break;
      final k = nCoeffs.keys.reduce(math.max);
      if (k < m) {
        return null;
      }
      final nk = nCoeffs[k]!;

      final Expr qc;
      if (dm == IntegerNumber.one) {
        qc = nk;
      } else if (dm == IntegerNumber.negativeOne) {
        qc = (-nk).expand().simplify();
      } else if (dm is RationalNumber) {
        qc = (nk * dm.reciprocal()).expand().simplify();
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
      map[deg] = (map[deg] ?? IntegerNumber.zero) + coeff;
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
      return (1, IntegerNumber.one);
    }
    if (term is Pow && term.exponent is IntegerNumber) {
      final exp = (term.exponent as IntegerNumber).asInt;
      if (exp != null && exp > 0) {
        if (term.base is Variable && (term.base as Variable).name == v) {
          return (exp, IntegerNumber.one);
        }
        if (term.base is Mul) {
          var totalDeg = 0;
          var totalCoeff = IntegerNumber.one as Expr;
          for (final f in (term.base as Mul).factors) {
            final part = exp == 1 ? f : Pow(f, term.exponent);
            final (d, c) = _termDegreeAndCoeff(part, v);
            totalDeg += d;
            totalCoeff = (totalCoeff * c).simplify();
          }
          return (totalDeg, totalCoeff);
        }
      }
    }
    if (!term.dependsOn(v)) {
      return (0, term);
    }
    if (term is Mul) {
      var totalDeg = 0;
      var totalCoeff = IntegerNumber.one as Expr;
      for (final f in term.factors) {
        final (d, c) = _termDegreeAndCoeff(f, v);
        totalDeg += d;
        totalCoeff = (totalCoeff * c).simplify();
      }
      return (totalDeg, totalCoeff);
    }
    return (0, term);
  }

  static List<Expr> _collectFactors(Expr expr) => switch (expr) {
    Mul(:final factors) => [for (final f in factors) ..._collectFactors(f)],
    Pow(:final base, exponent: final IntegerNumber n) when (n.asInt ?? 0) > 0 =>
      List.filled(n.asInt!, base),
    _ => [expr],
  };

  static bool _hasDiv(Expr e) => e.anyNode(
    (node) =>
        node is Pow &&
        node.exponent is RealNumeric &&
        (node.exponent as RealNumeric).isNegative,
  );

  static bool _isExprZero(Expr expr) {
    if (expr == IntegerNumber.zero) return true;
    if (expr is Number && expr.isZero) return true;
    final s = expr.expand().simplify();
    return switch (s) {
      RationalNumber(isZero: true) => true,
      RealNumber(value: 0.0) => true,
      _ => false,
    };
  }
}
