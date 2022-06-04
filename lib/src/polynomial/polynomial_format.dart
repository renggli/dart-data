// This enum is annoying, but I don't see an easy way to avoid them: (1) using
// the `Type` class of the polynomial does not work reliably because the generic
// type breaks comparison in certain cases, and (2) a constructor reference or
// a creation method does not work because the generic type is not properly
// passed to the new instance.

/// Formats of polynomials.
enum PolynomialFormat {
  standard,
  compressed,
  keyed,
  list,
}

/// Default polynomial format.
PolynomialFormat defaultPolynomialFormat = PolynomialFormat.standard;
