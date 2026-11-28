import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../../../shared/utils.dart';
import '../model/value.dart';
import 'icons.dart';

/// Interactive control panel rendering one or more [SliderValue] and
/// [InputValue] controls inside a notebook cell output.
///
/// Supports [tryUpdateInPlace] so live slider drags and formula editing
/// preserve pointer capture and cursor focus across automatic reactive updates.
final class ControlView {
  /// Builds interactive control widgets for [initialValue] (`SliderValue`,
  /// `InputValue`, or `ControlGroupValue`).
  new(CalcValue initialValue, {required this.digits, required this.onChanged}) {
    root = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-ctrl-group'
      ..onmousedown = ((web.MouseEvent e) => e.stopPropagation()).toJS
      ..onclick = ((web.MouseEvent e) => e.stopPropagation()).toJS;
    _mountAll(initialValue);
  }

  /// Display precision for numeric slider readouts.
  int digits;

  /// Invoked when the user adjusts or commits a control value (`null` resets).
  final void Function(String key, Object? value, {required bool recordUndo})
  onChanged;

  /// Root container mounted into the cell output slot.
  late final web.HTMLDivElement root;

  final List<_ControlEntry> _entries = [];

  /// Disposes any pending input debounce timers.
  void dispose() {
    for (final entry in _entries) {
      entry.dispose();
    }
    _entries.clear();
  }

  /// Updates existing DOM controls in-place when [nextValue] has the exact same
  /// control structure, returning `false` if a full rebuild is required.
  bool tryUpdateInPlace(CalcValue nextValue, {required int digits}) {
    this.digits = digits;
    final list = _extractControls(nextValue);
    if (list == null || list.length != _entries.length) return false;
    for (var i = 0; i < list.length; i++) {
      if (!_entries[i].canUpdateFrom(list[i])) return false;
    }
    for (var i = 0; i < list.length; i++) {
      _entries[i].updateFrom(list[i], digits: digits);
    }
    return true;
  }

  void _mountAll(CalcValue value) {
    final list = _extractControls(value) ?? const <ControlValue>[];
    for (final ctrl in list) {
      final entry = switch (ctrl) {
        SliderValue() => _SliderEntry(
          ctrl,
          digits: digits,
          onChanged: onChanged,
        ),
        InputValue() => _InputEntry(ctrl, onChanged: onChanged),
      };
      _entries.add(entry);
      root.append(entry.row);
    }
  }

  static List<ControlValue>? _extractControls(CalcValue val) => switch (val) {
    SliderValue() || InputValue() => [val as ControlValue],
    ControlGroupValue(:final controls) => controls,
    _ => null,
  };
}

sealed class _ControlEntry {
  web.HTMLDivElement get row;
  bool canUpdateFrom(ControlValue next);
  void updateFrom(ControlValue next, {required int digits});
  void dispose();
}

