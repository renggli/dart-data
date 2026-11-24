import 'package:data/linear.dart';
import 'package:data/symbolic.dart';

import 'value.dart';

/// Serializes a [CalcValue] to a JSON-compatible map for worker messaging and
/// snapshot persistence.
Map<String, Object?> valueToJson(CalcValue value) => switch (value) {
  ExprValue(:final expr) => {'type': 'expr', 'expr': expr.toString()},
  StringValue(:final value) => {'type': 'string', 'value': value},
  BoolValue(:final value) => {'type': 'bool', 'value': value},
  VectorValue(:final vector) => {
    'type': 'vector',
    'elements': [
      for (var i = 0; i < vector.length; i++) vector.getUnchecked(i).toString(),
    ],
  },
  MatrixValue(:final matrix) => {
    'type': 'matrix',
    'rows': [
      for (var r = 0; r < matrix.rowCount; r++)
        [
          for (var c = 0; c < matrix.colCount; c++)
            matrix.getUnchecked(r, c).toString(),
        ],
    ],
  },
  ListValue(:final elements) => {
    'type': 'list',
    'elements': [for (final e in elements) valueToJson(e)],
  },
  SeriesValue(:final series) => {
    'type': 'series',
    'variable': series.variable,
    'point': series.point.toString(),
    'order': series.order,
    'coefficients': {
      for (final entry in series.coefficients.entries)
        entry.key.toString(): entry.value.toString(),
    },
  },
  PlotValue(
    :final expressions,
    :final variable,
    :final minX,
    :final maxX,
    :final minY,
    :final maxY,
    :final curves,
    :final parameters,
    :final isParametric,
    :final isComplex,
    :final isOde,
    :final minT,
    :final maxT,
    :final surface3d,
    :final parametric3d,
    :final title,
    :final showGrid,
    :final showMarkers,
    :final showContours,
  ) =>
    {
      'type': 'plot',
      'expressions': [for (final e in expressions) e.toString()],
      'variable': variable,
      'minX': minX,
      'maxX': maxX,
      'minY': minY,
      'maxY': maxY,
      'curves': [for (final c in curves) c.toJson()],
      'parameters': parameters,
      'isParametric': isParametric,
      'isComplex': isComplex,
      'isOde': isOde,
      'minT': ?minT,
      'maxT': ?maxT,
      if (surface3d != null) 'surface3d': surface3d.toJson(),
      if (parametric3d != null) 'parametric3d': parametric3d.toJson(),
      'title': ?title,
      'showGrid': showGrid,
      'showMarkers': showMarkers,
      'showContours': showContours,
    },
  InfoValue(:final message, :final title) => {
    'type': 'info',
    'message': message,
    'title': ?title,
  },
  ErrorValue(:final message, :final offset, :final suggestion, :final source) =>
    {
      'type': 'error',
      'message': message,
      'offset': ?offset,
      'suggestion': ?suggestion,
      'source': ?source,
    },
};

/// Deserializes a [CalcValue] from a JSON map produced by [valueToJson].
CalcValue valueFromJson(Map<String, Object?> json) {
  final type = json['type']! as String;
  switch (type) {
    case 'expr':
      return ExprValue(Expr.parse(json['expr']! as String));
    case 'string':
      return StringValue(json['value']! as String);
    case 'bool':
      return BoolValue(json['value']! as bool);
    case 'vector':
      final elements = [
        for (final s in json['elements']! as List<Object?>)
          Expr.parse(s! as String),
      ];
      return VectorValue(Vector<Expr>.fromList(elements, type: exprDataType));
    case 'matrix':
      final rows = [
        for (final row in json['rows']! as List<Object?>)
          [for (final s in row! as List<Object?>) Expr.parse(s! as String)],
      ];
      return MatrixValue(Matrix<Expr>.fromRows(rows, type: exprDataType));
    case 'list':
      return ListValue([
        for (final e in json['elements']! as List<Object?>)
          valueFromJson(e! as Map<String, Object?>),
      ]);
    case 'series':
      final variable = json['variable']! as String;
      final point = Expr.parse(json['point']! as String);
      final order = (json['order']! as num).toInt();
      final rawCoeffs = json['coefficients']! as Map<String, Object?>;
      final coeffs = <int, Expr>{
        for (final entry in rawCoeffs.entries)
          int.parse(entry.key): Expr.parse(entry.value! as String),
      };
      return SeriesValue(PowerSeries(variable, point, coeffs, order));
    case 'plot':
      final rawSurface = json['surface3d'] as Map<String, Object?>?;
      final rawParam3d = json['parametric3d'] as Map<String, Object?>?;
      return PlotValue(
        expressions: [
          for (final s in json['expressions']! as List<Object?>)
            Expr.parse(s! as String),
        ],
        variable: json['variable']! as String,
        minX: (json['minX']! as num).toDouble(),
        maxX: (json['maxX']! as num).toDouble(),
        minY: (json['minY']! as num).toDouble(),
        maxY: (json['maxY']! as num).toDouble(),
        curves: [
          for (final c in json['curves'] as List<Object?>? ?? const [])
            PlotCurveData.fromJson(c! as Map<String, Object?>),
        ],
        parameters: [
          for (final p in json['parameters'] as List<Object?>? ?? const [])
            p! as String,
        ],
        isParametric: json['isParametric'] as bool? ?? false,
        isComplex: json['isComplex'] as bool? ?? false,
        isOde: json['isOde'] as bool? ?? false,
        minT: (json['minT'] as num?)?.toDouble(),
        maxT: (json['maxT'] as num?)?.toDouble(),
        surface3d: rawSurface == null
            ? null
            : Surface3dData.fromJson(rawSurface),
        parametric3d: rawParam3d == null
            ? null
            : Parametric3dData.fromJson(rawParam3d),
        title: json['title'] as String?,
        showGrid: json['showGrid'] as bool? ?? true,
        showMarkers: json['showMarkers'] as bool? ?? true,
        showContours: json['showContours'] as bool? ?? true,
      );
    case 'info':
      return InfoValue(
        json['message']! as String,
        title: json['title'] as String?,
      );
    case 'error':
      return ErrorValue(
        json['message']! as String,
        offset: (json['offset'] as num?)?.toInt(),
        suggestion: json['suggestion'] as String?,
        source: json['source'] as String?,
      );
    default:
      throw FormatException('Unknown CalcValue type: $type');
  }
}
