import '../../linear/matrix.dart';
import '../../linear/vector.dart';
import '../algebra/simplify.dart';
import '../assumptions.dart';
import '../ast.dart';
import '../type/expr_data_type.dart';
import 'differentiation.dart';

/// Multivariable calculus extensions on [Expr].
extension MultivariableExtension on Expr {
  /// Computes the analytical gradient vector:
  /// $\nabla f =$
  /// $\left(\frac{\partial f}{\partial x_1}, \dots,\right.$
  /// $\left.\frac{\partial f}{\partial x_n}\right)$
  /// as a [Vector] of symbolic expressions.
  ///
  /// Conceptually, the gradient points in the direction of steepest ascent on a
  /// multivariate surface. Formally, this yields the covector of first-order
  /// partial derivatives.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final y = Variable('y');
  /// final grad = (x * x + y * y).gradient(['x', 'y']);
  /// // grad[0]: 2 * x, grad[1]: 2 * y
  /// ```
  Vector<Expr> gradient(
    List<String> variables, {
    Assumptions assumptions = Assumptions.none,
  }) => _multivariableGradient(this, variables, assumptions: assumptions);

  /// Computes the analytical Hessian matrix
  /// $H_{ij} = \frac{\partial^2 f}{\partial x_i \partial x_j}$
  /// as a symmetric [Matrix] of symbolic expressions.
  ///
  /// Conceptually, the Hessian describes the local curvature or concavity of a
  /// multivariate surface. Formally, this is the symmetric matrix of second
  /// partial derivatives used in multivariate optimization and critical point
  /// classification.
  ///
  /// Exploits Clairaut's symmetry theorem to compute only the upper triangle
  /// ($j \ge i$) and mirror identical expressions to the lower triangle
  /// ($H_{ji} = H_{ij}$), halving the number of second derivative and
  /// simplification passes from $n^2$ to $\frac{n(n+1)}{2}$.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final y = Variable('y');
  /// final h = (x * x + x * y * 3).hessian(['x', 'y']);
  /// // h[0][0]: 2, h[0][1]: 3, h[1][0]: 3, h[1][1]: 0
  /// ```
  Matrix<Expr> hessian(
    List<String> variables, {
    Assumptions assumptions = Assumptions.none,
  }) => _multivariableHessian(this, variables, assumptions: assumptions);

  /// Computes the analytical Laplacian scalar field:
  /// $\Delta f = \nabla^2 f = \sum_{i=1}^n \frac{\partial^2 f}{\partial x_i^2}$.
  ///
  /// Conceptually, the Laplacian measures the difference between the value of
  /// the function at a point and the average value in its infinitesimal
  /// neighborhood. Formally, it is the divergence of the gradient
  /// ($\text{div}(\nabla f)$) or the trace of the Hessian matrix.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final y = Variable('y');
  /// final lap = (x * x * x + y * y * y).laplacian(['x', 'y']);
  /// // lap: 6 * x + 6 * y
  /// ```
  Expr laplacian(
    List<String> variables, {
    Assumptions assumptions = Assumptions.none,
  }) => _multivariableLaplacian(this, variables, assumptions: assumptions);
}

/// Multivariable calculus extensions on collections of [Expr].
extension MultivariableIterableExtension on Iterable<Expr> {
  /// Computes the analytical Jacobian matrix
  /// $J_{ij} = \frac{\partial f_i}{\partial x_j}$
  /// as a [Matrix] of symbolic expressions.
  ///
  /// Conceptually, the Jacobian shows how each component of a multivariable
  /// vector system changes with respect to each input variable. Formally, this
  /// represents the linear approximation / pushforward map of a vector-valued
  /// function $F: \mathbb{R}^n \to \mathbb{R}^m$.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final y = Variable('y');
  /// final jac = [x * y, x + y].jacobian(['x', 'y']);
  /// // jac[0][0]: y, jac[0][1]: x
  /// // jac[1][0]: 1, jac[1][1]: 1
  /// ```
  Matrix<Expr> jacobian(
    List<String> variables, {
    Assumptions assumptions = Assumptions.none,
  }) => _multivariableJacobian(toList(), variables, assumptions: assumptions);

  /// Computes the analytical divergence of this vector field:
  /// $\text{div}(F) = \nabla \cdot F = \sum_{i=1}^n \frac{\partial F_i}{\partial x_i}$.
  ///
  /// Conceptually, divergence measures the outgoing flux density of a vector
  /// field from an infinitesimal volume around a point (source vs sink).
  /// Formally, it is the trace of the Jacobian matrix.
  ///
  /// Throws [ArgumentError] if the number of vector field components does not
  /// equal the number of [variables].
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final y = Variable('y');
  /// final div = [x * x * y, x * y * y].divergence(['x', 'y']);
  /// // div: 2 * x * y + 2 * x * y = 4 * x * y
  /// ```
  Expr divergence(
    List<String> variables, {
    Assumptions assumptions = Assumptions.none,
  }) => _multivariableDivergence(toList(), variables, assumptions: assumptions);

