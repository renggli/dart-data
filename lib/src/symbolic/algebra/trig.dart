import 'package:more/math.dart';

import '../assumptions.dart';
import '../ast.dart';
import 'expand.dart';
import 'rational.dart';
import 'simplify.dart';
import 'simplify/additive.dart';
import 'simplify/multiplicative.dart';
import 'structural_order.dart';
import 'term_accumulator.dart';

/// Target representation for algebraic and transcendental [TrigRewriteExtension.rewrite].
enum RewriteTarget {
  /// Rewrites trigonometric and hyperbolic functions into exponential form
  /// ($e^{i x}$ and $e^x$).
  exp,

  /// Rewrites complex exponentials ($e^{a + i b}$) into trigonometric form
  /// via Euler's formula $e^{a + i b} = e^a (\cos b + i \sin b)$.
  trig,

  /// Rewrites tangent and hyperbolic tangent into sine/cosine and sinh/cosh
  /// quotients.
  sinCos,
}

/// Trigonometric and hyperbolic rewriting operations on [Expr].
extension TrigRewriteExtension on Expr {
  /// Expands trigonometric and hyperbolic functions of sums and integer
  /// multiples into polynomials in elementary functions of single arguments.
  ///
  /// Applies angle-addition identities ($\sin(a + b)$, $\cos(a + b)$,
  /// $\tan(a + b)$, $\sinh(a + b)$, $\cosh(a + b)$, $\tanh(a + b)$) and
  /// De Moivre multiple-angle expansions ($\sin(n x)$, $\cos(n x)$, etc. for
  /// integer $n$).
  ///
  /// ```dart
  /// final e = Expr.parse('sin(2 * x)');
  /// print(e.expandTrig()); // 2 * cos(x) * sin(x)
  /// ```
  Expr expandTrig({Assumptions assumptions = Assumptions.none}) =>
      _expandTrigExpr(
        simplify(assumptions: assumptions),
        assumptions,
      ).simplify(assumptions: assumptions);

  /// Simplifies trigonometric and hyperbolic expressions using Pythagorean,
  /// quotient ($\tan u = \sin u / \cos u$), double-angle, and product-to-sum
  /// identities.
  ///
  /// ```dart
  /// final e = Expr.parse('2 * sin(x) * cos(x)');
  /// print(e.simplifyTrig()); // sin(2 * x)
  /// ```
  Expr simplifyTrig({Assumptions assumptions = Assumptions.none}) =>
      _simplifyTrigExpr(
        simplify(assumptions: assumptions),
        assumptions,
      ).simplify(assumptions: assumptions);

  /// Rewrites this expression into the specified [target] representation.
  ///
  /// - [RewriteTarget.exp]: Converts `Sin`, `Cos`, `Tan`, `Sinh`, `Cosh`, and
  ///   `Tanh` into exponential expressions.
  /// - [RewriteTarget.trig]: Converts complex exponentials $e^{a + i b}$ into
  ///   $e^a (\cos b + i \sin b)$ via Euler's identity.
  /// - [RewriteTarget.sinCos]: Converts `Tan(u)` to `Sin(u) / Cos(u)` and
  ///   `Tanh(u)` to `Sinh(u) / Cosh(u)`.
  ///
  /// ```dart
  /// final euler = Expr.parse('cos(x) + i * sin(x)');
  /// print(euler.rewrite(RewriteTarget.exp)); // exp(i * x)
  /// ```
  Expr rewrite(
    RewriteTarget target, {
    Assumptions assumptions = Assumptions.none,
  }) => switch (target) {
    RewriteTarget.exp => _rewriteToExp(
      simplify(assumptions: assumptions),
      assumptions,
    ).expand(assumptions: assumptions).simplify(assumptions: assumptions),
    RewriteTarget.trig => _rewriteToTrig(
      simplify(assumptions: assumptions),
      assumptions,
    ).expand(assumptions: assumptions).simplify(assumptions: assumptions),
    RewriteTarget.sinCos => _rewriteToSinCos(
      simplify(assumptions: assumptions),
      assumptions,
    ).simplify(assumptions: assumptions),
  };
}

