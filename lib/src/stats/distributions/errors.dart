/// Error thrown when a probability value lies outside `[0, 1]`.
class InvalidProbability extends ArgumentError {
  /// Creates an error for an invalid [probability] argument.
  new(this.probability, [String? name])
    : super.value(probability, name, 'Invalid probability');

  /// The invalid probability value that caused the error.
  final num probability;

  /// Validates that [probability] is within `[0, 1]`, throwing an
  /// [InvalidProbability] otherwise.
  static void check(num probability) {
    if (!(probability >= 0 && probability <= 1)) {
      throw InvalidProbability(probability);
    }
  }
}
