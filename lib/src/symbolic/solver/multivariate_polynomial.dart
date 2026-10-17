import 'dart:math' as math;

import '../algebra/expand.dart';
import '../algebra/factor/multivariate.dart';
import '../algebra/simplify.dart';
import '../algebra/term_accumulator.dart';
import '../ast.dart';

/// Represents a monomial exponent vector over an ordered list of variables.
class Monomial {
  new(List<int> exponents)
    : exponents = List.unmodifiable(exponents),
      totalDegree = exponents.fold(0, (sum, e) => sum + e);

  factory zero(int numVariables) => Monomial(List<int>.filled(numVariables, 0));

  final List<int> exponents;
  final int totalDegree;

  int get length => exponents.length;
  int operator [](int index) => exponents[index];

  bool get isZero => totalDegree == 0;

  Monomial operator *(Monomial other) {
    assert(length == other.length, 'Variable counts must match');
    final result = List<int>.generate(
      length,
      (i) => exponents[i] + other.exponents[i],
    );
    return Monomial(result);
  }

  bool divides(Monomial other) {
    assert(length == other.length, 'Variable counts must match');
    for (var i = 0; i < length; i++) {
      if (exponents[i] > other.exponents[i]) return false;
    }
    return true;
  }

  Monomial divide(Monomial other) {
    assert(length == other.length, 'Variable counts must match');
    final result = List<int>.generate(length, (i) {
      final diff = exponents[i] - other.exponents[i];
      if (diff < 0) {
        throw ArgumentError('Monomial division yields negative exponent');
      }
      return diff;
    });
    return Monomial(result);
  }

  Monomial lcm(Monomial other) {
    assert(length == other.length, 'Variable counts must match');
    final result = List<int>.generate(
      length,
      (i) => math.max(exponents[i], other.exponents[i]),
    );
    return Monomial(result);
  }

  Monomial gcd(Monomial other) {
    assert(length == other.length, 'Variable counts must match');
    final result = List<int>.generate(
      length,
      (i) => math.min(exponents[i], other.exponents[i]),
    );
    return Monomial(result);
  }

  bool isCoprime(Monomial other) {
    assert(length == other.length, 'Variable counts must match');
    for (var i = 0; i < length; i++) {
      if (exponents[i] > 0 && other.exponents[i] > 0) return false;
    }
    return true;
  }

  bool isPurePower(int varIndex) {
    if (exponents[varIndex] == 0) return false;
    for (var i = 0; i < length; i++) {
      if (i != varIndex && exponents[i] > 0) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Monomial &&
          totalDegree == other.totalDegree &&
          _listEquals(exponents, other.exponents));

  @override
  int get hashCode => Object.hash(totalDegree, Object.hashAll(exponents));

  @override
  String toString() => 'Monomial$exponents';
}

/// Monomial term ordering strategies.
enum MonomialOrder {
  /// Graded reverse lexicographical order (degree first, then reverse lex on ties).
  grevlex,

  /// Pure lexicographical order.
  lex;

  int compare(Monomial a, Monomial b) {
    assert(a.length == b.length, 'Variable counts must match');
    switch (this) {
      case MonomialOrder.grevlex:
        if (a.totalDegree != b.totalDegree) {
          return a.totalDegree.compareTo(b.totalDegree);
        }
        for (var i = a.length - 1; i >= 0; i--) {
          if (a.exponents[i] != b.exponents[i]) {
            return b.exponents[i].compareTo(a.exponents[i]);
          }
        }
        return 0;
      case MonomialOrder.lex:
        for (var i = 0; i < a.length; i++) {
          if (a.exponents[i] != b.exponents[i]) {
            return a.exponents[i].compareTo(b.exponents[i]);
          }
        }
        return 0;
    }
  }
}

/// Represents a polynomial in multiple variables with exact rational coefficients.
class MultivariatePolynomial {
  new(this.variables, Map<Monomial, RationalNumber> terms, {int? sugar})
    : terms = _cleanTerms(terms),
      sugar = sugar ?? _calcInitialSugar(terms) {
    if (this.terms.isNotEmpty) {
      final varCount = variables.length;
      assert(
        this.terms.keys.every((m) => m.length == varCount),
        'Monomial variable length must match variables count',
      );
    }
  }

  factory zero(List<String> variables) =>
      MultivariatePolynomial(variables, const {});

  final List<String> variables;
  final Map<Monomial, RationalNumber> terms;
  final int sugar;

  bool get isZero => terms.isEmpty;
  int get length => variables.length;

  int get totalDegree => terms.isEmpty
      ? 0
      : terms.keys.fold(0, (max, m) => math.max(max, m.totalDegree));

  Monomial leadingMonomial([MonomialOrder order = MonomialOrder.grevlex]) {
    if (terms.isEmpty) return Monomial.zero(variables.length);
    Monomial? lead;
    for (final m in terms.keys) {
      if (lead == null || order.compare(m, lead) > 0) {
        lead = m;
      }
    }
    return lead!;
  }

