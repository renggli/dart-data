import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../../shared/html.dart';
import '../engine/commands.dart';
import '../language/completion.dart';
import '../language/grammar.dart';
import '../model/environment.dart';
import 'highlighter.dart';

/// Mode of syntax highlighting used by [CodeEditor].
enum CodeEditorMode { math, markdown }

/// Reusable dual-layer inline code editor with pixel-aligned syntax
/// highlighting, multiline auto-grow, dead-key normalization, autocomplete
/// popup, and active-parameter signature hints.
final class CodeEditor {
  new({
    required this.mode,
    required this.registry,
    required this.env,
    String initialText = '',
    this.placeholder = '',
    this.onChange,
    this.onRunAndAdvance,
    this.onRunInPlace,
    this.onApprox,
    this.onEscape,
    this.onBlur,
  }) {
    _buildDom(initialText);
  }

  final CodeEditorMode mode;
  final CommandRegistry registry;
  final Environment env;
  final String placeholder;

  final void Function(String value)? onChange;
  final void Function(String value)? onRunAndAdvance;
  final void Function(String value)? onRunInPlace;
  final void Function(String value)? onApprox;
  final void Function()? onEscape;
  final void Function()? onBlur;

  late final web.HTMLDivElement root;
  late final web.HTMLPreElement _backdrop;
  late final web.HTMLTextAreaElement _textarea;
  late final web.HTMLDivElement _sigBar;
  late final web.HTMLDivElement _popup;
  late final web.HTMLDivElement _errorBar;

  CompletionResult? _activeCompletion;
  int _selectedIndex = 0;

  String get value => _textarea.value;

  set value(String next) {
    _textarea.value = next;
    _syncHighlightAndSize();
  }

  void focus({bool moveToEnd = true}) {
    _textarea.focus();
    if (moveToEnd) {
      final len = _textarea.value.length;
      _textarea.setSelectionRange(len, len);
    }
    _syncHighlightAndSize();
  }

  void setError(String? message, {int? offset}) {
    if (message == null || message.isEmpty) {
      _errorBar.style.display = 'none';
      _errorBar.textContent = '';
      root.classList.remove('has-error');
      return;
    }
    root.classList.add('has-error');
    _errorBar.style.display = 'block';
    _errorBar.textContent = offset != null ? 'At $offset: $message' : message;
  }

  void _buildDom(String initialText) {
    root = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-editor';

    final stage = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-editor-stage';

    _backdrop = (web.document.createElement('pre') as web.HTMLPreElement)
      ..className = 'nb-editor-backdrop'
      ..setAttribute('aria-hidden', 'true');

    _textarea =
        (web.document.createElement('textarea') as web.HTMLTextAreaElement)
          ..className = 'nb-editor-input'
          ..value = initialText
          ..placeholder = placeholder
          ..rows = 1
          ..spellcheck = mode == CodeEditorMode.markdown
          ..setAttribute('autocapitalize', 'off')
          ..setAttribute('autocomplete', 'off')
          ..setAttribute('autocorrect', 'off');

    stage.append(_backdrop);
    stage.append(_textarea);

    _sigBar = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-editor-sig'
      ..style.display = 'none';

    _popup = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-editor-popup'
      ..style.display = 'none';

    _errorBar = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-editor-error'
      ..style.display = 'none';

    root
      ..append(stage)
      ..append(_sigBar)
      ..append(_popup)
      ..append(_errorBar);

    _textarea.oninput = ((web.Event _) {
      final raw = _textarea.value;
      final normalized = mode == CodeEditorMode.math
          ? CalcGrammar.normalizeDeadKeys(raw)
          : raw;
      if (normalized != raw) {
        final pos = _textarea.selectionStart;
        _textarea.value = normalized;
        _textarea.setSelectionRange(pos, pos);
      }
      setError(null);
      _syncHighlightAndSize();
      _refreshCompletion();
      onChange?.call(_textarea.value);
    }).toJS;

    _textarea.onscroll = ((web.Event _) {
      _backdrop.scrollTop = _textarea.scrollTop;
      _backdrop.scrollLeft = _textarea.scrollLeft;
    }).toJS;

    _textarea.onkeyup = ((web.KeyboardEvent e) {
      if (e.key == 'ArrowLeft' ||
          e.key == 'ArrowRight' ||
          e.key == 'Home' ||
          e.key == 'End') {
        _syncHighlightAndSize();
        _refreshCompletion();
      }
    }).toJS;

    _textarea.onclick = ((web.MouseEvent _) {
      _syncHighlightAndSize();
      _refreshCompletion();
    }).toJS;

    _textarea.onblur = ((web.FocusEvent _) {
      // Delay hiding popup so mousedown on popup item can fire first.
      Timer(const Duration(milliseconds: 120), () {
        _hidePopup();
        onBlur?.call();
      });
    }).toJS;

    _textarea.onkeydown = ((web.KeyboardEvent e) {
      if (_handlePopupKey(e)) return;

      if (mode == CodeEditorMode.math && _handleDelimiterKey(e)) return;

      if (e.key == 'Enter') {
        if (e.altKey) {
          e.preventDefault();
          _hidePopup();
          onApprox?.call(_textarea.value);
          return;
        }
        if (e.shiftKey) {
          e.preventDefault();
          _hidePopup();
          onRunAndAdvance?.call(_textarea.value);
          return;
        }
        if (e.ctrlKey || e.metaKey) {
          e.preventDefault();
          _hidePopup();
          onRunInPlace?.call(_textarea.value);
          return;
        }
      }

      if (e.key == 'Escape') {
        e.preventDefault();
        if (_activeCompletion != null && _activeCompletion!.items.isNotEmpty) {
          _hidePopup();
          return;
        }
        onEscape?.call();
      }
    }).toJS;

    _syncHighlightAndSize();
  }

