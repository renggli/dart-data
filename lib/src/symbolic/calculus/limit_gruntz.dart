import '../algebra/expand.dart';
import '../algebra/helpers.dart';
import '../algebra/simplify.dart';
import '../algebra/term_accumulator.dart';
import '../assumptions.dart';
import '../ast.dart';
import 'limit.dart';
import 'limit_asymptotic.dart';
import 'series.dart';

Expr gruntzLimit(Expr expr, String variable, Assumptions assumptions) {
  if (exceedsNodeBudget(expr, 4000)) {
    return Limit(expr, variable, Constant.infinity);
  }
  var f = rewriteHyperbolicsToExp(
    expr.simplify(assumptions: assumptions),
    assumptions,
  );
  if (!f.dependsOn(variable)) return f;

  if (containsUnboundedOscillation(f, variable)) {
    final squeezed = trySqueezeBoundedOscillation(f, variable);
    if (squeezed != null) return squeezed;
    throw UnsupportedError('Limit does not exist due to oscillation');
  }

  f = _expandLogArguments(f, variable);
  if (exceedsNodeBudget(f, 4000)) {
    return Limit(expr, variable, Constant.infinity);
  }
  final expandedExp = expandSubdominantExponentials(f, variable, assumptions);
  if (expandedExp != f) {
    f = expandedExp;
    if (exceedsNodeBudget(f, 4000)) {
      return Limit(expr, variable, Constant.infinity);
    }
    if (!f.dependsOn(variable)) return f;
    if (f is Pow && f.base == Constant.e) {
      return computeLimit(
        f,
        variable,
        Constant.infinity,
        assumptions: assumptions,
      );
    }
  }
  f = simplifyMulFiniteExponentials(f, variable, assumptions);
  if (!f.dependsOn(variable)) return f;

  if (f case Add(:final terms)) {
    final finiteSum = tryFiniteAddLimit(terms, variable, assumptions);
    if (finiteSum != null) return finiteSum;
  }

  f = splitPolyExpTerms(f, variable, assumptions);

  final expScale = _findDominantExpScale(f, variable);

  if (expScale == null && containsLogOfVariable(f, variable)) {
    final uName = freshLimitVar('_u', f);
    final u = Variable(uName);
    final uAssumptions = assumptions.copyWith(
      domains: {uName: VariableDomain.real},
    );
    final transformed = f
        .substitute(variable, Pow(Constant.e, u))
        .simplify(assumptions: uAssumptions);
    return computeInfiniteLimit(
      transformed,
      uName,
      isPositive: true,
      assumptions: uAssumptions,
    );
  }

  final omegaName = freshLimitVar('_omega', f);
  final omega = Variable(omegaName);

  if (expScale == null) {
    final rewritten = f
        .substitute(variable, IntegerNumber.one / omega)
        .simplify(assumptions: assumptions);

    final (numExpr, denExpr) = splitNumeratorDenominator(rewritten);
    if (denExpr != IntegerNumber.one) {
      for (final ord in const [4, 10]) {
        try {
          final sNum = numExpr.toPowerSeries(
            omegaName,
            point: IntegerNumber.zero,
            order: ord,
          );
          final sDen = denExpr.toPowerSeries(
            omegaName,
            point: IntegerNumber.zero,
            order: ord,
          );
          if ((sNum.leadingTerm, sDen.leadingTerm) case (
            final leadNum?,
            final leadDen?,
          )) {
            final m = leadNum.exponent - leadDen.exponent;
            final cm = (leadNum.coefficient / leadDen.coefficient).simplify(
              assumptions: assumptions,
            );
            if (m > 0) return IntegerNumber.zero;
            if (m == 0) return cm;
            final sign = asymptoticSignAtInfinity(
              cm,
              variable,
              null,
              assumptions,
            );
            if (sign != 0) {
              return sign > 0 ? Constant.infinity : negInfinity;
            }
          }
        } on UnsupportedError {
          break;
        } on ArgumentError {
          break;
        } on StateError {
          break;
        }
      }
    }

    for (final ord in const [4, 10]) {
      try {
        final series = rewritten.toPowerSeries(
          omegaName,
          point: IntegerNumber.zero,
          order: ord,
        );
        final lead = series.leadingTerm;
        if (lead != null) {
          if (lead.exponent > 0) return IntegerNumber.zero;
          if (lead.exponent == 0) {
            return lead.coefficient.simplify(assumptions: assumptions);
          }
          final sign = asymptoticSignAtInfinity(
            lead.coefficient,
            variable,
            null,
            assumptions,
          );
          if (sign == 0) break;
          return sign > 0 ? Constant.infinity : negInfinity;
        }
      } on UnsupportedError {
        break;
      } on ArgumentError {
        break;
      } on StateError {
        break;
      }
    }

    throw UnsupportedError(
      'Limit could not be determined for $expr as $variable -> infinity',
    );
  }

  final rewritten = _rewriteExpInOmega(
    f,
    variable,
    omega,
    expScale.degree,
    expScale.alpha,
  ).simplify(assumptions: assumptions);

  for (final ord in const [4, 10]) {
    try {
      final series = rewritten.toPowerSeries(
        omegaName,
        point: IntegerNumber.zero,
        order: ord,
      );
      final lead = series.leadingTerm;
      if (lead != null) {
        if (lead.exponent > 0) return IntegerNumber.zero;
        if (lead.exponent < 0) {
          final sign = asymptoticSignAtInfinity(
            lead.coefficient,
            variable,
            null,
            assumptions,
          );
          if (sign == 0) break;
          return sign > 0 ? Constant.infinity : negInfinity;
        }
        return computeLimit(
          lead.coefficient,
          variable,
          Constant.infinity,
          assumptions: assumptions,
        );
      }
    } on UnsupportedError {
      break;
    } on ArgumentError {
      break;
    } on StateError {
      break;
    }
  }

  throw UnsupportedError(
    'Limit could not be determined for $expr as $variable -> infinity',
  );
}

