import 'dart:js_interop';

import 'package:data/symbolic.dart';
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
void setAttrValue(web.HTMLElement element, String text) {
  element.textContent = text;
  element.title = text;
  element.setAttribute('data-copy', text);
}

/// Renders [expr] using MathML inside [element], setting plain text for copying.
void setAttrExpr(web.HTMLElement element, Expr? expr) {
  if (expr == null) {
    setAttrValue(element, '-');
    return;
  }
  final plainText = expr.toString();
  element.title = plainText;
  element.setAttribute('data-copy', plainText);
  try {
    final mathMl = expr.toMathMl();
    element.innerHTML = mathMl.toJS;
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

/// Initializes global event delegation on document body for copy buttons.
/// Only the copy button triggers clipboard actions.
void initGlobalCopyHandler() {
  injectCopyButtons();

  web.document.addEventListener(
    'click',
    (web.MouseEvent event) {
      final target = event.target as web.Element?;
      if (target == null) return;

      final copyBtn = target.closest('.copy-btn');
      if (copyBtn == null) return;

      final feedbackElement = copyBtn;
      final container =
          copyBtn.closest('.attr-value-container') ??
          copyBtn.closest('.attr-item') ??
          copyBtn.parentElement;
      final valEl = container?.querySelector('.attr-value');
      final textToCopy =
          copyBtn.getAttribute('data-copy') ??
          valEl?.getAttribute('data-copy') ??
          valEl?.textContent;

      if (textToCopy != null) {
        final clean = textToCopy.trim();
        if (clean.isNotEmpty && clean != '-' && clean != 'undefined') {
          copyToClipboard(clean);
          showCopyToast(clean);
          feedbackElement.classList.add('copied');
          Future.delayed(const Duration(milliseconds: 1200), () {
            feedbackElement.classList.remove('copied');
          });
        }
      }
    }.toJS,
  );
}

/// Prettily formats numeric values, handling NaN, Infinities, and negative zero.
String formatNumber(num value, {int precision = 4}) {
  if (value.isNaN) return 'undefined';
  if (value.isInfinite) return value.isNegative ? '-∞' : '∞';
  if (value.abs() < 1e-12) return '0.00';
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

/// Safely evaluates a numeric getter, returning a formatted string or 'undefined'.
String formatProperty(num Function() getter, {int precision = 4}) {
  try {
    return formatNumber(getter(), precision: precision);
  } catch (_) {
    return 'undefined';
  }
}
