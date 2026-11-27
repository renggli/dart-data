import 'package:data/symbolic.dart';

/// Selectable per-variable domain and property assumption for the Expressions app.
enum VariableAssumption {
  unknown('unknown', 'Unknown'),
  complex('complex', 'ℂ (Complex)'),
  real('real', 'ℝ (Real)'),
  positive('positive', 'ℝ⁺ (Positive)'),
  nonNegative('nonNegative', 'ℝ≥0 (Non-negative)'),
  negative('negative', 'ℝ⁻ (Negative)'),
  nonPositive('nonPositive', 'ℝ≤0 (Non-positive)'),
  nonZero('nonZero', '≠ 0 (Non-zero)'),
  integer('integer', 'ℤ (Integer)'),
  even('even', '2ℤ (Even)'),
  odd('odd', '2ℤ+1 (Odd)');

  new(this.key, this.label);

  /// URL/DOM serialization key for this assumption.
  final String key;

  /// Human-readable display label for the dropdown menu.
  final String label;

  /// Parses a serialized [key], defaulting to [VariableAssumption.unknown].
  static VariableAssumption parse(String value) => switch (value) {
    'complex' => VariableAssumption.complex,
    'real' => VariableAssumption.real,
    'positive' => VariableAssumption.positive,
    'nonNegative' => VariableAssumption.nonNegative,
    'negative' => VariableAssumption.negative,
    'nonPositive' => VariableAssumption.nonPositive,
    'nonZero' => VariableAssumption.nonZero,
    'integer' => VariableAssumption.integer,
    'even' => VariableAssumption.even,
    'odd' => VariableAssumption.odd,
    _ => VariableAssumption.unknown,
  };

  /// Applies this assumption for [variable] onto [base].
  Assumptions applyTo(Assumptions base, String variable) => switch (this) {
    VariableAssumption.unknown => base,
    VariableAssumption.complex => base.withComplex(variable),
    VariableAssumption.real => base.withReal(variable),
    VariableAssumption.positive => base.withPositive(variable),
    VariableAssumption.nonNegative => base.withNonNegative(variable),
    VariableAssumption.negative => base.withNegative(variable),
    VariableAssumption.nonPositive => base.withNonPositive(variable),
    VariableAssumption.nonZero => base.withNonZero(variable),
    VariableAssumption.integer => base.withInteger(variable),
    VariableAssumption.even => base.withEven(variable),
    VariableAssumption.odd => base.withOdd(variable),
  };
}

/// Recursively checks whether [expr] explicitly references a non-real complex number.
bool containsImaginary(Expr expr) =>
    expr.anyNode((node) => node is ComplexNumber && !node.isReal);

/// Builds an immutable [Assumptions] context from per-variable
/// [variableAssumptions] and comma-separated relational constraints
/// [relationsRaw] (e.g. `x > 0, x < pi, x > y`).
///
/// Constant one-variable inequalities are also folded into [VariableBounds] so
/// interval-based simplifiers and `DomainOracle` receive tight endpoint bounds.
({Assumptions assumptions, List<String> invalidRelations}) buildAssumptions(
  Map<String, VariableAssumption> variableAssumptions, {
  String relationsRaw = '',
}) {
  var assumptions = Assumptions.none;
  for (final entry in variableAssumptions.entries) {
    assumptions = entry.value.applyTo(assumptions, entry.key);
  }

  final invalid = <String>[];
  final boundsByVar = <String, VariableBounds>{};

  for (final segment in relationsRaw.split(',')) {
    final trimmed = segment.trim();
    if (trimmed.isEmpty) continue;
    final parsed = Expr.tryParse(trimmed);
    if (parsed is! Relational) {
      invalid.add(trimmed);
      continue;
    }
    assumptions = assumptions.withRelation(parsed);
    _recordConstantBound(parsed, boundsByVar);
  }

  for (final entry in boundsByVar.entries) {
    final b = entry.value;
    assumptions = assumptions.withBounds(
      entry.key,
      lower: b.lower,
      lowerInclusive: b.lowerInclusive,
      upper: b.upper,
      upperInclusive: b.upperInclusive,
    );
  }

  return (assumptions: assumptions, invalidRelations: invalid);
}

void _recordConstantBound(Relational rel, Map<String, VariableBounds> out) {
  final extracted = switch ((rel.left, rel.right)) {
    (Variable(:final name), final rhs) when rhs.freeVariables.isEmpty => (
      name,
      rel.op,
      rhs,
    ),
    (final lhs, Variable(:final name)) when lhs.freeVariables.isEmpty => (
      name,
      _flipRelOp(rel.op),
      lhs,
    ),
    _ => null,
  };
  if (extracted == null) return;
  final (varName, op, bound) = extracted;
  final prev = out[varName] ?? VariableBounds.unbounded;

  switch (op) {
    case RelOp.greaterThan:
      out[varName] = VariableBounds(
        lower: bound,
        lowerInclusive: false,
        upper: prev.upper,
        upperInclusive: prev.upperInclusive,
      );
    case RelOp.greaterEqual:
      out[varName] = VariableBounds(
        lower: bound,
        lowerInclusive: true,
        upper: prev.upper,
        upperInclusive: prev.upperInclusive,
      );
    case RelOp.lessThan:
      out[varName] = VariableBounds(
        lower: prev.lower,
        lowerInclusive: prev.lowerInclusive,
        upper: bound,
        upperInclusive: false,
      );
    case RelOp.lessEqual:
      out[varName] = VariableBounds(
        lower: prev.lower,
        lowerInclusive: prev.lowerInclusive,
        upper: bound,
        upperInclusive: true,
      );
    case RelOp.equal || RelOp.notEqual:
      break;
  }
}

RelOp _flipRelOp(RelOp op) => switch (op) {
  RelOp.greaterThan => RelOp.lessThan,
  RelOp.greaterEqual => RelOp.lessEqual,
  RelOp.lessThan => RelOp.greaterThan,
  RelOp.lessEqual => RelOp.greaterEqual,
  RelOp.equal => RelOp.equal,
  RelOp.notEqual => RelOp.notEqual,
};
