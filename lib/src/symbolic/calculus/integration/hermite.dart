import '../../algebra/rational.dart';
import '../../algebra/simplify.dart';
import '../../assumptions.dart';
import '../../ast.dart';
import '../../functions/fn.dart';
import '../../oracle/domain_oracle.dart';
import '../../poly/bridge.dart';
import '../../poly/factor.dart';
import '../../poly/univariate.dart';
import '../differentiation.dart';
import 'integration_elementary.dart';

/// Result of Hermite reduction decomposing `A(x) / D(x)` into an integrated
/// rational part plus a remaining proper fraction `num / den` with square-free
/// monic denominator [den].
class HermiteReductionResult {
  /// Creates a Hermite reduction result.
  const new({required this.rationalPart, required this.num, required this.den});

  /// The rational antiderivative extracted from repeated denominator factors
  /// and polynomial quotient terms.
  final Expr rationalPart;

  /// Reduced remainder numerator strictly below the degree of [den].
  final PolyQ num;

  /// Square-free monic denominator polynomial (or [PolyQ.one] if [num] is zero).
  final PolyQ den;
}

/// Performs Hermite reduction over `Q[x]` on the rational function `num / den`
/// with respect to [variable].
///
/// Decomposes `num / den = d/dx(rationalPart) + r / Q` where `Q` is square-free
/// and monic, using [PolyQ.squareFreeDecomposition] and [PolyQ.extendedGcd].
HermiteReductionResult hermiteReduce(
  PolyQ num,
  PolyQ den,
  String variable, {
  Assumptions assumptions = Assumptions.none,
}) {
  if (den.isZero) {
    throw ArgumentError('Denominator polynomial cannot be zero');
  }
  if (num.isZero) {
    return HermiteReductionResult(
      rationalPart: IntegerNumber.zero,
      num: PolyQ.zero,
      den: PolyQ.one,
    );
  }

  final rationalTerms = <Expr>[];
  final (:quotient, :remainder) = num.divRem(den);
  if (!quotient.isZero) {
    rationalTerms.add(_integratePolyQ(quotient, variable));
  }
  if (remainder.isZero) {
    return HermiteReductionResult(
      rationalPart: _sumExprs(rationalTerms, assumptions),
      num: PolyQ.zero,
      den: PolyQ.one,
    );
  }

  final invLead = den.leadingCoeff.reciprocal();
  var curNum = remainder.scale(invLead);
  final sqFree = den.monic().squareFreeDecomposition();
  final factors = [for (final item in sqFree) item.factor];
  final mults = [for (final item in sqFree) item.multiplicity];

  for (var idx = 0; idx < factors.length; idx++) {
    final v = factors[idx];
    final vExpr = polyQToExpr(v, variable);
    final vDeriv = v.derivative();
    while (mults[idx] >= 2) {
      final m = mults[idx];
      var w = PolyQ.one;
      for (var j = 0; j < factors.length; j++) {
        if (j == idx) continue;
        final mj = mults[j];
        if (mj > 0) {
          w = w * _polyQPow(factors[j], mj);
        }
      }
      final stepCoeffPoly = (w * vDeriv).scale(IntegerNumber.of(-(m - 1)));
      final (:gcd, :s, :t) = stepCoeffPoly.extendedGcd(v);
      if (!gcd.isConstant) {
        throw StateError('Square-free Hermite factor is not coprime: $v');
      }
      final invG = gcd.leadingCoeff.reciprocal();
      final sNorm = s.scale(invG);
      final tNorm = t.scale(invG);

      final (quotient: qDiv, remainder: b) = (curNum * sNorm).divRem(v);
      if (!b.isZero) {
        final bExpr = polyQToExpr(b, variable);
        final denomExpr = m == 2
            ? vExpr
            : Pow.of(vExpr, IntegerNumber.of(m - 1));
        rationalTerms.add(
          (bExpr / denomExpr).simplify(assumptions: assumptions),
        );
      }
      curNum = curNum * tNorm + qDiv * stepCoeffPoly - b.derivative() * w;
      mults[idx] = m - 1;
    }
  }

  var squareFreeDen = PolyQ.one;
  for (var i = 0; i < factors.length; i++) {
    if (mults[i] > 0) {
      squareFreeDen = squareFreeDen * factors[i];
    }
  }
  final finalDiv = curNum.divRem(squareFreeDen);
  if (!finalDiv.quotient.isZero) {
    rationalTerms.add(_integratePolyQ(finalDiv.quotient, variable));
  }

  return HermiteReductionResult(
    rationalPart: _sumExprs(rationalTerms, assumptions),
    num: finalDiv.remainder,
    den: finalDiv.remainder.isZero ? PolyQ.one : squareFreeDen,
  );
}

