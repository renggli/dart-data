# High-Level Architecture for Appealing Mathematical Rendering

Because a symbolic math library stores expressions in an algebra-optimized canonical form—where subtraction, division, negation, and roots are eliminated—naively printing the syntax tree produces unnatural output like (-1 *y) + x + (2* (z ^ -1)).

To generate textbook-quality LaTeX, Presentation MathML, and Plain Text, the rendering engine acts as a translation layer between canonical algebra and human mathematical typography.

## Reconstructing Human Operations from the Canonical AST

Instead of adding separate subtraction, division, or root nodes to the core AST, the renderer inspects canonical nodes on the fly and reconstructs familiar notation:

- Subtraction and Negation (Inside Sums):
  - When rendering an Add node, the formatter inspects every term after the first.
  - If a term is a negative number, or a Mul node whose leading coefficient is negative, the formatter emits a binary minus sign (-) instead of +, strips the negative sign from the term, and renders the positive remainder.
  - If a Mul node has a leading coefficient of -1 (and is not absorbed by a surrounding Add), it renders as a unary prefix minus (-x instead of -1 * x).
- Stacked Fractions (Inside Products):
  - When rendering a Mul node, the formatter partitions all factors into two buckets: a numerator list and a denominator list.
  - A Rational(p, q) places p (if not 1) into the numerator and q into the denominator.
  - Any Pow(base, exp) with a negative numeric exponent places Pow(base, -exp) into the denominator.
  - If the denominator bucket is non-empty, the entire product is rendered as a single fraction (\frac{num}{den} in LaTeX, <mfrac> in MathML, or num / den in text).
- Radicals (Inside Powers):
  - When rendering a Pow(base, exp) node, the formatter checks if exp is a positive Rational(p, q).
  - If p == 1 and q == 2, it renders as a square root (\sqrt{base} or <msqrt>).
  - If p == 1 and q > 2, it renders as an n-th root (\sqrt[q]{base} or <mroot>).
  - If p > 1 (such as x^(3/2)), it renders as \sqrt[q]{base^p} or keeps the fractional exponent depending on a user style preference.

## Context-Aware Parenthesization & Precedence Resetting

Nothing ruins mathematical readability faster than redundant parentheses like ((2 * (x ^ 2)) + 1). A clean formatter eliminates unnecessary brackets using precedence tracking and container resets:

- Precedence Hierarchy: Every operation is assigned a binding strength:

  1. Add / Subtraction (lowest: 10)
  2. Mul / Division (20)
  3. Unary Negation (25)
  4. Pow (30)
  5. Functions, Variables, Constants, and Atomic Numbers (highest: 40)
- The Parenthesization Rule: A child expression is wrapped in parentheses only if its precedence is strictly lower than its parent's precedence—or if equal precedence violates associativity:
  - Subtraction is right-sensitive: In a - (b + c), the right-hand sum has the same precedence as +, so when negated inside an Add, its required precedence threshold is bumped by 1 to force parentheses.
  - Exponentiation is right-associative: (a^b)^c requires parentheses around a^b, whereas a^(b^c) does not need parentheses around b^c.
- Invisible Grouping Containers (Precedence Reset):
  - In 2D formats (LaTeX and MathML), constructs like fraction numerators and denominators (\frac{...}{...}), square roots (\sqrt{...}), and superscripts (^{...}) act as visual grouping containers.
  - Whenever the formatter enters one of these containers, it resets the parent precedence to 0. This ensures (x + 1) / (x - 1) renders cleanly as \frac{x + 1}{x - 1} without outer parentheses around x + 1 or x - 1.

## Typography & Aesthetic Polish

### Implicit vs. Explicit Multiplication

Humans rarely write explicit multiplication symbols between numbers and variables. The formatter decides whether to join adjacent numerator factors implicitly (with a space/nothing) or explicitly (\cdot or *) by inspecting each adjacent pair (left, right):

