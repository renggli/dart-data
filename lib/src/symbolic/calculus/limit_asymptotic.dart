import '../algebra/expand.dart';
import '../algebra/helpers.dart';
import '../algebra/rational.dart';
import '../algebra/simplify.dart';
import '../assumptions.dart';
import '../ast.dart';
import '../compiler.dart';
import 'limit.dart';
import 'limit_gruntz.dart';

Expr computeInfiniteLimit(
  Expr expr,
  String variable, {
  required bool isPositive,
  required Assumptions assumptions,
}) {
  if (!isPositive) {
    final posAssumptions = assumptions.copyWith(
      domains: {variable: VariableDomain.positive},
    );
    final reflected = expr
        .substitute(variable, -Variable(variable))
        .simplify(assumptions: posAssumptions);
    return computeInfiniteLimit(
      reflected,
      variable,
      isPositive: true,
      assumptions: posAssumptions,
    );
  }

  final posAssumptions = assumptions.copyWith(
    domains: {variable: VariableDomain.positive},
  );
  final resolved = resolveAsymptoticAbsAndPiecewise(
    expr,
    variable,
  ).simplify(assumptions: posAssumptions);
  if (!resolved.dependsOn(variable)) return resolved;

  final combined = _combineNumericPowers(resolved, variable, posAssumptions);
  if (!combined.dependsOn(variable)) return combined;

  if (combined != resolved) {
    return computeLimit(
      combined,
      variable,
      Constant.infinity,
      assumptions: posAssumptions,
    );
  }

  final ratLim = rationalFunctionLimitAtInfinity(
    combined,
    variable,
    posAssumptions,
  );
  if (ratLim != null) return ratLim.simplify(assumptions: posAssumptions);

  final expPolyLim = exponentialPolynomialLimitAtInfinity(
    combined,
    variable,
    posAssumptions,
  );
  if (expPolyLim != null) {
    return expPolyLim.simplify(assumptions: posAssumptions);
  }

  final logPowerLim = tryLogVsPowerDominance(
    combined,
    variable,
    posAssumptions,
  );
  if (logPowerLim != null) return logPowerLim;

  if (combined case Mul(:final factors)) {
    var hasInf = false;
    var sign = 1;
    var allResolved = true;
    for (final f in factors) {
      try {
        final fLim = computeLimit(
          f,
          variable,
          Constant.infinity,
          assumptions: posAssumptions,
        );
        if (isPositiveInfinity(fLim)) {
          hasInf = true;
        } else if (isNegativeInfinity(fLim)) {
          hasInf = true;
          sign = -sign;
        } else if (fLim is Number && fLim.isZero ||
            fLim.anyNode((n) => n is Limit) ||
            fLim == Constant.undefined) {
          allResolved = false;
          break;
        } else {
          final s = getSign(fLim, posAssumptions);
          if (s == 0) {
            allResolved = false;
            break;
          }
          sign *= s;
        }
      } on Object {
        allResolved = false;
        break;
      }
    }
    if (allResolved && hasInf) {
      return sign > 0 ? Constant.infinity : negInfinity;
    }
  }

  final stirlingRewritten = rewriteStirlingAtPosInf(
    combined,
    variable,
    posAssumptions,
  );
  if (stirlingRewritten != combined) {
    return computeLimit(
      stirlingRewritten,
      variable,
      Constant.infinity,
      assumptions: posAssumptions,
    );
  }

  return gruntzLimit(combined, variable, posAssumptions);
}

