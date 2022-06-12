import '../../../vector.dart';
import '../functions.dart';

/// Provides parameters as a single positional map.
class MapParametrizedUnaryFunction<T> extends ParametrizedUnaryFunction<T> {
  const MapParametrizedUnaryFunction(super.dataType, this.names, this.function);

  ///  The list of named parameter names.
  final List<Symbol> names;

  /// Factory to bind the parametrized function.
  final UnaryFunction<T> Function(Map<Symbol, T> params) function;

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
          format: defaultVectorFormat);
    } else {
      return super.toVector(params, defaultParam: defaultParam);
    }
  }

  @override
  Map<Symbol, T> toBindings(Vector<T> params) {
    assert(count == params.count,
        'Expected $count params, but got ${params.count}.');
    return Map.fromIterables(names, params.iterable);
  }

  @override
  UnaryFunction<T> bind(Vector<T> params) => function(toBindings(params));
}
