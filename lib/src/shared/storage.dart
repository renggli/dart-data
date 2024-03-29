/// Interface common to all storage objects.
abstract class Storage {
  /// Returns the dimensions of this storage.
  List<int> get shape;

  /// Returns the underlying storage containers of this object.
  Set<Storage> get storage;
}
