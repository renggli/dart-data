# Implementation

Each AST node, data type, and symbolic algorithm in the library is structured around explicit data fields, strict invariants, and deterministic transformation passes.

## Base Expression Metadata

Every node in the syntax tree inherits from a single sealed Expr base type and stores two pieces of metadata alongside its payload:

- Cached Structural Hash: A 32-bit integer computed lazily once from the node's type and children. Because nodes are immutable, hash table lookups and inequality checks (a.hash != b.hash) execute in constant time.
- Simplification Flag: A boolean indicating whether the subtree is already in canonical simplified form. Any transformation pass checks this flag first to avoid re-traversing simplified subtrees.
- Canonical Type Rank: Every node class defines a fixed integer rank (Integer < Rational < Real < Complex < Constant < Variable < Add < Mul < Pow < Function < Integral < Matrix) so any two expressions can be compared and sorted deterministically.

## Representation of Numbers, Constants, and Variables

### Integers (Integer)

- Data Stored: A single zero-cost unified integer backed by an untyped Object reference that holds either a native 64-bit machine int or an arbitrary-precision BigInt.
- Invariants: Values within ±(2^30 - 1) are always stored as a native machine int (which the 64-bit Dart runtime keeps unallocated inside the pointer tag). Values outside that range are always stored as a BigInt. Because the ranges never overlap, equality and hashing are exact, and multiplying two small integers never overflows 64 bits before range promotion.

### Rational Fractions (Rational)

- Data Stored: Two ExactInt fields: numerator and denominator.
- Invariants:
  - numerator and denominator are always coprime (divided by their greatest common divisor at construction).
  - denominator is strictly greater than 1 (the sign is always stored in numerator).
  - Auto-Demotion: If an operation produces a denominator of 1 (or a numerator of 0), the constructor returns an Integer node instead of a Rational node.

### Floating-Point Reals (Real)

- Data Stored: A 64-bit IEEE-754 double (or an arbitrary-precision decimal float).
- Invariants:
  - -0.0 is normalized to +0.0 so equal floats always produce identical hash codes.
  - Contagion: Combining an exact number (Integer or Rational) with a Real promotes the result to a Real, except when multiplying by an exact 0, which yields exact Integer(0).

### Complex Numbers (Complex)

- Data Stored: Two RealNumeric fields: re (real part) and im (imaginary part).
- Invariants:
  - The static type of re and im is restricted to RealNumeric (Integer, Rational, or Real). This allows a single Complex node to represent Gaussian integers (3 + 4i), Gaussian rationals (1/2 - 3/7i), or complex floats (1.5 + 2.0i), while making nested complex numbers impossible.
  - im is never zero. If arithmetic cancels the imaginary part to zero, the constructor automatically demotes and returns re as a RealNumeric.

### Constants (Constant) vs. Algebraic Numbers

- Transcendental Constants (pi, e, eulerGamma): Stored as a Constant node containing an enum identifier and a floating-point evaluation value. In algebraic sums and products, they behave like immutable symbols (2*pi + 3*pi -> 5*pi).
- Algebraic Constants (sqrt(2), golden ratio): Never stored as Constant nodes. Instead, sqrt(2) is stored as a power node Pow(2, 1/2). This allows standard exponent rules to simplify sqrt(2)* sqrt(2) -> 2 and 2 / sqrt(2) -> sqrt(2) without special constant rules.

Variables (Variable)

- Data Stored: A name string (e.g., "x") and a domain assumption enum (any, real, positive, integer).
- Invariants: Domain assumptions govern conditional simplifications (for example, (x^2)^(1/2) simplifies to x only if x is marked positive).

## Structure of Operations (Sums, Products, Powers, Functions)

### Sums (Add)

- Data Stored: A flat, fixed-length list of child expressions (`List<Expr>`).
- How Subtraction is Represented: There is no Subtract node. a - b is represented as Add([a, Mul([-1, b])]).
- Canonical Simplified Form:
  - Flattened: An Add never contains another Add as a direct child.
  - Like terms merged: Symbolic terms with identical bodies have their numeric coefficients summed (2*x + 3*x becomes a single Mul([5, x]) inside the Add).
  - Sorted: Symbolic terms are ordered by the total canonical ordering, followed by at most one non-zero Numeric constant at the end of the list.
  - Collapsed: If all terms cancel out, Add collapses to Integer(0); if one term remains, it unwraps to that single expression.

### Products (Mul)

