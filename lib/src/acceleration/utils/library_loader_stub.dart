// coverage:ignore-file

/// Stub for non-FFI platforms.
List<Object> get platformBlasLibraries => const [];

/// Stub for non-FFI platforms.
List<Object> get platformVdspLibraries => const [];

/// Stub symbol checker for non-FFI platforms.
bool hasSymbol(String name, List<Object> libraries) => false;