Expr rewriteStirlingAtPosInf(
  Expr expr,
  String variable,
  Assumptions assumptions,
) {
  switch (expr) {
    case Factorial(expr: final inner) when inner.dependsOn(variable):
      final rewrittenInner = rewriteStirlingAtPosInf(
        inner,
        variable,
        assumptions,
      );
      final innerLim = computeLimit(
        rewrittenInner,
        variable,
        Constant.infinity,
        assumptions: assumptions,
      );
      if (isPositiveInfinity(innerLim)) {
        return Pow(
              IntegerNumber.two * Constant.pi * rewrittenInner,
              FractionNumber.half,
            ) *
            _stirlingPower(rewrittenInner) *
            Pow(
              Constant.e,
              IntegerNumber.one / (IntegerNumber.of(12) * rewrittenInner),
            );
      }
      return Factorial(rewrittenInner);
    case Gamma(expr: final inner) when inner.dependsOn(variable):
      final rewrittenInner = rewriteStirlingAtPosInf(
        inner,
        variable,
        assumptions,
      );
      final innerLim = computeLimit(
        rewrittenInner,
        variable,
        Constant.infinity,
        assumptions: assumptions,
      );
      if (isPositiveInfinity(innerLim)) {
        return Pow(
              (IntegerNumber.two * Constant.pi) / rewrittenInner,
              FractionNumber.half,
            ) *
            _stirlingPower(rewrittenInner) *
            Pow(
              Constant.e,
              IntegerNumber.one / (IntegerNumber.of(12) * rewrittenInner),
            );
      }
      return Gamma(rewrittenInner);
    default:
      return expr.mapChildren(
        (c) => rewriteStirlingAtPosInf(c, variable, assumptions),
      );
  }
}

Expr _stirlingPower(Expr u) {
  if (u case Mul(:final factors)
      when factors.length >= 2 &&
          factors.first is RationalNumber &&
          !(factors.first as RationalNumber).isNegative &&
          !(factors.first as RationalNumber).isZero) {
    final c = factors.first;
    final rest = factors.length == 2 ? factors[1] : Mul(factors.sublist(1));
    return Pow(c, u) * Pow(rest / Constant.e, u);
  }
  return Pow(u / Constant.e, u);
}

Expr _combineNumericPowers(
  Expr expr,
  String variable,
  Assumptions assumptions,
) {
  final mapped = expr.mapChildren(
    (c) => _combineNumericPowers(c, variable, assumptions),
  );
  if (mapped case Mul(:final factors)) {
    final numericPowers = <(RealNumeric base, RationalNumber k, Expr rem)>[];
    final otherFactors = <Expr>[];

    for (final f in factors) {
      if (f case Pow(:final base, :final exponent)
          when base is RealNumeric &&
              !base.isZero &&
              !base.isOne &&
              exponent.dependsOn(variable)) {
        final dom = extractDominantPolynomialTerm(exponent, variable);
        if (dom != null &&
            dom.degree == 1 &&
            (base.sign > 0 || dom.coeff.denominator == 1)) {
          numericPowers.add((base, dom.coeff, dom.remainder));
          continue;
        }
      }
      otherFactors.add(f);
    }

    if (numericPowers.isNotEmpty) {
      Expr combinedBase = IntegerNumber.one;
      final remFactors = <Expr>[];

      for (final (base, k, rem) in numericPowers) {
        final powered = base.pow(k);
        combinedBase = (combinedBase * powered).simplify(
          assumptions: assumptions,
        );
        if (rem != IntegerNumber.zero) {
          remFactors.add(Pow(base, rem).simplify(assumptions: assumptions));
        }
      }

      final combinedPow = combinedBase == IntegerNumber.one
          ? IntegerNumber.one
          : Pow(
              combinedBase,
              Variable(variable),
            ).simplify(assumptions: assumptions);

      return Mul([...otherFactors, ...remFactors, combinedPow])
          .simplify(assumptions: assumptions);
    }
  }
  return mapped.simplify(assumptions: assumptions);
}

