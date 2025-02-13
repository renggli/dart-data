import '../../../vector.dart';
import '../functions.dart';

/// Provides parameters as positional arguments.
class PositionalParametrizedUnaryFunction<T>
    extends ParametrizedUnaryFunction<T> {
  const PositionalParametrizedUnaryFunction(
    super.dataType,
    this.count,
    this.function,
  );

  @override
  final int count;

  /// Factory to bind the parametrized function:
  /// `MathematicalFunction<T> NumericFunction<T> Function(T a, T b, ...)`
  final Function function;

  @override
  List<T> toBindings(Vector<T> params) {
    assert(
      count == params.count,
      'Expected $count params, but got ${params.count}.',
    );
    return params.toList(growable: false);
  }

  @override
  UnaryFunction<T> bind(Vector<T> params) =>
      Function.apply(function, toBindings(params)) as UnaryFunction<T>;
}
