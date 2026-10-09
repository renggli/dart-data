import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('MemoryBuffer', () {
    test('empty constructor', () {
      const buf = MemoryBuffer<double>.empty();
      check(buf.id).equals(0);
      check(buf.data).isEmpty();
      check(buf.length).equals(0);
      check(buf.byteLength).equals(0);
    });

    test('typed list buffer properties', () {
      final list = Float64List(10);
      final buf = MemoryBuffer(list);
      check(buf.id).isGreaterThan(0);
      check(buf.length).equals(10);
      check(buf.byteLength).equals(80);
      check(buf.data).identicalTo(list);
    });

    test('sharesMemory static and instance', () {
      final list1 = Float64List(10);
      final view1 = Float64List.view(list1.buffer, 0, 5);
      final view2 = Float64List.view(list1.buffer, 40, 5);
      final list2 = Float64List(10);

      check(MemoryBuffer.sharesMemory(view1, view2)).isTrue();
      check(MemoryBuffer.sharesMemory(view1, list2)).isFalse();

      final buf1 = MemoryBuffer(view1);
      final buf2 = MemoryBuffer(view2);
      final buf3 = MemoryBuffer(list2);

      check(buf1.sharesMemoryWith(buf2)).isTrue();
      check(buf1.sharesMemoryWith(buf3)).isFalse();
    });

    test('typed buffer range overlap detection', () {
      final base = Float64List(20);
      final v1 = Float64List.view(base.buffer, 0, 10);
      final v2 = Float64List.view(base.buffer, 8 * 5, 10);
      final v3 = Float64List.view(base.buffer, 8 * 12, 5);

      final buf1 = MemoryBuffer(v1);
      final buf2 = MemoryBuffer(v2);
      final buf3 = MemoryBuffer(v3);

      check(buf1.overlaps(buf2, 0, 0, 10)).isTrue();
      check(buf1.overlaps(buf3, 0, 0, 5)).isFalse();
      check(buf2.overlaps(buf3, 0, 0, 5)).isFalse();
      check(buf2.overlaps(buf3, 7, 0, 3)).isTrue();
    });

    test('non-typed list overlap detection', () {
      final list = <int>[1, 2, 3, 4, 5];
      final b1 = MemoryBuffer(list);
      final b2 = MemoryBuffer(list);

      check(b1.overlaps(b2, 0, 2, 3)).isTrue();
      check(b1.overlaps(b2, 0, 3, 2)).isFalse();
    });
  });
}
