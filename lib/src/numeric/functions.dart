import 'package:meta/meta.dart';

import '../../vector.dart';
import '../type/type.dart';
import 'functions/list.dart';
import 'functions/map.dart';
import 'functions/named.dart';
import 'functions/positional.dart';
import 'functions/vector.dart';

/// A function with a single argument and an identical return type. Typically
/// used for numerical functions like _f(x)_ where _x_ ∈ [T] and _f(x)_ ∈ [T].
///
/// See https://en.wikipedia.org/wiki/Function_(mathematics).
typedef UnaryFunction<T> = T Function(T x);

/// Abstract factory of parametrized unary functions of type `UnaryFunction<T>`.
abstract class ParametrizedUnaryFunction<T> {
  /// Abstract constructor of a parametrized function.
  const ParametrizedUnaryFunction(this.dataType);

  /// Provides parameters as a single positional list argument.
  const factory ParametrizedUnaryFunction.list(
    DataType<T> dataType,
    int count,
    UnaryFunction<T> Function(List<T> params) function,
  ) = ListParametrizedUnaryFunction;

  /// Provides parameters as a single positional map.
  const factory ParametrizedUnaryFunction.map(
    DataType<T> dataType,
    List<Symbol> names,
    UnaryFunction<T> Function(Map<Symbol, T> params) function,
  ) = MapParametrizedUnaryFunction;

  /// Provides parameters are named arguments.
  const factory ParametrizedUnaryFunction.named(
    DataType<T> dataType,
    List<Symbol> names,
    Function function,
  ) = NamedParametrizedUnaryFunction;

  /// Provides parameters as positional arguments.
  const factory ParametrizedUnaryFunction.positional(
    DataType<T> dataType,
    int count,
    Function function,
  ) = PositionalParametrizedUnaryFunction;

  /// Provides parameters as a single positional vector argument.
  const factory ParametrizedUnaryFunction.vector(
    DataType<T> dataType,
    int count,
    UnaryFunction<T> Function(Vector<T> params) function,
  ) = VectorParametrizedUnaryFunction;

  /// The underlying data type of the function.
  final DataType<T> dataType;

  /// The number of parameters.
  int get count;

  /// Converts the parameter values [params] to a Vector.
  ///
  /// If params is `null` or parameters are missing they are initialized with
  /// [defaultParam], or an [ArgumentError] is thrown is [defaultParams] is not
  /// specified.
  Vector<T> toVector(Object? params, {T? defaultParam}) {
    if (params == null) {
      return Vector<T>.constant(dataType, count,
          value: checkDefaultParam(params, defaultParam));
    } else if (params is List<T>) {
      return Vector<T>.generate(
          dataType,
          count,
          (i) => i < params.length
              ? params[i]
              : checkDefaultParam(params, defaultParam, i),
          format: defaultVectorFormat);
    } else if (params is Vector<T>) {
      return Vector<T>.generate(
          dataType,
          count,
          (i) => i < params.count
              ? params.getUnchecked(i)
              : checkDefaultParam(params, defaultParam, i),
          format: defaultVectorFormat);
    } else {
      throw ArgumentError.value(params, 'params', 'Invalid parameter type');
    }
  }

  @protected
  T checkDefaultParam(Object? params, T? defaultParam, [Object? key]) {
    if (defaultParam is T) {
      return defaultParam;
    }
    throw ArgumentError.value(params, 'params',
        key == null ? 'Missing a parameter.' : 'Missing a parameter at $key.');
  }

  /// Converts the parameter values [params] to the underlying binding type.
  dynamic toBindings(Vector<T> params);

  /// Binds a vector of parameter values [params] to a function using the
  /// selected strategy.
  UnaryFunction<T> bind(Vector<T> params);
}
