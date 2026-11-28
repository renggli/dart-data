import 'dart:js_interop';

import 'package:data/symbolic.dart';
import 'package:web/web.dart' as web;

import '../../../shared/utils.dart';
import '../model/environment.dart';
import '../model/notebook.dart';
import '../model/value.dart';
import '../worker/engine_client.dart';
import 'icons.dart';
import 'persistence.dart';

/// Active tab of [LeftSidebar].
enum LeftSidebarTab { files, structure, settings }

/// Tabbed left sidebar providing local file management, document structure
/// navigation, and evaluation settings.
final class LeftSidebar {
  new({
    required this.client,
    required this.getActiveFileId,
    required this.getFocusedUid,
    required this.onNewFile,
    required this.onOpenFile,
    required this.onRenameFile,
    required this.onDeleteFile,
    required this.onImportFile,
    required this.onExportMarkdown,
    required this.onCopyShareUrl,
    required this.onSelectCell,
    required this.onDeleteCell,
    required this.onInsertMathCell,
    required this.onInsertTextCell,
    required this.onTerminalAction,
  }) {
    _buildDom();
  }

  final EngineClient client;
  final String? Function() getActiveFileId;
  final String? Function() getFocusedUid;
  final void Function() onNewFile;
  final void Function(String fileId) onOpenFile;
  final void Function(String fileId, String name) onRenameFile;
  final void Function(String fileId) onDeleteFile;
  final void Function(String filename, String content) onImportFile;
  final void Function() onExportMarkdown;
  final void Function() onCopyShareUrl;
  final void Function(String uid) onSelectCell;
  final void Function(String uid) onDeleteCell;
  final void Function() onInsertMathCell;
  final void Function() onInsertTextCell;
  final void Function() onTerminalAction;

  late final web.HTMLDivElement root;
  late final web.HTMLDivElement _filesPane;
  late final web.HTMLDivElement _structurePane;
  late final web.HTMLDivElement _settingsPane;
  late final web.HTMLInputElement _importInput;

  final Map<LeftSidebarTab, web.HTMLButtonElement> _tabButtons = {};
  LeftSidebarTab _activeTab = LeftSidebarTab.files;
  String? _renamingFileId;

  LeftSidebarTab get activeTab => _activeTab;

  void setTab(LeftSidebarTab tab) {
    _closeDropdowns();
    _activeTab = tab;
    for (final entry in _tabButtons.entries) {
      final isSel = entry.key == tab;
      entry.value
        ..classList.toggle('active', isSel)
        ..setAttribute('aria-selected', isSel ? 'true' : 'false');
    }
    _filesPane.style.display = tab == LeftSidebarTab.files ? 'flex' : 'none';
    _structurePane.style.display = tab == LeftSidebarTab.structure
        ? 'flex'
        : 'none';
    _settingsPane.style.display = tab == LeftSidebarTab.settings
        ? 'flex'
        : 'none';
    render();
  }

  void render() {
    switch (_activeTab) {
      case LeftSidebarTab.files:
        _renderFiles();
      case LeftSidebarTab.structure:
        _renderStructure();
      case LeftSidebarTab.settings:
        _renderSettings();
    }
  }

