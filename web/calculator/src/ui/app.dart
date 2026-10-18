import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:data/symbolic.dart';
import 'package:web/web.dart' as web;

import '../model/environment.dart';
import '../worker/engine_client.dart';
import 'help.dart';
import 'input_bar.dart';
import 'keypad.dart';
import 'palette.dart';
import 'persistence.dart';
import 'rpn_view.dart';
import 'scroll_view.dart';
import 'shortcuts.dart';

/// Top-level controller for the Symbolic Calculator PWA (`web/calculator/`).
final class CalculatorApp {
  new() {
    _mode = CalcPersistence.loadMode();
    _client = EngineClient(
      onBusyStateChanged: (busy, elapsedMs) {
        _inputBar.setBusy(busy, elapsedMs: elapsedMs);
      },
      onStateUpdated: _onStateUpdated,
    );
  }

  late final EngineClient _client;
  late CalcMode _mode;

  late final ScrollWorksheetView _scrollView;
  late final RpnStackView _rpnView;
  late final FormulaInputBar _inputBar;
  late final VirtualKeypad _keypad;

  late final web.HTMLButtonElement _modeScrollBtn;
  late final web.HTMLButtonElement _modeRpnBtn;
  late final web.HTMLButtonElement _anglePill;
  late final web.HTMLButtonElement _exactPill;
  late final web.HTMLButtonElement _domainPill;
  late final web.HTMLButtonElement _varsPill;
  late final web.HTMLDivElement _varsDrawer;
  late final web.HTMLDivElement _settingsPopover;
  late final web.HTMLDivElement _toastEl;

  Future<void> init() async {
    _bindHeaderControls();
    _mountMainViews();

    // Load from URL hash (#calc=...) or localStorage
    final hashState = CalcPersistence.tryLoadFromUrlHash();
    if (hashState != null) {
      await _client.loadSnapshot(hashState);
      _showToast('Loaded shared session from URL');
    } else {
      final savedState = CalcPersistence.loadState();
      if (savedState != null) {
        await _client.loadSnapshot(savedState);
      }
    }

    // Close popovers on outside click
    final settingsBtn = web.document.getElementById('btn-settings');
    web.document.addEventListener(
      'click',
      ((web.MouseEvent e) {
        final target = e.target as web.Node?;
        if (target != null) {
          if (!_varsDrawer.contains(target) && !_varsPill.contains(target)) {
            _varsDrawer.classList.add('hidden');
          }
          if (!_settingsPopover.contains(target) &&
              (settingsBtn == null || !settingsBtn.contains(target))) {
            _settingsPopover.classList.add('hidden');
          }
        }
      }).toJS,
    );

    GlobalShortcuts.register(
      onOpenPalette: _openCommandPalette,
      onToggleMode: () =>
          _setMode(_mode == CalcMode.scroll ? CalcMode.rpn : CalcMode.scroll),
      onOpenHelp: () => HelpDrawerModal.open(
        onRunExample: (ex) => unawaited(_handleSubmit(ex, forceNumeric: false)),
      ),
      onClearView: () => unawaited(_clearSession()),
      onFunctionKey: (fKey) {
        if (_mode != CalcMode.rpn) return false;
        return _rpnView.softKeyBar.handleFunctionKey(
          fKey,
          environment: _client.environment,
          session: _client.session,
        );
      },
    );

    _refreshAllUi();
    _inputBar.focus();
  }

