import 'package:more/printer.dart';

import 'tensor.dart';

class TensorPrinter<T> extends Printer<Tensor<T>> {
  const TensorPrinter({
    this.valuePrinter,
    this.paddingPrinter = const StandardPrinter<String>(),
    this.ellipsesPrinter = const StandardPrinter<String>(),
    this.limit = true,
    this.leadingItems = 3,
    this.trailingItems = 3,
    this.openTensor = '[',
    this.closeTensor = ']',
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
  final String openTensor;
  final String closeTensor;
  final String horizontalSeparator;
  final String verticalSeparator;
  final String horizontalEllipses;
  final String verticalEllipses;

  @override
  void printOn(Tensor<T> object, StringBuffer buffer) =>
      _printOn(object, buffer, axis: 0, offset: object.offset);

  void _printOn(Tensor<T> tensor, StringBuffer buffer,
      {required int axis, required int offset}) {
    if (axis == tensor.rank) {
      _printValueOn(tensor, buffer, axis: axis, offset: offset);
    } else {
      _printAxisOn(tensor, buffer, axis: axis, offset: offset);
    }
  }

  void _printAxisOn(Tensor<T> tensor, StringBuffer buffer,
      {required int axis, required int offset}) {
    final isLast = axis == tensor.rank - 1;
    buffer.write(openTensor);
    for (var i = 0; i < tensor.shape[axis]; i++) {
      if (i > 0) {
        if (isLast) {
          buffer.write(horizontalSeparator);
        } else {
          buffer.write(verticalSeparator);
          buffer.write(' ' * openTensor.length * (axis + 1));
        }
      }
      if (limit &&
          leadingItems <= i &&
          i < tensor.shape[axis] - trailingItems) {
        if (isLast) {
          buffer.write(paddingPrinter(ellipsesPrinter(horizontalEllipses)));
        } else {
          buffer.write(verticalEllipses);
        }
        i = tensor.shape[axis] - trailingItems - 1;
      } else {
        _printOn(tensor, buffer,
            axis: axis + 1, offset: offset + i * tensor.stride[axis]);
      }
    }
    buffer.write(closeTensor);
  }

  void _printValueOn(Tensor<T> object, StringBuffer buffer,
      {required int axis, required int offset}) {
    final printer = valuePrinter ?? object.type.printer;
    paddingPrinter.printOn(printer(object.data[offset]), buffer);
  }
}