Expr _rewriteExpInOmega(
  Expr expr,
  String variable,
  Expr omega,
  int targetDeg,
  RealNumeric alpha,
) {
  if (!expr.dependsOn(variable)) return expr;
  if (expr case Pow(base: Constant.e, :final exponent)) {
    return _rewriteSingleExp(exponent, variable, omega, targetDeg, alpha);
  }
  return expr.mapChildren(
    (c) => _rewriteExpInOmega(c, variable, omega, targetDeg, alpha),
  );
}

Expr _rewriteSingleExp(
  Expr inner,
  String variable,
  Expr omega,
  int targetDeg,
  RealNumeric alpha,
) {
  if (extractDominantPolynomialTerm(inner, variable)
      case (:final degree, :final coeff, :final remainder)
      when degree == targetDeg && !coeff.isZero) {
    int? asInt;
    if (coeff is RationalNumber && alpha is RationalNumber) {
      if (coeff.divRational(alpha) case IntegerNumber(asInt: final k?)) {
        asInt = k;
      }
    } else {
      final ratio = coeff.toDouble() / alpha.toDouble();
      if (ratio.isFinite &&
          ratio == ratio.roundToDouble() &&
          ratio.abs() <= 1e12) {
        asInt = ratio.round();
      }
    }
    if (asInt != null) {
      final omegaPower = switch (asInt) {
        1 => Pow(omega, IntegerNumber.negativeOne),
        -1 => omega,
        _ => Pow(omega, IntegerNumber.of(-asInt)),
      };
      final remRewritten = _rewriteExpInOmega(
        remainder,
        variable,
        omega,
        targetDeg,
        alpha,
      );
      final expRemainder = (remRewritten is Number && remRewritten.isZero)
          ? IntegerNumber.one
          : Pow(Constant.e, remRewritten);
      return (omegaPower * expRemainder).simplify();
    }
  }

  return Pow(
    Constant.e,
    _rewriteExpInOmega(inner, variable, omega, targetDeg, alpha),
  );
}

({int degree, RealNumeric coeff, Expr remainder})?
extractDominantPolynomialTerm(Expr expr, String variable) {
  final expanded = expr.expand().simplify();
  final acc = MonomialAccumulator(assumptions: Assumptions.none);
  acc.add(expanded);

  var maxDeg = 0;
  RealNumeric leadCoeff = IntegerNumber.zero;
  Expr? leadKey;

  for (final entry in acc.terms.entries) {
    final deg = monomialDegree(entry.key, variable);
    if (deg == null) return null;
    if (deg > maxDeg) {
      if (entry.value case final RealNumeric val when !val.isZero) {
        maxDeg = deg;
        leadCoeff = val;
        leadKey = entry.key;
      }
    }
  }

  if (maxDeg == 0 || leadCoeff.isZero || leadKey == null) {
    return null;
  }

  final remainingTerms = <Expr>[];
  for (final entry in acc.terms.entries) {
    if (entry.key == leadKey) continue;
    final term = entry.value.isOne ? entry.key : entry.value * entry.key;
    remainingTerms.add(term);
  }
  if (!acc.constant.isZero) {
    remainingTerms.add(acc.constant);
  }

  if (remainingTerms.isEmpty) {
    return (degree: maxDeg, coeff: leadCoeff, remainder: IntegerNumber.zero);
  }
  return (
    degree: maxDeg,
    coeff: leadCoeff,
    remainder: Add(remainingTerms).simplify(),
  );
}

