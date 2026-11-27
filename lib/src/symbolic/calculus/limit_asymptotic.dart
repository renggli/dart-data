import '../algebra/expand.dart';
import '../algebra/helpers.dart';
import '../algebra/rational.dart';
import '../algebra/simplify.dart';
import '../assumptions.dart';
import '../ast.dart';
import '../compiler.dart';
import '../functions/fn.dart';
import '../oracle/sign.dart';
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
      } on UnsupportedError {
        allResolved = false;
        break;
      } on ArgumentError {
        allResolved = false;
        break;
      } on StateError {
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
    case Call(id: FunctionId.factorial, args: [final inner])
        when inner.dependsOn(variable):
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
        return Pow.of(
              IntegerNumber.two * Constant.pi * rewrittenInner,
              FractionNumber.half,
            ) *
            _stirlingPower(rewrittenInner) *
            Pow.of(
              Constant.e,
              IntegerNumber.one / (IntegerNumber.of(12) * rewrittenInner),
            );
      }
      return Fn.factorial(rewrittenInner);
    case Call(id: FunctionId.gamma, args: [final inner])
        when inner.dependsOn(variable):
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
        return Pow.of(
              (IntegerNumber.two * Constant.pi) / rewrittenInner,
              FractionNumber.half,
            ) *
            _stirlingPower(rewrittenInner) *
            Pow.of(
              Constant.e,
              IntegerNumber.one / (IntegerNumber.of(12) * rewrittenInner),
            );
      }
      return Fn.gamma(rewrittenInner);
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
    final rest = factors.length == 2 ? factors[1] : Mul.of(factors.sublist(1));
    return Pow.of(c, u) * Pow.of(rest / Constant.e, u);
  }
  return Pow.of(u / Constant.e, u);
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
            dom.coeff is RationalNumber &&
            (base.sign > 0 || dom.coeff is IntegerNumber)) {
          numericPowers.add((base, dom.coeff as RationalNumber, dom.remainder));
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
          remFactors.add(Pow.of(base, rem).simplify(assumptions: assumptions));
        }
      }

      final combinedPow = combinedBase == IntegerNumber.one
          ? IntegerNumber.one
          : Pow.of(
              combinedBase,
              Variable(variable),
            ).simplify(assumptions: assumptions);

      return Mul.of([...otherFactors, ...remFactors, combinedPow])
          .simplify(assumptions: assumptions);
    }
  }
  return identical(mapped, expr)
      ? mapped
      : mapped.simplify(assumptions: assumptions);
}

Expr resolveAsymptoticAbsAndPiecewise(Expr expr, String variable) {
  if (!expr.dependsOn(variable)) return expr;
  final mapped = expr.mapChildren(
    (c) => resolveAsymptoticAbsAndPiecewise(c, variable),
  );
  if (mapped case Call(id: FunctionId.abs, args: [final inner])) {
    final sign = asymptoticSignAtInfinity(inner, variable);
    if (sign > 0) return inner;
    if (sign < 0) return (-inner).simplify();
    return mapped;
  }
  if (mapped case Piecewise(:final branches, :final otherwise)) {
    var undecided = false;
    for (final (:relation, :expr) in branches) {
      final status = _evalRelationAtPosInf(relation, variable);
      if (status == null) {
        undecided = true;
        break;
      }
      if (status) return expr;
    }
    if (!undecided && otherwise != null) {
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

bool? _evalRelationAtPosInf(Relational relation, String variable) {
  final diff = (relation.left - relation.right).simplify();
  final sign = asymptoticSignAtInfinity(diff, variable);
  if (sign != 0) {
    return switch (relation.op) {
      RelOp.greaterThan || RelOp.greaterEqual => sign > 0,
      RelOp.lessThan || RelOp.lessEqual => sign < 0,
      RelOp.equal => false,
      RelOp.notEqual => true,
    };
  }
  if (diff is Number && diff.isZero) {
    return switch (relation.op) {
      RelOp.greaterEqual || RelOp.lessEqual || RelOp.equal => true,
      RelOp.greaterThan || RelOp.lessThan || RelOp.notEqual => false,
    };
  }
  if (relation.freeVariables.difference({variable}).isNotEmpty) {
    return null;
  }
  bool? agreed;
  for (final sample in const [1e9, 1e15, 1e30]) {
    try {
      final v = relation.evaluate({variable: sample});
      if (v.isNaN) return null;
      final res = v == 1.0;
      if (agreed == null) {
        agreed = res;
      } else if (agreed != res) {
        return null;
      }
    } on UnsupportedError {
      return null;
    } on ArgumentError {
      return null;
    } on StateError {
      return null;
    }
  }
  return agreed;
}

bool isBoundedFactorAtInfinity(Expr expr, String variable) {
  final realVar = Assumptions(domains: {variable: VariableDomain.real});
  return switch (expr) {
    _ when !expr.dependsOn(variable) => isWellDefinedFinite(expr),
    Call(id: FunctionId.sin || FunctionId.cos, args: [final inner]) =>
      isProvenReal(inner, realVar),
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
      } on UnsupportedError {
        // Ignore
      } on ArgumentError {
        // Ignore
      } on StateError {
        // Ignore
      }
      return false;
    }(),
    _ => false,
  };
}

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
          : Mul.of(polyFactors).simplify(assumptions: assumptions);
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
        : Add.of(coeffs).simplify();
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
      _ => Mul.of(coeffFactors).simplify(),
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
    Call(id: FunctionId.sinh, args: [final u]) =>
      (FractionNumber.half *
              (Pow.of(Constant.e, u) -
                  Pow.of(Constant.e, (-u).simplify(assumptions: assumptions))))
          .simplify(assumptions: assumptions),
    Call(id: FunctionId.cosh, args: [final u]) =>
      (FractionNumber.half *
              (Pow.of(Constant.e, u) +
                  Pow.of(Constant.e, (-u).simplify(assumptions: assumptions))))
          .simplify(assumptions: assumptions),
    Call(id: FunctionId.tanh, args: [final u]) => () {
      final ePos = Pow.of(Constant.e, u);
      final eNeg = Pow.of(Constant.e, (-u).simplify(assumptions: assumptions));
      return ((ePos - eNeg) / (ePos + eNeg)).simplify(assumptions: assumptions);
    }(),
    Call(id: FunctionId.asinh, args: [final u]) => Fn.ln(
      u +
          Pow.of(
            Pow.of(u, IntegerNumber.two) + IntegerNumber.one,
            FractionNumber.half,
          ),
    ).simplify(assumptions: assumptions),
    Call(id: FunctionId.acosh, args: [final u]) => Fn.ln(
      u +
          Pow.of(u - IntegerNumber.one, FractionNumber.half) *
              Pow.of(u + IntegerNumber.one, FractionNumber.half),
    ).simplify(assumptions: assumptions),
    Call(id: FunctionId.atanh, args: [final u]) =>
      (FractionNumber.half *
              Fn.ln((IntegerNumber.one + u) / (IntegerNumber.one - u)))
          .simplify(assumptions: assumptions),
    _ =>
      identical(mapped, expr)
          ? mapped
          : mapped.simplify(assumptions: assumptions),
  };
}

