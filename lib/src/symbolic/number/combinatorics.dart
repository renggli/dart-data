import '../ast.dart';

/// Computes the Bernoulli numbers `B_0, B_1, ..., B_maxIndex` using the
/// first convention (`B_1 = -1/2`).
List<RationalNumber> bernoulliNumbers(int maxIndex) {
  if (maxIndex < 0) return const [];
  final b = <RationalNumber>[IntegerNumber.one];
  for (var m = 1; m <= maxIndex; m++) {
    if (m == 1) {
      b.add(FractionNumber.negativeHalf);
      continue;
    }
    if (m.isOdd) {
      b.add(IntegerNumber.zero);
      continue;
    }
    var binom = BigInt.one;
    RationalNumber sum = IntegerNumber.zero;
    for (var j = 0; j < m; j++) {
      if (j > 0) {
        binom = (binom * BigInt.from(m + 2 - j)) ~/ BigInt.from(j);
      }
      final bj = b[j];
      if (!bj.isZero) {
        sum = sum.addRational(IntegerNumber(binom).mulRational(bj));
      }
    }
    final next = sum.neg().divRational(IntegerNumber.of(m + 1));
    b.add(next);
  }
  return b;
}

/// Computes the triangle of Stirling numbers of the second kind `S(n, k)`
/// for `0 <= k <= n <= maxN`.
List<List<BigInt>> stirlingSecondKind(int maxN) {
  if (maxN < 0) return const [];
  final table = List<List<BigInt>>.generate(
    maxN + 1,
    (_) => List<BigInt>.filled(maxN + 1, BigInt.zero),
  );
  table[0][0] = BigInt.one;
  for (var n = 1; n <= maxN; n++) {
    for (var k = 1; k <= n; k++) {
      table[n][k] = BigInt.from(k) * table[n - 1][k] + table[n - 1][k - 1];
    }
  }
  return table;
}

/// Finds a non-trivial factor of composite positive [n] via Brent's cycle
/// variant of Pollard's rho algorithm, or returns `null` if unsuccessful.
BigInt? pollardsRho(BigInt n) {
  if (n <= BigInt.one) return null;
  if (n.isEven) return BigInt.two;
  for (final seed in [BigInt.two, BigInt.from(3), BigInt.from(5)]) {
    for (final c in [BigInt.one, BigInt.from(3), BigInt.from(5)]) {
      var y = seed;
      var r = 1;
      var q = BigInt.one;
      var g = BigInt.one;
      var ys = y;
      var x = y;
      while (g == BigInt.one) {
        x = y;
        for (var i = 0; i < r; i++) {
          y = (y * y + c) % n;
        }
        var k = 0;
        while (k < r && g == BigInt.one) {
          ys = y;
          final steps = 128 < (r - k) ? 128 : (r - k);
          for (var i = 0; i < steps; i++) {
            y = (y * y + c) % n;
            q = (q * (x - y).abs()) % n;
          }
          g = q.gcd(n);
          k += 128;
        }
        r <<= 1;
      }
      if (g == n) {
        do {
          ys = (ys * ys + c) % n;
          g = (x - ys).abs().gcd(n);
        } while (g == BigInt.one);
      }
      if (g > BigInt.one && g < n) return g;
    }
  }
  return null;
}
