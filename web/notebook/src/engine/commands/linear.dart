import 'package:data/linear.dart';
import 'package:data/symbolic.dart';

import '../../language/signature.dart';
import '../../model/value.dart';
import '../commands.dart';

final List<Command> linearCommands = [
  Command(
    name: 'det',
    category: CommandCategory.linear,
    signature: const FunctionSignature(
      positional: [ParamSpec.positional('matrix', type: ParamType.matrix)],
    ),
    doc: 'Computes the symbolic determinant of a square matrix.',
    examples: ['det([[1, 2], [3, 4]])', 'det([[a, b], [c, d]])'],
    chipLabel: 'det',
    appliesTo: (v) => v is MatrixValue && v.matrix.isSquare,
    buildChipCall: (input, _) => 'det($input)',
    run: (args, ctx) => ExprValue(
      args.matrix('matrix').determinant(assumptions: ctx.assumptions),
    ),
  ),
  Command(
    name: 'inv',
    category: CommandCategory.linear,
    signature: const FunctionSignature(
      positional: [ParamSpec.positional('matrix', type: ParamType.matrix)],
    ),
    doc: 'Computes the symbolic inverse of an invertible square matrix.',
    examples: ['inv([[1, 2], [3, 4]])'],
    chipLabel: 'inv',
    appliesTo: (v) => v is MatrixValue && v.matrix.isSquare,
    buildChipCall: (input, _) => 'inv($input)',
    run: (args, _) {
      final inv = args.matrix('matrix').inverse();
      if (inv == null) {
        return const ErrorValue('Matrix is singular and cannot be inverted');
      }
      return MatrixValue(inv.simplify());
    },
  ),
  Command(
    name: 'transpose',
    category: CommandCategory.linear,
    signature: const FunctionSignature(
      positional: [ParamSpec.positional('matrix', type: ParamType.matrix)],
    ),
    doc: 'Computes the transpose of a matrix.',
    examples: ['transpose([[1, 2, 3], [4, 5, 6]])'],
    chipLabel: 'transpose',
    appliesTo: (v) => v is MatrixValue,
    buildChipCall: (input, _) => 'transpose($input)',
    run: (args, _) {
      final m = args.matrix('matrix');
      return MatrixValue(
        Matrix<Expr>.generate(
          m.colCount,
          m.rowCount,
          (r, c) => m.getUnchecked(c, r),
          type: exprDataType,
        ),
      );
    },
  ),
  Command(
    name: 'trace',
    category: CommandCategory.linear,
    signature: const FunctionSignature(
      positional: [ParamSpec.positional('matrix', type: ParamType.matrix)],
    ),
    doc: 'Computes the trace (sum of diagonal entries) of a square matrix.',
    examples: ['trace([[1, 2], [3, 4]])'],
    run: (args, ctx) => ExprValue(
      args.matrix('matrix').trace.simplify(assumptions: ctx.assumptions),
    ),
  ),
  Command(
    name: 'charpoly',
    category: CommandCategory.linear,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('matrix', type: ParamType.matrix),
        ParamSpec.optional('var', type: ParamType.symbol),
      ],
    ),
    doc: 'Computes the characteristic polynomial det(lambda*I - A).',
    examples: ['charpoly([[1, 2], [3, 4]], lambda)'],
    run: (args, ctx) {
      final v = args.symbolOrNull('var') ?? 'lambda';
      return ExprValue(
        args
            .matrix('matrix')
            .characteristicPolynomial(lambda: v, assumptions: ctx.assumptions),
      );
    },
  ),
  Command(
    name: 'rank',
    category: CommandCategory.linear,
    signature: const FunctionSignature(
      positional: [ParamSpec.positional('matrix', type: ParamType.matrix)],
    ),
    doc: 'Computes the symbolic rank of a matrix.',
    examples: ['rank([[1, 2], [2, 4]])'],
    run: (args, _) => ExprValue(IntegerNumber.of(args.matrix('matrix').rank())),
  ),
  Command(
    name: 'rref',
    category: CommandCategory.linear,
    signature: const FunctionSignature(
      positional: [ParamSpec.positional('matrix', type: ParamType.matrix)],
    ),
    doc: 'Computes the reduced row echelon form (RREF) of a matrix.',
    examples: ['rref([[1, 2, 3], [4, 5, 6]])'],
    chipLabel: 'RREF',
    appliesTo: (v) => v is MatrixValue,
    buildChipCall: (input, _) => 'rref($input)',
    run: (args, _) =>
        MatrixValue(args.matrix('matrix').rowEchelon().simplify()),
  ),
  Command(
    name: 'nullspace',
    category: CommandCategory.linear,
    signature: const FunctionSignature(
      positional: [ParamSpec.positional('matrix', type: ParamType.matrix)],
    ),
    doc: 'Computes a basis for the nullspace (kernel) of a matrix.',
    examples: ['nullspace([[1, 2], [2, 4]])'],
    run: (args, _) {
      final basis = args.matrix('matrix').nullSpace();
      return ListValue([for (final v in basis) VectorValue(v.simplify())]);
    },
  ),
  Command(
    name: 'eigenvals',
    aliases: ['eigenvalues'],
    category: CommandCategory.linear,
    signature: const FunctionSignature(
      positional: [ParamSpec.positional('matrix', type: ParamType.matrix)],
    ),
    doc: 'Computes the symbolic eigenvalues of a square matrix.',
    examples: ['eigenvals([[2, 1], [1, 2]])'],
    chipLabel: 'eigenvals',
    appliesTo: (v) => v is MatrixValue && v.matrix.isSquare,
    buildChipCall: (input, _) => 'eigenvals($input)',
    run: (args, _) {
      final vals = args.matrix('matrix').eigenvalues();
      return ListValue([for (final e in vals) ExprValue(e)]);
    },
  ),
  Command(
    name: 'eigenvects',
    aliases: ['eigenvectors'],
    category: CommandCategory.linear,
    signature: const FunctionSignature(
      positional: [ParamSpec.positional('matrix', type: ParamType.matrix)],
    ),
    doc: 'Computes symbolic eigenvalues and eigenvectors of a square matrix.',
    examples: ['eigenvects([[2, 1], [1, 2]])'],
    run: (args, _) {
      final pairs = args.matrix('matrix').eigenvectors();
      return ListValue([
        for (final pair in pairs)
          ListValue([
            ExprValue(pair.eigenvalue),
            ListValue([
              for (final vec in pair.eigenvectors) VectorValue(vec.simplify()),
            ]),
          ]),
      ]);
    },
  ),
  Command(
    name: 'identity',
    category: CommandCategory.linear,
    signature: const FunctionSignature(
      positional: [ParamSpec.positional('n', type: ParamType.integer)],
    ),
    doc: 'Constructs an n x n symbolic identity matrix.',
    examples: ['identity(3)'],
    run: (args, _) {
      final n = args.intVal('n');
      return MatrixValue(Matrix<Expr>.identity(n, type: exprDataType));
    },
  ),
  Command(
    name: 'zeros',
    category: CommandCategory.linear,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('rows', type: ParamType.integer),
        ParamSpec.optional('cols', type: ParamType.integer),
      ],
    ),
    doc: 'Constructs a zero vector or zero matrix.',
    examples: ['zeros(3)', 'zeros(2, 3)'],
    run: (args, _) {
      final rows = args.intVal('rows');
      final cols = args.intOrNull('cols');
      if (cols == null) {
        return VectorValue(
          Vector<Expr>.filled(rows, IntegerNumber.zero, type: exprDataType),
        );
      }
      return MatrixValue(
        Matrix<Expr>.filled(rows, cols, IntegerNumber.zero, type: exprDataType),
      );
    },
  ),
  Command(
    name: 'dot',
    category: CommandCategory.linear,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('u', type: ParamType.vector),
        ParamSpec.positional('v', type: ParamType.vector),
      ],
    ),
    doc: 'Computes the dot product of two symbolic vectors.',
    examples: ['dot([1, 2, 3], [4, 5, 6])'],
    run: (args, ctx) => ExprValue(
      args
          .vector('u')
          .dot(args.vector('v'))
          .simplify(assumptions: ctx.assumptions),
    ),
  ),
  Command(
    name: 'cross',
    category: CommandCategory.linear,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('u', type: ParamType.vector),
        ParamSpec.positional('v', type: ParamType.vector),
      ],
    ),
    doc: 'Computes the 3D cross product of two 3-element vectors.',
    examples: ['cross([1, 0, 0], [0, 1, 0])'],
    run: (args, _) =>
        VectorValue(args.vector('u').cross(args.vector('v')).simplify()),
  ),
  Command(
    name: 'norm',
    category: CommandCategory.linear,
    signature: const FunctionSignature(
      positional: [ParamSpec.positional('v', type: ParamType.vector)],
      named: [ParamSpec.named('p', type: ParamType.number, defaultValue: 2.0)],
    ),
    doc: 'Computes the p-norm (default Euclidean 2-norm) of a vector.',
    examples: ['norm([3, 4])', 'norm([1, -2, 3], p: 1)'],
    run: (args, ctx) {
      final v = args.vector('v');
      final p = args.doubleVal('p');
      if (p == 2.0) {
        Expr sumSq = IntegerNumber.zero;
        for (var i = 0; i < v.length; i++) {
          final e = v.getUnchecked(i);
          sumSq = sumSq + Pow(Abs(e), IntegerNumber.two);
        }
        return ExprValue(
          Pow(
            sumSq,
            FractionNumber.half,
          ).simplify(assumptions: ctx.assumptions),
        );
      }
      if (p == 1.0) {
        Expr sumAbs = IntegerNumber.zero;
        for (var i = 0; i < v.length; i++) {
          sumAbs = sumAbs + Abs(v.getUnchecked(i));
        }
        return ExprValue(sumAbs.simplify(assumptions: ctx.assumptions));
      }
      Expr sumP = IntegerNumber.zero;
      final pNum = RealNumber.fromDouble(p);
      for (var i = 0; i < v.length; i++) {
        sumP = sumP + Pow(Abs(v.getUnchecked(i)), pNum);
      }
      return ExprValue(Pow(sumP, RealNumber.fromDouble(1.0 / p)).approximate());
    },
  ),
];
