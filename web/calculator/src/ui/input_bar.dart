import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../language/completion.dart';
import '../language/grammar.dart';
import '../model/environment.dart';
import '../model/session.dart';

/// Docked bottom formula input bar with dual-layer syntax/bracket highlighting,
/// PetitParser live validation indicator, parameter-aware autocomplete popup,
/// command history navigation, and busy/Cancel indicator.
final class FormulaInputBar {
  new({
    required this.onSubmit,
    required this.onRpnImmediateChar,
    required this.onRpnImmediateStackKey,
    required this.onCancelBusy,
    required this.onToggleMatrixBuilder,
    required this.onToggleKeypad,
    required this.getMode,
    required this.getEnvironment,
    required this.getSession,
  }) {
    _buildDom();
  }

  final void Function(String input, {required bool forceNumeric}) onSubmit;
  final bool Function(String opChar) onRpnImmediateChar;
  final bool Function(String key) onRpnImmediateStackKey;
  final void Function() onCancelBusy;
  final void Function() onToggleMatrixBuilder;
  final void Function() onToggleKeypad;
  final CalcMode Function() getMode;
  final Environment Function() getEnvironment;
  final Session Function() getSession;

  late final web.HTMLDivElement element;
  late final web.HTMLTextAreaElement textarea;
  late final web.HTMLDivElement _highlightLayer;
  late final web.HTMLDivElement _popupContainer;
  late final web.HTMLDivElement _sigHintBar;
  late final web.HTMLSpanElement _promptBadge;
  late final web.HTMLSpanElement _statusDot;
  late final web.HTMLButtonElement _matrixBtn;
  late final web.HTMLButtonElement _evalBtn;
  late final web.HTMLButtonElement _approxBtn;
  late final web.HTMLButtonElement _cancelBtn;

  CompletionResult _currentCompletion = const CompletionResult(
    prefix: '',
    replaceStart: 0,
    replaceEnd: 0,
    items: [],
  );
  int _selectedCompletionIdx = 0;
  bool _popupOpen = false;
  int _historyCursor = -1;
  String _draftBeforeHistory = '';
  bool _normalizingDeadKey = false;
  int _lastDeadKeyMs = 0;

  String get value => textarea.value;
  set value(String text) {
    textarea.value = text;
    _onInputChanged();
  }

  /// Returns `true` if the cursor in the input bar is currently inside an
  /// unclosed single quote (`'...'`), parenthesis (`(...)`), or square bracket
  /// (`[...]`).
  bool get isInsideCompoundLiteral {
    final pos = textarea.selectionEnd.clamp(0, textarea.value.length);
    final before = CalcGrammar.normalizeDeadKeys(
      textarea.value.substring(0, pos),
    );
    var quotes = 0;
    var bracketDepth = 0;
    var parenDepth = 0;
    for (var i = 0; i < before.length; i++) {
      final ch = before[i];
      if (ch == "'") {
        quotes++;
      } else if (quotes.isEven) {
        if (ch == '[') {
          bracketDepth++;
        } else if (ch == ']') {
          if (bracketDepth > 0) bracketDepth--;
        } else if (ch == '(') {
          parenDepth++;
        } else if (ch == ')') {
          if (parenDepth > 0) parenDepth--;
        }
      }
    }
    return quotes.isOdd || bracketDepth > 0 || parenDepth > 0;
  }

  void focus() => textarea.focus();

  /// Inserts [snippet] at the current cursor position and moves the cursor back
  /// by [cursorBack] characters.
  void insertAtCursor(String snippet, {int cursorBack = 0}) {
    final start = textarea.selectionStart;
    final end = textarea.selectionEnd;
    final cur = textarea.value;
    final updated = cur.replaceRange(start, end, snippet);
    textarea.value = updated;
    final newPos = (start + snippet.length - cursorBack).clamp(
      0,
      updated.length,
    );
    textarea.setSelectionRange(newPos, newPos);
    textarea.focus();
    _onInputChanged();
  }

