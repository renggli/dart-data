import 'dart:math' as math;

/// Default high-contrast color palette for graph curves.
const List<String> defaultGraphPalette = <String>[
  '#60a5fa',
  '#f472b6',
  '#34d399',
  '#fbbf24',
  '#a78bfa',
  '#fb7185',
  '#22d3ee',
  '#fb923c',
];

/// Continuous perceptual or thematic color maps for scalar and phase fields.
enum Colormap {
  viridis,
  plasma,
  diverging,
  oklchPhase,
  monochrome;

  /// Samples an RGBA byte tuple at normalized parameter [t] in `[0, 1]`.
  ({int r, int g, int b, int a}) sampleRgba(double t) {
    final clamped = t.isNaN ? 0.0 : t.clamp(0.0, 1.0);
    return switch (this) {
      Colormap.viridis => _sampleStops(clamped, _viridisStops),
      Colormap.plasma => _sampleStops(clamped, _plasmaStops),
      Colormap.diverging => _sampleStops(clamped, _divergingStops),
      Colormap.monochrome => _sampleStops(clamped, _monochromeStops),
      Colormap.oklchPhase => _samplePhase(clamped),
    };
  }

  /// Samples a CSS `rgb(r, g, b)` color string at normalized [t] in `[0, 1]`.
  String sampleCss(double t) {
    final c = sampleRgba(t);
    return 'rgb(${c.r}, ${c.g}, ${c.b})';
  }

  /// Generates [count] evenly spaced CSS color stops across `[0, 1]`.
  List<String> gradientStops([int count = 8]) {
    if (count <= 1) return <String>[sampleCss(0.5)];
    return List<String>.generate(
      count,
      (i) => sampleCss(i / (count - 1)),
      growable: false,
    );
  }
}

/// Visual legend swatch descriptor for a dataset.
sealed class LegendSwatch {
  /// Base constructor for legend swatches.
  const new();
}

/// Solid or dashed line legend swatch.
final class LineSwatch extends LegendSwatch {
  /// Creates a line swatch.
  const new({required this.color, this.dashed = false, this.width = 2.0});

  /// CSS stroke color.
  final String color;

  /// Whether the line is dashed.
  final bool dashed;

  /// Nominal stroke width in CSS pixels.
  final double width;
}

/// Point or stem marker legend swatch.
final class MarkerSwatch extends LegendSwatch {
  /// Creates a marker swatch.
  const new({required this.color, this.filled = true});

  /// CSS marker color.
  final String color;

  /// Whether the marker interior is filled.
  final bool filled;
}

/// Continuous colormap gradient legend swatch.
final class GradientSwatch extends LegendSwatch {
  /// Creates a gradient swatch.
  const new({required this.colormap, this.minLabel = '', this.maxLabel = ''});

  /// Colormap rendered in the swatch bar.
  final Colormap colormap;

  /// Optional label at the low end of the gradient.
  final String minLabel;

  /// Optional label at the high end of the gradient.
  final String maxLabel;
}

/// Periodic phase-wheel swatch for complex domain coloring.
final class PhaseSwatch extends LegendSwatch {
  /// Creates a phase swatch.
  const new();
}

/// Visual theme tokens for graph rendering.
class GraphTheme {
  /// Creates a graph theme.
  const new({
    required this.background,
    required this.surface,
    required this.gridColor,
    required this.axisColor,
    required this.textColor,
    required this.mutedTextColor,
    required this.palette,
    this.isDark = true,
  });

  /// Default dark theme matching the web workspace.
  static const GraphTheme dark = GraphTheme(
    background: '#181a1f',
    surface: '#22252b',
    gridColor: 'rgba(148, 163, 184, 0.16)',
    axisColor: 'rgba(148, 163, 184, 0.45)',
    textColor: '#eceef2',
    mutedTextColor: '#a1a8b5',
    palette: defaultGraphPalette,
    isDark: true,
  );

  /// Default light theme matching the web workspace.
  static const GraphTheme light = GraphTheme(
    background: '#f8f8f7',
    surface: '#ffffff',
    gridColor: 'rgba(24, 24, 27, 0.09)',
    axisColor: 'rgba(24, 24, 27, 0.32)',
    textColor: '#18181b',
    mutedTextColor: '#52525b',
    palette: defaultGraphPalette,
    isDark: false,
  );

  /// Canvas background color.
  final String background;

  /// Elevated HUD/surface color.
  final String surface;

  /// Minor/major grid line color.
  final String gridColor;

  /// Primary axis line color.
  final String axisColor;

  /// Primary label text color.
  final String textColor;

  /// Secondary/muted text color.
  final String mutedTextColor;

  /// Curve color palette.
  final List<String> palette;

  /// Whether this theme uses a dark background.
  final bool isDark;
}

/// Parses a `#RRGGBB` CSS hex color into normalized `[0, 1]` RGB channels.
({double r, double g, double b}) parseHexColor(String hex) {
  final clean = hex.startsWith('#') ? hex.substring(1) : hex;
  if (clean.length == 6) {
    final v = int.tryParse(clean, radix: 16);
    if (v != null) {
      return (
        r: ((v >> 16) & 0xff) / 255.0,
        g: ((v >> 8) & 0xff) / 255.0,
        b: (v & 0xff) / 255.0,
      );
    }
  }
  return (r: 0.38, g: 0.65, b: 0.98);
}

const List<({int r, int g, int b})> _viridisStops = [
  (r: 68, g: 1, b: 84),
  (r: 59, g: 82, b: 139),
  (r: 33, g: 145, b: 140),
  (r: 94, g: 201, b: 98),
  (r: 253, g: 231, b: 37),
];

const List<({int r, int g, int b})> _plasmaStops = [
  (r: 13, g: 8, b: 135),
  (r: 126, g: 3, b: 168),
  (r: 204, g: 71, b: 120),
  (r: 248, g: 149, b: 64),
  (r: 240, g: 249, b: 33),
];

const List<({int r, int g, int b})> _divergingStops = [
  (r: 59, g: 76, b: 192),
  (r: 141, g: 176, b: 254),
  (r: 247, g: 247, b: 247),
  (r: 244, g: 152, b: 122),
  (r: 180, g: 4, b: 38),
];

const List<({int r, int g, int b})> _monochromeStops = [
  (r: 15, g: 23, b: 42),
  (r: 100, g: 116, b: 139),
  (r: 241, g: 245, b: 249),
];

({int r, int g, int b, int a}) _sampleStops(
  double t,
  List<({int r, int g, int b})> stops,
) {
  final scaled = t * (stops.length - 1);
  final idx = scaled.floor().clamp(0, stops.length - 2);
  final frac = scaled - idx;
  final a = stops[idx];
  final b = stops[idx + 1];
  return (
    r: (a.r + (b.r - a.r) * frac).round().clamp(0, 255),
    g: (a.g + (b.g - a.g) * frac).round().clamp(0, 255),
    b: (a.b + (b.b - a.b) * frac).round().clamp(0, 255),
    a: 255,
  );
}

({int r, int g, int b, int a}) _samplePhase(double t) {
  final angle = t * 2.0 * math.pi;
  final r = (0.5 + 0.45 * math.cos(angle)).clamp(0.0, 1.0);
  final g = (0.5 + 0.45 * math.cos(angle - 2.0 * math.pi / 3.0)).clamp(
    0.0,
    1.0,
  );
  final b = (0.5 + 0.45 * math.cos(angle + 2.0 * math.pi / 3.0)).clamp(
    0.0,
    1.0,
  );
  return (
    r: (r * 255).round(),
    g: (g * 255).round(),
    b: (b * 255).round(),
    a: 255,
  );
}