Expr _expandTrigExpr(Expr expr, Assumptions assumptions) {
  final mapped = expr
      .mapChildren((c) => _expandTrigExpr(c, assumptions))
      .simplify(assumptions: assumptions);
  return switch (mapped) {
    Sin(expr: final arg) => _expandSin(arg, assumptions),
    Cos(expr: final arg) => _expandCos(arg, assumptions),
    Tan(expr: final arg) => _expandTan(arg, assumptions),
    Sinh(expr: final arg) => _expandSinh(arg, assumptions),
    Cosh(expr: final arg) => _expandCosh(arg, assumptions),
    Tanh(expr: final arg) => _expandTanh(arg, assumptions),
    _ => mapped,
  };
}

Expr _expandSin(Expr arg, Assumptions assumptions) {
  if (arg case Add(:final terms) when terms.length >= 2) {
    final first = terms.first;
    final rest = terms.length == 2
        ? terms[1]
        : Add(terms.sublist(1), isSimplified: true);
    final sinA = _expandSin(first, assumptions);
    final cosA = _expandCos(first, assumptions);
    final sinB = _expandSin(rest, assumptions);
    final cosB = _expandCos(rest, assumptions);
    return (sinA * cosB + cosA * sinB)
        .expand(assumptions: assumptions)
        .simplify(assumptions: assumptions);
  }
  if (_extractIntegerMultiple(arg) case (:final n, :final base)
      when n.abs() >= 2 && n.abs() <= 16) {
    final absN = n.abs();
    final expanded = _deMoivreSin(absN, base, assumptions);
    return n < 0 ? (-expanded).simplify(assumptions: assumptions) : expanded;
  }
  return Sin(arg).simplify(assumptions: assumptions);
}

Expr _expandCos(Expr arg, Assumptions assumptions) {
  if (arg case Add(:final terms) when terms.length >= 2) {
    final first = terms.first;
    final rest = terms.length == 2
        ? terms[1]
        : Add(terms.sublist(1), isSimplified: true);
    final sinA = _expandSin(first, assumptions);
    final cosA = _expandCos(first, assumptions);
    final sinB = _expandSin(rest, assumptions);
    final cosB = _expandCos(rest, assumptions);
    return (cosA * cosB - sinA * sinB)
        .expand(assumptions: assumptions)
        .simplify(assumptions: assumptions);
  }
  if (_extractIntegerMultiple(arg) case (:final n, :final base)
      when n.abs() >= 2 && n.abs() <= 16) {
    return _deMoivreCos(n.abs(), base, assumptions);
  }
  return Cos(arg).simplify(assumptions: assumptions);
}

Expr _expandTan(Expr arg, Assumptions assumptions) {
  if (arg case Add(:final terms) when terms.length >= 2) {
    final first = terms.first;
    final rest = terms.length == 2
        ? terms[1]
        : Add(terms.sublist(1), isSimplified: true);
    final tanA = _expandTan(first, assumptions);
    final tanB = _expandTan(rest, assumptions);
    return ((tanA + tanB) / (IntegerNumber.one - tanA * tanB)).simplify(
      assumptions: assumptions,
    );
  }
  if (_extractIntegerMultiple(arg) case (:final n, :final base)
      when n.abs() >= 2 && n.abs() <= 16) {
    final absN = n.abs();
    final expanded = _deMoivreTan(absN, base, assumptions);
    return n < 0 ? (-expanded).simplify(assumptions: assumptions) : expanded;
  }
  return Tan(arg).simplify(assumptions: assumptions);
}

Expr _expandSinh(Expr arg, Assumptions assumptions) {
  if (arg case Add(:final terms) when terms.length >= 2) {
    final first = terms.first;
    final rest = terms.length == 2
        ? terms[1]
        : Add(terms.sublist(1), isSimplified: true);
    final sinhA = _expandSinh(first, assumptions);
    final coshA = _expandCosh(first, assumptions);
    final sinhB = _expandSinh(rest, assumptions);
    final coshB = _expandCosh(rest, assumptions);
    return (sinhA * coshB + coshA * sinhB)
        .expand(assumptions: assumptions)
        .simplify(assumptions: assumptions);
  }
  if (_extractIntegerMultiple(arg) case (:final n, :final base)
      when n.abs() >= 2 && n.abs() <= 16) {
    final absN = n.abs();
    final expanded = _deMoivreSinh(absN, base, assumptions);
    return n < 0 ? (-expanded).simplify(assumptions: assumptions) : expanded;
  }
  return Sinh(arg).simplify(assumptions: assumptions);
}

