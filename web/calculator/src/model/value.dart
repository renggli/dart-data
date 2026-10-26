import 'dart:math' as math;
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:data/linear.dart';
import 'package:data/symbolic.dart';

/// Sampled polyline segment for a 2D curve without vertical asymptotes.
final class PlotSegmentData {
  const new({required this.x, required this.y});

  final Float64List x;
  final Float64List y;

  Map<String, Object?> toJson() => {
    'x': [
      for (final v in x)
        if (v.isFinite) v else null,
    ],
    'y': [
      for (final v in y)
        if (v.isFinite) v else null,
    ],
  };

  factory fromJson(Map<String, Object?> json) => PlotSegmentData(
    x: Float64List.fromList(
      (json['x'] as List<Object?>)
          .map((e) => e == null ? double.nan : (e as num).toDouble())
          .toList(),
    ),
    y: Float64List.fromList(
      (json['y'] as List<Object?>)
          .map((e) => e == null ? double.nan : (e as num).toDouble())
          .toList(),
    ),
  );
}

/// Notable point marker on a plotted curve (root, local minimum, local maximum).
final class PlotMarkerData {
  const new({
    required this.x,
    required this.y,
    required this.label,
    required this.kind,
  });

  final double x;
  final double y;
  final String label;
  final String kind; // 'root' | 'min' | 'max'

  Map<String, Object?> toJson() => {
    'x': x.isFinite ? x : null,
    'y': y.isFinite ? y : null,
    'label': label,
    'kind': kind,
  };

  factory fromJson(Map<String, Object?> json) => PlotMarkerData(
    x: json['x'] == null ? double.nan : (json['x']! as num).toDouble(),
    y: json['y'] == null ? double.nan : (json['y']! as num).toDouble(),
    label: json['label']! as String,
    kind: json['kind']! as String,
  );
}

/// Sampled data for a single curve in a [PlotValue].
final class PlotCurveData {
  const new({
    required this.label,
    required this.exprText,
    required this.segments,
    this.imaginarySegments = const [],
    this.markers = const [],
  });

  final String label;
  final String exprText;
  final List<PlotSegmentData> segments;
  final List<PlotSegmentData> imaginarySegments;
  final List<PlotMarkerData> markers;

  bool get hasImaginary => imaginarySegments.isNotEmpty;

  Map<String, Object?> toJson() => {
    'label': label,
    'exprText': exprText,
    'segments': [for (final s in segments) s.toJson()],
    'imaginarySegments': [for (final s in imaginarySegments) s.toJson()],
    'markers': [for (final m in markers) m.toJson()],
  };

  factory fromJson(Map<String, Object?> json) => PlotCurveData(
    label: json['label']! as String,
    exprText: json['exprText']! as String,
    segments: (json['segments'] as List<Object?>? ?? const [])
        .map((e) => PlotSegmentData.fromJson(e! as Map<String, Object?>))
        .toList(),
    imaginarySegments: (json['imaginarySegments'] as List<Object?>? ?? const [])
        .map((e) => PlotSegmentData.fromJson(e! as Map<String, Object?>))
        .toList(),
    markers: (json['markers'] as List<Object?>? ?? const [])
        .map((e) => PlotMarkerData.fromJson(e! as Map<String, Object?>))
        .toList(),
  );
}

/// Pre-sampled 3D surface grid data for $z = f(x, y)$ over `[minX, maxX] × [minY, maxY]`.
final class Surface3dData {
  const new({
    required this.xVar,
    required this.yVar,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.minZ,
    required this.maxZ,
    required this.gridSize,
    required this.zValues,
  });

  final String xVar;
  final String yVar;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final double minZ;
  final double maxZ;
  final int gridSize;
  final Float64List zValues;

  Map<String, Object?> toJson() => {
    'xVar': xVar,
    'yVar': yVar,
    'minX': minX,
    'maxX': maxX,
    'minY': minY,
    'maxY': maxY,
    'minZ': minZ,
    'maxZ': maxZ,
    'gridSize': gridSize,
    'zValues': [
      for (final v in zValues)
        if (v.isFinite) v else null,
    ],
  };

  factory fromJson(Map<String, Object?> json) {
    final rawZ = json['zValues']! as List<Object?>;
    return Surface3dData(
      xVar: json['xVar'] as String? ?? 'x',
      yVar: json['yVar'] as String? ?? 'y',
      minX: (json['minX']! as num).toDouble(),
      maxX: (json['maxX']! as num).toDouble(),
      minY: (json['minY']! as num).toDouble(),
      maxY: (json['maxY']! as num).toDouble(),
      minZ: (json['minZ']! as num).toDouble(),
      maxZ: (json['maxZ']! as num).toDouble(),
      gridSize: (json['gridSize']! as num).toInt(),
      zValues: rawZ is Float64List
          ? rawZ
          : Float64List.fromList(
              rawZ
                  .map((e) => e == null ? double.nan : (e as num).toDouble())
                  .toList(),
            ),
    );
  }
}

