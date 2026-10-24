import 'dart:js_interop';

import 'package:data/linear.dart';
import 'package:data/symbolic.dart';
import 'package:data/type.dart';
import 'package:web/web.dart' as web;

/// Copies a given [text] to the system clipboard using the Web Clipboard API.
void copyToClipboard(String text) {
  final navigator = web.window.navigator;
  final clipboard = navigator.clipboard;
  clipboard.writeText(text);
}

/// Floating copy notification toast reference.
web.HTMLDivElement? _copyToast;

/// Shows a non-intrusive floating toast notifying that [text] was copied.
void showCopyToast(String text) {
  var toast = _copyToast;
  if (toast == null) {
    toast = web.document.createElement('div') as web.HTMLDivElement;
    toast.id = 'global-copy-toast';
    toast.className = 'copy-toast';
    web.document.body?.appendChild(toast);
    _copyToast = toast;
  }

  final preview = text.length > 36 ? '${text.substring(0, 36)}…' : text;
  toast.textContent = '✓ Copied: $preview';
  toast.classList.add('show');

  Future.delayed(const Duration(milliseconds: 1600), () {
    toast?.classList.remove('show');
  });
}

/// Sets text on an [element] with full title tooltip for hover and data-copy.
/// If [customCopy] is supplied, copying uses [customCopy] instead of [text].
void setAttrValue(web.HTMLElement element, String text, {String? customCopy}) {
  element.textContent = text;
  element.title = text;
  element.setAttribute('data-copy', customCopy ?? text);
}

/// Renders [expr] using MathML inside [element], setting plain text for copying.
/// If [customCopy] is supplied, copying uses [customCopy] instead.
void setAttrExpr(
  web.HTMLElement element,
  Expr? expr, {
  int decimalPlaces = 4,
  String? customCopy,
}) {
  if (expr == null) {
    setAttrValue(element, '-', customCopy: customCopy);
    return;
  }
  final plainText = expr.format(decimalPlaces: decimalPlaces);
  element.title = plainText;
  element.setAttribute('data-copy', customCopy ?? plainText);
  try {
    final mathMl = expr.toMathMl(decimalPlaces: decimalPlaces);
    element.innerHTML = mathMl.toJS;
  } catch (_) {
    element.textContent = plainText;
  }
}

/// Renders a list of [Expr] separated by commas using MathML inside [element].
/// If [customCopy] is supplied, copying uses [customCopy] instead.
void setAttrExprList(
  web.HTMLElement element,
  List<Expr> expressions, {
  String emptyText = 'None found',
  String? customCopy,
}) {
  if (expressions.isEmpty) {
    setAttrValue(element, emptyText, customCopy: customCopy);
    return;
  }
  final plainText = expressions.map((s) => s.format()).join(', ');
  element.title = plainText;
  element.setAttribute('data-copy', customCopy ?? plainText);
  try {
    final mathList = expressions.map((s) => s.toMathMl()).join(', ');
    element.innerHTML = mathList.toJS;
  } catch (_) {
    element.textContent = plainText;
  }
}

/// Renders a symbolic [Matrix] using MathML inside [element].
/// If [customCopy] is supplied, copying uses [customCopy] instead.
void setAttrMatrix(
  web.HTMLElement element,
  Matrix<Expr>? matrix, {
  String? customCopy,
}) {
  if (matrix == null) {
    setAttrValue(element, '-', customCopy: customCopy);
    return;
  }
  final plainText = matrix.format();
  element.title = plainText;
  element.setAttribute('data-copy', customCopy ?? plainText);
  try {
    element.innerHTML = matrix.toMathMl().toJS;
  } catch (_) {
    element.textContent = plainText;
  }
}

/// Renders a symbolic [Vector] using MathML inside [element].
/// If [customCopy] is supplied, copying uses [customCopy] instead.
void setAttrVector(
  web.HTMLElement element,
  Vector<Expr>? vector, {
  String? customCopy,
}) {
  if (vector == null) {
    setAttrValue(element, '-', customCopy: customCopy);
    return;
  }
  final plainText = vector.format();
  element.title = plainText;
  element.setAttribute('data-copy', customCopy ?? plainText);
  try {
    element.innerHTML = vector.toMathMl().toJS;
  } catch (_) {
    element.textContent = plainText;
  }
}

