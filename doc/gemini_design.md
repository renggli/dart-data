# Symbolic Mathematics Library — High-Level Architecture

A Computer Algebra System (CAS) in Dart 3 achieves both symbolic expressiveness and high runtime performance by combining algebraic canonicalization, immutable value semantics, and compile-time zero-cost abstractions.

## Unified AST & Two-Phase Simplification

- Elimination of Inverse Operations: The syntax tree excludes dedicated nodes for subtraction, negation, division, and roots. Instead, negation and subtraction are represented as addition of negative products, division as multiplication by negative powers, and roots as fractional exponents. This reduces the number of algebraic rewrite, differentiation, and integration rules by more than half.
- Separation of Construction and Simplification: Building an expression via standard operators preserves the exact structure entered by the user so unsimplified expressions can be rendered faithfully. Simplification is an explicit pass that flattens nested operations, merges like terms, and marks the resulting subtree as simplified so subsequent passes short-circuit in constant time.

## Structural Value Semantics Without Interning

- Cached Structural Hashing: Every expression node is deeply immutable and caches its structural hash code lazyily. Checking inequality or looking up subexpressions in hash maps takes constant time.
- Total Canonical Ordering: All expression variants define a strict, deterministic ordering across node types (numbers, constants, variables, sums, products, powers, functions, matrices). Sorting operands into this canonical order guarantees that algebraically equivalent expressions produce identical trees and hash codes.
- Modern Dart Type System: The expression hierarchy uses sealed classes for exhaustive pattern matching, ephemeral records for zero-allocation term decomposition, and extension types to avoid wrapper overhead on primitives.

## The Atomic Number Tower & Constants

- Strict Separation of Numbers and Symbols: Exact numbers live in a dedicated sub-hierarchy at the leaves of the syntax tree and evaluate eagerly. Fractions and Gaussian complex numbers are single atomic nodes rather than symbolic division or addition trees.
- Automatic Demotion: Numeric operations always return the simplest representation—fractions with a unit denominator automatically demote to integers, and complex numbers with a zero imaginary part demote to real numbers.
- Zero-Cost Integer Unification: Machine integers and arbitrary-precision integers are unified under a single extension type. Everyday small integers remain unallocated in CPU registers (within a safe range that prevents multiplication overflow), spilling to heap-allocated big integers only when necessary.
- Transcendental vs. Algebraic Constants: Transcendental constants (such as pi and Euler's number) are represented as dedicated constant nodes with numeric metadata. Algebraic constants (such as the square root of 2) are represented as fractional powers of integers so standard exponent rules and prime-factor radical extraction simplify them automatically without special lookup tables.

## Algebraic Simplification & Calculus

- Hash-Based Term and Exponent Collection: Simplifying sums and products uses hash maps (keyed by the symbolic body or base) to accumulate numeric coefficients and merge exponents in linear time, sorting the surviving terms only once at the end.
- Symbolic Differentiation: Differentiation operates recursively over the minimal node set using the sum, product, and generalized logarithmic power rules, paired with chain-rule dispatch on elementary functions.
- Multi-Stage Symbolic Integration: Integration runs through a prioritized pipeline:

  1. Constant extraction and linearity over sums.
  2. Table lookups and affine argument scaling for powers, exponentials, and trigonometric functions.
  3. Heuristic substitution ("derivative-divides"), testing candidate subexpressions to see if dividing by their derivative eliminates the integration variable.
  4. Integration by parts ordered by function priority (logarithmic, inverse trig, algebraic, trigonometric, exponential) with bounded recursion depth.
  5. Fallback to a symbolic unevaluated integral node that obeys the Fundamental Theorem of Calculus when differentiated.
  6. Linear Algebra (Vectors & Matrices)

- Contiguous Storage & Unified Entries: Matrices and vectors store symbolic or numeric expressions in a flat, one-dimensional row-major array paired with row and column dimensions.
- Non-Commutative Multiplication: Scalar multiplication distributes across matrix entries, while matrix-matrix multiplication is kept strictly non-commutative and dimension-checked.
- Hybrid Matrix Algorithms: Determinants and inverses use direct closed-form formulas for 1x1, 2x2, and 3x3 matrices to prevent symbolic expression swell, switching to fraction-free elimination (Bareiss and Gauss-Jordan) for larger dimensions.

## Output Formatting & High-Speed Numerical Evaluation

- Presentation-Aware Formatters: Output generators for plain text, LaTeX, and Presentation MathML traverse the unified syntax tree using pattern matching and operator-precedence tracking. By inspecting leading negative coefficients and negative or unit-fraction exponents, formatters reconstruct natural subtraction, stacked fractions, and radical symbols without needing separate AST nodes.
- Zero-Allocation Bytecode Virtual Machine: For workloads requiring repeated numerical evaluation (such as plotting, root-finding, or numerical quadrature), the expression DAG is compiled once—performing common subexpression elimination via a hash map—into a flat array of bit-packed register instructions executed over a pre-allocated typed float array with zero garbage collection overhead.
