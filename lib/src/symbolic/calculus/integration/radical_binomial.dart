import 'package:more/math.dart' show LcmIntegerExtension;

import '../../algebra/expand.dart';
import '../../algebra/helpers.dart';
import '../../algebra/rational.dart';
import '../../algebra/simplify.dart';
import '../../algebra/simplify/domain.dart';
import '../../assumptions.dart';
import '../../ast.dart';
import '../../number/integer.dart';
import '../linear_form.dart';
import 'definite.dart';
import 'integration.dart';

import 'radical.dart';

Expr? tryChebyshevBinomial(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  final factors = expr is Mul ? expr.factors : [expr];
  var constScale = IntegerNumber.one as Expr;
  var m = 0;
  Pow? binomPow;

  for (final f in factors) {
    if (!f.dependsOn(variable)) {
      constScale = (constScale * f).simplify();
      continue;
    }
    if (f is Variable && f.name == variable) {
      m += 1;
      continue;
    }
    if (f case Pow(base: Variable(:final name), :final exponent)
        when name == variable) {
      if (exponent case IntegerNumber(:final asInt) when asInt != null) {
        m += asInt;
        continue;
      }
      return null;
    }
    if (f is Pow && binomPow == null) {
      binomPow = f;
      continue;
    }
    return null;
  }

  if (binomPow == null) return null;
  final fracExp = fractionalExponent(binomPow.exponent);
  if (fracExp == null) return null;
  final (:p, :q) = fracExp;

  final baseCoeffs = extractPolynomialCoefficients(binomPow.base, variable);
  if (baseCoeffs == null) return null;
  final n = maxPolynomialDegree(baseCoeffs);
  if (n < 2) return null;
  for (var deg = 1; deg < n; deg++) {
    if (baseCoeffs[deg] != null && baseCoeffs[deg] != IntegerNumber.zero) {
      return null;
    }
  }
  final a = baseCoeffs[0] ?? IntegerNumber.zero;
  final b = baseCoeffs[n] ?? IntegerNumber.zero;
  if (a == IntegerNumber.zero || b == IntegerNumber.zero) return null;

  final uName = freshIntegrationVar('_u', expr, variable, depth);
  final uVar = Variable(uName);

  // Case 1: (m + 1) / n is an integer k
  if ((m + 1) % n == 0) {
    final k = (m + 1) ~/ n;
    if (k > 0 && k <= 8) {
      final transformed =
          (constScale *
                  (IntegerNumber.one / (IntegerNumber.of(n) * b)) *
                  Pow((uVar - a) / b, IntegerNumber.of(k - 1)) *
                  Pow(uVar, FractionNumber(Integer(p), Integer(q))))
              .expand()
              .simplify(assumptions: assumptions);
      final uAntideriv = antiDerivative(
        transformed,
        uName,
        assumptions: assumptions,
        depth: depth + 1,
      );
      if (!hasUnevaluatedIntegral(uAntideriv, uName)) {
        return uAntideriv
            .substitute(uName, binomPow.base)
            .simplify(assumptions: assumptions);
      }
    } else if (k <= 0 && k >= -10 && q >= 2) {
      final bPow = k == 0 ? IntegerNumber.one : Pow(b, IntegerNumber.of(k));
      final transformed =
          (constScale *
                  (IntegerNumber.of(q) / (IntegerNumber.of(n) * bPow)) *
                  Pow(uVar, IntegerNumber.of(p + q - 1)) *
                  Pow(
                    Pow(uVar, IntegerNumber.of(q)) - a,
                    IntegerNumber.of(k - 1),
                  ))
              .simplify(assumptions: assumptions);
      final uAntideriv = antiDerivative(
        transformed,
        uName,
        assumptions: assumptions,
        depth: depth + 1,
      );
      if (!hasUnevaluatedIntegral(uAntideriv, uName)) {
        return uAntideriv
            .substitute(
              uName,
              Pow(binomPow.base, FractionNumber(Integer.one, Integer(q))),
            )
            .simplify(assumptions: assumptions);
      }
    }
  }

  // Case 2: (m + 1) / n + p / q is an integer r
  final numSum = (m + 1) * q + p * n;
  final denProd = n * q;
  if (numSum % denProd == 0) {
    final r = numSum ~/ denProd;
    if (r.abs() <= 6) {
      final transformed =
          (constScale *
                  (-IntegerNumber.of(q) / (IntegerNumber.of(n) * a)) *
                  Pow(uVar, IntegerNumber.of(q - 1 + p)) *
                  Pow(
                    (Pow(uVar, IntegerNumber.of(q)) - b) / a,
                    IntegerNumber.of(-(r + 1)),
                  ))
              .expand()
              .simplify(assumptions: assumptions);
      final uAntideriv = antiDerivative(
        transformed,
        uName,
        assumptions: assumptions,
        depth: depth + 1,
      );
      if (!hasUnevaluatedIntegral(uAntideriv, uName)) {
        final xVar = Variable(variable);
        final Expr backSub;
        if (n % q == 0) {
          backSub =
              (Pow(binomPow.base, FractionNumber(Integer.one, Integer(q))) *
                      Pow(xVar, IntegerNumber.of(-(n ~/ q))))
                  .simplify(assumptions: assumptions);
        } else {
          final backRad = Pow(
            (a * Pow(xVar, IntegerNumber.of(-n)) + b).simplify(
              assumptions: assumptions,
            ),
            FractionNumber(Integer.one, Integer(q)),
          );
          final absXSignPow =
              (n.isEven &&
                  p.isOdd &&
                  !isNonNegativeExpr(xVar, assumptions: assumptions))
              ? Sign(xVar)
              : IntegerNumber.one;
          backSub = (absXSignPow * backRad).simplify(assumptions: assumptions);
        }
        return uAntideriv
            .substitute(uName, backSub)
            .simplify(assumptions: assumptions);
      }
    }
  }

  final isNegIntAlpha = (m + 1) % n == 0 && (m + 1) ~/ n <= 0;
  if (m != -1 && isSymbolicPositive(a) && !isNegIntAlpha) {
    final alpha = FractionNumber(Integer(m + 1), Integer(n));
    final beta = FractionNumber(Integer(-p), Integer(q));
    final alphaPlus1 = (alpha + IntegerNumber.one).simplify(
      assumptions: assumptions,
    );
    final xVar = Variable(variable);
    final aPow = Pow(
      a,
      FractionNumber(Integer(p), Integer(q)),
    ).simplify(assumptions: assumptions);
    final arg = (-b * Pow(xVar, IntegerNumber.of(n)) / a).simplify(
      assumptions: assumptions,
    );
    return (constScale *
            aPow *
            Pow(xVar, IntegerNumber.of(m + 1)) *
            Hypergeometric([alpha, beta], [alphaPlus1], arg) /
            IntegerNumber.of(m + 1))
        .simplify(assumptions: assumptions);
  }

  return null;
}