Expr resolveAsymptoticAbsAndPiecewise(Expr expr, String variable) {
  if (!expr.dependsOn(variable)) return expr;
  final mapped = expr.mapChildren(
    (c) => resolveAsymptoticAbsAndPiecewise(c, variable),
  );
  if (mapped case Abs(expr: final inner)) {
    final sign = asymptoticSignAtInfinity(inner, variable);
    if (sign > 0) return inner;
    if (sign < 0) return (-inner).simplify();
    return mapped;
  }
  if (mapped case Piecewise(:final branches, :final otherwise)) {
    for (final (:relation, :expr) in branches) {
      try {
        if (relation.evaluate({variable: 1e9}) == 1.0) {
          return expr;
        }
      } on Object {
        // Ignore
      }
    }
    if (otherwise != null) {
      return otherwise;
    }
  }
  if (mapped case Mul(:final factors)
      when factors.contains(IntegerNumber.zero)) {
    final nonZero = <Expr>[];
    for (final f in factors) {
      if (f != IntegerNumber.zero) {
        if (f == Constant.infinity ||
            f == negInfinity ||
            f == Constant.undefined) {
          return mapped;
        }
        nonZero.add(f);
      }
    }
    if (nonZero.every((f) => isBoundedFactorAtInfinity(f, variable))) {
      return IntegerNumber.zero;
    }
  }
  return mapped;
}

bool isBoundedFactorAtInfinity(Expr expr, String variable) => switch (expr) {
  _ when !expr.dependsOn(variable) => isWellDefinedFinite(expr),
  Sin() || Cos() => true,
  Pow(base: final RealNumeric b, :final exponent) => () {
    final cmp = b.abs().compareTo(IntegerNumber.one);
    if (cmp == 0) return true;
    try {
      final expLim = computeInfiniteLimit(
        exponent,
        variable,
        isPositive: true,
        assumptions: Assumptions.none,
      );
      if (cmp < 0 && isPositiveInfinity(expLim)) return true;
      if (cmp > 0 && isNegativeInfinity(expLim)) return true;
    } on Object {
      // Ignore
    }
    return false;
  }(),
  _ => false,
};

Expr? rationalFunctionLimitAtInfinity(
  Expr expr,
  String variable,
  Assumptions assumptions,
) {
  Expr? evalQuotient(Expr candidate) {
    final (num, den) = splitNumeratorDenominator(candidate);
    if ((
          polynomialDegreeAndLead(num, variable),
          polynomialDegreeAndLead(den, variable),
        )
        case ((final dP, final cP), (final dQ, final cQ))) {
      if (dP < dQ) return IntegerNumber.zero;
      if (dP == dQ) {
        return (cP / cQ).simplify(assumptions: assumptions);
      }

      final ratio = (cP / cQ).simplify(assumptions: assumptions);
      final sign = getSign(ratio, assumptions);
      if (sign == 0) {
        throw UnsupportedError('Sign of leading coefficient $ratio is unknown');
      }
      return sign > 0 ? Constant.infinity : negInfinity;
    }
    return null;
  }

  final direct = evalQuotient(expr);
  if (direct != null) return direct;
  final combined = expr.together(assumptions: assumptions);
  if (combined != expr) {
    return evalQuotient(combined);
  }
  return null;
}

Expr? exponentialPolynomialLimitAtInfinity(
  Expr expr,
  String variable,
  Assumptions assumptions,
) {
  if (expr case Mul(:final factors)) {
    RealNumeric? expBase;
    RealNumeric? expScale;
    final polyFactors = <Expr>[];
    for (final f in factors) {
      if (expBase == null) {
        if (f case Pow(:final RealNumeric base, :final exponent)
            when !base.isZero) {
          final scale = switch (exponent) {
            Variable(:final name) when name == variable => IntegerNumber.one,
            Mul(factors: [final RealNumeric c, Variable(:final name)]) ||
            Mul(
              factors: [Variable(:final name), final RealNumeric c],
            ) when name == variable && !c.isZero => c,
            _ => null,
          };
          if (scale != null) {
            expBase = base;
            expScale = scale;
            continue;
          }
        }
      }
      polyFactors.add(f);
    }
    if (expBase != null && expScale != null) {
      final poly = polyFactors.isEmpty
          ? IntegerNumber.one
          : Mul(polyFactors).simplify(assumptions: assumptions);
      final polyDeg = polynomialDegreeAndLead(poly, variable);
      if (polyDeg != null) {
        final (_, lead) = polyDeg;
        final cmpOne =
            expBase.abs().compareTo(IntegerNumber.one) * expScale.sign;
        if (cmpOne < 0) {
          return IntegerNumber.zero;
        }
        if (cmpOne > 0 && expBase.sign > 0) {
          final sign = getSign(lead, assumptions);
          if (sign == 0) {
            throw UnsupportedError(
              'Sign of leading coefficient $lead is unknown',
            );
          }
          return sign > 0 ? Constant.infinity : negInfinity;
        }
        if (cmpOne > 0 && expBase.sign < 0) {
          throw UnsupportedError('Limit does not exist due to oscillation');
        }
      }
    }
  }
  return null;
}