  void _bindHeaderControls() {
    _modeScrollBtn =
        web.document.getElementById('mode-scroll-btn')!
            as web.HTMLButtonElement;
    _modeRpnBtn =
        web.document.getElementById('mode-rpn-btn')! as web.HTMLButtonElement;
    _anglePill =
        web.document.getElementById('pill-angle')! as web.HTMLButtonElement;
    _exactPill =
        web.document.getElementById('pill-exact')! as web.HTMLButtonElement;
    _domainPill =
        web.document.getElementById('pill-domain')! as web.HTMLButtonElement;
    _varsPill =
        web.document.getElementById('pill-vars')! as web.HTMLButtonElement;
    _varsDrawer =
        web.document.getElementById('vars-drawer')! as web.HTMLDivElement;
    _settingsPopover =
        web.document.getElementById('settings-popover')! as web.HTMLDivElement;
    _toastEl = web.document.getElementById('calc-toast')! as web.HTMLDivElement;

    _modeScrollBtn.addEventListener(
      'click',
      ((web.Event _) => _setMode(CalcMode.scroll)).toJS,
    );
    _modeRpnBtn.addEventListener(
      'click',
      ((web.Event _) => _setMode(CalcMode.rpn)).toJS,
    );

    _anglePill.addEventListener(
      'click',
      ((web.Event _) {
        final cur = _client.environment.settings;
        final next = cur.angleMode == AngleMode.rad
            ? AngleMode.deg
            : AngleMode.rad;
        unawaited(_client.updateSettings(cur.copyWith(angleMode: next)));
      }).toJS,
    );

    _exactPill.addEventListener(
      'click',
      ((web.Event _) {
        final cur = _client.environment.settings;
        unawaited(
          _client.updateSettings(cur.copyWith(approxMode: !cur.approxMode)),
        );
      }).toJS,
    );

    _domainPill.addEventListener(
      'click',
      ((web.Event _) {
        final cur = _client.environment.settings;
        final next = switch (cur.domain) {
          VariableDomain.unknown => VariableDomain.real,
          VariableDomain.real => VariableDomain.positive,
          VariableDomain.positive => VariableDomain.integer,
          VariableDomain.integer => VariableDomain.complex,
          VariableDomain.complex => VariableDomain.unknown,
        };
        unawaited(_client.updateSettings(cur.copyWith(domain: next)));
      }).toJS,
    );

    _varsPill.addEventListener(
      'click',
      ((web.Event e) {
        e.stopPropagation();
        _renderVarsDrawer();
        _varsDrawer.classList.toggle('hidden');
      }).toJS,
    );

    final paletteBtn =
        web.document.getElementById('btn-palette')! as web.HTMLButtonElement;
    paletteBtn.addEventListener(
      'click',
      ((web.Event _) => _openCommandPalette()).toJS,
    );

    final settingsBtn =
        web.document.getElementById('btn-settings')! as web.HTMLButtonElement;
    settingsBtn.addEventListener(
      'click',
      ((web.Event e) {
        e.stopPropagation();
        _renderSettingsPopover();
        _settingsPopover.classList.toggle('hidden');
      }).toJS,
    );

    final helpBtn =
        web.document.getElementById('btn-help')! as web.HTMLButtonElement;
    helpBtn.addEventListener(
      'click',
      ((web.Event _) => HelpDrawerModal.open(
        onRunExample: (ex) => unawaited(_handleSubmit(ex, forceNumeric: false)),
      )).toJS,
    );
  }

  void _mountMainViews() {
    final workspace =
        web.document.getElementById('calc-workspace')! as web.HTMLDivElement;

    _scrollView = ScrollWorksheetView(
      onInsertText: (snippet) => _inputBar.insertAtCursor(snippet),
      onRunStatement: (stmt) =>
          unawaited(_handleSubmit(stmt, forceNumeric: false)),
      onUpdateCell: (id, newInput) =>
          unawaited(_client.updateScrollCell(id, newInput)),
      onDeleteCell: (id) => unawaited(_client.deleteCell(id)),
      onRecomputeAllStale: () => unawaited(_client.recomputeStaleCells()),
      onQuickStartSelect: (code) =>
          unawaited(_handleSubmit(code, forceNumeric: false)),
      onToast: _showToast,
    );

    _rpnView = RpnStackView(
      onExecuteRpnCommand: (cmd) => unawaited(_executeRpnCommand(cmd)),
      onInsertText: (snippet) => _inputBar.insertAtCursor(snippet),
    );

    _inputBar = FormulaInputBar(
      onSubmit: (input, {required forceNumeric}) =>
          unawaited(_handleSubmit(input, forceNumeric: forceNumeric)),
      onRpnImmediateChar: (opChar) {
        unawaited(_handleRpnImmediateOperator(opChar));
        return true;
      },
      onRpnImmediateStackKey: (key) {
        final cmd = switch (key) {
          'Enter' => 'DUP',
          'Backspace' || 'ArrowDown' => 'DROP',
          'ArrowUp' => 'SWAP',
          _ => null,
        };
        if (cmd != null) {
          unawaited(_executeRpnCommand(cmd));
          return true;
        }
        return false;
      },
      onCancelBusy: () {
        _client.cancelActiveComputation();
        _showToast('Computation cancelled');
      },
      onToggleKeypad: () {
        final cur = _client.environment.settings;
        unawaited(
          _client.updateSettings(
            cur.copyWith(keypadVisible: !cur.keypadVisible),
          ),
        );
      },
      getMode: () => _mode,
      getEnvironment: () => _client.environment,
      getSession: () => _client.session,
    );

    _keypad = VirtualKeypad(
      onInsert: (text, {cursorBack = 0}) =>
          _inputBar.insertAtCursor(text, cursorBack: cursorBack),
      onEvaluate: ({required forceNumeric}) {
        final raw = _inputBar.value.trim();
        if (raw.isNotEmpty) {
          _inputBar.value = '';
          unawaited(_handleSubmit(raw, forceNumeric: forceNumeric));
        } else if (_mode == CalcMode.rpn) {
          unawaited(_executeRpnCommand(forceNumeric ? 'approx' : 'DUP'));
        }
      },
      onBackspace: () => _inputBar.backspaceAtCursor(),
      onExecuteRpn: (cmd) => unawaited(_executeRpnCommand(cmd)),
    );

    workspace
      ..append(_scrollView.element)
      ..append(_rpnView.element)
      ..append(_inputBar.element)
      ..append(_keypad.element);
  }