  RationalNumber leadingCoefficient([
    MonomialOrder order = MonomialOrder.grevlex,
  ]) {
    if (terms.isEmpty) return IntegerNumber.zero;
    final lm = leadingMonomial(order);
    return terms[lm]!;
  }

  (Monomial, RationalNumber) leadingTerm([
    MonomialOrder order = MonomialOrder.grevlex,
  ]) {
    final lm = leadingMonomial(order);
    return (lm, terms[lm] ?? IntegerNumber.zero);
  }

  static Map<Monomial, RationalNumber> _cleanTerms(
    Map<Monomial, RationalNumber> map,
  ) {
    final res = <Monomial, RationalNumber>{};
    for (final entry in map.entries) {
      if (!entry.value.isZero) {
        res[entry.key] = entry.value;
      }
    }
    return Map.unmodifiable(res);
  }

  static int _calcInitialSugar(Map<Monomial, RationalNumber> terms) {
    var maxDeg = 0;
    for (final m in terms.keys) {
      if (!terms[m]!.isZero && m.totalDegree > maxDeg) {
        maxDeg = m.totalDegree;
      }
    }
    return maxDeg;
  }

  MultivariatePolynomial operator +(MultivariatePolynomial other) {
    assert(_listEquals(variables, other.variables));
    final newTerms = Map<Monomial, RationalNumber>.of(terms);
    for (final entry in other.terms.entries) {
      final cur = newTerms[entry.key] ?? IntegerNumber.zero;
      final sum = cur.addRational(entry.value);
      if (sum.isZero) {
        newTerms.remove(entry.key);
      } else {
        newTerms[entry.key] = sum;
      }
    }
    return MultivariatePolynomial(
      variables,
      newTerms,
      sugar: math.max(sugar, other.sugar),
    );
  }

  MultivariatePolynomial operator -(MultivariatePolynomial other) {
    assert(_listEquals(variables, other.variables));
    final newTerms = Map<Monomial, RationalNumber>.of(terms);
    for (final entry in other.terms.entries) {
      final cur = newTerms[entry.key] ?? IntegerNumber.zero;
      final diff = cur.subRational(entry.value);
      if (diff.isZero) {
        newTerms.remove(entry.key);
      } else {
        newTerms[entry.key] = diff;
      }
    }
    return MultivariatePolynomial(
      variables,
      newTerms,
      sugar: math.max(sugar, other.sugar),
    );
  }

  MultivariatePolynomial scale(RationalNumber scalar, {int? newSugar}) {
    if (scalar.isZero || terms.isEmpty) {
      return MultivariatePolynomial.zero(variables);
    }
    final newTerms = <Monomial, RationalNumber>{};
    for (final entry in terms.entries) {
      newTerms[entry.key] = entry.value.mulRational(scalar);
    }
    return MultivariatePolynomial(
      variables,
      newTerms,
      sugar: newSugar ?? sugar,
    );
  }

  MultivariatePolynomial multiplyMonomial(
    Monomial monomial,
    RationalNumber coeff, {
    int? newSugar,
  }) {
    if (coeff.isZero || terms.isEmpty) {
      return MultivariatePolynomial.zero(variables);
    }
    final newTerms = <Monomial, RationalNumber>{};
    for (final entry in terms.entries) {
      final newM = entry.key * monomial;
      newTerms[newM] = entry.value.mulRational(coeff);
    }
    return MultivariatePolynomial(
      variables,
      newTerms,
      sugar: newSugar ?? (sugar + monomial.totalDegree),
    );
  }

  MultivariatePolynomial operator *(MultivariatePolynomial other) {
    assert(_listEquals(variables, other.variables));
    if (isZero || other.isZero) {
      return MultivariatePolynomial.zero(variables);
    }
    final newTerms = <Monomial, RationalNumber>{};
    for (final e1 in terms.entries) {
      for (final e2 in other.terms.entries) {
        final m = e1.key * e2.key;
        final c = (newTerms[m] ?? IntegerNumber.zero).addRational(
          e1.value.mulRational(e2.value),
        );
        if (c.isZero) {
          newTerms.remove(m);
        } else {
          newTerms[m] = c;
        }
      }
    }
    return MultivariatePolynomial(
      variables,
      newTerms,
      sugar: sugar + other.sugar,
    );
  }

  MultivariatePolynomial monic([MonomialOrder order = MonomialOrder.grevlex]) {
    if (isZero) return this;
    final lc = leadingCoefficient(order);
    if (lc.isOne) return this;
    return scale(lc.reciprocal(), newSugar: sugar);
  }

