import 'package:more/printer.dart';

import 'tensor.dart';

/// Configurable object to print tensors.
class TensorPrinter<T> extends Printer<Tensor<T>> {
  const TensorPrinter({
    this.valuePrinter,
    this.paddingPrinter = const StandardPrinter<String>(),
    this.ellipsesPrinter = const StandardPrinter<String>(),
    this.limit = true,
    this.leadingItems = 3,
    this.trailingItems = 3,
    this.empty = '\u2205',
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
  final String empty;
  final String openTensor;
  final String closeTensor;
  final String horizontalSeparator;
  final String verticalSeparator;
  final String horizontalEllipses;
  final String verticalEllipses;

  @override
  void printOn(Tensor<T> object, StringBuffer buffer) => object.length == 0
      ? buffer.write(empty)
      : _printOn(object, buffer, offset: object.layout.offset, axis: 0);

  void _printOn(Tensor<T> tensor, StringBuffer buffer,
          {required int axis, required int offset}) =>
      axis == tensor.rank
          ? _printValueOn(tensor, buffer, offset: offset)
          : _printAxisOn(tensor, buffer, offset: offset, axis: axis);

  void _printAxisOn(Tensor<T> tensor, StringBuffer buffer,
      {required int offset, required int axis}) {
    final isLast = axis == tensor.rank - 1;
    final shape = tensor.layout.shape[axis];
    final stride = tensor.layout.strides[axis];
    buffer.write(openTensor);
    for (var i = 0; i < shape; i++) {
      if (i > 0) {
        if (isLast) {
          buffer.write(horizontalSeparator);
        } else {
          buffer.write(verticalSeparator);
          buffer.write(' ' * openTensor.length * (axis + 1));
        }
      }
      if (limit && leadingItems <= i && i < shape - trailingItems) {
        if (isLast) {
          buffer.write(paddingPrinter(ellipsesPrinter(horizontalEllipses)));
        } else {
          buffer.write(verticalEllipses);
        }
        i = shape - trailingItems - 1;
      } else {
        _printOn(tensor, buffer, axis: axis + 1, offset: offset + i * stride);
      }
    }
    buffer.write(closeTensor);
  }

  void _printValueOn(Tensor<T> object, StringBuffer buffer,
      {required int offset}) {
    final printer = valuePrinter ?? object.type.printer;
    paddingPrinter.printOn(printer(object.data[offset]), buffer);
  }
}
