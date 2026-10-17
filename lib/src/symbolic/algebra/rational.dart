import '../../../linear.dart';
import '../ast.dart';
import '../budget.dart';
import '../linear/bareiss.dart';
import '../type/expr_data_type.dart';
import 'expand.dart';
import 'factor.dart';
import 'factor/fraction.dart';
import 'simplify.dart';
import 'structural_order.dart';
import 'term_accumulator.dart';

/// Result of univariate polynomial long division $A(x) = Q(x) B(x) + R(x)$.
typedef PolynomialDivisionResult = ({Expr quotient, Expr remainder});

/// Rational-function and polynomial manipulation operations on [Expr].
extension RationalFunctionExtension on Expr {
  /// Returns the algebraic numerator of this expression after canonical
  /// simplification.
  ///
  /// Extracts the numerator of a [FractionNumber] or the product of all
  /// non-negative-exponent factors in a [Mul] expression.
  ///
  /// ```dart
  /// final e = Expr.parse('(x + 1) / (x - 1)');
  /// print(e.numerator); // 1 + x
  /// ```
  Expr get numerator {
    final (numPart, _) = splitNumeratorDenominator(simplify());
    return numPart;
  }

  /// Returns the algebraic denominator of this expression after canonical
  /// simplification.
  ///
  /// Extracts the denominator of a [FractionNumber] or the product of all
  /// negative-exponent factors (with negated exponents) in a [Mul] or [Pow]
  /// expression. Returns [IntegerNumber.one] when there is no denominator.
  ///
  /// ```dart
  /// final e = Expr.parse('(x + 1) / (x - 1)');
  /// print(e.denominator); // -1 + x
  /// ```
  Expr get denominator {
    final (_, denPart) = splitNumeratorDenominator(simplify());
    return denPart;
  }

  /// Combines rational subexpressions over a least common denominator.
  ///
  /// Recursively traverses the expression bottom-up and rewrites sums of
  /// fractions into a single rational expression $N / D$.
  ///
  /// ```dart
  /// final e = Expr.parse('1 / x + 1 / (x + 1)');
  /// print(e.together()); // (1 + 2 * x) / (x * (1 + x))
  /// ```
  Expr together() => _togetherExpr(simplify());

  /// Cancels common polynomial and numeric factors between the numerator and
  /// denominator of this rational expression.
  ///
  /// First combines any nested rational sums over a common denominator via
  /// [together], expands the numerator and denominator, factors both, and
  /// cancels all common factors.
  ///
  /// ```dart
  /// final e = Expr.parse('(x^2 - 1) / (x^2 + 2*x + 1)');
  /// print(e.cancel()); // (-1 + x) / (1 + x)
  /// ```
  Expr cancel() {
    final combined = together();
    final (numPart, denPart) = splitNumeratorDenominator(combined);
    if (denPart == IntegerNumber.one) {
      return numPart.simplify();
    }
    final expNum = numPart.expand().simplify();
    final expDen = denPart.expand().simplify();
    return cancelFactoredFraction(
      _factorPolynomial(expNum),
      _factorPolynomial(expDen),
    ).simplify();
  }

  /// Expands and collects additive terms by powers of [variable].
  ///
  /// Rewrites a multivariate expression as $\sum_k c_k \, x^k$ where each
  /// coefficient $c_k$ is simplified and independent of [variable]. If this
  /// expression has a non-unit denominator, collects both numerator and
  /// denominator with respect to [variable].
  ///
  /// ```dart
  /// final e = Expr.parse('a * x^2 + b * x^2 + c * x + d * x + 5');
  /// print(e.collect('x')); // 5 + (c + d) * x + (a + b) * x ^ 2
  /// ```
  Expr collect(String variable) {
    final simplified = simplify();
    final (numPart, denPart) = splitNumeratorDenominator(simplified);
    if (denPart != IntegerNumber.one) {
      final colNum = _collectAdditive(numPart, variable);
      final colDen = _collectAdditive(denPart, variable);
      return simplifyDiv(colNum, colDen);
    }
    return _collectAdditive(simplified, variable);
  }

