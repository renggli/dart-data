part of '../ast.dart';

/// Canonical N-ary addition node: `sum_i t_i`.
///
/// Always contains at least 2 canonically flattened, combined, and sorted terms.
/// Use [Add.of] or `+` to construct canonical sums.
final class Add extends Expr {
  new _(Iterable<Expr> terms, {bool simplified = false})
    : terms = List<Expr>.unmodifiable(terms),
      flags = _computeListFlags(terms, simplified: simplified),
      nodeCount = _computeListNodeCount(terms);

  /// Constructs a canonical [Add] node directly from an already canonically
  /// ordered, simplified list of at least two terms.
  new canonical(List<Expr> terms, {bool simplified = false})
    : assert(terms.length >= 2),
      terms = List<Expr>.unmodifiable(terms),
      flags = _computeListFlags(terms, simplified: simplified),
      nodeCount = _computeListNodeCount(terms);

  /// Constructs a canonically flattened, combined, and sorted binary sum `a + b`
  /// with fast paths that avoid allocating intermediate lists for common cases.
  static Expr binary(Expr a, Expr b) {
    if (a == Constant.undefined || b == Constant.undefined) {
      return Constant.undefined;
    }
    if (a is Number && a.isZero && !a.hasReal) return b;
    if (b is Number && b.isZero && !b.hasReal) return a;
    if (a is Number && b is Number && a is! RealNumber && b is! RealNumber) {
      return a.add(b);
    }
    if (a is! Add &&
        b is! Add &&
        a is! Mul &&
        b is! Mul &&
        a is! OrderTerm &&
        b is! OrderTerm &&
        a != Constant.infinity &&
        b != Constant.infinity) {
      if (a is Number && !a.hasReal && b is! Number) {
        return Add._([a, b]);
      }
      if (b is Number && !b.hasReal && a is! Number) {
        return Add._([b, a]);
      }
      if (a is! Number && b is! Number) {
        final cmp = compareStructural(a, b);
        if (cmp == 0) return Mul._([IntegerNumber.two, a]);
        return cmp < 0 ? Add._([a, b]) : Add._([b, a]);
      }
    }
    return Add.of([a, b]);
  }

