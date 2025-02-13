import '../../../vector.dart';
import '../functions.dart';

/// Provides parameters are named arguments.
class NamedParametrizedUnaryFunction<T> extends ParametrizedUnaryFunction<T> {
  const NamedParametrizedUnaryFunction(
    super.dataType,
    this.names,
    this.function,
  );

  ///  The list of named parameter names.
  final List<Symbol> names;

  /// Factory to bind the parametrized function:
  /// `MathematicalFunction<T> Function({required T a, required T b, ...})`
  final Function function;

  @override
  int get count => names.length;

  @override
  Vector<T> toVector(Object? params, {T? defaultParam}) {
    if (params is Map<Symbol, T>) {
      return Vector<T>.generate(
        dataType,
        names.length,
        (i) =>
            params[names[i]] ??
            checkDefaultParam(params, defaultParam, names[i]),
        format: VectorFormat.standard,
      );
    } else {
      return super.toVector(params, defaultParam: defaultParam);
    }
  }

  @override
  Map<Symbol, T> toBindings(Vector<T> params) {
    assert(
      count == params.count,
      'Expected $count params, but got ${params.count}.',
    );
    return Map.fromIterables(names, params.iterable);
  }

  @override
  UnaryFunction<T> bind(Vector<T> params) =>
      Function.apply(function, const [], toBindings(params))
          as UnaryFunction<T>;
}