/// Integrates `P(x) / sqrt(Q(x))`, `sqrt(Q(x)) / x^k`, or `c / (x^k * sqrt(Q(x)))`.
Expr? tryPolynomialOverSqrtQuadratic(Expr left, Expr right, String variable) {
  // Case 1: P(x) / sqrt(Ax^2 + Bx + C) with deg(P) >= 2
  if (right case Pow(base: final quad, exponent: final exp)
      when halfIntExponent(exp) == 1) {
    final coeffs = extractPolynomialCoefficients(quad, variable);
    if (coeffs != null && maxPolynomialDegree(coeffs) == 2) {
      final rawDegLeft = polynomialDegree(left, variable);
      if (rawDegLeft != null && rawDegLeft >= 2 && rawDegLeft <= 12) {
        final leftExp = left.expand().simplify();
        final degLeft = polynomialDegree(leftExp, variable);
        if (degLeft != null && degLeft >= 2 && degLeft <= 12) {
          return integratePolyOverSqrtQ(
            leftExp,
            quad,
            coeffs[2] ?? IntegerNumber.zero,
            coeffs[1] ?? IntegerNumber.zero,
            coeffs[0] ?? IntegerNumber.zero,
            variable,
          );
        }
      }
    }
  }

  // Case 2: P(x) * sqrt(Ax^2 + Bx + C) / x^k (k >= 1)
  final Expr? polyFactorLeft;
  final Pow? radLeft;
  if (left case Pow(base: final q, exponent: final exp)
      when halfIntExponent(exp) == 1) {
    polyFactorLeft = IntegerNumber.one;
    radLeft = Pow(q, exp);
  } else if (left is Mul) {
    Pow? foundRad;
    final polyParts = <Expr>[];
    for (final f in left.factors) {
      if (f is Pow && halfIntExponent(f.exponent) == 1 && foundRad == null) {
        foundRad = f;
      } else {
        polyParts.add(f);
      }
    }
    if (foundRad != null && polyParts.isNotEmpty) {
      final candidatePoly = polyParts.length == 1
          ? polyParts.first
          : Mul(polyParts).simplify();
      final degP = polynomialDegree(candidatePoly, variable);
      if (degP != null && degP <= 6) {
        polyFactorLeft = candidatePoly;
        radLeft = foundRad;
      } else {
        polyFactorLeft = null;
        radLeft = null;
      }
    } else {
      polyFactorLeft = null;
      radLeft = null;
    }
  } else {
    polyFactorLeft = null;
    radLeft = null;
  }

  if (radLeft != null && polyFactorLeft != null) {
    final coeffs = extractPolynomialCoefficients(radLeft.base, variable);
    if (coeffs != null && maxPolynomialDegree(coeffs) == 2) {
      int? k;
      if (right is Variable && right.name == variable) {
        k = 1;
      } else if (right
          case Pow(
            base: Variable(:final name),
            exponent: IntegerNumber(asInt: final p?),
          )
          when name == variable && p >= 1 && p <= 10) {
        k = p;
      }
      if (k != null) {
        if (polyFactorLeft != IntegerNumber.one &&
            polyFactorLeft.dependsOn(variable)) {
          final pCoeffs = extractPolynomialCoefficients(
            polyFactorLeft.expand().simplify(),
            variable,
          );
          if (pCoeffs != null) {
            final xVar = Variable(variable);
            final sumTerms = <Expr>[];
            var ok = true;
            for (final MapEntry(key: j, value: cJ) in pCoeffs.entries) {
              if (cJ is Number && cJ.isZero) continue;
              final Expr? tRes;
              if (j >= k) {
                final numJ = j == k
                    ? cJ
                    : (cJ * Pow(xVar, IntegerNumber.of(j - k))).simplify();
                tRes =
                    tryQuadraticRadical(numJ, radLeft.base, 1, variable) ??
                    antiDerivative(
                      (numJ * radLeft).simplify(),
                      variable,
                      assumptions: Assumptions.none,
                      depth: 2,
                    );
              } else {
                final denJ = k - j == 1
                    ? xVar
                    : Pow(xVar, IntegerNumber.of(k - j));
                tRes = tryPolynomialOverSqrtQuadratic(
                  (cJ * radLeft).simplify(),
                  denJ,
                  variable,
                );
              }
              if (tRes == null || hasUnevaluatedIntegral(tRes, variable)) {
                ok = false;
                break;
              }
              sumTerms.add(tRes);
            }
            if (ok) {
              return sumTerms.isEmpty
                  ? IntegerNumber.zero
                  : Add(sumTerms).simplify();
            }
          }
          return null;
        }

        final a = coeffs[2] ?? IntegerNumber.zero;
        final b = coeffs[1] ?? IntegerNumber.zero;
        final c = coeffs[0] ?? IntegerNumber.zero;
        final xVar = Variable(variable);
        // sqrt(Q)/x^k = A*x^(2-k)/sqrt(Q) + B*x^(1-k)/sqrt(Q) + C/(x^k * sqrt(Q))
        final term1 = k == 1
            ? antiDerivative(
                (a * xVar / radLeft).simplify(),
                variable,
                assumptions: Assumptions.none,
              )
            : (k == 2
                  ? antiDerivative(
                      (a / radLeft).simplify(),
                      variable,
                      assumptions: Assumptions.none,
                    )
                  : tryPolynomialOverSqrtQuadratic(
                      a,
                      Pow(xVar, IntegerNumber.of(k - 2)) * radLeft,
                      variable,
                    ));
        final term2 = (b is Number && b.isZero)
            ? IntegerNumber.zero
            : (k == 1
                  ? antiDerivative(
                      (b / radLeft).simplify(),
                      variable,
                      assumptions: Assumptions.none,
                    )
                  : tryPolynomialOverSqrtQuadratic(
                      b,
                      Pow(xVar, IntegerNumber.of(k - 1)) * radLeft,
                      variable,
                    ));
        final term3 = (c is Number && c.isZero)
            ? IntegerNumber.zero
            : tryPolynomialOverSqrtQuadratic(
                c,
                (right * radLeft).simplify(),
                variable,
              );
        if (term1 != null &&
            term2 != null &&
            term3 != null &&
            !hasUnevaluatedIntegral(term1, variable) &&
            !hasUnevaluatedIntegral(term2, variable) &&
            !hasUnevaluatedIntegral(term3, variable)) {
          return (polyFactorLeft * (term1 + term2 + term3)).simplify();
        }
      }
    }
  }

  // Case 3: P(x) / (x^k * sqrt(Ax^2 + Bx + C)) (k >= 1) via t = 1/x
  if (right is Mul) {
    final factors = right.factors;
    var k = 0;
    Pow? rad;
    var valid = true;
    for (final f in factors) {
      if (f is Variable && f.name == variable) {
        k += 1;
      } else if (f
          case Pow(
            base: Variable(:final name),
            exponent: IntegerNumber(asInt: final p?),
          )
          when name == variable && p >= 1) {
        k += p;
      } else if (f is Pow && halfIntExponent(f.exponent) == 1 && rad == null) {
        rad = f;
      } else {
        valid = false;
      }
    }
    if (valid && k >= 1 && k <= 12 && rad != null) {
      if (left.dependsOn(variable)) {
        final degLeft = polynomialDegree(left, variable);
        if (degLeft != null && degLeft <= 8) {
          final pCoeffs = extractPolynomialCoefficients(left, variable);
          if (pCoeffs != null) {
            final xVar = Variable(variable);
            final results = <Expr>[];
            var ok = true;
            for (final MapEntry(key: j, value: coeff) in pCoeffs.entries) {
              if (coeff is Number && coeff.isZero) continue;
              final Expr? termRes;
              if (j >= k) {
                final numTerm = j == k
                    ? coeff
                    : (coeff * Pow(xVar, IntegerNumber.of(j - k))).simplify();
                termRes = antiDerivative(
                  (numTerm / rad).simplify(),
                  variable,
                  assumptions: Assumptions.none,
                  depth: 2,
                );
              } else {
                final denomTerm = (Pow(xVar, IntegerNumber.of(k - j)) * rad)
                    .simplify();
                termRes = tryPolynomialOverSqrtQuadratic(
                  coeff,
                  denomTerm,
                  variable,
                );
              }
              if (termRes == null ||
                  hasUnevaluatedIntegral(termRes, variable)) {
                ok = false;
                break;
              }
              results.add(termRes);
            }
            if (ok) {
              return results.isEmpty
                  ? IntegerNumber.zero
                  : Add(results).simplify();
            }
          }
        }
        return null;
      }
      final coeffs = extractPolynomialCoefficients(rad.base, variable);
      if (coeffs != null && maxPolynomialDegree(coeffs) == 2) {
        final a = coeffs[2] ?? IntegerNumber.zero;
        final b = coeffs[1] ?? IntegerNumber.zero;
        final c = coeffs[0] ?? IntegerNumber.zero;
        const tName = '_inv';
        const tVar = Variable(tName);
        final qT = (c * tVar * tVar + b * tVar + a).simplify();
        final numT =
            (-left *
                    (k == 1
                        ? IntegerNumber.one
                        : Pow(tVar, IntegerNumber.of(k - 1))))
                .simplify();
        final tIntegrand = (numT / Pow(qT, FractionNumber.half)).simplify();
        final tInt =
            tryQuadraticRadical(numT, qT, -1, tName, preferLog: true) ??
            (c is Number && c.isZero
                ? tryAffineRadicalSubstitution(
                    tIntegrand,
                    tName,
                    assumptions: Assumptions.none,
                    depth: 0,
                  )
                : null) ??
            antiDerivative(
              tIntegrand,
              tName,
              assumptions: Assumptions.none,
              depth: 1,
            );
        if (!hasUnevaluatedIntegral(tInt, tName)) {
          final xVar = Variable(variable);
          final radBase = rad.base;
          final qTCoeffs = extractPolynomialCoefficients(qT, tName);
          final qTLead = qTCoeffs != null
              ? qTCoeffs[maxPolynomialDegree(qTCoeffs)]
              : null;
          Expr replaceQuadT(Expr node) {
            if (node case Pow(:final base, exponent: final FractionNumber exp)
                when exp.denominator == Integer.two) {
              final numInt = exp.numerator.asInt;
              if (numInt != null) {
                Expr? scaleFactor;
                if (base == qT) {
                  scaleFactor = IntegerNumber.one;
                } else if (qTLead != null && qTCoeffs != null) {
                  final bCoeffs = extractPolynomialCoefficients(base, tName);
                  if (bCoeffs != null &&
                      maxPolynomialDegree(bCoeffs) ==
                          maxPolynomialDegree(qTCoeffs)) {
                    final candidateScale =
                        (bCoeffs[maxPolynomialDegree(bCoeffs)]! / qTLead)
                            .simplify();
                    if (!candidateScale.dependsOn(tName) &&
                        (base - candidateScale * qT).expand().simplify() ==
                            IntegerNumber.zero) {
                      scaleFactor = candidateScale;
                    }
                  }
                }
                if (scaleFactor != null) {
                  final newRadBase = scaleFactor == IntegerNumber.one
                      ? radBase
                      : (scaleFactor * radBase).simplify();
                  return Pow(newRadBase, exp) *
                      Pow(xVar, IntegerNumber.of(-numInt));
                }
              }
            }
            return node.mapChildren(replaceQuadT);
          }

          return replaceQuadT(tInt)
              .substitute(tName, IntegerNumber.one / xVar)
              .simplify();
        }
      }
    }
  }

  // Case 3b: P(x) / ((c*x + d)^k * sqrt(Ax^2 + Bx + C)) (k >= 1, d != 0)
  // via u = c*x + d.
  if (right is Mul) {
    final factors = right.factors;
    var k = 0;
    Expr? linBase;
    Pow? rad;
    final constFactors = <Expr>[];
    var valid = true;
    for (final f in factors) {
      if (!f.dependsOn(variable)) {
        constFactors.add(f);
      } else if (f is Pow && halfIntExponent(f.exponent) == 1 && rad == null) {
        rad = f;
      } else if (f.matchLinear(variable) != null &&
          (linBase == null || linBase == f)) {
        linBase = f;
        k += 1;
      } else if (f
          case Pow(:final base, exponent: IntegerNumber(asInt: final p?))
          when p >= 1 &&
              base.matchLinear(variable) != null &&
              (linBase == null || linBase == base)) {
        linBase = base;
        k += p;
      } else {
        valid = false;
        break;
      }
    }
    if (valid && k >= 1 && k <= 8 && linBase != null && rad != null) {
      if (linBase.matchLinear(variable)
          case (a: final slope, b: final intercept)
          when !(intercept is Number && intercept.isZero)) {
        final coeffs = extractPolynomialCoefficients(rad.base, variable);
        if (coeffs != null && maxPolynomialDegree(coeffs) == 2) {
          const uName = '_lin';
          const uVar = Variable(uName);
          final xOfU = ((uVar - intercept) / slope).simplify();
          final constScale = constFactors.isEmpty
              ? IntegerNumber.one
              : Mul(constFactors).simplify();
          final numU = (left.substitute(variable, xOfU) / (constScale * slope))
              .simplify();
          final qU = rad.base.substitute(variable, xOfU).simplify();
          final denU =
              (Pow(uVar, IntegerNumber.of(k)) * Pow(qU, FractionNumber.half))
                  .simplify();
          final uRes = tryPolynomialOverSqrtQuadratic(numU, denU, uName);
          if (uRes != null && !hasUnevaluatedIntegral(uRes, uName)) {
            return uRes.substitute(uName, linBase).simplify();
          }
        }
      }
    }
  }

  return null;
}