  /// Constructs a canonically flattened, combined, and sorted sum from [terms].
  ///
  /// Returns `0` for empty sums, the unwrapped expression for single-term sums,
  /// [Constant.undefined] when indeterminate, or an [Add] node for 2+ terms.
  static Expr of(Iterable<Expr> terms) {
    final flat = <Expr>[];
    for (final t in terms) {
      if (t == Constant.undefined) return Constant.undefined;
      if (t is Add) {
        flat.addAll(t.terms);
      } else {
        flat.add(t);
      }
    }
    if (flat.isEmpty) return IntegerNumber.zero;
    if (flat.length == 1) return flat.first;
    if (flat.length == 2) {
      final a = flat[0];
      final b = flat[1];
      if (a is Number && b is Number && a is! RealNumber && b is! RealNumber) {
        return a.add(b);
      }
      if (a is Number &&
          !a.hasReal &&
          b is! Number &&
          b is! Mul &&
          b is! OrderTerm &&
          b != Constant.infinity &&
          b != Constant.undefined) {
        return a.isZero ? b : Add._([a, b]);
      }
      if (b is Number &&
          !b.hasReal &&
          a is! Number &&
          a is! Mul &&
          a is! OrderTerm &&
          a != Constant.infinity &&
          a != Constant.undefined) {
        return b.isZero ? a : Add._([b, a]);
      }
    }

    Number scalar = IntegerNumber.zero;
    var hasReal = false;
    Map<(String, Expr), int>? orderTerms;
    final buckets = <Expr, Number>{};
    Number? infCoeff;
    int? infSign;

    for (var i = 0; i < flat.length; i++) {
      final item = flat[i];
      if (item.hasReal) hasReal = true;
      if (item == Constant.undefined) return Constant.undefined;
      switch (item) {
        case Number():
          scalar = scalar.add(item);
        case OrderTerm(:final variable, :final order, :final point):
          final map = orderTerms ??= <(String, Expr), int>{};
          final key = (variable, point);
          final prev = map[key];
          map[key] = prev == null || order < prev ? order : prev;
        default:
          final (c, core) = _splitTermCoeff(item);
          if (c.isZero) continue;
          if (core == Constant.infinity) {
            if (c is RealNumeric) {
              final s = c.sign;
              if (infSign != null && infSign != s) return Constant.undefined;
              if (infCoeff != null) return Constant.undefined;
              infSign = s;
            } else {
              if (infSign != null) return Constant.undefined;
              infCoeff = infCoeff == null ? c : infCoeff.add(c);
              if (infCoeff.isZero) return Constant.undefined;
            }
          } else {
            final existing = buckets[core];
            if (existing == null) {
              buckets[core] = c;
            } else {
              final next = existing.add(c);
              if (next.isZero) {
                if (next is RealNumber) hasReal = true;
                buckets.remove(core);
              } else {
                buckets[core] = next;
              }
            }
          }
      }
    }

    final result = <Expr>[];
    if (!scalar.isZero) {
      result.add(
        hasReal && scalar is RationalNumber
            ? RealNumber(scalar.toDouble())
            : scalar,
      );
    }

    if (buckets.isNotEmpty) {
      final sortedKeys = buckets.keys.toList(growable: false)
        ..sort(compareStructural);
      for (var i = 0; i < sortedKeys.length; i++) {
        final core = sortedKeys[i];
        final coeff = buckets[core]!;
        if (coeff.isOne && coeff is! RealNumber) {
          result.add(core);
        } else if (coeff.isOne && coeff is RealNumber) {
          result.add(core);
        } else if (core is Mul) {
          result.add(Mul._([coeff, ...core.factors]));
        } else {
          result.add(Mul._([coeff, core]));
        }
      }
    }

    if (infSign != null) {
      result.add(
        infSign > 0
            ? Constant.infinity
            : Mul._([IntegerNumber.negativeOne, Constant.infinity]),
      );
    } else if (infCoeff != null) {
      result.add(
        infCoeff.isOne
            ? Constant.infinity
            : Mul._([infCoeff, Constant.infinity]),
      );
    }

    if (orderTerms != null && orderTerms.isNotEmpty) {
      final entries = orderTerms.entries.toList(growable: false)
        ..sort((a, b) {
          final (varA, ptA) = a.key;
          final (varB, ptB) = b.key;
          final cmpVar = varA.compareTo(varB);
          if (cmpVar != 0) return cmpVar;
          final cmpOrd = a.value.compareTo(b.value);
          if (cmpOrd != 0) return cmpOrd;
          return compareStructural(ptA, ptB);
        });
      for (final MapEntry(key: (varName, point), value: order) in entries) {
        result.add(OrderTerm(varName, order, point: point));
      }
    }

    return switch (result) {
      [] => hasReal ? RealNumber.zero : IntegerNumber.zero,
      [final single] => single,
      _ => Add._(result),
    };
  }

  /// Canonically ordered list of additive terms (always `length >= 2`).
  final List<Expr> terms;

  @override
  final int flags;

  @override
  final int nodeCount;

  @override
  int get structuralTag => 72;

  @override
  late final int hashCode = Object.hash(Add, Object.hashAll(terms));

  @override
  late final Set<String> freeVariables = _unionAllFreeVariables(terms);

  @override
  Expr mapChildren(Expr Function(Expr) transform) {
    final mapped = _mapExprList(terms, transform);
    return identical(mapped, terms) ? this : Add.of(mapped);
  }

  @override
  bool anyNode(bool Function(Expr) predicate) {
    if (predicate(this)) return true;
    for (var i = 0; i < terms.length; i++) {
      if (terms[i].anyNode(predicate)) return true;
    }
    return false;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Add &&
          terms.length == other.terms.length &&
          hashCode == other.hashCode &&
          const ListEquality<Expr>().equals(terms, other.terms));
}

/// Canonical N-ary multiplication node: `prod_i f_i`.
///
/// Always contains at least 2 canonically flattened, base-merged, and sorted
/// factors. Use [Mul.of] or `*` to construct canonical products.
final class Mul extends Expr {
  new _(Iterable<Expr> factors, {bool simplified = false})
    : factors = List<Expr>.unmodifiable(factors),
      flags = _computeListFlags(factors, simplified: simplified),
      nodeCount = _computeListNodeCount(factors);

