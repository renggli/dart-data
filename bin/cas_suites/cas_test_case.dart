/// Shared test case definitions, declarative builders, SymPy syntax rewriters,
/// and symbolic/numerical equivalence verifiers for `bin/cas_runner.dart`.
library;

import 'dart:math' as math;

import 'package:data/symbolic.dart';
import 'package:more/number.dart' show Complex;

/// Outcome status of a single CAS benchmark case.
enum CasStatus { pass, fail, error }

/// Result of running a single [CasTestCase].
typedef CasCaseResult = ({CasStatus status, String? detail, int elapsedUs});

/// A named group of [CasTestCase]s forming a benchmark suite.
final class CasTestSuite {
  /// Creates a named [CasTestSuite].
  new({
    required this.name,
    required this.description,
    required this.buildCases,
    this.setUp,
  });

  /// Short identifier used for `--suite` filtering.
  final String name;

  /// Human-readable description and attribution summary.
  final String description;

  /// Callback building the ordered test cases in this suite.
  final List<CasTestCase> Function() buildCases;

  /// Optional setup callback invoked before cases in this suite are built.
  final void Function({bool forceUpdate})? setUp;

  /// Ordered test cases in this suite, built on first access.
  late final List<CasTestCase> cases = buildCases();
}

/// A single self-contained CAS benchmark case.
final class CasTestCase {
  /// Creates a [CasTestCase] with an evaluation closure.
  const new({required this.name, required this.description, required this.run});

  /// Unique case identifier within its suite (e.g. `wester_C1` or `gruntz_8_1`).
  final String name;

  /// Short mathematical formula or problem description used for `--test` filtering.
  final String description;

  /// Executes the case and returns `(ok, detail)`.
  final ({bool ok, String? detail}) Function() run;
}

/// Default SymPy-compatible parser (`E`, `I`, `oo`, `Abs`, `ceiling`, `log`, `Rational`).
final ExprSyntax casSyntax = buildCasSyntax();

final ExprSyntax _casSyntaxRenameE = buildCasSyntax(renameE: true);
final ExprSyntax _casSyntaxRenameEI = buildCasSyntax(
  renameE: true,
  renameI: true,
);

/// Builds a SymPy-compatible [ExprSyntax], optionally treating lowercase `e` or
/// `i` as symbolic variables (for Rubi and Blake integration suites).
ExprSyntax buildCasSyntax({bool renameE = false, bool renameI = false}) =>
    ExprSyntax(
      constants: {
        'E': Constant.e,
        'I': ComplexNumber.i,
        'oo': Constant.infinity,
        if (renameE) 'e': const Variable('e'),
        if (renameI) 'i': const Variable('i'),
      },
      unaryFunctions: {'Abs': Abs.new, 'ceiling': Ceil.new, 'log': Ln.new},
      binaryFunctions: {
        'Max': (a, b) => VariableFunction('Max', [a, b]),
        'Min': (a, b) => VariableFunction('Min', [a, b]),
        'Mod': Mod.new,
        'Rational': (a, b) => a / b,
      },
      variadicFunctions: {
        'Derivative': ExprSyntax.standardVariadicFunctions['diff']!,
      },
    );

/// Selects the appropriate [ExprSyntax] for [renameE] / [renameI].
ExprSyntax selectCasSyntax({bool renameE = false, bool renameI = false}) =>
    switch ((renameE, renameI)) {
      (_, true) => _casSyntaxRenameEI,
      (true, false) => _casSyntaxRenameE,
      _ => casSyntax,
    };

/// Parses [source] using [selectCasSyntax] after normalizing SymPy special forms.
Expr parseCas(String source, {bool renameE = false, bool renameI = false}) =>
    selectCasSyntax(
      renameE: renameE,
      renameI: renameI,
    ).parse(rewriteSympySpecialForms(source));