  /// Reduces this polynomial against a collection of [divisors].
  MultivariatePolynomial reduce(
    List<MultivariatePolynomial> divisors, {
    MonomialOrder order = MonomialOrder.grevlex,
  }) {
    if (isZero) return this;
    final nonZeroDivisors = divisors.where((d) => !d.isZero).toList();
    if (nonZeroDivisors.isEmpty) return this;

    var p = this;
    final remainderTerms = <Monomial, RationalNumber>{};
    var currentSugar = sugar;

    while (!p.isZero) {
      final (lmP, lcP) = p.leadingTerm(order);
      var reduced = false;
      for (final g in nonZeroDivisors) {
        final (lmG, lcG) = g.leadingTerm(order);
        if (lmG.divides(lmP)) {
          final quotM = lmP.divide(lmG);
          final quotC = lcP.divRational(lcG);
          final step = g.multiplyMonomial(quotM, quotC);
          p = p - step;
          currentSugar = math.max(currentSugar, g.sugar + quotM.totalDegree);
          reduced = true;
          break;
        }
      }
      if (!reduced) {
        remainderTerms[lmP] = lcP;
        final remP = Map<Monomial, RationalNumber>.of(p.terms)..remove(lmP);
        p = MultivariatePolynomial(variables, remP, sugar: currentSugar);
      }
    }

    return MultivariatePolynomial(
      variables,
      remainderTerms,
      sugar: currentSugar,
    );
  }

  /// Computes the S-polynomial $S(f, g)$ between two polynomials.
  static MultivariatePolynomial sPolynomial(
    MultivariatePolynomial f,
    MultivariatePolynomial g, {
    MonomialOrder order = MonomialOrder.grevlex,
  }) {
    assert(_listEquals(f.variables, g.variables));
    final (lmF, lcF) = f.leadingTerm(order);
    final (lmG, lcG) = g.leadingTerm(order);
    final m = lmF.lcm(lmG);
    final u = m.divide(lmF);
    final v = m.divide(lmG);

    final termF = f.multiplyMonomial(u, lcF.reciprocal());
    final termG = g.multiplyMonomial(v, lcG.reciprocal());
    final sSugar = math.max(f.sugar + u.totalDegree, g.sugar + v.totalDegree);

    final sPoly = termF - termG;
    return MultivariatePolynomial(f.variables, sPoly.terms, sugar: sSugar);
  }

  /// Parses a symbolic [Expr] into a [MultivariatePolynomial] in [variables].
  static MultivariatePolynomial fromExpr(Expr expr, List<String> variables) {
    final expanded = expr.expand();
    final termsList = <Expr>[];
    collectAdditiveTerms(expanded, 1, termsList);

    final termMap = <Monomial, RationalNumber>{};
    for (final t in termsList) {
      final (coeff, base) = decomposeTerm(t);
      if (coeff is! RationalNumber) {
        throw ArgumentError(
          'Expression "$expr" is not a polynomial with rational coefficients '
          'in $variables (non-rational coefficient: $coeff)',
        );
      }
      final powers = <String, int>{};
      final residuals = <Expr>[];
      collectVariablePowers(base, powers, residuals);
      if (residuals.isNotEmpty) {
        throw ArgumentError(
          'Expression "$expr" is not a polynomial with rational coefficients '
          'in $variables (non-polynomial or non-rational factor: ${residuals.first})',
        );
      }

      final expList = List<int>.filled(variables.length, 0);
      for (final e in powers.entries) {
        final idx = variables.indexOf(e.key);
        if (idx == -1) {
          throw ArgumentError(
            'Unknown variable "${e.key}" in polynomial expression "$expr"',
          );
        }
        expList[idx] = e.value;
      }
      final mon = Monomial(expList);
      final prev = termMap[mon] ?? IntegerNumber.zero;
      termMap[mon] = prev.addRational(coeff);
    }

    return MultivariatePolynomial(variables, termMap);
  }

  /// Converts this multivariate polynomial back into a symbolic [Expr].
  Expr toExpr() {
    if (isZero) return IntegerNumber.zero;
    final sortedMonomials = terms.keys.toList()
      ..sort((a, b) => MonomialOrder.grevlex.compare(a, b));

    final termExprs = <Expr>[];
    for (final m in sortedMonomials) {
      final coeff = terms[m]!;
      final factors = <Expr>[];
      if (!coeff.isOne || m.isZero) {
        factors.add(coeff);
      }
      for (var i = 0; i < variables.length; i++) {
        final power = m.exponents[i];
        if (power > 0) {
          final varExpr = Variable(variables[i]);
          final factor = power == 1
              ? varExpr
              : Pow(varExpr, IntegerNumber.of(power));
          factors.add(factor);
        }
      }
      final termExpr = factors.length == 1
          ? factors.first
          : Mul(factors).simplify();
      termExprs.add(termExpr);
    }
    if (termExprs.isEmpty) return IntegerNumber.zero;
    if (termExprs.length == 1) return termExprs.first;
    return Add(termExprs).simplify();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MultivariatePolynomial &&
          _listEquals(variables, other.variables) &&
          _mapsEqual(terms, other.terms));

  @override
  int get hashCode => Object.hash(
    Object.hashAll(variables),
    Object.hashAllUnordered(
      terms.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  @override
  String toString() => toExpr().toString();
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapsEqual(
  Map<Monomial, RationalNumber> a,
  Map<Monomial, RationalNumber> b,
) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}
