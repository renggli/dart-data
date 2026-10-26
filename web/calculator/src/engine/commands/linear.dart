import 'package:data/linear.dart';
import 'package:data/symbolic.dart';

import '../../model/value.dart';
import '../commands.dart';

/// Builds canonical linear algebra commands (`det`, `inv`, `transpose`,
/// `trace`, `charpoly`, `rank`, `rref`, `nullspace`, `eigenvals`,
/// `eigenvects`, `identity`, `zeros`, `dot`, `cross`, `norm`).
List<Command> buildLinearCommands() => [
  Command(
    name: 'det',
    category: CommandCategory.linear,
    signature: 'det(A)',
    paramSpecs: const [ParamSpec.expr('A')],
    minArity: 1,
    maxArity: 1,
    doc: 'Computes the exact symbolic determinant using Bareiss elimination.',
    examples: const [
      'det([[a, b], [c, d]])',
      'det([[1, 2, 3], [0, 4, 5], [1, 0, 6]])',
    ],
    rpnLabel: 'Det',
    rpnArity: 1,
    appliesTo: (v) => v is MatrixValue && v.matrix.isSquare,
    chipLabel: 'det',
    buildChipCall: (id, _) => 'det(r[$id])',
    run: (args, ctx) {
      checkCommandArity('det', args, 1, 1);
      final m = expectCommandMatrix(args[0], 'det');
      return ExprValue(m.determinant());
    },
  ),
  Command(
    name: 'inv',
    category: CommandCategory.linear,
    signature: 'inv(A)',
    paramSpecs: const [ParamSpec.expr('A')],
    minArity: 1,
    maxArity: 1,
    doc: 'Computes the exact symbolic matrix inverse A⁻¹.',
    examples: const ['inv([[a, b], [c, d]])', 'inv([[2, 1], [1, 1]])'],
    rpnLabel: 'Inv',
    rpnArity: 1,
    appliesTo: (v) => v is MatrixValue && v.matrix.isSquare,
    chipLabel: 'inv',
    buildChipCall: (id, _) => 'inv(r[$id])',
    run: (args, ctx) {
      checkCommandArity('inv', args, 1, 1);
      final m = expectCommandMatrix(args[0], 'inv');
      final inv = m.inverse();
      if (inv == null) {
        throw StateError('Matrix is singular (determinant is 0).');
      }
      return MatrixValue(inv);
    },
  ),
  Command(
    name: 'transpose',
    category: CommandCategory.linear,
    signature: 'transpose(A)',
    paramSpecs: const [ParamSpec.expr('A')],
    minArity: 1,
    maxArity: 1,
    doc: 'Returns the matrix transpose Aᵀ (also available via postfix A\').',
    examples: const ['transpose([[1, 2, 3], [4, 5, 6]])', '[[1, 2], [3, 4]]\''],
    rpnLabel: 'Transpose',
    rpnArity: 1,
    appliesTo: (v) => v is MatrixValue,
    chipLabel: 'Aᵀ',
    buildChipCall: (id, _) => 'transpose(r[$id])',
    run: (args, ctx) {
      checkCommandArity('transpose', args, 1, 1);
      final m = expectCommandMatrix(args[0], 'transpose');
      return MatrixValue(m.transposed);
    },
  ),
  Command(
    name: 'trace',
    category: CommandCategory.linear,
    signature: 'trace(A)',
    paramSpecs: const [ParamSpec.expr('A')],
    minArity: 1,
    maxArity: 1,
    doc: 'Computes the sum of diagonal elements of a square matrix.',
    examples: const ['trace([[a, b], [c, d]])'],
    rpnLabel: 'Trace',
    rpnArity: 1,
    appliesTo: (v) => v is MatrixValue && v.matrix.isSquare,
    chipLabel: 'trace',
    buildChipCall: (id, _) => 'trace(r[$id])',
    run: (args, ctx) {
      checkCommandArity('trace', args, 1, 1);
      final m = expectCommandMatrix(args[0], 'trace');
      if (!m.isSquare) {
        throw ArgumentError('trace requires a square matrix.');
      }
      return ExprValue(m.trace.simplify(assumptions: ctx.assumptions));
    },
  ),
  Command(
    name: 'charpoly',
    category: CommandCategory.linear,
    signature: 'charpoly(A, [lambda])',
    paramSpecs: const [ParamSpec.expr('A'), ParamSpec.symbol('[lambda]')],
    minArity: 1,
    maxArity: 2,
    doc: 'Computes the characteristic polynomial det(λI - A).',
    examples: const ['charpoly([[2, 1], [1, 2]], x)'],
    rpnLabel: 'CharPoly',
    rpnArity: 1,
    appliesTo: (v) => v is MatrixValue && v.matrix.isSquare,
    chipLabel: 'charpoly',
    buildChipCall: (id, _) => 'charpoly(r[$id], x)',
    run: (args, ctx) {
      checkCommandArity('charpoly', args, 1, 2);
      final m = expectCommandMatrix(args[0], 'charpoly');
      final v = args.length == 2
          ? expectCommandVarName(args[1], 'charpoly')
          : 'x';
      return ExprValue(m.characteristicPolynomial(v));
    },
  ),
  Command(
    name: 'rank',
    category: CommandCategory.linear,
    signature: 'rank(A)',
    paramSpecs: const [ParamSpec.expr('A')],
    minArity: 1,
    maxArity: 1,
    doc: 'Computes the exact algebraic rank of a matrix.',
    examples: const ['rank([[1, 2, 3], [2, 4, 6], [1, 1, 1]])'],
    rpnLabel: 'Rank',
    rpnArity: 1,
    appliesTo: (_) => false,
    chipLabel: 'rank',
    buildChipCall: (id, _) => 'rank(r[$id])',
    run: (args, ctx) {
      checkCommandArity('rank', args, 1, 1);
      final m = expectCommandMatrix(args[0], 'rank');
      return ExprValue(IntegerNumber.of(m.rank()));
    },
  ),
  Command(
    name: 'rref',
    category: CommandCategory.linear,
    signature: 'rref(A)',
    paramSpecs: const [ParamSpec.expr('A')],
    minArity: 1,
    maxArity: 1,
    doc: 'Computes the Reduced Row Echelon Form (RREF) of a matrix.',
    examples: const [
      'rref([[1, 2, -1, -4], [2, 3, -1, -11], [-2, 0, -3, 22]])',
    ],
    rpnLabel: 'RREF',
    rpnArity: 1,
    appliesTo: (v) => v is MatrixValue,
    chipLabel: 'rref',
    buildChipCall: (id, _) => 'rref(r[$id])',
    run: (args, ctx) {
      checkCommandArity('rref', args, 1, 1);
      final m = expectCommandMatrix(args[0], 'rref');
      return MatrixValue(m.rowEchelon());
    },
  ),
  Command(
    name: 'nullspace',
    category: CommandCategory.linear,
    signature: 'nullspace(A)',
    paramSpecs: const [ParamSpec.expr('A')],
    minArity: 1,
    maxArity: 1,
    doc: 'Computes a basis of vectors for the right nullspace ker(A).',
    examples: const ['nullspace([[1, 2, 3], [4, 5, 6], [7, 8, 9]])'],
    rpnLabel: 'NullSpace',
    rpnArity: 1,
    appliesTo: (_) => false,
    chipLabel: 'nullspace',
    buildChipCall: (id, _) => 'nullspace(r[$id])',
    run: (args, ctx) {
      checkCommandArity('nullspace', args, 1, 1);
      final m = expectCommandMatrix(args[0], 'nullspace');
      final basis = m.nullSpace();
      return ListValue([for (final v in basis) VectorValue(v)]);
    },
  ),
  Command(
    name: 'eigenvals',
    category: CommandCategory.linear,
    signature: 'eigenvals(A)',
    paramSpecs: const [ParamSpec.expr('A')],
    minArity: 1,
    maxArity: 1,
    doc: 'Computes the symbolic eigenvalues of a square matrix.',
    examples: const [
      'eigenvals([[2, 1], [1, 2]])',
      'eigenvals([[0, -1], [1, 0]])',
    ],
    rpnLabel: 'Eigenvalues',
    rpnArity: 1,
    appliesTo: (v) => v is MatrixValue && v.matrix.isSquare,
    chipLabel: 'eigen',
    buildChipCall: (id, _) => 'eigenvals(r[$id])',
    run: (args, ctx) {
      checkCommandArity('eigenvals', args, 1, 1);
      final m = expectCommandMatrix(args[0], 'eigenvals');
      final vals = m.eigenvalues();
      return ListValue([for (final e in vals) ExprValue(e)]);
    },
  ),
  Command(
    name: 'eigenvects',
    category: CommandCategory.linear,
    signature: 'eigenvects(A)',
    paramSpecs: const [ParamSpec.expr('A')],
    minArity: 1,
    maxArity: 1,
    doc: 'Computes eigenvalues and basis eigenvectors of a square matrix.',
    examples: const ['eigenvects([[2, 1], [1, 2]])'],
    rpnLabel: 'Eigenvectors',
    rpnArity: 1,
    appliesTo: (_) => false,
    chipLabel: 'eigenvects',
    buildChipCall: (id, _) => 'eigenvects(r[$id])',
    run: (args, ctx) {
      checkCommandArity('eigenvects', args, 1, 1);
      final m = expectCommandMatrix(args[0], 'eigenvects');
      final pairs = m.eigenvectors();
      return ListValue([
        for (final p in pairs)
          ListValue([
            ExprValue(p.eigenvalue),
            ExprValue(IntegerNumber.of(p.algebraicMultiplicity)),
            ListValue([for (final v in p.eigenvectors) VectorValue(v)]),
          ]),
      ]);
    },
  ),
  Command(
    name: 'identity',
    category: CommandCategory.linear,
    signature: 'identity(n)',
    paramSpecs: const [ParamSpec.expr('n')],
    minArity: 1,
    maxArity: 1,
    doc: 'Creates an n × n symbolic identity matrix.',
    examples: const ['identity(3)'],
    rpnLabel: 'Identity',
    rpnArity: 1,
    appliesTo: (_) => false,
    chipLabel: 'identity',
    buildChipCall: (id, _) => 'identity(3)',
    run: (args, ctx) {
      checkCommandArity('identity', args, 1, 1);
      final n = expectCommandInt(args[0], 'identity');
      if (n < 1 || n > 32) {
        throw ArgumentError('identity dimension must be between 1 and 32.');
      }
      return MatrixValue(Matrix<Expr>.identity(n, type: exprDataType));
    },
  ),
  Command(
    name: 'zeros',
    category: CommandCategory.linear,
    signature: 'zeros(m, [n])',
    paramSpecs: const [ParamSpec.expr('m'), ParamSpec.optionalInt('[n]')],
    minArity: 1,
    maxArity: 2,
    doc: 'Creates an m × n matrix (or m-vector) of zeros.',
    examples: const ['zeros(2, 3)', 'zeros(4)'],
    rpnLabel: 'Zeros',
    rpnArity: 2,
    appliesTo: (_) => false,
    chipLabel: 'zeros',
    buildChipCall: (id, _) => 'zeros(3, 3)',
    run: (args, ctx) {
      checkCommandArity('zeros', args, 1, 2);
      final m = expectCommandInt(args[0], 'zeros');
      if (args.length == 1) {
        return VectorValue(
          Vector<Expr>.generate(
            m,
            (_) => IntegerNumber.zero,
            type: exprDataType,
          ),
        );
      }
      final n = expectCommandInt(args[1], 'zeros');
      return MatrixValue(
        Matrix<Expr>.generate(
          m,
          n,
          (_, _) => IntegerNumber.zero,
          type: exprDataType,
        ),
      );
    },
  ),
  Command(
    name: 'dot',
    category: CommandCategory.linear,
    signature: 'dot(u, v)',
    paramSpecs: const [ParamSpec.expr('u'), ParamSpec.expr('v')],
    minArity: 2,
    maxArity: 2,
    doc: 'Computes the symbolic dot product u · v of two vectors.',
    examples: const ['dot([1, x, x^2], [2, 3, 4])'],
    rpnLabel: 'Dot',
    rpnArity: 2,
    appliesTo: (_) => false,
    chipLabel: 'dot',
    buildChipCall: (id, _) => 'dot(r[$id], r[$id])',
    run: (args, ctx) {
      checkCommandArity('dot', args, 2, 2);
      final u = expectCommandVector(args[0], 'dot');
      final v = expectCommandVector(args[1], 'dot');
      if (u.length != v.length) {
        throw ArgumentError(
          'dot requires vectors of equal length (${u.length} != ${v.length}).',
        );
      }
      var sum = IntegerNumber.zero as Expr;
      for (var i = 0; i < u.length; i++) {
        sum = (sum + u.getUnchecked(i) * v.getUnchecked(i)).simplify();
      }
      return ExprValue(sum);
    },
  ),
  Command(
    name: 'cross',
    category: CommandCategory.linear,
    signature: 'cross(u, v)',
    paramSpecs: const [ParamSpec.expr('u'), ParamSpec.expr('v')],
    minArity: 2,
    maxArity: 2,
    doc: 'Computes the 3D vector cross product u × v.',
    examples: const ['cross([1, 0, 0], [0, 1, 0])'],
    rpnLabel: 'Cross',
    rpnArity: 2,
    appliesTo: (_) => false,
    chipLabel: 'cross',
    buildChipCall: (id, _) => 'cross(r[$id], r[$id])',
    run: (args, ctx) {
      checkCommandArity('cross', args, 2, 2);
      final u = expectCommandVector(args[0], 'cross');
      final v = expectCommandVector(args[1], 'cross');
      if (u.length != 3 || v.length != 3) {
        throw ArgumentError('cross product is only defined for 3D vectors.');
      }
      final c0 = (u[1] * v[2] - u[2] * v[1]).simplify();
      final c1 = (u[2] * v[0] - u[0] * v[2]).simplify();
      final c2 = (u[0] * v[1] - u[1] * v[0]).simplify();
      return VectorValue(
        Vector<Expr>.fromList([c0, c1, c2], type: exprDataType),
      );
    },
  ),
  Command(
    name: 'norm',
    category: CommandCategory.linear,
    signature: 'norm(v)',
    paramSpecs: const [ParamSpec.expr('v')],
    minArity: 1,
    maxArity: 1,
    doc: 'Computes the Euclidean norm ||v||₂ of a vector or Frobenius norm of a matrix.',
    examples: const ['norm([3, 4])', 'norm([x, y, z])'],
    rpnLabel: 'Norm',
    rpnArity: 1,
    appliesTo: (v) => v is VectorValue,
    chipLabel: '||v||',
    buildChipCall: (id, _) => 'norm(r[$id])',
    run: (args, ctx) {
      checkCommandArity('norm', args, 1, 1);
      if (args[0] case VectorValue(:final vector)) {
        var sumSq = IntegerNumber.zero as Expr;
        for (var i = 0; i < vector.length; i++) {
          final item = vector.getUnchecked(i);
          sumSq = (sumSq + item * item).simplify();
        }
        return ExprValue(
          Pow(
            sumSq,
            FractionNumber.half,
          ).simplify(assumptions: ctx.assumptions),
        );
      }
      if (args[0] case MatrixValue(:final matrix)) {
        var sumSq = IntegerNumber.zero as Expr;
        for (var r = 0; r < matrix.rowCount; r++) {
          for (var c = 0; c < matrix.colCount; c++) {
            final item = matrix.getUnchecked(r, c);
            sumSq = (sumSq + item * item).simplify();
          }
        }
        return ExprValue(
          Pow(
            sumSq,
            FractionNumber.half,
          ).simplify(assumptions: ctx.assumptions),
        );
      }
      final e = expectCommandExpr(args[0], 'norm');
      return ExprValue(Abs(e).simplify(assumptions: ctx.assumptions));
    },
  ),
];
