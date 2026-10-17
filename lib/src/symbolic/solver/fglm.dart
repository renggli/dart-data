import '../ast.dart';
import 'multivariate_polynomial.dart';

/// FGLM algorithm engine for Gröbner basis order conversion from `grevlex` to `lex`.
class FglmEngine {
  /// Converts a reduced Gröbner basis from `grevlex` to `lex` order.
  static List<MultivariatePolynomial> convert(
    List<MultivariatePolynomial> grevlexBasis, {
    MonomialOrder targetOrder = MonomialOrder.lex,
  }) {
    if (grevlexBasis.isEmpty) return const [];
    final variables = grevlexBasis.first.variables;
    final n = variables.length;

    // Check if ideal is trivial {1}
    if (grevlexBasis.any(
      (g) => g.leadingMonomial(MonomialOrder.grevlex).isZero,
    )) {
      return [
        MultivariatePolynomial(variables, {
          Monomial.zero(n): IntegerNumber.one,
        }),
      ];
    }

    // Zero-dimensional precondition check
    for (var i = 0; i < n; i++) {
      var found = false;
      for (final g in grevlexBasis) {
        final lm = g.leadingMonomial(MonomialOrder.grevlex);
        if (lm.isPurePower(i)) {
          found = true;
          break;
        }
      }
      if (!found) {
        throw UnsupportedError(
          'FGLM algorithm requires a zero-dimensional polynomial system.',
        );
      }
    }

    // 1. Compute standard monomials basis B of the quotient ring Q = k[x] / <G>
    final standardMonomials = _computeStandardMonomials(grevlexBasis, n);
    final bSize = standardMonomials.length;

    // 2. FGLM main loop: search for linear relations in lex order
    final lexBasis = <MultivariatePolynomial>[];
    final bLex = <Monomial>[];
    final vLex = <List<RationalNumber>>[]; // Coordinate vectors for bLex
    final candidateQueue = <Monomial>[Monomial.zero(n)];

    while (candidateQueue.isNotEmpty) {
      candidateQueue.sort(targetOrder.compare);
      final m = candidateQueue.removeAt(0);

      // Skip m if it is already divisible by the leading monomial of any lexBasis element
      if (lexBasis.any((g) => g.leadingMonomial(targetOrder).divides(m))) {
        continue;
      }

      // Compute normal form of m with respect to G_grevlex
      final nfPoly = MultivariatePolynomial(variables, {
        m: IntegerNumber.one,
      }).reduce(grevlexBasis, order: MonomialOrder.grevlex);

      // Coordinate vector in standardMonomials basis
      final coord = List<RationalNumber>.generate(
        bSize,
        (idx) => nfPoly.terms[standardMonomials[idx]] ?? IntegerNumber.zero,
      );

      // Test linear dependence of coord against vLex
      final relation = _findLinearRelation(vLex, coord);
      if (relation != null) {
        // Linearly dependent: m - sum(c_k * bLex[k]) = 0
        final terms = <Monomial, RationalNumber>{m: IntegerNumber.one};
        for (var k = 0; k < relation.length; k++) {
          final c = relation[k];
          if (!c.isZero) {
            terms[bLex[k]] = c.neg();
          }
        }
        final newPoly = MultivariatePolynomial(
          variables,
          terms,
        ).monic(targetOrder);
        lexBasis.add(newPoly);
      } else {
        // Linearly independent: add m to bLex
        bLex.add(m);
        vLex.add(coord);
        for (var i = 0; i < n; i++) {
          final exp = List<int>.of(m.exponents);
          exp[i]++;
          final nextM = Monomial(exp);
          if (!candidateQueue.contains(nextM)) {
            candidateQueue.add(nextM);
          }
        }
      }
    }

    lexBasis.sort(
      (a, b) => targetOrder.compare(
        b.leadingMonomial(targetOrder),
        a.leadingMonomial(targetOrder),
      ),
    );
    return lexBasis;
  }

  static List<Monomial> _computeStandardMonomials(
    List<MultivariatePolynomial> grevlexBasis,
    int n,
  ) {
    final leadingMonomials = grevlexBasis
        .map((g) => g.leadingMonomial(MonomialOrder.grevlex))
        .toList();

    final result = <Monomial>[];
    final queue = <Monomial>[Monomial.zero(n)];
    final visited = <Monomial>{Monomial.zero(n)};

    while (queue.isNotEmpty) {
      final m = queue.removeAt(0);
      var isDivisible = false;
      for (final lm in leadingMonomials) {
        if (lm.divides(m)) {
          isDivisible = true;
          break;
        }
      }
      if (!isDivisible) {
        result.add(m);
        for (var i = 0; i < n; i++) {
          final exp = List<int>.of(m.exponents);
          exp[i]++;
          final nextM = Monomial(exp);
          if (visited.add(nextM)) {
            queue.add(nextM);
          }
        }
      }
    }

    return result;
  }

  /// Solves vLex * c = target. Returns c if solvable, null if independent.
  static List<RationalNumber>? _findLinearRelation(
    List<List<RationalNumber>> vLex,
    List<RationalNumber> target,
  ) {
    final k = vLex.length;
    if (k == 0) {
      final isZero = target.every((f) => f.isZero);
      return isZero ? const [] : null;
    }
    final d = target.length;

    // Augmented matrix of size d x (k + 1)
    final matrix = List<List<RationalNumber>>.generate(
      d,
      (r) => List<RationalNumber>.generate(
        k + 1,
        (c) => c < k ? vLex[c][r] : target[r],
      ),
    );

    // Gaussian elimination with partial pivoting
    var lead = 0;
    for (var r = 0; r < d; r++) {
      if (lead >= k + 1) break;
      var i = r;
      while (matrix[i][lead].isZero) {
        i++;
        if (i == d) {
          i = r;
          lead++;
          if (lead == k + 1) break;
        }
      }
      if (lead >= k + 1) break;

      // Swap rows i and r
      final temp = matrix[i];
      matrix[i] = matrix[r];
      matrix[r] = temp;

      final pivot = matrix[r][lead];
      for (var col = 0; col < k + 1; col++) {
        matrix[r][col] = matrix[r][col].divRational(pivot);
      }

      for (var row = 0; row < d; row++) {
        if (row != r) {
          final factor = matrix[row][lead];
          if (!factor.isZero) {
            for (var col = 0; col < k + 1; col++) {
              matrix[row][col] = matrix[row][col].subRational(
                factor.mulRational(matrix[r][col]),
              );
            }
          }
        }
      }
      lead++;
    }

    // Check for inconsistency (row of zeros in coeffs, non-zero in target)
    for (var r = 0; r < d; r++) {
      var allZero = true;
      for (var c = 0; c < k; c++) {
        if (!matrix[r][c].isZero) {
          allZero = false;
          break;
        }
      }
      if (allZero && !matrix[r][k].isZero) {
        return null; // Linearly independent
      }
    }

    // Extract solution c
    final solution = List<RationalNumber>.filled(k, IntegerNumber.zero);
    for (var col = 0; col < k; col++) {
      var pivotRow = -1;
      for (var r = 0; r < d; r++) {
        if (matrix[r][col].isOne) {
          var isLead = true;
          for (var c = 0; c < col; c++) {
            if (!matrix[r][c].isZero) {
              isLead = false;
              break;
            }
          }
          if (isLead) {
            pivotRow = r;
            break;
          }
        }
      }
      if (pivotRow != -1) {
        solution[col] = matrix[pivotRow][k];
      }
    }

    return solution;
  }
}