final class _SliderEntry implements _ControlEntry {
  new(SliderValue initial, {required int digits, required this.onChanged})
    : _current = initial {
    row = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-ctrl-row nb-ctrl-slider-row';

    final header = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-ctrl-header';

    _labelEl = (web.document.createElement('span') as web.HTMLSpanElement)
      ..className = 'nb-ctrl-label'
      ..textContent = initial.label ?? initial.symbol ?? initial.key;

    final readoutWrap =
        (web.document.createElement('div') as web.HTMLDivElement)
          ..className = 'nb-ctrl-readout-wrap';

    _numberInput = (web.document.createElement('input') as web.HTMLInputElement)
      ..type = 'number'
      ..className = 'custom-number-input nb-ctrl-num'
      ..min = '${initial.min}'
      ..max = '${initial.max}'
      ..step = '${initial.step}'
      ..value = formatRealDigits(initial.value, digits)
      ..setAttribute('aria-label', '${_labelEl.textContent} numeric value');

    _resetBtn = (web.document.createElement('button') as web.HTMLButtonElement)
      ..type = 'button'
      ..className = 'icon-btn nb-ctrl-reset'
      ..title = 'Reset to default (${initial.defaultValue})'
      ..setAttribute('aria-label', 'Reset slider')
      ..innerHTML = NbIcons.undo.toJS;

    readoutWrap
      ..append(_numberInput)
      ..append(_resetBtn);

    header
      ..append(_labelEl)
      ..append(readoutWrap);

    final sliderWrap = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-ctrl-slider-wrap';

    final minEl = (web.document.createElement('span') as web.HTMLSpanElement)
      ..className = 'nb-ctrl-bound'
      ..textContent = PlotValue.fmtBound(initial.min);

    _rangeInput = (web.document.createElement('input') as web.HTMLInputElement)
      ..type = 'range'
      ..className = 'custom-slider nb-ctrl-slider'
      ..min = '${initial.min}'
      ..max = '${initial.max}'
      ..step = '${initial.step}'
      ..value = '${initial.value}'
      ..setAttribute('aria-label', _labelEl.textContent ?? 'Slider');

    final maxEl = (web.document.createElement('span') as web.HTMLSpanElement)
      ..className = 'nb-ctrl-bound'
      ..textContent = PlotValue.fmtBound(initial.max);

    sliderWrap
      ..append(minEl)
      ..append(_rangeInput)
      ..append(maxEl);

    row
      ..append(header)
      ..append(sliderWrap);

    _syncResetVisibility();

    _rangeInput.oninput = ((web.Event _) {
      final parsed = double.tryParse(_rangeInput.value);
      if (parsed == null || !parsed.isFinite) return;
      _numberInput.value = formatRealDigits(parsed, _lastDigits);
      _scheduleLiveUpdate(parsed);
    }).toJS;

    _rangeInput.onchange = ((web.Event _) {
      final parsed = double.tryParse(_rangeInput.value);
      if (parsed == null || !parsed.isFinite) return;
      _rafPending = false;
      onChanged(_current.key, parsed, recordUndo: true);
    }).toJS;

    _numberInput.onchange = ((web.Event _) {
      final parsed = double.tryParse(_numberInput.value);
      if (parsed == null || !parsed.isFinite) {
        _numberInput.value = formatRealDigits(_current.value, _lastDigits);
        return;
      }
      final clamped = parsed.clamp(_current.min, _current.max);
      _rangeInput.value = '$clamped';
      onChanged(_current.key, clamped, recordUndo: true);
    }).toJS;

    _resetBtn.onclick = ((web.MouseEvent e) {
      e.stopPropagation();
      _rangeInput.value = '${_current.defaultValue}';
      _numberInput.value = formatRealDigits(_current.defaultValue, _lastDigits);
      onChanged(_current.key, _current.defaultValue, recordUndo: true);
    }).toJS;

    _lastDigits = digits;
  }

  final void Function(String key, Object? value, {required bool recordUndo})
  onChanged;
  SliderValue _current;
  int _lastDigits = 10;
  bool _rafPending = false;
  double? _queuedValue;

  @override
  late final web.HTMLDivElement row;
  late final web.HTMLSpanElement _labelEl;
  late final web.HTMLInputElement _rangeInput;
  late final web.HTMLInputElement _numberInput;
  late final web.HTMLButtonElement _resetBtn;

  void _scheduleLiveUpdate(double val) {
    _queuedValue = val;
    if (_rafPending) return;
    _rafPending = true;
    web.window.requestAnimationFrame(
      ((num _) {
        _rafPending = false;
        final next = _queuedValue;
        if (next != null) {
          onChanged(_current.key, next, recordUndo: false);
        }
      }).toJS,
    );
  }

  void _syncResetVisibility() {
    final tol = 1e-9 * math.max(1.0, (_current.max - _current.min).abs());
    final atDefault = (_current.value - _current.defaultValue).abs() <= tol;
    setHidden(_resetBtn, atDefault);
  }

  @override
  bool canUpdateFrom(ControlValue next) =>
      next is SliderValue &&
      next.key == _current.key &&
      next.min == _current.min &&
      next.max == _current.max &&
      next.step == _current.step &&
      next.defaultValue == _current.defaultValue;

  @override
  void updateFrom(ControlValue next, {required int digits}) {
    final s = next as SliderValue;
    _current = s;
    _lastDigits = digits;
    _labelEl.textContent = s.label ?? s.symbol ?? s.key;
    if (web.document.activeElement != _rangeInput) {
      _rangeInput.value = '${s.value}';
    }
    if (web.document.activeElement != _numberInput) {
      _numberInput.value = formatRealDigits(s.value, digits);
    }
    _syncResetVisibility();
  }