  static const Map<String, String> _delimiterPairs = {
    '(': ')',
    '[': ']',
    '{': '}',
    "'": "'",
    '"': '"',
  };

  static const Set<String> _closingDelimiters = {')', ']', '}', "'", '"'};

  bool _handleDelimiterKey(web.KeyboardEvent e) {
    if (e.ctrlKey || e.metaKey || e.altKey) return false;

    final start = _textarea.selectionStart;
    final end = _textarea.selectionEnd;
    final text = _textarea.value;

    // Backspace between an empty delimiter pair deletes both characters.
    if (e.key == 'Backspace' &&
        start == end &&
        start > 0 &&
        end < text.length) {
      final prev = text[start - 1];
      final next = text[start];
      if (_delimiterPairs[prev] == next) {
        e.preventDefault();
        final updated =
            '${text.substring(0, start - 1)}${text.substring(start + 1)}';
        _setValueAndCursor(updated, start - 1, start - 1);
        return true;
      }
      return false;
    }

    final key = e.key;
    final close = _delimiterPairs[key];

    // Wrap non-empty selection in matching delimiter pair.
    if (close != null && start != end) {
      e.preventDefault();
      final selected = text.substring(start, end);
      final updated =
          '${text.substring(0, start)}$key$selected$close${text.substring(end)}';
      _setValueAndCursor(updated, start + 1, end + 1);
      return true;
    }

    // Skip over existing matching closing delimiter when cursor is right before it.
    if (_closingDelimiters.contains(key) &&
        start == end &&
        start < text.length &&
        text[start] == key) {
      e.preventDefault();
      _textarea.setSelectionRange(start + 1, start + 1);
      _syncHighlightAndSize();
      _refreshCompletion();
      return true;
    }

    // Auto-close delimiter at collapsed cursor when followed by whitespace,
    // end-of-text, or structural punctuation.
    if (close != null && start == end) {
      final nextOk =
          start == text.length || _isAutoCloseRightChar(text.codeUnitAt(start));
      if (!nextOk) return false;
      if (key == "'" || key == '"') {
        if (start > 0 && _isWordOrNumChar(text.codeUnitAt(start - 1))) {
          return false;
        }
        if (_isInsideUnclosedQuote(text.substring(0, start), key)) {
          return false;
        }
      }
      e.preventDefault();
      final updated =
          '${text.substring(0, start)}$key$close${text.substring(start)}';
      _setValueAndCursor(updated, start + 1, start + 1);
      return true;
    }

    return false;
  }

  void _setValueAndCursor(String next, int selStart, int selEnd) {
    _textarea.value = next;
    _textarea.setSelectionRange(selStart, selEnd);
    setError(null);
    _syncHighlightAndSize();
    _refreshCompletion();
    onChange?.call(next);
  }

  static bool _isAutoCloseRightChar(int ch) =>
      ch == 32 ||
      ch == 9 ||
      ch == 10 ||
      ch == 13 ||
      ch == 41 /* ) */ ||
      ch == 93 /* ] */ ||
      ch == 125 /* } */ ||
      ch == 44 /* , */ ||
      ch == 59 /* ; */ ||
      ch == 58 /* : */;

  static bool _isWordOrNumChar(int ch) =>
      (ch >= 65 && ch <= 90) ||
      (ch >= 97 && ch <= 122) ||
      (ch >= 48 && ch <= 57) ||
      ch == 95;

  static bool _isInsideUnclosedQuote(String before, String quote) {
    final code = quote.codeUnitAt(0);
    var inQuote = false;
    var i = 0;
    while (i < before.length) {
      final c = before.codeUnitAt(i);
      if (inQuote && c == 92 /* \ */ ) {
        i += 2;
        continue;
      }
      if (c == code) {
        inQuote = !inQuote;
      } else if (c == 10 || c == 13) {
        inQuote = false;
      }
      i++;
    }
    return inQuote;
  }