/// Attempts fractional-linear radical substitution `u = ((a*x + b) / (c*x + d))^(1/n)`.
Expr? tryFractionalLinearRadical(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  Pow? targetPow;
  ({int p, int q})? frac;
  Expr? foundNumB;
  Expr? foundDenB;
  void scan(Expr n) {
    if (targetPow != null || !n.dependsOn(variable)) return;
    if (n case Pow(:final base, :final exponent)) {
      if (fractionalExponent(exponent) case final fq? when fq.q <= 4) {
        var (numB, denB) = splitNumeratorDenominator(base);
        if (numB.matchLinear(variable) == null ||
            !denB.dependsOn(variable) ||
            denB.matchLinear(variable) == null) {
          final normBase = base
              .together(assumptions: assumptions)
              .cancel(assumptions: assumptions);
          if (normBase != base) {
            (numB, denB) = splitNumeratorDenominator(normBase);
          }
        }
        if (numB.matchLinear(variable) != null &&
            denB.dependsOn(variable) &&
            denB.matchLinear(variable) != null) {
          targetPow = n;
          frac = fq;
          foundNumB = numB;
          foundDenB = denB;
          return;
        }
      }
    }
    n.mapChildren((c) {
      scan(c);
      return c;
    });
  }

  scan(expr);
  if (targetPow == null ||
      frac == null ||
      foundNumB == null ||
      foundDenB == null) {
    return null;
  }

  final numB = foundNumB!;
  final denB = foundDenB!;
  final (:a, :b) = numB.matchLinear(variable)!;
  final (a: c, b: d) = denB.matchLinear(variable)!;
  final det = (a * d - b * c).simplify(assumptions: assumptions);
  if (det is Number && det.isZero) {
    final ratio = (a / c).simplify(assumptions: assumptions);
    final constVal = Pow(
      ratio,
      FractionNumber(Integer(frac!.p), Integer(frac!.q)),
    ).simplify(assumptions: assumptions);
    Expr replaceZeroDet(Expr node) {
      if (node == targetPow) return constVal;
      return node.mapChildren(replaceZeroDet);
    }

    final rewritten = replaceZeroDet(expr).simplify(assumptions: assumptions);
    if (rewritten != expr) {
      final res = antiDerivative(
        rewritten,
        variable,
        assumptions: assumptions,
        depth: depth + 1,
      );
      if (!hasUnevaluatedIntegral(res, variable)) return res;
    }
    return null;
  }
  final n = frac!.q;
  if (isIntegrationBudgetExhausted() || exceedsNodeBudget(expr, 150) || n > 4) {
    return null;
  }

  final uName = freshIntegrationVar('_fl', expr, variable, depth);
  final uVar = Variable(uName);
  final uPowN = Pow(uVar, IntegerNumber.of(n));
  final xOfU = ((d * uPowN - b) / (a - c * uPowN)).simplify();
  final dx =
      (IntegerNumber.of(n) *
              (a * d - b * c) *
              Pow(uVar, IntegerNumber.of(n - 1)) /
              Pow(a - c * uPowN, IntegerNumber.two))
          .simplify();

  Expr replaceNode(Expr node) {
    if (node == targetPow) return Pow(uVar, IntegerNumber.of(frac!.p));
    if (node is Variable && node.name == variable) return xOfU;
    return node.mapChildren(replaceNode);
  }

  final transformed = (replaceNode(expr) * dx).simplify(
    assumptions: assumptions,
  );
  if (transformed.dependsOn(variable) ||
      exceedsNodeBudget(transformed, 180) ||
      isIntegrationBudgetExhausted()) {
    return null;
  }
  final uInt = antiDerivative(
    transformed,
    uName,
    assumptions: assumptions,
    depth: 2,
  );
  if (hasUnevaluatedIntegral(uInt, uName)) return null;

  final backSub = Pow(targetPow!.base, FractionNumber(Integer.one, Integer(n)));
  return uInt.substitute(uName, backSub).simplify(assumptions: assumptions);
}

