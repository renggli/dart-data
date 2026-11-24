import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../engine/commands.dart';
import '../model/value.dart';

/// Builds contextual math action chips strictly for the currently focused
/// math cell.
final class ActionChips {
  const new _();

  static web.HTMLDivElement build(
    String inputSource,
    CalcValue? value,
    CommandRegistry registry,
    void Function(String newCall) onApply,
  ) {
    final row = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-contextual-chips';

    if (value == null || inputSource.trim().isEmpty) {
      return row;
    }

    for (final cmd in registry.all) {
      if (cmd.chipLabel == null || cmd.appliesTo == null) continue;
      if (!cmd.appliesTo!(value)) continue;
      final call = cmd.buildChipCall?.call(inputSource.trim(), value);
      if (call == null) continue;

      final btn =
          (web.document.createElement('button') as web.HTMLButtonElement)
            ..type = 'button'
            ..className = 'nb-chip'
            ..textContent = cmd.chipLabel
            ..title = cmd.doc;
      btn.onmousedown = ((web.MouseEvent e) {
        e.preventDefault();
        onApply(call);
      }).toJS;
      row.append(btn);
    }

    return row;
  }
}