  Future<void> _handleSubmit(
    String rawInput, {
    required bool forceNumeric,
  }) async {
    CalcPersistence.triggerHaptic(
      enabled: _client.environment.settings.haptics,
    );
    if (_mode == CalcMode.rpn) {
      final line = forceNumeric ? '$rawInput approx' : rawInput;
      final err = await _client.evaluateRpnLine(line);
      if (err != null) {
        _showToast('Error: ${err.message}');
      }
    } else {
      await _client.evaluateScroll(rawInput, forceNumeric: forceNumeric);
    }
    _inputBar.focus();
  }

  Future<void> _handleRpnImmediateOperator(String opChar) async {
    final pending = _inputBar.value.trim();
    _inputBar.value = '';
    final line = pending.isEmpty ? opChar : '$pending $opChar';
    final err = await _client.evaluateRpnLine(line);
    if (err != null) {
      _showToast('Error: ${err.message}');
    }
  }

  Future<void> _executeRpnCommand(String cmd) async {
    CalcPersistence.triggerHaptic(
      enabled: _client.environment.settings.haptics,
    );
    final pending = _inputBar.value.trim();
    if (pending.isNotEmpty) {
      _inputBar.value = '';
      final errPush = await _client.evaluateRpnLine(pending);
      if (errPush != null) {
        _showToast('Error: ${errPush.message}');
        return;
      }
    }
    final err = await _client.executeRpnCommand(cmd);
    if (err != null) {
      _showToast('Error: ${err.message}');
    }
  }

  void _setMode(CalcMode newMode) {
    _mode = newMode;
    CalcPersistence.saveMode(_mode);
    // If switching to RPN with an empty stack and existing Scroll results, seed Level 1:
    if (_mode == CalcMode.rpn &&
        _client.stack.isEmpty &&
        _client.session.activeCells.isNotEmpty) {
      final last = _client.session.activeCells.last;
      unawaited(_client.evaluateRpnLine('r[${last.id}]'));
    }
    _refreshAllUi();
    _inputBar.focus();
  }

  void _onStateUpdated() {
    CalcPersistence.saveState(_client.exportSnapshot());
    _refreshAllUi();
  }

  void _refreshAllUi() {
    final settings = _client.environment.settings;

    // Mode toggle pills
    _modeScrollBtn.className = _mode == CalcMode.scroll
        ? 'calc-mode-btn active'
        : 'calc-mode-btn';
    _modeRpnBtn.className = _mode == CalcMode.rpn
        ? 'calc-mode-btn active'
        : 'calc-mode-btn';

    if (_mode == CalcMode.scroll) {
      _scrollView.element.classList.remove('hidden');
      _rpnView.element.classList.add('hidden');
    } else {
      _scrollView.element.classList.add('hidden');
      _rpnView.element.classList.remove('hidden');
    }

    // Status pills
    _anglePill.textContent = settings.angleMode.name.toUpperCase();
    _exactPill.textContent = settings.approxMode
        ? 'APPROX (${settings.digits})'
        : 'EXACT';
    _domainPill.textContent = switch (settings.domain) {
      VariableDomain.unknown => 'x ∈ ℂ/ℝ',
      VariableDomain.real => 'x ∈ ℝ',
      VariableDomain.positive => 'x > 0',
      VariableDomain.integer => 'x ∈ ℤ',
      VariableDomain.complex => 'x ∈ ℂ',
    };
    final symCount =
        _client.environment.variables.length +
        _client.environment.functions.length;
    _varsPill.textContent = 'VARS ($symCount)';

    // Views
    _scrollView.render(session: _client.session, digits: settings.digits);
    _rpnView.render(
      stack: _client.stack,
      environment: _client.environment,
      session: _client.session,
    );
    _inputBar.updatePrompt(mode: _mode, nextId: _client.session.nextId);
    _keypad.setVisible(settings.keypadVisible, mode: _mode);
  }