/// Builds a canonical `simplify` test case.
CasTestCase simplifyCase(
  String name,
  String input,
  String expected, {
  Assumptions assumptions = Assumptions.none,
}) => CasTestCase(
  name: name,
  description: 'simplify($input) == $expected',
  run: () {
    final actual = parseCas(input).simplify(assumptions: assumptions);
    final exp = parseCas(expected).simplify(assumptions: assumptions);
    final ok = verifyExprEquivalent(actual, exp, assumptions: assumptions);
    return (
      ok: ok,
      detail: ok ? null : 'simplify($input) -> $actual (expected: $exp)',
    );
  },
);

/// Builds a polynomial/algebraic `expand` test case.
CasTestCase expandCase(
  String name,
  String input,
  String expected, {
  Assumptions assumptions = Assumptions.none,
}) => CasTestCase(
  name: name,
  description: 'expand($input) == $expected',
  run: () {
    final actual = parseCas(input)
        .expand(assumptions: assumptions)
        .simplify(assumptions: assumptions);
    final exp = parseCas(expected).simplify(assumptions: assumptions);
    final ok = actual == exp;
    return (
      ok: ok,
      detail: ok ? null : 'expand($input) -> $actual (expected: $exp)',
    );
  },
);

/// Builds a polynomial `factor` test case.
CasTestCase factorCase(
  String name,
  String input,
  String expected, {
  Assumptions assumptions = Assumptions.none,
}) => CasTestCase(
  name: name,
  description: 'factor($input) == $expected',
  run: () {
    final raw = parseCas(input);
    final actual = raw.factor(assumptions: assumptions);
    final exp = parseCas(expected);
    final ok = _verifyFactoredEquivalent(actual, exp, assumptions: assumptions);
    return (
      ok: ok,
      detail: ok ? null : 'factor($input) -> $actual (expected: $exp)',
    );
  },
);

/// Builds a rational function `cancel` test case.
CasTestCase cancelCase(
  String name,
  String input,
  String expected, {
  Assumptions assumptions = Assumptions.none,
}) => CasTestCase(
  name: name,
  description: 'cancel($input) == $expected',
  run: () {
    final actual = parseCas(input).cancel(assumptions: assumptions);
    final exp = parseCas(expected).simplify(assumptions: assumptions);
    final ok =
        actual == exp ||
        verifyExprEquivalent(actual, exp, assumptions: assumptions);
    return (
      ok: ok,
      detail: ok ? null : 'cancel($input) -> $actual (expected: $exp)',
    );
  },
);

/// Builds a rational function `together` test case.
CasTestCase togetherCase(
  String name,
  String input,
  String expected, {
  Assumptions assumptions = Assumptions.none,
}) => CasTestCase(
  name: name,
  description: 'together($input) == $expected',
  run: () {
    final actual = parseCas(input).together(assumptions: assumptions);
    final exp = parseCas(expected).simplify(assumptions: assumptions);
    final ok =
        actual == exp ||
        verifyExprEquivalent(actual, exp, assumptions: assumptions);
    return (
      ok: ok,
      detail: ok ? null : 'together($input) -> $actual (expected: $exp)',
    );
  },
);

/// Builds a partial-fraction decomposition `apart` test case.
CasTestCase apartCase(
  String name,
  String input,
  String variable,
  String expected, {
  Assumptions assumptions = Assumptions.none,
}) => CasTestCase(
  name: name,
  description: 'apart($input, $variable) == $expected',
  run: () {
    final actual = parseCas(input).apart(variable, assumptions: assumptions);
    final exp = parseCas(expected).simplify(assumptions: assumptions);
    final ok =
        actual == exp ||
        (actual is Add &&
            exp is Add &&
            verifyExprEquivalent(actual, exp, assumptions: assumptions));
    return (
      ok: ok,
      detail: ok
          ? null
          : 'apart($input, $variable) -> $actual (expected: $exp)',
    );
  },
);

/// Builds a trigonometric `simplifyTrig` test case.
CasTestCase trigSimplifyCase(
  String name,
  String input,
  String expected, {
  Assumptions assumptions = Assumptions.none,
}) => CasTestCase(
  name: name,
  description: 'simplifyTrig($input) == $expected',
  run: () {
    final actual = parseCas(input).simplifyTrig(assumptions: assumptions);
    final exp = parseCas(expected).simplify(assumptions: assumptions);
    final ok = verifyExprEquivalent(actual, exp, assumptions: assumptions);
    return (
      ok: ok,
      detail: ok ? null : 'simplifyTrig($input) -> $actual (expected: $exp)',
    );
  },
);

