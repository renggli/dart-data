import 'package:collection/collection.dart';

import 'ast.dart';

/// Bitmask flags for composable symbolic variable properties.
const int _kPropReal = 1 << 0;
const int _kPropPositive = 1 << 1;
const int _kPropNegative = 1 << 2;
const int _kPropNonNegative = 1 << 3;
const int _kPropNonPositive = 1 << 4;
const int _kPropNonZero = 1 << 5;
const int _kPropInteger = 1 << 6;
const int _kPropEven = 1 << 7;
const int _kPropOdd = 1 << 8;
const int _kPropComplex = 1 << 9;

/// Immutable interval bounds `lower <(=) x <(=) upper` for a symbolic [Variable].
///
/// Unspecified [lower] or [upper] represents an unbounded endpoint (`-oo` or
/// `+oo`). When at least one endpoint is present, the bounded variable is
/// implicitly constrained to the real line unless overridden in [Assumptions].
final class VariableBounds {
  /// Creates variable interval bounds with optional [lower] and [upper]
  /// endpoints and boundary inclusivity flags.
  const new({
    this.lower,
    this.lowerInclusive = false,
    this.upper,
    this.upperInclusive = false,
  });

  /// Unbounded variable domain `(-oo, +oo)`.
  static const VariableBounds unbounded = VariableBounds();

  /// Lower bound expression (`null` for `-oo`).
  final Expr? lower;

  /// Whether [lower] is inclusive (`>=` when `true`, `>` when `false`).
  final bool lowerInclusive;

  /// Upper bound expression (`null` for `+oo`).
  final Expr? upper;

  /// Whether [upper] is inclusive (`<=` when `true`, `<` when `false`).
  final bool upperInclusive;

  /// Whether neither lower nor upper bound is specified.
  bool get isUnbounded => lower == null && upper == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VariableBounds &&
          lower == other.lower &&
          lowerInclusive == other.lowerInclusive &&
          upper == other.upper &&
          upperInclusive == other.upperInclusive;

  @override
  int get hashCode => Object.hash(lower, lowerInclusive, upper, upperInclusive);

  @override
  String toString() {
    if (isUnbounded) return '(-oo, oo)';
    final left = lower == null ? '(-oo' : '${lowerInclusive ? '[' : '('}$lower';
    final right = upper == null ? 'oo)' : '$upper${upperInclusive ? ']' : ')'}';
    return '$left, $right';
  }
}

/// Immutable mathematical domain, interval, property, and relational assumptions
/// for symbolic variables.
///
/// Pass an [Assumptions] instance to symbolic transformation, calculus, or
/// equation-solving methods to supply domain constraints (`positive`, `real`,
/// `integer`, `complex`), interval [bounds], parity/sign properties, and
/// relational inequalities for [Variable] nodes without mutating AST nodes.
///
/// ```dart
/// final expr = Expr.parse('sqrt(x^2) + conj(y)');
/// final simplified = expr.simplify(
///   assumptions: const Assumptions(
///     domains: {'x': VariableDomain.positive, 'y': VariableDomain.real},
///   ),
/// );
/// print(simplified); // x + y
/// ```
final class Assumptions {
  /// Creates an [Assumptions] context with per-variable [domains], fallback
  /// [defaultDomain] (defaulting to [VariableDomain.unknown]), interval
  /// [VariableBounds], composable bitmask properties, and relational constraints
  /// [relations].
  const new({
    this.domains = const {},
    this.defaultDomain = VariableDomain.unknown,
    this.bounds = const {},
    this.relations = const [],
  }) : _properties = const {};

  const new _(
    this.domains,
    this.defaultDomain,
    this.bounds,
    this._properties,
    this.relations,
  );

  /// Empty assumptions where all unspecified variables default to
  /// [VariableDomain.unknown].
  static const Assumptions none = Assumptions();

  /// Assumptions where all unspecified variables default to
  /// [VariableDomain.real].
  static const Assumptions real = Assumptions(
    defaultDomain: VariableDomain.real,
  );

  /// Assumptions where all unspecified variables default to
  /// [VariableDomain.positive].
  static const Assumptions positive = Assumptions(
    defaultDomain: VariableDomain.positive,
  );

  /// Assumptions where all unspecified variables default to
  /// [VariableDomain.complex].
  static const Assumptions complex = Assumptions(
    defaultDomain: VariableDomain.complex,
  );

  /// Explicit domain assignments by variable name.
  final Map<String, VariableDomain> domains;