/// Integrates a square-free rational function `num / den` over `Q[x]`, returning
/// `null` only if an irreducible factor of degree >= 3 cannot be split via
/// Rothstein-Trager rational-root logs.
Expr? integrateSquareFreeRational(
  PolyQ num,
  PolyQ den,
  String variable, {
  Assumptions assumptions = Assumptions.none,
}) {
  if (den.isZero) {
    throw ArgumentError('Denominator polynomial cannot be zero');
  }
  if (num.isZero) return IntegerNumber.zero;

  final invLead = den.leadingCoeff.reciprocal();
  final scaledNum = num.scale(invLead);
  final monicDen = den.monic();
  final (:quotient, :remainder) = scaledNum.divRem(monicDen);
  final terms = <Expr>[];
  if (!quotient.isZero) {
    terms.add(_integratePolyQ(quotient, variable));
  }
  if (remainder.isZero) {
    return _sumExprs(terms, assumptions);
  }

  final factored = factorPolyQ(monicDen);
  if (factored.factors.any((entry) => entry.multiplicity != 1)) {
    return null;
  }
  final irred = [
    for (final entry in factored.factors) entry.factor.toPolyQ().monic(),
  ];
  if (irred.isEmpty) {
    return _sumExprs(terms, assumptions);
  }

  var remNum = remainder;
  for (var i = 0; i < irred.length; i++) {
    final fi = irred[i];
    Expr? piece;
    if (i == irred.length - 1) {
      piece = _integrateIrreduciblePiece(remNum, fi, variable, assumptions);
    } else {
      var rest = PolyQ.one;
      for (var j = i + 1; j < irred.length; j++) {
        rest = rest * irred[j];
      }
      final (:gcd, :s, :t) = fi.extendedGcd(rest);
      if (!gcd.isConstant) return null;
      final invG = gcd.leadingCoeff.reciprocal();
      final sNorm = s.scale(invG);
      final tNorm = t.scale(invG);
      final (quotient: qSplit, remainder: ni) = (remNum * tNorm).divRem(fi);
      remNum = remNum * sNorm + qSplit * rest;
      piece = _integrateIrreduciblePiece(ni, fi, variable, assumptions);
    }
    if (piece == null) return null;
    terms.add(piece);
  }

  return _sumExprs(terms, assumptions);
}