  /// Performs univariate polynomial long division of this expression by
  /// [divisor] with respect to [variable].
  ///
  /// Returns `(quotient: Q, remainder: R)` satisfying
  /// $\text{this} = Q \cdot \text{divisor} + R$ with
  /// $\deg_x(R) < \deg_x(\text{divisor})$ or $R = 0$.
  ///
  /// Throws [ArgumentError] if [divisor] is zero or if either expression is
  /// not a polynomial in [variable].
  ///
  /// ```dart
  /// final p = Expr.parse('x^3 + 2*x^2 - x - 2');
  /// final d = Expr.parse('x - 1');
  /// final res = p.polynomialDivide(d, 'x');
  /// // res.quotient == 2 + 3 * x + x ^ 2, res.remainder == 0
  /// ```
  PolynomialDivisionResult polynomialDivide(Expr divisor, String variable) {
    const field = ExprField.instance;
    final simpDivisor = divisor.expand().simplify();
    if (field.isZero(simpDivisor)) {
      throw ArgumentError.value(
        divisor,
        'divisor',
        'Polynomial division by zero.',
      );
    }

    final numCoeffs = _extractPolynomialCoeffs(this, variable);
    final denCoeffs = _extractPolynomialCoeffs(simpDivisor, variable);
    if (numCoeffs == null) {
      throw ArgumentError(
        'Dividend is not a polynomial in "$variable": $this.',
      );
    }
    if (denCoeffs == null) {
      throw ArgumentError(
        'Divisor is not a polynomial in "$variable": $divisor.',
      );
    }

    final dDen = _maxDegree(denCoeffs, field);
    if (dDen < 0) {
      throw ArgumentError.value(
        divisor,
        'divisor',
        'Polynomial division by zero.',
      );
    }

    var dRem = _maxDegree(numCoeffs, field);
    if (dRem < 0) {
      return (quotient: IntegerNumber.zero, remainder: IntegerNumber.zero);
    }
    if (dDen == 0) {
      final c0 = denCoeffs[0]!;
      final scaledCoeffs = <int, Expr>{
        for (final MapEntry(key: deg, value: coeff) in numCoeffs.entries)
          deg: field.div(coeff, c0),
      };
      return (
        quotient: _buildPolynomial(scaledCoeffs, variable),
        remainder: IntegerNumber.zero,
      );
    }
    if (dRem < dDen) {
      return (
        quotient: IntegerNumber.zero,
        remainder: _buildPolynomial(numCoeffs, variable),
      );
    }

    final rem = Map<int, Expr>.from(numCoeffs);
    final quot = <int, Expr>{};
    final leadDen = denCoeffs[dDen]!;

    while (dRem >= dDen) {
      ComputationBudget.check();
      final shift = dRem - dDen;
      final factor = field.div(rem[dRem]!, leadDen);
      final existingQ = quot[shift];
      quot[shift] = existingQ == null ? factor : field.add(existingQ, factor);

      for (final MapEntry(key: deg, value: coeff) in denCoeffs.entries) {
        final targetDeg = deg + shift;
        final subTerm = field.mul(factor, coeff);
        final cur = rem[targetDeg] ?? IntegerNumber.zero;
        rem[targetDeg] = field.sub(cur, subTerm);
      }
      rem.remove(dRem);
      dRem = _maxDegree(rem, field);
    }

    return (
      quotient: _buildPolynomial(quot, variable),
      remainder: _buildPolynomial(rem, variable),
    );
  }

