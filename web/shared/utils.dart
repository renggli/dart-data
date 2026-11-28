import 'dart:js_interop';

import 'package:data/linear.dart';
import 'package:data/symbolic.dart';
import 'package:data/type.dart';
import 'package:more/printer.dart';
import 'package:web/web.dart' as web;

/// Checks whether an [element] is currently hidden.
bool isHidden(web.HTMLElement element) => element.hasAttribute('hidden');

/// Sets or removes the `hidden` attribute on an [element].
void setHidden(web.HTMLElement element, bool hidden) {
  if (hidden) {
    element.setAttribute('hidden', '');
  } else {
    element.removeAttribute('hidden');
  }
}

/// Copies a given [text] to the system clipboard using the Web Clipboard API.
void copyToClipboard(String text) {
  final navigator = web.window.navigator;
  final clipboard = navigator.clipboard;
  clipboard.writeText(text);
}

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

final _fixedIntPrinter = FixedNumberPrinter<num>(
  precision: 0,
  infinity: '∞',
  nan: 'Undefined',
);

/// Prettily formats numeric values using `package:more` printers.
String formatNumber(num value, {int precision = 4}) {
  if (value.isNaN) return 'Undefined';
  if (value.isInfinite) return value.isNegative ? '-∞' : '∞';
  if (value == DataType.integer.safeMin) return '-∞';
  if (value == DataType.integer.safeMax) return '∞';
  if (value.abs() < 1e-12) return '0';
  if (value % 1 == 0 && value.abs() < 1e12) {
    return _fixedIntPrinter.print(value.toInt());
  }
  return FixedNumberPrinter<num>(
    precision: precision,
    infinity: '∞',
    nan: 'Undefined',
  ).print(value);
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

/// Mobile viewport width threshold in CSS pixels aligned with `shared/style.css`.
const int mobileBreakpoint = 767;

/// Whether the current viewport width is at or below [mobileBreakpoint].
bool isMobileViewport() => web.window.innerWidth <= mobileBreakpoint;

/// Whether the left application sidebar is currently collapsed.
bool isSidebarCollapsed() =>
    web.document.body?.classList.contains('sidebar-collapsed') ?? true;

/// Programmatically sets the left application sidebar's collapsed state,
/// persisting to `localStorage` on desktop and notifying listeners.
void setSidebarCollapsed(bool collapsed, {bool persist = true}) {
  final body = web.document.body;
  if (body == null) return;
  body.classList.toggle('sidebar-collapsed', collapsed);
  if (persist && !isMobileViewport()) {
    web.window.localStorage.setItem(
      'data_sidebar_collapsed',
      collapsed ? 'true' : 'false',
    );
  }
  web.window.dispatchEvent(web.CustomEvent('sidebar-change'));
}

/// Triggers a browser file download with [filename], [content], and [mimeType].
void downloadFile(String filename, String content, String mimeType) {
  final blob = web.Blob(
    [content.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final a = (web.document.createElement('a') as web.HTMLAnchorElement)
    ..href = url
    ..download = filename;
  a.click();
  web.URL.revokeObjectURL(url);
}

/// Subscribes to shared `[data-sidebar-toggle]` / `sidebar-change` events and
/// invokes [onToggled] immediately and after the CSS transition settles.
void setupSidebarToggle({void Function(bool collapsed)? onToggled}) {
  void fire() {
    final collapsed = isSidebarCollapsed();
    onToggled?.call(collapsed);
    Future<void>.delayed(const Duration(milliseconds: 280), () {
      onToggled?.call(collapsed);
    });
  }

  web.window.addEventListener('sidebar-change', ((web.Event _) => fire()).toJS);
}

/// Floating copy notification toast reference.
web.HTMLDivElement? _copyToast;

/// Safe floating-point viewport coordinates for [web.MouseEvent] and
/// [web.PointerEvent], avoiding `package:web`'s `int` getter cast failures
/// on fractional browser coordinates.
extension MouseEventCoordinates on web.MouseEvent {
  @JS('clientX')
  external num get _rawClientX;

  @JS('clientY')
  external num get _rawClientY;

  /// Floating-point viewport X coordinate.
  double get clientXDouble => _rawClientX.toDouble();

  /// Floating-point viewport Y coordinate.
  double get clientYDouble => _rawClientY.toDouble();
}