Expr? integratePolyOverSqrtQ(
  Expr poly,
  Expr quad,
  Expr a,
  Expr b,
  Expr c,
  String variable, {
  bool preferLog = false,
}) {
  final coeffs = extractPolynomialCoefficients(poly, variable);
  if (coeffs == null) return null;
  final deg = maxPolynomialDegree(coeffs);
  if (deg <= 1) {
    return tryQuadraticRadical(poly, quad, -1, variable, preferLog: preferLog);
  }
  final leadCoeff = coeffs[deg]!;
  final m = deg;
  final xVar = Variable(variable);
  final rad = Pow(quad, FractionNumber.half);
  final term1 =
      (leadCoeff *
              Pow(xVar, IntegerNumber.of(m - 1)) *
              rad /
              (IntegerNumber.of(m) * a))
          .simplify();

  final rem1 =
      (-leadCoeff *
              IntegerNumber.of(2 * m - 1) *
              b /
              (IntegerNumber.two * IntegerNumber.of(m) * a) *
              Pow(xVar, IntegerNumber.of(m - 1)))
          .simplify();
  final rem2 =
      (-leadCoeff *
              IntegerNumber.of(m - 1) *
              c /
              (IntegerNumber.of(m) * a) *
              (m - 2 == 0
                  ? IntegerNumber.one
                  : Pow(xVar, IntegerNumber.of(m - 2))))
          .simplify();
  final lowerPoly =
      (poly - leadCoeff * Pow(xVar, IntegerNumber.of(m)) + rem1 + rem2)
          .expand()
          .simplify();
  final remInt = integratePolyOverSqrtQ(
    lowerPoly,
    quad,
    a,
    b,
    c,
    variable,
    preferLog: preferLog,
  );
  if (remInt == null) return null;
  return (term1 + remInt).simplify();
}

