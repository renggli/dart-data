class InvalidProbability extends ArgumentError {
  static void check(double probability) {
    if (probability < 0.0 || 1.0 < probability) {
      throw InvalidProbability(probability);
    }
  }

  final double probability;

  InvalidProbability(this.probability)
      : super('Invalid probability: $probability');
}