(int, Expr)? polynomialDegreeAndLead(Expr expr, String variable) {
  final expanded = expr.expand().simplify();
  if (!expanded.dependsOn(variable)) {
    return (0, expanded);
  }

  final terms = expanded is Add ? expanded.terms : [expanded];
  final byDegree = <int, List<Expr>>{};

  for (final term in terms) {
    final parsed = _splitMonomialTerm(term, variable);
    if (parsed == null) return null;
    final (:degree, :coeff) = parsed;
    (byDegree[degree] ??= <Expr>[]).add(coeff);
  }

  final degrees = byDegree.keys.toList()..sort((a, b) => b.compareTo(a));
  for (final deg in degrees) {
    final coeffs = byDegree[deg]!;
    final sum = coeffs.length == 1
        ? coeffs.first.simplify()
        : Add(coeffs).simplify();
    if (sum != IntegerNumber.zero) {
      return (deg, sum);
    }
  }

  return (0, IntegerNumber.zero);
}

({int degree, Expr coeff})? _splitMonomialTerm(Expr term, String variable) {
  if (!term.dependsOn(variable)) {
    return (degree: 0, coeff: term);
  }
  if (monomialDegree(term, variable) case final deg?) {
    return (degree: deg, coeff: IntegerNumber.one);
  }
  if (term case Mul(:final factors)) {
    var degree = 0;
    final coeffFactors = <Expr>[];
    for (final factor in factors) {
      if (!factor.dependsOn(variable)) {
        coeffFactors.add(factor);
      } else if (monomialDegree(factor, variable) case final deg?) {
        degree += deg;
      } else {
        return null;
      }
    }
    final coeff = switch (coeffFactors) {
      [] => IntegerNumber.one,
      [final single] => single,
      _ => Mul(coeffFactors).simplify(),
    };
    return (degree: degree, coeff: coeff);
  }
  return null;
}

int? monomialDegree(Expr base, String variable) => switch (base) {
  Variable(:final name) when name == variable => 1,
  Pow(base: Variable(:final name), exponent: IntegerNumber(:final asInt?))
      when name == variable && asInt >= 0 =>
    asInt,
  _ when !base.dependsOn(variable) => 0,
  _ => null,
};

Expr rewriteHyperbolicsToExp(Expr expr, Assumptions assumptions) {
  final mapped = expr.mapChildren(
    (c) => rewriteHyperbolicsToExp(c, assumptions),
  );
  return switch (mapped) {
    Sinh(expr: final u) =>
      (FractionNumber.half *
              (Pow(Constant.e, u) -
                  Pow(Constant.e, (-u).simplify(assumptions: assumptions))))
          .simplify(assumptions: assumptions),
    Cosh(expr: final u) =>
      (FractionNumber.half *
              (Pow(Constant.e, u) +
                  Pow(Constant.e, (-u).simplify(assumptions: assumptions))))
          .simplify(assumptions: assumptions),
    Tanh(expr: final u) => () {
      final ePos = Pow(Constant.e, u);
      final eNeg = Pow(Constant.e, (-u).simplify(assumptions: assumptions));
      return ((ePos - eNeg) / (ePos + eNeg)).simplify(assumptions: assumptions);
    }(),
    Asinh(expr: final u) => Ln(
      u +
          Pow(
            Pow(u, IntegerNumber.two) + IntegerNumber.one,
            FractionNumber.half,
          ),
    ).simplify(assumptions: assumptions),
    Acosh(expr: final u) => Ln(
      u +
          Pow(u - IntegerNumber.one, FractionNumber.half) *
              Pow(u + IntegerNumber.one, FractionNumber.half),
    ).simplify(assumptions: assumptions),
    Atanh(expr: final u) =>
      (FractionNumber.half *
              Ln((IntegerNumber.one + u) / (IntegerNumber.one - u)))
          .simplify(assumptions: assumptions),
    _ => mapped.simplify(assumptions: assumptions),
  };
}