  void backspaceAtCursor() {
    final start = textarea.selectionStart;
    final end = textarea.selectionEnd;
    final cur = textarea.value;
    if (start != end) {
      textarea.value = cur.replaceRange(start, end, '');
      textarea.setSelectionRange(start, start);
    } else if (start > 0) {
      textarea.value = cur.replaceRange(start - 1, start, '');
      textarea.setSelectionRange(start - 1, start - 1);
    }
    textarea.focus();
    _onInputChanged();
  }

  void updatePrompt({required CalcMode mode, required int nextId}) {
    if (mode == CalcMode.rpn) {
      _promptBadge.textContent = 'RPN ▸';
      textarea.placeholder = 'Enter symbols, numbers, or postfix commands (e.g. x 2 ^ 1 - factor)...';
      _evalBtn.textContent = 'Enter ↵';
      _evalBtn.title = 'Push to stack or DUP (Enter)';
      _approxBtn.title = 'Approximate numerically on stack (Alt+Enter)';
      _approxBtn.classList.remove('hidden');
    } else {
      _promptBadge.textContent = 'in[$nextId] ▸';
      textarea.placeholder = 'Enter expression, equation, or command (e.g. integrate(x * cos(x), x))...';
      _evalBtn.textContent = 'Eval ↵';
      _evalBtn.title = 'Evaluate exact (Enter)';
      _approxBtn.title = 'Approximate numerically (Alt+Enter)';
      _approxBtn.classList.remove('hidden');
    }
  }

  void setBusy(bool busy, {int elapsedMs = 0}) {
    if (busy) {
      _cancelBtn.classList.remove('hidden');
      final secs = (elapsedMs / 1000).toStringAsFixed(1);
      _cancelBtn.textContent = '⏳ ${secs}s — Cancel';
      _evalBtn.disabled = true;
      _approxBtn.disabled = true;
    } else {
      _cancelBtn.classList.add('hidden');
      _evalBtn.disabled = false;
      _approxBtn.disabled = false;
    }
  }

  void setMatrixBuilderActive(bool active) {
    _matrixBtn.className = active ? 'calc-icon-btn active' : 'calc-icon-btn';
  }

