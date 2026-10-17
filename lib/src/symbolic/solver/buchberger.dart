import 'dart:math' as math;

import 'multivariate_polynomial.dart';

/// Buchberger algorithm engine with Sugar selection strategy and Gebauer-Möller criteria.
class BuchbergerEngine {
  /// Computes the monic, reduced Gröbner basis for [polynomials] with [order].
  static List<MultivariatePolynomial> compute(
    List<MultivariatePolynomial> polynomials, {
    MonomialOrder order = MonomialOrder.grevlex,
    int maxIterations = 1000,
    int maxDegree = 20,
  }) {
    final nonZero = polynomials
        .where((p) => !p.isZero)
        .map((p) => p.monic(order))
        .toList();
    if (nonZero.isEmpty) return const [];

    final gBasis = <MultivariatePolynomial>[];
    var pairs = <_CriticalPair>[];
    var nextId = 0;

    for (final p in nonZero) {
      if (p.sugar > maxDegree || p.totalDegree > maxDegree) {
        throw StateError('Buchberger degree bound ($maxDegree) exceeded.');
      }
      pairs = _updatePairs(gBasis, p, gBasis.length, pairs, order, nextId);
      gBasis.add(p);
      nextId += gBasis.length;
    }

    var iteration = 0;
    while (pairs.isNotEmpty) {
      iteration++;
      if (iteration > maxIterations) {
        throw StateError(
          'Buchberger iteration limit ($maxIterations) exceeded.',
        );
      }

      final pair = pairs.removeAt(0);
      if (pair.sugar > maxDegree || pair.lcm.totalDegree > maxDegree) {
        throw StateError('Buchberger degree bound ($maxDegree) exceeded.');
      }

      final sPoly = MultivariatePolynomial.sPolynomial(
        pair.f,
        pair.g,
        order: order,
      );

      final remainder = sPoly.reduce(gBasis, order: order);
      if (!remainder.isZero) {
        final monicRemainder = remainder.monic(order);

        // If constant polynomial 1 is derived, basis is {1}
        if (monicRemainder.leadingMonomial(order).isZero) {
          return [monicRemainder];
        }

        pairs = _updatePairs(
          gBasis,
          monicRemainder,
          gBasis.length,
          pairs,
          order,
          nextId,
        );
        gBasis.add(monicRemainder);
        nextId += gBasis.length;
      }
    }

    return autoreduce(gBasis, order: order);
  }

  /// Transforms a Gröbner basis into a monic, minimal reduced Gröbner basis.
  static List<MultivariatePolynomial> autoreduce(
    List<MultivariatePolynomial> gBasis, {
    MonomialOrder order = MonomialOrder.grevlex,
  }) {
    if (gBasis.isEmpty) return const [];

    // Filter non-minimal leading monomials
    final minimal = <MultivariatePolynomial>[];
    for (var i = 0; i < gBasis.length; i++) {
      final lmI = gBasis[i].leadingMonomial(order);
      var isDivisible = false;
      for (var j = 0; j < gBasis.length; j++) {
        if (i == j) continue;
        final lmJ = gBasis[j].leadingMonomial(order);
        if (lmJ.divides(lmI)) {
          if (lmJ == lmI && j > i) continue;
          isDivisible = true;
          break;
        }
      }
      if (!isDivisible) {
        minimal.add(gBasis[i].monic(order));
      }
    }

    // Interreduce: tail reduction against remaining basis elements
    final reduced = <MultivariatePolynomial>[];
    for (var i = 0; i < minimal.length; i++) {
      final others = [
        for (var j = 0; j < minimal.length; j++)
          if (i != j) minimal[j],
      ];
      final rem = minimal[i].reduce(others, order: order).monic(order);
      reduced.add(rem);
    }

    reduced.sort(
      (a, b) =>
          order.compare(a.leadingMonomial(order), b.leadingMonomial(order)),
    );
    return reduced;
  }

  static List<_CriticalPair> _updatePairs(
    List<MultivariatePolynomial> gBasis,
    MultivariatePolynomial h,
    int k,
    List<_CriticalPair> existingPairs,
    MonomialOrder order,
    int nextId,
  ) {
    final lmH = h.leadingMonomial(order);

    // Criterion F: eliminate existing pairs if lm(h) divides pair.lcm
    final retainedExisting = existingPairs.where((pair) {
      if (lmH.divides(pair.lcm)) {
        final lcmIH = gBasis[pair.i].leadingMonomial(order).lcm(lmH);
        final lcmJH = gBasis[pair.j].leadingMonomial(order).lcm(lmH);
        if (lcmIH != pair.lcm && lcmJH != pair.lcm) {
          return false;
        }
      }
      return true;
    }).toList();

    // Candidates with h
    final candidateIndices = <int>[];
    for (var i = 0; i < gBasis.length; i++) {
      final lmG = gBasis[i].leadingMonomial(order);
      // Criterion 1: Coprime leading terms reduce to zero
      if (lmG.isCoprime(lmH)) continue;
      candidateIndices.add(i);
    }

    // Criterion M: Minimal LCMs among candidate pairs with h
    final minimalCandidates = <int>[];
    for (var i = 0; i < candidateIndices.length; i++) {
      final idxI = candidateIndices[i];
      final lcmI = gBasis[idxI].leadingMonomial(order).lcm(lmH);
      var isMinimal = true;
      for (var j = 0; j < candidateIndices.length; j++) {
        if (i == j) continue;
        final idxJ = candidateIndices[j];
        final lcmJ = gBasis[idxJ].leadingMonomial(order).lcm(lmH);
        if (lcmJ != lcmI && lcmJ.divides(lcmI)) {
          isMinimal = false;
          break;
        }
      }
      if (isMinimal) {
        minimalCandidates.add(idxI);
      }
    }

    final newPairs = <_CriticalPair>[];
    for (final idx in minimalCandidates) {
      final g = gBasis[idx];
      final lmG = g.leadingMonomial(order);
      final m = lmG.lcm(lmH);
      final u = m.divide(lmG);
      final v = m.divide(lmH);
      final sSugar = math.max(g.sugar + u.totalDegree, h.sugar + v.totalDegree);
      newPairs.add(
        _CriticalPair(
          i: idx,
          j: k,
          f: g,
          g: h,
          lcm: m,
          sugar: sSugar,
          order: order,
          id: nextId++,
        ),
      );
    }

    return [...retainedExisting, ...newPairs]..sort();
  }
}

class _CriticalPair implements Comparable<_CriticalPair> {
  new({
    required this.i,
    required this.j,
    required this.f,
    required this.g,
    required this.lcm,
    required this.sugar,
    required this.order,
    required this.id,
  });

  final int i;
  final int j;
  final MultivariatePolynomial f;
  final MultivariatePolynomial g;
  final Monomial lcm;
  final int sugar;
  final MonomialOrder order;
  final int id;

  @override
  int compareTo(_CriticalPair other) {
    if (sugar != other.sugar) return sugar.compareTo(other.sugar);
    final monCmp = order.compare(lcm, other.lcm);
    if (monCmp != 0) return monCmp;
    return id.compareTo(other.id);
  }
}