/// Integrates fractional powers `(b * tan(a*x + c))^(k/2)` via
/// `u = (b * tan(a*x + c))^(1/2)`.
Expr? tryTrigRadicalSubstitution(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  if (depth >= 2) return null;
  final factors = expr is Mul ? expr.factors : [expr];
  var constScale = IntegerNumber.one as Expr;
  Pow? tanPow;

  for (final f in factors) {
    if (!f.dependsOn(variable)) {
      constScale = (constScale * f).simplify();
      continue;
    }
    if (f is Pow && tanPow == null) {
      tanPow = f;
      continue;
    }
    return null;
  }

  if (tanPow == null) return null;
  final k = halfIntExponent(tanPow.exponent);
  if (k == null || k.isEven || k.abs() > 7) return null;

  Expr bScale = IntegerNumber.one;
  Tan? tanNode;
  if (tanPow.base case final Tan t) {
    tanNode = t;
  } else if (tanPow.base case Mul(:final factors)) {
    final consts = <Expr>[];
    final vars = <Expr>[];
    for (final f in factors) {
      if (f.dependsOn(variable)) {
        vars.add(f);
      } else {
        consts.add(f);
      }
    }
    if (vars.length == 1 && vars.first is Tan) {
      tanNode = vars.first as Tan;
      if (consts.isNotEmpty) {
        bScale = Mul(consts).simplify(assumptions: assumptions);
      }
    }
  }
  if (tanNode == null) return null;

  final inner = tanNode.expr;
  final lin = inner.matchLinear(variable);
  if (lin == null) return null;
  final d = lin.a;

  final uName = freshIntegrationVar('_u', expr, variable, depth);
  final uVar = Variable(uName);
  final bSq = (bScale * bScale).simplify(assumptions: assumptions);
  final quarticDen = (Pow(uVar, const IntegerNumber(Integer(4))) + bSq)
      .simplify(assumptions: assumptions);
  final preFactor = (constScale * (IntegerNumber.two * bScale / d)).simplify(
    assumptions: assumptions,
  );

  Expr? uAntideriv;
  if (k >= -1) {
    final numU = k + 1 == 0
        ? IntegerNumber.one
        : Pow(uVar, IntegerNumber.of(k + 1));
    final transformed = (preFactor * numU / quarticDen).simplify(
      assumptions: assumptions,
    );
    uAntideriv = antiDerivative(
      transformed,
      uName,
      assumptions: assumptions,
      depth: depth + 1,
    );
  } else {
    // k <= -3: m = -(k + 1) in {2, 4, 6}
    var m = -(k + 1);
    var remScale = IntegerNumber.one as Expr;
    final terms = <Expr>[];
    while (m > 0) {
      final coeff = (remScale / bSq).simplify(assumptions: assumptions);
      final laurentInt =
          (-coeff /
                  (IntegerNumber.of(m - 1) *
                      Pow(uVar, IntegerNumber.of(m - 1))))
              .simplify(assumptions: assumptions);
      terms.add(laurentInt);
      remScale = (-coeff).simplify(assumptions: assumptions);
      m -= 4;
    }
    final remPow = -m; // 0 or 2
    final remNum = remPow == 0
        ? remScale
        : (remScale * Pow(uVar, IntegerNumber.of(remPow))).simplify(
            assumptions: assumptions,
          );
    final remInt = antiDerivative(
      (remNum / quarticDen).simplify(assumptions: assumptions),
      uName,
      assumptions: assumptions,
      depth: depth + 1,
    );
    if (!hasUnevaluatedIntegral(remInt, uName)) {
      terms.add(remInt);
      uAntideriv = (preFactor * Add(terms)).simplify(assumptions: assumptions);
    }
  }

  if (uAntideriv == null || hasUnevaluatedIntegral(uAntideriv, uName)) {
    return null;
  }
  return uAntideriv
      .substitute(uName, Pow(tanPow.base, FractionNumber.half))
      .simplify(assumptions: assumptions);
}