  bool _handlePopupKey(web.KeyboardEvent e) {
    final comp = _activeCompletion;
    if (comp == null || comp.items.isEmpty) return false;

    if (e.key == 'ArrowDown') {
      e.preventDefault();
      _selectedIndex = (_selectedIndex + 1) % comp.items.length;
      _renderPopup(comp);
      return true;
    }
    if (e.key == 'ArrowUp') {
      e.preventDefault();
      _selectedIndex =
          (_selectedIndex - 1 + comp.items.length) % comp.items.length;
      _renderPopup(comp);
      return true;
    }
    if (e.key == 'Tab' ||
        (e.key == 'Enter' &&
            !e.shiftKey &&
            !e.ctrlKey &&
            !e.metaKey &&
            !e.altKey)) {
      e.preventDefault();
      _applyCompletion(comp, comp.items[_selectedIndex]);
      return true;
    }
    return false;
  }

  void _syncHighlightAndSize() {
    final text = _textarea.value;
    final cursor = _textarea.selectionStart;
    final html = mode == CodeEditorMode.math
        ? SyntaxHighlighter.highlightMathHtml(
            text,
            registry: registry,
            env: env,
            cursorOffset: cursor,
          )
        : SyntaxHighlighter.highlightMarkdownHtml(text);

    // Trailing newline ensures the backdrop matches textarea height when the
    // last line is empty.
    _backdrop.innerHTML = '$html\n'.toJS;
    _textarea.style.height = 'auto';
    final scrollH = _textarea.scrollHeight;
    final h = scrollH > 24 ? scrollH : 24;
    _textarea.style.height = '${h}px';
    _backdrop.style.height = '${h}px';
  }

  void _refreshCompletion() {
    if (mode != CodeEditorMode.math) {
      _hidePopup();
      return;
    }
    final cursor = _textarea.selectionStart;
    final res = NotebookCompletion.suggest(
      _textarea.value,
      cursor,
      registry: registry,
      env: env,
    );
    _activeCompletion = res;
    _selectedIndex = 0;
    _renderSigBar(res.signatureHint);
    _renderPopup(res);
  }

  void _renderSigBar(SignatureHint? hint) {
    if (hint == null) {
      _sigBar.style.display = 'none';
      _sigBar.innerHTML = ''.toJS;
      return;
    }
    final active = hint.activeParamName;
    final sigHtml = active == null
        ? escapeHtml(hint.signatureText)
        : escapeHtml(hint.signatureText).replaceFirst(
            escapeHtml(active),
            '<strong>${escapeHtml(active)}</strong>',
          );
    _sigBar.innerHTML =
        '<span class="nb-sig-fn">$sigHtml</span><span class="nb-sig-doc">${escapeHtml(hint.doc)}</span>'
            .toJS;
    _sigBar.style.display = 'flex';
  }

  void _renderPopup(CompletionResult comp) {
    if (comp.items.isEmpty) {
      _popup.style.display = 'none';
      _popup.innerHTML = ''.toJS;
      return;
    }
    _popup.innerHTML = ''.toJS;
    for (var i = 0; i < comp.items.length; i++) {
      final item = comp.items[i];
      final row =
          (web.document.createElement('button') as web.HTMLButtonElement)
            ..type = 'button'
            ..className = i == _selectedIndex
                ? 'nb-popup-item active'
                : 'nb-popup-item';
      row.innerHTML =
          '<span class="nb-popup-label">${escapeHtml(item.label)}</span>'
                  '<span class="nb-popup-detail">${escapeHtml(item.detail)}</span>'
              .toJS;
      row.onmousedown = ((web.MouseEvent e) {
        e.preventDefault();
        _applyCompletion(comp, item);
      }).toJS;
      _popup.append(row);
    }
    _popup.style.display = 'flex';
  }

  void _applyCompletion(CompletionResult comp, CompletionItem item) {
    final text = _textarea.value;
    final before = text.substring(0, comp.replaceStart);
    final after = text.substring(comp.replaceEnd);
    final next = '$before${item.insertText}$after';
    final nextCursor =
        (before.length + item.insertText.length - item.cursorBackOffset).clamp(
          0,
          next.length,
        );
    _textarea.value = next;
    _textarea.setSelectionRange(nextCursor, nextCursor);
    _hidePopup();
    _syncHighlightAndSize();
    _refreshCompletion();
    onChange?.call(next);
  }

  void _hidePopup() {
    _activeCompletion = null;
    _popup.style.display = 'none';
    _sigBar.style.display = 'none';
  }
}