/// Sealed hierarchy representing all calculator values in Scroll and RPN modes.
sealed class CalcValue {
  const new();

  /// Short string identifier for the value kind (`expr`, `vector`, `matrix`,
  /// `list`, `series`, `plot`, `info`, `error`).
  String get kind;

  /// Whether this value is symbolically exact (contains no floating-point
  /// [RealNumber] nodes).
  bool get isExact;

  /// Canonical text representation that round-trips through the calculator
  /// parser.
  String toCanonicalText();

  /// W3C MathML representation for high-quality mathematical rendering.
  String toMathMl({bool display = false, bool root = true});

  /// LaTeX representation for clipboard export and documentation.
  String toLatex();

  /// Formatted numeric approximation string (`≈ 1.414213562`) when this value
  /// is a closed exact scalar (no free variables and not already a plain
  /// integer or float), or `null` when no secondary approximation line applies.
  String? approxSummary({int digits = 10}) => null;

  @override
  String toString() => toCanonicalText();
}

/// Scalar symbolic expression or relational equation (`Expr`).
final class ExprValue extends CalcValue {
  const new(this.expr);

  final Expr expr;

  /// Whether this expression is a relational equation or inequality.
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
    if (expr is IntegerNumber) return null;
    if (expr is RelationalExpr) return null;
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
  String toCanonicalText() => vector.format();

  @override
  String toMathMl({bool display = false, bool root = true}) =>
      vector.toMathMl(display: display, root: root);

  @override
  String toLatex() => vector.toLatex();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! VectorValue || vector.length != other.vector.length) {
      return false;
    }
    for (var i = 0; i < vector.length; i++) {
      if (vector.getUnchecked(i) != other.vector.getUnchecked(i)) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    VectorValue,
    Object.hashAll([
      for (var i = 0; i < vector.length; i++) vector.getUnchecked(i),
    ]),
  );
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
  String toCanonicalText() => matrix.format();

  @override
  String toMathMl({bool display = false, bool root = true}) =>
      matrix.toMathMl(display: display, root: root);

  @override
  String toLatex() => matrix.toLatex();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MatrixValue ||
        matrix.rowCount != other.matrix.rowCount ||
        matrix.colCount != other.matrix.colCount) {
      return false;
    }
    for (var r = 0; r < matrix.rowCount; r++) {
      for (var c = 0; c < matrix.colCount; c++) {
        if (matrix.getUnchecked(r, c) != other.matrix.getUnchecked(r, c)) {
          return false;
        }
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    MatrixValue,
    matrix.rowCount,
    matrix.colCount,
    Object.hashAll([
      for (var r = 0; r < matrix.rowCount; r++)
        for (var c = 0; c < matrix.colCount; c++) matrix.getUnchecked(r, c),
    ]),
  );
}

/// Ordered list of calculator values (e.g., solution sets or eigenpairs).
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
    if (elements.isEmpty) {
      const empty = '<mrow><mo>[</mo><mo>]</mo></mrow>';
      if (!root) return empty;
      final attr = display ? ' display="block"' : '';
      return '<math$attr>$empty</math>';
    }
    final inner =
        '<mrow><mo>[</mo>${elements.map((e) => e.toMathMl(root: false)).join('<mo>,</mo><mspace width="0.3em"/>')}<mo>]</mo></mrow>';
    if (!root) return inner;
    final attr = display ? ' display="block"' : '';
    return '<math$attr>$inner</math>';
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

/// Truncated power/Laurent series value with `O(...)` order term.
final class SeriesValue extends CalcValue {
  const new(this.series);

  final PowerSeries series;

  Expr get exprWithOrder => series.toExpr(includeOrder: true);
  Expr get polynomialExpr => series.toExpr(includeOrder: false);

  @override
  String get kind => 'series';

  @override
  bool get isExact => !_containsRealNumber(exprWithOrder);

  @override
  String toCanonicalText() => exprWithOrder.toString();

  @override
  String toMathMl({bool display = false, bool root = true}) =>
      exprWithOrder.toMathMl(display: display, root: root);

  @override
  String toLatex() => exprWithOrder.toLatex();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeriesValue && exprWithOrder == other.exprWithOrder);

  @override
  int get hashCode => Object.hash(SeriesValue, exprWithOrder);
}

/// Interactive plot value representing one or more expressions over a domain.
final class PlotValue extends CalcValue {
  const new({
    required this.expressions,
    required this.variable,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    this.curves = const [],
    this.parameters = const [],
    this.isParametric = false,
    this.isOde = false,
    this.isDegrees = false,
    this.minT,
    this.maxT,
    this.surface3d,
  });