/// Integrates products of 2 or 3 non-proportional linear binomials
/// `scale * prod_{i=1..k} (a_i + b_i * x)^{e_i}` (`k in {2, 3}`) containing at
/// least one non-integer or symbolic exponent via Gauss `Hypergeometric`
/// `2F1` (`k == 2`) or `AppellF1` (`k == 3`).
Expr? tryLinearBinomialProductSpecial(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
}) {
  if (exceedsNodeBudget(expr, 180)) return null;
  final factors = expr is Mul ? expr.factors : [expr];
  var scale = IntegerNumber.one as Expr;
  final linItems =
      <({Expr base, Expr a, Expr b, Expr exp, bool isZeroConst})>[];

  for (final f in factors) {
    if (!f.dependsOn(variable)) {
      scale = (scale * f).simplify(assumptions: assumptions);
      continue;
    }
    final Expr b;
    final Expr exp;
    if (f case Pow(:final base, :final exponent)) {
      if (exponent.dependsOn(variable)) return null;
      b = base;
      exp = exponent;
    } else {
      b = f;
      exp = IntegerNumber.one;
    }
    final lin = b.matchLinear(variable);
    if (lin == null) return null;
    linItems.add((
      base: b,
      a: lin.b,
      b: lin.a,
      exp: exp,
      isZeroConst: lin.b is Number && (lin.b as Number).isZero,
    ));
  }

  if (linItems.length != 2 && linItems.length != 3) return null;
  if (linItems.every((e) => e.exp is IntegerNumber)) return null;

  bool isBadPrimaryExp(Expr e) =>
      (e is IntegerNumber && e.isNegative) ||
      (e is RealNumber &&
          e.value <= -1.0 &&
          e.value == e.value.roundToDouble());

  var primaryIdx = -1;
  for (var i = 0; i < linItems.length; i++) {
    if (isBadPrimaryExp(linItems[i].exp)) continue;
    if (primaryIdx == -1 ||
        (!linItems[primaryIdx].isZeroConst && linItems[i].isZeroConst) ||
        (linItems[primaryIdx].isZeroConst == linItems[i].isZeroConst &&
            linItems[primaryIdx].exp is IntegerNumber &&
            linItems[i].exp is! IntegerNumber)) {
      primaryIdx = i;
    }
  }
  if (primaryIdx == -1) return null;

  final u0Item = linItems[primaryIdx];
  final others = [
    for (var i = 0; i < linItems.length; i++)
      if (i != primaryIdx) linItems[i],
  ];

  final m = u0Item.exp;
  final mPlus1 = (m + IntegerNumber.one).simplify(assumptions: assumptions);
  if (mPlus1 is Number && mPlus1.isZero) return null;

  final dets = <Expr>[];
  final args = <Expr>[];
  final oneMinusArgs = <Expr>[];
  for (final item in others) {
    final det = (u0Item.b * item.a - u0Item.a * item.b).expand().simplify(
      assumptions: assumptions,
    );
    if (det is Number && det.isZero) return null;
    dets.add(det);
    args.add((-item.b * u0Item.base / det).simplify(assumptions: assumptions));
    oneMinusArgs.add(
      (u0Item.b * item.base / det).simplify(assumptions: assumptions),
    );
  }

  if (others.length == 1) {
    final u1Item = others[0];
    final n = u1Item.exp;
    if (m is RationalNumber && n is RationalNumber) {
      final sumExp = (m + n).simplify(assumptions: assumptions);
      final q1 = m.denominator.asInt;
      final q2 = n.denominator.asInt;
      if (sumExp is IntegerNumber &&
          sumExp.asInt != null &&
          q1 != null &&
          q2 != null) {
        final q = q1.lcm(q2);
        final k = sumExp.asInt!;
        final bigN = (n * IntegerNumber.of(q)).simplify(
          assumptions: assumptions,
        );
        if (q >= 2 &&
            q <= 4 &&
            k + 2 >= -8 &&
            k + 2 <= 10 &&
            bigN is IntegerNumber &&
            bigN.asInt != null &&
            (bigN.asInt! + q - 1).abs() <= 16) {
          final uName = freshIntegrationVar('_u', expr, variable, 0);
          final uVar = Variable(uName);
          final qExpr = IntegerNumber.of(q);
          final uPowQ = Pow(uVar, qExpr);
          final uIntegrand =
              (-scale *
                      qExpr *
                      Pow(dets[0], IntegerNumber.of(k + 1)) *
                      Pow(uVar, IntegerNumber.of(bigN.asInt! + q - 1)) *
                      Pow(
                        u0Item.b * uPowQ - u1Item.b,
                        IntegerNumber.of(-(k + 2)),
                      ))
                  .simplify(assumptions: assumptions);
          if (!exceedsNodeBudget(uIntegrand, 200)) {
            final uRes = antiDerivative(
              uIntegrand,
              uName,
              assumptions: assumptions,
              depth: 1,
            );
            if (!hasUnevaluatedIntegral(uRes, uName)) {
              final invQ = FractionNumber(Integer.one, Integer(q));
              final backSub = (Pow(u1Item.base, invQ) * Pow(u0Item.base, -invQ))
                  .simplify(assumptions: assumptions);
              return uRes
                  .substitute(uName, backSub)
                  .simplify(assumptions: assumptions);
            }
          }
        }
      }
    }
    final numFactor = (scale * Pow(u0Item.base, mPlus1) * Pow(u1Item.base, n))
        .simplify(assumptions: assumptions);
    final denFactor = (u0Item.b * mPlus1 * Pow(oneMinusArgs[0], n)).simplify(
      assumptions: assumptions,
    );
    return (numFactor *
            Hypergeometric(
              [mPlus1, (-n).simplify(assumptions: assumptions)],
              [(mPlus1 + IntegerNumber.one).simplify(assumptions: assumptions)],
              args[0],
            ) /
            denFactor)
        .simplify(assumptions: assumptions);
  }

  final u1Item = others[0];
  final u2Item = others[1];
  final allThree = [u0Item, u1Item, u2Item];
  for (var intIdx = 0; intIdx < 3; intIdx++) {
    final intItem = allThree[intIdx];
    if (intItem.exp case IntegerNumber(asInt: final r?)
        when r != 0 && r.abs() <= 8) {
      final fItems = [
        for (var j = 0; j < 3; j++)
          if (j != intIdx) allThree[j],
      ];
      final fa = fItems[0];
      final fb = fItems[1];
      if (fa.exp case final RationalNumber mA) {
        if (fb.exp case final RationalNumber nB) {
          final sumExp = (mA + nB).simplify(assumptions: assumptions);
          final q1 = mA.denominator.asInt;
          final q2 = nB.denominator.asInt;
          if (sumExp is IntegerNumber &&
              sumExp.asInt != null &&
              q1 != null &&
              q2 != null) {
            final q = q1.lcm(q2);
            final k = sumExp.asInt!;
            final bigN = (nB * IntegerNumber.of(q)).simplify(
              assumptions: assumptions,
            );
            final detAB = (fa.b * fb.a - fa.a * fb.b).expand().simplify(
              assumptions: assumptions,
            );
            if (!(detAB is Number && detAB.isZero) &&
                q >= 2 &&
                q <= 4 &&
                k + r + 2 >= -6 &&
                k + r + 2 <= 8 &&
                bigN is IntegerNumber &&
                bigN.asInt != null &&
                (bigN.asInt! + q - 1).abs() <= 16) {
              final uName = freshIntegrationVar('_u', expr, variable, 0);
              final uVar = Variable(uName);
              final qExpr = IntegerNumber.of(q);
              final uPowQ = Pow(uVar, qExpr);
              final bigA2 = (intItem.b * fb.a - intItem.a * fb.b)
                  .expand()
                  .simplify(assumptions: assumptions);
              final bigB2 = (intItem.a * fa.b - intItem.b * fa.a)
                  .expand()
                  .simplify(assumptions: assumptions);
              final uIntegrand =
                  (-scale *
                          qExpr *
                          Pow(detAB, IntegerNumber.of(k + 1)) *
                          Pow(uVar, IntegerNumber.of(bigN.asInt! + q - 1)) *
                          Pow(bigA2 + bigB2 * uPowQ, IntegerNumber.of(r)) *
                          Pow(
                            fa.b * uPowQ - fb.b,
                            IntegerNumber.of(-(k + r + 2)),
                          ))
                      .simplify(assumptions: assumptions);
              if (!exceedsNodeBudget(uIntegrand, 220)) {
                final uRes = antiDerivative(
                  uIntegrand,
                  uName,
                  assumptions: assumptions,
                  depth: 1,
                );
                if (!hasUnevaluatedIntegral(uRes, uName)) {
                  final invQ = FractionNumber(Integer.one, Integer(q));
                  final backSub = (Pow(fb.base, invQ) * Pow(fa.base, -invQ))
                      .simplify(assumptions: assumptions);
                  return uRes
                      .substitute(uName, backSub)
                      .simplify(assumptions: assumptions);
                }
              }
            }
          }
        }
      }
    }
  }
  final n = u1Item.exp;
  final p = u2Item.exp;
  final numFactor =
      (scale *
              Pow(u0Item.base, mPlus1) *
              Pow(u1Item.base, n) *
              Pow(u2Item.base, p))
          .simplify(assumptions: assumptions);
  final denFactor =
      (u0Item.b * mPlus1 * Pow(oneMinusArgs[0], n) * Pow(oneMinusArgs[1], p))
          .simplify(assumptions: assumptions);
  return (numFactor *
          AppellF1(
            mPlus1,
            (-n).simplify(assumptions: assumptions),
            (-p).simplify(assumptions: assumptions),
            (mPlus1 + IntegerNumber.one).simplify(assumptions: assumptions),
            args[0],
            args[1],
          ) /
          denFactor)
      .simplify(assumptions: assumptions);
}
