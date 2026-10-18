import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../model/value.dart';
import 'plot_view.dart';

/// Renders any [CalcValue] into a rich MathML / HTML DOM element for either
/// Scroll worksheet cells or RPN stack rows.
abstract final class ValueRenderer {
  /// Builds the primary rendered DOM node for [value].
  static web.HTMLElement renderValue(
    CalcValue value, {
    int digits = 10,
    void Function(double minX, double maxX)? onPlotResample,
  }) {
    final wrap = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-value-render calc-value-${value.kind}';

    switch (value) {
      case PlotValue():
        wrap.append(PlotView.create(value, onResample: onPlotResample));
        return wrap;

      case ErrorValue(
        :final message,
        :final suggestion,
        :final offset,
        :final source,
      ):
        final errBox = web.document.createElement('div') as web.HTMLDivElement
          ..className = 'calc-error-box';
        final msgSpan = web.document.createElement('div') as web.HTMLDivElement
          ..className = 'calc-error-msg'
          ..textContent = message;
        errBox.append(msgSpan);

        if (source != null &&
            offset != null &&
            offset >= 0 &&
            offset <= source.length) {
          final snippet =
              web.document.createElement('pre') as web.HTMLPreElement
                ..className = 'calc-error-caret';
          final caretLine = '${' ' * offset}^';
          snippet.textContent = '$source\n$caretLine';
          errBox.append(snippet);
        }

        if (suggestion != null && suggestion.isNotEmpty) {
          final hint = web.document.createElement('div') as web.HTMLDivElement
            ..className = 'calc-error-suggestion'
            ..textContent = '💡 $suggestion';
          errBox.append(hint);
        }
        wrap.append(errBox);
        return wrap;

      case InfoValue(:final message, :final title):
        final infoBox = web.document.createElement('div') as web.HTMLDivElement
          ..className = 'calc-info-box';
        if (title != null && title.isNotEmpty) {
          final titleEl =
              web.document.createElement('div') as web.HTMLDivElement
                ..className = 'calc-info-title'
                ..textContent = title;
          infoBox.append(titleEl);
        }
        final pre = web.document.createElement('pre') as web.HTMLPreElement
          ..className = 'calc-info-text'
          ..textContent = message;
        infoBox.append(pre);
        wrap.append(infoBox);
        return wrap;

      default:
        final mathRow = web.document.createElement('div') as web.HTMLDivElement
          ..className = 'calc-math-row';

        // Exact vs Approx badge
        final badge = web.document.createElement('span') as web.HTMLSpanElement
          ..className = value.isExact
              ? 'calc-badge calc-badge-exact'
              : 'calc-badge calc-badge-approx'
          ..textContent = value.isExact ? '=' : '≈'
          ..title = value.isExact
              ? 'Exact symbolic result'
              : 'Floating-point approximation';
        mathRow.append(badge);

        // MathML container
        final mathContainer =
            web.document.createElement('div') as web.HTMLDivElement
              ..className = 'calc-mathml-output';
        final mathMl = value.toMathMl();
        if (mathMl.isNotEmpty) {
          mathContainer.innerHTML = mathMl.toJS;
        } else {
          mathContainer.textContent = value.toCanonicalText();
        }
        mathRow.append(mathContainer);

        // Secondary approximate subtitle when exact non-integer closed value
        final approxSub = value.approxSummary(digits: digits);
        if (approxSub != null) {
          final subSpan =
              web.document.createElement('span') as web.HTMLSpanElement
                ..className = 'calc-approx-subtitle'
                ..textContent = '≈ $approxSub';
          mathRow.append(subSpan);
        }

        wrap.append(mathRow);
        return wrap;
    }
  }
}