Expr _expandCosh(Expr arg, Assumptions assumptions) {
  if (arg case Add(:final terms) when terms.length >= 2) {
    final first = terms.first;
    final rest = terms.length == 2
        ? terms[1]
        : Add(terms.sublist(1), isSimplified: true);
    final sinhA = _expandSinh(first, assumptions);
    final coshA = _expandCosh(first, assumptions);
    final sinhB = _expandSinh(rest, assumptions);
    final coshB = _expandCosh(rest, assumptions);
    return (coshA * coshB + sinhA * sinhB)
        .expand(assumptions: assumptions)
        .simplify(assumptions: assumptions);
  }
  if (_extractIntegerMultiple(arg) case (:final n, :final base)
      when n.abs() >= 2 && n.abs() <= 16) {
    return _deMoivreCosh(n.abs(), base, assumptions);
  }
  return Cosh(arg).simplify(assumptions: assumptions);
}

Expr _expandTanh(Expr arg, Assumptions assumptions) {
  if (arg case Add(:final terms) when terms.length >= 2) {
    final first = terms.first;
    final rest = terms.length == 2
        ? terms[1]
        : Add(terms.sublist(1), isSimplified: true);
    final tanhA = _expandTanh(first, assumptions);
    final tanhB = _expandTanh(rest, assumptions);
    return ((tanhA + tanhB) / (IntegerNumber.one + tanhA * tanhB)).simplify(
      assumptions: assumptions,
    );
  }
  if (_extractIntegerMultiple(arg) case (:final n, :final base)
      when n.abs() >= 2 && n.abs() <= 16) {
    final absN = n.abs();
    final expanded = _deMoivreTanh(absN, base, assumptions);
    return n < 0 ? (-expanded).simplify(assumptions: assumptions) : expanded;
  }
  return Tanh(arg).simplify(assumptions: assumptions);
}

({int n, Expr base})? _extractIntegerMultiple(Expr arg) {
  if (arg case Mul(factors: [IntegerNumber(asInt: final k?), ...final rest])
      when rest.isNotEmpty) {
    final base = rest.length == 1
        ? rest.first
        : Mul(rest, isSimplified: arg.isSimplified);
    return (n: k, base: base);
  }
  return null;
}

Expr _deMoivreSin(int n, Expr u, Assumptions assumptions) {
  final sinU = Sin(u).simplify(assumptions: assumptions);
  final cosU = Cos(u).simplify(assumptions: assumptions);
  final terms = <Expr>[];
  for (var k = 1; k <= n; k += 2) {
    final sign = ((k - 1) ~/ 2).isEven ? 1 : -1;
    final coeff = IntegerNumber.of(sign * n.binomial(k));
    final cosPow = n - k == 0
        ? IntegerNumber.one
        : Pow(cosU, IntegerNumber.of(n - k));
    final sinPow = k == 1 ? sinU : Pow(sinU, IntegerNumber.of(k));
    terms.add((coeff * cosPow * sinPow).simplify(assumptions: assumptions));
  }
  return Add(terms)
      .expand(assumptions: assumptions)
      .simplify(assumptions: assumptions);
}

Expr _deMoivreCos(int n, Expr u, Assumptions assumptions) {
  final sinU = Sin(u).simplify(assumptions: assumptions);
  final cosU = Cos(u).simplify(assumptions: assumptions);
  final terms = <Expr>[];
  for (var k = 0; k <= n; k += 2) {
    final sign = (k ~/ 2).isEven ? 1 : -1;
    final coeff = IntegerNumber.of(sign * n.binomial(k));
    final cosPow = n - k == 0
        ? IntegerNumber.one
        : Pow(cosU, IntegerNumber.of(n - k));
    final sinPow = k == 0 ? IntegerNumber.one : Pow(sinU, IntegerNumber.of(k));
    terms.add((coeff * cosPow * sinPow).simplify(assumptions: assumptions));
  }
  return Add(terms)
      .expand(assumptions: assumptions)
      .simplify(assumptions: assumptions);
}