  /// Computes the partial fraction decomposition of this rational expression
  /// with respect to [variable].
  ///
  /// Decomposes a rational function $P(x) / Q(x)$ into a polynomial quotient
  /// plus proper partial fractions over the irreducible factors of $Q(x)$:
  ///
  /// $$\frac{P(x)}{Q(x)} = Q_0(x) + \sum_{i=1}^m \sum_{k=1}^{e_i} \frac{N_{i,k}(x)}{F_i(x)^k}$$
  ///
  /// where $\deg_x(N_{i,k}) < \deg_x(F_i)$. Uses exact polynomial factorization
  /// and fraction-free linear system solving via the method of undetermined
  /// coefficients.
  ///
  /// ```dart
  /// final e = Expr.parse('1 / (x^2 - 1)');
  /// print(e.apart('x')); // 1/2 / (-1 + x) - 1/2 / (1 + x)
  /// ```
  Expr apart(String variable) {
    final cancelled = cancel();
    final (numExpr, denExpr) = splitNumeratorDenominator(cancelled);
    if (!denExpr.dependsOn(variable)) {
      return (numExpr / denExpr).expand().simplify();
    }

    if (_extractPolynomialCoeffs(numExpr, variable) == null ||
        _extractPolynomialCoeffs(denExpr, variable) == null) {
      return cancelled;
    }

    final (:quotient, :remainder) = numExpr.polynomialDivide(denExpr, variable);
    const field = ExprField.instance;
    if (field.isZero(remainder)) {
      return quotient;
    }

    final factoredDen = _factorPolynomial(denExpr);
    final rawFactors = <Expr, int>{};
    RationalNumber scalar = IntegerNumber.one;
    flattenFactored(factoredDen, rawFactors, (s) {
      scalar = scalar.mulRational(s);
    });

    final constFactors = <Expr>[if (!scalar.isOne) scalar];
    final polyFactors = <({Expr base, int multiplicity, int degree})>[];

    for (final MapEntry(key: factorBase, value: mult) in rawFactors.entries) {
      if (!factorBase.dependsOn(variable)) {
        constFactors.add(
          mult == 1 ? factorBase : Pow(factorBase, IntegerNumber.of(mult)),
        );
      } else {
        final coeffs = _extractPolynomialCoeffs(factorBase, variable);
        if (coeffs == null) return cancelled;
        final deg = _maxDegree(coeffs, field);
        if (deg <= 0) {
          constFactors.add(
            mult == 1 ? factorBase : Pow(factorBase, IntegerNumber.of(mult)),
          );
        } else {
          polyFactors.add((base: factorBase, multiplicity: mult, degree: deg));
        }
      }
    }

    if (polyFactors.isEmpty) {
      return cancelled;
    }

    if (polyFactors.length == 1 && polyFactors.first.multiplicity == 1) {
      final frac = cancelFactoredFraction(
        _factorPolynomial(remainder),
        factoredDen,
      ).simplify();
      return field.isZero(quotient) ? frac : (quotient + frac).simplify();
    }

    final c0 = constFactors.isEmpty
        ? IntegerNumber.one
        : simplifyMul(constFactors);
    final totalDegree = polyFactors.fold<int>(
      0,
      (sum, f) => sum + f.multiplicity * f.degree,
    );

    // Build undetermined coefficients linear system A * u = b of size D x D.
    final aRows = List.generate(
      totalDegree,
      (_) => List<Expr>.filled(totalDegree, IntegerNumber.zero),
    );
    var colIdx = 0;

    for (var i = 0; i < polyFactors.length; i++) {
      final fI = polyFactors[i];
      for (var k = 1; k <= fI.multiplicity; k++) {
        ComputationBudget.check();
        // Cofactor C_{i,k}(x) = prod_{j != i} F_j^{e_j} * F_i^{e_i - k}
        final cofactorParts = <Expr>[];
        for (var j = 0; j < polyFactors.length; j++) {
          final fJ = polyFactors[j];
          final exp = j == i ? fI.multiplicity - k : fJ.multiplicity;
          if (exp == 1) {
            cofactorParts.add(fJ.base);
          } else if (exp > 1) {
            cofactorParts.add(Pow(fJ.base, IntegerNumber.of(exp)));
          }
        }
        final cofactorExpr = cofactorParts.isEmpty
            ? IntegerNumber.one
            : simplifyMul(cofactorParts).expand().simplify();
        final cofactorCoeffs = _extractPolynomialCoeffs(cofactorExpr, variable);
        if (cofactorCoeffs == null) return cancelled;

        for (var m = 0; m < fI.degree; m++) {
          for (final MapEntry(key: deg, value: coeff)
              in cofactorCoeffs.entries) {
            final targetDeg = deg + m;
            if (targetDeg < totalDegree) {
              aRows[targetDeg][colIdx] = coeff;
            }
          }
          colIdx++;
        }
      }
    }

    final scaledRemainder = field.div(remainder, c0);
    final remCoeffs = _extractPolynomialCoeffs(scaledRemainder, variable);
    if (remCoeffs == null) return cancelled;

    final bRows = List.generate(
      totalDegree,
      (deg) => [remCoeffs[deg] ?? IntegerNumber.zero],
    );

    final aMat = Matrix<Expr>.fromRows(aRows, type: exprDataType);
    final bMat = Matrix<Expr>.fromRows(bRows, type: exprDataType);
    final uMat = const BareissEngine().solve(aMat, bMat);
    if (uMat == null) {
      return cancelled;
    }

    final pfTerms = <Expr>[if (!field.isZero(quotient)) quotient];
    final xVar = Variable(variable);
    var uIdx = 0;

    for (var i = 0; i < polyFactors.length; i++) {
      final fI = polyFactors[i];
      for (var k = 1; k <= fI.multiplicity; k++) {
        final numTerms = <Expr>[];
        for (var m = 0; m < fI.degree; m++) {
          final coeff = uMat.getUnchecked(uIdx++, 0).simplify();
          if (!field.isZero(coeff)) {
            final xPow = m == 0
                ? IntegerNumber.one
                : m == 1
                ? xVar
                : Pow(xVar, IntegerNumber.of(m));
            numTerms.add(m == 0 ? coeff : (coeff * xPow).simplify());
          }
        }
        if (numTerms.isNotEmpty) {
          final numPoly = numTerms.length == 1
              ? numTerms.first
              : Add(numTerms).simplify();
          final denPow = k == 1
              ? fI.base
              : Pow(fI.base, IntegerNumber.of(k), isSimplified: true);
          pfTerms.add(
            cancelFactoredFraction(
              _factorPolynomial(numPoly),
              denPow,
            ).simplify(),
          );
        }
      }
    }

    return switch (pfTerms) {
      [] => IntegerNumber.zero,
      [final single] => single,
      _ => Add(pfTerms).simplify(),
    };
  }
}