bool containsLogOfVariable(Expr expr, String variable) =>
    expr.anyNode((e) => e is Ln && e.expr.dependsOn(variable));

bool containsUnboundedOscillation(Expr expr, String variable) =>
    expr.anyNode((e) {
      if (e
          case Sin(expr: final inner) ||
              Cos(expr: final inner) ||
              Tan(expr: final inner)
          when inner.dependsOn(variable)) {
        try {
          final lim = computeLimit(
            inner,
            variable,
            Constant.infinity,
            assumptions: Assumptions.none,
          );
          return isPositiveInfinity(lim) || isNegativeInfinity(lim);
        } on Object {
          return true;
        }
      }
      return false;
    });

Expr? trySqueezeBoundedOscillation(Expr expr, String variable) {
  final (numExpr, denExpr) = splitNumeratorDenominator(expr);
  if (denExpr == IntegerNumber.one && expr is! Mul) return null;

  final numFactors = numExpr is Mul ? numExpr.factors : <Expr>[numExpr];
  final denFactors = denExpr is Mul
      ? denExpr.factors
      : (denExpr == IntegerNumber.one ? <Expr>[] : <Expr>[denExpr]);

  final nonOscNum = <Expr>[];
  var hasOsc = false;
  for (final f in numFactors) {
    if (_isBoundedOscillator(f, variable)) {
      hasOsc = true;
    } else {
      nonOscNum.add(f);
    }
  }
  if (!hasOsc) return null;

  for (final f in denFactors) {
    if (containsUnboundedOscillation(f, variable)) return null;
  }

  final numPart = switch (nonOscNum) {
    [] => IntegerNumber.one,
    [final single] => single,
    _ => Mul(nonOscNum),
  };
  final denPart = switch (denFactors) {
    [] => IntegerNumber.one,
    [final single] => single,
    _ => Mul(denFactors),
  };

  final envelope = (numPart / denPart).simplify();
  try {
    final envLim = computeLimit(
      envelope,
      variable,
      Constant.infinity,
      assumptions: Assumptions.none,
    );
    if (envLim is Number && envLim.isZero) {
      return IntegerNumber.zero;
    }
  } on Object {
    // Ignore
  }
  return null;
}

bool _isBoundedOscillator(Expr expr, String variable) => switch (expr) {
  Sin() || Cos() => containsUnboundedOscillation(expr, variable),
  Pow(:final base, exponent: final RealNumeric exp)
      when !exp.isNegative && !exp.isZero =>
    _isBoundedOscillator(base, variable),
  Add(:final terms) =>
    terms.any((t) => _isBoundedOscillator(t, variable)) &&
        terms.every((t) => _isBoundedAtInfinity(t, variable)),
  Mul(:final factors) =>
    factors.any((f) => _isBoundedOscillator(f, variable)) &&
        factors.every((f) => _isBoundedAtInfinity(f, variable)),
  _ => false,
};

bool _isBoundedAtInfinity(Expr expr, String variable) {
  if (!expr.dependsOn(variable)) return true;
  return switch (expr) {
    Sin() || Cos() || Atan() || Tanh() => true,
    Add(:final terms) => terms.every((t) => _isBoundedAtInfinity(t, variable)),
    Mul(:final factors) => factors.every(
      (f) => _isBoundedAtInfinity(f, variable),
    ),
    Pow(:final base, exponent: final RealNumeric exp) when !exp.isNegative =>
      _isBoundedAtInfinity(base, variable),
    _ => false,
  };
}