  /// Constructs a canonical [Mul] node directly from an already canonically
  /// ordered list of at least two factors.
  new canonical(List<Expr> factors, {bool simplified = false})
    : assert(factors.length >= 2),
      factors = List<Expr>.unmodifiable(factors),
      flags = _computeListFlags(factors, simplified: simplified),
      nodeCount = _computeListNodeCount(factors);

  /// Constructs a raw product node without flattening, folding, or reordering [factors].
  ///
  /// Used where structural factorization (such as integer prime-power factorization)
  /// must preserve explicit unreduced factors.
  factory raw(Iterable<Expr> factors) => Mul._(factors);

  /// Constructs a canonically flattened, base-merged, and sorted binary product
  /// `a * b` with fast paths that avoid intermediate list allocations.
  static Expr binary(Expr a, Expr b, {bool simplified = false}) {
    if (a == Constant.undefined || b == Constant.undefined) {
      return Constant.undefined;
    }
    if ((a is Number && a.isZero) || (b is Number && b.isZero)) {
      if (a == Constant.infinity ||
          b == Constant.infinity ||
          (a is Mul && a.factors.contains(Constant.infinity)) ||
          (b is Mul && b.factors.contains(Constant.infinity))) {
        return Constant.undefined;
      }
      return (a.hasReal || b.hasReal) ? RealNumber.zero : IntegerNumber.zero;
    }
    if (a is Number && b is Number && a is! RealNumber && b is! RealNumber) {
      return a.mul(b);
    }
    if (a is! Mul &&
        b is! Mul &&
        a is! OrderTerm &&
        b is! OrderTerm &&
        a is! Pow &&
        b is! Pow &&
        a != Constant.infinity &&
        b != Constant.infinity) {
      if (a is Number && b is! Number) {
        return a.isOne ? b : Mul._([a, b], simplified: simplified);
      }
      if (b is Number && a is! Number) {
        return b.isOne ? a : Mul._([b, a], simplified: simplified);
      }
      if (a is! Number && b is! Number) {
        final cmp = compareStructural(a, b);
        if (cmp == 0) {
          return Pow._(a, IntegerNumber.two, simplified: simplified);
        }
        return cmp < 0
            ? Mul._([a, b], simplified: simplified)
            : Mul._([b, a], simplified: simplified);
      }
    }
    return Mul.of([a, b], simplified: simplified);
  }