Expr _factorPolynomial(Expr expr) => expr is Number ? expr : expr.factor();

Expr _togetherExpr(Expr expr) {
  ComputationBudget.check();
  final mapped = expr.mapChildren(_togetherExpr);
  return switch (mapped) {
    Add(:final terms) => _togetherAdd(terms),
    Mul(:final factors) => _togetherMul(factors),
    Pow(:final base, :final exponent) => _togetherPow(base, exponent),
    _ => mapped.simplify(),
  };
}

Expr _togetherMul(List<Expr> factors) {
  final numParts = <Expr>[];
  final denParts = <Expr>[];
  for (final f in factors) {
    final (n, d) = splitNumeratorDenominator(f);
    if (n != IntegerNumber.one) numParts.add(n);
    if (d != IntegerNumber.one) denParts.add(d);
  }
  if (denParts.isEmpty) {
    return simplifyMul(factors);
  }
  final numExpr = numParts.isEmpty ? IntegerNumber.one : simplifyMul(numParts);
  final denExpr = simplifyMul(denParts);
  return cancelFactoredFraction(
    _factorPolynomial(numExpr),
    _factorPolynomial(denExpr),
  ).simplify();
}

Expr _togetherPow(Expr base, Expr exponent) {
  final (n, d) = splitNumeratorDenominator(base);
  if (d == IntegerNumber.one) {
    return simplifyPow(base, exponent);
  }
  if (exponent case IntegerNumber(asInt: final exp?)) {
    if (exp < 0) {
      final posExp = IntegerNumber.of(-exp);
      return simplifyDiv(simplifyPow(d, posExp), simplifyPow(n, posExp));
    }
    if (exp > 0) {
      return simplifyDiv(simplifyPow(n, exponent), simplifyPow(d, exponent));
    }
  }
  return simplifyPow(base, exponent);
}

