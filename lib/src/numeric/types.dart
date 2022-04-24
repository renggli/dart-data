/// A numeric function `f(x)` with argument `x` and result of type [double].
typedef NumericFunction = double Function(double x);

/// A parametrized numeric function `f_(p_1)(p_2)..(p_n)(x)` with parameters,
/// argument `x` and result of type [double].
typedef ParameterizedFunction = double Function(List<double> params, double x);