/// SVG icon markup for the copy button.
const _copyIconSvg =
    '<svg class="copy-icon" viewBox="0 0 24 24" width="12" height="12" '
    'stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round" '
    'stroke-linejoin="round">'
    '<rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>'
    '<path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>'
    '</svg>';

/// Creates a standard copy button DOM element.
web.HTMLButtonElement createCopyButton({String title = 'Copy to clipboard'}) {
  final btn = web.document.createElement('button') as web.HTMLButtonElement;
  btn.className = 'copy-btn';
  btn.title = title;
  btn.setAttribute('aria-label', title);
  btn.innerHTML = _copyIconSvg.toJS;
  return btn;
}

/// Dynamically injects copy buttons next to all `.attr-value` elements
/// across the document.
void injectCopyButtons() {
  final attrValues = web.document.querySelectorAll('.attr-value');
  for (var i = 0; i < attrValues.length; i++) {
    final valEl = attrValues.item(i) as web.HTMLElement;
    final parent = valEl.parentElement;
    if (parent == null) continue;

    if (parent.classList.contains('attr-value-container')) {
      if (parent.querySelector('.copy-btn') == null) {
        parent.appendChild(createCopyButton());
      }
    } else {
      final container = web.document.createElement('div') as web.HTMLDivElement;
      container.className = 'attr-value-container';
      parent.insertBefore(container, valEl);
      container.appendChild(valEl);
      container.appendChild(createCopyButton());
    }
  }
}

/// Initializes global event delegation on document body for copy buttons and copyable values.
/// Clicking the copy button or a copyable value triggers clipboard actions.
void initGlobalCopyHandler() {
  injectCopyButtons();

  web.document.addEventListener(
    'click',
    (web.MouseEvent event) {
      final target = event.target as web.Element?;
      if (target == null) return;

      final copyBtn = target.closest('.copy-btn');
      final attrValueEl = target.closest('.attr-value');

      // Allow either clicking the copy button directly or clicking an .attr-value directly
      if (copyBtn == null && attrValueEl == null) return;

      if (attrValueEl != null && copyBtn == null) {
        final selection = web.window.getSelection()?.toString() ?? '';
        if (selection.trim().isNotEmpty) return;
      }

      final container =
          copyBtn?.closest('.attr-value-container') ??
          copyBtn?.closest('.attr-item') ??
          attrValueEl?.closest('.attr-value-container') ??
          attrValueEl?.closest('.attr-item');

      final valEl = container?.querySelector('.attr-value');
      final activeCopyBtn = container?.querySelector('.copy-btn');

      final textToCopy =
          copyBtn?.getAttribute('data-copy') ??
          valEl?.getAttribute('data-copy') ??
          container?.getAttribute('data-copy') ??
          valEl?.textContent;

      if (textToCopy != null) {
        final clean = textToCopy.trim();
        if (clean.isNotEmpty &&
            clean != '-' &&
            clean.toLowerCase() != 'undefined') {
          copyToClipboard(clean);
          showCopyToast(clean);
          activeCopyBtn?.classList.add('copied');
          valEl?.classList.add('copied');
          Future.delayed(const Duration(milliseconds: 1200), () {
            activeCopyBtn?.classList.remove('copied');
            valEl?.classList.remove('copied');
          });
        }
      }
    }.toJS,
  );
}

/// Prettily formats numeric values, handling NaN, Infinities, and negative zero.
String formatNumber(num value, {int precision = 4}) {
  if (value.isNaN) return 'Undefined';
  if (value.isInfinite) return value.isNegative ? '-∞' : '∞';
  if (value == DataType.integer.safeMin) return '-∞';
  if (value == DataType.integer.safeMax) return '∞';
  if (value.abs() < 1e-12) return '0';
  if (value % 1 == 0 && value.abs() < 1e12) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(precision);
}

/// Safe getter for dynamic computations that might throw exceptions or be undefined.
num? safeGet(num Function() getter) {
  try {
    final val = getter();
    return val.isNaN ? null : val;
  } catch (_) {
    return null;
  }
}

/// Safely evaluates a numeric getter, returning a formatted string or 'Undefined'.
String formatProperty(num Function() getter, {int precision = 4}) {
  try {
    return formatNumber(getter(), precision: precision);
  } catch (_) {
    return 'Undefined';
  }
}
