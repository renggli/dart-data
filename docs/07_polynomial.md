# Subsystem Architecture: Polynomials & Orthogonal Function Systems

## 1. Overview & Current Deficiencies

The `polynomial` subsystem ([lib/src/polynomial/](../lib/src/polynomial/)) provides representations and operations for 1D polynomials, including evaluation (Horner's method), differentiation, integration, arithmetic ($+$, $-$, $\times$), and root finding.

However, several architectural shortcomings and algorithmic gaps limit its effectiveness in scientific and numerical contexts.

### 1.1 Identified Deficiencies & Issues

1. **Ill-Conditioned Monomial Basis for High Degrees**:
   - The current `Polynomial<T>` implementation represents polynomials strictly in the standard monomial power basis:
     $$P(x) = c_0 + c_1 x + c_2 x^2 + \dots + c_n x^n$$
   - Monomial bases are notoriously ill-conditioned for higher degrees ($n \ge 6$), leading to severe numerical cancellation, loss of significance, and Runge's phenomenon.
   - Missing orthogonal polynomial bases:
     - **Chebyshev Polynomials** ($T_n(x)$ of the first kind and $U_n(x)$ of the second kind): Optimal minimax approximation of continuous functions.
     - **Legendre Polynomials** ($P_n(x)$): Essential for Gauss-Legendre quadrature and spherical harmonics.
     - **Hermite Polynomials** ($H_n(x)$): Central to quantum mechanics, Gaussian integrals, and probability.
     - **Laguerre Polynomials** ($L_n(x)$): Key to radial wavefunctions and semi-infinite domain integration.

2. **Missing Algebraic Operations**:
   - **Greatest Common Divisor (GCD)**: Computing the polynomial GCD via Euclidean or subresultant algorithms is missing.
   - **Polynomial Composition**: Calculating $P(Q(x))$ (evaluating one polynomial with another) is not supported.
   - **Rational Functions**: Representing rational quotients $\frac{P(x)}{Q(x)}$ with pole evaluation and partial fraction expansion.

3. **Unchecked Memory Aliasing in `Polynomial.copyInto`**:
   - In [`lib/src/polynomial/polynomial.dart:189-196`](../lib/src/polynomial/polynomial.dart#L189-L196):

     ```dart
     Polynomial<T> copyInto(Polynomial<T> target) {
       assert(degree == target.degree, ...);
       if (this != target) {
         for (var i = 0; i <= degree; i++) {
           target.setUnchecked(i, getUnchecked(i));
         }
       }
       return target;
     }
     ```

     If the target polynomial shares memory with a transformed view (e.g. `p.shift(-1).copyInto(p)` or a polynomial view over vector/matrix storage), writing elements in-place corrupts elements that will be read later in the iteration.

---

## 2. Target Design & Architecture

```
+-------------------------------------------------------------------------+
|                          Polynomial Subsystem                           |
+-------------------------------------------------------------------------+
        |                                                 |
+------------------------------+        +---------------------------------+
|      Polynomial Bases        |        |      Algebraic Operations       |
|  - MonomialPolynomial        |        |  - Euclidean GCD                |
|  - ChebyshevPolynomial (T, U)|        |  - Composition P(Q(x))          |
|  - LegendrePolynomial        |        |  - Division with Remainder      |
|  - HermitePolynomial         |        |  - RationalFunction (P / Q)     |
+------------------------------+        +---------------------------------+
```

### 2.1 Abstract Polynomial Interface

Unify monomial and orthogonal polynomial representations under a common contract:

```dart
abstract class Polynomial<T> implements Storage {
  DataType<T> get dataType;
  int get degree;
  
  T getCoefficient(int index);
  T evaluate(T x);
  
  Polynomial<T> derivative({int order = 1});
  Polynomial<T> integrate({T? constant});
  
  Polynomial<T> add(Polynomial<T> other);
  Polynomial<T> sub(Polynomial<T> other);
  Polynomial<T> mul(Polynomial<T> other);
  (Polynomial<T> quotient, Polynomial<T> remainder) divRem(Polynomial<T> other);
}
```

### 2.2 Orthogonal Polynomial Families

Implement orthogonal series using Clenshaw's recurrence algorithm for fast and stable evaluation $O(N)$:

```dart
class ChebyshevPolynomial<T> implements Polynomial<T> {
  final List<T> _coefficients; // c_0 T_0(x) + c_1 T_1(x) + ...
  
  @override
  T evaluate(T x) {
    // Clenshaw recurrence evaluation
    // y_{k} = 2*x*y_{k+1} - y_{k+2} + c_k
  }
  
  MonomialPolynomial<T> toMonomial();
  static ChebyshevPolynomial<double> interpolate(double Function(double) f, int degree);
}
```

### 2.3 Polynomial Greatest Common Divisor (GCD)

Implement the Euclidean algorithm with monic normalization:

```dart
Polynomial<T> polynomialGcd<T>(Polynomial<T> a, Polynomial<T> b) {
  var r0 = a;
  var r1 = b;
  while (!r1.isZero) {
    final (_, rem) = r0.divRem(r1);
    r0 = r1;
    r1 = rem;
  }
  return r0.monic();
}
```

### 2.4 Rational Functions

Represent quotients of polynomials $R(x) = \frac{P(x)}{Q(x)}$:

```dart
class RationalFunction<T> {
  final Polynomial<T> numerator;
  final Polynomial<T> denominator;
  
  RationalFunction(this.numerator, this.denominator) {
    assert(!denominator.isZero, 'Denominator cannot be zero');
    // Simplify via GCD
  }
  
  T evaluate(T x) => numerator.evaluate(x) / denominator.evaluate(x);
}
```

---

## 3. Prioritized Implementation Task List

| Task ID | Phase | Priority | Description | Verification / Success Criteria |
| :--- | :--- | :--- | :--- | :--- |
| **POL-01** | Correctness | **P0** | Guard against memory aliasing in `Polynomial.copyInto` ([lib/src/polynomial/polynomial.dart:189-196](../lib/src/polynomial/polynomial.dart#L189-L196)) using overlap detection. | Add test verifying `p.shift(-1).copyInto(p)` evaluates without corrupting coefficients. |
| **POL-02** | Arithmetic | **P1** | Implement polynomial division with remainder (`divRem`) returning both quotient and remainder. | Test $(A \cdot B + R).divRem(B) == (A, R)$. |
| **POL-03** | GCD | **P1** | Implement polynomial Greatest Common Divisor (GCD) using the Euclidean algorithm. | Compute $\gcd((x-1)(x-2), (x-1)(x-3)) == (x-1)$. |
| **POL-04** | Composition | **P1** | Implement polynomial composition $P(Q(x))$ supporting nested polynomial evaluation. | Evaluate $P(Q(x))$ matches direct function composition $x \mapsto P(Q(x))$. |
| **POL-05** | Chebyshev | **P2** | Implement `ChebyshevPolynomial` (first and second kind) using Clenshaw's recurrence algorithm. | Chebyshev approximation of $\sin(x)$ on $[-1, 1]$ achieves minimax error bound. |
| **POL-06** | Legendre/Hermite | **P2** | Implement `LegendrePolynomial` and `HermitePolynomial` with 3-term recurrence relations. | Verify orthogonality: $\int_{-1}^1 P_m(x) P_n(x) dx = 0$ for $m \ne n$. |
| **POL-07** | Rational Func | **P3** | Implement `RationalFunction<T>` with automatic GCD simplification and differentiation. | Test evaluation and derivative of $\frac{1}{1 + x^2}$. |