- Use Implicit Multiplication (2x, 3 \pi, x \sin(y)): Whenever a number is followed by a variable, constant, root, power with a symbolic base, or function—or when single-letter variables and parenthesized sums are adjacent (x(x + 1)).
- Require Explicit Multiplication (2 \cdot 3, 2 \cdot 3^x): Whenever the right-hand factor begins with a digit (for example, 2 followed by 3^x must render as 2 \cdot 3^x so it does not look like 23^x), or in plain text when two multi-character variable names are adjacent.

### Display Ordering vs. Internal Canonical Ordering

Internally, the AST sorts terms and factors using a fast structural comparator. At render time, applying a lightweight Display Sort makes expressions look like they were written by a mathematician:

- Polynomial Descending Order: In an Add node, order monomials by descending degree of the primary variable (x^3 + 2x^2 - 5x + 1 instead of 1 - 5x + 2x^2 + x^3).
- Leading Positive Term: If the first term of a sum is negative and a later term is positive (e.g., -y + x), optionally swap the first positive term to the front so it reads x - y.
- Visual Factor Ordering in Products: Within the numerator of a Mul node, order factors visually as:
  Numeric Coefficient -> Constants (pi, e) -> Variables (alphabetical) -> Radicals -> Functions -> Parenthesized Sums
  This guarantees 2 \pi r \sqrt{x} \sin(\theta) (x + 1) instead of scrambled factor orders.

### Trigonometric and Function Conventions

- Powers of Trig Functions: When rendering Pow(Sin(x), n) where n is a positive integer greater than 1, format the exponent directly on the function name (\sin^{2}(x) instead of \left(\sin(x)\right)^{2}).
- Never Use -1 Superscript for Reciprocal Trig: Keep Pow(Sin(x), -1) as \frac{1}{\sin(x)} (or \csc(x)) so it is never confused with the inverse function \arcsin(x).
- Variable & Greek Letter Styling: Automatically map known variable names (alpha, beta, theta, omega) to their LaTeX (\alpha, \theta) and MathML (&#x03B1;, &#x03B8;) symbols, and render trailing digits in variable names (x_1 or x1) as subscripts.

## Target-Specific Formatting Rules

### LaTeX

- Smart Delimiter Sizing: Only emit \left( and \right) when the enclosed subexpression is vertically tall (contains a stacked fraction, matrix, integral, or n-th root). For flat expressions like \sin(x + 1), standard ( and ) produce much cleaner spacing and line-height in LaTeX engines (MathJax, KaTeX, and pdfLaTeX).
- Brace Hygiene: Always wrap exponents and subscripts in braces ({x}^{10}) so multi-character exponents never break, and insert thin spaces (\,) before differential terms (\int f(x) \, \mathrm{d}x).

### Presentation MathML

- Semantic Token Elements: Wrap every leaf in its proper MathML token tag so screen readers and browser math layout engines apply correct operator spacing:
  - <mn> for numbers (2, 3.14).
  - <mi> for variables and constants (x, &#x03C0;).
  - <mo> for operators, parentheses, and separators (+, -, (, )).
- Invisible Operators: Emit the Unicode Invisible Times (<mo>&#x2062;</mo>) for implicit multiplication and Function Application (<mo>&#x2061;</mo>) between a function name and its argument. This makes the MathML both visually appealing and accessible/copy-pasteable.
- Structural Grouping (<mrow>): Wrap every logical subexpression in <mrow>...</mrow> so stretchy parentheses (<mo>(</mo>) automatically scale only to the height of their immediate group.

### Plain Text / Unicode String

- Dual-Mode Text Output:
  - ASCII / Parser-Safe Mode (toText()): Uses standard *, /, ^, and sqrt(...) ((x^2 - sqrt(2)) / (x + 1)). Maintains strict 1D operator precedence (wrapping multi-term fraction numerators and denominators in parentheses) so the output can be pasted straight into code or re-parsed.
  - Pretty Unicode Mode (toPrettyText()): Uses Unicode superscripts (x²), symbols (π, √), and minus signs (−) for compact single-line terminal or UI labels ((x² − √2) / (x + 1)).
