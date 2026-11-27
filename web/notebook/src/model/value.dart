import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:data/linear.dart';
import 'package:data/symbolic.dart';

/// Sealed hierarchy representing all evaluated values in the symbolic notebook.
sealed class CalcValue {
  const new();

  /// Short string identifier for the value kind.
  String get kind;

  /// Whether this value is symbolically exact (no [RealNumber] nodes).
  bool get isExact;

  /// Canonical text representation that round-trips through the parser.
  String toCanonicalText();

  /// W3C MathML representation.
  String toMathMl({bool display = false, bool root = true});

  /// LaTeX representation.
  String toLatex();

  /// Formatted numeric approximation summary when applicable, or `null`.
  String? approxSummary({int digits = 10}) => null;

  @override
  String toString() => toCanonicalText();
}

/// Scalar symbolic expression or relational equation (`Expr`).
final class ExprValue extends CalcValue {
  const new(this.expr);

  final Expr expr;

  bool get isEquation => expr is RelationalExpr;

  @override
  String get kind => isEquation ? 'equation' : 'expr';

  @override
  bool get isExact => !_containsRealNumber(expr);

  @override
  String toCanonicalText() => expr.toString();

  @override
  String toMathMl({bool display = false, bool root = true}) =>
      expr.toMathMl(display: display, root: root);

  @override
  String toLatex() => expr.toLatex();

  @override
  String? approxSummary({int digits = 10}) {
    if (!isExact) return null;
    if (expr is IntegerNumber || expr is RelationalExpr) return null;
    if (expr.freeVariables.isNotEmpty) return null;
    if (expr == Constant.infinity ||
        expr == -Constant.infinity ||
        expr == Constant.undefined) {
      return null;
    }
    final approx = expr.approximate();
    if (approx == expr) return null;
    if (approx is RealNumber) {
      final v = approx.value;
      if (v.isNaN || v.isInfinite) return null;
      return formatRealDigits(v, digits);
    }
    if (approx is ComplexNumber) {
      final re = approx.real.toDouble();
      final im = approx.imaginary.toDouble();
      if (re.isNaN || im.isNaN) return null;
      return _formatComplexDigits(re, im, digits);
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ExprValue && expr == other.expr);

  @override
  int get hashCode => Object.hash(ExprValue, expr);
}

/// String literal or text value.
final class StringValue extends CalcValue {
  const new(this.value);

  final String value;

  @override
  String get kind => 'string';

  @override
  bool get isExact => true;

  @override
  String toCanonicalText() => "'${value.replaceAll("'", "\\'")}'";

  @override
  String toMathMl({bool display = false, bool root = true}) {
    final escaped = _escapeXml(value);
    if (!root) return '<mtext>$escaped</mtext>';
    final attr = display ? ' display="block"' : '';
    return '<math$attr><mtext>$escaped</mtext></math>';
  }

  @override
  String toLatex() => '\\text{${_escapeLatexText(value)}}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is StringValue && value == other.value);

  @override
  int get hashCode => Object.hash(StringValue, value);
}

/// Boolean value (`true` or `false`).
final class BoolValue extends CalcValue {
  const new(this.value);

  final bool value;

  @override
  String get kind => 'bool';

  @override
  bool get isExact => true;

  @override
  String toCanonicalText() => value ? 'true' : 'false';

  @override
  String toMathMl({bool display = false, bool root = true}) {
    final inner = '<mi>${value ? 'true' : 'false'}</mi>';
    if (!root) return inner;
    final attr = display ? ' display="block"' : '';
    return '<math$attr>$inner</math>';
  }

  @override
  String toLatex() => '\\text{${value ? 'true' : 'false'}}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is BoolValue && value == other.value);

  @override
  int get hashCode => Object.hash(BoolValue, value);
}

/// Symbolic vector value (`[e1, e2, ...]`).
final class VectorValue extends CalcValue {
  const new(this.vector);

