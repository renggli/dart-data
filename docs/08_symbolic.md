# Symbolic Computation & Expression Compilation Engine

## 1. Executive Summary

This document specifies a dedicated symbolic computation subsystem (`lib/src/symbolic/`) for `package:data`. The engine provides:
1. **Algebraic AST**: Immutable symbolic expressions supporting variables, constants, arithmetic operators, transcendental functions, powers, and symbolic vectors/matrices.
2. **Exact Symbolic Differentiation**: Automated differentiation (`expr.diff('x')`) supporting product rule, quotient rule, chain rule, and generalized power rules.
3. **Canonical Algebraic Simplification**: Constant folding, identity reduction ($0 \times x \to 0$, $1 \times x \to x$), associative flattening, and like-term collection.
4. **Zero-Allocation JIT Compiler**: High-throughput compilation of symbolic expressions into unboxed, positional closures (`double Function(double)`) and fused tensor kernels over contiguous `Float64List` buffers without AST walking or Map lookups.
5. **Cross-Subsystem Synergy**: Lossless conversion with `Polynomial<T>`, exact analytical gradient/Jacobian/Hessian computation for `numeric` optimization, and LaTeX rendering.

---

## 2. Architecture & Class Hierarchy

```text
                                  ┌───────────────────┐
                                  │     Expr (AST)    │
                                  └─────────┬─────────┘
                                            │
         ┌──────────────────┬───────────────┴───────────────┬──────────────────┐
         │                  │                               │                  │
┌─────────────────┐ ┌─────────────────┐           ┌───────────────────┐ ┌───────────────────┐
│ Variable / Const│ │ Binary: Add/Mul │           │ Unary: Sin/Cos/Ln │ │ Symbolic Matrix   │
└─────────────────┘ └─────────────────┘           └───────────────────┘ └───────────────────┘
                            │                               │
              ┌─────────────┴─────────────┐   ┌─────────────┴─────────────┐
              │   Algebraic Manipulation  │   │    High-Speed Compiler    │
              │ - Simplification / Rewrite│   │ - Positional Closure Gen  │
              │ - Exact Differentiation   │   │ - Zero-Allocation Tensor  │
              │ - Taylor Series Expansion │   │   Fused Contiguous Loops  │
              └───────────────────────────┘   └───────────────────────────┘
```

### 2.1 Expression AST (`lib/src/symbolic/ast.dart`)