  void _buildDom() {
    root = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-sidebar-shell';

    final header = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-sidebar-tabs-bar';

    final tabs = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'segmented-control nb-tabs-group'
      ..setAttribute('role', 'tablist');

    tabs
      ..append(_buildTabButton(LeftSidebarTab.files, 'Files', NbIcons.files))
      ..append(
        _buildTabButton(LeftSidebarTab.structure, 'Structure', NbIcons.list),
      )
      ..append(
        _buildTabButton(LeftSidebarTab.settings, 'Settings', NbIcons.sliders),
      );

    header.append(tabs);

    _importInput = (web.document.createElement('input') as web.HTMLInputElement)
      ..type = 'file'
      ..accept = '.md,.markdown,.json,.txt'
      ..style.display = 'none';
    _importInput.onchange = ((web.Event _) {
      final files = _importInput.files;
      if (files == null || files.length == 0) return;
      final file = files.item(0);
      if (file == null) return;
      final reader = web.FileReader();
      reader.onload = ((web.Event _) {
        final text = (reader.result as JSString?)?.toDart ?? '';
        onImportFile(file.name, text);
        onTerminalAction();
      }).toJS;
      reader.readAsText(file);
    }).toJS;

    _filesPane = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-sidebar-pane'
      ..setAttribute('role', 'tabpanel');
    _structurePane = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-sidebar-pane'
      ..setAttribute('role', 'tabpanel');
    _settingsPane = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-sidebar-pane'
      ..setAttribute('role', 'tabpanel');

    root
      ..append(header)
      ..append(_importInput)
      ..append(_filesPane)
      ..append(_structurePane)
      ..append(_settingsPane);

    web.document.addEventListener(
      'mousedown',
      ((web.MouseEvent e) {
        final target = e.target;
        if (target == null || !target.isA<web.Element>()) {
          _closeDropdowns();
          return;
        }
        if ((target as web.Element).closest('.nb-select-wrap') == null) {
          _closeDropdowns();
        }
      }).toJS,
    );
    web.document.addEventListener(
      'keydown',
      ((web.KeyboardEvent e) {
        if (e.key == 'Escape') _closeDropdowns();
      }).toJS,
    );

    setTab(LeftSidebarTab.files);
  }

  web.HTMLButtonElement _buildTabButton(
    LeftSidebarTab tab,
    String label,
    String iconSvg,
  ) {
    final isSel = tab == _activeTab;
    final btn = (web.document.createElement('button') as web.HTMLButtonElement)
      ..type = 'button'
      ..className = isSel ? 'segmented-btn active' : 'segmented-btn'
      ..setAttribute('role', 'tab')
      ..setAttribute('aria-selected', isSel ? 'true' : 'false')
      ..innerHTML =
          '<span class="nb-tab-icon">$iconSvg</span><span>$label</span>'.toJS;
    btn.onclick = ((web.MouseEvent _) => setTab(tab)).toJS;
    _tabButtons[tab] = btn;
    return btn;
  }

  void _renderFiles() {
    _filesPane.replaceChildren(<JSAny>[].toJS);

    final actionBar = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-files-actions';

    actionBar
      ..append(
        _miniActionBtn('New notebook', NbIcons.plus, 'New', () {
          onNewFile();
          onTerminalAction();
        }, primary: true),
      )
      ..append(
        _miniActionBtn('Import .md or .json', NbIcons.upload, 'Import', () {
          _importInput.value = '';
          _importInput.click();
        }),
      )
      ..append(
        _miniActionBtn('Export Markdown (.md)', NbIcons.download, 'Export', () {
          onExportMarkdown();
          onTerminalAction();
        }),
      )
      ..append(
        _miniActionBtn('Copy shareable URL', NbIcons.link, 'Share', () {
          onCopyShareUrl();
          onTerminalAction();
        }),
      );

    _filesPane.append(actionBar);

    final files = NotebookPersistence.listFiles();
    final activeId = getActiveFileId();
    final filesList = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-pane-list';

    if (files.isEmpty) {
      filesList.append(
        (web.document.createElement('div') as web.HTMLDivElement)
          ..className = 'nb-outline-empty'
          ..textContent = 'No local files yet.',
      );
    } else {
      for (final file in files) {
        final isActive = file.id == activeId;
        final row = (web.document.createElement('div') as web.HTMLDivElement)
          ..className = isActive
              ? 'sidebar-item nb-file-row active'
              : 'sidebar-item nb-file-row';

        if (_renamingFileId == file.id) {
          final input =
              (web.document.createElement('input') as web.HTMLInputElement)
                ..type = 'text'
                ..className = 'nb-rename-input'
                ..value = file.name;
          void commit() {
            final next = input.value.trim();
            _renamingFileId = null;
            if (next.isNotEmpty && next != file.name) {
              onRenameFile(file.id, next);
            } else {
              _renderFiles();
            }
          }

          input.onkeydown = ((web.KeyboardEvent e) {
            if (e.key == 'Enter') {
              e.preventDefault();
              commit();
            } else if (e.key == 'Escape') {
              e.preventDefault();
              _renamingFileId = null;
              _renderFiles();
            }
          }).toJS;
          input.onblur = ((web.FocusEvent _) => commit()).toJS;
          row.append(input);
          Future<void>.microtask(() {
            input
              ..focus()
              ..select();
          });
        } else {
          final info = (web.document.createElement('div') as web.HTMLDivElement)
            ..className = 'nb-file-info';
          final titleEl =
              (web.document.createElement('div') as web.HTMLDivElement)
                ..className = 'nb-file-name'
                ..textContent = file.name;
          final metaEl =
              (web.document.createElement('div') as web.HTMLDivElement)
                ..className = 'nb-file-meta'
                ..textContent =
                    '${file.cellCount} cell${file.cellCount == 1 ? '' : 's'}';
          info
            ..append(titleEl)
            ..append(metaEl);

          final rowBtns =
              (web.document.createElement('div') as web.HTMLDivElement)
                ..className = 'nb-row-actions';

          final renameBtn =
              (web.document.createElement('button') as web.HTMLButtonElement)
                ..type = 'button'
                ..className = 'icon-btn nb-mini-icon-btn'
                ..title = 'Rename notebook'
                ..setAttribute('aria-label', 'Rename notebook')
                ..innerHTML = NbIcons.pencil.toJS;
          renameBtn.onclick = ((web.MouseEvent e) {
            e.stopPropagation();
            _renamingFileId = file.id;
            _renderFiles();
          }).toJS;

          final deleteBtn =
              (web.document.createElement('button') as web.HTMLButtonElement)
                ..type = 'button'
                ..className = 'icon-btn nb-mini-icon-btn danger'
                ..title = 'Delete notebook'
                ..setAttribute('aria-label', 'Delete notebook')
                ..innerHTML = NbIcons.trash.toJS;
          deleteBtn.onclick = ((web.MouseEvent e) {
            e.stopPropagation();
            onDeleteFile(file.id);
          }).toJS;

          rowBtns
            ..append(renameBtn)
            ..append(deleteBtn);

          row
            ..append(info)
            ..append(rowBtns)
            ..onclick = ((web.MouseEvent _) {
              onOpenFile(file.id);
              onTerminalAction();
            }).toJS;
        }
        filesList.append(row);
      }
    }
    _filesPane.append(filesList);
  }

