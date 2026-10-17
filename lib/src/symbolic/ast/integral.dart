part of '../ast.dart';

/// Symbolic integral node representing an unevaluated indefinite integral
/// $\int f(x) \, dx$ or definite integral $\int_{a}^{b} f(x) \, dx$.
final class Integral extends Expr {
  /// Creates a symbolic integral of [integrand] with respect to [variable],
  /// optionally bounded from [lower] to [upper].
  new(
    this.integrand,
    this.variable, {
    this.lower,
    this.upper,
    this.isSimplified = false,
  }) : assert(
         (lower == null) == (upper == null),
         'Both lower and upper bounds must be provided for definite integrals, '
         'or neither for indefinite integrals.',
       );

  /// The integrand expression $f(x)$.
  final Expr integrand;

  /// The variable of integration $x$.
  final String variable;

  /// Optional lower bound $a$ for a definite integral.
  final Expr? lower;

  /// Optional upper bound $b$ for a definite integral.
  final Expr? upper;

  /// Whether this represents a definite integral with [lower] and [upper] bounds.
  bool get isDefinite => lower != null && upper != null;

  @override
  final bool isSimplified;

  @override
  late final int hashCode = Object.hash(
    Integral,
    integrand,
    variable,
    lower,
    upper,
  );

  @override
  double evaluate([Map<String, double> context = const {}]) {
    if (!isDefinite) {
      return double.nan;
    }
    final a = lower!.evaluate(context);
    final b = upper!.evaluate(context);
    if (a.isNaN || b.isNaN) return double.nan;
    if (a == b) return 0.0;
    final localContext = Map<String, double>.of(context);
    double f(double x) {
      localContext[variable] = x;
      return integrand.evaluate(localContext);
    }

    return _quadratureDefinite(f, a, b);
  }

  @override
  void collectFreeVariables(Set<String> target) {
    if (isDefinite) {
      final innerVars = <String>{};
      integrand.collectFreeVariables(innerVars);
      innerVars.remove(variable);
      target.addAll(innerVars);
      lower!.collectFreeVariables(target);
      upper!.collectFreeVariables(target);
    } else {
      integrand.collectFreeVariables(target);
      target.add(variable);
    }
  }

  @override
  bool dependsOn(String v) {
    if (isDefinite) {
      return (v != variable && integrand.dependsOn(v)) ||
          lower!.dependsOn(v) ||
          upper!.dependsOn(v);
    }
    return v == variable || integrand.dependsOn(v);
  }

  @override
  Expr substitute(String v, Expr replacement) {
    if (isDefinite) {
      return Integral(
        v == variable ? integrand : integrand.substitute(v, replacement),
        variable,
        lower: lower!.substitute(v, replacement),
        upper: upper!.substitute(v, replacement),
      );
    }
    return Integral(integrand.substitute(v, replacement), variable);
  }

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Integral(
    transform(integrand),
    variable,
    lower: lower != null ? transform(lower!) : null,
    upper: upper != null ? transform(upper!) : null,
  );

  @override
  bool anyNode(bool Function(Expr) predicate) =>
      predicate(this) ||
      integrand.anyNode(predicate) ||
      (lower?.anyNode(predicate) ?? false) ||
      (upper?.anyNode(predicate) ?? false);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Integral &&
          hashCode == other.hashCode &&
          variable == other.variable &&
          integrand == other.integrand &&
          lower == other.lower &&
          upper == other.upper);
}

double _quadratureDefinite(double Function(double) f, double a, double b) {
  if (b < a) {
    return -_quadratureDefinite(f, b, a);
  }
  if (a == double.negativeInfinity && b == double.infinity) {
    return _gaussLegendre16(
      (t) {
        final denom = 1.0 - t * t;
        if (denom == 0.0) return 0.0;
        final x = t / denom;
        final dx = (1.0 + t * t) / (denom * denom);
        return f(x) * dx;
      },
      -1.0,
      1.0,
    );
  }
  if (a.isFinite && b == double.infinity) {
    return _gaussLegendre16(
      (t) {
        if (t >= 1.0) return 0.0;
        final d = 1.0 - t;
        final x = a + t / d;
        final dx = 1.0 / (d * d);
        return f(x) * dx;
      },
      0.0,
      1.0,
    );
  }
  if (a == double.negativeInfinity && b.isFinite) {
    return _gaussLegendre16(
      (t) {
        if (t >= 1.0) return 0.0;
        final d = 1.0 - t;
        final x = b - t / d;
        final dx = 1.0 / (d * d);
        return f(x) * dx;
      },
      0.0,
      1.0,
    );
  }
  return _gaussLegendre16(f, a, b);
}

const _glNodes8 = <double>[
  0.09501250983763744,
  0.2816035507792589,
  0.45801677765722737,
  0.6178762444026438,
  0.755404408355003,
  0.8656312023878318,
  0.9445750230732326,
  0.9894009349916499,
];

const _glWeights8 = <double>[
  0.1894506104550685,
  0.18260341504492358,
  0.16915651939500254,
  0.14959598881657674,
  0.12462897125553388,
  0.09515851168249279,
  0.062253523938647894,
  0.027152459411754096,
];

double _gaussLegendre16(double Function(double) f, double a, double b) {
  final half = 0.5 * (b - a);
  final mid = 0.5 * (a + b);
  var sum = 0.0;
  for (var i = 0; i < 8; i++) {
    final dx = half * _glNodes8[i];
    final y1 = f(mid - dx);
    final y2 = f(mid + dx);
    sum +=
        _glWeights8[i] * ((y1.isFinite ? y1 : 0.0) + (y2.isFinite ? y2 : 0.0));
  }
  return half * sum;
}