  /// Constructs a canonically flattened, base-merged, and sorted product from
  /// [factors].
  static Expr of(Iterable<Expr> factors, {bool simplified = false}) {
    final flat = <Expr>[];
    var hasReal = false;
    var hasZero = false;
    var hasInfinity = false;

    for (final f in factors) {
      if (f == Constant.undefined) return Constant.undefined;
      if (f.hasReal) hasReal = true;
      if (f is Mul) {
        for (final sub in f.factors) {
          if (sub == Constant.undefined) return Constant.undefined;
          if (sub is Number && sub.isZero) hasZero = true;
          if (sub == Constant.infinity) hasInfinity = true;
          flat.add(sub);
        }
      } else {
        if (f is Number && f.isZero) hasZero = true;
        if (f == Constant.infinity) hasInfinity = true;
        flat.add(f);
      }
    }

    if (flat.isEmpty) return IntegerNumber.one;
    if (flat.length == 1) return flat.first;
    if (hasZero && hasInfinity) return Constant.undefined;
    if (hasZero) return hasReal ? RealNumber.zero : IntegerNumber.zero;
    if (flat.length == 2) {
      final a = flat[0];
      final b = flat[1];
      if (a is Number && b is Number && a is! RealNumber && b is! RealNumber) {
        return a.mul(b);
      }
      if (a is Number &&
          b is! Number &&
          b is! OrderTerm &&
          b is! Pow &&
          b != Constant.infinity &&
          b != Constant.undefined) {
        return a.isOne ? b : Mul._([a, b], simplified: simplified);
      }
      if (b is Number &&
          a is! Number &&
          a is! OrderTerm &&
          a is! Pow &&
          a != Constant.infinity &&
          a != Constant.undefined) {
        return b.isOne ? a : Mul._([b, a], simplified: simplified);
      }
    }

    Number coeff = IntegerNumber.one;
    final baseExps = <Expr, Expr>{};
    Map<(String, Expr), int>? orderTerms;

    for (var i = 0; i < flat.length; i++) {
      final f = flat[i];
      if (f is Number) {
        coeff = coeff.mul(f);
        if (coeff.isZero) {
          return coeff is RealNumber ? RealNumber.zero : IntegerNumber.zero;
        }
        continue;
      }
      if (f is OrderTerm) {
        final map = orderTerms ??= <(String, Expr), int>{};
        final key = (f.variable, f.point);
        map[key] = (map[key] ?? 0) + f.order;
        continue;
      }
      final (base, exp) = switch (f) {
        Pow(:final base, :final exponent) => (base, exponent),
        _ => (f, IntegerNumber.one as Expr),
      };
      if (base == Constant.infinity) {
        final existing = baseExps[base];
        baseExps[base] = existing == null ? exp : existing + exp;
        continue;
      }
      final existing = baseExps[base];
      if (existing == null) {
        baseExps[base] = exp;
      } else {
        final sumExp = existing + exp;
        if (sumExp is Number && sumExp.isZero) {
          if (sumExp is RealNumber || base is RealNumber) {
            coeff = coeff.mul(RealNumber.one);
          }
          baseExps.remove(base);
        } else {
          baseExps[base] = sumExp;
        }
      }
    }

    final remaining = <Expr>[];
    for (final MapEntry(key: base, value: exp) in baseExps.entries) {
      final built = Pow.of(base, exp);
      if (built == Constant.undefined) return Constant.undefined;
      if (built is Number) {
        coeff = coeff.mul(built);
        if (coeff.isZero) {
          return coeff is RealNumber ? RealNumber.zero : IntegerNumber.zero;
        }
      } else if (built is Mul) {
        for (final sub in built.factors) {
          if (sub is Number) {
            coeff = coeff.mul(sub);
          } else {
            remaining.add(sub);
          }
        }
      } else {
        remaining.add(built);
      }
    }

    if (orderTerms != null) {
      for (final entry in orderTerms.entries) {
        remaining.add(
          OrderTerm(entry.key.$1, entry.value, point: entry.key.$2),
        );
      }
    }

    remaining.sort(compareStructural);
    if (!coeff.isOne) {
      remaining.insert(0, coeff);
    } else if (remaining.isEmpty) {
      return coeff;
    }

    return remaining.length == 1
        ? remaining.first
        : Mul._(remaining, simplified: simplified);
  }

  /// Canonically ordered list of multiplicative factors (always `length >= 2`).
  final List<Expr> factors;

  @override
  final int flags;

  @override
  final int nodeCount;

  @override
  int get structuralTag => 71;

  @override
  late final int hashCode = Object.hash(Mul, Object.hashAll(factors));

  @override
  late final Set<String> freeVariables = _unionAllFreeVariables(factors);

  @override
  Expr mapChildren(Expr Function(Expr) transform) {
    final mapped = _mapExprList(factors, transform);
    return identical(mapped, factors) ? this : Mul.of(mapped);
  }

  @override
  bool anyNode(bool Function(Expr) predicate) {
    if (predicate(this)) return true;
    for (var i = 0; i < factors.length; i++) {
      if (factors[i].anyNode(predicate)) return true;
    }
    return false;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Mul &&
          factors.length == other.factors.length &&
          hashCode == other.hashCode &&
          const ListEquality<Expr>().equals(factors, other.factors));
}

/// Canonical exponentiation node: `base^exponent`.
///
/// Use [Pow.of] or `pow` to construct canonical powers.
final class Pow extends Expr {
  new _(this.base, this.exponent, {bool simplified = false})
    : flags =
          ((base.flags | exponent.flags) & kStructuralFlagsMask) |
          (simplified ? kFlagSimplified : 0),
      nodeCount = 1 + base.nodeCount + exponent.nodeCount;

  /// Constructs a canonical [Pow] node directly without re-folding.
  new canonical(this.base, this.exponent, {bool simplified = false})
    : flags =
          ((base.flags | exponent.flags) & kStructuralFlagsMask) |
          (simplified ? kFlagSimplified : 0),
      nodeCount = 1 + base.nodeCount + exponent.nodeCount;

  /// Constructs a raw power node without folding [base] and [exponent].
  ///
  /// Used for explicit prime-power factorizations.
  factory raw(Expr base, Expr exponent) => Pow._(base, exponent);

