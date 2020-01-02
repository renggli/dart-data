library data.shared.storage;

/// Interface common to all storage objects.
abstract class Storage {
  /// Returns the dimensions of this storage.
  List<int> get shape;

  /// Returns the underlying storage containers of this tensor.
  Set<Storage> get storage;

  /// Creates a deep copy of this structure.
  Storage copy();
}
