import 'package:more/printer.dart';

import 'style.dart';

/// Interactive pointer probe coordinates in data space.
sealed class GraphProbe {
  /// Base constructor for graph probes.
  const new();
}

/// 2D data-space probe at `(x, y)` with optional secondary `y2`.
final class Probe2D extends GraphProbe {
  /// Creates a 2D probe.
  const new({required this.x, required this.y, this.y2});

  /// Horizontal coordinate in data space.
  final double x;

  /// Primary vertical coordinate in data space.
  final double y;

  /// Optional secondary vertical coordinate in data space.
  final double? y2;
}

/// 3D data-space probe at `(x, y, z)`.
final class Probe3D extends GraphProbe {
  /// Creates a 3D probe.
  const new({required this.x, required this.y, required this.z});

  /// X coordinate in data space.
  final double x;

  /// Y coordinate in data space.
  final double y;

  /// Z coordinate in data space.
  final double z;
}

/// Formatted readout displayed inside a legend item when hovering.
class LegendReadout {
  /// Creates a legend readout.
  const new({this.valueText, this.detailText});

  /// Primary numeric value text.
  final String? valueText;

  /// Optional secondary coordinate or vector detail.
  final String? detailText;
}

/// Base contract for any 2D or 3D plottable dataset.
abstract class GraphDataset {
  /// Creates a graph dataset.
  const new({required this.id, required this.label, this.visible = true});

  /// Unique identifier within a scene.
  final String id;

  /// Human-readable legend label.
  final String label;

  /// Whether this dataset is currently visible.
  final bool visible;

  /// Visual legend swatch for this dataset.
  LegendSwatch get swatch;

  /// Computes a formatted readout at [probe], or `null` when unavailable.
  LegendReadout? readout(GraphProbe? probe);
}

final _graphFixedPrinters = <int, FixedNumberPrinter<double>>{
  for (var p = 0; p <= 6; p++)
    p: FixedNumberPrinter<double>(precision: p, infinity: '∞', nan: 'NaN'),
};
final _graphScientificPrinter = ScientificNumberPrinter<double>(
  precision: 3,
  infinity: '∞',
  nan: 'NaN',
);

/// Formats a scalar using `package:more` printers for HUD, tick, and legend readouts.
String formatGraphNumber(double value, {int? precision}) {
  if (value.isNaN) return 'NaN';
  if (value.isInfinite) return value.isNegative ? '-∞' : '∞';
  final normalized = value.abs() < 1e-12 ? 0.0 : value;
  if (precision != null) {
    final p = precision.clamp(0, 6);
    return _graphFixedPrinters[p]!.print(normalized);
  }
  final abs = normalized.abs();
  if (abs >= 1e5 || (abs > 0 && abs < 1e-4)) {
    return _graphScientificPrinter.print(normalized);
  }
  return _graphFixedPrinters[4]!.print(normalized);
}