/// Builds a trigonometric `expandTrig` test case.
CasTestCase trigExpandCase(
  String name,
  String input,
  String expected, {
  Assumptions assumptions = Assumptions.none,
}) => CasTestCase(
  name: name,
  description: 'expandTrig($input) == $expected',
  run: () {
    final actual = parseCas(input).expandTrig(assumptions: assumptions);
    final exp = parseCas(expected).simplify(assumptions: assumptions);
    final ok =
        actual == exp ||
        verifyExprEquivalent(actual, exp, assumptions: assumptions);
    return (
      ok: ok,
      detail: ok ? null : 'expandTrig($input) -> $actual (expected: $exp)',
    );
  },
);

/// Builds a complex rectangular normal-form `toRectangular` test case.
CasTestCase rectangularCase(
  String name,
  String input,
  String expected, {
  Assumptions assumptions = Assumptions.none,
}) => CasTestCase(
  name: name,
  description: 'toRectangular($input) == $expected',
  run: () {
    final actual = parseCas(input).toRectangular(assumptions: assumptions);
    final exp = parseCas(expected).simplify(assumptions: assumptions);
    final ok = verifyExprEquivalent(actual, exp, assumptions: assumptions);
    return (
      ok: ok,
      detail: ok ? null : 'toRectangular($input) -> $actual (expected: $exp)',
    );
  },
);

/// Builds a symbolic `derivative` test case.
///
/// Verifies that differentiating [input] with respect to [variable] ([order]
/// times) equals [expected].
CasTestCase differentiateCase(
  String name,
  String input,
  String variable,
  String expected, {
  int order = 1,
  bool renameE = false,
  bool renameI = false,
  Assumptions assumptions = Assumptions.none,
}) => CasTestCase(
  name: name,
  description: 'derivative($input, $variable, order: $order) == $expected',
  run: () {
    final expr = parseCas(input, renameE: renameE, renameI: renameI);
    final exp = parseCas(expected, renameE: renameE, renameI: renameI);
    final unknownFn = findUnknownFunction(expr) ?? findUnknownFunction(exp);
    if (unknownFn != null) {
      throw UnsupportedError('Unknown function: $unknownFn');
    }
    if (order == 1) {
      final ok = verifyDerivative(
        exp,
        expr,
        variable,
        assumptions: assumptions,
      );
      return (ok: ok, detail: ok ? null : 'd/d$variable($expr) != $exp');
    }
    final actual = expr.derivative(
      variable,
      order: order,
      assumptions: assumptions,
    );
    final ok = verifyExprEquivalent(actual, exp, assumptions: assumptions);
    return (
      ok: ok,
      detail: ok
          ? null
          : 'derivative($input, $variable, order: $order) -> $actual (expected: $exp)',
    );
  },
);

/// Builds an indefinite or definite symbolic `integrate` test case.
CasTestCase integrateCase(
  String name,
  String integrand,
  String variable, {
  String? expected,
  String? lower,
  String? upper,
  bool renameE = false,
  bool renameI = false,
  Assumptions assumptions = Assumptions.none,
}) => CasTestCase(
  name: name,
  description: lower != null || upper != null
      ? 'integrate($integrand, $variable = $lower..$upper)'
      : 'integrate($integrand, $variable)',
  run: () {
    final isDefinite = lower != null || upper != null;
    final expr = parseCas(integrand, renameE: renameE, renameI: renameI);
    final exp = expected == null
        ? null
        : parseCas(expected, renameE: renameE, renameI: renameI);
    final low = lower == null
        ? null
        : parseCas(lower, renameE: renameE, renameI: renameI);
    final high = upper == null
        ? null
        : parseCas(upper, renameE: renameE, renameI: renameI);

    final unknownFn =
        findUnknownFunction(expr) ??
        findUnknownFunction(exp) ??
        findUnknownFunction(low) ??
        findUnknownFunction(high);
    if (unknownFn != null) {
      throw UnsupportedError('Unknown function: $unknownFn');
    }

    if (isDefinite && (low == null || high == null)) {
      return (ok: false, detail: 'Missing definite bounds');
    }

    final actual = isDefinite
        ? expr.integrate(
            variable,
            from: low,
            to: high,
            assumptions: assumptions,
          )
        : expr.integrate(variable, assumptions: assumptions);

    final ok = isDefinite
        ? (exp != null &&
              verifyExprEquivalent(actual, exp, assumptions: assumptions))
        : ((exp != null && actual == exp) ||
              (!actual.anyNode((n) => n is Integral) &&
                  verifyDerivative(
                    expr,
                    actual,
                    variable,
                    assumptions: assumptions,
                  )));

    return (
      ok: ok,
      detail: ok ? null : 'int($expr, $variable) = $actual (expected: $exp)',
    );
  },
);

