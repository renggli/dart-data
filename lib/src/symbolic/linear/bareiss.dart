import 'dart:math' as math;

import '../../linear/matrix.dart';
import '../../linear/vector.dart';
import '../algebra/expand.dart';
import '../algebra/factor.dart';
import '../algebra/factor/fraction.dart';
import '../algebra/factor/multivariate.dart';
import '../algebra/simplify.dart';
import '../ast.dart';
import '../type/expr_data_type.dart';

/// Computational engine for fraction-free symbolic matrix determinants,
/// reduced row echelon form (RREF), rank, nullspace, and exact linear solves.
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

  /// Reduces [matrix] to Reduced Row Echelon Form (RREF) and returns the
  /// reduced matrix together with the list of 0-based pivot column indices.
  ({Matrix<Expr> rref, List<int> pivotColumns}) rowEchelonWithPivots(
    Matrix<Expr> matrix,
  ) {
    final rowCount = matrix.rowCount;
    final colCount = matrix.colCount;
    final effectiveType = matrix.type is ExprDataType
        ? matrix.type
        : exprDataType;
    final grid = [
      for (var r = 0; r < rowCount; r++)
        [
          for (var c = 0; c < colCount; c++)
            matrix.getUnchecked(r, c).simplify(),
        ],
    ];
    final pivotColumns = <int>[];
    var pivotRow = 0;

    for (var col = 0; col < colCount && pivotRow < rowCount; col++) {
      var bestRow = -1;
      var bestScore = -1;
      for (var r = pivotRow; r < rowCount; r++) {
        final candidate = grid[r][col];
        if (!_isExprZero(candidate)) {
          final score = _pivotPreferenceScore(candidate);
          if (score > bestScore) {
            bestScore = score;
            bestRow = r;
          }
        }
      }
      if (bestRow == -1) continue;

      if (bestRow != pivotRow) {
        final temp = grid[pivotRow];
        grid[pivotRow] = grid[bestRow];
        grid[bestRow] = temp;
      }

      pivotColumns.add(col);
      final pivot = grid[pivotRow][col];
      grid[pivotRow][col] = IntegerNumber.one;
      if (pivot != IntegerNumber.one) {
        for (var c = col + 1; c < colCount; c++) {
          grid[pivotRow][c] = _simplifyRatio(grid[pivotRow][c], pivot);
        }
      }

      for (var r = 0; r < rowCount; r++) {
        if (r == pivotRow) continue;
        final factor = grid[r][col];
        if (_isExprZero(factor)) {
          grid[r][col] = IntegerNumber.zero;
          continue;
        }
        grid[r][col] = IntegerNumber.zero;
        for (var c = col + 1; c < colCount; c++) {
          final pivotEntry = grid[pivotRow][c];
          if (!_isExprZero(pivotEntry)) {
            grid[r][c] = _simplifyDifference(grid[r][c], factor * pivotEntry);
          }
        }
      }

      pivotRow++;
    }

    final rref = Matrix<Expr>.fromRows(grid, type: effectiveType);
    return (rref: rref, pivotColumns: pivotColumns);
  }

  /// Computes the Reduced Row Echelon Form (RREF) of [matrix].
  Matrix<Expr> rowEchelon(Matrix<Expr> matrix) =>
      rowEchelonWithPivots(matrix).rref;

  /// Computes the exact algebraic rank of [matrix].
  int rank(Matrix<Expr> matrix) =>
      rowEchelonWithPivots(matrix).pivotColumns.length;

  /// Computes a basis for the right nullspace (kernel) $\{x \mid A x = 0\}$
  /// of [matrix].
  List<Vector<Expr>> nullSpace(Matrix<Expr> matrix) {
    final (:rref, :pivotColumns) = rowEchelonWithPivots(matrix);
    final colCount = matrix.colCount;
    final effectiveType = matrix.type is ExprDataType
        ? matrix.type
        : exprDataType;
    final pivotSet = pivotColumns.toSet();
    final basis = <Vector<Expr>>[];

    for (var freeCol = 0; freeCol < colCount; freeCol++) {
      if (pivotSet.contains(freeCol)) continue;
      final coords = List<Expr>.filled(colCount, IntegerNumber.zero);
      coords[freeCol] = IntegerNumber.one;
      for (var pIdx = 0; pIdx < pivotColumns.length; pIdx++) {
        final pCol = pivotColumns[pIdx];
        final entry = rref.getUnchecked(pIdx, freeCol);
        if (!_isExprZero(entry)) {
          coords[pCol] = (-entry).simplify();
        }
      }
      basis.add(Vector<Expr>.fromList(coords, type: effectiveType));
    }
    return basis;
  }

  /// Solves the symbolic linear system $A x = b$ for a [Vector] or [Matrix]
  /// right-hand side [b], returning `null` if the system has no unique solution.
  S? solve<S extends Object>(Matrix<Expr> matrix, S b) {
    final m = matrix.rowCount;
    final n = matrix.colCount;
    final effectiveType = matrix.type is ExprDataType
        ? matrix.type
        : exprDataType;

    if (b is Vector<Expr>) {
      if (b.length != m) {
        throw ArgumentError(
          'Dimension mismatch: Matrix $m x $n, Vector ${b.length}',
        );
      }
      final solvedMat = solve<Matrix<Expr>>(matrix, b.toMatrix());
      return solvedMat?.col(0).copy() as S?;
    }

    if (b is Matrix<Expr>) {
      if (b.rowCount != m) {
        throw ArgumentError(
          'Dimension mismatch: Matrix $m x $n, Matrix RHS ${b.rowCount} x ${b.colCount}',
        );
      }
      final k = b.colCount;
      final augmented = Matrix<Expr>.generate(
        m,
        n + k,
        (r, c) => c < n ? matrix.getUnchecked(r, c) : b.getUnchecked(r, c - n),
        type: effectiveType,
      );
      final (:rref, :pivotColumns) = rowEchelonWithPivots(augmented);

      // Inconsistent if any pivot column lies in the RHS columns (>= n),
      // or underdetermined if fewer than n pivots lie in the first n columns.
      if (pivotColumns.any((p) => p >= n) || pivotColumns.length < n) {
        return null;
      }

      return Matrix<Expr>.generate(
        n,
        k,
        (r, c) => rref.getUnchecked(r, n + c),
        type: effectiveType,
      ) as S;
    }

    throw ArgumentError.value(b, 'b', 'Expected Vector<Expr> or Matrix<Expr>');
  }

  static int _pivotPreferenceScore(Expr expr) => switch (expr) {
    IntegerNumber(isOne: true) || IntegerNumber(isNegativeOne: true) => 4,
    IntegerNumber() => 3,
    RationalNumber() => 2,
    _ when expr.freeVariables.isEmpty => 1,
    _ => 0,
  };

  static Expr _simplifyRatio(Expr num, Expr den) {
    final sNum = num.expand().simplify();
    if (_isExprZero(sNum)) return IntegerNumber.zero;
    final sDen = den.expand().simplify();
    if (sDen == IntegerNumber.one) return sNum;
    if (sDen == IntegerNumber.negativeOne) return (-sNum).simplify();
    final direct = (sNum / sDen).simplify();
    if (!_hasDiv(direct)) return direct;
    return cancelFactoredFraction(sNum.factor(), sDen.factor()).simplify();
  }

  static Expr _simplifyDifference(Expr a, Expr b) {
    final diff = (a - b).simplify();
    if (!_hasDiv(diff)) return diff.expand().simplify();
    return diff;
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

    // Polynomial long division path (univariate or multivariate)
    final polyDiv = _polynomialLongDivide(num, den);
    if (polyDiv != null && !_hasDiv(polyDiv)) {
      return polyDiv;
    }

    return direct;
  }

  static Expr? _polynomialLongDivide(Expr num, Expr den) {
    final vars = den.freeVariables.toList();
    if (vars.isEmpty) return null;

    // Rank candidate variables
    final candidates = <({String v, int score, int m, Expr dm})>[];
    for (final v in vars) {
      final dCoeffs = _extractCoefficients(den, v);
      if (dCoeffs.isEmpty) continue;
      final m = dCoeffs.keys.reduce(math.max);
      if (m <= 0) continue;
      final dm = dCoeffs[m]!;
      final score =
          (switch (dm) {
            IntegerNumber(isOne: true) ||
            IntegerNumber(isNegativeOne: true) => 100,
            RationalNumber() => 80,
            Number() || Constant() => 60,
            _ => 40,
          }) -
          m;
      candidates.add((v: v, score: score, m: m, dm: dm));
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));

    for (final (:v, score: _, :m, :dm) in candidates) {
      final res = _divideByVariable(num, den, v, m, dm);
      if (res != null && !_hasDiv(res)) {
        return res;
      }
    }

    return null;
  }

  static Expr? _divideByVariable(Expr num, Expr den, String v, int m, Expr dm) {
    var remainder = num.expand().simplify();
    Expr quotient = IntegerNumber.zero;

    var nCoeffs = _extractCoefficients(remainder, v);

    while (!_isExprZero(remainder)) {
      if (nCoeffs.isEmpty) break;
      final k = nCoeffs.keys.reduce(math.max);
      if (k < m) {
        return null;
      }
      final nk = nCoeffs[k]!;

      final Expr qc;
      switch (dm) {
        case IntegerNumber(isOne: true):
          qc = nk;
        case IntegerNumber(isNegativeOne: true):
          qc = (-nk).expand().simplify();
        case RationalNumber():
          qc = (nk * dm.reciprocal()).expand().simplify();
        case _:
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
    for (final MapEntry(:key, :value) in map.entries) {
      final c = value.expand().simplify();
      if (!_isExprZero(c)) {
        result[key] = c;
      }
    }
    return result;
  }

  static (int, Expr) _termDegreeAndCoeff(Expr term, String v) {
    switch (term) {
      case Variable(:final name) when name == v:
        return (1, IntegerNumber.one);
      case Pow(
            base: Variable(:final name),
            exponent: IntegerNumber(asInt: final int exp),
          )
          when name == v && exp > 0:
        return (exp, IntegerNumber.one);
      case _ when !term.dependsOn(v):
        return (0, term);
      case Mul(:final factors):
        var totalDeg = 0;
        Expr totalCoeff = IntegerNumber.one;
        for (final f in factors) {
          final (d, c) = _termDegreeAndCoeff(f, v);
          totalDeg += d;
          totalCoeff = (totalCoeff * c).simplify();
        }
        return (totalDeg, totalCoeff);
      case _:
        return (0, term);
    }
  }

  static List<Expr> _collectFactors(Expr expr) => switch (expr) {
    Mul(:final factors) => [for (final f in factors) ..._collectFactors(f)],
    Pow(:final base, exponent: IntegerNumber(asInt: final int n)) when n > 0 =>
      List.filled(n, base),
    _ => [expr],
  };

  static bool _hasDiv(Expr e) => e.anyNode(
    (node) => switch (node) {
      Pow(exponent: RealNumeric(isNegative: true)) => true,
      _ => false,
    },
  );

  static bool _isExprZero(Expr expr) {
    if (expr is Number && expr.isZero) return true;
    final s = expr.expand().simplify();
    return s is Number && s.isZero;
  }
}