Expr? tryInfiniteLimit(Expr expr, String variable, Assumptions assumptions) {
  if (expr case Mul(:final factors)) {
    final constFactors = <Expr>[];
    final varFactors = <Expr>[];
    for (final f in factors) {
      if (f.dependsOn(variable)) {
        varFactors.add(f);
      } else {
        constFactors.add(f);
      }
    }
    if (constFactors.isNotEmpty && varFactors.isNotEmpty) {
      final varExpr = varFactors.length == 1
          ? varFactors.first
          : Mul(varFactors).simplify(assumptions: assumptions);
      final varLim = tryInfiniteLimit(varExpr, variable, assumptions);
      if (varLim == null) return null;
      final constExpr = constFactors.length == 1
          ? constFactors.first
          : Mul(constFactors).simplify(assumptions: assumptions);
      final prod = (constExpr * varLim).simplify(assumptions: assumptions);
      return prod == Constant.undefined ? null : prod;
    }
  }
  try {
    return computeLimit(
      expr,
      variable,
      Constant.infinity,
      assumptions: assumptions,
    );
  } on Object {
    return null;
  }
}

Expr? tryFiniteAddLimit(
  List<Expr> terms,
  String variable,
  Assumptions assumptions,
) {
  final limits = <Expr>[];
  for (final term in terms) {
    final lim = tryInfiniteLimit(term, variable, assumptions);
    if (lim == null ||
        lim == Constant.undefined ||
        lim.anyNode((n) => n is Limit) ||
        isPositiveInfinity(lim) ||
        isNegativeInfinity(lim)) {
      return null;
    }
    limits.add(lim);
  }
  return Add(limits).simplify(assumptions: assumptions);
}

(Expr coeff, Expr exponent)? _matchScaledExp(Expr term, String variable) {
  switch (term) {
    case Pow(base: Constant.e, :final exponent):
      return (IntegerNumber.one, exponent);
    case Mul(:final factors):
      final coeffFactors = <Expr>[];
      Expr? expArg;
      for (final f in factors) {
        if (expArg == null && f is Pow && f.base == Constant.e) {
          expArg = f.exponent;
        } else if (!f.dependsOn(variable)) {
          coeffFactors.add(f);
        } else {
          return null;
        }
      }
      if (expArg != null) {
        final coeff = coeffFactors.isEmpty
            ? IntegerNumber.one
            : coeffFactors.length == 1
            ? coeffFactors.first
            : Mul(coeffFactors, isSimplified: true);
        return (coeff, expArg);
      }
      return null;
    default:
      return null;
  }
}

Expr expandSubdominantExponentials(
  Expr expr,
  String variable,
  Assumptions assumptions,
) {
  if (!expr.dependsOn(variable)) return expr;
  final mapped = expr.mapChildren(
    (c) => expandSubdominantExponentials(c, variable, assumptions),
  );

  if (mapped case Add(terms: [final t1, final t2])) {
    final m1 = _matchScaledExp(t1, variable);
    final m2 = _matchScaledExp(t2, variable);
    if (m1 != null && m2 != null) {
      final (c1, u) = m1;
      final (c2, v) = m2;
      final sumCoeff = (c1 + c2).simplify(assumptions: assumptions);
      if (sumCoeff is Number && sumCoeff.isZero) {
        final delta = (u - v).simplify(assumptions: assumptions);
        if (delta is Number && delta.isZero) return IntegerNumber.zero;
        final deltaLim = tryInfiniteLimit(delta, variable, assumptions);
        if (deltaLim == IntegerNumber.zero) {
          return (c1 * Pow(Constant.e, v) * delta).simplify(
            assumptions: assumptions,
          );
        }
        final bothPoly =
            _isPolyMonomialTerm(u, variable) &&
            _isPolyMonomialTerm(v, variable);
        if (!bothPoly) {
          if (deltaLim != null && isPositiveInfinity(deltaLim)) {
            return (c1 * Pow(Constant.e, u)).simplify(assumptions: assumptions);
          }
          if (deltaLim != null && isNegativeInfinity(deltaLim)) {
            return (c2 * Pow(Constant.e, v)).simplify(assumptions: assumptions);
          }
          if (deltaLim != null && !deltaLim.dependsOn(variable)) {
            return (c1 *
                    Pow(Constant.e, v) *
                    (Pow(Constant.e, deltaLim) - IntegerNumber.one))
                .simplify(assumptions: assumptions);
          }
        }
      }
    }
  }

  return mapped;
}

