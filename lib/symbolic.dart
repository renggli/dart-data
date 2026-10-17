/// Symbolic mathematics, computer algebra, and exact calculus.
library;

export 'src/symbolic/algebra/approximate.dart' show ApproximationExtension;
export 'src/symbolic/algebra/expand.dart' show ExpandExtension;
export 'src/symbolic/algebra/factor.dart' show FactorExtension;
export 'src/symbolic/algebra/simplify.dart' show SimplifierExtension;
export 'src/symbolic/ast.dart';
export 'src/symbolic/calculus/differentiation.dart'
    show DifferentiationExtension;
export 'src/symbolic/calculus/integration.dart' show IntegrationExtension;
export 'src/symbolic/calculus/limit.dart' show LimitExtension;
export 'src/symbolic/calculus/multivariable.dart'
    show MultivariableExtension, MultivariableIterableExtension;
export 'src/symbolic/calculus/series.dart' show PowerSeries, SeriesExtension;
export 'src/symbolic/compiler.dart'
    show BytecodeEvaluator, CompilerExtension, CompilerIterableExtension;
export 'src/symbolic/linear/matrix.dart'
    show SymbolicMatrixExtension, SymbolicVectorExtension;
export 'src/symbolic/number/integer.dart' show Integer;
export 'src/symbolic/parser.dart' show ExprSyntax;
export 'src/symbolic/solver/polynomial_system.dart'
    show PolynomialSystemMethod, PolynomialSystemSolverExtension;
export 'src/symbolic/solver/system.dart' show SystemSolverExtension;
export 'src/symbolic/solver/univariate.dart' show SolverExtension;
export 'src/symbolic/textualization/latex.dart' show LatexExtension;
export 'src/symbolic/textualization/mathml.dart' show MathMlExtension;
export 'src/symbolic/type/expr_data_type.dart'
    show ExprDataType, ExprEquality, ExprField, exprDataType;