  void _renderVarsDrawer() {
    _varsDrawer.innerHTML = ''.toJS;
    final header = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-popover-header';
    final title = web.document.createElement('strong') as web.HTMLElement
      ..textContent = 'Assigned Variables & Functions';
    final clearAllBtn =
        web.document.createElement('button') as web.HTMLButtonElement
          ..type = 'button'
          ..className = 'calc-chip-btn calc-chip-secondary'
          ..textContent = 'Clear All';
    clearAllBtn.addEventListener(
      'click',
      ((web.Event _) {
        _varsDrawer.classList.add('hidden');
        unawaited(_handleSubmit('clearall()', forceNumeric: false));
      }).toJS,
    );
    header
      ..append(title)
      ..append(clearAllBtn);
    _varsDrawer.append(header);

    final vars = _client.environment.variables;
    final fns = _client.environment.functions;
    if (vars.isEmpty && fns.isEmpty) {
      final empty = web.document.createElement('p') as web.HTMLParagraphElement
        ..className = 'calc-popover-empty'
        ..textContent = 'No symbols defined. Use "a := 5" or "f(x) := x^2".';
      _varsDrawer.append(empty);
      return;
    }

    for (final entry in vars.entries) {
      final row = web.document.createElement('div') as web.HTMLDivElement
        ..className = 'calc-var-row';
      final insertBtn =
          web.document.createElement('button') as web.HTMLButtonElement
            ..type = 'button'
            ..className = 'calc-var-insert'
            ..textContent = '${entry.key} := ${entry.value.toCanonicalText()}';
      insertBtn.addEventListener(
        'click',
        ((web.Event _) {
          _varsDrawer.classList.add('hidden');
          _inputBar.insertAtCursor(entry.key);
        }).toJS,
      );
      final delBtn =
          web.document.createElement('button') as web.HTMLButtonElement
            ..type = 'button'
            ..className = 'calc-cell-icon-btn'
            ..textContent = '✕';
      delBtn.addEventListener(
        'click',
        ((web.Event _) {
          unawaited(_handleSubmit('clear(${entry.key})', forceNumeric: false));
          _renderVarsDrawer();
        }).toJS,
      );
      row
        ..append(insertBtn)
        ..append(delBtn);
      _varsDrawer.append(row);
    }

    for (final fn in fns.values) {
      final row = web.document.createElement('div') as web.HTMLDivElement
        ..className = 'calc-var-row';
      final insertBtn =
          web.document.createElement('button') as web.HTMLButtonElement
            ..type = 'button'
            ..className = 'calc-var-insert'
            ..textContent = '${fn.signature} := ${fn.sourceText}';
      insertBtn.addEventListener(
        'click',
        ((web.Event _) {
          _varsDrawer.classList.add('hidden');
          _inputBar.insertAtCursor('${fn.name}()', cursorBack: 1);
        }).toJS,
      );
      final delBtn =
          web.document.createElement('button') as web.HTMLButtonElement
            ..type = 'button'
            ..className = 'calc-cell-icon-btn'
            ..textContent = '✕';
      delBtn.addEventListener(
        'click',
        ((web.Event _) {
          unawaited(_handleSubmit('clear(${fn.name})', forceNumeric: false));
          _renderVarsDrawer();
        }).toJS,
      );
      row
        ..append(insertBtn)
        ..append(delBtn);
      _varsDrawer.append(row);
    }
  }

