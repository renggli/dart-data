class InvalidProbability extends ArgumentError {
  static void check(num probability) {
    if (probability < 0.0 || 1.0 < probability) {
      throw InvalidProbability(probability);
    }
  }

  final num probability;

  InvalidProbability(this.probability)
      : super('Invalid probability: $probability');
}