/// Builds a symbolic `limit` test case.
CasTestCase limitCase(
  String name,
  String input,
  String variable,
  String point,
  String expected, {
  LimitDirection direction = LimitDirection.both,
  Assumptions assumptions = Assumptions.none,
}) => CasTestCase(
  name: name,
  description: 'limit($input, $variable -> $point) == $expected',
  run: () {
    final pt = parseCas(point);
    final actual = parseCas(input)
        .limit(variable, pt, direction: direction, assumptions: assumptions);
    if (actual.anyNode((n) => n is Limit)) {
      return (
        ok: false,
        detail:
            'limit($input, $variable -> $point) remained unevaluated: $actual (expected: $expected)',
      );
    }
    final exp = parseCas(expected).simplify(assumptions: assumptions);
    final ok = verifyExprEquivalent(actual, exp, assumptions: assumptions);
    return (
      ok: ok,
      detail: ok
          ? null
          : 'limit($input, $variable -> $point) -> $actual (expected: $exp)',
    );
  },
);

/// Builds a `limit` test case expected to throw [UnsupportedError] (e.g. non-existent two-sided or oscillating limit).
CasTestCase limitDoesNotExistCase(
  String name,
  String input,
  String variable,
  String point, {
  LimitDirection direction = LimitDirection.both,
  Assumptions assumptions = Assumptions.none,
}) => CasTestCase(
  name: name,
  description: 'limit($input, $variable -> $point) DNE',
  run: () {
    final pt = parseCas(point);
    try {
      final actual = parseCas(input)
          .limit(variable, pt, direction: direction, assumptions: assumptions);
      final isUnevaluatedOrUndefined =
          actual == Constant.undefined || actual.anyNode((n) => n is Limit);
      return (
        ok: isUnevaluatedOrUndefined,
        detail: isUnevaluatedOrUndefined
            ? null
            : 'Expected limit DNE, got $actual',
      );
    } on UnsupportedError {
      return (ok: true, detail: null);
    }
  },
);

/// Builds a Taylor/Laurent `series` expansion test case.
CasTestCase seriesCase(
  String name,
  String input,
  String variable, {
  String point = '0',
  required int order,
  required String expected,
  Assumptions assumptions = Assumptions.none,
}) => CasTestCase(
  name: name,
  description: 'series($input, $variable, point: $point, order: $order)',
  run: () {
    final pt = parseCas(point);
    final actual = parseCas(input)
        .series(variable, point: pt, order: order, assumptions: assumptions);
    final exp = parseCas(expected).simplify(assumptions: assumptions);
    final diff = (actual - exp)
        .expand(assumptions: assumptions)
        .simplify(assumptions: assumptions);
    final ok =
        actual == exp ||
        diff == OrderTerm(variable, order, point: pt) ||
        verifyExprEquivalent(
          _stripOrderTerm(actual),
          _stripOrderTerm(exp),
          assumptions: assumptions,
        );
    return (
      ok: ok,
      detail: ok
          ? null
          : 'series($input, $variable, $point, $order) -> $actual (expected: $exp)',
    );
  },
);

