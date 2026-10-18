import '../ast.dart';
import 'expand.dart';
import 'rational.dart';
import 'simplify.dart';
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
  Expr expandTrig() => _expandTrigExpr(simplify()).simplify();

  /// Simplifies trigonometric and hyperbolic expressions using Pythagorean,
  /// quotient ($\tan u = \sin u / \cos u$), double-angle, and product-to-sum
  /// identities.
  ///
  /// ```dart
  /// final e = Expr.parse('2 * sin(x) * cos(x)');
  /// print(e.simplifyTrig()); // sin(2 * x)
  /// ```
  Expr simplifyTrig() => _simplifyTrigExpr(simplify());

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
  Expr rewrite(RewriteTarget target) => switch (target) {
    RewriteTarget.exp => _rewriteToExp(simplify()).expand().simplify(),
    RewriteTarget.trig => _rewriteToTrig(simplify()).expand().simplify(),
    RewriteTarget.sinCos => _rewriteToSinCos(simplify()).simplify(),
  };
}

Expr _expandTrigExpr(Expr expr) {
  final mapped = expr.mapChildren(_expandTrigExpr).simplify();
  return switch (mapped) {
    Sin(expr: final arg) => _expandSin(arg),
    Cos(expr: final arg) => _expandCos(arg),
    Tan(expr: final arg) => _expandTan(arg),
    Sinh(expr: final arg) => _expandSinh(arg),
    Cosh(expr: final arg) => _expandCosh(arg),
    Tanh(expr: final arg) => _expandTanh(arg),
    _ => mapped,
  };
}

Expr _expandSin(Expr arg) {
  if (arg case Add(:final terms) when terms.length >= 2) {
    final first = terms.first;
    final rest = terms.length == 2
        ? terms[1]
        : Add(terms.sublist(1), isSimplified: true);
    final sinA = _expandSin(first);
    final cosA = _expandCos(first);
    final sinB = _expandSin(rest);
    final cosB = _expandCos(rest);
    return (sinA * cosB + cosA * sinB).expand().simplify();
  }
  if (_extractIntegerMultiple(arg) case (:final n, :final base)
      when n.abs() >= 2 && n.abs() <= 16) {
    final absN = n.abs();
    final expanded = _deMoivreSin(absN, base);
    return n < 0 ? (-expanded).simplify() : expanded;
  }
  return Sin(arg).simplify();
}

Expr _expandCos(Expr arg) {
  if (arg case Add(:final terms) when terms.length >= 2) {
    final first = terms.first;
    final rest = terms.length == 2
        ? terms[1]
        : Add(terms.sublist(1), isSimplified: true);
    final sinA = _expandSin(first);
    final cosA = _expandCos(first);
    final sinB = _expandSin(rest);
    final cosB = _expandCos(rest);
    return (cosA * cosB - sinA * sinB).expand().simplify();
  }
  if (_extractIntegerMultiple(arg) case (:final n, :final base)
      when n.abs() >= 2 && n.abs() <= 16) {
    return _deMoivreCos(n.abs(), base);
  }
  return Cos(arg).simplify();
}

Expr _expandTan(Expr arg) {
  if (arg case Add(:final terms) when terms.length >= 2) {
    final first = terms.first;
    final rest = terms.length == 2
        ? terms[1]
        : Add(terms.sublist(1), isSimplified: true);
    final tanA = _expandTan(first);
    final tanB = _expandTan(rest);
    return ((tanA + tanB) / (IntegerNumber.one - tanA * tanB)).simplify();
  }
  if (_extractIntegerMultiple(arg) case (:final n, :final base)
      when n.abs() >= 2 && n.abs() <= 16) {
    final absN = n.abs();
    final expanded = _deMoivreTan(absN, base);
    return n < 0 ? (-expanded).simplify() : expanded;
  }
  return Tan(arg).simplify();
}

Expr _expandSinh(Expr arg) {
  if (arg case Add(:final terms) when terms.length >= 2) {
    final first = terms.first;
    final rest = terms.length == 2
        ? terms[1]
        : Add(terms.sublist(1), isSimplified: true);
    final sinhA = _expandSinh(first);
    final coshA = _expandCosh(first);
    final sinhB = _expandSinh(rest);
    final coshB = _expandCosh(rest);
    return (sinhA * coshB + coshA * sinhB).expand().simplify();
  }
  if (_extractIntegerMultiple(arg) case (:final n, :final base)
      when n.abs() >= 2 && n.abs() <= 16) {
    final absN = n.abs();
    final expanded = _deMoivreSinh(absN, base);
    return n < 0 ? (-expanded).simplify() : expanded;
  }
  return Sinh(arg).simplify();
}