  final Vector<Expr> vector;

  @override
  String get kind => 'vector';

  @override
  bool get isExact {
    for (var i = 0; i < vector.length; i++) {
      if (_containsRealNumber(vector.getUnchecked(i))) return false;
    }
    return true;
  }

  @override
  String toCanonicalText() =>
      '[${[for (var i = 0; i < vector.length; i++) vector.getUnchecked(i)].join(', ')}]';

  @override
  String toMathMl({bool display = false, bool root = true}) =>
      vector.toMathMl(display: display, root: root);

  @override
  String toLatex() => vector.toLatex();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VectorValue && vector == other.vector);

  @override
  int get hashCode => Object.hash(VectorValue, vector);
}

/// Symbolic matrix value (`[[a, b], [c, d]]`).
final class MatrixValue extends CalcValue {
  const new(this.matrix);

  final Matrix<Expr> matrix;

  @override
  String get kind => 'matrix';

  @override
  bool get isExact {
    for (var r = 0; r < matrix.rowCount; r++) {
      for (var c = 0; c < matrix.colCount; c++) {
        if (_containsRealNumber(matrix.getUnchecked(r, c))) return false;
      }
    }
    return true;
  }

  @override
  String toCanonicalText() {
    final rows = [
      for (var r = 0; r < matrix.rowCount; r++)
        '[${[for (var c = 0; c < matrix.colCount; c++) matrix.getUnchecked(r, c)].join(', ')}]',
    ];
    return '[${rows.join(', ')}]';
  }

  @override
  String toMathMl({bool display = false, bool root = true}) =>
      matrix.toMathMl(display: display, root: root);

  @override
  String toLatex() => matrix.toLatex();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MatrixValue && matrix == other.matrix);

  @override
  int get hashCode => Object.hash(MatrixValue, matrix);
}

/// Ordered list of [CalcValue] elements (e.g. equation solutions).
final class ListValue extends CalcValue {
  const new(this.elements);

  final List<CalcValue> elements;

  @override
  String get kind => 'list';

  @override
  bool get isExact => elements.every((e) => e.isExact);

  @override
  String toCanonicalText() =>
      '[${elements.map((e) => e.toCanonicalText()).join(', ')}]';

  @override
  String toMathMl({bool display = false, bool root = true}) {
    final inner = elements
        .map((e) => e.toMathMl(root: false))
        .join('<mo>,</mo>');
    final wrapped = '<mrow><mo>[</mo>$inner<mo>]</mo></mrow>';
    if (!root) return wrapped;
    final attr = display ? ' display="block"' : '';
    return '<math$attr>$wrapped</math>';
  }

  @override
  String toLatex() =>
      '\\left[${elements.map((e) => e.toLatex()).join(', ')}\\right]';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ListValue &&
          const ListEquality<CalcValue>().equals(elements, other.elements));

  @override
  int get hashCode => Object.hash(ListValue, Object.hashAll(elements));
}

/// Truncated power series value wrapping [PowerSeries].
final class SeriesValue extends CalcValue {
  const new(this.series);

  final PowerSeries series;

  Expr get exprWithOrder => series.toExpr();

  @override
  String get kind => 'series';

  @override
  bool get isExact => !_containsRealNumber(exprWithOrder);

  @override
  String toCanonicalText() => exprWithOrder.toString();

  @override
  String toMathMl({bool display = false, bool root = true}) =>
      series.toMathMl(display: display, root: root);

  @override
  String toLatex() => exprWithOrder.toLatex();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeriesValue && exprWithOrder == other.exprWithOrder);

  @override
  int get hashCode => Object.hash(SeriesValue, exprWithOrder);
}

/// Kind of plot represented by a [PlotValue] across worker boundaries.
enum PlotKind {
  function2d,
  parametric2d,
  complex2d,
  ode2d,
  vectorField2d,
  heatmap2d,
  surface3d,
  complex3d,
  vectorField3d,
}

