import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../engine/commands.dart';
import '../model/environment.dart';
import '../model/session.dart';

/// Fuzzy command, function, variable, and result search palette (`Ctrl/Cmd+K`).
final class CommandPaletteModal {
  static void open({
    required Environment environment,
    required Session session,
    required void Function(String snippet, {required bool executeImmediately})
    onSelect,
  }) {
    final backdrop = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-modal-backdrop';
    final dialog = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-modal-dialog calc-palette-dialog';

    final searchWrap = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-palette-search-wrap';
    final searchInput =
        web.document.createElement('input') as web.HTMLInputElement
          ..type = 'text'
          ..className = 'calc-palette-input'
          ..placeholder =
              'Search commands, functions, or variables...';
    searchWrap.append(searchInput);

    final listContainer =
        web.document.createElement('div') as web.HTMLDivElement
          ..className = 'calc-palette-list';

    dialog
      ..append(searchWrap)
      ..append(listContainer);
    backdrop.append(dialog);

    var selectedIdx = 0;
    var currentEntries = <_PaletteEntry>[];

    List<_PaletteEntry> buildEntries(String query) {
      final q = query.trim().toLowerCase();
      final all = <_PaletteEntry>[];

      // Session variables & user functions
      for (final entry in environment.variables.entries) {
        all.add(
          _PaletteEntry(
            title: entry.key,
            badge: 'VAR',
            subtitle: '= ${entry.value.toCanonicalText()}',
            snippet: entry.key,
            executeImmediately: false,
          ),
        );
      }
      for (final fn in environment.functions.values) {
        all.add(
          _PaletteEntry(
            title: fn.signature,
            badge: 'FN',
            subtitle: ':= ${fn.sourceText}',
            snippet: '${fn.name}(',
            executeImmediately: false,
          ),
        );
      }

      // Commands
      for (final cmd in CommandRegistry.all) {
        all.add(
          _PaletteEntry(
            title: cmd.signature,
            badge: cmd.category.softMenuLabel,
            subtitle: cmd.doc,
            snippet: '${cmd.name}(',
            executeImmediately: false,
          ),
        );
      }

      if (q.isEmpty) return all.take(40).toList();
      final scored = <({int score, _PaletteEntry entry})>[];
      for (final item in all) {
        final t = item.title.toLowerCase();
        final s = item.subtitle.toLowerCase();
        if (t.startsWith(q)) {
          scored.add((score: 0, entry: item));
        } else if (t.contains(q)) {
          scored.add((score: 1, entry: item));
        } else if (s.contains(q) || item.badge.toLowerCase().contains(q)) {
          scored.add((score: 2, entry: item));
        }
      }
      scored.sort((a, b) => a.score.compareTo(b.score));
      return [for (final s in scored.take(40)) s.entry];
    }

    void renderList() {
      listContainer.innerHTML = ''.toJS;
      if (currentEntries.isEmpty) {
        final empty = web.document.createElement('div') as web.HTMLDivElement
          ..className = 'calc-palette-empty'
          ..textContent = 'No matching commands or symbols.';
        listContainer.append(empty);
        return;
      }
      for (var i = 0; i < currentEntries.length; i++) {
        final entry = currentEntries[i];
        final row =
            web.document.createElement('button') as web.HTMLButtonElement
              ..type = 'button'
              ..className = i == selectedIdx
                  ? 'calc-palette-item active'
                  : 'calc-palette-item';
        final topRow = web.document.createElement('div') as web.HTMLDivElement
          ..className = 'calc-palette-item-top';
        final titleSpan =
            web.document.createElement('span') as web.HTMLSpanElement
              ..className = 'calc-palette-item-title'
              ..textContent = entry.title;
        final badgeSpan =
            web.document.createElement('span') as web.HTMLSpanElement
              ..className = 'calc-palette-item-badge'
              ..textContent = entry.badge;
        topRow
          ..append(titleSpan)
          ..append(badgeSpan);

        final subDiv = web.document.createElement('div') as web.HTMLDivElement
          ..className = 'calc-palette-item-sub'
          ..textContent = entry.subtitle;
        row
          ..append(topRow)
          ..append(subDiv);

        row.addEventListener(
          'click',
          ((web.Event _) {
            backdrop.remove();
            onSelect(
              entry.snippet,
              executeImmediately: entry.executeImmediately,
            );
          }).toJS,
        );
        listContainer.append(row);
      }
    }

    searchInput.addEventListener(
      'input',
      ((web.Event _) {
        selectedIdx = 0;
        currentEntries = buildEntries(searchInput.value);
        renderList();
      }).toJS,
    );

    searchInput.addEventListener(
      'keydown',
      ((web.KeyboardEvent e) {
        if (e.key == 'Escape') {
          e.preventDefault();
          backdrop.remove();
        } else if (e.key == 'ArrowDown') {
          e.preventDefault();
          if (currentEntries.isNotEmpty) {
            selectedIdx = (selectedIdx + 1) % currentEntries.length;
            renderList();
          }
        } else if (e.key == 'ArrowUp') {
          e.preventDefault();
          if (currentEntries.isNotEmpty) {
            selectedIdx =
                (selectedIdx - 1 + currentEntries.length) %
                currentEntries.length;
            renderList();
          }
        } else if (e.key == 'Enter') {
          e.preventDefault();
          if (currentEntries.isNotEmpty) {
            final chosen = currentEntries[selectedIdx];
            backdrop.remove();
            onSelect(
              chosen.snippet,
              executeImmediately: chosen.executeImmediately,
            );
          }
        }
      }).toJS,
    );

    backdrop.addEventListener(
      'click',
      ((web.MouseEvent e) {
        if (e.target == backdrop) backdrop.remove();
      }).toJS,
    );

    currentEntries = buildEntries('');
    renderList();
    web.document.body?.append(backdrop);
    searchInput.focus();
  }
}

final class _PaletteEntry {
  const new({
    required this.title,
    required this.badge,
    required this.subtitle,
    required this.snippet,
    required this.executeImmediately,
  });

  final String title;
  final String badge;
  final String subtitle;
  final String snippet;
  final bool executeImmediately;
}
