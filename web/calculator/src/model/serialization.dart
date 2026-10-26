import 'package:data/symbolic.dart';

import 'value.dart';

/// Serializes [CalcValue] instances to and from JSON envelopes and canonical
/// text strings.
abstract final class CalcSerialization {
  /// Encodes a [CalcValue] into a JSON-compatible map containing both
  /// structured fields and pre-rendered strings for the main thread.
  static Map<String, Object?> toJson(CalcValue value, {int digits = 10}) {
    final base = <String, Object?>{
      'kind': value.kind,
      'text': value.toCanonicalText(),
      'mathml': value.toMathMl(),
      'latex': value.toLatex(),
      'exact': value.isExact,
      'approxText': value.approxSummary(digits: digits),
    };
    return switch (value) {
      ExprValue(:final expr) => {...base, 'expr': expr.toString()},
      VectorValue(:final vector) => {...base, 'vector': vector.format()},
      MatrixValue(:final matrix) => {...base, 'matrix': matrix.format()},
      ListValue(:final elements) => {
        ...base,
        'elements': [for (final e in elements) toJson(e, digits: digits)],
      },
      SeriesValue(:final series) => {
        ...base,
        'variable': series.variable,
        'point': series.point.toString(),
        'order': series.order,
        'coefficients': {
          for (final entry in series.coefficients.entries)
            '${entry.key}': entry.value.toString(),
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
        :final isOde,
        :final isDegrees,
        :final minT,
        :final maxT,
        :final surface3d,
      ) =>
        {
          ...base,
          'expressions': [for (final e in expressions) e.toString()],
          'variable': variable,
          'minX': minX,
          'maxX': maxX,
          'minY': minY,
          'maxY': maxY,
          'curves': [for (final c in curves) c.toJson()],
          if (parameters.isNotEmpty) 'parameters': parameters,
          if (isParametric) 'isParametric': true,
          if (isOde) 'isOde': true,
          if (isDegrees) 'isDegrees': true,
          'minT': ?minT,
          'maxT': ?maxT,
          if (surface3d != null) 'surface3d': surface3d.toJson(),
        },
      InfoValue(:final message, :final title) => {
        ...base,
        'message': message,
        'title': ?title,
      },
      ErrorValue(
        :final message,
        :final offset,
        :final suggestion,
        :final source,
      ) =>
        {
          ...base,
          'message': message,
          'offset': ?offset,
          'suggestion': ?suggestion,
          'source': ?source,
        },
    };
  }

  /// Decodes a [CalcValue] from a JSON map produced by [toJson].
  static CalcValue fromJson(Map<String, Object?> json) {
    final kind = json['kind'] as String? ?? 'expr';
    switch (kind) {
      case 'expr':
      case 'equation':
        final exprStr = (json['expr'] ?? json['text'])! as String;
        return ExprValue(Expr.parse(exprStr));
      case 'vector':
        final vecStr = (json['vector'] ?? json['text'])! as String;
        return VectorValue(ExprSyntax.standard.parseVector(vecStr));
      case 'matrix':
        final matStr = (json['matrix'] ?? json['text'])! as String;
        return MatrixValue(ExprSyntax.standard.parseMatrix(matStr));
      case 'list':
        final elems = (json['elements'] as List<Object?>? ?? const [])
            .map((e) => fromJson(e! as Map<String, Object?>))
            .toList();
        return ListValue(elems);
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
        final exprs = (json['expressions'] as List<Object?>? ?? const [])
            .map((e) => Expr.parse(e! as String))
            .toList();
        final curves = (json['curves'] as List<Object?>? ?? const [])
            .map((c) => PlotCurveData.fromJson(c! as Map<String, Object?>))
            .toList();
        final params = (json['parameters'] as List<Object?>? ?? const [])
            .cast<String>()
            .toList();
        final rawS3d = json['surface3d'] as Map<String, Object?>?;
        return PlotValue(
          expressions: exprs,
          variable: json['variable'] as String? ?? 'x',
          minX: (json['minX'] as num?)?.toDouble() ?? -5.0,
          maxX: (json['maxX'] as num?)?.toDouble() ?? 5.0,
          minY: (json['minY'] as num?)?.toDouble() ?? -5.0,
          maxY: (json['maxY'] as num?)?.toDouble() ?? 5.0,
          curves: curves,
          parameters: params,
          isParametric: json['isParametric'] as bool? ?? false,
          isOde: json['isOde'] as bool? ?? false,
          isDegrees: json['isDegrees'] as bool? ?? false,
          minT: (json['minT'] as num?)?.toDouble(),
          maxT: (json['maxT'] as num?)?.toDouble(),
          surface3d: rawS3d != null ? Surface3dData.fromJson(rawS3d) : null,
        );
      case 'info':
        return InfoValue(
          (json['message'] ?? json['text'] ?? '') as String,
          title: json['title'] as String?,
        );
      case 'error':
        return ErrorValue(
          (json['message'] ?? json['text'] ?? 'Error') as String,
          offset: (json['offset'] as num?)?.toInt(),
          suggestion: json['suggestion'] as String?,
          source: json['source'] as String?,
        );
      default:
        final text = json['text'] as String? ?? '0';
        return parseCanonical(text);
    }
  }

  /// Parses a canonical text representation back into a [CalcValue].
  static CalcValue parseCanonical(String text) {
    final trimmed = text.trim();
    if (trimmed.startsWith('Error:')) {
      return ErrorValue(trimmed.substring('Error:'.length).trim());
    }
    if (trimmed.startsWith('[[')) {
      final mat = ExprSyntax.standard.tryParseMatrix(trimmed);
      if (mat != null) return MatrixValue(mat);
    }
    if (trimmed.startsWith('[')) {
      final vec = ExprSyntax.standard.tryParseVector(trimmed);
      if (vec != null) return VectorValue(vec);
    }
    final expr = Expr.tryParse(trimmed);
    if (expr != null) {
      if (expr.anyNode((n) => n is OrderTerm)) {
        // Reconstruct PowerSeries if possible, otherwise keep ExprValue
        return ExprValue(expr);
      }
      return ExprValue(expr);
    }
    return InfoValue(trimmed);
  }
}
