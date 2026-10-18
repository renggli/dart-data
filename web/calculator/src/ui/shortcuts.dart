import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Registers global keyboard shortcuts for the Calculator PWA (`Ctrl/Cmd+K`
/// Command Palette, `Ctrl/Cmd+M` Mode Toggle, `Ctrl/Cmd+/` Help Drawer,
/// `Ctrl/Cmd+L` Clear View, `F1`–`F6` RPN Soft Keys).
abstract final class GlobalShortcuts {
  static void register({
    required void Function() onOpenPalette,
    required void Function() onToggleMode,
    required void Function() onOpenHelp,
    required void Function() onClearView,
    required bool Function(String fKey) onFunctionKey,
  }) {
    web.window.addEventListener(
      'keydown',
      ((web.KeyboardEvent e) {
        final mod = e.ctrlKey || e.metaKey;
        if (mod && e.key.toLowerCase() == 'k') {
          e.preventDefault();
          onOpenPalette();
          return;
        }
        if (mod && e.key.toLowerCase() == 'm') {
          e.preventDefault();
          onToggleMode();
          return;
        }
        if (mod && e.key == '/') {
          e.preventDefault();
          onOpenHelp();
          return;
        }
        if (mod && e.key.toLowerCase() == 'l') {
          e.preventDefault();
          onClearView();
          return;
        }
        if (!mod &&
            !e.altKey &&
            const {'F1', 'F2', 'F3', 'F4', 'F5', 'F6'}.contains(e.key)) {
          if (onFunctionKey(e.key)) {
            e.preventDefault();
          }
        }
      }).toJS,
    );
  }
}