  /// Computes the analytical curl of this 3-dimensional vector field:
  /// $\text{curl}(F) = \nabla \times F = \left(\frac{\partial F_z}{\partial y} - \frac{\partial F_y}{\partial z}, \frac{\partial F_x}{\partial z} - \frac{\partial F_z}{\partial x}, \frac{\partial F_y}{\partial x} - \frac{\partial F_x}{\partial y}\right)$.
  ///
  /// Conceptually, curl measures the microscopic rotation or circulation
  /// density of a vector field around a point.
  ///
  /// Throws [ArgumentError] if the vector field does not have exactly 3 components
  /// or if [variables] does not have exactly 3 elements.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final y = Variable('y');
  /// final z = Variable('z');
  /// final c = [-y, x, IntegerNumber.zero].curl(['x', 'y', 'z']);
  /// // c: [0, 0, 2]
  /// ```
  Vector<Expr> curl(
    List<String> variables, {
    Assumptions assumptions = Assumptions.none,
  }) => _multivariableCurl(toList(), variables, assumptions: assumptions);
}

/// Computes the analytical Laplacian scalar field $\Delta f = \nabla^2 f$.
Expr laplacian(
  Expr function,
  List<String> variables, {
  Assumptions assumptions = Assumptions.none,
}) => _multivariableLaplacian(function, variables, assumptions: assumptions);

/// Computes the analytical divergence $\text{div}(F) = \nabla \cdot F$.
Expr divergence(
  Iterable<Expr> vectorField,
  List<String> variables, {
  Assumptions assumptions = Assumptions.none,
}) => _multivariableDivergence(
  vectorField.toList(),
  variables,
  assumptions: assumptions,
);

/// Computes the analytical curl $\text{curl}(F) = \nabla \times F$.
Vector<Expr> curl(
  Iterable<Expr> vectorField,
  List<String> variables, {
  Assumptions assumptions = Assumptions.none,
}) => _multivariableCurl(
  vectorField.toList(),
  variables,
  assumptions: assumptions,
);

Vector<Expr> _multivariableGradient(
  Expr function,
  List<String> variables, {
  Assumptions assumptions = Assumptions.none,
}) => Vector<Expr>.generate(
  variables.length,
  (i) => function.derivative(variables[i], assumptions: assumptions),
  type: exprDataType,
);

Matrix<Expr> _multivariableJacobian(
  List<Expr> functions,
  List<String> variables, {
  Assumptions assumptions = Assumptions.none,
}) {
  final m = functions.length;
  final n = variables.length;
  return Matrix<Expr>.generate(
    m,
    n,
    (r, c) => functions[r].derivative(variables[c], assumptions: assumptions),
    type: exprDataType,
  );
}

Matrix<Expr> _multivariableHessian(
  Expr function,
  List<String> variables, {
  Assumptions assumptions = Assumptions.none,
}) {
  final n = variables.length;
  final grad = _multivariableGradient(
    function,
    variables,
    assumptions: assumptions,
  );
  final entries = List<Expr?>.filled(n * n, null);
  for (var i = 0; i < n; i++) {
    final df = grad[i];
    for (var j = i; j < n; j++) {
      final d2f = df.derivative(variables[j], assumptions: assumptions);
      entries[i * n + j] = d2f;
      entries[j * n + i] = d2f;
    }
  }
  return Matrix<Expr>.generate(
    n,
    n,
    (r, c) => entries[r * n + c]!,
    type: exprDataType,
  );
}

Expr _multivariableLaplacian(
  Expr function,
  List<String> variables, {
  Assumptions assumptions = Assumptions.none,
}) {
  if (variables.isEmpty) return IntegerNumber.zero;
  final terms = <Expr>[];
  for (final v in variables) {
    final d2f = function
        .derivative(v, assumptions: assumptions)
        .derivative(v, assumptions: assumptions);
    terms.add(d2f);
  }
  return Add(terms).simplify(assumptions: assumptions);
}

Expr _multivariableDivergence(
  List<Expr> vectorField,
  List<String> variables, {
  Assumptions assumptions = Assumptions.none,
}) {
  if (vectorField.length != variables.length) {
    throw ArgumentError(
      'Vector field dimension (${vectorField.length}) must match variable count (${variables.length}).',
    );
  }
  if (vectorField.isEmpty) return IntegerNumber.zero;
  final terms = <Expr>[];
  for (var i = 0; i < vectorField.length; i++) {
    terms.add(
      vectorField[i].derivative(variables[i], assumptions: assumptions),
    );
  }
  return Add(terms).simplify(assumptions: assumptions);
}

Vector<Expr> _multivariableCurl(
  List<Expr> vectorField,
  List<String> variables, {
  Assumptions assumptions = Assumptions.none,
}) {
  if (vectorField.length != 3 || variables.length != 3) {
    throw ArgumentError(
      'Curl is defined for 3-dimensional vector fields with 3 variables (got ${vectorField.length} components and ${variables.length} variables).',
    );
  }
  final fx = vectorField[0];
  final fy = vectorField[1];
  final fz = vectorField[2];
  final x = variables[0];
  final y = variables[1];
  final z = variables[2];

  final cx =
      (fz.derivative(y, assumptions: assumptions) -
              fy.derivative(z, assumptions: assumptions))
          .simplify(assumptions: assumptions);
  final cy =
      (fx.derivative(z, assumptions: assumptions) -
              fz.derivative(x, assumptions: assumptions))
          .simplify(assumptions: assumptions);
  final cz =
      (fy.derivative(x, assumptions: assumptions) -
              fx.derivative(y, assumptions: assumptions))
          .simplify(assumptions: assumptions);

  return Vector<Expr>.fromList([cx, cy, cz], type: exprDataType);
}