  void _renderStructure() {
    _structurePane.replaceChildren(<JSAny>[].toJS);

    final addRow = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-structure-actions';
    addRow
      ..append(
        _miniActionBtn('Add Math cell', NbIcons.plus, 'Math Cell', () {
          onInsertMathCell();
          onTerminalAction();
        }, primary: true),
      )
      ..append(
        _miniActionBtn('Add Text cell', NbIcons.fileText, 'Text Cell', () {
          onInsertTextCell();
          onTerminalAction();
        }),
      );
    _structurePane.append(addRow);

    final cells = client.document.cells;
    final list = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-pane-list';

    if (cells.isEmpty) {
      list.append(
        (web.document.createElement('div') as web.HTMLDivElement)
          ..className = 'nb-outline-empty'
          ..textContent = 'Document is empty. Add a cell above.',
      );
      _structurePane.append(list);
      return;
    }

    final focusedUid = getFocusedUid();
    var insideSection = false;

    for (final cell in cells) {
      final isFocused = cell.uid == focusedUid;
      switch (cell) {
        case MarkdownCell(:final source, :final stale):
          final headings = _extractHeadings(source);
          if (headings.isNotEmpty) {
            for (var i = 0; i < headings.length; i++) {
              final heading = headings[i];
              insideSection = true;
              final row =
                  (web.document.createElement('div') as web.HTMLDivElement)
                    ..className =
                        'sidebar-item nb-structure-heading nb-structure-h${heading.level}'
                        '${isFocused ? ' active' : ''}';
              final label =
                  (web.document.createElement('span') as web.HTMLSpanElement)
                    ..className = 'nb-structure-heading-label'
                    ..textContent = heading.title;
              row.append(label);
              if (i == 0) {
                row.append(_structureDeleteActions(cell.uid));
              }
              row.onclick = ((web.MouseEvent _) {
                onSelectCell(cell.uid);
                onTerminalAction();
              }).toJS;
              list.append(row);
            }
          } else {
            final row =
                (web.document.createElement('div') as web.HTMLDivElement)
                  ..className =
                      'sidebar-item nb-structure-cell'
                      '${insideSection ? ' nested' : ''}'
                      '${isFocused ? ' active' : ''}';
            final tag =
                (web.document.createElement('span') as web.HTMLSpanElement)
                  ..className = 'badge nb-structure-badge'
                  ..textContent = stale ? 'Text ·' : 'Text';
            final firstLine = source.trim().split('\n').first;
            final label =
                (web.document.createElement('span') as web.HTMLSpanElement)
                  ..className = 'nb-outline-label'
                  ..textContent = firstLine.isEmpty ? 'Text cell' : firstLine;
            row
              ..append(tag)
              ..append(label)
              ..append(_structureDeleteActions(cell.uid))
              ..onclick = ((web.MouseEvent _) {
                onSelectCell(cell.uid);
                onTerminalAction();
              }).toJS;
            list.append(row);
          }
        case MathCell(:final id, :final source, :final stale, :final value):
          final row = (web.document.createElement('div') as web.HTMLDivElement)
            ..className =
                'sidebar-item nb-structure-cell'
                '${insideSection ? ' nested' : ''}'
                '${isFocused ? ' active' : ''}';
          final tag =
              (web.document.createElement('span') as web.HTMLSpanElement)
                ..className = 'badge nb-structure-badge'
                ..textContent = 'r[$id]';
          if (value is ErrorValue) {
            tag.classList.add('nb-badge-error');
          } else if (stale) {
            tag.classList.add('nb-badge-stale');
          }
          final firstLine = source.trim().split('\n').first;
          final label =
              (web.document.createElement('span') as web.HTMLSpanElement)
                ..className = 'nb-outline-label'
                ..textContent = firstLine.isEmpty ? 'Math cell' : firstLine;
          row
            ..append(tag)
            ..append(label)
            ..append(_structureDeleteActions(cell.uid))
            ..onclick = ((web.MouseEvent _) {
              onSelectCell(cell.uid);
              onTerminalAction();
            }).toJS;
          list.append(row);
      }
    }

    _structurePane.append(list);
  }

