import '../../linear/matrix.dart';
import '../../linear/vector.dart';
import '../algebra/expand.dart';
import '../algebra/factor.dart';
import '../algebra/factor/fraction.dart';
import '../algebra/helpers.dart';
import '../algebra/rational.dart';
import '../algebra/simplify.dart';
import '../assumptions.dart';
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
  Expr determinant(
    Matrix<Expr> matrix, {
    Assumptions assumptions = Assumptions.none,
  }) {
    if (!matrix.isSquare) {
      throw ArgumentError(
        'Matrix must be square to compute determinant, got '
        '${matrix.rowCount} x ${matrix.colCount}.',
      );
    }

    final n = matrix.rowCount;
    if (n == 0) return IntegerNumber.one;
    if (n == 1) {
      return matrix.getUnchecked(0, 0).simplify(assumptions: assumptions);
    }
    if (n == 2) {
      final a = matrix.getUnchecked(0, 0);
      final b = matrix.getUnchecked(0, 1);
      final c = matrix.getUnchecked(1, 0);
      final d = matrix.getUnchecked(1, 1);
      return (a * d - b * c).expand().simplify(assumptions: assumptions);
    }

    // Working mutable grid of expressions.
    final m = matrix.toNestedList();
    var sign = 1;
    Expr pPrev = IntegerNumber.one;

    for (var k = 0; k < n - 1; k++) {
      // 1. Fraction-free row pivoting if pivot candidate vanishes.
      var pivot = m[k][k];
      if (_isExprZero(pivot, assumptions)) {
        var swapRow = -1;
        for (var r = k + 1; r < n; r++) {
          if (!_isExprZero(m[r][k], assumptions)) {
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
          final num = (m[k][k] * m[i][j] - m[i][k] * m[k][j]).expand().simplify(
            assumptions: assumptions,
          );
          m[i][j] = _exactDivide(num, pPrev, assumptions);
        }
      }

      // 3. Update previous pivot invariant for next step.
      pPrev = pivot;
    }

    final det = m[n - 1][n - 1];
    return sign == 1
        ? det.simplify(assumptions: assumptions)
        : (-det).simplify(assumptions: assumptions);
  }

  /// Reduces [matrix] to Reduced Row Echelon Form (RREF) and returns the
  /// reduced matrix together with the list of 0-based pivot column indices.
  ({Matrix<Expr> rref, List<int> pivotColumns}) rowEchelonWithPivots(
    Matrix<Expr> matrix, {
    Assumptions assumptions = Assumptions.none,
  }) => _rowEchelonWithPivots(matrix, assumptions: assumptions)!;

  /// Solves `A * x = b` like [solve], returning `null` if intermediate
  /// expressions exceed [maxCellNodes] or elimination exceeds [maxElapsedMs].
  Matrix<Expr>? solveBounded(
    Matrix<Expr> matrix,
    Matrix<Expr> b, {
    Assumptions assumptions = Assumptions.none,
    int maxCellNodes = 600,
    int maxElapsedMs = 150,
  }) {
    final m = matrix.rowCount;
    final n = matrix.colCount;
    if (b.rowCount != m) {
      throw ArgumentError(
        'Dimension mismatch: Matrix $m x $n, Matrix RHS ${b.rowCount} x ${b.colCount}',
      );
    }
    final effectiveType = matrix.type is ExprDataType
        ? matrix.type
        : exprDataType;
    final k = b.colCount;
    final augmented = Matrix<Expr>.generate(
      m,
      n + k,
      (r, c) => c < n ? matrix.getUnchecked(r, c) : b.getUnchecked(r, c - n),
      type: effectiveType,
    );
    final res = _rowEchelonWithPivots(
      augmented,
      assumptions: assumptions,
      maxCellNodes: maxCellNodes,
      maxElapsedMs: maxElapsedMs,
    );
    if (res == null) return null;
    final (:rref, :pivotColumns) = res;
    if (pivotColumns.any((p) => p >= n) || pivotColumns.length < n) {
      return null;
    }
    return Matrix<Expr>.generate(
      n,
      k,
      (r, c) => rref.getUnchecked(r, n + c),
      type: effectiveType,
    );
  }

  /// Computes the Reduced Row Echelon Form (RREF) of [matrix].
  Matrix<Expr> rowEchelon(
    Matrix<Expr> matrix, {
    Assumptions assumptions = Assumptions.none,
  }) => rowEchelonWithPivots(matrix, assumptions: assumptions).rref;

  /// Computes the exact algebraic rank of [matrix].
  int rank(Matrix<Expr> matrix, {Assumptions assumptions = Assumptions.none}) =>
      rowEchelonWithPivots(
        matrix,
        assumptions: assumptions,
      ).pivotColumns.length;

  /// Computes a basis for the right nullspace (kernel) `{x | A * x = 0}`
  /// of [matrix].
  List<Vector<Expr>> nullSpace(
    Matrix<Expr> matrix, {
    Assumptions assumptions = Assumptions.none,
  }) {
    final (:rref, :pivotColumns) = rowEchelonWithPivots(
      matrix,
      assumptions: assumptions,
    );
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
        if (!_isExprZero(entry, assumptions)) {
          coords[pCol] = (-entry).simplify(assumptions: assumptions);
        }
      }
      basis.add(Vector<Expr>.fromList(coords, type: effectiveType));
    }
    return basis;
  }

  /// Solves the symbolic linear system `A * x = b` for a [Vector] or [Matrix]
  /// right-hand side [b], returning `null` if the system has no unique solution.
  S? solve<S extends Object>(
    Matrix<Expr> matrix,
    S b, {
    Assumptions assumptions = Assumptions.none,
  }) {
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
      final solvedMat = solve<Matrix<Expr>>(
        matrix,
        b.toMatrix(),
        assumptions: assumptions,
      );
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
      final (:rref, :pivotColumns) = rowEchelonWithPivots(
        augmented,
        assumptions: assumptions,
      );

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

  static ({Matrix<Expr> rref, List<int> pivotColumns})? _rowEchelonWithPivots(
    Matrix<Expr> matrix, {
    required Assumptions assumptions,
    int? maxCellNodes,
    int? maxElapsedMs,
  }) {
    final rowCount = matrix.rowCount;
    final colCount = matrix.colCount;
    final effectiveType = matrix.type is ExprDataType
        ? matrix.type
        : exprDataType;
    if (rowCount == 0 || colCount == 0) {
      return (
        rref: Matrix<Expr>.filled(
          rowCount,
          colCount,
          IntegerNumber.zero,
          type: effectiveType,
        ),
        pivotColumns: const [],
      );
    }
    final stopwatch = maxElapsedMs == null ? null : (Stopwatch()..start());
    final grid = [
      for (var r = 0; r < rowCount; r++)
        [
          for (var c = 0; c < colCount; c++)
            matrix.getUnchecked(r, c).simplify(assumptions: assumptions),
        ],
    ];
    final pivotColumns = <int>[];
    var pivotRow = 0;

    for (var col = 0; col < colCount && pivotRow < rowCount; col++) {
      if (stopwatch != null && stopwatch.elapsedMilliseconds >= maxElapsedMs!) {
        return null;
      }
      var bestRow = -1;
      var bestScore = -1;
      for (var r = pivotRow; r < rowCount; r++) {
        final candidate = grid[r][col];
        if (!_isExprZero(candidate, assumptions)) {
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
      if (maxCellNodes != null && exceedsNodeBudget(pivot, maxCellNodes)) {
        return null;
      }
      grid[pivotRow][col] = IntegerNumber.one;
      if (pivot != IntegerNumber.one) {
        for (var c = col + 1; c < colCount; c++) {
          if (stopwatch != null &&
              stopwatch.elapsedMilliseconds >= maxElapsedMs!) {
            return null;
          }
          final ratio = _simplifyRatio(
            grid[pivotRow][c],
            pivot,
            assumptions,
            maxCellNodes: maxCellNodes,
          );
          if (maxCellNodes != null && exceedsNodeBudget(ratio, maxCellNodes)) {
            return null;
          }
          grid[pivotRow][c] = ratio;
        }
      }

      for (var r = 0; r < rowCount; r++) {
        if (r == pivotRow) continue;
        if (stopwatch != null &&
            stopwatch.elapsedMilliseconds >= maxElapsedMs!) {
          return null;
        }
        final factor = grid[r][col];
        if (_isExprZero(factor, assumptions)) {
          grid[r][col] = IntegerNumber.zero;
          continue;
        }
        grid[r][col] = IntegerNumber.zero;
        for (var c = col + 1; c < colCount; c++) {
          final pivotEntry = grid[pivotRow][c];
          if (!_isExprZero(pivotEntry, assumptions)) {
            final cell = grid[r][c];
            final updated =
                (cell is Number && factor is Number && pivotEntry is Number)
                ? cell.sub(factor.mul(pivotEntry))
                : _simplifyDifference(
                    cell,
                    factor * pivotEntry,
                    assumptions,
                    maxCellNodes: maxCellNodes,
                  );
            if (maxCellNodes != null &&
                exceedsNodeBudget(updated, maxCellNodes)) {
              return null;
            }
            grid[r][c] = updated;
          }
        }
      }

      pivotRow++;
    }

    final rref = Matrix<Expr>.fromRows(grid, type: effectiveType);
    return (rref: rref, pivotColumns: pivotColumns);
  }

  static int _pivotPreferenceScore(Expr expr) => switch (expr) {
    IntegerNumber(isOne: true) || IntegerNumber(isNegativeOne: true) => 4,
    IntegerNumber() => 3,
    RationalNumber() => 2,
    _ when expr.freeVariables.isEmpty => 1,
    _ => 0,
  };

  static Expr _simplifyRatio(
    Expr num,
    Expr den,
    Assumptions assumptions, {
    int? maxCellNodes,
  }) {
    if (num is Number && den is Number && !den.isZero) return num.div(den);
    final sNum = num.expand().simplify(assumptions: assumptions);
    if (_isExprZero(sNum, assumptions)) return IntegerNumber.zero;
    final sDen = den.expand().simplify(assumptions: assumptions);
    if (sDen == IntegerNumber.one) return sNum;
    if (sDen == IntegerNumber.negativeOne) {
      return (-sNum).simplify(assumptions: assumptions);
    }
    final direct = (sNum / sDen).simplify(assumptions: assumptions);
    if (!_hasDiv(direct)) return direct;
    final nodeCap = maxCellNodes ?? 1000;
    if (exceedsNodeBudget(sNum, nodeCap) || exceedsNodeBudget(sDen, nodeCap)) {
      return direct;
    }
    return cancelFactoredFraction(
      sNum.factor(assumptions: assumptions),
      sDen.factor(assumptions: assumptions),
    ).simplify(assumptions: assumptions);
  }

  static Expr _simplifyDifference(
    Expr a,
    Expr b,
    Assumptions assumptions, {
    int? maxCellNodes,
  }) {
    if (a is Number && b is Number) return a.sub(b);
    final diff = (a - b).simplify(assumptions: assumptions);
    if (!_hasDiv(diff)) return diff.expand().simplify(assumptions: assumptions);
    final nodeCap = maxCellNodes ?? 1000;
    if (exceedsNodeBudget(diff, nodeCap)) return diff;
    return diff
        .cancel(assumptions: assumptions)
        .simplify(assumptions: assumptions);
  }

  /// Divides [num] by [den] with guaranteed zero remainder.
  static Expr _exactDivide(Expr num, Expr den, Assumptions assumptions) {
    if (den == IntegerNumber.one) return num;
    if (den == IntegerNumber.negativeOne) {
      return (-num).expand().simplify(assumptions: assumptions);
    }
    if (_isExprZero(num, assumptions)) return IntegerNumber.zero;

    // (a) Numeric divisor: direct division
    if (den is Number) {
      return (num / den).expand().simplify(assumptions: assumptions);
    }

    // (b) Polynomial long division path (univariate or multivariate)
    final polyDiv = _polynomialLongDivide(num, den, assumptions);
    if (polyDiv != null && !_hasDiv(polyDiv)) {
      return polyDiv;
    }

    // (c) Factored cancellation fallback
    final cancelled = cancelFactoredFraction(
      num.factor(assumptions: assumptions),
      den.factor(assumptions: assumptions),
    ).expand().simplify(assumptions: assumptions);
    if (!_hasDiv(cancelled)) return cancelled;

    // Sequential factor division: if den factors into multiple factors, divide sequentially
    final denFactors = <Expr>[];
    collectFactors(den.factor(assumptions: assumptions), denFactors);
    if (denFactors.length > 1) {
      var current = num;
      var allClean = true;
      for (final f in denFactors) {
        current = _exactDivide(current, f, assumptions);
        if (_hasDiv(current)) {
          allClean = false;
          break;
        }
      }
      if (allClean && !_hasDiv(current)) {
        return current.expand().simplify(assumptions: assumptions);
      }
    }

    return (num / den).simplify(assumptions: assumptions);
  }

  static Expr? _polynomialLongDivide(
    Expr num,
    Expr den,
    Assumptions assumptions,
  ) {
    final vars = den.freeVariables.toList();
    if (vars.isEmpty) return null;

    // Rank candidate variables
    final candidates = <({String v, int score, int m, Expr dm})>[];
    for (final v in vars) {
      final dCoeffs = extractPolynomialCoefficients(den, v);
      if (dCoeffs == null) continue;
      final m = maxPolynomialDegree(dCoeffs);
      if (m <= 0) continue;
      final dm = dCoeffs[m];
      if (dm == null) continue;
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
      final res = _divideByVariable(num, den, v, m, dm, assumptions);
      if (res != null && !_hasDiv(res)) {
        return res;
      }
    }

    return null;
  }

  static Expr? _divideByVariable(
    Expr num,
    Expr den,
    String v,
    int m,
    Expr dm,
    Assumptions assumptions,
  ) {
    var remainder = num.expand().simplify(assumptions: assumptions);
    Expr quotient = IntegerNumber.zero;

    var nCoeffs = extractPolynomialCoefficients(remainder, v);

    while (!_isExprZero(remainder, assumptions)) {
      if (nCoeffs == null) break;
      final k = maxPolynomialDegree(nCoeffs);
      if (k < m) {
        return null;
      }
      final nk = nCoeffs[k];
      if (nk == null) return null;

      final Expr qc;
      switch (dm) {
        case IntegerNumber(isOne: true):
          qc = nk;
        case IntegerNumber(isNegativeOne: true):
          qc = (-nk).expand().simplify(assumptions: assumptions);
        case RationalNumber():
          qc = (nk * dm.reciprocal()).expand().simplify(
            assumptions: assumptions,
          );
        case _:
          qc = _exactDivide(nk, dm, assumptions);
          if (_hasDiv(qc)) return null;
      }

      final p = k - m;
      final qTerm = p == 0
          ? qc
          : (p == 1 ? qc * Variable(v) : qc * Variable(v).pow(p));

      quotient = (quotient + qTerm).expand().simplify(assumptions: assumptions);
      final nextRemainder = (remainder - (qTerm * den)).expand().simplify(
        assumptions: assumptions,
      );
      final nextCoeffs = extractPolynomialCoefficients(nextRemainder, v);
      if (!_isExprZero(nextRemainder, assumptions) &&
          nextCoeffs != null &&
          maxPolynomialDegree(nextCoeffs) >= k) {
        return null;
      }
      remainder = nextRemainder;
      nCoeffs = nextCoeffs;
    }

    if (_isExprZero(remainder, assumptions)) {
      return quotient.expand().simplify(assumptions: assumptions);
    }
    return null;
  }

  static bool _hasDiv(Expr e) => e.anyNode(
    (node) => switch (node) {
      Pow(exponent: RealNumeric(isNegative: true)) => true,
      _ => false,
    },
  );

  static bool _isExprZero(
    Expr expr, [
    Assumptions assumptions = Assumptions.none,
  ]) {
    if (isZeroExpr(expr)) return true;
    final simp = expr.simplify(assumptions: assumptions);
    if (isZeroExpr(simp)) return true;
    if (_hasDiv(simp)) {
      final combined = simp
          .together(assumptions: assumptions)
          .simplify(assumptions: assumptions);
      return isZeroExpr(combined);
    }
    return false;
  }
}