  @override
  void dispose() {
    _queuedValue = null;
  }
}

final class _InputEntry implements _ControlEntry {
  new(InputValue initial, {required this.onChanged}) : _current = initial {
    row = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-ctrl-row nb-ctrl-input-row';

    final header = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-ctrl-header';

    _labelEl = (web.document.createElement('span') as web.HTMLSpanElement)
      ..className = 'nb-ctrl-label'
      ..textContent = initial.label ?? initial.symbol ?? initial.key;

    _resetBtn = (web.document.createElement('button') as web.HTMLButtonElement)
      ..type = 'button'
      ..className = 'icon-btn nb-ctrl-reset'
      ..title = 'Reset to default (${initial.defaultSource})'
      ..setAttribute('aria-label', 'Reset formula input')
      ..innerHTML = NbIcons.undo.toJS;

    header
      ..append(_labelEl)
      ..append(_resetBtn);

    final body = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-ctrl-input-body';

    _textInput = (web.document.createElement('input') as web.HTMLInputElement)
      ..type = 'text'
      ..className = 'custom-text-input nb-ctrl-input'
      ..value = initial.source
      ..setAttribute('spellcheck', 'false')
      ..setAttribute('autocomplete', 'off')
      ..setAttribute('aria-label', _labelEl.textContent ?? 'Formula input');

    _previewEl = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-ctrl-preview';

    body
      ..append(_textInput)
      ..append(_previewEl);

    row
      ..append(header)
      ..append(body);

    _syncPreview();
    _syncResetVisibility();

    _textInput.oninput = ((web.Event _) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 140), () {
        onChanged(_current.key, _textInput.value, recordUndo: false);
      });
    }).toJS;

    _textInput.onkeydown = ((web.KeyboardEvent e) {
      if (e.key == 'Enter') {
        e.preventDefault();
        _debounceTimer?.cancel();
        onChanged(_current.key, _textInput.value, recordUndo: true);
      } else if (e.key == 'Escape') {
        e.preventDefault();
        _textInput.blur();
      }
    }).toJS;

    _textInput.onblur = ((web.FocusEvent _) {
      _debounceTimer?.cancel();
      if (_textInput.value != _current.source) {
        onChanged(_current.key, _textInput.value, recordUndo: true);
      }
    }).toJS;

    _resetBtn.onclick = ((web.MouseEvent e) {
      e.stopPropagation();
      _debounceTimer?.cancel();
      _textInput.value = _current.defaultSource;
      onChanged(_current.key, null, recordUndo: true);
    }).toJS;
  }

  final void Function(String key, Object? value, {required bool recordUndo})
  onChanged;
  InputValue _current;
  Timer? _debounceTimer;

  @override
  late final web.HTMLDivElement row;
  late final web.HTMLSpanElement _labelEl;
  late final web.HTMLInputElement _textInput;
  late final web.HTMLDivElement _previewEl;
  late final web.HTMLButtonElement _resetBtn;

  void _syncPreview() {
    final val = _current.evaluated;
    if (val is ErrorValue) {
      _previewEl
        ..className = 'nb-ctrl-error'
        ..textContent = val.message;
      _textInput.classList.add('has-error');
    } else {
      _textInput.classList.remove('has-error');
      _previewEl
        ..className = 'nb-ctrl-preview'
        ..innerHTML = val.toMathMl(display: false).toJS;
    }
  }

  void _syncResetVisibility() {
    setHidden(_resetBtn, _current.source == _current.defaultSource);
  }

  @override
  bool canUpdateFrom(ControlValue next) =>
      next is InputValue &&
      next.key == _current.key &&
      next.defaultSource == _current.defaultSource;

  @override
  void updateFrom(ControlValue next, {required int digits}) {
    final inp = next as InputValue;
    _current = inp;
    _labelEl.textContent = inp.label ?? inp.symbol ?? inp.key;
    if (web.document.activeElement != _textInput) {
      _textInput.value = inp.source;
    }
    _syncPreview();
    _syncResetVisibility();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }
}
