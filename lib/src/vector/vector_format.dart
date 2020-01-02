library data.vector.vector_format;

// This enum is annoying, but I don't see an easy way to avoid them: (1) using
// the `Type` class of the vector does not work reliably because the generic
// type breaks comparison in certain cases, and (2) a constructor reference or
// a creation method does not work because the generic type is not properly
// passed to the new instance.

/// Formats of vectors.
enum VectorFormat {
  standard,
  list,
  keyed,
}

/// Default vector format.
VectorFormat defaultVectorFormat = VectorFormat.standard;