  void _buildDom() {
    element = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-input-dock';

    // Parameter signature hint bar + autocomplete popup above dock
    _sigHintBar = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-sig-hint hidden';
    _popupContainer = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-autocomplete-popup hidden';

    final bar = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'formula-input-bar calc-formula-bar';

    _promptBadge = web.document.createElement('span') as web.HTMLSpanElement
      ..className = 'calc-prompt-badge'
      ..textContent = 'in[1] ▸';

    _statusDot = web.document.createElement('span') as web.HTMLSpanElement
      ..className = 'calc-syntax-dot valid'
      ..title = 'Syntax valid';

    final editorContainer =
        web.document.createElement('div') as web.HTMLDivElement
          ..className = 'editor-container calc-editor-container';
    _highlightLayer = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'editor-layer highlight-layer';
    textarea = web.document.createElement('textarea') as web.HTMLTextAreaElement
      ..id = 'calc-formula-input'
      ..name = 'calc-formula-input'
      ..className = 'editor-layer input-layer'
      ..rows = 1
      ..spellcheck = false
      ..autocomplete = 'off';
    textarea.setAttribute('aria-label', 'Calculator formula input');
    editorContainer
      ..append(_highlightLayer)
      ..append(textarea);

    final toolsGroup = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-input-tools';

    _matrixBtn = web.document.createElement('button') as web.HTMLButtonElement
      ..type = 'button'
      ..className = 'calc-icon-btn'
      ..title = 'Toggle Matrix / Vector grid builder'
      ..innerHTML =
          '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'
                  '<rect x="3" y="3" width="18" height="18" rx="2"/>'
                  '<path d="M3 9h18M3 15h18M9 3v18M15 3v18"/>'
                  '</svg>'
              .toJS;
    _matrixBtn.setAttribute(
      'aria-label',
      'Toggle Matrix / Vector grid builder',
    );
    _matrixBtn.addEventListener(
      'click',
      ((web.Event _) => onToggleMatrixBuilder()).toJS,
    );

    final keypadBtn =
        web.document.createElement('button') as web.HTMLButtonElement
          ..type = 'button'
          ..className = 'calc-icon-btn'
          ..title = 'Toggle virtual math keypad'
          ..innerHTML =
              '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'
                      '<rect x="2" y="4" width="20" height="16" rx="2"/>'
                      '<path d="M6 8h.01M10 8h.01M14 8h.01M18 8h.01M6 12h.01M10 12h.01M14 12h.01M18 12h.01M8 16h8"/>'
                      '</svg>'
                  .toJS;
    keypadBtn.setAttribute('aria-label', 'Toggle virtual math keypad');
    keypadBtn.addEventListener(
      'click',
      ((web.Event _) => onToggleKeypad()).toJS,
    );

    toolsGroup
      ..append(_matrixBtn)
      ..append(keypadBtn);

    final actionGroup = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-input-actions';

    _approxBtn = web.document.createElement('button') as web.HTMLButtonElement
      ..type = 'button'
      ..className = 'calc-btn-secondary calc-eval-approx-btn'
      ..textContent = '≈ Approx'
      ..title = 'Approximate numerically (Alt+Enter)';
    _approxBtn.addEventListener(
      'click',
      ((web.Event _) => _submit(forceNumeric: true)).toJS,
    );

    _evalBtn = web.document.createElement('button') as web.HTMLButtonElement
      ..type = 'button'
      ..className = 'calc-btn-primary calc-eval-btn'
      ..textContent = 'Eval ↵'
      ..title = 'Evaluate exact (Enter)';
    _evalBtn.addEventListener(
      'click',
      ((web.Event _) => _submit(forceNumeric: false)).toJS,
    );

    _cancelBtn = web.document.createElement('button') as web.HTMLButtonElement
      ..type = 'button'
      ..className = 'calc-btn-danger hidden'
      ..textContent = 'Cancel';
    _cancelBtn.addEventListener(
      'click',
      ((web.Event _) => onCancelBusy()).toJS,
    );

    actionGroup
      ..append(_approxBtn)
      ..append(_evalBtn)
      ..append(_cancelBtn);

    bar
      ..append(_promptBadge)
      ..append(_statusDot)
      ..append(toolsGroup)
      ..append(editorContainer)
      ..append(actionGroup);

    element
      ..append(_sigHintBar)
      ..append(_popupContainer)
      ..append(bar);

    textarea.addEventListener(
      'scroll',
      ((web.Event _) {
        _highlightLayer.scrollLeft = textarea.scrollLeft;
      }).toJS,
    );

    textarea.addEventListener(
      'input',
      ((web.Event _) {
        _historyCursor = -1;
        _onInputChanged();
      }).toJS,
    );

    textarea.addEventListener('keydown', _onKeyDown.toJS);

    textarea.addEventListener(
      'blur',
      ((web.Event _) {
        if (_normalizingDeadKey) return;
        // Delay hiding popup so clicks on completion items register
        web.window.setTimeout(
          (() {
            _popupOpen = false;
            _popupContainer.classList.add('hidden');
          }).toJS,
          160.toJS,
        );
      }).toJS,
    );
  }