Expr _deMoivreTan(int n, Expr u, Assumptions assumptions) {
  final tanU = Tan(u).simplify(assumptions: assumptions);
  final numTerms = <Expr>[];
  final denTerms = <Expr>[];
  for (var k = 1; k <= n; k += 2) {
    final sign = ((k - 1) ~/ 2).isEven ? 1 : -1;
    final coeff = IntegerNumber.of(sign * n.binomial(k));
    final pow = k == 1 ? tanU : Pow(tanU, IntegerNumber.of(k));
    numTerms.add((coeff * pow).simplify(assumptions: assumptions));
  }
  for (var k = 0; k <= n; k += 2) {
    final sign = (k ~/ 2).isEven ? 1 : -1;
    final coeff = IntegerNumber.of(sign * n.binomial(k));
    final pow = k == 0 ? IntegerNumber.one : Pow(tanU, IntegerNumber.of(k));
    denTerms.add((coeff * pow).simplify(assumptions: assumptions));
  }
  return (Add(numTerms).simplify(assumptions: assumptions) /
          Add(denTerms).simplify(assumptions: assumptions))
      .simplify(assumptions: assumptions);
}

Expr _deMoivreSinh(int n, Expr u, Assumptions assumptions) {
  final sinhU = Sinh(u).simplify(assumptions: assumptions);
  final coshU = Cosh(u).simplify(assumptions: assumptions);
  final terms = <Expr>[];
  for (var k = 1; k <= n; k += 2) {
    final coeff = IntegerNumber.of(n.binomial(k));
    final coshPow = n - k == 0
        ? IntegerNumber.one
        : Pow(coshU, IntegerNumber.of(n - k));
    final sinhPow = k == 1 ? sinhU : Pow(sinhU, IntegerNumber.of(k));
    terms.add((coeff * coshPow * sinhPow).simplify(assumptions: assumptions));
  }
  return Add(terms)
      .expand(assumptions: assumptions)
      .simplify(assumptions: assumptions);
}

Expr _deMoivreCosh(int n, Expr u, Assumptions assumptions) {
  final sinhU = Sinh(u).simplify(assumptions: assumptions);
  final coshU = Cosh(u).simplify(assumptions: assumptions);
  final terms = <Expr>[];
  for (var k = 0; k <= n; k += 2) {
    final coeff = IntegerNumber.of(n.binomial(k));
    final coshPow = n - k == 0
        ? IntegerNumber.one
        : Pow(coshU, IntegerNumber.of(n - k));
    final sinhPow = k == 0
        ? IntegerNumber.one
        : Pow(sinhU, IntegerNumber.of(k));
    terms.add((coeff * coshPow * sinhPow).simplify(assumptions: assumptions));
  }
  return Add(terms)
      .expand(assumptions: assumptions)
      .simplify(assumptions: assumptions);
}

Expr _deMoivreTanh(int n, Expr u, Assumptions assumptions) {
  final tanhU = Tanh(u).simplify(assumptions: assumptions);
  final numTerms = <Expr>[];
  final denTerms = <Expr>[];
  for (var k = 1; k <= n; k += 2) {
    final coeff = IntegerNumber.of(n.binomial(k));
    final pow = k == 1 ? tanhU : Pow(tanhU, IntegerNumber.of(k));
    numTerms.add((coeff * pow).simplify(assumptions: assumptions));
  }
  for (var k = 0; k <= n; k += 2) {
    final coeff = IntegerNumber.of(n.binomial(k));
    final pow = k == 0 ? IntegerNumber.one : Pow(tanhU, IntegerNumber.of(k));
    denTerms.add((coeff * pow).simplify(assumptions: assumptions));
  }
  return (Add(numTerms).simplify(assumptions: assumptions) /
          Add(denTerms).simplify(assumptions: assumptions))
      .simplify(assumptions: assumptions);
}

