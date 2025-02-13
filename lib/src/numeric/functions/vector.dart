import '../../../vector.dart';
import '../functions.dart';

/// Provides parameters as a single positional vector argument.
class VectorParametrizedUnaryFunction<T> extends ParametrizedUnaryFunction<T> {
  const VectorParametrizedUnaryFunction(
    super.dataType,
    this.count,
    this.function,
  );

  @override
  final int count;

  /// Factory to bind the parametrized function.
  final UnaryFunction<T> Function(Vector<T> params) function;

  @override
  Vector<T> toBindings(Vector<T> params) {
    assert(
      count == params.count,
      'Expected $count params, but got ${params.count}.',
    );
    return params.toVector();
  }

  @override
  UnaryFunction<T> bind(Vector<T> params) => function(toBindings(params));
}
