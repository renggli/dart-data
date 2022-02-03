/// Error of an invalid probability outside the range of 0.0 to 1.0.
class InvalidProbability extends ArgumentError {
  InvalidProbability(this.probability, [String? name])
      : super.value(probability, name, 'Invalid probability');

  static void check(num probability) {
    if (probability < 0.0 || 1.0 < probability) {
      throw InvalidProbability(probability);
    }
  }

  final num probability;
}
