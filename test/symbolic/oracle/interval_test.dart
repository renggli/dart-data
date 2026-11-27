import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/src/symbolic/oracle/interval.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('IEEE-754 nextUp and nextDown', () {
    test('steps across zero, subnormals, normal numbers, and infinities', () {
      check(RealInterval.nextUp(0.0)).equals(double.minPositive);
      check(RealInterval.nextUp(-0.0)).equals(double.minPositive);
      check(RealInterval.nextDown(0.0)).equals(-double.minPositive);
      check(RealInterval.nextUp(double.infinity)).equals(double.infinity);
      check(RealInterval.nextDown(double.negativeInfinity))
          .equals(double.negativeInfinity);
      check(RealInterval.nextUp(-double.minPositive)).equals(0.0);
      check(RealInterval.nextDown(double.minPositive)).equals(0.0);
      check(RealInterval.nextUp(1.0) > 1.0).isTrue;
      check(RealInterval.nextDown(1.0) < 1.0).isTrue;
      check(RealInterval.nextDown(RealInterval.nextUp(1.0))).equals(1.0);
      check(RealInterval.nextUp(RealInterval.nextDown(-2.5))).equals(-2.5);
    });
  });

  group('RealInterval construction and set operations', () {
    test(
      'tracks emptiness, openness, sign predicates, intersect, and hull',
      () {
        check(RealInterval.empty.isEmpty).isTrue;
        check(RealInterval.open(1.0, 1.0).isEmpty).isTrue;
        check(RealInterval.fromBounds(2.0, 1.0).isEmpty).isTrue;
        check(RealInterval.positive.isStrictlyPositive).isTrue;
        check(RealInterval.nonNegative.isStrictlyPositive).isFalse;
        check(RealInterval.nonNegative.isNonNegative).isTrue;
        check(RealInterval.negative.isStrictlyNegative).isTrue;
        check(RealInterval.nonPositive.isNonPositive).isTrue;
        check(RealInterval.point(0.0).isZero).isTrue;
        check(RealInterval.all.isAll).isTrue;

        final a = RealInterval.fromBounds(0.0, 3.0, loInclusive: false);
        final b = RealInterval.closed(0.0, 2.0);
        final inter = a.intersect(b);
        check(inter.lo).equals(0.0);
        check(inter.loInclusive).isFalse;
        check(inter.hi).equals(2.0);
        check(inter.hiInclusive).isTrue;

        final hull = a.hull(b);
        check(hull.lo).equals(0.0);
        check(hull.loInclusive).isTrue;
        check(hull.hi).equals(3.0);
        check(a.isSubsetOf(RealInterval.nonNegative)).isTrue;
        check(RealInterval.forDomain(VariableDomain.positive))
            .equals(RealInterval.positive);
      },
    );
  });

  group('RealInterval outward-rounded arithmetic and functions', () {
    test(
      'encloses sum, difference, product, quotient, and division by zero',
      () {
        final a = RealInterval.closed(1.0, 2.0);
        final b = RealInterval.closed(-1.0, 3.0);
        final sum = a + b;
        check(sum.contains(0.0)).isTrue;
        check(sum.contains(5.0)).isTrue;

        final prod = a * b;
        check(prod.contains(-2.0)).isTrue;
        check(prod.contains(6.0)).isTrue;

        final invPos = RealInterval.point(1.0) / RealInterval.positive;
        check(invPos.isStrictlyPositive).isTrue;
        check(invPos.contains(1000.0)).isTrue;

        final acrossZero = a / b;
        check(acrossZero).equals(RealInterval.all);
        check((a / RealInterval.point(0.0)).isEmpty).isTrue;
      },
    );

    test(
      'computes elementary, trig, hyperbolic, rounding, and erf enclosures',
      () {
        check(RealInterval.closed(-2.0, 1.0).abs().isNonNegative).isTrue;
        check(RealInterval.closed(-4.0, 4.0).sqrt())
            .equals(RealInterval.closed(0.0, RealInterval.nextUp(2.0)));
        check(RealInterval.negative.exp().isStrictlyPositive).isTrue;
        check(RealInterval.all.exp().isStrictlyPositive).isTrue;
        check(RealInterval.point(1.0).ln().contains(0.0)).isTrue;
        check(RealInterval.all.sin()).equals(RealInterval.unitClosed);
        check(RealInterval.all.cos()).equals(RealInterval.unitClosed);
        check(RealInterval.closed(0.0, math.pi / 2.0).sin().isNonNegative)
            .isTrue;
        check(RealInterval.closed(-1.0, 1.0).asin().contains(0.0)).isTrue;
        check(RealInterval.all.cosh().lo >= 1.0).isTrue;
        check(
          RealInterval.all.atan().isSubsetOf(
            RealInterval.open(-math.pi / 2.0, math.pi / 2.0),
          ),
        ).isTrue;
        check(RealInterval.closed(-1.0, 1.0).atan().contains(0.0)).isTrue;
        check(RealInterval.closed(1.2, 2.8).floor())
            .equals(RealInterval.closed(1.0, 2.0));
        check(RealInterval.closed(1.2, 2.8).ceil())
            .equals(RealInterval.closed(2.0, 3.0));
        check(RealInterval.all.erf().lo >= -1.0).isTrue;
        check(RealInterval.all.erfc().hi <= 2.0).isTrue;
      },
    );
  });
}