Expr _expandLogArguments(Expr expr, String variable) {
  final mapped = expr.mapChildren((c) => _expandLogArguments(c, variable));
  if (mapped case Ln(expr: Add(:final terms)) when terms.length >= 2) {
    return _tryFactorLogAdd(terms, variable) ?? mapped;
  }
  return mapped;
}

Expr? _tryFactorLogAdd(List<Expr> terms, String variable) {
  for (var i = 0; i < terms.length; i++) {
    final t = terms[i];
    if (t case Pow(base: Constant.e, :final exponent)
        when exponent.dependsOn(variable)) {
      final dom = extractDominantPolynomialTerm(exponent, variable);
      if (dom != null && dom.coeff.sign > 0) {
        final negU = (-exponent).simplify();
        final restTerms = <Expr>[
          for (var j = 0; j < terms.length; j++)
            if (j != i) terms[j],
        ];
        final rest = restTerms.length == 1
            ? restTerms.first
            : Add(restTerms, isSimplified: true);
        return (exponent + Ln(IntegerNumber.one + rest * Pow(Constant.e, negU)))
            .simplify();
      }
    }
  }
  return null;
}

({int degree, RealNumeric alpha})? _findDominantExpScale(
  Expr expr,
  String variable,
) {
  var maxDeg = 0;
  final coeffsAtMax = <RealNumeric>[];

  void scan(Expr e) {
    if (e case Pow(base: Constant.e, :final exponent)
        when exponent.dependsOn(variable)) {
      final dom = extractDominantPolynomialTerm(exponent, variable);
      if (dom != null && !dom.coeff.isZero) {
        if (dom.degree > maxDeg) {
          maxDeg = dom.degree;
          coeffsAtMax
            ..clear()
            ..add(dom.coeff.abs());
        } else if (dom.degree == maxDeg) {
          coeffsAtMax.add(dom.coeff.abs());
        }
      }
    }
    switch (e) {
      case Add(:final terms):
        for (final t in terms) {
          scan(t);
        }
      case Mul(:final factors):
        for (final f in factors) {
          scan(f);
        }
      case BinaryExpr(:final left, :final right):
        scan(left);
        scan(right);
      case UnaryExpr(:final expr):
        scan(expr);
      case Piecewise(:final branches, :final otherwise):
        for (final (:relation, :expr) in branches) {
          scan(relation);
          scan(expr);
        }
        if (otherwise != null) scan(otherwise);
      case Integral(:final integrand, :final lower, :final upper):
        scan(integrand);
        if (lower != null) scan(lower);
        if (upper != null) scan(upper);
      case Derivative(:final expr, :final point):
        scan(expr);
        if (point != null) scan(point);
      case Limit(:final expr, :final point):
        scan(expr);
        scan(point);
      case Sum(:final expr, :final lower, :final upper) ||
          Product(:final expr, :final lower, :final upper):
        scan(expr);
        scan(lower);
        scan(upper);
      case VariableFunction(:final arguments):
        for (final argument in arguments) {
          scan(argument);
        }
      case EllipticE(:final expr, :final amplitude):
        scan(expr);
        if (amplitude != null) scan(amplitude);
      case EllipticPi(:final characteristic, :final amplitude, :final modulus):
        scan(characteristic);
        scan(amplitude);
        scan(modulus);
      case Zeta(:final expr, :final shift):
        scan(expr);
        if (shift != null) scan(shift);
      case Hypergeometric(:final upper, :final lower, :final argument):
        for (final u in upper) {
          scan(u);
        }
        for (final l in lower) {
          scan(l);
        }
        scan(argument);
      case Min(:final args) ||
          Max(:final args) ||
          Gcd(:final args) ||
          Lcm(:final args) ||
          Tuple(:final args):
        for (final a in args) {
          scan(a);
        }
      case Number() || Constant() || Variable() || OrderTerm():
        break;
    }
  }

  scan(expr);
  if (maxDeg == 0 || coeffsAtMax.isEmpty) return null;

  if (coeffsAtMax.every((c) => c is RationalNumber)) {
    final rats = coeffsAtMax.cast<RationalNumber>();
    var numGcd = rats.first.numerator.abs();
    var denLcm = rats.first.denominator;
    for (var i = 1; i < rats.length; i++) {
      final c = rats[i];
      numGcd = numGcd.gcd(c.numerator.abs());
      final g = denLcm.gcd(c.denominator);
      denLcm = (denLcm ~/ g) * c.denominator;
    }
    return (degree: maxDeg, alpha: RationalNumber.of(numGcd, denLcm));
  }
  return (degree: maxDeg, alpha: coeffsAtMax.first);
}