  /// Default domain for variables not explicitly listed in [domains].
  final VariableDomain defaultDomain;

  /// Explicit real interval bounds by variable name.
  final Map<String, VariableBounds> bounds;

  final Map<String, int> _properties;

  /// Explicit symbolic relational assumptions (e.g. `x > 0`, `x > y`).
  final List<Relational> relations;

  /// Whether this context specifies no domain, bound, property, or relational
  /// assumptions.
  bool get isEmpty =>
      defaultDomain == VariableDomain.unknown &&
      domains.values.every((domain) => domain == VariableDomain.unknown) &&
      bounds.values.every((bound) => bound.isUnbounded) &&
      _properties.values.every((mask) => mask == 0) &&
      relations.isEmpty;

  /// Resolves the [VariableDomain] of variable [name].
  ///
  /// Upgrades [VariableDomain.unknown] to [VariableDomain.positive],
  /// [VariableDomain.integer], or [VariableDomain.real] when composable
  /// properties, interval [bounds], or [relations] imply it.
  VariableDomain domainOf(String name) {
    final domain = domains[name] ?? defaultDomain;
    if (domain != VariableDomain.unknown) return domain;
    final mask = _propMaskOf(name);
    if ((mask & _kPropComplex) != 0) return VariableDomain.complex;
    if ((mask & _kPropInteger) != 0) return VariableDomain.integer;
    if ((mask & _kPropPositive) != 0) return VariableDomain.positive;
    if ((mask & _kPropReal) != 0) return VariableDomain.real;
    final bound = bounds[name];
    if (bound != null && !bound.isUnbounded) {
      if (bound.lower case final RealNumeric low) {
        if (!low.isNegative && (!low.isZero || !bound.lowerInclusive)) {
          return VariableDomain.positive;
        }
      }
      return VariableDomain.real;
    }
    return VariableDomain.unknown;
  }

  /// Resolves the [VariableBounds] of variable [name].
  VariableBounds boundsOf(String name) =>
      bounds[name] ?? VariableBounds.unbounded;

  /// Whether variable [name] is assumed strictly positive (`> 0`).
  bool isPositive(String name) =>
      domainOf(name) == VariableDomain.positive ||
      (_propMaskOf(name) & _kPropPositive) != 0;

  /// Whether variable [name] is assumed strictly negative (`< 0`).
  bool isNegative(String name) => (_propMaskOf(name) & _kPropNegative) != 0;

  /// Whether variable [name] is assumed non-negative (`>= 0`).
  bool isNonNegative(String name) =>
      isPositive(name) || (_propMaskOf(name) & _kPropNonNegative) != 0;

  /// Whether variable [name] is assumed non-positive (`<= 0`).
  bool isNonPositive(String name) =>
      isNegative(name) || (_propMaskOf(name) & _kPropNonPositive) != 0;

  /// Whether variable [name] is assumed non-zero (`!= 0`).
  bool isNonZero(String name) =>
      isPositive(name) ||
      isNegative(name) ||
      isOdd(name) ||
      (_propMaskOf(name) & _kPropNonZero) != 0;

  /// Whether variable [name] is assumed integer-valued (`∈ Z`).
  bool isInteger(String name) {
    final domain = domains[name] ?? defaultDomain;
    return domain == VariableDomain.integer ||
        (_propMaskOf(name) & (_kPropInteger | _kPropEven | _kPropOdd)) != 0;
  }

  /// Whether variable [name] is assumed to be an even integer (`∈ 2Z`).
  bool isEven(String name) => (_propMaskOf(name) & _kPropEven) != 0;

  /// Whether variable [name] is assumed to be an odd integer (`∈ 2Z + 1`).
  bool isOdd(String name) => (_propMaskOf(name) & _kPropOdd) != 0;

  /// Whether variable [name] is assumed real-valued (`∈ R`).
  bool isReal(String name) {
    final domain = domainOf(name);
    if (domain == VariableDomain.real ||
        domain == VariableDomain.positive ||
        domain == VariableDomain.integer) {
      return true;
    }
    final mask = _propMaskOf(name);
    return (mask &
            (_kPropReal |
                _kPropPositive |
                _kPropNegative |
                _kPropNonNegative |
                _kPropNonPositive |
                _kPropInteger |
                _kPropEven |
                _kPropOdd)) !=
        0;
  }

