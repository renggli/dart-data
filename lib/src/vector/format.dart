library data.vector.format;

// This enum is annoying, but I don't see an easy way to avoid them: (1) using
// the `Type` class of the vector does not work reliably because the generic
// type breaks comparison in certain cases, and (2) a constructor reference or
// a creation method does not work because the generic type is not properly
// passed to the new instance.

/// Storage formats of matrices.
enum Format {
  standard,
  list,
  keyed,
}
