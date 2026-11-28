import 'package:data/symbolic.dart';

/// Top-level statement in a notebook math cell.
sealed class CalcStatement {
  const new();

  int get offset;
}

/// Variable assignment statement: `x := expr` or `x = expr`.
final class AssignmentStatement extends CalcStatement {
  const new(this.name, this.value, {required this.offset});

  final String name;
  final CalcNode value;

  @override
  final int offset;

  @override
  String toString() => '$name := $value';
}

/// Parameter definition in a [FunctionDefStatement].
final class ParamDef {
  const new(
    this.name, {
    this.isOptionalPositional = false,
    this.isNamed = false,
    this.defaultExpr,
  });

  final String name;
  final bool isOptionalPositional;
  final bool isNamed;
  final CalcNode? defaultExpr;

  @override
  String toString() {
    if (isOptionalPositional) {
      return defaultExpr == null ? '[$name]' : '[$name = $defaultExpr]';
    }
    if (isNamed) {
      return defaultExpr == null ? '{$name}' : '{$name: $defaultExpr}';
    }
    return name;
  }
}

/// User-defined function statement: `f(x, [a = 1], {scale: 2}) := body`.
final class FunctionDefStatement extends CalcStatement {
  const new(this.name, this.params, this.body, {required this.offset});

  final String name;
  final List<ParamDef> params;
  final CalcNode body;

  @override
  final int offset;

  @override
  String toString() => '$name(${params.join(', ')}) := $body';
}

/// Expression or command evaluation statement.
final class EvalStatement extends CalcStatement {
  const new(this.node);

  final CalcNode node;

  @override
  int get offset => node.offset;

  @override
  String toString() => '$node';
}

/// Multiple semicolon- or newline-separated statements in one cell.
final class MultiStatement extends CalcStatement {
  const new(this.statements, {required this.offset});

  final List<CalcStatement> statements;

  @override
  final int offset;

  @override
  String toString() => statements.join('; ');
}

/// Named argument in a [CallNode]: `name: value`.
final class NamedArg {
  const new(this.name, this.value, {required this.offset});

  final String name;
  final CalcNode value;
  final int offset;

  @override
  String toString() => '$name: $value';
}

/// Expression AST node for the notebook language.
sealed class CalcNode {
  const new(this.offset);

  final int offset;
}

/// Literal symbolic [Expr] leaf (number or constant).
final class ExprLeafNode extends CalcNode {
  const new(this.expr, int offset) : super(offset);

  final Expr expr;

  @override
  String toString() => '$expr';
}

/// String literal node: `'...'` or `"..."`.
final class StringLiteralNode extends CalcNode {
  const new(this.value, int offset) : super(offset);

  final String value;

  @override
  String toString() => "'$value'";
}

/// Boolean literal node: `true` or `false`.
final class BoolLiteralNode extends CalcNode {
  const new(this.value, int offset) : super(offset);

  final bool value;

  @override
  String toString() => value ? 'true' : 'false';
}

/// Identifier / symbol reference node.
final class SymbolNode extends CalcNode {
  const new(this.name, int offset) : super(offset);

  final String name;

  @override
  String toString() => name;
}

/// Result reference node: `r[n]` or `r[-n]`.
final class ResultRefNode extends CalcNode {
  const new(this.index, int offset) : super(offset);

  final int index;

  @override
  String toString() => 'r[$index]';
}

/// Vector literal node: `[a, b, c]`.
final class VectorLiteralNode extends CalcNode {
  const new(this.elements, int offset) : super(offset);

  final List<CalcNode> elements;

  @override
  String toString() => '[${elements.join(', ')}]';
}

/// Matrix literal node: `[[a, b], [c, d]]`.
final class MatrixLiteralNode extends CalcNode {
  const new(this.rows, int offset) : super(offset);

  final List<List<CalcNode>> rows;

  @override
  String toString() => '[${rows.map((r) => '[${r.join(', ')}]').join(', ')}]';
}

/// Function or command call node with positional and named arguments.
final class CallNode extends CalcNode {
  const new(this.name, this.positionalArgs, this.namedArgs, int offset)
    : super(offset);

  final String name;
  final List<CalcNode> positionalArgs;
  final List<NamedArg> namedArgs;

  @override
  String toString() {
    final parts = [
      for (final p in positionalArgs) '$p',
      for (final n in namedArgs) '$n',
    ];
    return '$name(${parts.join(', ')})';
  }
}

/// Prefix unary operation (`+`, `-`, `√`).
final class UnaryOpNode extends CalcNode {
  const new(this.op, this.operand, int offset) : super(offset);

  final String op;
  final CalcNode operand;

  @override
  String toString() => '$op$operand';
}

/// Postfix unary operation (`!`).
final class PostfixOpNode extends CalcNode {
  const new(this.op, this.operand, int offset) : super(offset);

  final String op;
  final CalcNode operand;

  @override
  String toString() => '$operand$op';
}

/// Infix binary operation (`+`, `-`, `*`, `/`, `^`, `=`, `<`, `<=`, `>`, `>=`, `!=`).
final class BinaryOpNode extends CalcNode {
  const new(this.op, this.left, this.right, int offset) : super(offset);

  final String op;
  final CalcNode left;
  final CalcNode right;

  @override
  String toString() => '($left $op $right)';
}

/// Range literal node (`start..end`).
final class RangeNode extends CalcNode {
  const new(this.start, this.end, int offset) : super(offset);

  final CalcNode start;
  final CalcNode end;

  @override
  String toString() => '$start..$end';
}