  static final RegExp _headingPattern = RegExp(r'^(#{1,3})\s+(.+?)\s*$');

  List<({int level, String title})> _extractHeadings(String source) {
    final result = <({int level, String title})>[];
    for (final rawLine in source.split('\n')) {
      final match = _headingPattern.firstMatch(rawLine.trimLeft());
      if (match != null) {
        result.add((
          level: match.group(1)!.length.clamp(1, 3),
          title: match.group(2)!,
        ));
      }
    }
    return result;
  }

  web.HTMLDivElement _structureDeleteActions(String uid) {
    final wrap = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-row-actions';
    final delBtn =
        (web.document.createElement('button') as web.HTMLButtonElement)
          ..type = 'button'
          ..className = 'icon-btn nb-mini-icon-btn danger'
          ..title = 'Delete entry'
          ..setAttribute('aria-label', 'Delete entry')
          ..innerHTML = NbIcons.trash.toJS;
    delBtn.onclick = ((web.MouseEvent e) {
      e.stopPropagation();
      onDeleteCell(uid);
    }).toJS;
    wrap.append(delBtn);
    return wrap;
  }

  void _renderSettings() {
    _settingsPane.replaceChildren(<JSAny>[].toJS);
    final settings = client.env.settings;

    final list = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-settings-list';

    final domDropdown = _dropdownControl<VariableDomain>(
      ariaLabel: 'Default domain',
      value: settings.domain,
      options: VariableDomain.values,
      labelFor: _domainLabel,
      onChanged: (chosen) {
        client.updateSettings(client.env.settings.copyWith(domain: chosen));
      },
    );

    final digitsInput =
        (web.document.createElement('input') as web.HTMLInputElement)
          ..type = 'number'
          ..className = 'custom-number-input'
          ..min = '2'
          ..max = '16'
          ..value = '${settings.digits}';
    digitsInput.onchange = ((web.Event _) {
      final d = (int.tryParse(digitsInput.value) ?? 10).clamp(2, 16);
      client.updateSettings(client.env.settings.copyWith(digits: d));
    }).toJS;

    final complexDropdown = _dropdownControl<ComplexDisplayMode>(
      ariaLabel: 'Complex display',
      value: settings.complexDisplay,
      options: ComplexDisplayMode.values,
      labelFor: _complexDisplayLabel,
      onChanged: (chosen) {
        client.updateSettings(
          client.env.settings.copyWith(complexDisplay: chosen),
        );
      },
    );

    list
      ..append(_settingRow('Default domain', domDropdown))
      ..append(_settingRow('Approx digits', digitsInput))
      ..append(_settingRow('Complex display', complexDropdown))
      ..append(
        _toggleRow(
          'Auto-simplify expressions',
          settings.autoSimplify,
          (v) => client.updateSettings(
            client.env.settings.copyWith(autoSimplify: v),
          ),
        ),
      )
      ..append(
        _toggleRow(
          'Approximate mode',
          settings.approxMode,
          (v) => client.updateSettings(
            client.env.settings.copyWith(approxMode: v),
          ),
        ),
      )
      ..append(
        _toggleRow(
          'Implicit multiplication',
          settings.implicitMultiplication,
          (v) => client.updateSettings(
            client.env.settings.copyWith(implicitMultiplication: v),
          ),
        ),
      );

    _settingsPane.append(list);

    final actions = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-settings-actions';

    final recomputeBtn =
        (web.document.createElement('button') as web.HTMLButtonElement)
          ..type = 'button'
          ..className = 'btn btn-primary nb-full-btn'
          ..textContent = 'Recompute All Cells'
          ..onclick = ((web.MouseEvent _) {
            client.recomputeAll();
            onTerminalAction();
          }).toJS;

    final clearBtn =
        (web.document.createElement('button') as web.HTMLButtonElement)
          ..type = 'button'
          ..className = 'btn btn-secondary nb-full-btn'
          ..textContent = 'Clear Session Variables'
          ..onclick = ((web.MouseEvent _) {
            client.clearSession();
            onTerminalAction();
          }).toJS;

    actions
      ..append(recomputeBtn)
      ..append(clearBtn);
    _settingsPane.append(actions);

    final env = client.env;
    if (env.variables.isNotEmpty ||
        env.functions.isNotEmpty ||
        env.settings.variableDomains.isNotEmpty) {
      final heading = (web.document.createElement('div') as web.HTMLDivElement)
        ..className = 'group-heading nb-pane-heading'
        ..textContent = 'Active Session';
      _settingsPane.append(heading);

      final stateList =
          (web.document.createElement('div') as web.HTMLDivElement)
            ..className = 'nb-session-list';
      for (final entry in env.variables.entries) {
        stateList.append(
          (web.document.createElement('div') as web.HTMLDivElement)
            ..className = 'nb-session-item'
            ..textContent = '${entry.key} := ${entry.value.toCanonicalText()}',
        );
      }
      for (final fn in env.functions.values) {
        stateList.append(
          (web.document.createElement('div') as web.HTMLDivElement)
            ..className = 'nb-session-item'
            ..textContent = fn.source,
        );
      }
      for (final entry in env.settings.variableDomains.entries) {
        stateList.append(
          (web.document.createElement('div') as web.HTMLDivElement)
            ..className = 'nb-session-item'
            ..textContent = 'assume(${entry.key}, ${entry.value.name})',
        );
      }
      _settingsPane.append(stateList);
    }
  }