  void _onKeyDown(web.KeyboardEvent e) {
    final mode = getMode();

    // Swallow redundant confirmation Space right after a dead key (e.g. ^ + Space
    // or ' + Space on US International keyboards)
    if (e.key == ' ' && !e.ctrlKey && !e.metaKey && !e.altKey) {
      final elapsed = DateTime.now().millisecondsSinceEpoch - _lastDeadKeyMs;
      if (elapsed >= 0 && elapsed < 600) {
        final cur = textarea.value;
        final pos = textarea.selectionEnd;
        final prevChar = (pos > 0 && pos <= cur.length) ? cur[pos - 1] : '';
        if ((mode == CalcMode.rpn && cur.isEmpty) ||
            prevChar == '^' ||
            prevChar == "'") {
          e.preventDefault();
          _lastDeadKeyMs = 0;
          return;
        }
      }
    }

    // Autocomplete navigation when popup is visible
    if (_popupOpen && _currentCompletion.items.isNotEmpty) {
      if (e.key == 'ArrowDown') {
        e.preventDefault();
        _selectedCompletionIdx =
            (_selectedCompletionIdx + 1) % _currentCompletion.items.length;
        _renderPopup();
        return;
      }
      if (e.key == 'ArrowUp') {
        e.preventDefault();
        _selectedCompletionIdx =
            (_selectedCompletionIdx - 1 + _currentCompletion.items.length) %
            _currentCompletion.items.length;
        _renderPopup();
        return;
      }
      if (e.key == 'Tab') {
        e.preventDefault();
        _applyCompletion(_currentCompletion.items[_selectedCompletionIdx]);
        return;
      }
      if (e.key == 'Escape') {
        e.preventDefault();
        _popupOpen = false;
        _popupContainer.classList.add('hidden');
        return;
      }
    }

    // Auto-closing delimiter pairs
    if (!e.ctrlKey && !e.metaKey && !e.altKey) {
      const pairs = {'(': ')', '[': ']', "'": "'"};
      if (pairs.containsKey(e.key)) {
        final start = textarea.selectionStart;
        final end = textarea.selectionEnd;
        if (start != end) {
          e.preventDefault();
          final selected = textarea.value.substring(start, end);
          final wrapped = '${e.key}$selected${pairs[e.key]}';
          textarea.value = textarea.value.replaceRange(start, end, wrapped);
          textarea.setSelectionRange(start + 1, end + 1);
          _onInputChanged();
          return;
        }
      }
    }

    // RPN immediate mode keys when not inside compound literal ('...', [...], (...))
    if (mode == CalcMode.rpn) {
      final raw = CalcGrammar.normalizeDeadKeys(textarea.value);
      final normalizedKey = e.key == 'ˆ' ? '^' : e.key;

      if (!isInsideCompoundLiteral &&
          !e.ctrlKey &&
          !e.metaKey &&
          !e.altKey &&
          const {'+', '-', '*', '/', '^', '!'}.contains(normalizedKey)) {
        // Allow '-' after 'e' or 'E' for scientific notation (1e-5)
        final endsWithSci =
            normalizedKey == '-' && (raw.endsWith('e') || raw.endsWith('E'));
        if (!endsWithSci) {
          e.preventDefault();
          onRpnImmediateChar(normalizedKey);
          return;
        }
      }

      if (raw.isEmpty && !e.ctrlKey && !e.metaKey && !e.altKey) {
        if (e.key == 'Backspace' ||
            e.key == 'ArrowUp' ||
            e.key == 'ArrowDown' ||
            e.key == 'Enter') {
          e.preventDefault();
          onRpnImmediateStackKey(e.key);
          return;
        }
      }
    }

    // Enter / Alt+Enter / Shift+Enter
    if (e.key == 'Enter') {
      if (e.shiftKey) {
        // Allow multiline newline
        return;
      }
      e.preventDefault();
      _submit(forceNumeric: e.altKey);
      return;
    }

    // Up / Down input history when single-line or at top/bottom edge
    if (e.key == 'ArrowUp' && !textarea.value.contains('\n')) {
      final history = getSession().history;
      if (history.isNotEmpty) {
        e.preventDefault();
        if (_historyCursor == -1) {
          _draftBeforeHistory = textarea.value;
          _historyCursor = history.length - 1;
        } else if (_historyCursor > 0) {
          _historyCursor--;
        }
        textarea.value = history[_historyCursor];
        _onInputChanged();
      }
      return;
    }
    if (e.key == 'ArrowDown' &&
        !textarea.value.contains('\n') &&
        _historyCursor != -1) {
      final history = getSession().history;
      e.preventDefault();
      if (_historyCursor < history.length - 1) {
        _historyCursor++;
        textarea.value = history[_historyCursor];
      } else {
        _historyCursor = -1;
        textarea.value = _draftBeforeHistory;
      }
      _onInputChanged();
      return;
    }
  }