/// Interactive 2D, 3D, or complex domain-coloring plot value.
final class PlotValue extends CalcValue {
  const new({
    required this.expressions,
    required this.variable,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    this.isParametric = false,
    this.isComplex = false,
    this.isOde = false,
    this.minT,
    this.maxT,
    this.odeY0,
    this.odeMethod,
    this.title,
    this.showGrid = true,
    this.showMarkers = true,
    this.showContours = true,
    this.plotKind = PlotKind.function2d,
    this.yVariable,
    this.gridSize = 48,
  });

  final List<Expr> expressions;
  final String variable;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final bool isParametric;
  final bool isComplex;
  final bool isOde;
  final double? minT;
  final double? maxT;
  final double? odeY0;
  final String? odeMethod;
  final String? title;
  final bool showGrid;
  final bool showMarkers;
  final bool showContours;
  final PlotKind plotKind;
  final String? yVariable;
  final int gridSize;

  bool get is3d =>
      plotKind == PlotKind.surface3d ||
      plotKind == PlotKind.complex3d ||
      plotKind == PlotKind.vectorField3d;

  @override
  String get kind => 'plot';

  @override
  bool get isExact => false;

  @override
  String toCanonicalText() {
    if (plotKind == PlotKind.complex3d && expressions.isNotEmpty) {
      return 'plotcomplex3d(${expressions.first}, $variable, reFrom: ${fmtBound(minX)}, reTo: ${fmtBound(maxX)}, imFrom: ${fmtBound(minY)}, imTo: ${fmtBound(maxY)})';
    }
    if (plotKind == PlotKind.surface3d && expressions.isNotEmpty) {
      return 'plot3d(${expressions.first}, $variable, ${yVariable ?? 'y'}, xFrom: ${fmtBound(minX)}, xTo: ${fmtBound(maxX)}, yFrom: ${fmtBound(minY)}, yTo: ${fmtBound(maxY)})';
    }
    if ((plotKind == PlotKind.complex2d || isComplex) &&
        expressions.isNotEmpty) {
      return 'plotcomplex(${expressions.first}, $variable, reFrom: ${fmtBound(minX)}, reTo: ${fmtBound(maxX)}, imFrom: ${fmtBound(minY)}, imTo: ${fmtBound(maxY)})';
    }
    if ((plotKind == PlotKind.parametric2d || isParametric) &&
        expressions.length >= 2) {
      final t0 = minT ?? minX;
      final t1 = maxT ?? maxX;
      return 'parametric(${expressions[0]}, ${expressions[1]}, $variable, from: ${fmtBound(t0)}, to: ${fmtBound(t1)})';
    }
    if (expressions.length == 1) {
      return 'plot(${expressions.first}, $variable, from: ${fmtBound(minX)}, to: ${fmtBound(maxX)})';
    }
    return 'plot([${expressions.join(', ')}], $variable, from: ${fmtBound(minX)}, to: ${fmtBound(maxX)})';
  }

  @override
  String toMathMl({bool display = false, bool root = true}) {
    final inner = expressions
        .map((e) => e.toMathMl(root: false))
        .join('<mo>,</mo><mspace width="0.4em"/>');
    if (!root) return '<mrow>$inner</mrow>';
    final attr = display ? ' display="block"' : '';
    return '<math$attr><mrow>$inner</mrow></math>';
  }

  @override
  String toLatex() => expressions.map((e) => e.toLatex()).join(', ');