- Data Stored: A flat, fixed-length list of child expressions (`List<Expr>`).
- How Negation and Division are Represented: There are no Negate or Divide nodes. -x is Mul([-1, x]), and a / b is Mul([a, Pow(b, -1)]).
- Canonical Simplified Form:
  - Flattened: A Mul never contains another Mul as a direct child.
  - Single leading coefficient: All numeric factors are multiplied together and placed at index 0 (or omitted if equal to 1). If the numeric coefficient is 0, the entire Mul collapses to Integer(0).
  - Merged exponents: Factors sharing the same base have their exponents added (x^2 *x^3 -> Pow(x, 5), and x* x^-1 -> 1).
  - Sorted: All non-numeric factors are sorted in canonical order.

### Powers and Roots (Pow)

- Data Stored: Two child expressions: base (`Expr`) and exponent (`Expr`).
- How Roots and Exponentials are Represented:
  - Square root sqrt(x) is Pow(x, Rational(1, 2)).
  - N-th root root(x, n) is Pow(x, Rational(1, n)).
  - Reciprocal 1 / x is Pow(x, Integer(-1)).
  - Natural exponential exp(x) is Pow(Constant.e, x).
- Canonical Simplified Form:
  - Trivial powers collapse: x^0 -> 1, x^1 -> x, 1^x -> 1, and 0^x -> 0 (for positive x).
  - Exact integer powers of Integer and Rational evaluate immediately ((2/3)^-2 -> 9/4).
  - Radical extraction: When a positive Integer is raised to a Rational exponent p/q, small prime powers k^q are factored out of the base (12^(1/2) -> 2 * 3^(1/2)).
  - Negative square roots convert to complex numbers: (-4)^(1/2) -> 2i.

### Elementary Functions (UnaryFunc / BinaryFunc)

- Data Stored: The argument expression (arg) inside specific subclasses (Sin, Cos, Tan, Asin, Acos, Atan, Ln), plus a funcOrder integer for canonical sorting.
- Canonical Simplified Form:
  - Exact evaluation at known points (sin(0) -> 0, cos(pi) -> -1, ln(1) -> 0, ln(e^x) -> x).
  - Parity extraction: If the argument has a negative leading coefficient, odd functions pull the minus sign outside (sin(-2*x) -> -sin(2*x)) and even functions drop it (cos(-2*x) -> cos(2*x)).

## Matrices and Vectors (MatrixExpr)

- Data Stored:
  - rows (`int`) and cols (`int`).
  - data (`List<Expr>`): A single flat, fixed-length 1D array of length rows *cols in row-major order (entry (r, c) is stored at r* cols + c).
- Vectors: A column vector of dimension N is a MatrixExpr with rows = N, cols = 1; a row vector has rows = 1, cols = N.
- Algebraic Behavior:
  - Adding two MatrixExpr nodes of identical dimensions sums their elements entry-by-entry.
  - Multiplying a scalar Expr by a MatrixExpr inside Mul scales every entry of the matrix.
  - Matrix-matrix multiplication (matmul) is non-commutative, verifies left.cols == right.rows, and computes each cell as the simplified dot product of the corresponding row and column.
  - Determinants and inverses use direct closed-form expressions for 1x1, 2x2, and 3x3 matrices, and fraction-free Bareiss / Gauss-Jordan elimination for 4x4 and larger matrices.

## How Core Symbolic Algorithms Work

### Simplification (simplify)

Simplification is a bottom-up recursive pass that enforces canonical form without expanding products of sums:

Recursively simplify all child nodes (returning immediately if isSimplified is true)

1. In Add: Split every child into a (numericCoefficient, symbolicBody) pair. Insert symbolicBody into a hash map, adding numericCoefficient to any existing entry. Remove entries whose coefficient became 0, sort the surviving keys using compareTo, and rebuild Add.
2. In Mul: Multiply all Numeric children into a single running coefficient. Split remaining children into (base, exponent) pairs and accumulate exponents for identical bases in a hash map. Simplify each resulting Pow(base, exponent), sort the factors, and prepend the numeric coefficient.
3. In Pow and UnaryFunc: Apply local algebraic identities (radical extraction, exponent flattening (x^a)^n -> x^(a*n) for integer n, inverse function cancellation e^(ln(x)) -> x, and parity normalization).

### Expansion (expand)

Expansion eliminates nested parentheses by distributing multiplication over addition and expanding integer powers of sums:

Distributing Products (Mul): Recursively expand all factors. If any factors are Add nodes, compute the Cartesian product of their terms—multiplying every term of the first sum by every term of the next sum—and pass the resulting flat list of terms to Add.simplify() to combine like terms

1. Expanding Powers of Sums (Pow): When the base is an Add node and the exponent is a small positive Integer(n), apply the binomial/multinomial expansion (or repeated expanded multiplication) to turn (a + b)^n into a flat sum of monomials.
2. Structural Preservation: Simplification intentionally does not call expand() automatically because (x + 1)^100 is much more compact in factored form than as a 101-term polynomial.

