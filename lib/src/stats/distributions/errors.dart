/// Error thrown when a probability value lies outside the valid $\lbrack 0, 1 \rbrack$ interval.
class InvalidProbability extends ArgumentError {
  /// Creates an error for an invalid [probability] argument.
  new(this.probability, [String? name])
    : super.value(probability, name, 'Invalid probability');

  /// The invalid probability value that caused the error.
  final num probability;

  /// Validates that [probability] is within the interval $\lbrack 0, 1 \rbrack$, throwing an [InvalidProbability] otherwise.
  static void check(num probability) {
    if (probability < 0 || 1 < probability) {
      throw InvalidProbability(probability);
    }
  }
}
