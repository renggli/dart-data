import 'package:more/collection.dart';
import 'package:more/printer.dart';

sealed class Index with ToStringPrinter {
  const factory Index.skip() = SkipIndex;

  const factory Index.at(int index) = SingleIndex;

  const factory Index.range(int start, int stop) = RangeIndex;

  const Index();
}

class SkipIndex extends Index {
  const SkipIndex();
}

extension IndexIntExtension on int {
  Index toIndex() => SingleIndex(this);
}

class SingleIndex extends Index {
  const SingleIndex(this.index);

  final int index;

  @override
  ObjectPrinter get toStringPrinter =>
      super.toStringPrinter..addValue(index, name: 'index');
}

extension IndexRangeExtension on IntegerRange {
  Index toIndex() => RangeIndex(start, end, step: step);
}

class RangeIndex extends Index {
  const RangeIndex(this.start, this.end, {this.step = 1});

  final int start;

  final int end;

  final int step;

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(start, name: 'start')
    ..addValue(end, name: 'end')
    ..addValue(step, name: 'step');
}