  String _domainLabel(VariableDomain d) => switch (d) {
    VariableDomain.unknown => 'Unknown',
    VariableDomain.complex => 'Complex',
    VariableDomain.real => 'Real',
    VariableDomain.positive => 'Positive',
    VariableDomain.integer => 'Integer',
  };

  String _complexDisplayLabel(ComplexDisplayMode m) => switch (m) {
    ComplexDisplayMode.rectangular => 'Rectangular',
    ComplexDisplayMode.polar => 'Polar',
  };

  void _closeDropdowns() {
    final openMenus = _settingsPane.querySelectorAll('.nb-select-menu');
    for (var i = 0; i < openMenus.length; i++) {
      final el = openMenus.item(i);
      if (el != null) setHidden(el as web.HTMLElement, true);
    }
    final triggers = _settingsPane.querySelectorAll('.nb-select-trigger');
    for (var i = 0; i < triggers.length; i++) {
      final el = triggers.item(i);
      if (el != null) {
        (el as web.HTMLElement).setAttribute('aria-expanded', 'false');
      }
    }
  }

  web.HTMLDivElement _dropdownControl<T>({
    required String ariaLabel,
    required T value,
    required List<T> options,
    required String Function(T) labelFor,
    required void Function(T) onChanged,
  }) {
    final wrap = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-select-wrap';

    final trigger =
        (web.document.createElement('button') as web.HTMLButtonElement)
          ..type = 'button'
          ..className = 'nb-select-trigger'
          ..setAttribute('aria-label', ariaLabel)
          ..setAttribute('aria-haspopup', 'listbox')
          ..setAttribute('aria-expanded', 'false');

    final labelSpan =
        (web.document.createElement('span') as web.HTMLSpanElement)
          ..className = 'nb-select-label'
          ..textContent = labelFor(value);
    final chevronSpan =
        (web.document.createElement('span') as web.HTMLSpanElement)
          ..className = 'nb-select-chevron'
          ..innerHTML = NbIcons.chevronDown.toJS;
    trigger
      ..append(labelSpan)
      ..append(chevronSpan);

    final menu = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'dropdown-menu nb-select-menu'
      ..setAttribute('role', 'listbox');
    setHidden(menu, true);

    for (final option in options) {
      final isSel = option == value;
      final item =
          (web.document.createElement('button') as web.HTMLButtonElement)
            ..type = 'button'
            ..className = isSel
                ? 'dropdown-menu-item active'
                : 'dropdown-menu-item'
            ..setAttribute('role', 'option')
            ..setAttribute('aria-selected', isSel ? 'true' : 'false');
      final textSpan =
          (web.document.createElement('span') as web.HTMLSpanElement)
            ..className = 'dropdown-menu-label'
            ..textContent = labelFor(option);
      item.append(textSpan);
      if (isSel) {
        item.append(
          (web.document.createElement('span') as web.HTMLSpanElement)
            ..className = 'dropdown-menu-icon'
            ..innerHTML = NbIcons.check.toJS,
        );
      }
      item.onclick = ((web.MouseEvent e) {
        e.stopPropagation();
        _closeDropdowns();
        if (option != value) onChanged(option);
      }).toJS;
      menu.append(item);
    }

    trigger.onclick = ((web.MouseEvent e) {
      e.stopPropagation();
      final wasOpen = !isHidden(menu);
      _closeDropdowns();
      if (!wasOpen) {
        setHidden(menu, false);
        trigger.setAttribute('aria-expanded', 'true');
      }
    }).toJS;

    wrap
      ..append(trigger)
      ..append(menu);
    return wrap;
  }

