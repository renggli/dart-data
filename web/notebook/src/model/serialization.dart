import 'package:data/linear.dart';
import 'package:data/symbolic.dart';

import 'value.dart';

/// Serializes a [CalcValue] to a JSON-compatible map for worker messaging and
/// snapshot persistence.
Map<String, Object?> valueToJson(CalcValue value) => switch (value) {
  ExprValue(:final expr) => {'type': 'expr', 'expr': _exprToJson(expr)},
  StringValue(:final value) => {'type': 'string', 'value': value},
  BoolValue(:final value) => {'type': 'bool', 'value': value},
  VectorValue(:final vector) => {
    'type': 'vector',
    'elements': [
      for (var i = 0; i < vector.length; i++)
        _exprToJson(vector.getUnchecked(i)),
    ],
  },
  MatrixValue(:final matrix) => {
    'type': 'matrix',
    'rows': [
      for (var r = 0; r < matrix.rowCount; r++)
        [
          for (var c = 0; c < matrix.colCount; c++)
            _exprToJson(matrix.getUnchecked(r, c)),
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
  RangeValue(:final start, :final end) => {
    'type': 'range',
    'start': start.toString(),
    'end': end.toString(),
  },
  PlotValue(
    :final expressions,
    :final variable,
    :final minX,
    :final maxX,
    :final minY,
    :final maxY,
    :final isParametric,
    :final isComplex,
    :final isOde,
    :final minT,
    :final maxT,
    :final odeY0,
    :final odeMethod,
    :final title,
    :final showGrid,
    :final showMarkers,
    :final showContours,
    :final plotKind,
    :final yVariable,
    :final gridSize,
  ) =>
    {
      'type': 'plot',
      'expressions': [for (final e in expressions) e.toString()],
      'variable': variable,
      'minX': minX,
      'maxX': maxX,
      'minY': minY,
      'maxY': maxY,
      'isParametric': isParametric,
      'isComplex': isComplex,
      'isOde': isOde,
      'minT': ?minT,
      'maxT': ?maxT,
      'odeY0': ?odeY0,
      'odeMethod': ?odeMethod,
      'title': ?title,
      'showGrid': showGrid,
      'showMarkers': showMarkers,
      'showContours': showContours,
      'plotKind': plotKind.name,
      'yVariable': ?yVariable,
      'gridSize': gridSize,
    },
  InfoValue(:final message, :final title) => {
    'type': 'info',
    'message': message,
    'title': ?title,
  },
  SliderValue(
    :final key,
    :final symbol,
    :final label,
    :final min,
    :final max,
    :final step,
    :final defaultValue,
    :final value,
  ) =>
    {
      'type': 'slider',
      'key': key,
      'symbol': ?symbol,
      'label': ?label,
      'min': min,
      'max': max,
      'step': step,
      'defaultValue': defaultValue,
      'value': value,
    },
  InputValue(
    :final key,
    :final symbol,
    :final label,
    :final defaultSource,
    :final source,
    :final evaluated,
  ) =>
    {
      'type': 'input',
      'key': key,
      'symbol': ?symbol,
      'label': ?label,
      'defaultSource': defaultSource,
      'source': source,
      'evaluated': valueToJson(evaluated),
    },
  ControlGroupValue(:final controls) => {
    'type': 'controls',
    'controls': [for (final c in controls) valueToJson(c)],
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
      return ExprValue(_exprFromJson(json['expr']));
    case 'string':
      return StringValue(json['value']! as String);
    case 'bool':
      return BoolValue(json['value']! as bool);
    case 'vector':
      final elements = [
        for (final s in json['elements']! as List<Object?>) _exprFromJson(s),
      ];
      return VectorValue(Vector<Expr>.fromList(elements, type: exprDataType));
    case 'matrix':
      final rows = [
        for (final row in json['rows']! as List<Object?>)
          [for (final s in row! as List<Object?>) _exprFromJson(s)],
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
    case 'range':
      return RangeValue(
        Expr.parse(json['start']! as String),
        Expr.parse(json['end']! as String),
      );
    case 'plot':
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
        isParametric: json['isParametric'] as bool? ?? false,
        isComplex: json['isComplex'] as bool? ?? false,
        isOde: json['isOde'] as bool? ?? false,
        minT: (json['minT'] as num?)?.toDouble(),
        maxT: (json['maxT'] as num?)?.toDouble(),
        odeY0: (json['odeY0'] as num?)?.toDouble(),
        odeMethod: json['odeMethod'] as String?,
        title: json['title'] as String?,
        showGrid: json['showGrid'] as bool? ?? true,
        showMarkers: json['showMarkers'] as bool? ?? true,
        showContours: json['showContours'] as bool? ?? true,
        plotKind: PlotKind.values.firstWhere(
          (k) => k.name == json['plotKind'],
          orElse: () => PlotKind.function2d,
        ),
        yVariable: json['yVariable'] as String?,
        gridSize: (json['gridSize'] as num?)?.toInt() ?? 48,
      );
    case 'info':
      return InfoValue(
        json['message']! as String,
        title: json['title'] as String?,
      );
    case 'slider':
      return SliderValue(
        key: json['key'] as String? ?? '',
        symbol: json['symbol'] as String?,
        label: json['label'] as String?,
        min: (json['min']! as num).toDouble(),
        max: (json['max']! as num).toDouble(),
        step: (json['step']! as num).toDouble(),
        defaultValue: (json['defaultValue']! as num).toDouble(),
        value: (json['value']! as num).toDouble(),
      );
    case 'input':
      return InputValue(
        key: json['key'] as String? ?? '',
        symbol: json['symbol'] as String?,
        label: json['label'] as String?,
        defaultSource: json['defaultSource']! as String,
        source: json['source']! as String,
        evaluated: valueFromJson(json['evaluated']! as Map<String, Object?>),
      );
    case 'controls':
      return ControlGroupValue([
        for (final c in json['controls']! as List<Object?>)
          valueFromJson(c! as Map<String, Object?>) as ControlValue,
      ]);
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

bool _needsStructuralEncoding(Expr expr) => switch (expr) {
  Mul(:final factors) =>
    factors.whereType<Number>().length > 1 ||
        factors.any(_needsStructuralEncoding),
  Pow(:final base, :final exponent) =>
    (base is Number && exponent is Number) ||
        _needsStructuralEncoding(base) ||
        _needsStructuralEncoding(exponent),
  _ => false,
};

Object _exprToJson(Expr expr) {
  if (!_needsStructuralEncoding(expr)) return expr.toString();
  return switch (expr) {
    Mul(:final factors) => {
      'k': 'mul',
      'f': [for (final f in factors) _exprToJson(f)],
    },
    Pow(:final base, :final exponent) => {
      'k': 'pow',
      'b': _exprToJson(base),
      'e': _exprToJson(exponent),
    },
    _ => expr.toString(),
  };
}

Expr _exprFromJson(Object? raw) {
  if (raw is String) return Expr.parse(raw);
  if (raw is Map) {
    final map = raw.cast<String, Object?>();
    switch (map['k']) {
      case 'mul':
        final rawFactors = map['f']! as List<Object?>;
        return Mul.raw([for (final f in rawFactors) _exprFromJson(f)]);
      case 'pow':
        return Pow.raw(_exprFromJson(map['b']), _exprFromJson(map['e']));
    }
  }
  throw FormatException('Invalid serialized expression: $raw');
}