  void _submit({required bool forceNumeric}) {
    final raw = CalcGrammar.normalizeDeadKeys(textarea.value).trim();
    if (raw.isEmpty) {
      if (getMode() == CalcMode.rpn) {
        onRpnImmediateStackKey(forceNumeric ? 'Approx' : 'Enter');
      }
      return;
    }
    textarea.value = '';
    _historyCursor = -1;
    _onInputChanged();
    onSubmit(raw, forceNumeric: forceNumeric);
  }

  static bool _hasDeadKeyChars(String s) =>
      s.contains('ˆ') ||
      s.contains('\u0302') ||
      s.contains('‸') ||
      s.contains('＾') ||
      s.contains('´') ||
      s.contains('\u0301');

  void _onInputChanged() {
    if (_normalizingDeadKey) return;
    var raw = textarea.value;

    // Normalize US International dead-key circumflex (ˆ) and acute quote (´)
    // and abort active IME composition so subsequent characters type normally.
    if (_hasDeadKeyChars(raw)) {
      final cursor = textarea.selectionEnd;
      final normalized = CalcGrammar.normalizeDeadKeys(raw);
      _normalizingDeadKey = true;
      _lastDeadKeyMs = DateTime.now().millisecondsSinceEpoch;
      textarea.blur();
      textarea.focus();
      textarea.value = normalized;
      final clampedCursor = cursor.clamp(0, normalized.length);
      textarea.setSelectionRange(clampedCursor, clampedCursor);
      _normalizingDeadKey = false;
      raw = normalized;
    }

    // In RPN mode outside compound literals, a trailing '^' (from dead-key composition)
    // executes immediately as the RPN power operator.
    if (getMode() == CalcMode.rpn) {
      if (!isInsideCompoundLiteral && raw.endsWith('^')) {
        final withoutCaret = raw.substring(0, raw.length - 1);
        _normalizingDeadKey = true;
        textarea.value = withoutCaret;
        _normalizingDeadKey = false;
        _highlightLayer.innerHTML = _buildHighlightedHtml(withoutCaret).toJS;
        onRpnImmediateChar('^');
        return;
      }
    }

    // Auto-grow height (1 to 4 rows)
    final lineCount = '\n'.allMatches(raw).length + 1;
    textarea.rows = lineCount.clamp(1, 4);

    // Highlight layer
    _highlightLayer.innerHTML = _buildHighlightedHtml(raw).toJS;
    _highlightLayer.scrollLeft = textarea.scrollLeft;

    // Live PetitParser syntax validation
    if (raw.trim().isEmpty) {
      _statusDot.className = 'calc-syntax-dot valid';
      _statusDot.title = 'Ready';
    } else {
      final grammar = CalcGrammar(
        implicitMultiplication:
            getEnvironment().settings.implicitMultiplication,
      );
      final isValid = getMode() == CalcMode.rpn
          ? _acceptRpn(grammar, raw)
          : grammar.acceptStatement(raw);
      _statusDot.className = isValid
          ? 'calc-syntax-dot valid'
          : 'calc-syntax-dot pending';
      _statusDot.title = isValid
          ? 'Valid syntax'
          : 'Incomplete or invalid expression';
    }

    // Autocomplete & signature hints
    final cursor = textarea.selectionEnd.clamp(0, raw.length);
    _currentCompletion = CalcCompletion.complete(
      raw,
      cursor,
      environment: getEnvironment(),
      session: getSession(),
    );
    _selectedCompletionIdx = 0;

    final sig = _currentCompletion.signatureHint;
    if (sig != null) {
      _sigHintBar.classList.remove('hidden');
      _renderSignatureHint(sig);
    } else {
      _sigHintBar.classList.add('hidden');
    }

    if (_currentCompletion.items.isNotEmpty) {
      _popupOpen = true;
      _popupContainer.classList.remove('hidden');
      _renderPopup();
    } else {
      _popupOpen = false;
      _popupContainer.classList.add('hidden');
    }
  }