  static String fmtBound(double v) =>
      (v % 1 == 0 && v.abs() < 1e9) ? v.toInt().toString() : v.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlotValue &&
          plotKind == other.plotKind &&
          variable == other.variable &&
          yVariable == other.yVariable &&
          minX == other.minX &&
          maxX == other.maxX &&
          minY == other.minY &&
          maxY == other.maxY &&
          minT == other.minT &&
          maxT == other.maxT &&
          odeY0 == other.odeY0 &&
          odeMethod == other.odeMethod &&
          gridSize == other.gridSize &&
          isParametric == other.isParametric &&
          isComplex == other.isComplex &&
          is3d == other.is3d &&
          title == other.title &&
          const ListEquality<Expr>().equals(expressions, other.expressions));

  @override
  int get hashCode => Object.hash(
    PlotValue,
    plotKind,
    variable,
    yVariable,
    minX,
    maxX,
    minY,
    maxY,
    minT,
    maxT,
    odeY0,
    odeMethod,
    gridSize,
    isParametric,
    isComplex,
    is3d,
    title,
    Object.hashAll(expressions),
  );
}

/// Informational text message value.
final class InfoValue extends CalcValue {
  const new(this.message, {this.title});

  final String message;
  final String? title;

  @override
  String get kind => 'info';

  @override
  bool get isExact => true;

  @override
  String toCanonicalText() => message;

  @override
  String toMathMl({bool display = false, bool root = true}) {
    final escaped = _escapeXml(message);
    if (!root) return '<mtext>$escaped</mtext>';
    final attr = display ? ' display="block"' : '';
    return '<math$attr><mtext>$escaped</mtext></math>';
  }

  @override
  String toLatex() => '\\text{${_escapeLatexText(message)}}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InfoValue && message == other.message && title == other.title);

  @override
  int get hashCode => Object.hash(InfoValue, message, title);
}

/// Structured error value with optional character offset and suggestion.
final class ErrorValue extends CalcValue {
  const new(this.message, {this.offset, this.suggestion, this.source});

  final String message;
  final int? offset;
  final String? suggestion;
  final String? source;

  @override
  String get kind => 'error';

  @override
  bool get isExact => true;

  @override
  String toCanonicalText() => message;

  @override
  String toMathMl({bool display = false, bool root = true}) {
    final escaped = _escapeXml(message);
    if (!root) return '<mtext>$escaped</mtext>';
    final attr = display ? ' display="block"' : '';
    return '<math$attr><mtext>$escaped</mtext></math>';
  }

  @override
  String toLatex() => '\\text{${_escapeLatexText(message)}}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ErrorValue &&
          message == other.message &&
          offset == other.offset &&
          suggestion == other.suggestion &&
          source == other.source);

  @override
  int get hashCode => Object.hash(ErrorValue, message, offset, suggestion);
}

/// Formats a finite double to [digits] significant digits, stripping trailing
/// zeros.
String formatRealDigits(double v, int digits) {
  if (v == 0) return '0';
  final abs = v.abs();
  if (abs >= 1e12 || abs < 1e-6) {
    return v
        .toStringAsExponential(math.max(1, digits - 1))
        .replaceFirst(RegExp(r'\.?0+(?=e)'), '');
  }
  final s = v.toStringAsPrecision(digits);
  if (s.contains('e') || s.contains('E')) return s;
  if (!s.contains('.')) return s;
  return s.replaceFirst(RegExp(r'\.?0+$'), '');
}

String _formatComplexDigits(double re, double im, int digits) {
  if (im.abs() < 1e-12) return formatRealDigits(re, digits);
  final imStr = formatRealDigits(im.abs(), digits);
  if (re.abs() < 1e-12) {
    return im < 0 ? '-${imStr}i' : '${imStr}i';
  }
  final reStr = formatRealDigits(re, digits);
  return im < 0 ? '$reStr - ${imStr}i' : '$reStr + ${imStr}i';
}

bool _containsRealNumber(Expr expr) => expr.anyNode((n) => n is RealNumber);

String _escapeXml(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

String _escapeLatexText(String text) => text
    .replaceAll(r'\', r'\textbackslash{}')
    .replaceAll('{', r'\{')
    .replaceAll('}', r'\}')
    .replaceAll('_', r'\_')
    .replaceAll('%', r'\%')
    .replaceAll('&', r'\&');