/// Builds a symbolic summation `sum` test case.
CasTestCase sumCase(
  String name,
  String term,
  String variable,
  String lower,
  String upper,
  String expected, {
  Assumptions assumptions = Assumptions.none,
}) => CasTestCase(
  name: name,
  description: 'sum($term, $variable = $lower..$upper) == $expected',
  run: () {
    final actual = parseCas(
      term,
    ).sum(variable, parseCas(lower), parseCas(upper), assumptions: assumptions);
    if (actual.anyNode((n) => n is Sum)) {
      return (
        ok: false,
        detail:
            'sum($term, $variable = $lower..$upper) remained unevaluated: $actual (expected: $expected)',
      );
    }
    final exp = parseCas(expected).simplify(assumptions: assumptions);
    final ok = verifyExprEquivalent(actual, exp, assumptions: assumptions);
    return (
      ok: ok,
      detail: ok
          ? null
          : 'sum($term, $variable = $lower..$upper) -> $actual (expected: $exp)',
    );
  },
);

/// Builds a symbolic product `product` test case.
CasTestCase productCase(
  String name,
  String factor,
  String variable,
  String lower,
  String upper,
  String expected, {
  Assumptions assumptions = Assumptions.none,
}) => CasTestCase(
  name: name,
  description: 'product($factor, $variable = $lower..$upper) == $expected',
  run: () {
    final actual = parseCas(factor).product(
      variable,
      parseCas(lower),
      parseCas(upper),
      assumptions: assumptions,
    );
    if (actual.anyNode((n) => n is Product)) {
      return (
        ok: false,
        detail:
            'product($factor, $variable = $lower..$upper) remained unevaluated: $actual (expected: $expected)',
      );
    }
    final exp = parseCas(expected).simplify(assumptions: assumptions);
    final ok = verifyExprEquivalent(actual, exp, assumptions: assumptions);
    return (
      ok: ok,
      detail: ok
          ? null
          : 'product($factor, $variable = $lower..$upper) -> $actual (expected: $exp)',
    );
  },
);

/// Builds a univariate equation `solve` test case.
CasTestCase solveCase(
  String name,
  String equation,
  String variable,
  List<String> expectedRoots, {
  Assumptions assumptions = Assumptions.none,
}) => CasTestCase(
  name: name,
  description: 'solve($equation, $variable) == $expectedRoots',
  run: () {
    final actual = parseCas(equation).solve(variable, assumptions: assumptions);
    final expected = [
      for (final r in expectedRoots)
        parseCas(r).simplify(assumptions: assumptions),
    ];
    final ok = _verifyRootSetsEqual(actual, expected, assumptions: assumptions);
    return (
      ok: ok,
      detail: ok
          ? null
          : 'solve($equation, $variable) -> $actual (expected: $expected)',
    );
  },
);

/// Builds an ordinary differential equation `solveOde` test case.
CasTestCase odeCase(
  String name,
  String equation,
  String dependent,
  String independent,
  String expected, {
  Object? at,
  List<Object> initialValues = const [],
  Assumptions assumptions = Assumptions.none,
}) => CasTestCase(
  name: name,
  description: 'solveOde($equation, $dependent, $independent) == $expected',
  run: () {
    final actual = parseCas(equation).solveOde(
      dependent: dependent,
      independent: independent,
      at: at is String ? parseCas(at) : at,
      initialValues: [
        for (final v in initialValues)
          if (v is String) parseCas(v) else v,
      ],
      assumptions: assumptions,
    );
    final exp = parseCas(expected).simplify(assumptions: assumptions);
    final ok = verifyExprEquivalent(actual, exp, assumptions: assumptions);
    return (
      ok: ok,
      detail: ok
          ? null
          : 'solveOde($equation, $dependent, $independent) -> $actual (expected: $exp)',
    );
  },
);

/// Builds a custom programmatic test case (e.g. for `Matrix<Expr>`, `solve`, or multivariable calculus).
CasTestCase customCase(
  String name,
  String description,
  ({bool ok, String? detail}) Function() verify,
) => CasTestCase(name: name, description: description, run: verify);