  web.HTMLButtonElement _miniActionBtn(
    String title,
    String svg,
    String label,
    void Function() onTap, {
    bool primary = false,
  }) {
    final btn = (web.document.createElement('button') as web.HTMLButtonElement)
      ..type = 'button'
      ..className = primary ? 'nb-tool-btn primary' : 'nb-tool-btn'
      ..title = title
      ..innerHTML =
          '<span class="nb-tool-icon">$svg</span><span>$label</span>'.toJS;
    btn.onclick = ((web.MouseEvent _) => onTap()).toJS;
    return btn;
  }

  web.HTMLDivElement _settingRow(String label, web.HTMLElement control) {
    final row = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-setting-row';
    final lbl = (web.document.createElement('label') as web.HTMLLabelElement)
      ..textContent = label;
    row
      ..append(lbl)
      ..append(control);
    return row;
  }

  web.HTMLDivElement _toggleRow(
    String label,
    bool checked,
    void Function(bool value) onChanged,
  ) {
    final row = (web.document.createElement('label') as web.HTMLLabelElement)
      ..className = 'nb-setting-toggle';
    final lbl = (web.document.createElement('span') as web.HTMLSpanElement)
      ..textContent = label;
    final box = (web.document.createElement('input') as web.HTMLInputElement)
      ..type = 'checkbox'
      ..className = 'toggle-input'
      ..checked = checked;
    box.onchange = ((web.Event _) => onChanged(box.checked)).toJS;
    final slider = (web.document.createElement('span') as web.HTMLSpanElement)
      ..className = 'toggle-track';
    final switchWrap =
        (web.document.createElement('span') as web.HTMLSpanElement)
          ..className = 'toggle-switch'
          ..append(box)
          ..append(slider);

    row
      ..append(lbl)
      ..append(switchWrap);
    return (web.document.createElement('div') as web.HTMLDivElement)
      ..append(row);
  }
}
