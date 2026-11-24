import 'dart:math' as math;
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:data/linear.dart';
import 'package:data/symbolic.dart';

import '../../../shared/graph/model/dataset_2d.dart';
import '../../../shared/graph/model/dataset_3d.dart';

/// Sampled polyline segment for a 2D curve without vertical asymptotes.
final class PlotSegmentData {
  const new({required this.x, required this.y, this.t});

  factory fromJson(Map<String, Object?> json) {
    final rawT = json['t'] as List<Object?>?;
    return PlotSegmentData(
      x: _decodeFloatList(json['x']! as List<Object?>),
      y: _decodeFloatList(json['y']! as List<Object?>),
      t: rawT == null ? null : _decodeFloatList(rawT),
    );
  }

  final Float64List x;
  final Float64List y;
  final Float64List? t;

  Map<String, Object?> toJson() => {
    'x': _encodeFloatList(x),
    'y': _encodeFloatList(y),
    if (t != null) 't': _encodeFloatList(t!),
  };
}

/// Notable point marker on a plotted curve (`root`, `min`, or `max`).
final class PlotMarkerData {
  const new({
    required this.x,
    required this.y,
    required this.label,
    required this.kind,
  });

  factory fromJson(Map<String, Object?> json) => PlotMarkerData(
    x: json['x'] == null ? double.nan : (json['x']! as num).toDouble(),
    y: json['y'] == null ? double.nan : (json['y']! as num).toDouble(),
    label: json['label']! as String,
    kind: json['kind']! as String,
  );

  final double x;
  final double y;
  final String label;
  final String kind;

  Map<String, Object?> toJson() => {
    'x': x.isFinite ? x : null,
    'y': y.isFinite ? y : null,
    'label': label,
    'kind': kind,
  };
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
}

/// Pre-sampled 3D surface grid data for `z = f(x, y)`.
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
    this.phaseValues,
  });

  factory fromJson(Map<String, Object?> json) {
    final rawZ = json['zValues']! as List<Object?>;
    final rawPhase = json['phaseValues'] as List<Object?>?;
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
      zValues: _decodeFloatList(rawZ),
      phaseValues: rawPhase == null ? null : _decodeFloatList(rawPhase),
    );
  }

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
  final Float64List? phaseValues;

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
    'zValues': _encodeFloatList(zValues),
    if (phaseValues != null) 'phaseValues': _encodeFloatList(phaseValues!),
  };
}

/// Pre-sampled 3D parametric space curve `(x(t), y(t), z(t))`.
final class Parametric3dData {
  const new({
    required this.tVar,
    required this.minT,
    required this.maxT,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.minZ,
    required this.maxZ,
    required this.tValues,
    required this.xValues,
    required this.yValues,
    required this.zValues,
  });

  factory fromJson(Map<String, Object?> json) => Parametric3dData(
    tVar: json['tVar'] as String? ?? 't',
    minT: (json['minT']! as num).toDouble(),
    maxT: (json['maxT']! as num).toDouble(),
    minX: (json['minX']! as num).toDouble(),
    maxX: (json['maxX']! as num).toDouble(),
    minY: (json['minY']! as num).toDouble(),
    maxY: (json['maxY']! as num).toDouble(),
    minZ: (json['minZ']! as num).toDouble(),
    maxZ: (json['maxZ']! as num).toDouble(),
    tValues: _decodeFloatList(json['tValues']! as List<Object?>),
    xValues: _decodeFloatList(json['xValues']! as List<Object?>),
    yValues: _decodeFloatList(json['yValues']! as List<Object?>),
    zValues: _decodeFloatList(json['zValues']! as List<Object?>),
  );

  final String tVar;
  final double minT;
  final double maxT;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final double minZ;
  final double maxZ;
  final Float64List tValues;
  final Float64List xValues;
  final Float64List yValues;
  final Float64List zValues;

  Map<String, Object?> toJson() => {
    'tVar': tVar,
    'minT': minT,
    'maxT': maxT,
    'minX': minX,
    'maxX': maxX,
    'minY': minY,
    'maxY': maxY,
    'minZ': minZ,
    'maxZ': maxZ,
    'tValues': _encodeFloatList(tValues),
    'xValues': _encodeFloatList(xValues),
    'yValues': _encodeFloatList(yValues),
    'zValues': _encodeFloatList(zValues),
  };
}

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

/// Interactive 2D, 3D, or complex domain-coloring plot value.
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
    this.isComplex = false,
    this.isOde = false,
    this.minT,
    this.maxT,
    this.surface3d,
    this.parametric3d,
    this.title,
    this.showGrid = true,
    this.showMarkers = true,
    this.showContours = true,
    this.scene2d,
    this.scene3d,
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
  final bool isComplex;
  final bool isOde;
  final double? minT;
  final double? maxT;
  final Surface3dData? surface3d;
  final Parametric3dData? parametric3d;
  final String? title;
  final bool showGrid;
  final bool showMarkers;
  final bool showContours;
  final Scene2D? scene2d;
  final Scene3D? scene3d;

  bool get is3d => scene3d != null || surface3d != null || parametric3d != null;

  @override
  String get kind => 'plot';

  @override
  bool get isExact => false;

  @override
  String toCanonicalText() {
    final p3d = parametric3d;
    if (p3d != null && expressions.length >= 3) {
      return 'parametric([${expressions[0]}, ${expressions[1]}, ${expressions[2]}], ${p3d.tVar}, from: ${fmtBound(p3d.minT)}, to: ${fmtBound(p3d.maxT)})';
    }
    final s3d = surface3d;
    if (s3d != null && expressions.isNotEmpty) {
      if (isComplex) {
        return 'plotcomplex3d(${expressions.first}, $variable, reFrom: ${fmtBound(s3d.minX)}, reTo: ${fmtBound(s3d.maxX)}, imFrom: ${fmtBound(s3d.minY)}, imTo: ${fmtBound(s3d.maxY)})';
      }
      return 'plot3d(${expressions.first}, ${s3d.xVar}, ${s3d.yVar}, xFrom: ${fmtBound(s3d.minX)}, xTo: ${fmtBound(s3d.maxX)}, yFrom: ${fmtBound(s3d.minY)}, yTo: ${fmtBound(s3d.maxY)})';
    }
    if (isComplex && expressions.isNotEmpty) {
      return 'plotcomplex(${expressions.first}, $variable, reFrom: ${fmtBound(minX)}, reTo: ${fmtBound(maxX)}, imFrom: ${fmtBound(minY)}, imTo: ${fmtBound(maxY)})';
    }
    if (isParametric && expressions.length >= 2) {
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
          variable == other.variable &&
          minX == other.minX &&
          maxX == other.maxX &&
          isParametric == other.isParametric &&
          isComplex == other.isComplex &&
          is3d == other.is3d &&
          title == other.title &&
          const ListEquality<Expr>().equals(expressions, other.expressions));

  @override
  int get hashCode => Object.hash(
    PlotValue,
    variable,
    minX,
    maxX,
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

List<double?> _encodeFloatList(Float64List list) => [
  for (final v in list)
    if (v.isFinite) v else null,
];

Float64List _decodeFloatList(List<Object?> raw) => raw is Float64List
    ? raw
    : Float64List.fromList([
        for (final e in raw)
          if (e == null) double.nan else (e as num).toDouble(),
      ]);

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