Expr simplifyMulFiniteExponentials(
  Expr expr,
  String variable,
  Assumptions assumptions,
) {
  if (expr case Mul(:final factors)) {
    final flat = <Expr>[];
    void collect(Expr e) {
      if (e is Mul) {
        for (final sub in e.factors) {
          collect(sub);
        }
      } else {
        flat.add(e);
      }
    }

    for (final f in factors) {
      collect(f);
    }

    final newFactors = <Expr>[];
    var changed = flat.length != factors.length;
    for (final f in flat) {
      if (f is Pow && f.base == Constant.e) {
        final lim = tryInfiniteLimit(f, variable, assumptions);
        if (lim != null &&
            lim != Constant.undefined &&
            !lim.anyNode((n) => n is Limit) &&
            !isPositiveInfinity(lim) &&
            !isNegativeInfinity(lim) &&
            !(lim is Number && lim.isZero)) {
          newFactors.add(lim);
          changed = true;
          continue;
        }
      }
      newFactors.add(f);
    }
    var result = changed
        ? Mul(newFactors).simplify(assumptions: assumptions)
        : expr;
    if (result is Mul &&
        result.factors.any(
          (f) => f is Add && f.anyNode((n) => n is Pow && n.base == Constant.e),
        )) {
      result = result.expand().simplify(assumptions: assumptions);
    }
    return result;
  }
  return expr;
}

bool _isPolyMonomialTerm(Expr term, String variable) {
  if (!term.dependsOn(variable)) return true;
  if (monomialDegree(term, variable) != null) return true;
  if (term case Mul(:final factors)) {
    return factors.every(
      (f) => !f.dependsOn(variable) || monomialDegree(f, variable) != null,
    );
  }
  return false;
}

Expr splitPolyExpTerms(Expr expr, String variable, Assumptions assumptions) {
  if (!expr.dependsOn(variable)) return expr;
  if (expr case Pow(base: Constant.e, exponent: Add(:final terms))) {
    final polyTerms = <Expr>[];
    final otherTerms = <Expr>[];
    var hasVarPoly = false;
    for (final t in terms) {
      if (_isPolyMonomialTerm(t, variable)) {
        polyTerms.add(t);
        if (t.dependsOn(variable)) hasVarPoly = true;
      } else {
        otherTerms.add(t);
      }
    }
    if (hasVarPoly && otherTerms.isNotEmpty) {
      final polyExp = polyTerms.length == 1
          ? polyTerms.first
          : Add(polyTerms).simplify(assumptions: assumptions);
      final otherExp = otherTerms.length == 1
          ? otherTerms.first
          : Add(otherTerms).simplify(assumptions: assumptions);
      return Mul([
        Pow(Constant.e, polyExp, isSimplified: true),
        Pow(Constant.e, otherExp, isSimplified: true),
      ], isSimplified: true);
    }
  }
  return expr.mapChildren((c) => splitPolyExpTerms(c, variable, assumptions));
}

