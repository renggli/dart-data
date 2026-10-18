import 'package:data/symbolic.dart';

/// Top-level statement in the calculator input language.
sealed class CalcStatement {
  const new();
}

/// Variable assignment statement: `name := rhs`.
final class AssignmentStatement extends CalcStatement {
  const new(this.name, this.rhs);

  final String name;
  final CalcNode rhs;
}

/// User function definition statement: `name(p1, p2, ...) := body`.
final class FunctionDefStatement extends CalcStatement {
  const new(this.name, this.params, this.body);

  final String name;
  final List<String> params;
  final CalcNode body;
}

/// Expression or command evaluation statement.
final class EvalStatement extends CalcStatement {
  const new(this.node);

  final CalcNode node;
}

/// Sequence of statements separated by newlines or semicolons in a single cell.
final class MultiStatement extends CalcStatement {
  const new(this.statements);

  final List<CalcStatement> statements;
}

/// AST node in the calculator input language (superset of [Expr]).
sealed class CalcNode {
  const new();
}

/// Scalar [Expr] literal node (number, constant, variable).
final class ExprLeafNode extends CalcNode {
  const new(this.expr);

  final Expr expr;
}

/// Named symbol / variable identifier node (`x`, `A`).
final class SymbolNode extends CalcNode {
  const new(this.name);

  final String name;
}

/// Result reference node (`r[1]`, `r[-1]`).
final class ResultRefNode extends CalcNode {
  const new(this.index);

  final int index;
}

/// Vector literal node (`[e1, e2, ...]`).
final class VectorLiteralNode extends CalcNode {
  const new(this.elements);

  final List<CalcNode> elements;
}

/// Matrix literal node (`[[a, b], [c, d]]`).
final class MatrixLiteralNode extends CalcNode {
  const new(this.rows);

  final List<List<CalcNode>> rows;
}

/// Function or command call node (`diff(r[1], x)`, `sin(x)`).
final class CallNode extends CalcNode {
  const new(this.name, this.args);

  final String name;
  final List<CalcNode> args;
}

/// Unary prefix or postfix operation on a [CalcNode].
enum CalcUnaryOp { negate, plus, factorial, transpose }

final class UnaryOpNode extends CalcNode {
  const new(this.op, this.operand);

  final CalcUnaryOp op;
  final CalcNode operand;
}

/// Binary infix operation between two [CalcNode]s.
enum CalcBinaryOp { add, sub, mul, div, pow, eq, ne, lt, le, gt, ge }

final class BinaryOpNode extends CalcNode {
  const new(this.op, this.left, this.right);

  final CalcBinaryOp op;
  final CalcNode left;
  final CalcNode right;
}

/// Token in an RPN command-line stream.
sealed class RpnToken {
  const new();
}

/// Push a parsed [CalcNode] (number, `'algebraic'`, `[vector]`, `[[matrix]]`,
/// `r[n]`) onto the stack.
final class RpnPushNodeToken extends RpnToken {
  const new(this.node, this.rawText);

  final CalcNode node;
  final String rawText;
}

/// Execute an operator or command (`+`, `-`, `*`, `/`, `^`, `factor`, `SWAP`,
/// `'a' STO`) or push a symbol if unbound.
final class RpnCommandToken extends RpnToken {
  const new(this.name);

  final String name;
}