/// Verifies whether `d/d[variable]([antideriv]) == [integrand]` symbolically or
/// numerically across real and complex sample points.
bool verifyDerivative(
  Expr integrand,
  Expr antideriv,
  String variable, {
  Assumptions assumptions = Assumptions.none,
}) {
  final Expr deriv;
  try {
    deriv = antideriv.derivative(variable, assumptions: assumptions);
  } on Object {
    return false;
  }
  try {
    final diff = (deriv - integrand).simplify(assumptions: assumptions);
    if (diff is Number && diff.isZero) return true;
  } on Object {
    // Fall back to numerical derivative check.
  }
  final freeVars = <String>{...integrand.freeVariables, ...deriv.freeVariables}
    ..remove(variable);
  try {
    final env = <String, double>{};
    var seed = 1.37;
    for (final v in freeVars) {
      env[v] = seed;
      seed += 0.41;
    }
    var checked = 0;
    for (final pt in const [0.37, 0.73, 1.19, 1.63, 2.11]) {
      env[variable] = pt;
      final lhs = deriv.evaluate(env);
      final rhs = integrand.evaluate(env);
      if (!lhs.isFinite || !rhs.isFinite) continue;
      if ((lhs - rhs).abs() > 1e-6 * math.max(1.0, rhs.abs())) return false;
      checked++;
    }
    if (checked > 0) return true;
  } on Object {
    // Fall back to complex evaluation when real evaluation fails.
  }
  try {
    final complexEnv = <String, Complex>{};
    var seed = const Complex(0.63, 0.19);
    for (final v in freeVars) {
      complexEnv[v] = seed;
      seed += const Complex(0.31, -0.07);
    }
    var checked = 0;
    for (final pt in const [
      Complex(0.37, 0.29),
      Complex(1.19, -0.41),
      Complex(-0.73, 0.53),
      Complex(2.63, 0.17),
      Complex(5.41, -0.31),
    ]) {
      complexEnv[variable] = pt;
      final lhs = deriv.evaluateComplex(complexEnv);
      final rhs = integrand.evaluateComplex(complexEnv);
      if (!lhs.a.isFinite ||
          !lhs.b.isFinite ||
          !rhs.a.isFinite ||
          !rhs.b.isFinite) {
        continue;
      }
      if ((lhs - rhs).abs() > 1e-6 * math.max(1.0, rhs.abs())) return false;
      checked++;
    }
    return checked > 0;
  } on Object {
    return false;
  }
}

