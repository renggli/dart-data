/// Symbolic mathematics, computer algebra, exact calculus, and equation solving.
library;

export 'src/symbolic/algebra/approximate.dart' show ApproximationExtension;
export 'src/symbolic/algebra/expand.dart' show ExpandExtension;
export 'src/symbolic/algebra/factor.dart' show FactorExtension;
export 'src/symbolic/algebra/orthogonal.dart'
    show chebyshevT, chebyshevU, hermiteH, hermiteHe, laguerreL, legendreP;
export 'src/symbolic/algebra/rational.dart'
    show PolynomialDivisionResult, RationalFunctionExtension;
export 'src/symbolic/algebra/simplify.dart' show SimplifierExtension;
export 'src/symbolic/algebra/trig.dart'
    show RewriteTarget, TrigRewriteExtension;
export 'src/symbolic/assumptions.dart' show Assumptions, VariableBounds;
export 'src/symbolic/ast.dart';
export 'src/symbolic/calculus/differentiation.dart'
    show DifferentiationExtension;
export 'src/symbolic/calculus/integration/integration.dart'
    show IntegrationBound, IntegrationExtension;
export 'src/symbolic/calculus/limit.dart' show LimitExtension;
export 'src/symbolic/calculus/multivariable.dart'
    show MultivariableExtension, MultivariableIterableExtension;
export 'src/symbolic/calculus/puiseux_series.dart'
    show PuiseuxSeries, PuiseuxSeriesExtension;
export 'src/symbolic/calculus/series.dart' show PowerSeries, SeriesExtension;
export 'src/symbolic/calculus/summation.dart' show SummationExtension;
export 'src/symbolic/compiler.dart'
    show CompilerExtension, CompilerIterableExtension;
export 'src/symbolic/compiler/bytecode.dart' show Op;
export 'src/symbolic/compiler/evaluator.dart' show BytecodeEvaluator;
export 'src/symbolic/functions/fn.dart' show Fn;
export 'src/symbolic/linear/matrix.dart'
    show SymbolicEigenpair, SymbolicMatrixExtension, SymbolicVectorExtension;
export 'src/symbolic/parser.dart' show ExprFunctionInfo, ExprSyntax;
export 'src/symbolic/solver/ode.dart' show OdeExtension;
export 'src/symbolic/solver/polynomial_system.dart' show PolynomialSystemMethod;
export 'src/symbolic/solver/system.dart' show SystemSolverExtension;
export 'src/symbolic/solver/univariate.dart' show SolverExtension;
export 'src/symbolic/textualization/latex.dart' show LatexExtension;
export 'src/symbolic/textualization/mathml.dart'
    show MathMlExtension, PowerSeriesMathMlExtension;
export 'src/symbolic/textualization/string.dart' show TextExtension;
export 'src/symbolic/type/expr_data_type.dart'
    show ExprDataType, ExprEquality, ExprField, exprDataType;