Expr _expandCosh(Expr arg) {
  if (arg case Add(:final terms) when terms.length >= 2) {
    final first = terms.first;
    final rest = terms.length == 2
        ? terms[1]
        : Add(terms.sublist(1), isSimplified: true);
    final sinhA = _expandSinh(first);
    final coshA = _expandCosh(first);
    final sinhB = _expandSinh(rest);
    final coshB = _expandCosh(rest);
    return (coshA * coshB + sinhA * sinhB).expand().simplify();
  }
  if (_extractIntegerMultiple(arg) case (:final n, :final base)
      when n.abs() >= 2 && n.abs() <= 16) {
    return _deMoivreCosh(n.abs(), base);
  }
  return Cosh(arg).simplify();
}

Expr _expandTanh(Expr arg) {
  if (arg case Add(:final terms) when terms.length >= 2) {
    final first = terms.first;
    final rest = terms.length == 2
        ? terms[1]
        : Add(terms.sublist(1), isSimplified: true);
    final tanhA = _expandTanh(first);
    final tanhB = _expandTanh(rest);
    return ((tanhA + tanhB) / (IntegerNumber.one + tanhA * tanhB)).simplify();
  }
  if (_extractIntegerMultiple(arg) case (:final n, :final base)
      when n.abs() >= 2 && n.abs() <= 16) {
    final absN = n.abs();
    final expanded = _deMoivreTanh(absN, base);
    return n < 0 ? (-expanded).simplify() : expanded;
  }
  return Tanh(arg).simplify();
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

int _binom(int n, int k) {
  if (k < 0 || k > n) return 0;
  var kk = k;
  if (kk > n - kk) kk = n - kk;
  var res = 1;
  for (var i = 1; i <= kk; i++) {
    res = (res * (n - kk + i)) ~/ i;
  }
  return res;
}

Expr _deMoivreSin(int n, Expr u) {
  final sinU = Sin(u).simplify();
  final cosU = Cos(u).simplify();
  final terms = <Expr>[];
  for (var k = 1; k <= n; k += 2) {
    final sign = ((k - 1) ~/ 2).isEven ? 1 : -1;
    final coeff = IntegerNumber.of(sign * _binom(n, k));
    final cosPow = n - k == 0
        ? IntegerNumber.one
        : Pow(cosU, IntegerNumber.of(n - k));
    final sinPow = k == 1 ? sinU : Pow(sinU, IntegerNumber.of(k));
    terms.add((coeff * cosPow * sinPow).simplify());
  }
  return Add(terms).expand().simplify();
}

Expr _deMoivreCos(int n, Expr u) {
  final sinU = Sin(u).simplify();
  final cosU = Cos(u).simplify();
  final terms = <Expr>[];
  for (var k = 0; k <= n; k += 2) {
    final sign = (k ~/ 2).isEven ? 1 : -1;
    final coeff = IntegerNumber.of(sign * _binom(n, k));
    final cosPow = n - k == 0
        ? IntegerNumber.one
        : Pow(cosU, IntegerNumber.of(n - k));
    final sinPow = k == 0 ? IntegerNumber.one : Pow(sinU, IntegerNumber.of(k));
    terms.add((coeff * cosPow * sinPow).simplify());
  }
  return Add(terms).expand().simplify();
}

Expr _deMoivreTan(int n, Expr u) {
  final tanU = Tan(u).simplify();
  final numTerms = <Expr>[];
  final denTerms = <Expr>[];
  for (var k = 1; k <= n; k += 2) {
    final sign = ((k - 1) ~/ 2).isEven ? 1 : -1;
    final coeff = IntegerNumber.of(sign * _binom(n, k));
    final pow = k == 1 ? tanU : Pow(tanU, IntegerNumber.of(k));
    numTerms.add((coeff * pow).simplify());
  }
  for (var k = 0; k <= n; k += 2) {
    final sign = (k ~/ 2).isEven ? 1 : -1;
    final coeff = IntegerNumber.of(sign * _binom(n, k));
    final pow = k == 0 ? IntegerNumber.one : Pow(tanU, IntegerNumber.of(k));
    denTerms.add((coeff * pow).simplify());
  }
  return (Add(numTerms).simplify() / Add(denTerms).simplify()).simplify();
}

Expr _deMoivreSinh(int n, Expr u) {
  final sinhU = Sinh(u).simplify();
  final coshU = Cosh(u).simplify();
  final terms = <Expr>[];
  for (var k = 1; k <= n; k += 2) {
    final coeff = IntegerNumber.of(_binom(n, k));
    final coshPow = n - k == 0
        ? IntegerNumber.one
        : Pow(coshU, IntegerNumber.of(n - k));
    final sinhPow = k == 1 ? sinhU : Pow(sinhU, IntegerNumber.of(k));
    terms.add((coeff * coshPow * sinhPow).simplify());
  }
  return Add(terms).expand().simplify();
}

Expr _deMoivreCosh(int n, Expr u) {
  final sinhU = Sinh(u).simplify();
  final coshU = Cosh(u).simplify();
  final terms = <Expr>[];
  for (var k = 0; k <= n; k += 2) {
    final coeff = IntegerNumber.of(_binom(n, k));
    final coshPow = n - k == 0
        ? IntegerNumber.one
        : Pow(coshU, IntegerNumber.of(n - k));
    final sinhPow = k == 0
        ? IntegerNumber.one
        : Pow(sinhU, IntegerNumber.of(k));
    terms.add((coeff * coshPow * sinhPow).simplify());
  }
  return Add(terms).expand().simplify();
}

Expr _deMoivreTanh(int n, Expr u) {
  final tanhU = Tanh(u).simplify();
  final numTerms = <Expr>[];
  final denTerms = <Expr>[];
  for (var k = 1; k <= n; k += 2) {
    final coeff = IntegerNumber.of(_binom(n, k));
    final pow = k == 1 ? tanhU : Pow(tanhU, IntegerNumber.of(k));
    numTerms.add((coeff * pow).simplify());
  }
  for (var k = 0; k <= n; k += 2) {
    final coeff = IntegerNumber.of(_binom(n, k));
    final pow = k == 0 ? IntegerNumber.one : Pow(tanhU, IntegerNumber.of(k));
    denTerms.add((coeff * pow).simplify());
  }
  return (Add(numTerms).simplify() / Add(denTerms).simplify()).simplify();
}

Expr _simplifyTrigExpr(Expr expr) {
  // 1. Convert tan -> sin/cos and tanh -> sinh/cosh, then combine and cancel
  // rational fractions so Pythagorean identities in numerators/denominators
  // reduce via simplify().
  final sinCosForm = _rewriteToSinCos(expr).cancel();

  // 2. Apply product-to-sum and double-angle contractions bottom-up.
  final contracted = _contractTrigNode(sinCosForm).simplify();

  // 3. Fold pure sin^k(u) * cos^(-k)(u) quotients back into tan^k(u).
  return _foldQuotientToTan(contracted).simplify();
}

Expr _contractTrigNode(Expr expr) {
  final mapped = expr.mapChildren(_contractTrigNode).simplify();
  return switch (mapped) {
    Mul(:final factors) => _contractTrigProduct(factors),
    Add(:final terms) => _contractTrigSum(terms),
    _ => mapped,
  };
}

Expr _contractTrigProduct(List<Expr> factors) {
  // Look for pairs of Sin/Cos or Sinh/Cosh in the numerator factors
  final remaining = List<Expr>.of(factors);
  var changed = false;

  for (var i = 0; i < remaining.length; i++) {
    final f1 = remaining[i];
    if (f1 is Sin || f1 is Cos) {
      for (var j = i + 1; j < remaining.length; j++) {
        final f2 = remaining[j];
        final combined = _productToSumPair(f1, f2);
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
        final combined = _hyperbolicProductToSumPair(f1, f2);
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

  final prod = simplifyMul(remaining);
  if (changed) {
    return _contractTrigNode(prod.expand().simplify());
  }
  return prod;
}

Expr? _productToSumPair(Expr f1, Expr f2) {
  const half = FractionNumber.half;
  return switch ((f1, f2)) {
    (Sin(expr: final a), Cos(expr: final b)) ||
    (Cos(expr: final b), Sin(expr: final a)) => () {
      final sumTerm = Sin((a + b).simplify());
      final diffTerm = compareStructural(a, b) <= 0
          ? Sin((a - b).simplify())
          : -Sin((b - a).simplify());
      return half * (diffTerm + sumTerm);
    }(),
    (Cos(expr: final a), Cos(expr: final b)) => () {
      final diffArg = compareStructural(a, b) <= 0
          ? (a - b).simplify()
          : (b - a).simplify();
      return half * (Cos(diffArg) + Cos((a + b).simplify()));
    }(),
    (Sin(expr: final a), Sin(expr: final b)) => () {
      final diffArg = compareStructural(a, b) <= 0
          ? (a - b).simplify()
          : (b - a).simplify();
      return half * (Cos(diffArg) - Cos((a + b).simplify()));
    }(),
    _ => null,
  };
}

Expr? _hyperbolicProductToSumPair(Expr f1, Expr f2) {
  const half = FractionNumber.half;
  return switch ((f1, f2)) {
    (Sinh(expr: final a), Cosh(expr: final b)) ||
    (Cosh(expr: final b), Sinh(expr: final a)) => () {
      final sumTerm = Sinh((a + b).simplify());
      final diffTerm = compareStructural(a, b) <= 0
          ? Sinh((a - b).simplify())
          : -Sinh((b - a).simplify());
      return half * (diffTerm + sumTerm);
    }(),
    (Cosh(expr: final a), Cosh(expr: final b)) => () {
      final diffArg = compareStructural(a, b) <= 0
          ? (a - b).simplify()
          : (b - a).simplify();
      return half * (Cosh(diffArg) + Cosh((a + b).simplify()));
    }(),
    (Sinh(expr: final a), Sinh(expr: final b)) => () {
      final diffArg = compareStructural(a, b) <= 0
          ? (a - b).simplify()
          : (b - a).simplify();
      return half * (Cosh((a + b).simplify()) - Cosh(diffArg));
    }(),
    _ => null,
  };
}

Expr _contractTrigSum(List<Expr> terms) {
  // Check for cos^2(u) - sin^2(u) -> cos(2*u) and cosh^2(u) + sinh^2(u) -> cosh(2*u)
  final acc = MonomialAccumulator(simplify: simplifyExpr);
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
        acc.add(Cos((IntegerNumber.two * u).simplify()), cosCoeff);
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
        acc.add(Cosh((IntegerNumber.two * u).simplify()), coshCoeff);
      }
    }
  }

  return acc.build();
}

Expr _foldQuotientToTan(Expr expr) {
  final mapped = expr.mapChildren(_foldQuotientToTan);
  return switch (mapped) {
    Mul(:final factors) => _foldMulToTan(factors),
    _ => mapped,
  };
}

Expr _foldMulToTan(List<Expr> factors) {
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

  return simplifyMul(rebuilt);
}

Expr _rewriteToSinCos(Expr expr) {
  final mapped = expr.mapChildren(_rewriteToSinCos);
  return switch (mapped) {
    Tan(:final expr) => (Sin(expr) / Cos(expr)).simplify(),
    Tanh(:final expr) => (Sinh(expr) / Cosh(expr)).simplify(),
    _ => mapped.simplify(),
  };
}

Expr _rewriteToExp(Expr expr) {
  final mapped = expr.mapChildren(_rewriteToExp);
  const i = ComplexNumber.i;
  const negHalfI = ComplexNumber(
    IntegerNumber.zero,
    FractionNumber.negativeHalf,
  );
  const half = FractionNumber.half;
  return switch (mapped) {
    Sin(expr: final u) => () {
      final iu = (i * u).expand().simplify();
      final negIu = (-iu).simplify();
      return (negHalfI * (Pow(Constant.e, iu) - Pow(Constant.e, negIu)))
          .simplify();
    }(),
    Cos(expr: final u) => () {
      final iu = (i * u).expand().simplify();
      final negIu = (-iu).simplify();
      return (half * (Pow(Constant.e, iu) + Pow(Constant.e, negIu))).simplify();
    }(),
    Tan(expr: final u) => () {
      final iu = (i * u).expand().simplify();
      final negIu = (-iu).simplify();
      final ePos = Pow(Constant.e, iu);
      final eNeg = Pow(Constant.e, negIu);
      return ((-i * (ePos - eNeg)) / (ePos + eNeg)).simplify();
    }(),
    Sinh(expr: final u) =>
      (half * (Pow(Constant.e, u) - Pow(Constant.e, (-u).simplify())))
          .simplify(),
    Cosh(expr: final u) =>
      (half * (Pow(Constant.e, u) + Pow(Constant.e, (-u).simplify())))
          .simplify(),
    Tanh(expr: final u) => () {
      final ePos = Pow(Constant.e, u);
      final eNeg = Pow(Constant.e, (-u).simplify());
      return ((ePos - eNeg) / (ePos + eNeg)).simplify();
    }(),
    _ => mapped.simplify(),
  };
}

Expr _rewriteToTrig(Expr expr) {
  final mapped = expr.mapChildren(_rewriteToTrig);
  return switch (mapped) {
    Pow(base: Constant.e, :final exponent) => _expToTrig(exponent),
    _ => mapped.simplify(),
  };
}

Expr _expToTrig(Expr exponent) {
  final expanded = exponent.expand().simplify();
  final rawTerms = <Expr>[];
  MonomialAccumulator.collectTerms(expanded, rawTerms);

  final realTerms = <Expr>[];
  final imagTerms = <Expr>[];

  for (final t in rawTerms) {
    final imagFactor = _extractImaginaryCoeff(t);
    if (imagFactor != null) {
      imagTerms.add(imagFactor);
    } else {
      realTerms.add(t);
    }
  }

  if (imagTerms.isEmpty) {
    return Pow(Constant.e, expanded).simplify();
  }

  final theta = simplifyAdd(imagTerms);
  final euler = (Cos(theta) + ComplexNumber.i * Sin(theta)).simplify();
  if (realTerms.isEmpty) {
    return euler;
  }
  final realArg = simplifyAdd(realTerms);
  return (Pow(Constant.e, realArg) * euler).simplify();
}

Expr? _extractImaginaryCoeff(Expr term) {
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
      return (imaginary * restExpr).simplify();
    default:
      return null;
  }
}