  void _renderSettingsPopover() {
    _settingsPopover.innerHTML = ''.toJS;
    final s = _client.environment.settings;

    web.HTMLElement toggleRow(
      String label,
      bool current,
      void Function(bool) onChanged,
    ) {
      final row = web.document.createElement('label') as web.HTMLLabelElement
        ..className = 'calc-setting-row';
      final span = web.document.createElement('span') as web.HTMLSpanElement
        ..textContent = label;
      final cb = web.document.createElement('input') as web.HTMLInputElement
        ..type = 'checkbox'
        ..checked = current;
      cb.addEventListener(
        'change',
        ((web.Event _) => onChanged(cb.checked)).toJS,
      );
      row
        ..append(span)
        ..append(cb);
      return row;
    }

    _settingsPopover
      ..append(
        toggleRow(
          'Auto-simplify results',
          s.autoSimplify,
          (v) => unawaited(_client.updateSettings(s.copyWith(autoSimplify: v))),
        ),
      )
      ..append(
        toggleRow(
          'Implicit multiplication (2x)',
          s.implicitMultiplication,
          (v) => unawaited(
            _client.updateSettings(s.copyWith(implicitMultiplication: v)),
          ),
        ),
      )
      ..append(
        toggleRow(
          'Approximate mode (≈)',
          s.approxMode,
          (v) => unawaited(_client.updateSettings(s.copyWith(approxMode: v))),
        ),
      )
      ..append(
        toggleRow(
          'Polar complex display (r·e^iθ)',
          s.complexDisplay == ComplexDisplayMode.polar,
          (v) => unawaited(
            _client.updateSettings(
              s.copyWith(
                complexDisplay: v
                    ? ComplexDisplayMode.polar
                    : ComplexDisplayMode.rect,
              ),
            ),
          ),
        ),
      )
      ..append(
        toggleRow(
          'Show virtual keypad',
          s.keypadVisible,
          (v) =>
              unawaited(_client.updateSettings(s.copyWith(keypadVisible: v))),
        ),
      );

    // Session actions: Share Link, Export JSON, Import JSON, Reset Session
    final actionsDiv = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-setting-actions';

    final shareBtn =
        web.document.createElement('button') as web.HTMLButtonElement
          ..type = 'button'
          ..className = 'calc-chip-btn'
          ..textContent = '🔗 Share Link';
    shareBtn.addEventListener(
      'click',
      ((web.Event _) {
        final url = CalcPersistence.buildShareUrl(_client.exportSnapshot());
        CalcPersistence.copyToClipboard(
          url,
          onCopied: () => _showToast('Shareable #calc= link copied!'),
        );
        _settingsPopover.classList.add('hidden');
      }).toJS,
    );

    final exportBtn =
        web.document.createElement('button') as web.HTMLButtonElement
          ..type = 'button'
          ..className = 'calc-chip-btn'
          ..textContent = '⬇ Export JSON';
    exportBtn.addEventListener(
      'click',
      ((web.Event _) {
        CalcPersistence.downloadSessionJson(_client.exportSnapshot());
        _settingsPopover.classList.add('hidden');
      }).toJS,
    );

    final importBtn =
        web.document.createElement('button') as web.HTMLButtonElement
          ..type = 'button'
          ..className = 'calc-chip-btn'
          ..textContent = '⬆ Import JSON';
    importBtn.addEventListener(
      'click',
      ((web.Event _) {
        final fileInput =
            web.document.createElement('input') as web.HTMLInputElement
              ..type = 'file'
              ..accept = '.json';
        fileInput.addEventListener(
          'change',
          ((web.Event _) {
            final files = fileInput.files;
            if (files != null && files.length > 0) {
              final file = files.item(0)!;
              final reader = web.FileReader();
              reader.onload = ((web.Event _) {
                try {
                  final raw = (reader.result as JSString).toDart;
                  final map = (jsonDecode(raw) as Map).cast<String, Object?>();
                  unawaited(_client.loadSnapshot(map));
                  _showToast('Imported session JSON');
                } catch (_) {
                  _showToast('Invalid session JSON file');
                }
              }).toJS;
              reader.readAsText(file);
            }
          }).toJS,
        );
        fileInput.click();
        _settingsPopover.classList.add('hidden');
      }).toJS,
    );

    final resetBtn =
        web.document.createElement('button') as web.HTMLButtonElement
          ..type = 'button'
          ..className = 'calc-chip-btn calc-btn-danger-outline'
          ..textContent = '🗑 Reset Session';
    resetBtn.addEventListener(
      'click',
      ((web.Event _) {
        _settingsPopover.classList.add('hidden');
        unawaited(_clearSession());
      }).toJS,
    );

    actionsDiv
      ..append(shareBtn)
      ..append(exportBtn)
      ..append(importBtn)
      ..append(resetBtn);
    _settingsPopover.append(actionsDiv);
  }

  void _openCommandPalette() {
    CommandPaletteModal.open(
      environment: _client.environment,
      session: _client.session,
      onSelect: (snippet, {required executeImmediately}) {
        if (executeImmediately) {
          unawaited(_handleSubmit(snippet, forceNumeric: false));
        } else {
          final back = snippet.endsWith('(') ? 0 : 0;
          _inputBar.insertAtCursor(snippet, cursorBack: back);
        }
      },
    );
  }

  Future<void> _clearSession() async {
    CalcPersistence.clearSavedState();
    await _client.resetAll();
    _showToast('Session cleared');
  }

  void _showToast(String message) {
    _toastEl.textContent = message;
    _toastEl.classList.remove('hidden');
    web.window.setTimeout(
      (() {
        _toastEl.classList.add('hidden');
      }).toJS,
      2400.toJS,
    );
  }
}
