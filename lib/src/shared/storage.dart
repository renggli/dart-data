library data.shared.storage;

abstract class Storage {
  /// Returns the dimensions of this storage.
  List<int> get shape;

  /// Returns the underlying storage containers of this tensor.
  Set<Storage> get storage;
}