  /// Returns a new [Assumptions] adding or overriding [domain] for [name].
  Assumptions withDomain(String name, VariableDomain domain) =>
      copyWith(domains: {name: domain});

  /// Returns a new [Assumptions] marking [name] as strictly positive (`> 0`).
  Assumptions withPositive(String name) => _withPropertyMask(
    name,
    _kPropReal | _kPropPositive | _kPropNonNegative | _kPropNonZero,
    domain: VariableDomain.positive,
  );

  /// Returns a new [Assumptions] marking [name] as strictly negative (`< 0`).
  Assumptions withNegative(String name) => _withPropertyMask(
    name,
    _kPropReal | _kPropNegative | _kPropNonPositive | _kPropNonZero,
    domain: domains[name] == null ? VariableDomain.real : null,
  );

  /// Returns a new [Assumptions] marking [name] as non-negative (`>= 0`).
  Assumptions withNonNegative(String name) => _withPropertyMask(
    name,
    _kPropReal | _kPropNonNegative,
    domain: domains[name] == null ? VariableDomain.real : null,
  );

  /// Returns a new [Assumptions] marking [name] as non-positive (`<= 0`).
  Assumptions withNonPositive(String name) => _withPropertyMask(
    name,
    _kPropReal | _kPropNonPositive,
    domain: domains[name] == null ? VariableDomain.real : null,
  );

  /// Returns a new [Assumptions] marking [name] as non-zero (`!= 0`).
  Assumptions withNonZero(String name) =>
      _withPropertyMask(name, _kPropNonZero);

  /// Returns a new [Assumptions] marking [name] as real-valued (`∈ R`).
  Assumptions withReal(String name) =>
      _withPropertyMask(name, _kPropReal, domain: VariableDomain.real);

  /// Returns a new [Assumptions] marking [name] as complex-valued (`∈ C`).
  Assumptions withComplex(String name) =>
      _withPropertyMask(name, _kPropComplex, domain: VariableDomain.complex);

  /// Returns a new [Assumptions] marking [name] as integer-valued (`∈ Z`).
  Assumptions withInteger(String name) => _withPropertyMask(
    name,
    _kPropReal | _kPropInteger,
    domain: VariableDomain.integer,
  );

  /// Returns a new [Assumptions] marking [name] as an even integer (`∈ 2Z`).
  Assumptions withEven(String name) => _withPropertyMask(
    name,
    _kPropReal | _kPropInteger | _kPropEven,
    domain: VariableDomain.integer,
  );

  /// Returns a new [Assumptions] marking [name] as an odd integer (`∈ 2Z + 1`).
  Assumptions withOdd(String name) => _withPropertyMask(
    name,
    _kPropReal | _kPropInteger | _kPropOdd | _kPropNonZero,
    domain: VariableDomain.integer,
  );

  /// Returns a new [Assumptions] adding interval bounds for [name].
  Assumptions withBounds(
    String name, {
    Expr? lower,
    bool lowerInclusive = false,
    Expr? upper,
    bool upperInclusive = false,
  }) => copyWith(
    bounds: {
      name: VariableBounds(
        lower: lower,
        lowerInclusive: lowerInclusive,
        upper: upper,
        upperInclusive: upperInclusive,
      ),
    },
  );

  /// Returns a new [Assumptions] recording relational constraint [relation].
  Assumptions withRelation(Relational relation) {
    final nextRelations = List<Relational>.unmodifiable([
      ...relations,
      relation,
    ]);
    var next = copyWith(relations: nextRelations);
    if (relation case Relational(:final op, :final left, :final right)) {
      Assumptions applySide(
        Assumptions curr,
        Expr varSide,
        Expr otherSide, {
        required bool flipped,
      }) {
        if (varSide case Variable(:final name)) {
          if (otherSide is Number && otherSide.isZero) {
            final mask = _relationMaskOfZeroOp(op, flipped: flipped);
            if (mask != 0) {
              final domain =
                  (op != RelOp.notEqual && curr.domains[name] == null)
                  ? VariableDomain.real
                  : null;
              return curr._withPropertyMask(name, mask, domain: domain);
            }
          } else if (op != RelOp.equal &&
              op != RelOp.notEqual &&
              (curr.domains[name] ?? curr.defaultDomain) ==
                  VariableDomain.unknown) {
            return curr.withReal(name);
          }
        }
        return curr;
      }

      next = applySide(next, left, right, flipped: false);
      next = applySide(next, right, left, flipped: true);
    }
    return next;
  }