Expr? combineLogAddTerms(
  List<Expr> terms,
  String variable,
  Assumptions assumptions,
) {
  final logTerms = <({Expr coeff, Expr arg})>[];
  final otherTerms = <Expr>[];
  for (final t in terms) {
    if (t case Ln(:final expr)) {
      logTerms.add((coeff: IntegerNumber.one, arg: expr));
    } else if (t case Mul(:final factors)) {
      Ln? lnNode;
      final coeffFactors = <Expr>[];
      var valid = true;
      for (final f in factors) {
        if (f is Ln && lnNode == null) {
          lnNode = f;
        } else if (f is RealNumeric) {
          coeffFactors.add(f);
        } else {
          valid = false;
          break;
        }
      }
      if (valid && lnNode != null && coeffFactors.isNotEmpty) {
        final coeff = coeffFactors.length == 1
            ? coeffFactors.first
            : Mul(coeffFactors).simplify(assumptions: assumptions);
        logTerms.add((coeff: coeff, arg: lnNode.expr));
      } else {
        otherTerms.add(t);
      }
    } else {
      otherTerms.add(t);
    }
  }
  if (logTerms.length < 2) return null;
  var lcmDen = 1;
  var allRational = true;
  for (final (:coeff, arg: _) in logTerms) {
    if (coeff case RationalNumber(:final denominator)
        when denominator.asInt != null) {
      final den = denominator.asInt!.abs();
      lcmDen = (lcmDen * den) ~/ lcmDen.gcd(den);
    } else {
      allRational = false;
      break;
    }
  }
  final scale = allRational && lcmDen > 1
      ? IntegerNumber.of(lcmDen)
      : IntegerNumber.one;
  var gcdNum = 0;
  if (allRational) {
    for (final (:coeff, arg: _) in logTerms) {
      if (coeff case RationalNumber(:final numerator, :final denominator)
          when numerator.asInt != null && denominator.asInt != null) {
        final scaledNum =
            numerator.asInt!.abs() * (lcmDen ~/ denominator.asInt!.abs());
        gcdNum = gcdNum == 0 ? scaledNum : gcdNum.gcd(scaledNum);
      } else {
        gcdNum = 1;
        break;
      }
    }
  }
  final factorGcd = allRational && gcdNum > 1
      ? IntegerNumber.of(gcdNum)
      : IntegerNumber.one;
  final combinedArg = Mul([
    for (final (:coeff, :arg) in logTerms)
      Pow(arg, (coeff * scale / factorGcd).simplify(assumptions: assumptions)),
  ]).simplify(assumptions: assumptions);
  final outerCoeff = (factorGcd / scale).simplify(assumptions: assumptions);
  final combinedLog = outerCoeff == IntegerNumber.one
      ? Ln(combinedArg)
      : outerCoeff * Ln(combinedArg);
  if (otherTerms.isEmpty) return combinedLog;
  return Add([...otherTerms, combinedLog]).simplify(assumptions: assumptions);
}

Expr? tryLogVsPowerDominance(
  Expr expr,
  String variable,
  Assumptions assumptions,
) {
  if (expr is! Add) return null;
  final logTerms = <Expr>[];
  final otherTerms = <Expr>[];
  for (final t in expr.terms) {
    if (!t.dependsOn(variable)) {
      otherTerms.add(t);
      continue;
    }
    final innerLn = switch (t) {
      Ln(:final expr) => expr,
      Mul(:final factors) => () {
        Ln? found;
        for (final f in factors) {
          if (f is Ln && found == null) {
            found = f;
          } else if (f.dependsOn(variable)) {
            return null;
          }
        }
        return found?.expr;
      }(),
      _ => null,
    };
    if (innerLn != null && isPurelyAlgebraic(innerLn)) {
      logTerms.add(t);
    } else {
      otherTerms.add(t);
    }
  }
  if (logTerms.isEmpty || otherTerms.isEmpty) return null;
  final otherExpr = otherTerms.length == 1
      ? otherTerms.first
      : Add(otherTerms).simplify(assumptions: assumptions);
  if (!otherExpr.dependsOn(variable) || !isPurelyAlgebraic(otherExpr)) {
    return null;
  }
  try {
    final otherLim = computeLimit(
      otherExpr,
      variable,
      Constant.infinity,
      assumptions: assumptions,
    );
    if (isPositiveInfinity(otherLim)) return Constant.infinity;
    if (isNegativeInfinity(otherLim)) return negInfinity;
  } on Object {
    // Fall through
  }
  return null;
}

bool isPurelyAlgebraic(Expr expr) => switch (expr) {
  Number() || Constant() || Variable() => true,
  Add(:final terms) => terms.every(isPurelyAlgebraic),
  Mul(:final factors) => factors.every(isPurelyAlgebraic),
  Pow(:final base, exponent: RealNumeric()) => isPurelyAlgebraic(base),
  Abs(:final expr) => isPurelyAlgebraic(expr),
  _ => false,
};