Expr _togetherAdd(List<Expr> terms) {
  final decomposed = <({Expr num, Integer denScalar, Map<Expr, int> denMap})>[];
  var hasDenominator = false;

  for (final term in terms) {
    final (rawNum, rawDen) = splitNumeratorDenominator(term);
    if (rawDen != IntegerNumber.one) {
      hasDenominator = true;
    }
    final factoredDen = _factorPolynomial(rawDen);
    final denMap = <Expr, int>{};
    RationalNumber scalar = IntegerNumber.one;
    flattenFactored(factoredDen, denMap, (s) {
      scalar = scalar.mulRational(s);
    });

    var adjNum = rawNum;
    if (scalar.isNegative) {
      adjNum = simplifyNeg(adjNum);
      scalar = scalar.neg();
    }
    final q = scalar.denominator;
    if (!q.isOne) {
      adjNum = simplifyMul([IntegerNumber(q), adjNum]);
    }
    final p = scalar.numerator;
    decomposed.add((num: adjNum, denScalar: p, denMap: denMap));
  }

  if (!hasDenominator) {
    return simplifyAdd(terms);
  }

  // Compute LCM of denominator scalars and symbolic factor exponents.
  var lcmScalar = Integer.one;
  final lcmFactors = <Expr, int>{};
  for (final item in decomposed) {
    if (!item.denScalar.isZero) {
      final g = lcmScalar.gcd(item.denScalar);
      lcmScalar = (lcmScalar ~/ g) * item.denScalar;
    }
    for (final MapEntry(:key, :value) in item.denMap.entries) {
      final existing = lcmFactors[key] ?? 0;
      if (value > existing) {
        lcmFactors[key] = value;
      }
    }
  }

  final scaledNumerators = <Expr>[];
  for (final item in decomposed) {
    final multScalar = IntegerNumber(lcmScalar ~/ item.denScalar);
    final diffFactors = <Expr, int>{};
    for (final MapEntry(:key, :value) in lcmFactors.entries) {
      final remExp = value - (item.denMap[key] ?? 0);
      if (remExp > 0) {
        diffFactors[key] = remExp;
      }
    }
    final multiplier = buildFactoredExpr(
      scalar: multScalar,
      factors: diffFactors,
    );
    scaledNumerators.add((item.num * multiplier).expand().simplify());
  }

  final totalNum = Add(scaledNumerators).expand().simplify();
  final totalDen = buildFactoredExpr(
    scalar: IntegerNumber(lcmScalar),
    factors: lcmFactors,
  );
  return cancelFactoredFraction(
    _factorPolynomial(totalNum),
    totalDen,
  ).simplify();
}

