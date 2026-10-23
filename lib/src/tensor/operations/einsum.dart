import '../tensor.dart';
import 'contraction.dart';

/// Evaluates Einstein summation convention on [operands] according to
/// [equation].
///
/// Conceptually, Einstein summation provides a concise notation for specifying
/// multidimensional tensor transformations, products, and contractions through
/// index subscript labels.
///
/// Formally, this calculates general tensor contractions defined by index
/// subscript labels: repeated indices across input operands that do not appear
/// in the output subscript are summed over.
///
/// Supported equations include:
/// - Matrix multiplication: `'ij,jk->ik'`
/// - Dot product: `'i,i->'` or `'i,i'`
/// - Outer product: `'i,j->ij'`
/// - Transpose: `'ij->ji'`
/// - Diagonal extraction: `'ii->i'`
/// - Matrix trace: `'ii->'`
/// - Batched matrix multiplication: `'bij,bjk->bik'`
/// - Sum of elements: `'ij->'`
/// - Multi-tensor contractions: `'ijk,jkl,klm->im'`
///
/// ```dart
/// final a = Tensor<int>.fromObject([[1, 2], [3, 4]]);
/// final b = Tensor<int>.fromObject([[2, 0], [1, 2]]);
/// final c = einsum('ij,jk->ik', [a, b]);
/// // c is [[4, 4], [10, 8]]
/// ```
Tensor<T> einsum<T>(String equation, List<Tensor<T>> operands) {
  if (operands.isEmpty) {
    throw ArgumentError('At least one operand required for einsum');
  }

  final String inputsPart;
  final String outputPart;
  if (equation.contains('->')) {
    final parts = equation.split('->');
    if (parts.length != 2) {
      throw ArgumentError.value(
        equation,
        'equation',
        'Invalid einsum equation format: multiple "->" delimiters',
      );
    }
    inputsPart = parts[0].replaceAll(' ', '');
    outputPart = parts[1].replaceAll(' ', '');
  } else {
    inputsPart = equation.replaceAll(' ', '');
    // NumPy convention: indices occurring exactly once, sorted alphabetically
    final counts = <String, int>{};
    for (var i = 0; i < inputsPart.length; i++) {
      final ch = inputsPart[i];
      if (ch != ',') {
        counts[ch] = (counts[ch] ?? 0) + 1;
      }
    }
    final singleIndices =
        counts.entries.where((e) => e.value == 1).map((e) => e.key).toList()
          ..sort();
    outputPart = singleIndices.join();
  }

  final inputLabels = inputsPart.split(',');
  if (inputLabels.length != operands.length) {
    throw ArgumentError(
      'Number of operand subscripts (${inputLabels.length}) does not match operands list length (${operands.length})',
    );
  }

  // Dimension validation and indexing
  final dimMap = <String, int>{};
  for (var opIdx = 0; opIdx < operands.length; opIdx++) {
    final label = inputLabels[opIdx];
    final op = operands[opIdx];
    if (label.length != op.rank) {
      throw ArgumentError(
        'Subscript "$label" length (${label.length}) does not match operand $opIdx rank (${op.rank})',
      );
    }
    for (var axis = 0; axis < label.length; axis++) {
      final ch = label[axis];
      final dim = op.shape[axis];
      if (dimMap.containsKey(ch)) {
        if (dimMap[ch] != dim) {
          throw ArgumentError(
            'Dimension mismatch for index "$ch": expected ${dimMap[ch]}, got $dim',
          );
        }
      } else {
        dimMap[ch] = dim;
      }
    }
  }

  // Verify output labels
  final seenOut = <String>{};
  for (var i = 0; i < outputPart.length; i++) {
    final ch = outputPart[i];
    if (!dimMap.containsKey(ch)) {
      throw ArgumentError(
        'Output index "$ch" does not appear in any input subscript',
      );
    }
    if (!seenOut.add(ch)) {
      throw ArgumentError('Duplicate index "$ch" in output subscript');
    }
  }

  final outShape = [
    for (var i = 0; i < outputPart.length; i++) dimMap[outputPart[i]]!,
  ];

  // Fast path: single operand
  if (operands.length == 1) {
    final inLabel = inputLabels[0];
    final op = operands[0];
    if (inLabel == outputPart) return op;
    // Pure permutation (no duplicates, no reduction)
    if (inLabel.length == outputPart.length &&
        inLabel.split('').toSet().length == inLabel.length &&
        outputPart.split('').toSet().length == outputPart.length) {
      final perm = [
        for (var i = 0; i < outputPart.length; i++)
          inLabel.indexOf(outputPart[i]),
      ];
      return op.transpose(perm);
    }
  }

  // Fast path: two operands without duplicate labels within an operand and
  // without batching
  if (operands.length == 2) {
    final labelA = inputLabels[0];
    final labelB = inputLabels[1];
    final setA = labelA.split('').toSet();
    final setB = labelB.split('').toSet();
    final outSet = outputPart.split('').toSet();

    if (setA.length == labelA.length && setB.length == labelB.length) {
      final common = setA.intersection(setB);
      final batch = common.intersection(outSet);
      if (batch.isEmpty) {
        // Pure tensordot candidate
        final contractedA = [for (final c in common) labelA.indexOf(c)];
        final contractedB = [for (final c in common) labelB.indexOf(c)];
        final freeA = [
          for (var i = 0; i < labelA.length; i++)
            if (!common.contains(labelA[i])) labelA[i],
        ];
        final freeB = [
          for (var i = 0; i < labelB.length; i++)
            if (!common.contains(labelB[i])) labelB[i],
        ];
        final tdOutputLabels = [...freeA, ...freeB].join();

        if (tdOutputLabels == outputPart) {
          return operands[0].tensordot(
            operands[1],
            contractAxes: (self: contractedA, other: contractedB),
          );
        } else if (tdOutputLabels.length == outputPart.length &&
            tdOutputLabels.split('').toSet().containsAll(outSet)) {
          final td = operands[0].tensordot(
            operands[1],
            contractAxes: (self: contractedA, other: contractedB),
          );
          final perm = [
            for (var i = 0; i < outputPart.length; i++)
              tdOutputLabels.indexOf(outputPart[i]),
          ];
          return td.transpose(perm);
        }
      }
    }
  }

  // Universal multi-index contraction loop
  final uniqueLabels = <String>[];
  // Prioritize output labels first, followed by contracted labels
  for (var i = 0; i < outputPart.length; i++) {
    uniqueLabels.add(outputPart[i]);
  }
  for (final label in inputLabels) {
    for (var i = 0; i < label.length; i++) {
      final ch = label[i];
      if (!uniqueLabels.contains(ch)) {
        uniqueLabels.add(ch);
      }
    }
  }

  final varDims = [for (final v in uniqueLabels) dimMap[v]!];
  final totalSteps = varDims.isEmpty
      ? 1
      : varDims.fold(1, (prod, d) => prod * d);

  final firstOp = operands.first;
  final field = firstOp.type.field;
  final outTensor = Tensor<T>.filled(
    field.additiveIdentity,
    shape: outShape,
    type: firstOp.type,
  );

  if (totalSteps == 0) return outTensor;

  final opVarIndices = [
    for (final label in inputLabels)
      [for (var i = 0; i < label.length; i++) uniqueLabels.indexOf(label[i])],
  ];
  final outVarIndices = [
    for (var i = 0; i < outputPart.length; i++)
      uniqueLabels.indexOf(outputPart[i]),
  ];

  final currentCoords = List<int>.filled(uniqueLabels.length, 0);
  final opCoords = [for (final op in operands) List<int>.filled(op.rank, 0)];
  final outCoord = List<int>.filled(outShape.length, 0);

  for (var step = 0; step < totalSteps; step++) {
    // Compute operand product
    var prod = field.multiplicativeIdentity;
    for (var opIdx = 0; opIdx < operands.length; opIdx++) {
      final op = operands[opIdx];
      final coord = opCoords[opIdx];
      final indices = opVarIndices[opIdx];
      for (var a = 0; a < op.rank; a++) {
        coord[a] = currentCoords[indices[a]];
      }
      prod = field.mul(prod, op.getValue(coord));
    }

    // Accumulate into output
    for (var a = 0; a < outShape.length; a++) {
      outCoord[a] = currentCoords[outVarIndices[a]];
    }
    final existing = outTensor.getValue(outCoord);
    outTensor.setValue(outCoord, field.add(existing, prod));

    // Advance odometer
    for (var d = uniqueLabels.length - 1; d >= 0; d--) {
      currentCoords[d]++;
      if (currentCoords[d] < varDims[d]) {
        break;
      }
      currentCoords[d] = 0;
    }
  }

  return outTensor;
}