Expr _simplifyTrigExpr(Expr expr, Assumptions assumptions) {
  // 1. Convert tan -> sin/cos and tanh -> sinh/cosh, then combine and cancel
  // rational fractions so Pythagorean identities in numerators/denominators
  // reduce via simplify().
  final sinCosForm = _rewriteToSinCos(
    expr,
    assumptions,
  ).cancel(assumptions: assumptions);

  // 2. Apply product-to-sum and double-angle contractions bottom-up.
  final contracted = _contractTrigNode(
    sinCosForm,
    assumptions,
  ).simplify(assumptions: assumptions);

  // 3. Fold pure sin^k(u) * cos^(-k)(u) quotients back into tan^k(u).
  return _foldQuotientToTan(
    contracted,
    assumptions,
  ).simplify(assumptions: assumptions);
}

Expr _contractTrigNode(Expr expr, Assumptions assumptions) {
  final mapped = expr
      .mapChildren((c) => _contractTrigNode(c, assumptions))
      .simplify(assumptions: assumptions);
  return switch (mapped) {
    Mul(:final factors) => _contractTrigProduct(factors, assumptions),
    Add(:final terms) => _contractTrigSum(terms, assumptions),
    _ => mapped,
  };
}

Expr _contractTrigProduct(List<Expr> factors, Assumptions assumptions) {
  // Look for pairs of Sin/Cos or Sinh/Cosh in the numerator factors
  final remaining = List<Expr>.of(factors);
  var changed = false;

  for (var i = 0; i < remaining.length; i++) {
    final f1 = remaining[i];
    if (f1 is Sin || f1 is Cos) {
      for (var j = i + 1; j < remaining.length; j++) {
        final f2 = remaining[j];
        final combined = _productToSumPair(f1, f2, assumptions);
        if (combined != null) {
          remaining
            ..removeAt(j)
            ..removeAt(i)
            ..add(combined);
          changed = true;
          break;
        }
      }
      if (changed) break;
    } else if (f1 is Sinh || f1 is Cosh) {
      for (var j = i + 1; j < remaining.length; j++) {
        final f2 = remaining[j];
        final combined = _hyperbolicProductToSumPair(f1, f2, assumptions);
        if (combined != null) {
          remaining
            ..removeAt(j)
            ..removeAt(i)
            ..add(combined);
          changed = true;
          break;
        }
      }
      if (changed) break;
    }
  }

  final prod = simplifyMul(remaining, assumptions: assumptions);
  if (changed) {
    return _contractTrigNode(
      prod.expand(assumptions: assumptions).simplify(assumptions: assumptions),
      assumptions,
    );
  }
  return prod;
}

Expr? _productToSumPair(Expr f1, Expr f2, Assumptions assumptions) {
  const half = FractionNumber.half;
  return switch ((f1, f2)) {
    (Sin(expr: final a), Cos(expr: final b)) ||
    (Cos(expr: final b), Sin(expr: final a)) => () {
      final sumTerm = Sin((a + b).simplify(assumptions: assumptions));
      final diffTerm = compareStructural(a, b) <= 0
          ? Sin((a - b).simplify(assumptions: assumptions))
          : -Sin((b - a).simplify(assumptions: assumptions));
      return half * (diffTerm + sumTerm);
    }(),
    (Cos(expr: final a), Cos(expr: final b)) => () {
      final diffArg = compareStructural(a, b) <= 0
          ? (a - b).simplify(assumptions: assumptions)
          : (b - a).simplify(assumptions: assumptions);
      return half *
          (Cos(diffArg) + Cos((a + b).simplify(assumptions: assumptions)));
    }(),
    (Sin(expr: final a), Sin(expr: final b)) => () {
      final diffArg = compareStructural(a, b) <= 0
          ? (a - b).simplify(assumptions: assumptions)
          : (b - a).simplify(assumptions: assumptions);
      return half *
          (Cos(diffArg) - Cos((a + b).simplify(assumptions: assumptions)));
    }(),
    _ => null,
  };
}