  final List<Expr> expressions;
  final String variable;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final List<PlotCurveData> curves;
  final List<String> parameters;
  final bool isParametric;
  final bool isOde;
  final bool isDegrees;
  final double? minT;
  final double? maxT;
  final Surface3dData? surface3d;

  /// Whether this plot is a 3D surface plot $z = f(x, y)$.
  bool get is3d => surface3d != null;

  @override
  String get kind => 'plot';

  @override
  bool get isExact => false;

  @override
  String toCanonicalText() {
    final s3d = surface3d;
    if (s3d != null && expressions.isNotEmpty) {
      return 'plot3d(${expressions.first}, ${s3d.xVar}, ${fmtBound(s3d.minX)}, ${fmtBound(s3d.maxX)}, ${s3d.yVar}, ${fmtBound(s3d.minY)}, ${fmtBound(s3d.maxY)})';
    }
    if (isParametric && expressions.length >= 2) {
      final t0 = minT ?? minX;
      final t1 = maxT ?? maxX;
      return 'plot([${expressions[0]}, ${expressions[1]}], $variable, ${fmtBound(t0)}, ${fmtBound(t1)})';
    }
    if (expressions.length == 1) {
      return 'plot(${expressions.first}, $variable, ${fmtBound(minX)}, ${fmtBound(maxX)})';
    }
    return 'plot([${expressions.join(', ')}], $variable, ${fmtBound(minX)}, ${fmtBound(maxX)})';
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
          variable == other.variable &&
          minX == other.minX &&
          maxX == other.maxX &&
          isParametric == other.isParametric &&
          is3d == other.is3d &&
          const ListEquality<Expr>().equals(expressions, other.expressions));

  @override
  int get hashCode => Object.hash(
    PlotValue,
    variable,
    minX,
    maxX,
    isParametric,
    is3d,
    Object.hashAll(expressions),
  );
}

/// Informational text message value (e.g. from `help`, `vars`, `clear`).
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

/// Structured error value with optional character offset and quick-fix suggestion.
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
  String toCanonicalText() => 'Error: $message';

  @override
  String toMathMl({bool display = false, bool root = true}) {
    final escaped = _escapeXml(message);
    if (!root) return '<mtext>$escaped</mtext>';
    final attr = display ? ' display="block"' : '';
    return '<math$attr><mtext>$escaped</mtext></math>';
  }

  @override
  String toLatex() => '\\text{Error: ${_escapeLatexText(message)}}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ErrorValue &&
          message == other.message &&
          offset == other.offset &&
          suggestion == other.suggestion);

  @override
  int get hashCode => Object.hash(ErrorValue, message, offset, suggestion);
}

bool _containsRealNumber(Expr expr) => expr.anyNode((n) => n is RealNumber);

/// Formats a floating-point [value] to [digits] significant digits without
/// trailing fractional zeros.
String formatRealDigits(double value, int digits) {
  if (value.isNaN) return 'undefined';
  if (value.isInfinite) return value.isNegative ? '-infinity' : 'infinity';
  if (value == 0.0) return '0';
  final d = digits.clamp(1, 15);
  final absVal = value.abs();
  if (absVal >= 1e-4 && absVal < math.pow(10, d)) {
    final intDigits = absVal < 1
        ? 0
        : (math.log(absVal) / math.ln10).floor() + 1;
    final fracDigits = math.max(0, d - intDigits);
    var s = value.toStringAsFixed(fracDigits);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return s == '-0' ? '0' : s;
  }
  final s = value.toStringAsPrecision(d);
  if (s.contains('e')) {
    final parts = s.split('e');
    final mantissa = parts[0]
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return '${mantissa}e${parts[1]}';
  }
  return s;
}

String _formatComplexDigits(double re, double im, int digits) {
  final reZero = re.abs() < 1e-15;
  final imZero = im.abs() < 1e-15;
  if (imZero) return formatRealDigits(re, digits);
  final imAbsStr = (im.abs() - 1.0).abs() < 1e-15
      ? 'i'
      : '${formatRealDigits(im.abs(), digits)} * i';
  if (reZero) return im < 0 ? '-$imAbsStr' : imAbsStr;
  final reStr = formatRealDigits(re, digits);
  final sign = im < 0 ? ' - ' : ' + ';
  return '$reStr$sign$imAbsStr';
}

String _escapeXml(String input) => input
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

String _escapeLatexText(String input) => input
    .replaceAll(r'\', r'\textbackslash{}')
    .replaceAll('{', r'\{')
    .replaceAll('}', r'\}')
    .replaceAll(r'$', r'\$')
    .replaceAll('&', r'\&')
    .replaceAll('#', r'\#')
    .replaceAll('^', r'\textasciicircum{}')
    .replaceAll('_', r'\_')
    .replaceAll('~', r'\textasciitilde{}')
    .replaceAll('%', r'\%');
