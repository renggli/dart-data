import '../../linear/vector.dart';
import '../ast.dart';
import 'fast_eval.dart';

/// Builds a multi-variable positional closure from [expression] and [indices].
double Function(List<double> args) buildPositionalEvaluator(
  Expr expression,
  Map<String, int> indices,
) => compileEvaluator<List<double>>(expression, (name) {
  final idx = indices[name] ?? (throw ArgumentError('Unbound variable: $name'));
  return (args) => args[idx];
});

/// Builds a `Vector<double>` evaluation closure from [expression] and [indices].
double Function(Vector<double> args) buildVectorEvaluator(
  Expr expression,
  Map<String, int> indices,
) => compileEvaluator<Vector<double>>(expression, (name) {
  final idx = indices[name] ?? (throw ArgumentError('Unbound variable: $name'));
  return (args) => args[idx];
});