Expr? _hyperbolicProductToSumPair(Expr f1, Expr f2, Assumptions assumptions) {
  const half = FractionNumber.half;
  return switch ((f1, f2)) {
    (Sinh(expr: final a), Cosh(expr: final b)) ||
    (Cosh(expr: final b), Sinh(expr: final a)) => () {
      final sumTerm = Sinh((a + b).simplify(assumptions: assumptions));
      final diffTerm = compareStructural(a, b) <= 0
          ? Sinh((a - b).simplify(assumptions: assumptions))
          : -Sinh((b - a).simplify(assumptions: assumptions));
      return half * (diffTerm + sumTerm);
    }(),
    (Cosh(expr: final a), Cosh(expr: final b)) => () {
      final diffArg = compareStructural(a, b) <= 0
          ? (a - b).simplify(assumptions: assumptions)
          : (b - a).simplify(assumptions: assumptions);
      return half *
          (Cosh(diffArg) + Cosh((a + b).simplify(assumptions: assumptions)));
    }(),
    (Sinh(expr: final a), Sinh(expr: final b)) => () {
      final diffArg = compareStructural(a, b) <= 0
          ? (a - b).simplify(assumptions: assumptions)
          : (b - a).simplify(assumptions: assumptions);
      return half *
          (Cosh((a + b).simplify(assumptions: assumptions)) - Cosh(diffArg));
    }(),
    _ => null,
  };
}

Expr _contractTrigSum(List<Expr> terms, Assumptions assumptions) {
  // Check for cos^2(u) - sin^2(u) -> cos(2*u) and cosh^2(u) + sinh^2(u) -> cosh(2*u)
  final acc = MonomialAccumulator(
    simplify: (e) => simplifyExpr(e, assumptions: assumptions),
    assumptions: assumptions,
  );
  for (final t in terms) {
    acc.add(t);
  }
  acc.reduceIdentities();

  final cosSquares = <Expr, (Expr, Number)>{};
  final sinSquares = <Expr, (Expr, Number)>{};
  final coshSquares = <Expr, (Expr, Number)>{};
  final sinhSquares = <Expr, (Expr, Number)>{};

  for (final MapEntry(:key, :value) in acc.terms.entries) {
    if (key case Pow(
      base: Cos(:final expr),
      exponent: IntegerNumber(asInt: 2),
    )) {
      cosSquares[expr] = (key, value);
    } else if (key case Pow(
      base: Sin(:final expr),
      exponent: IntegerNumber(asInt: 2),
    )) {
      sinSquares[expr] = (key, value);
    } else if (key case Pow(
      base: Cosh(:final expr),
      exponent: IntegerNumber(asInt: 2),
    )) {
      coshSquares[expr] = (key, value);
    } else if (key case Pow(
      base: Sinh(:final expr),
      exponent: IntegerNumber(asInt: 2),
    )) {
      sinhSquares[expr] = (key, value);
    }
  }

  for (final u in cosSquares.keys) {
    if (sinSquares.containsKey(u)) {
      final (cosKey, cosCoeff) = cosSquares[u]!;
      final (sinKey, sinCoeff) = sinSquares[u]!;
      if (cosCoeff == sinCoeff.neg()) {
        acc.terms
          ..remove(cosKey)
          ..remove(sinKey);
        acc.add(
          Cos((IntegerNumber.two * u).simplify(assumptions: assumptions)),
          cosCoeff,
        );
      }
    }
  }

  for (final u in coshSquares.keys) {
    if (sinhSquares.containsKey(u)) {
      final (coshKey, coshCoeff) = coshSquares[u]!;
      final (sinhKey, sinhCoeff) = sinhSquares[u]!;
      if (coshCoeff == sinhCoeff) {
        acc.terms
          ..remove(coshKey)
          ..remove(sinhKey);
        acc.add(
          Cosh((IntegerNumber.two * u).simplify(assumptions: assumptions)),
          coshCoeff,
        );
      }
    }
  }

  return acc.build();
}

Expr _foldQuotientToTan(Expr expr, Assumptions assumptions) {
  final mapped = expr.mapChildren((c) => _foldQuotientToTan(c, assumptions));
  return switch (mapped) {
    Mul(:final factors) => _foldMulToTan(factors, assumptions),
    _ => mapped,
  };
}

