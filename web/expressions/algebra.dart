import 'package:data/symbolic.dart';

/// Recursively checks whether [expr] explicitly references a non-real complex number.
bool containsImaginary(Expr expr) =>
    expr.anyNode((node) => node is ComplexNumber && !node.isReal);
