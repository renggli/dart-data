import '../../algebra/expand.dart';
import '../../algebra/helpers.dart';
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

  final uName = '_u$depth';
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

  // Case 2: sqrt(Ax^2 + Bx + C) / x^k (k >= 1)
  if (left case Pow(base: final quad, exponent: final exp)
      when halfIntExponent(exp) == 1) {
    final coeffs = extractPolynomialCoefficients(quad, variable);
    if (coeffs != null && maxPolynomialDegree(coeffs) == 2) {
      int? k;
      if (right is Variable && right.name == variable) {
        k = 1;
      } else if (right
          case Pow(
            base: Variable(:final name),
            exponent: IntegerNumber(asInt: final p?),
          )
          when name == variable && p >= 1 && p <= 4) {
        k = p;
      }
      if (k != null) {
        final a = coeffs[2] ?? IntegerNumber.zero;
        final b = coeffs[1] ?? IntegerNumber.zero;
        final c = coeffs[0] ?? IntegerNumber.zero;
        final xVar = Variable(variable);
        // sqrt(Q)/x^k = A*x^(2-k)/sqrt(Q) + B*x^(1-k)/sqrt(Q) + C/(x^k * sqrt(Q))
        final term1 = k == 1
            ? antiDerivative(
                (a * xVar / left).simplify(),
                variable,
                assumptions: Assumptions.none,
              )
            : (k == 2
                  ? antiDerivative(
                      (a / left).simplify(),
                      variable,
                      assumptions: Assumptions.none,
                    )
                  : tryPolynomialOverSqrtQuadratic(
                      a,
                      Pow(xVar, IntegerNumber.of(k - 2)) * left,
                      variable,
                    ));
        final term2 = (b is Number && b.isZero)
            ? IntegerNumber.zero
            : (k == 1
                  ? antiDerivative(
                      (b / left).simplify(),
                      variable,
                      assumptions: Assumptions.none,
                    )
                  : tryPolynomialOverSqrtQuadratic(
                      b,
                      Pow(xVar, IntegerNumber.of(k - 1)) * left,
                      variable,
                    ));
        final term3 = (c is Number && c.isZero)
            ? IntegerNumber.zero
            : tryPolynomialOverSqrtQuadratic(
                c,
                (right * left).simplify(),
                variable,
              );
        if (term1 != null &&
            term2 != null &&
            term3 != null &&
            !hasUnevaluatedIntegral(term1, variable) &&
            !hasUnevaluatedIntegral(term2, variable) &&
            !hasUnevaluatedIntegral(term3, variable)) {
          return (term1 + term2 + term3).simplify();
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
    if (valid && k >= 1 && k <= 8 && rad != null) {
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
        final tInt =
            tryQuadraticRadical(numT, qT, -1, tName, preferLog: true) ??
            antiDerivative(
              (numT / Pow(qT, FractionNumber.half)).simplify(),
              tName,
              assumptions: Assumptions.none,
              depth: 2,
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
  void scan(Expr n) {
    if (targetPow != null || !n.dependsOn(variable)) return;
    if (n case Pow(:final base, :final exponent)) {
      if (fractionalExponent(exponent) case final fq? when fq.q <= 4) {
        final (numB, denB) = splitNumeratorDenominator(base);
        if (numB.matchLinear(variable) != null &&
            denB.dependsOn(variable) &&
            denB.matchLinear(variable) != null) {
          targetPow = n;
          frac = fq;
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
  if (targetPow == null || frac == null) return null;

  final (numB, denB) = splitNumeratorDenominator(targetPow!.base);
  final (:a, :b) = numB.matchLinear(variable)!;
  final (a: c, b: d) = denB.matchLinear(variable)!;
  final det = (a * d - b * c).simplify(assumptions: assumptions);
  if (det is Number && det.isZero) {
    final ratio = (a / c).simplify(assumptions: assumptions);
    return (Pow(ratio, FractionNumber(Integer(frac!.p), Integer(frac!.q))) *
            Variable(variable))
        .simplify(assumptions: assumptions);
  }
  final n = frac!.q;
  if (isIntegrationBudgetExhausted() || exceedsNodeBudget(expr, 150) || n > 4) {
    return null;
  }

  const uName = '_fl';
  const uVar = Variable(uName);
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

  final uName = '_u$depth';
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