Expr _foldMulToTan(List<Expr> factors, Assumptions assumptions) {
  final sinExps = <Expr, int>{};
  final cosExps = <Expr, int>{};
  final sinhExps = <Expr, int>{};
  final coshExps = <Expr, int>{};
  final otherFactors = <Expr>[];

  for (final f in factors) {
    switch (f) {
      case Sin(:final expr):
        sinExps[expr] = (sinExps[expr] ?? 0) + 1;
      case Pow(
        base: Sin(:final expr),
        exponent: IntegerNumber(asInt: final k?),
      ):
        sinExps[expr] = (sinExps[expr] ?? 0) + k;
      case Cos(:final expr):
        cosExps[expr] = (cosExps[expr] ?? 0) + 1;
      case Pow(
        base: Cos(:final expr),
        exponent: IntegerNumber(asInt: final k?),
      ):
        cosExps[expr] = (cosExps[expr] ?? 0) + k;
      case Sinh(:final expr):
        sinhExps[expr] = (sinhExps[expr] ?? 0) + 1;
      case Pow(
        base: Sinh(:final expr),
        exponent: IntegerNumber(asInt: final k?),
      ):
        sinhExps[expr] = (sinhExps[expr] ?? 0) + k;
      case Cosh(:final expr):
        coshExps[expr] = (coshExps[expr] ?? 0) + 1;
      case Pow(
        base: Cosh(:final expr),
        exponent: IntegerNumber(asInt: final k?),
      ):
        coshExps[expr] = (coshExps[expr] ?? 0) + k;
      default:
        otherFactors.add(f);
    }
  }

  final rebuilt = <Expr>[...otherFactors];

  final allTrigArgs = {...sinExps.keys, ...cosExps.keys}.toList()
    ..sort(compareStructural);
  for (final u in allTrigArgs) {
    final sExp = sinExps[u] ?? 0;
    final cExp = cosExps[u] ?? 0;
    if (sExp > 0 && cExp == -sExp) {
      final tanNode = Tan(u, isSimplified: true);
      rebuilt.add(sExp == 1 ? tanNode : Pow(tanNode, IntegerNumber.of(sExp)));
    } else {
      if (sExp != 0) {
        final sNode = Sin(u, isSimplified: true);
        rebuilt.add(sExp == 1 ? sNode : Pow(sNode, IntegerNumber.of(sExp)));
      }
      if (cExp != 0) {
        final cNode = Cos(u, isSimplified: true);
        rebuilt.add(cExp == 1 ? cNode : Pow(cNode, IntegerNumber.of(cExp)));
      }
    }
  }

  final allHypArgs = {...sinhExps.keys, ...coshExps.keys}.toList()
    ..sort(compareStructural);
  for (final u in allHypArgs) {
    final shExp = sinhExps[u] ?? 0;
    final chExp = coshExps[u] ?? 0;
    if (shExp > 0 && chExp == -shExp) {
      final tanhNode = Tanh(u, isSimplified: true);
      rebuilt.add(
        shExp == 1 ? tanhNode : Pow(tanhNode, IntegerNumber.of(shExp)),
      );
    } else {
      if (shExp != 0) {
        final shNode = Sinh(u, isSimplified: true);
        rebuilt.add(shExp == 1 ? shNode : Pow(shNode, IntegerNumber.of(shExp)));
      }
      if (chExp != 0) {
        final chNode = Cosh(u, isSimplified: true);
        rebuilt.add(chExp == 1 ? chNode : Pow(chNode, IntegerNumber.of(chExp)));
      }
    }
  }

  return simplifyMul(rebuilt, assumptions: assumptions);
}

Expr _rewriteToSinCos(Expr expr, Assumptions assumptions) {
  final mapped = expr.mapChildren((c) => _rewriteToSinCos(c, assumptions));
  return switch (mapped) {
    Tan(:final expr) => (Sin(expr) / Cos(expr)).simplify(
      assumptions: assumptions,
    ),
    Tanh(:final expr) => (Sinh(expr) / Cosh(expr)).simplify(
      assumptions: assumptions,
    ),
    _ => mapped.simplify(assumptions: assumptions),
  };
}