Expr _collectAdditive(Expr expr, String variable) {
  final expanded = expr.expand().simplify();
  if (!expanded.dependsOn(variable)) return expanded;

  final rawTerms = <Expr>[];
  MonomialAccumulator.collectTerms(expanded, rawTerms);

  final groups = <Expr, List<Expr>>{};
  for (final term in rawTerms) {
    final (:varPart, :coeffPart) = _splitByVariable(term, variable);
    groups.putIfAbsent(varPart, () => []).add(coeffPart);
  }

  final sortedVarParts = groups.keys.toList()..sort(compareStructural);
  final collectedTerms = <Expr>[];
  for (final varPart in sortedVarParts) {
    final coeffs = groups[varPart]!;
    final sumCoeff = coeffs.length == 1
        ? coeffs.first
        : Add(coeffs).expand().simplify();
    if (sumCoeff is Number && sumCoeff.isZero) continue;
    if (varPart == IntegerNumber.one) {
      collectedTerms.add(sumCoeff);
    } else if (sumCoeff == IntegerNumber.one) {
      collectedTerms.add(varPart);
    } else if (sumCoeff == IntegerNumber.negativeOne) {
      collectedTerms.add(MonomialAccumulator.negateMonomial(varPart));
    } else {
      final factors = <Expr>[
        sumCoeff,
        if (varPart case Mul(factors: final vf)) ...vf else varPart,
      ];
      collectedTerms.add(Mul(factors, isSimplified: true));
    }
  }

  return switch (collectedTerms) {
    [] => IntegerNumber.zero,
    [final single] => single,
    _ => Add(collectedTerms, isSimplified: true),
  };
}

({Expr varPart, Expr coeffPart}) _splitByVariable(Expr term, String variable) {
  if (!term.dependsOn(variable)) {
    return (varPart: IntegerNumber.one, coeffPart: term);
  }
  if (term case Mul(:final factors)) {
    final varFactors = <Expr>[];
    final coeffFactors = <Expr>[];
    for (final f in factors) {
      if (f.dependsOn(variable)) {
        varFactors.add(f);
      } else {
        coeffFactors.add(f);
      }
    }
    final varPart = switch (varFactors) {
      [] => IntegerNumber.one,
      [final single] => single,
      _ => simplifyMul(varFactors),
    };
    final coeffPart = switch (coeffFactors) {
      [] => IntegerNumber.one,
      [final single] => single,
      _ => simplifyMul(coeffFactors),
    };
    return (varPart: varPart, coeffPart: coeffPart);
  }
  return (varPart: term, coeffPart: IntegerNumber.one);
}

Map<int, Expr>? _extractPolynomialCoeffs(Expr expr, String variable) {
  final expanded = expr.expand().simplify();
  if (!_isPolynomialIn(expanded, variable)) return null;
  final acc = MonomialAccumulator()..add(expanded);
  return acc.extractPolynomialCoefficients(variable);
}

bool _isPolynomialIn(Expr expr, String variable) {
  if (!expr.dependsOn(variable)) return true;
  return switch (expr) {
    Variable(:final name) => name == variable,
    Add(:final terms) => terms.every((t) => _isPolynomialIn(t, variable)),
    Mul(:final factors) => factors.every((f) => _isPolynomialIn(f, variable)),
    Pow(:final base, exponent: IntegerNumber(:final value))
        when value >= Integer.zero && !value.isBig =>
      _isPolynomialIn(base, variable),
    _ => false,
  };
}

int _maxDegree(Map<int, Expr> coeffs, ExprField field) {
  var maxD = -1;
  for (final MapEntry(key: deg, value: coeff) in coeffs.entries) {
    if (!field.isZero(coeff) && deg > maxD) {
      maxD = deg;
    }
  }
  return maxD;
}

Expr _buildPolynomial(Map<int, Expr> coeffs, String variable) {
  const field = ExprField.instance;
  final x = Variable(variable);
  final terms = <Expr>[];
  final sortedDegrees = coeffs.keys.toList()..sort();
  for (final deg in sortedDegrees) {
    final c = coeffs[deg]!.simplify();
    if (field.isZero(c)) continue;
    final xPow = deg == 0
        ? IntegerNumber.one
        : deg == 1
        ? x
        : Pow(x, IntegerNumber.of(deg));
    terms.add(deg == 0 ? c : (c * xPow).simplify());
  }
  return switch (terms) {
    [] => IntegerNumber.zero,
    [final single] => single,
    _ => Add(terms).simplify(),
  };
}
