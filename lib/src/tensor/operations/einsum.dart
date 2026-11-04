import '../tensor.dart';
import 'matmul.dart';

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

  int dimOf(String label) => dimMap[label] ?? 0;

  final outShape = [
    for (var i = 0; i < outputPart.length; i++) dimOf(outputPart[i]),
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

  // Fast path: two operands without duplicate labels within an operand
  if (operands.length == 2) {
    final labelA = inputLabels[0];
    final labelB = inputLabels[1];
    final setA = labelA.split('').toSet();
    final setB = labelB.split('').toSet();
    final outSet = outputPart.split('').toSet();

    if (setA.length == labelA.length && setB.length == labelB.length) {
      final common = setA.intersection(setB);
      final batch = common.intersection(outSet);
      final contracted = common.difference(outSet);
      final freeA = setA.difference(common);
      final freeB = setB.difference(common);

      if (freeA.every(outSet.contains) &&
          freeB.every(outSet.contains) &&
          outSet.length == batch.length + freeA.length + freeB.length &&
          (contracted.isNotEmpty || freeA.isNotEmpty || freeB.isNotEmpty)) {
        final opA = operands[0];
        final opB = operands[1];

        // Maintain consistent batch order matching outputPart
        final batchList = [
          for (var i = 0; i < outputPart.length; i++)
            if (batch.contains(outputPart[i])) outputPart[i],
        ];
        final freeAList = [
          for (var i = 0; i < labelA.length; i++)
            if (freeA.contains(labelA[i])) labelA[i],
        ];
        final freeBList = [
          for (var i = 0; i < labelB.length; i++)
            if (freeB.contains(labelB[i])) labelB[i],
        ];
        final contractedList = [
          for (var i = 0; i < labelA.length; i++)
            if (contracted.contains(labelA[i])) labelA[i],
        ];

        final permA = [
          for (final c in [...batchList, ...freeAList, ...contractedList])
            labelA.indexOf(c),
        ];
        final permB = [
          for (final c in [...batchList, ...contractedList, ...freeBList])
            labelB.indexOf(c),
        ];

        final batchShape = [for (final c in batchList) dimOf(c)];
        final shapeFreeA = [for (final c in freeAList) dimOf(c)];
        final shapeFreeB = [for (final c in freeBList) dimOf(c)];
        final shapeContracted = [for (final c in contractedList) dimOf(c)];

        final sizeFreeA = shapeFreeA.fold(1, (prod, d) => prod * d);
        final sizeFreeB = shapeFreeB.fold(1, (prod, d) => prod * d);
        final sizeContracted = shapeContracted.fold(1, (prod, d) => prod * d);

        final transA = _isIdentityPermutation(permA)
            ? opA
            : opA.transpose(permA);
        final transB = _isIdentityPermutation(permB)
            ? opB
            : opB.transpose(permB);

        final matA = transA.reshape([...batchShape, sizeFreeA, sizeContracted]);
        final matB = transB.reshape([...batchShape, sizeContracted, sizeFreeB]);

        final prodMat = matA.matmul(matB);
        final reshaped = prodMat.reshape([
          ...batchShape,
          ...shapeFreeA,
          ...shapeFreeB,
        ]);

        final intermediateLabels = [
          ...batchList,
          ...freeAList,
          ...freeBList,
        ].join();
        if (intermediateLabels == outputPart) {
          return reshaped;
        } else {
          final outPerm = [
            for (var i = 0; i < outputPart.length; i++)
              intermediateLabels.indexOf(outputPart[i]),
          ];
          return reshaped.transpose(outPerm);
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

  final varDims = [for (final v in uniqueLabels) dimOf(v)];
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

  final numVars = uniqueLabels.length;
  final numOps = operands.length;

  final outStrideDelta = List<int>.filled(numVars, 0);
  final outStrideReset = List<int>.filled(numVars, 0);
  for (var d = 0; d < numVars; d++) {
    final v = uniqueLabels[d];
    var delta = 0;
    for (var a = 0; a < outputPart.length; a++) {
      if (outputPart[a] == v) {
        delta += outTensor.layout.strides[a];
      }
    }
    outStrideDelta[d] = delta;
    outStrideReset[d] = -(varDims[d] - 1) * delta;
  }

  final opStrideDelta = [
    for (var opIdx = 0; opIdx < numOps; opIdx++) List<int>.filled(numVars, 0),
  ];
  final opStrideReset = [
    for (var opIdx = 0; opIdx < numOps; opIdx++) List<int>.filled(numVars, 0),
  ];
  for (var opIdx = 0; opIdx < numOps; opIdx++) {
    final op = operands[opIdx];
    final label = inputLabels[opIdx];
    for (var d = 0; d < numVars; d++) {
      final v = uniqueLabels[d];
      var delta = 0;
      for (var a = 0; a < label.length; a++) {
        if (label[a] == v) {
          delta += op.layout.strides[a];
        }
      }
      opStrideDelta[opIdx][d] = delta;
      opStrideReset[opIdx][d] = -(varDims[d] - 1) * delta;
    }
  }

  var outOffset = outTensor.layout.offset;
  final opOffsets = [for (final op in operands) op.layout.offset];

  final outData = outTensor.data;
  final opData = [for (final op in operands) op.data];

  final currentCoords = List<int>.filled(numVars, 0);

  for (var step = 0; step < totalSteps; step++) {
    // Compute operand product
    var prod = opData[0][opOffsets[0]];
    for (var opIdx = 1; opIdx < numOps; opIdx++) {
      prod = field.mul(prod, opData[opIdx][opOffsets[opIdx]]);
    }

    // Accumulate into output
    outData[outOffset] = field.add(outData[outOffset], prod);

    // Advance odometer
    for (var d = numVars - 1; d >= 0; d--) {
      currentCoords[d]++;
      if (currentCoords[d] < varDims[d]) {
        outOffset += outStrideDelta[d];
        for (var opIdx = 0; opIdx < numOps; opIdx++) {
          opOffsets[opIdx] += opStrideDelta[opIdx][d];
        }
        break;
      }
      currentCoords[d] = 0;
      outOffset += outStrideReset[d];
      for (var opIdx = 0; opIdx < numOps; opIdx++) {
        opOffsets[opIdx] += opStrideReset[opIdx][d];
      }
    }
  }

  return outTensor;
}

bool _isIdentityPermutation(List<int> perm) {
  for (var i = 0; i < perm.length; i++) {
    if (perm[i] != i) return false;
  }
  return true;
}