### Factorization (factor)

Factorization reverses expansion, converting an Add node into a Mul of irreducible components:

Common Monomial Extraction (Content): Inspect all terms of an Add node. Compute the greatest common divisor (GCD) of all numeric coefficients and the minimum exponent of every symbolic base that appears in every term. Factor this common monomial out in front of the sum (6*x^3*y + 9*x^2*y^2 -> 3*x^2*y * (2*x + 3*y))

1. Difference of Squares & Cubes: If the remaining sum has two terms with even or cubic exponents and opposite signs (A^2 - B^2), rewrite directly into (A - B) * (A + B).
2. Univariate Polynomial Factoring: If the remaining sum is a polynomial in a single variable x:

- Extract the array of coefficients by degree [a_0, a_1, ..., a_n].
- Perform Square-Free Factorization by computing gcd(P(x), P'(x)) to separate repeated roots.
- For degree 2, apply the quadratic formula (keeping factors rational or radical as requested).
- For degree 3 and higher, test rational roots p / q (where p divides a_0 and q divides a_n) via synthetic division (Horner's method), dividing out (x - r) for each root found.

### Differentiation (differentiate)

Differentiation is a single top-down pass with respect to a target Variable(x) followed by .simplify():

- Leaves: Numeric and Constant nodes return 0. A Variable returns 1 if equal to x, or 0 otherwise.
- Sums (Add): Maps .differentiate(x) across all terms (d(u + v) = du + dv).
- Products (Mul): Applies the generalized product rule—producing an Add of N terms where the i-th term replaces factor i with its derivative while keeping all other factors intact.
- Powers (Pow(u, w)):
  - If w does not depend on x: returns w *Pow(u, w - 1)* du.
  - If u does not depend on x: returns Pow(u, w) *Ln(u)* dw.
  - If both u and w depend on x: applies logarithmic differentiation Pow(u, w) *(dw* Ln(u) + w *du / u).
- Functions (UnaryFunc): Multiplies the outer derivative by the inner derivative (du):
  - Sin(u) -> Cos(u)* du
  - Cos(u) -> -Sin(u) *du
  - Tan(u) -> Pow(Cos(u), -2)* du
  - Ln(u) -> Pow(u, -1) * du

### Symbolic Integration (integrate)

Integration runs a 5-stage pipeline to find an antiderivative with respect to Variable(x):

#### Constant & Linearity Extraction

- If the integrand does not contain x, return integrand * x.
- If the integrand is an Add, integrate each term separately and sum the results.
- If the integrand is a Mul, partition the factors into x-independent and x-dependent lists, pulling the x-independent product outside the integral.

1. Table Lookup & Affine Argument Scaling:

- Check if the integrand matches an elementary form f(a*x + b) where a and b are independent of x:
  - (a*x + b)^(-1) -> Ln(a*x + b) / a
  - (a*x + b)^n -> (a*x + b)^(n + 1) / (a * (n + 1))
  - e^(a*x + b) -> e^(a*x + b) / a
  - Sin(a*x + b) -> -Cos(a*x + b) / a
  - Cos(a*x + b) -> Sin(a*x + b) / a

1. Heuristic Substitution ("Derivative-Divides"):

- Collect candidate inner subexpressions u(x) from bases, exponents, and function arguments.
- For each candidate u(x), compute its derivative du = u.differentiate(x), form the simplified quotient q = (integrand / du).simplify(), and structurally replace u(x) with a fresh dummy variable uVar.
- If q no longer depends on x, recursively integrate q with respect to uVar and substitute u(x) back into the result. (For example, on 2 *x* cos(x^2), testing u = x^2 gives du = 2*x, leaving cos(u), which integrates immediately to sin(x^2)).

1. Integration by Parts (LIATE Priority):

- If the integrand is a product Mul that failed substitution, rank its factors using the LIATE hierarchy: Logarithmic (Ln) > Inverse trig > Algebraic (x^n) > Trigonometric (Sin, Cos) > Exponential (e^x).
- Assign the highest-priority factor to u and the remaining factors to dv. Compute v = integrate(dv, x) and du = u.differentiate(x). If v succeeds, return u *v - integrate(v* du, x) (bounded to a maximum recursion depth of 2 to prevent infinite loops).

1. Symbolic Fallback (Integral Node):

- If none of the stages find a closed-form elementary antiderivative (e.g., e^(-x^2)), return an unevaluated Integral(integrand, x) AST node. If that node is later differentiated with respect to x, it immediately simplifies back to integrand via the Fundamental Theorem of Calculus.