Expr? _integrateIrreduciblePiece(
  PolyQ num,
  PolyQ den,
  String variable,
  Assumptions assumptions,
) {
  if (num.isZero) return IntegerNumber.zero;
  final deg = den.degree;
  final fExpr = polyQToExpr(den, variable);

  if (deg == 1) {
    final coeff = num.coeffs.first;
    return (coeff * logAntiderivative(fExpr, assumptions)).simplify(
      assumptions: assumptions,
    );
  }

  if (deg == 2) {
    // den = x^2 + p*x + q, num = d*x + e
    final p = den.coeffs[1];
    final q = den.coeffs[0];
    final e = num.coeffs[0];
    final d = num.degree >= 1 ? num.coeffs[1] : IntegerNumber.zero;
    final parts = <Expr>[];
    if (!d.isZero) {
      final halfD = d.mulRational(FractionNumber.half);
      parts.add(
        (halfD * logAntiderivative(fExpr, assumptions)).simplify(
          assumptions: assumptions,
        ),
      );
    }
    final remConst = e.subRational(
      d.mulRational(p).mulRational(FractionNumber.half),
    );
    if (!remConst.isZero) {
      final disc = p
          .mulRational(p)
          .subRational(IntegerNumber.of(4).mulRational(q));
      final linearShift = (IntegerNumber.two * Variable(variable) + p).simplify(
        assumptions: assumptions,
      );
      if (disc.isNegative) {
        final posDelta = disc.neg();
        final rootDelta = Pow.of(
          posDelta,
          FractionNumber.half,
        ).simplify(assumptions: assumptions);
        final coeff = (IntegerNumber.two * remConst / rootDelta).simplify(
          assumptions: assumptions,
        );
        parts.add(
          (coeff *
                  Fn.atan(
                    (linearShift / rootDelta).simplify(
                      assumptions: assumptions,
                    ),
                  ))
              .simplify(assumptions: assumptions),
        );
      } else {
        final rootDisc = Pow.of(
          disc,
          FractionNumber.half,
        ).simplify(assumptions: assumptions);
        final coeff = (remConst / rootDisc).simplify(assumptions: assumptions);
        final lower = (linearShift - rootDisc).simplify(
          assumptions: assumptions,
        );
        final upper = (linearShift + rootDisc).simplify(
          assumptions: assumptions,
        );
        final logRatio =
            (logAntiderivative(lower, assumptions) -
                    logAntiderivative(upper, assumptions))
                .simplify(assumptions: assumptions);
        parts.add((coeff * logRatio).simplify(assumptions: assumptions));
      }
    }
    return _sumExprs(parts, assumptions);
  }

  // Degree >= 3: quick derivative multiple check and Rothstein-Trager rational-root logs.
  final denDeriv = den.derivative();
  final (quotient: qDer, remainder: rDer) = num.divRem(denDeriv);
  if (rDer.isZero && qDer.isConstant) {
    final c = qDer.isZero ? IntegerNumber.zero : qDer.coeffs.first;
    return (c * logAntiderivative(fExpr, assumptions)).simplify(
      assumptions: assumptions,
    );
  }
  if (deg <= 8) {
    final resultantPoly = _rothsteinTragerResultantPoly(num, den, denDeriv);
    if (!resultantPoly.isZero && resultantPoly.degree >= 1) {
      final rtFactored = factorPolyQ(resultantPoly);
      final canSplitLinear = rtFactored.factors.every(
        (item) => item.factor.degree == 1,
      );
      if (canSplitLinear && rtFactored.factors.isNotEmpty) {
        final logTerms = <Expr>[];
        for (final item in rtFactored.factors) {
          final lin = item.factor.toPolyQ();
          // lin = c1 * t + c0 -> root = -c0 / c1
          final root = lin.coeffs[0].neg().divRational(lin.coeffs[1]);
          final shifted = num - denDeriv.scale(root);
          final g = den.gcd(shifted);
          if (g.degree >= 1 && !root.isZero) {
            logTerms.add(
              (root * logAntiderivative(polyQToExpr(g, variable), assumptions))
                  .simplify(assumptions: assumptions),
            );
          }
        }
        if (logTerms.isNotEmpty) {
          final candidate = _sumExprs(logTerms, assumptions);
          final residual =
              (candidate.derivative(variable, assumptions: assumptions) -
                      polyQToExpr(num, variable) / fExpr)
                  .cancel(assumptions: assumptions);
          if (residual == IntegerNumber.zero ||
              DomainOracle(assumptions).signOf(residual) == Sign.zero) {
            return candidate;
          }
        }
      }
    }
  }
  return null;
}

PolyQ _rothsteinTragerResultantPoly(PolyQ num, PolyQ den, PolyQ denDeriv) {
  final deg = den.degree;
  final y = <RationalNumber>[
    for (var k = 0; k <= deg; k++)
      den.resultant(num - denDeriv.scale(IntegerNumber.of(k))),
  ];
  // Newton forward difference interpolation at t = 0, 1, ..., deg.
  for (var j = 1; j <= deg; j++) {
    for (var i = deg; i >= j; i--) {
      y[i] = y[i].subRational(y[i - 1]);
    }
  }
  var poly = PolyQ.zero;
  var falling = PolyQ.one;
  var fact = BigInt.one;
  for (var j = 0; j <= deg; j++) {
    if (j > 0) {
      fact *= BigInt.from(j);
      falling =
          falling * PolyQ([IntegerNumber.of(-(j - 1)), IntegerNumber.one]);
    }
    if (!y[j].isZero) {
      final weight = y[j].divRational(IntegerNumber(fact));
      poly = poly + falling.scale(weight);
    }
  }
  return poly;
}

PolyQ _polyQPow(PolyQ base, int exp) {
  var result = PolyQ.one;
  var cur = base;
  var e = exp;
  while (e > 0) {
    if (e.isOdd) result = result * cur;
    e >>= 1;
    if (e > 0) cur = cur * cur;
  }
  return result;
}

Expr _integratePolyQ(PolyQ poly, String variable) {
  final x = Variable(variable);
  final terms = <Expr>[];
  for (var i = 0; i < poly.coeffs.length; i++) {
    final c = poly.coeffs[i];
    if (c.isZero) continue;
    final newPow = i + 1;
    final scaledCoeff = c.divRational(IntegerNumber.of(newPow));
    final mon = newPow == 1 ? x : Pow.of(x, IntegerNumber.of(newPow));
    terms.add(scaledCoeff.isOne ? mon : scaledCoeff * mon);
  }
  return switch (terms) {
    [] => IntegerNumber.zero,
    [final single] => single,
    _ => Add.of(terms),
  };
}

Expr _sumExprs(List<Expr> terms, Assumptions assumptions) => switch (terms) {
  [] => IntegerNumber.zero,
  [final single] => single.simplify(assumptions: assumptions),
  _ => Add.of(terms).simplify(assumptions: assumptions),
};