/// Verifies whether [actual] and [expected] represent the same mathematical
/// expression under [assumptions].
bool verifyExprEquivalent(
  Expr actual,
  Expr expected, {
  Assumptions assumptions = Assumptions.none,
}) {
  if (actual == expected) return true;
  if (actual == Constant.undefined || expected == Constant.undefined) {
    return actual == expected;
  }
  final sActual = actual.simplify(assumptions: assumptions);
  final sExpected = expected.simplify(assumptions: assumptions);
  if (sActual == sExpected) return true;

  try {
    final diff = (sActual - sExpected).simplify(assumptions: assumptions);
    if (diff is Number && diff.isZero) return true;
    final expDiff = diff
        .expand(assumptions: assumptions)
        .simplify(assumptions: assumptions);
    if (expDiff is Number && expDiff.isZero) return true;
    final trigDiff = expDiff.simplifyTrig(assumptions: assumptions);
    if (trigDiff is Number && trigDiff.isZero) return true;
    final cancelDiff = diff.together(assumptions: assumptions);
    if (cancelDiff is Number && cancelDiff.isZero) return true;
  } on Object {
    // Fall through to numerical probe.
  }

  // Do not accept an unevaluated operator node via numerical evaluation if expected is closed-form.
  if (_hasUnevaluatedCalculusNode(sActual) !=
      _hasUnevaluatedCalculusNode(sExpected)) {
    return false;
  }

  final freeVars = <String>{
    ...sActual.freeVariables,
    ...sExpected.freeVariables,
  }.toList()..sort();

  try {
    var checked = 0;
    for (var sample = 0; sample < 5; sample++) {
      final env = <String, double>{};
      for (var i = 0; i < freeVars.length; i++) {
        final v = freeVars[i];
        final dom = assumptions.domainOf(v);
        env[v] = dom == VariableDomain.integer
            ? (sample + 2 + i).toDouble()
            : 0.43 + 0.37 * sample + 0.29 * i;
      }
      final a = sActual.evaluate(env);
      final b = sExpected.evaluate(env);
      if (!a.isFinite || !b.isFinite) continue;
      if ((a - b).abs() > 1e-6 * math.max(1.0, b.abs())) return false;
      checked++;
    }
    if (checked > 0) return true;
  } on Object {
    // Fall through to complex evaluation.
  }

  try {
    var checked = 0;
    for (var sample = 0; sample < 5; sample++) {
      final env = <String, Complex>{};
      for (var i = 0; i < freeVars.length; i++) {
        final v = freeVars[i];
        final dom = assumptions.domainOf(v);
        env[v] = dom == VariableDomain.integer
            ? Complex((sample + 2 + i).toDouble())
            : (dom == VariableDomain.real || dom == VariableDomain.positive)
            ? Complex(0.43 + 0.37 * sample + 0.29 * i)
            : Complex(0.43 + 0.31 * sample + 0.19 * i, 0.17 + 0.11 * sample);
      }
      final a = sActual.evaluateComplex(env);
      final b = sExpected.evaluateComplex(env);
      if (!a.a.isFinite || !a.b.isFinite || !b.a.isFinite || !b.b.isFinite) {
        continue;
      }
      if ((a - b).abs() > 1e-6 * math.max(1.0, b.abs())) return false;
      checked++;
    }
    return checked > 0;
  } on Object {
    return false;
  }
}

/// Returns the name of the first unknown [VariableFunction] in [expr], or `null`.
String? findUnknownFunction(Expr? expr) {
  if (expr == null) return null;
  if (expr is VariableFunction) return expr.name;
  String? found;
  expr.mapChildren((child) {
    found ??= findUnknownFunction(child);
    return child;
  });
  return found;
}

/// Rewrites SymPy special forms (`Matrix([...]).det()`, `Sum(f, (k, a, b))`,
/// `Product(f, (k, a, b))`, `Integral(f, (x, a, b))`, `hyper(...)`) into
/// standard `package:data/symbolic.dart` syntax.
String rewriteSympySpecialForms(String s) {
  if (s.contains('Matrix(')) {
    s = s.replaceAllMapped(
      RegExp(r'Matrix\(\[(.*?)\]\)\.det\(\)'),
      (m) =>
          'det(${m[1]!.replaceAllMapped(RegExp(r'\[([^\[\]]+)\]'), (r) => 'row(${r[1]})')})',
    );
  }
  for (final pair in const [
    ('Sum', 'sum'),
    ('Product', 'product'),
    ('Integral', 'integrate'),
  ]) {
    if (s.contains('${pair.$1}(')) s = _rewriteTupleBounds(s, pair.$1, pair.$2);
  }
  if (s.contains('hyper(')) s = _rewriteHyper(s);
  return s;
}

int _matchingParen(String s, int openIdx) {
  var depth = 0;
  for (var i = openIdx; i < s.length; i++) {
    if (s[i] == '(') depth++;
    if (s[i] == ')' && --depth == 0) return i;
  }
  return s.length - 1;
}

List<String> _splitArgs(String inner) {
  final args = <String>[];
  var depth = 0;
  var start = 0;
  for (var i = 0; i < inner.length; i++) {
    final ch = inner[i];
    if (ch == '(' || ch == '[') depth++;
    if (ch == ')' || ch == ']') depth--;
    if (ch == ',' && depth == 0) {
      args.add(inner.substring(start, i).trim());
      start = i + 1;
    }
  }
  return [...args, inner.substring(start).trim()];
}