bool containsLogOfVariable(Expr expr, String variable) => expr.anyNode(
  (e) => e is Call && e.id == FunctionId.ln && e.args[0].dependsOn(variable),
);

bool containsUnboundedOscillation(Expr expr, String variable) =>
    expr.anyNode((e) {
      if (e
          case Call(
            id: FunctionId.sin || FunctionId.cos || FunctionId.tan,
            args: [final inner],
          )
          when inner.dependsOn(variable)) {
        try {
          final lim = computeLimit(
            inner,
            variable,
            Constant.infinity,
            assumptions: Assumptions.none,
          );
          return isPositiveInfinity(lim) || isNegativeInfinity(lim);
        } on UnsupportedError {
          return true;
        } on ArgumentError {
          return true;
        } on StateError {
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
    _ => Mul.of(nonOscNum),
  };
  final denPart = switch (denFactors) {
    [] => IntegerNumber.one,
    [final single] => single,
    _ => Mul.of(denFactors),
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
  } on UnsupportedError {
    // Ignore
  } on ArgumentError {
    // Ignore
  } on StateError {
    // Ignore
  }
  return null;
}

bool _isBoundedOscillator(Expr expr, String variable) => switch (expr) {
  Call(id: FunctionId.sin || FunctionId.cos) => containsUnboundedOscillation(
    expr,
    variable,
  ),
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
  final realVar = Assumptions(domains: {variable: VariableDomain.real});
  return switch (expr) {
    Call(
      id: FunctionId.sin ||
          FunctionId.cos ||
          FunctionId.tanh ||
          FunctionId.atan,
      args: [final inner],
    ) =>
      isProvenReal(inner, realVar),
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
          : Mul.of(varFactors).simplify(assumptions: assumptions);
      final varLim = tryInfiniteLimit(varExpr, variable, assumptions);
      if (varLim == null) return null;
      final constExpr = constFactors.length == 1
          ? constFactors.first
          : Mul.of(constFactors).simplify(assumptions: assumptions);
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
  return Add.of(limits).simplify(assumptions: assumptions);
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
            : Mul.of(coeffFactors);
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
  Assumptions assumptions, [
  bool inCancellingContext = false,
]) {
  if (!expr.dependsOn(variable)) return expr;
  final childCancel =
      inCancellingContext ||
      expr is Add ||
      (expr is Call && expr.id == FunctionId.ln);
  final mapped = expr.mapChildren(
    (c) => expandSubdominantExponentials(c, variable, assumptions, childCancel),
  );

  if (mapped case Add(terms: [final t1, final t2]) when !inCancellingContext) {
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
          return (c1 * Pow.of(Constant.e, v) * delta).simplify(
            assumptions: assumptions,
          );
        }
        final bothPoly =
            isPolyMonomialTerm(u, variable) && isPolyMonomialTerm(v, variable);
        if (!bothPoly) {
          if (deltaLim != null && isPositiveInfinity(deltaLim)) {
            return (c1 * Pow.of(Constant.e, u)).simplify(
              assumptions: assumptions,
            );
          }
          if (deltaLim != null && isNegativeInfinity(deltaLim)) {
            return (c2 * Pow.of(Constant.e, v)).simplify(
              assumptions: assumptions,
            );
          }
          if (deltaLim != null && !deltaLim.dependsOn(variable)) {
            return (c1 *
                    Pow.of(Constant.e, v) *
                    (Pow.of(Constant.e, deltaLim) - IntegerNumber.one))
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
        ? Mul.of(newFactors).simplify(assumptions: assumptions)
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

bool isPolyMonomialTerm(Expr term, String variable) {
  if (!term.dependsOn(variable)) return true;
  if (monomialDegree(term, variable) != null) return true;
  if (term case Mul(:final factors)) {
    return factors.every(
      (f) => !f.dependsOn(variable) || monomialDegree(f, variable) != null,
    );
  }
  return false;
}

Expr? combineLogAddTerms(
  List<Expr> terms,
  String variable,
  Assumptions assumptions,
) {
  final logTerms = <({Expr coeff, Expr arg})>[];
  final otherTerms = <Expr>[];
  for (final t in terms) {
    if (t case Call(id: FunctionId.ln, args: [final expr])) {
      logTerms.add((coeff: IntegerNumber.one, arg: expr));
    } else if (t case Mul(:final factors)) {
      Call? lnNode;
      final coeffFactors = <Expr>[];
      var valid = true;
      for (final f in factors) {
        if (f is Call && f.id == FunctionId.ln && lnNode == null) {
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
            : Mul.of(coeffFactors).simplify(assumptions: assumptions);
        logTerms.add((coeff: coeff, arg: lnNode.args[0]));
      } else {
        otherTerms.add(t);
      }
    } else {
      otherTerms.add(t);
    }
  }
  if (logTerms.length < 2) return null;
  var lcmDen = BigInt.one;
  var allRational = true;
  for (final (:coeff, arg: _) in logTerms) {
    if (coeff case RationalNumber(:final denominator)) {
      final den = denominator.abs();
      lcmDen = (lcmDen * den) ~/ lcmDen.gcd(den);
    } else {
      allRational = false;
      break;
    }
  }
  final scale = allRational && lcmDen > BigInt.one
      ? IntegerNumber(lcmDen)
      : IntegerNumber.one;
  var gcdNum = BigInt.zero;
  if (allRational) {
    for (final (:coeff, arg: _) in logTerms) {
      if (coeff case RationalNumber(:final numerator, :final denominator)) {
        final scaledNum = numerator.abs() * (lcmDen ~/ denominator.abs());
        gcdNum = gcdNum == BigInt.zero ? scaledNum : gcdNum.gcd(scaledNum);
      } else {
        gcdNum = BigInt.one;
        break;
      }
    }
  }
  final factorGcd = allRational && gcdNum > BigInt.one
      ? IntegerNumber(gcdNum)
      : IntegerNumber.one;
  final combinedArg = Mul.of([
    for (final (:coeff, :arg) in logTerms)
      Pow.of(
        arg,
        (coeff * scale / factorGcd).simplify(assumptions: assumptions),
      ),
  ]).simplify(assumptions: assumptions);
  final outerCoeff = (factorGcd / scale).simplify(assumptions: assumptions);
  final combinedLog = outerCoeff == IntegerNumber.one
      ? Fn.ln(combinedArg)
      : outerCoeff * Fn.ln(combinedArg);
  if (otherTerms.isEmpty) return combinedLog;
  return Add.of([...otherTerms, combinedLog])
      .simplify(assumptions: assumptions);
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
      Call(id: FunctionId.ln, args: [final expr]) => expr,
      Mul(:final factors) => () {
        Call? found;
        for (final f in factors) {
          if (f is Call && f.id == FunctionId.ln && found == null) {
            found = f;
          } else if (f.dependsOn(variable)) {
            return null;
          }
        }
        return found?.args[0];
      }(),
      _ => null,
    };
    if (innerLn != null &&
        isPurelyAlgebraic(innerLn) &&
        asymptoticSignAtInfinity(innerLn, variable, null, assumptions) > 0) {
      logTerms.add(t);
    } else {
      otherTerms.add(t);
    }
  }
  if (logTerms.isEmpty || otherTerms.isEmpty) return null;
  final otherExpr = otherTerms.length == 1
      ? otherTerms.first
      : Add.of(otherTerms).simplify(assumptions: assumptions);
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
  } on UnsupportedError {
    // Fall through
  } on ArgumentError {
    // Fall through
  } on StateError {
    // Fall through
  }
  return null;
}

bool isPurelyAlgebraic(Expr expr) => switch (expr) {
  Number() || Constant() || Variable() => true,
  Add(:final terms) => terms.every(isPurelyAlgebraic),
  Mul(:final factors) => factors.every(isPurelyAlgebraic),
  Pow(:final base, exponent: RealNumeric()) => isPurelyAlgebraic(base),
  Call(id: FunctionId.abs, args: [final expr]) => isPurelyAlgebraic(expr),
  _ => false,
};