  /// Constructs a canonical power expression `base^exponent`.
  static Expr of(Expr base, Expr exponent, {bool simplified = false}) {
    if (base == Constant.undefined || exponent == Constant.undefined) {
      return Constant.undefined;
    }
    if (exponent is Number && exponent.isZero) {
      if (base == Constant.infinity ||
          (base is Mul && base.factors.contains(Constant.infinity))) {
        return Constant.undefined;
      }
      return (base.hasReal || exponent is RealNumber)
          ? RealNumber.one
          : IntegerNumber.one;
    }
    if (exponent is IntegerNumber && exponent.isOne) {
      return base;
    }
    if (base is Number &&
        base.isOne &&
        !exponent.anyNode((n) => n == Constant.infinity)) {
      return (base is RealNumber || exponent is RealNumber)
          ? RealNumber.one
          : IntegerNumber.one;
    }
    if (base is Number && exponent is Number) {
      if (base is RationalNumber &&
          base.isNegative &&
          exponent is FractionNumber) {
        return Pow._(base, exponent, simplified: simplified);
      }
      if (base.isZero && exponent is RealNumeric && exponent.isNegative) {
        return Pow._(base, exponent, simplified: simplified);
      }
      final folded = base.powNumber(exponent);
      if (folded != null) return folded;
    }
    return Pow._(base, exponent, simplified: simplified);
  }

  /// Base of the power expression.
  final Expr base;

  /// Exponent of the power expression.
  final Expr exponent;

  @override
  final int flags;

  @override
  final int nodeCount;

  @override
  int get structuralTag => 70;

  @override
  late final int hashCode = Object.hash(Pow, base, exponent);

  @override
  late final Set<String> freeVariables = _unionFreeVariables(
    base.freeVariables,
    exponent.freeVariables,
  );

  @override
  Expr mapChildren(Expr Function(Expr) transform) {
    final nextBase = transform(base);
    final nextExp = transform(exponent);
    return identical(nextBase, base) && identical(nextExp, exponent)
        ? this
        : Pow.of(nextBase, nextExp);
  }

  @override
  bool anyNode(bool Function(Expr) predicate) =>
      predicate(this) || base.anyNode(predicate) || exponent.anyNode(predicate);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Pow &&
          hashCode == other.hashCode &&
          base == other.base &&
          exponent == other.exponent);
}

(Number, Expr) _splitTermCoeff(Expr expr) {
  if (expr is Number) return (expr, IntegerNumber.one);
  if (expr is Mul && expr.factors.first is Number) {
    final c = expr.factors.first as Number;
    final rest = expr.factors.sublist(1);
    final core = rest.length == 1 ? rest.first : Mul._(rest);
    return (c, core);
  }
  return (IntegerNumber.one, expr);
}

int _computeListFlags(Iterable<Expr> nodes, {bool simplified = false}) {
  var f = simplified ? kFlagSimplified : 0;
  for (final n in nodes) {
    f |= n.flags & kStructuralFlagsMask;
  }
  return f;
}

int _computeListNodeCount(Iterable<Expr> nodes) {
  var c = 1;
  for (final n in nodes) {
    c += n.nodeCount;
  }
  return c;
}

Set<String> _unionFreeVariables(Set<String> a, Set<String> b) {
  if (a.isEmpty) return b.isEmpty ? const <String>{} : b;
  if (b.isEmpty) return a;
  return Set<String>.unmodifiable({...a, ...b});
}

Set<String> _unionAllFreeVariables(List<Expr> nodes) {
  Set<String>? single;
  Set<String>? merged;
  for (var i = 0; i < nodes.length; i++) {
    final vars = nodes[i].freeVariables;
    if (vars.isEmpty) continue;
    if (merged != null) {
      merged.addAll(vars);
    } else if (single == null) {
      single = vars;
    } else if (!identical(single, vars)) {
      merged = {...single, ...vars};
    }
  }
  if (merged != null) return Set<String>.unmodifiable(merged);
  return single ?? const <String>{};
}

List<Expr> _mapExprList(List<Expr> items, Expr Function(Expr) transform) {
  List<Expr>? updated;
  for (var i = 0; i < items.length; i++) {
    final original = items[i];
    final next = transform(original);
    if (updated != null) {
      updated[i] = next;
    } else if (!identical(next, original)) {
      updated = List<Expr>.of(items);
      updated[i] = next;
    }
  }
  return updated ?? items;
}
