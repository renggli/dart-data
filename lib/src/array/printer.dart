import 'package:more/printer.dart';

import 'array.dart';

class ArrayPrinter<T> extends Printer<Array<T>> {
  const ArrayPrinter({
    this.valuePrinter,
    this.paddingPrinter = const StandardPrinter<String>(),
    this.ellipsesPrinter = const StandardPrinter<String>(),
    this.limit = true,
    this.leadingItems = 3,
    this.trailingItems = 3,
    this.openArray = '[',
    this.closeArray = ']',
    this.horizontalSeparator = ', ',
    this.verticalSeparator = ',\n',
    this.horizontalEllipses = '\u2026',
    this.verticalEllipses = '\u22ee',
  });

  final Printer<T>? valuePrinter;
  final Printer<String> paddingPrinter;
  final Printer<String> ellipsesPrinter;
  final bool limit;
  final int leadingItems;
  final int trailingItems;
  final String openArray;
  final String closeArray;
  final String horizontalSeparator;
  final String verticalSeparator;
  final String horizontalEllipses;
  final String verticalEllipses;

  @override
  void printOn(Array<T> object, StringBuffer buffer) =>
      _printOn(object, buffer, axis: 0, offset: object.offset);

  void _printOn(Array<T> array, StringBuffer buffer,
      {required int axis, required int offset}) {
    if (axis == array.dimensions) {
      _printValueOn(array, buffer, axis: axis, offset: offset);
    } else {
      _printAxisOn(array, buffer, axis: axis, offset: offset);
    }
  }

  void _printAxisOn(Array<T> array, StringBuffer buffer,
      {required int axis, required int offset}) {
    final isLast = axis == array.dimensions - 1;
    buffer.write(openArray);
    for (var i = 0; i < array.shape[axis]; i++) {
      if (i > 0) {
        if (isLast) {
          buffer.write(horizontalSeparator);
        } else {
          buffer.write(verticalSeparator);
          buffer.write(' ' * openArray.length * (axis + 1));
        }
      }
      if (limit && leadingItems <= i && i < array.shape[axis] - trailingItems) {
        if (isLast) {
          buffer.write(paddingPrinter(ellipsesPrinter(horizontalEllipses)));
        } else {
          buffer.write(verticalEllipses);
        }
        i = array.shape[axis] - trailingItems - 1;
      } else {
        _printOn(array, buffer,
            axis: axis + 1, offset: offset + i * array.strides[axis]);
      }
    }
    buffer.write(closeArray);
  }

  void _printValueOn(Array<T> object, StringBuffer buffer,
      {required int axis, required int offset}) {
    final printer = valuePrinter ?? object.type.printer;
    paddingPrinter.printOn(printer(object.data[offset]), buffer);
  }
}