  bool _acceptRpn(CalcGrammar grammar, String raw) {
    try {
      grammar.parseRpnTokens(raw);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _renderSignatureHint(SignatureHint sig) {
    _sigHintBar.innerHTML = ''.toJS;
    final fnSpan = web.document.createElement('span') as web.HTMLSpanElement
      ..className = 'calc-sig-name'
      ..textContent = '${sig.name}(';
    _sigHintBar.append(fnSpan);

    for (var i = 0; i < sig.params.length; i++) {
      if (i > 0) {
        _sigHintBar.append(web.document.createTextNode(', '));
      }
      final pSpan = web.document.createElement('span') as web.HTMLSpanElement
        ..className = i == math.min(sig.activeParamIndex, sig.params.length - 1)
            ? 'calc-sig-param active'
            : 'calc-sig-param'
        ..textContent = sig.params[i];
      _sigHintBar.append(pSpan);
    }
    _sigHintBar.append(web.document.createTextNode(') — '));
    final docSpan = web.document.createElement('span') as web.HTMLSpanElement
      ..className = 'calc-sig-doc'
      ..textContent = sig.doc;
    _sigHintBar.append(docSpan);
  }

  void _renderPopup() {
    _popupContainer.innerHTML = ''.toJS;
    final items = _currentCompletion.items.take(8).toList();
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final row = web.document.createElement('button') as web.HTMLButtonElement
        ..type = 'button'
        ..className = i == _selectedCompletionIdx
            ? 'calc-ac-item active'
            : 'calc-ac-item';
      final label = web.document.createElement('span') as web.HTMLSpanElement
        ..className = 'calc-ac-label'
        ..textContent = item.label;
      final detail = web.document.createElement('span') as web.HTMLSpanElement
        ..className = 'calc-ac-detail'
        ..textContent = item.detail;
      row
        ..append(label)
        ..append(detail);
      row.addEventListener(
        'mousedown',
        ((web.Event e) {
          e.preventDefault();
          _applyCompletion(item);
        }).toJS,
      );
      _popupContainer.append(row);
    }
  }

  void _applyCompletion(CompletionItem item) {
    final cur = textarea.value;
    final start = _currentCompletion.replaceStart.clamp(0, cur.length);
    final end = _currentCompletion.replaceEnd.clamp(start, cur.length);
    final updated = cur.replaceRange(start, end, item.insertText);
    textarea.value = updated;
    final newCursor = (start + item.insertText.length).clamp(0, updated.length);
    textarea.setSelectionRange(newCursor, newCursor);
    _popupOpen = false;
    _popupContainer.classList.add('hidden');
    textarea.focus();
    _onInputChanged();
  }

  static String _buildHighlightedHtml(String text) {
    if (text.isEmpty) return '';
    final buf = StringBuffer();
    var depth = 0;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == '(' || ch == '[') {
        final lvl = depth % 3;
        depth++;
        buf.write('<span class="hl-bracket-$lvl">${_esc(ch)}</span>');
      } else if (ch == ')' || ch == ']') {
        depth = math.max(0, depth - 1);
        final lvl = depth % 3;
        buf.write('<span class="hl-bracket-$lvl">${_esc(ch)}</span>');
      } else {
        buf.write(_esc(ch));
      }
    }
    if (text.endsWith('\n')) buf.write(' ');
    return buf.toString();
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
