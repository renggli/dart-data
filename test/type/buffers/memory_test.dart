import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Memory', () {
    test('sharesMemory on typed lists', () {
      final list1 = Float64List(10);
      final view1 = Float64List.view(list1.buffer, 0, 5);
      final view2 = Float64List.view(list1.buffer, 40, 5);
      final list2 = Float64List(10);

      check(sharesMemory(view1, view2)).isTrue();
      check(sharesMemory(view1, list2)).isFalse();
      check(view1.sharesMemoryWith(view2)).isTrue();
      check(view1.sharesMemoryWith(list2)).isFalse();
    });

    test('sharesMemory on non-typed lists', () {
      final list1 = <int>[1, 2, 3];
      final list2 = <int>[1, 2, 3];

      check(sharesMemory(list1, list1)).isTrue();
      check(sharesMemory(list1, list2)).isFalse();
      check(list1.sharesMemoryWith(list1)).isTrue();
      check(list1.sharesMemoryWith(list2)).isFalse();
    });

    test('typed buffer range overlap detection', () {
      final base = Float64List(20);
      final v1 = Float64List.view(base.buffer, 0, 10);
      final v2 = Float64List.view(base.buffer, 8 * 5, 10);
      final v3 = Float64List.view(base.buffer, 8 * 12, 5);

      check(hasOverlap(v1, 0, v2, 0, 10)).isTrue();
      check(hasOverlap(v1, 0, v3, 0, 5)).isFalse();
      check(hasOverlap(v2, 0, v3, 0, 5)).isFalse();
      check(hasOverlap(v2, 7, v3, 0, 3)).isTrue();

      check(v1.overlaps(v2, 0, 0, 10)).isTrue();
      check(v1.overlaps(v3, 0, 0, 5)).isFalse();
      check(v2.overlaps(v3, 0, 0, 5)).isFalse();
      check(v2.overlaps(v3, 7, 0, 3)).isTrue();
    });

    test('non-typed list overlap detection', () {
      final list1 = <int>[1, 2, 3, 4, 5];
      final list2 = <int>[1, 2, 3, 4, 5];

      check(hasOverlap(list1, 0, list1, 2, 3)).isTrue();
      check(hasOverlap(list1, 0, list1, 3, 2)).isFalse();
      check(hasOverlap(list1, 0, list2, 0, 5)).isFalse();

      check(list1.overlaps(list1, 0, 2, 3)).isTrue();
      check(list1.overlaps(list1, 0, 3, 2)).isFalse();
      check(list1.overlaps(list2, 0, 0, 5)).isFalse();
    });
  });
}