  /// Returns a new [Assumptions] merging [domains], [bounds], and [relations],
  /// and optionally overriding [defaultDomain].
  Assumptions copyWith({
    Map<String, VariableDomain>? domains,
    VariableDomain? defaultDomain,
    Map<String, VariableBounds>? bounds,
    List<Relational>? relations,
  }) => Assumptions._(
    domains == null || domains.isEmpty
        ? this.domains
        : Map<String, VariableDomain>.unmodifiable({
            ...this.domains,
            ...domains,
          }),
    defaultDomain ?? this.defaultDomain,
    bounds == null || bounds.isEmpty
        ? this.bounds
        : Map<String, VariableBounds>.unmodifiable({...this.bounds, ...bounds}),
    _properties,
    relations ?? this.relations,
  );

  Assumptions _withPropertyMask(
    String name,
    int mask, {
    VariableDomain? domain,
  }) {
    final nextMask = (_properties[name] ?? 0) | mask;
    return Assumptions._(
      domain == null
          ? domains
          : Map<String, VariableDomain>.unmodifiable({
              ...domains,
              name: domain,
            }),
      defaultDomain,
      bounds,
      Map<String, int>.unmodifiable({..._properties, name: nextMask}),
      relations,
    );
  }

  int _propMaskOf(String name) {
    var mask = _properties[name] ?? 0;
    final dom = domains[name] ?? defaultDomain;
    switch (dom) {
      case VariableDomain.positive:
        mask |= _kPropReal | _kPropPositive | _kPropNonNegative | _kPropNonZero;
      case VariableDomain.integer:
        mask |= _kPropReal | _kPropInteger;
      case VariableDomain.real:
        mask |= _kPropReal;
      case VariableDomain.complex:
        mask |= _kPropComplex;
      case VariableDomain.unknown:
        break;
    }
    if (relations.isNotEmpty) {
      for (final rel in relations) {
        mask |= _relationVarPropMask(rel, name);
      }
    }
    return mask;
  }

  static int _relationMaskOfZeroOp(RelOp op, {required bool flipped}) {
    final effectiveOp = flipped
        ? switch (op) {
            RelOp.greaterThan => RelOp.lessThan,
            RelOp.greaterEqual => RelOp.lessEqual,
            RelOp.lessThan => RelOp.greaterThan,
            RelOp.lessEqual => RelOp.greaterEqual,
            RelOp.equal => RelOp.equal,
            RelOp.notEqual => RelOp.notEqual,
          }
        : op;
    return switch (effectiveOp) {
      RelOp.greaterThan =>
        _kPropReal | _kPropPositive | _kPropNonNegative | _kPropNonZero,
      RelOp.greaterEqual => _kPropReal | _kPropNonNegative,
      RelOp.lessThan =>
        _kPropReal | _kPropNegative | _kPropNonPositive | _kPropNonZero,
      RelOp.lessEqual => _kPropReal | _kPropNonPositive,
      RelOp.notEqual => _kPropNonZero,
      RelOp.equal => 0,
    };
  }

  static int _relationVarPropMask(Relational rel, String name) {
    var mask = 0;
    int sideMask(Expr varSide, Expr otherSide, {required bool flipped}) {
      if (varSide case Variable(name: final vName) when vName == name) {
        if (otherSide is Number && otherSide.isZero) {
          return _relationMaskOfZeroOp(rel.op, flipped: flipped);
        }
        if (rel.op != RelOp.equal && rel.op != RelOp.notEqual) {
          return _kPropReal;
        }
      }
      return 0;
    }

    mask |= sideMask(rel.left, rel.right, flipped: false);
    mask |= sideMask(rel.right, rel.left, flipped: true);
    return mask;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Assumptions &&
          defaultDomain == other.defaultDomain &&
          _mapEquality.equals(domains, other.domains) &&
          _boundsEquality.equals(bounds, other.bounds) &&
          _propEquality.equals(_properties, other._properties) &&
          _relEquality.equals(relations, other.relations);

  @override
  int get hashCode => Object.hash(
    defaultDomain,
    _mapEquality.hash(domains),
    _boundsEquality.hash(bounds),
    _propEquality.hash(_properties),
    _relEquality.hash(relations),
  );

  static const _mapEquality = MapEquality<String, VariableDomain>();
  static const _boundsEquality = MapEquality<String, VariableBounds>();
  static const _propEquality = MapEquality<String, int>();
  static const _relEquality = ListEquality<Relational>();
}
