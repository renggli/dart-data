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

/// Formats a finite scalar concisely for HUD and legend readouts.
String formatGraphNumber(double value) {
  if (!value.isFinite) return value.isNaN ? 'NaN' : value.toString();
  if (value == 0.0) return '0';
  final abs = value.abs();
  if (abs >= 1e5 || (abs > 0 && abs < 1e-4)) {
    return value.toStringAsExponential(3);
  }
  final fixed = value.toStringAsFixed(4);
  return fixed.contains('.')
      ? fixed.replaceFirst(RegExp(r'\.?0+$'), '')
      : fixed;
}