Expr _rewriteToExp(Expr expr, Assumptions assumptions) {
  final mapped = expr.mapChildren((c) => _rewriteToExp(c, assumptions));
  const i = ComplexNumber.i;
  const negHalfI = ComplexNumber(
    IntegerNumber.zero,
    FractionNumber.negativeHalf,
  );
  const half = FractionNumber.half;
  return switch (mapped) {
    Sin(expr: final u) => () {
      final iu = (i * u)
          .expand(assumptions: assumptions)
          .simplify(assumptions: assumptions);
      final negIu = (-iu).simplify(assumptions: assumptions);
      return (negHalfI * (Pow(Constant.e, iu) - Pow(Constant.e, negIu)))
          .simplify(assumptions: assumptions);
    }(),
    Cos(expr: final u) => () {
      final iu = (i * u)
          .expand(assumptions: assumptions)
          .simplify(assumptions: assumptions);
      final negIu = (-iu).simplify(assumptions: assumptions);
      return (half * (Pow(Constant.e, iu) + Pow(Constant.e, negIu))).simplify(
        assumptions: assumptions,
      );
    }(),
    Tan(expr: final u) => () {
      final iu = (i * u)
          .expand(assumptions: assumptions)
          .simplify(assumptions: assumptions);
      final negIu = (-iu).simplify(assumptions: assumptions);
      final ePos = Pow(Constant.e, iu);
      final eNeg = Pow(Constant.e, negIu);
      return ((-i * (ePos - eNeg)) / (ePos + eNeg)).simplify(
        assumptions: assumptions,
      );
    }(),
    Sinh(expr: final u) =>
      (half *
              (Pow(Constant.e, u) -
                  Pow(Constant.e, (-u).simplify(assumptions: assumptions))))
          .simplify(assumptions: assumptions),
    Cosh(expr: final u) =>
      (half *
              (Pow(Constant.e, u) +
                  Pow(Constant.e, (-u).simplify(assumptions: assumptions))))
          .simplify(assumptions: assumptions),
    Tanh(expr: final u) => () {
      final ePos = Pow(Constant.e, u);
      final eNeg = Pow(Constant.e, (-u).simplify(assumptions: assumptions));
      return ((ePos - eNeg) / (ePos + eNeg)).simplify(assumptions: assumptions);
    }(),
    _ => mapped.simplify(assumptions: assumptions),
  };
}

Expr _rewriteToTrig(Expr expr, Assumptions assumptions) {
  final mapped = expr.mapChildren((c) => _rewriteToTrig(c, assumptions));
  return switch (mapped) {
    Pow(base: Constant.e, :final exponent) => _expToTrig(exponent, assumptions),
    _ => mapped.simplify(assumptions: assumptions),
  };
}

Expr _expToTrig(Expr exponent, Assumptions assumptions) {
  final expanded = exponent
      .expand(assumptions: assumptions)
      .simplify(assumptions: assumptions);
  final rawTerms = <Expr>[];
  MonomialAccumulator.collectTerms(expanded, rawTerms);

  final realTerms = <Expr>[];
  final imagTerms = <Expr>[];

  for (final t in rawTerms) {
    final imagFactor = _extractImaginaryCoeff(t, assumptions);
    if (imagFactor != null) {
      imagTerms.add(imagFactor);
    } else {
      realTerms.add(t);
    }
  }

  if (imagTerms.isEmpty) {
    return Pow(Constant.e, expanded).simplify(assumptions: assumptions);
  }

  final theta = simplifyAdd(imagTerms, assumptions: assumptions);
  final euler = (Cos(theta) + ComplexNumber.i * Sin(theta)).simplify(
    assumptions: assumptions,
  );
  if (realTerms.isEmpty) {
    return euler;
  }
  final realArg = simplifyAdd(realTerms, assumptions: assumptions);
  return (Pow(Constant.e, realArg) * euler).simplify(assumptions: assumptions);
}

Expr? _extractImaginaryCoeff(Expr term, Assumptions assumptions) {
  switch (term) {
    case ComplexNumber(:final real, :final imaginary) when real.isZero:
      return imaginary;
    case Mul(
          factors: [
            ComplexNumber(:final real, :final imaginary),
            ...final rest,
          ],
        )
        when real.isZero && rest.isNotEmpty:
      final restExpr = rest.length == 1 ? rest.first : Mul(rest);
      return (imaginary * restExpr).simplify(assumptions: assumptions);
    default:
      return null;
  }
}