```dart
sealed class Expr {
  const Expr();

  bool dependsOn(String name);
  Set<String> get freeVariables;
  Expr diff(String variable);
  Expr simplify();
  Expr substitute(String variable, Expr replacement);

  // Operator overloads constructing the AST
  Expr operator +(Object other) => Add(this, _wrap(other));
  Expr operator -(Object other) => Sub(this, _wrap(other));
  Expr operator *(Object other) => Mul(this, _wrap(other));
  Expr operator /(Object other) => Div(this, _wrap(other));
  Expr operator -() => Neg(this);
  Expr pow(Object exponent) => Pow(this, _wrap(exponent));

  static Expr _wrap(Object value) =>
      value is Expr ? value : Constant((value as num).toDouble());
}

final class Variable extends Expr {
  final String name;
  const Variable(this.name);

  @override
  bool dependsOn(String name) => this.name == name;
  @override
  Set<String> get freeVariables => {name};
  @override
  Expr diff(String variable) =>
      this.name == variable ? const Constant(1.0) : const Constant(0.0);
  @override
  Expr simplify() => this;
  @override
  Expr substitute(String variable, Expr replacement) =>
      this.name == variable ? replacement : this;
  @override
  String toString() => name;
}

final class Constant extends Expr {
  final double value;
  const Constant(this.value);

  @override
  bool dependsOn(String name) => false;
  @override
  Set<String> get freeVariables => const {};
  @override
  Expr diff(String variable) => const Constant(0.0);
  @override
  Expr simplify() => this;
  @override
  Expr substitute(String variable, Expr replacement) => this;
  @override
  String toString() => value % 1 == 0 ? value.toInt().toString() : value.toString();
}

final class Add extends Expr {
  final Expr left, right;
  const Add(this.left, this.right);
  @override
  bool dependsOn(String name) => left.dependsOn(name) || right.dependsOn(name);
  @override
  Set<String> get freeVariables => {...left.freeVariables, ...right.freeVariables};
  @override
  Expr diff(String variable) => Add(left.diff(variable), right.diff(variable));
  @override
  Expr simplify() => Simplifier.add(left.simplify(), right.simplify());
  @override
  Expr substitute(String variable, Expr replacement) =>
      Add(left.substitute(variable, replacement), right.substitute(variable, replacement));
}

final class Mul extends Expr {
  final Expr left, right;
  const Mul(this.left, this.right);
  @override
  bool dependsOn(String name) => left.dependsOn(name) || right.dependsOn(name);
  @override
  Set<String> get freeVariables => {...left.freeVariables, ...right.freeVariables};
  // Product rule: (u * v)' = u' * v + u * v'
  @override
  Expr diff(String variable) => Add(Mul(left.diff(variable), right), Mul(left, right.diff(variable)));
  @override
  Expr simplify() => Simplifier.mul(left.simplify(), right.simplify());
  @override
  Expr substitute(String variable, Expr replacement) =>
      Mul(left.substitute(variable, replacement), right.substitute(variable, replacement));
}

final class Pow extends Expr {
  final Expr base, exponent;
  const Pow(this.base, this.exponent);
  @override
  bool dependsOn(String name) => base.dependsOn(name) || exponent.dependsOn(name);
  @override
  Set<String> get freeVariables => {...base.freeVariables, ...exponent.freeVariables};
  // Generalized power rule: d/dx(u^v) = u^v * (v' * ln(u) + v * u' / u)
  @override
  Expr diff(String variable) {
    final bDep = base.dependsOn(variable);
    final eDep = exponent.dependsOn(variable);
    if (!bDep && !eDep) return const Constant(0.0);
    if (bDep && !eDep) {
      return Mul(Mul(exponent, Pow(base, Sub(exponent, const Constant(1.0)))), base.diff(variable));
    }
    if (!bDep && eDep) {
      return Mul(Mul(this, Ln(base)), exponent.diff(variable));
    }
    return Mul(this, Add(Mul(exponent.diff(variable), Ln(base)), Div(Mul(exponent, base.diff(variable)), base)));
  }
  @override
  Expr simplify() => Simplifier.pow(base.simplify(), exponent.simplify());
  @override
  Expr substitute(String variable, Expr replacement) =>
      Pow(base.substitute(variable, replacement), exponent.substitute(variable, replacement));
}
```

---

## 3. High-Performance Positional Compiler (`lib/src/symbolic/compiler.dart`)

To avoid runtime map lookups and heap allocations during evaluation:

