import '../../../vector.dart';
import '../functions.dart';

/// Provides params as a single positional list argument.
class ListParametrizedUnaryFunction<T> extends ParametrizedUnaryFunction<T> {
  const ListParametrizedUnaryFunction(
    super.dataType,
    this.count,
    this.function,
  );

  @override
  final int count;

  /// Factory to bind the parametrized function.
  final UnaryFunction<T> Function(List<T> params) function;

  @override
  List<T> toBindings(Vector<T> params) {
    assert(
      count == params.count,
      'Expected $count params, but got ${params.count}.',
    );
    return params.toList(growable: false);
  }

  @override
  UnaryFunction<T> bind(Vector<T> params) => function(toBindings(params));
}
