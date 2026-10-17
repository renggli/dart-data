import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Faulhaber and polynomial sums', () {
    test('evaluates finite concrete and symbolic polynomial sums', () {
      const k = Variable('k');
      const n = Variable('n');

      // Concrete sums
      check(k.sum('k', 1, 10)).equals(IntegerNumber.of(55));
      check((k * k).sum('k', 1, 5)).equals(IntegerNumber.of(55));
      check(k.sum('k', 5, 2)).equals(IntegerNumber.zero);

      // Symbolic constant sum: sum_{k=1..n} c = c * n
      check(IntegerNumber.of(3).sum('k', 1, n).toString()).equals('3 * n');

      // sum_{k=1..n} k = n * (n + 1) / 2
      check(k.sum('k', 1, n).toString()).equals('1/2 * n + 1/2 * n ^ 2');

      // sum_{k=1..n} k^2 = n * (n + 1) * (2*n + 1) / 6
      check((k * k).sum('k', 1, n).toString())
          .equals('1/6 * n + 1/2 * n ^ 2 + 1/3 * n ^ 3');

      // sum_{k=1..n} k^3 = n^2 * (n + 1)^2 / 4
      check(k.pow(3).sum('k', 1, n).toString())
          .equals('1/4 * n ^ 2 + 1/2 * n ^ 3 + 1/4 * n ^ 4');

      // Linear combination: sum_{k=1..n} (2*k - 1) = n^2
      check(
        (IntegerNumber.two * k - IntegerNumber.one).sum('k', 1, n).toString(),
      ).equals('n ^ 2');
    });
  });

  group('Geometric, Gosper, and telescoping sums', () {
    test('evaluates geometric, polynomial-geometric, factorial, and telescoping sums', () {
      const k = Variable('k');
      const n = Variable('n');

      // Geometric: sum_{k=0..n} 2^k = 2^(n + 1) - 1
      final geom = IntegerNumber.two.pow(k).sum('k', 0, n);
      check(geom.substitute('n', IntegerNumber.of(4)).simplify())
          .equals(IntegerNumber.of(31));

      // Infinite geometric: sum_{k=0..inf} (1/2)^k = 2
      final infGeom = FractionNumber.half.pow(k).sum('k', 0, Constant.infinity);
      check(infGeom).equals(IntegerNumber.two);

      // Gosper polynomial-geometric: sum_{k=1..n} k * 2^k = (n - 1) * 2^(n + 1) + 2
      final polyGeom = (k * IntegerNumber.two.pow(k)).sum('k', 1, n);
      check(polyGeom.substitute('n', IntegerNumber.of(3)).simplify())
          .equals(IntegerNumber.of(34)); // 1*2 + 2*4 + 3*8 = 34

      // Gosper factorial: sum_{k=1..n} k * k! = (n + 1)! - 1
      final factSum = (k * Factorial(k)).sum('k', 1, n);
      check(factSum.substitute('n', IntegerNumber.of(4)).simplify())
          .equals(IntegerNumber.of(119)); // 5! - 1 = 119

      // Telescoping rational: sum_{k=1..n} 1 / (k * (k + 1)) = 1 - 1 / (n + 1) = n / (n + 1)
      final tele = (IntegerNumber.one / (k * (k + 1))).sum('k', 1, n);
      check(tele.together().toString()).equals('n / (1 + n)');

      // Infinite telescoping rational: sum_{k=1..inf} 1 / (k * (k + 1)) = 1
      final infTele = (IntegerNumber.one / (k * (k + 1))).sum(
        'k',
        1,
        Constant.infinity,
      );
      check(infTele).equals(IntegerNumber.one);

      // General shift-difference telescoping: sum_{k=1..n} (ln(k + 1) - ln(k)) = ln(n + 1)
      final logTele = (Ln(k + 1) - Ln(k)).sum('k', 1, n);
      check(logTele.toString()).equals('ln(1 + n)');

      // Unevaluated fallback when no closed form exists
      final uneval = Sin(k * k).sum('k', 1, n);
      check(uneval.toString()).equals('sum(sin(k ^ 2), k, 1, n)');
    });
  });

  group('Closed-form products', () {
    test(
      'evaluates finite, factorial, exponential, and telescoping products',
      () {
        const k = Variable('k');
        const n = Variable('n');

        // Concrete products
        check(k.product('k', 1, 5)).equals(IntegerNumber.of(120));
        check(k.product('k', 5, 2)).equals(IntegerNumber.one);

        // Constant product: prod_{k=1..n} 2 = 2^n
        check(IntegerNumber.two.product('k', 1, n).toString()).equals('2 ^ n');

        // Factorial product: prod_{k=1..n} k = n!
        check(k.product('k', 1, n)).equals(Factorial(n));

        // Shifted linear product: prod_{k=1..n} (k + 1) = (n + 1)!
        check((k + 1).product('k', 1, n).toString()).equals('(1 + n)!');

        // Exponential product: prod_{k=1..n} 2^k = 2^(n * (n + 1) / 2)
        final expProd = IntegerNumber.two.pow(k).product('k', 1, n);
        check(expProd.substitute('n', IntegerNumber.of(3)).simplify())
            .equals(IntegerNumber.of(64)); // 2^(1+2+3) = 64

        // Telescoping product: prod_{k=1..n} (k + 1) / k = n + 1
        check(((k + 1) / k).product('k', 1, n).toString()).equals('1 + n');

        // Telescoping product: prod_{k=2..n} (1 - 1 / k^2) = 1/2 * (1 + n) / n
        final sqTele = (IntegerNumber.one - IntegerNumber.one / (k * k))
            .product('k', 2, n);
        check(sqTele.together().toString()).equals('1/2 * (1 + n) / n');
      },
    );
  });
}