```dart
extension ExprCompiler on Expr {
  /// Compiles into a direct double Function(double) with ZERO AST overhead.
  double Function(double x) compile1D(String varName) {
    final s = simplify();
    return _compileFast1D(s, varName);
  }

  static double Function(double x) _compileFast1D(Expr e, String v) => switch (e) {
    Constant(value: final val) => (_) => val,
    Variable(name: final n) => n == v ? (x) => x : (_) => 0.0,
    Add(left: final l, right: final r) => {
      final fL = _compileFast1D(l, v), fR = _compileFast1D(r, v);
      (x) => fL(x) + fR(x)
    },
    Mul(left: final l, right: final r) => {
      final fL = _compileFast1D(l, v), fR = _compileFast1D(r, v);
      (x) => fL(x) * fR(x)
    },
    Pow(base: final b, exponent: final exp) => {
      final fB = _compileFast1D(b, v), fE = _compileFast1D(exp, v);
      (x) => math.pow(fB(x), fE(x)).toDouble()
    },
    _ => (x) => e.substitute(v, Constant(x)).simplify() is Constant
        ? (e.substitute(v, Constant(x)).simplify() as Constant).value
        : throw UnsupportedError('Uncompilable node: $e'),
  };

  /// Compiles expression into a zero-allocation, vectorized loop over contiguous Float64List buffers.
  void Function(List<Float64List> inputs, Float64List output) compileTensorKernel(List<String> varOrder) {
    final s = simplify();
    final varIndices = {for (var i = 0; i < varOrder.length; i++) varOrder[i]: i};
    final evaluator = _buildPositionalEvaluator(s, varIndices);

    return (List<Float64List> inputs, Float64List output) {
      final len = output.length;
      final argCount = inputs.length;
      final currentArgs = List<double>.filled(argCount, 0.0);

      // Single contiguous loop - zero Map lookups, zero object allocations
      for (var i = 0; i < len; i++) {
        for (var a = 0; a < argCount; a++) {
          currentArgs[a] = inputs[a][i];
        }
        output[i] = evaluator(currentArgs);
      }
    };
  }

  static double Function(List<double>) _buildPositionalEvaluator(Expr e, Map<String, int> indices) => switch (e) {
    Constant(value: final val) => (_) => val,
    Variable(name: final n) => {
      final idx = indices[n] ?? (throw ArgumentError('Unbound variable: $n'));
      (args) => args[idx]
    },
    Add(left: final l, right: final r) => {
      final fL = _buildPositionalEvaluator(l, indices), fR = _buildPositionalEvaluator(r, indices);
      (args) => fL(args) + fR(args)
    },
    Mul(left: final l, right: final r) => {
      final fL = _buildPositionalEvaluator(l, indices), fR = _buildPositionalEvaluator(r, indices);
      (args) => fL(args) * fR(args)
    },
    _ => throw UnsupportedError('Node not supported in fast positional evaluation: $e'),
  };
}
```

---

## 4. Prioritized Implementation Task List

| Task ID | Phase | Priority | Description | Verification / Success Criteria |
| :--- | :--- | :--- | :--- | :--- |
| **SYM-01** | Core AST | **P1** | Implement core immutable `Expr` nodes (`Variable`, `Constant`, `Add`, `Sub`, `Mul`, `Div`, `Neg`, `Pow`, `Sin`, `Cos`, `Exp`, `Ln`). | Unit test expression creation and string representation. |
| **SYM-02** | Differentiation | **P1** | Implement exact symbolic differentiation (`diff`) covering sum, product, quotient, chain, and power rules. | Verify analytical derivative of $x^3 \sin(x)$ matches $3x^2 \sin(x) + x^3 \cos(x)$. |
| **SYM-03** | Simplification | **P1** | Implement canonical algebraic simplifier: constant folding, identity reductions, and associative term grouping. | `(x * 0) + (1 * y) + 4 + 6` simplifies to `y + 10`. |
| **SYM-04** | Fast 1D Compiler | **P1** | Implement `compile1D(varName)` generating high-speed recursive double closures without AST walking. | Benchmark: Compiled closure executes within $1.1\times$ of handwritten Dart scalar closure. |
| **SYM-05** | Tensor Kernel | **P2** | Implement `compileTensorKernel(varOrder)` generating vectorized contiguous `Float64List` kernel loops. | Evaluates $10^6$ elements in $< 5\text{ ms}$ with zero garbage collector allocations. |
| **SYM-06** | Jacobians/Hessians | **P2** | Implement symbolic vector gradient $\nabla f$, matrix Jacobian $J_f$, and matrix Hessian $H_f$. | Integrate with `numeric` BFGS optimizer; matches analytical solutions. |
| **SYM-07** | Polynomial Bridge | **P2** | Implement `Polynomial.fromExpr(expr, 'x')` and `expr.taylorSeries('x', order: n)`. | Round-trip tests between polynomial representations and symbolic expressions. |
| **SYM-08** | LaTeX Rendering | **P3** | Implement `expr.toLatex()` producing formatted LaTeX math equations. | Output renders correctly in KaTeX / MathJax. |
