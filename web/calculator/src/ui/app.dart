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
import 'matrix_editor.dart';
import 'palette.dart';
import 'persistence.dart';
import 'rpn_view.dart';
import 'scroll_view.dart';
import 'shortcuts.dart';

enum _SidePanelTab { vars, settings, help }

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
  late final MatrixBuilderPanel _matrixPanel;
  late final VirtualKeypad _keypad;

  late final web.HTMLButtonElement _modeScrollBtn;
  late final web.HTMLButtonElement _modeRpnBtn;
  late final web.HTMLButtonElement _undoBtn;
  late final web.HTMLButtonElement _redoBtn;
  late final web.HTMLButtonElement _varsBtn;
  late final web.HTMLButtonElement _settingsBtn;
  late final web.HTMLButtonElement _helpBtn;
  late final web.HTMLDivElement _sidePanel;
  late final web.HTMLDivElement _toastEl;
  _SidePanelTab? _activePanel;

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

    GlobalShortcuts.register(
      onOpenPalette: _openCommandPalette,
      onToggleMode: () =>
          _setMode(_mode == CalcMode.scroll ? CalcMode.rpn : CalcMode.scroll),
      onUndo: () => unawaited(_client.undo()),
      onRedo: () => unawaited(_client.redo()),
      onOpenHelp: () => _toggleSidePanel(_SidePanelTab.help),
      onClearView: () => unawaited(_clearSession()),
      onFunctionKey: (fKey) {
        if (_mode != CalcMode.rpn) return false;
        final cmd = switch (fKey) {
          'F1' => 'SWAP',
          'F2' => 'DUP',
          'F3' => 'DROP',
          'F4' => 'OVER',
          'F5' => 'ROT',
          'F6' => 'CLEAR',
          _ => null,
        };
        if (cmd != null) {
          unawaited(_executeRpnCommand(cmd));
          return true;
        }
        return false;
      },
    );

    _refreshAllUi();
    if (web.window.matchMedia('(pointer: fine)').matches) {
      _inputBar.focus();
    }
  }

  void _bindHeaderControls() {
    _modeScrollBtn =
        web.document.getElementById('mode-scroll-btn')!
            as web.HTMLButtonElement;
    _modeRpnBtn =
        web.document.getElementById('mode-rpn-btn')! as web.HTMLButtonElement;
    _undoBtn =
        web.document.getElementById('btn-undo')! as web.HTMLButtonElement;
    _redoBtn =
        web.document.getElementById('btn-redo')! as web.HTMLButtonElement;
    _varsBtn =
        web.document.getElementById('btn-vars')! as web.HTMLButtonElement;
    _settingsBtn =
        web.document.getElementById('btn-settings')! as web.HTMLButtonElement;
    _helpBtn =
        web.document.getElementById('btn-help')! as web.HTMLButtonElement;
    _sidePanel =
        web.document.getElementById('calc-side-panel')! as web.HTMLDivElement;
    _toastEl = web.document.getElementById('calc-toast')! as web.HTMLDivElement;

    _modeScrollBtn.addEventListener(
      'click',
      ((web.Event _) => _setMode(CalcMode.scroll)).toJS,
    );
    _modeRpnBtn.addEventListener(
      'click',
      ((web.Event _) => _setMode(CalcMode.rpn)).toJS,
    );
    _undoBtn.addEventListener(
      'click',
      ((web.Event _) => unawaited(_client.undo())).toJS,
    );
    _redoBtn.addEventListener(
      'click',
      ((web.Event _) => unawaited(_client.redo())).toJS,
    );

    final paletteBtn =
        web.document.getElementById('btn-palette')! as web.HTMLButtonElement;
    paletteBtn.addEventListener(
      'click',
      ((web.Event _) => _openCommandPalette()).toJS,
    );

    _varsBtn.addEventListener(
      'click',
      ((web.Event _) => _toggleSidePanel(_SidePanelTab.vars)).toJS,
    );
    _settingsBtn.addEventListener(
      'click',
      ((web.Event _) => _toggleSidePanel(_SidePanelTab.settings)).toJS,
    );
    _helpBtn.addEventListener(
      'click',
      ((web.Event _) => _toggleSidePanel(_SidePanelTab.help)).toJS,
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
      onPushToStack: (cellId) {
        unawaited(
          _client.pushCellToStack(cellId).then((_) {
            _setMode(CalcMode.rpn);
            _showToast('Pushed r[$cellId] to RPN stack');
          }),
        );
      },
    );

    _rpnView = RpnStackView(
      onExecuteRpnCommand: (cmd) => unawaited(_executeRpnCommand(cmd)),
      onInsertText: (snippet) => _inputBar.insertAtCursor(snippet),
      onQuickStartSelect: (line) =>
          unawaited(_handleSubmit(line, forceNumeric: false)),
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
          'Approx' => 'approx',
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
      onToggleMatrixBuilder: () => _matrixPanel.toggle(),
      onToggleKeypad: () {
        final cur = _client.environment.settings;
        final next = !cur.keypadVisible;
        if (next) {
          _inputBar.setKeypadActive(true);
          _inputBar.textarea.blur();
          _inputBar.textarea.focus();
        } else {
          _inputBar.setKeypadActive(false);
        }
        unawaited(_client.updateSettings(cur.copyWith(keypadVisible: next)));
      },
      getMode: () => _mode,
      getEnvironment: () => _client.environment,
      getSession: () => _client.session,
    );

    _matrixPanel = MatrixBuilderPanel(
      onInsert: (text) => _inputBar.insertAtCursor(text),
      onVisibilityChanged: (visible) =>
          _inputBar.setMatrixBuilderActive(visible),
    );

    _keypad = VirtualKeypad(
      onInsert: (text, {cursorBack = 0}) =>
          _inputBar.insertAtCursor(text, cursorBack: cursorBack),
      onBackspace: () => _inputBar.backspaceAtCursor(),
      onExecuteRpn: (cmd) => unawaited(_executeRpnCommand(cmd)),
      onToggleMatrixBuilder: () => _matrixPanel.toggle(),
      isInsideCompoundLiteral: () => _inputBar.isInsideCompoundLiteral,
    );

    workspace
      ..append(_scrollView.element)
      ..append(_rpnView.element)
      ..append(_inputBar.element)
      ..append(_matrixPanel.element)
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
      final err = await _client.evaluateRpnLine(
        rawInput,
        forceNumeric: forceNumeric,
      );
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
    _refreshAllUi();
    if (web.window.matchMedia('(pointer: fine)').matches) {
      _inputBar.focus();
    }
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

    _undoBtn.disabled = !_client.canUndo;
    _redoBtn.disabled = !_client.canRedo;

    final symCount =
        _client.environment.variables.length +
        _client.environment.functions.length;
    _varsBtn.title = 'Assigned Variables & Functions ($symCount)';

    // Views
    _scrollView.render(session: _client.session, digits: settings.digits);
    _rpnView.render(
      stack: _client.stack,
      environment: _client.environment,
      session: _client.session,
    );
    _inputBar.updatePrompt(mode: _mode, nextId: _client.session.nextId);
    _keypad.setVisible(settings.keypadVisible, mode: _mode);
    _inputBar.setKeypadActive(settings.keypadVisible);

    if (_activePanel == _SidePanelTab.vars ||
        _activePanel == _SidePanelTab.settings) {
      _renderSidePanel();
    }
  }

  void _toggleSidePanel(_SidePanelTab tab) {
    if (_activePanel == tab) {
      _closeSidePanel();
    } else {
      _activePanel = tab;
      _updateSidePanelButtons();
      _renderSidePanel();
      _sidePanel.classList.remove('hidden');
    }
  }

  void _closeSidePanel() {
    _activePanel = null;
    _updateSidePanelButtons();
    _sidePanel.classList.add('hidden');
  }

  void _updateSidePanelButtons() {
    _varsBtn.classList.toggle('active', _activePanel == _SidePanelTab.vars);
    _settingsBtn.classList.toggle(
      'active',
      _activePanel == _SidePanelTab.settings,
    );
    _helpBtn.classList.toggle('active', _activePanel == _SidePanelTab.help);
  }

  void _renderSidePanel() {
    final tab = _activePanel;
    if (tab == null) return;
    _sidePanel.innerHTML = ''.toJS;

    final body = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-side-panel-body';

    switch (tab) {
      case _SidePanelTab.vars:
        _renderVarsPanel(body);
      case _SidePanelTab.settings:
        _renderSettingsPanel(body);
      case _SidePanelTab.help:
        HelpPanel.render(
          body,
          onRunExample: (ex) {
            if (web.window.matchMedia('(max-width: 768px)').matches) {
              _closeSidePanel();
            }
            unawaited(_handleSubmit(ex, forceNumeric: false));
          },
        );
    }

    _sidePanel.append(body);
  }

  void _renderVarsPanel(web.HTMLDivElement container) {
    final settings = _client.environment.settings;

    // 1. Default Variable Domain selector
    final domainSec = web.document.createElement('section')
      ..className = 'calc-panel-section';
    final domainTitle = web.document.createElement('h4')
      ..className = 'calc-panel-section-title'
      ..textContent = 'Default Domain';
    final domainGroup = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-domain-pills';
    const domainOptions = [
      (domain: VariableDomain.unknown, label: 'Any', title: 'Unknown (ℂ / ℝ)'),
      (domain: VariableDomain.real, label: 'ℝ', title: 'Real (∈ ℝ)'),
      (domain: VariableDomain.positive, label: '> 0', title: 'Positive (> 0)'),
      (domain: VariableDomain.integer, label: 'ℤ', title: 'Integer (∈ ℤ)'),
      (domain: VariableDomain.complex, label: 'ℂ', title: 'Complex (∈ ℂ)'),
    ];
    for (final opt in domainOptions) {
      final btn = web.document.createElement('button') as web.HTMLButtonElement
        ..type = 'button'
        ..className = settings.domain == opt.domain
            ? 'calc-domain-pill active'
            : 'calc-domain-pill'
        ..textContent = opt.label
        ..title = opt.title;
      btn.addEventListener(
        'click',
        ((web.Event _) => unawaited(
          _client.updateSettings(settings.copyWith(domain: opt.domain)),
        )).toJS,
      );
      domainGroup.append(btn);
    }
    domainSec
      ..append(domainTitle)
      ..append(domainGroup);
    container.append(domainSec);

    // 2. Per-Variable Domain Assumptions
    final varDomainSec = web.document.createElement('section')
      ..className = 'calc-panel-section';
    final varDomainHeader =
        web.document.createElement('div') as web.HTMLDivElement
          ..className = 'calc-panel-section-header';
    final varDomainTitle = web.document.createElement('h4')
      ..className = 'calc-panel-section-title'
      ..textContent = 'Variable Domains';
    varDomainHeader.append(varDomainTitle);

    final varDomains = settings.variableDomains;
    if (varDomains.isNotEmpty) {
      final clearDomainsBtn =
          web.document.createElement('button') as web.HTMLButtonElement
            ..type = 'button'
            ..className = 'calc-text-btn calc-text-btn-danger'
            ..textContent = 'Clear All';
      clearDomainsBtn.addEventListener(
        'click',
        ((web.Event _) => unawaited(
          _client.updateSettings(settings.copyWith(variableDomains: const {})),
        )).toJS,
      );
      varDomainHeader.append(clearDomainsBtn);
    }
    varDomainSec.append(varDomainHeader);

    final varDomainForm =
        web.document.createElement('form') as web.HTMLFormElement
          ..className = 'calc-var-define-form';
    final varNameInput =
        web.document.createElement('input') as web.HTMLInputElement
          ..type = 'text'
          ..className = 'calc-var-define-input calc-var-name-input'
          ..placeholder = 'var (e.g. x, n)'
          ..autocomplete = 'off'
          ..spellcheck = false;
    final domainSelect =
        web.document.createElement('select') as web.HTMLSelectElement
          ..className = 'calc-domain-select'
          ..title = 'Domain';
    for (final opt in const [
      (domain: VariableDomain.real, label: '∈ ℝ'),
      (domain: VariableDomain.positive, label: '> 0'),
      (domain: VariableDomain.integer, label: '∈ ℤ'),
      (domain: VariableDomain.complex, label: '∈ ℂ'),
    ]) {
      final option =
          web.document.createElement('option') as web.HTMLOptionElement
            ..value = opt.domain.name
            ..textContent = opt.label;
      domainSelect.append(option);
    }
    final setDomainBtn =
        web.document.createElement('button') as web.HTMLButtonElement
          ..type = 'submit'
          ..className = 'calc-btn-primary calc-var-define-btn'
          ..textContent = 'Set';
    varDomainForm.addEventListener(
      'submit',
      ((web.Event e) {
        e.preventDefault();
        final name = varNameInput.value.trim();
        if (name.isEmpty) return;
        final chosen = VariableDomain.values.firstWhere(
          (d) => d.name == domainSelect.value,
          orElse: () => VariableDomain.real,
        );
        final nextMap = Map<String, VariableDomain>.from(varDomains)
          ..[name] = chosen;
        varNameInput.value = '';
        unawaited(
          _client.updateSettings(settings.copyWith(variableDomains: nextMap)),
        );
      }).toJS,
    );
    varDomainForm
      ..append(varNameInput)
      ..append(domainSelect)
      ..append(setDomainBtn);
    varDomainSec.append(varDomainForm);

    for (final entry in varDomains.entries) {
      final row = web.document.createElement('div') as web.HTMLDivElement
        ..className = 'calc-var-row';
      final domainLabel = switch (entry.value) {
        VariableDomain.real => '∈ ℝ',
        VariableDomain.positive => '> 0',
        VariableDomain.integer => '∈ ℤ',
        VariableDomain.complex => '∈ ℂ',
        VariableDomain.unknown => 'Any',
      };
      final cycleBtn =
          web.document.createElement('button') as web.HTMLButtonElement
            ..type = 'button'
            ..className = 'calc-var-insert'
            ..title = 'Click to cycle domain for ${entry.key}'
            ..textContent = '${entry.key} $domainLabel';
      cycleBtn.addEventListener(
        'click',
        ((web.Event _) {
          final nextDomain = switch (entry.value) {
            VariableDomain.real => VariableDomain.positive,
            VariableDomain.positive => VariableDomain.integer,
            VariableDomain.integer => VariableDomain.complex,
            VariableDomain.complex => VariableDomain.real,
            VariableDomain.unknown => VariableDomain.real,
          };
          final nextMap = Map<String, VariableDomain>.from(varDomains)
            ..[entry.key] = nextDomain;
          unawaited(
            _client.updateSettings(settings.copyWith(variableDomains: nextMap)),
          );
        }).toJS,
      );
      final delBtn =
          web.document.createElement('button') as web.HTMLButtonElement
            ..type = 'button'
            ..className = 'calc-cell-icon-btn'
            ..title = 'Remove domain for ${entry.key}'
            ..textContent = '✕';
      delBtn.addEventListener(
        'click',
        ((web.Event _) {
          final nextMap = Map<String, VariableDomain>.from(varDomains)
            ..remove(entry.key);
          unawaited(
            _client.updateSettings(settings.copyWith(variableDomains: nextMap)),
          );
        }).toJS,
      );
      row
        ..append(cycleBtn)
        ..append(delBtn);
      varDomainSec.append(row);
    }
    container.append(varDomainSec);

    // 3. Variables & Functions (define form + defined symbols list)
    final vars = _client.environment.variables;
    final fns = _client.environment.functions;
    final symbolsSec = web.document.createElement('section')
      ..className = 'calc-panel-section';
    final symbolsHeader =
        web.document.createElement('div') as web.HTMLDivElement
          ..className = 'calc-panel-section-header';
    final symbolsTitle = web.document.createElement('h4')
      ..className = 'calc-panel-section-title'
      ..textContent = 'Variables & Functions';
    symbolsHeader.append(symbolsTitle);

    if (vars.isNotEmpty || fns.isNotEmpty) {
      final clearAllBtn =
          web.document.createElement('button') as web.HTMLButtonElement
            ..type = 'button'
            ..className = 'calc-text-btn calc-text-btn-danger'
            ..textContent = 'Clear All';
      clearAllBtn.addEventListener(
        'click',
        ((web.Event _) => unawaited(_client.clearAllSymbols())).toJS,
      );
      symbolsHeader.append(clearAllBtn);
    }
    symbolsSec.append(symbolsHeader);

    final defineForm = web.document.createElement('form') as web.HTMLFormElement
      ..className = 'calc-var-define-form';
    final defineInput =
        web.document.createElement('input') as web.HTMLInputElement
          ..type = 'text'
          ..className = 'calc-var-define-input'
          ..placeholder = 'a := 5  or  f(x) := x^2'
          ..autocomplete = 'off'
          ..spellcheck = false;
    final defineBtn =
        web.document.createElement('button') as web.HTMLButtonElement
          ..type = 'submit'
          ..className = 'calc-btn-primary calc-var-define-btn'
          ..textContent = 'Add';
    defineForm.addEventListener(
      'submit',
      ((web.Event e) {
        e.preventDefault();
        final text = defineInput.value.trim();
        if (text.isEmpty) return;
        unawaited(
          _client.defineSymbol(text).then((err) {
            if (err != null) {
              _showToast(err.message);
            } else {
              defineInput.value = '';
            }
          }),
        );
      }).toJS,
    );
    defineForm
      ..append(defineInput)
      ..append(defineBtn);
    symbolsSec.append(defineForm);

    if (vars.isEmpty && fns.isEmpty) {
      final empty = web.document.createElement('p') as web.HTMLParagraphElement
        ..className = 'calc-side-panel-empty'
        ..textContent = 'No variables or functions defined yet.';
      symbolsSec.append(empty);
      container.append(symbolsSec);
      return;
    }

    for (final entry in vars.entries) {
      final row = web.document.createElement('div') as web.HTMLDivElement
        ..className = 'calc-var-row';
      final insertBtn =
          web.document.createElement('button') as web.HTMLButtonElement
            ..type = 'button'
            ..className = 'calc-var-insert'
            ..title = 'Insert ${entry.key}'
            ..textContent = '${entry.key} := ${entry.value.toCanonicalText()}';
      insertBtn.addEventListener(
        'click',
        ((web.Event _) {
          if (web.window.matchMedia('(max-width: 768px)').matches) {
            _closeSidePanel();
          }
          _inputBar.insertAtCursor(entry.key);
        }).toJS,
      );
      final delBtn =
          web.document.createElement('button') as web.HTMLButtonElement
            ..type = 'button'
            ..className = 'calc-cell-icon-btn'
            ..title = 'Remove ${entry.key}'
            ..textContent = '✕';
      delBtn.addEventListener(
        'click',
        ((web.Event _) => unawaited(_client.clearSymbol(entry.key))).toJS,
      );
      row
        ..append(insertBtn)
        ..append(delBtn);
      symbolsSec.append(row);
    }

    for (final fn in fns.values) {
      final row = web.document.createElement('div') as web.HTMLDivElement
        ..className = 'calc-var-row';
      final insertBtn =
          web.document.createElement('button') as web.HTMLButtonElement
            ..type = 'button'
            ..className = 'calc-var-insert'
            ..title = 'Insert ${fn.name}()'
            ..textContent = '${fn.signature} := ${fn.sourceText}';
      insertBtn.addEventListener(
        'click',
        ((web.Event _) {
          if (web.window.matchMedia('(max-width: 768px)').matches) {
            _closeSidePanel();
          }
          _inputBar.insertAtCursor('${fn.name}()', cursorBack: 1);
        }).toJS,
      );
      final delBtn =
          web.document.createElement('button') as web.HTMLButtonElement
            ..type = 'button'
            ..className = 'calc-cell-icon-btn'
            ..title = 'Remove ${fn.name}'
            ..textContent = '✕';
      delBtn.addEventListener(
        'click',
        ((web.Event _) => unawaited(_client.clearSymbol(fn.name))).toJS,
      );
      row
        ..append(insertBtn)
        ..append(delBtn);
      symbolsSec.append(row);
    }
    container.append(symbolsSec);
  }

  void _renderSettingsPanel(web.HTMLDivElement container) {
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

    final evalSec = web.document.createElement('section')
      ..className = 'calc-panel-section';
    final evalTitle = web.document.createElement('h4')
      ..className = 'calc-panel-section-title'
      ..textContent = 'Evaluation & Display';

    evalSec
      ..append(evalTitle)
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
      );
    container.append(evalSec);

    final sessionSec = web.document.createElement('section')
      ..className = 'calc-panel-section';
    final sessionTitle = web.document.createElement('h4')
      ..className = 'calc-panel-section-title'
      ..textContent = 'Session';
    sessionSec.append(sessionTitle);

    web.HTMLButtonElement actionCard(
      String title,
      String description,
      void Function() onClick, {
      bool danger = false,
    }) {
      final btn = web.document.createElement('button') as web.HTMLButtonElement
        ..type = 'button'
        ..className = danger
            ? 'calc-action-card calc-action-card-danger'
            : 'calc-action-card';
      final titleEl = web.document.createElement('span') as web.HTMLSpanElement
        ..className = 'calc-action-card-title'
        ..textContent = title;
      final descEl = web.document.createElement('span') as web.HTMLSpanElement
        ..className = 'calc-action-card-desc'
        ..textContent = description;
      btn
        ..append(titleEl)
        ..append(descEl)
        ..addEventListener('click', ((web.Event _) => onClick()).toJS);
      return btn;
    }

    final actionsDiv = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-setting-actions';

    actionsDiv
      ..append(
        actionCard(
          'Copy Share Link',
          'Copy a URL containing the current worksheet and symbols',
          () {
            final url = CalcPersistence.buildShareUrl(_client.exportSnapshot());
            CalcPersistence.copyToClipboard(
              url,
              onCopied: () => _showToast('Shareable #calc= link copied!'),
            );
          },
        ),
      )
      ..append(
        actionCard(
          'Export Session JSON',
          'Download history, stack, and definitions as a file',
          () => CalcPersistence.downloadSessionJson(_client.exportSnapshot()),
        ),
      )
      ..append(
        actionCard(
          'Import Session JSON',
          'Restore a previously exported session file',
          () {
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
                      final map = (jsonDecode(raw) as Map)
                          .cast<String, Object?>();
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
          },
        ),
      )
      ..append(
        actionCard(
          'Reset Session',
          'Clear all cells, RPN stack, and defined symbols',
          () => unawaited(_clearSession()),
          danger: true,
        ),
      );

    sessionSec.append(actionsDiv);
    container.append(sessionSec);
  }

  void _openCommandPalette() {
    CommandPaletteModal.open(
      mode: _mode,
      environment: _client.environment,
      session: _client.session,
      onSelect: (snippet, {required executeImmediately}) {
        if (executeImmediately) {
          if (_mode == CalcMode.rpn) {
            unawaited(_executeRpnCommand(snippet));
          } else {
            unawaited(_handleSubmit(snippet, forceNumeric: false));
          }
        } else {
          _inputBar.insertAtCursor(snippet);
        }
      },
    );
  }

  Future<void> _clearSession() async {
    CalcPersistence.clearSavedState();
    await _client.resetAll();
    _showToast('Session cleared');
  }

  int? _toastTimerId;

  void _showToast(String message) {
    if (_toastTimerId != null) {
      web.window.clearTimeout(_toastTimerId!);
    }
    _toastEl.textContent = message;
    _toastEl.classList.remove('hidden');
    _toastTimerId = web.window.setTimeout(
      (() {
        _toastTimerId = null;
        _toastEl.classList.add('hidden');
      }).toJS,
      2400.toJS,
    );
  }
}