String _rewriteTupleBounds(String s, String symName, String targetName) {
  final token = '$symName(';
  final buf = StringBuffer();
  var idx = 0;
  while (true) {
    final pos = s.indexOf(token, idx);
    if (pos == -1) {
      buf.write(s.substring(idx));
      return buf.toString();
    }
    if (pos > 0 && RegExp(r'[A-Za-z0-9_]').hasMatch(s[pos - 1])) {
      buf.write(s.substring(idx, pos + token.length));
      idx = pos + token.length;
      continue;
    }
    buf.write(s.substring(idx, pos));
    final closeIdx = _matchingParen(s, pos + symName.length);
    final inner = _rewriteTupleBounds(
      s.substring(pos + token.length, closeIdx),
      symName,
      targetName,
    );
    final args = _splitArgs(inner);
    if (args.length == 2 && args[1].startsWith('(') && args[1].endsWith(')')) {
      final bounds = _splitArgs(args[1].substring(1, args[1].length - 1));
      buf.write('$targetName(${args[0]}, ${bounds.join(', ')})');
    } else {
      buf.write('$targetName($inner)');
    }
    idx = closeIdx + 1;
  }
}

String _rewriteHyper(String s) {
  final buf = StringBuffer();
  var idx = 0;
  while (true) {
    final pos = s.indexOf('hyper(', idx);
    if (pos == -1) {
      buf.write(s.substring(idx));
      return buf.toString();
    }
    buf.write(s.substring(idx, pos + 6));
    var cur = pos + 6;
    for (var arg = 0; arg < 2; arg++) {
      while (cur < s.length && s[cur] == ' ') {
        buf.write(' ');
        cur++;
      }
      if (cur < s.length && s[cur] == '(') {
        final closeIdx = _matchingParen(s, cur);
        var inner = s.substring(cur + 1, closeIdx).trimRight();
        if (inner.endsWith(',')) {
          inner = inner.substring(0, inner.length - 1).trimRight();
        }
        buf.write('tuple($inner)');
        cur = closeIdx + 1;
        while (cur < s.length && (s[cur] == ',' || s[cur] == ' ')) {
          buf.write(s[cur++]);
        }
      }
    }
    idx = cur;
  }
}

bool _verifyFactoredEquivalent(
  Expr actual,
  Expr expected, {
  required Assumptions assumptions,
}) {
  if (actual == expected) return true;
  if (actual.simplify(assumptions: assumptions) ==
      expected.simplify(assumptions: assumptions)) {
    if (_factorDepth(actual) >= _factorDepth(expected)) {
      return true;
    }
  }
  final diffExpanded =
      (actual.expand(assumptions: assumptions) -
              expected.expand(assumptions: assumptions))
          .simplify(assumptions: assumptions);
  if (diffExpanded is Number &&
      diffExpanded.isZero &&
      _factorDepth(actual) >= _factorDepth(expected) &&
      actual is! Add) {
    return true;
  }
  return false;
}

int _factorDepth(Expr expr) => switch (expr) {
  Mul(:final factors) => factors.fold<int>(
    0,
    (acc, f) => acc + _factorDepth(f),
  ),
  Pow(:final exponent) when exponent is IntegerNumber =>
    exponent.asInt?.abs() ?? 1,
  _ => 1,
};

bool _verifyRootSetsEqual(
  List<Expr> actual,
  List<Expr> expected, {
  required Assumptions assumptions,
}) {
  if (actual.length != expected.length) return false;
  final matched = List<bool>.filled(expected.length, false);
  for (final a in actual) {
    var found = false;
    for (var j = 0; j < expected.length; j++) {
      if (matched[j]) continue;
      if (verifyExprEquivalent(a, expected[j], assumptions: assumptions)) {
        matched[j] = true;
        found = true;
        break;
      }
    }
    if (!found) return false;
  }
  return true;
}

Expr _stripOrderTerm(Expr expr) => switch (expr) {
  OrderTerm() => IntegerNumber.zero,
  Add(:final terms) => Add([
    for (final t in terms)
      if (t is! OrderTerm) t,
  ]).simplify(),
  _ => expr,
};

bool _hasUnevaluatedCalculusNode(Expr expr) => expr.anyNode(
  (n) => n is Limit || n is Sum || n is Product || n is Integral,
);
