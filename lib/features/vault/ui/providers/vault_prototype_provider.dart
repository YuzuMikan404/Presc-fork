import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import '../../data/models/vault_document.dart';
import '../../data/saf_vault_service.dart';

enum VaultPanelMode { files, tags }

class VaultProvider with ChangeNotifier {
  VaultProvider({SafVaultService? service})
      : _service = service ?? SafVaultService() {
    unawaited(initialize());
  }

  static const _treeUriPreference = 'vault_tree_uri';
  static const _vaultNamePreference = 'vault_display_name';
  static const _vaultCanWritePreference = 'vault_can_write';
  static const _lastDocumentPreference = 'vault_last_document_uri';

  final SafVaultService _service;
  VaultPanelMode _panelMode = VaultPanelMode.files;
  List<SafDocumentEntry> _entries = const [];
  List<VaultTreeNode> _tree = const [];
  final Map<String, List<String>> _tagIndex = {};
  final List<String> _backHistory = [];
  final List<String> _forwardHistory = [];

  bool _initialized = false;
  bool _loading = false;
  bool _loadingDocument = false;
  bool _indexingTags = false;
  bool _saving = false;
  int _vaultGeneration = 0;
  String? _treeUri;
  String? _vaultName;
  bool _vaultCanWrite = false;
  String? _errorMessage;
  VaultDocument? _selectedDocument;

  VaultPanelMode get panelMode => _panelMode;
  bool get initialized => _initialized;
  bool get loading => _loading;
  bool get loadingDocument => _loadingDocument;
  bool get indexingTags => _indexingTags;
  bool get saving => _saving;
  bool get hasVault => _treeUri != null;
  String get vaultName => _vaultName ?? 'Markdown Vault';
  bool get vaultCanWrite => _vaultCanWrite;
  bool get canGoBack => _backHistory.isNotEmpty;
  bool get canGoForward => _forwardHistory.isNotEmpty;
  String? get errorMessage => _errorMessage;
  VaultDocument? get selectedDocument => _selectedDocument;
  List<VaultTreeNode> get tree => _tree;

  Map<String, int> get tagCounts {
    final counts = <String, int>{};
    final displayNames = <String, String>{};
    for (final tags in _tagIndex.values) {
      for (final tag in tags.map((tag) => tag.toLowerCase()).toSet()) {
        final original = tags.firstWhere(
          (candidate) => candidate.toLowerCase() == tag,
        );
        displayNames.putIfAbsent(tag, () => original);
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    return {
      for (final entry in counts.entries)
        (displayNames[entry.key] ?? entry.key): entry.value,
    };
  }

  List<VaultTreeNode> documentsForTag(String tag) {
    final normalizedTag = tag.toLowerCase();
    return _entries
        .where(
          (entry) =>
              !entry.isDirectory &&
              (_tagIndex[entry.uri]?.any(
                    (candidate) {
                      final normalizedCandidate = candidate.toLowerCase();
                      return normalizedCandidate == normalizedTag ||
                          normalizedCandidate.startsWith('$normalizedTag/');
                    },
                  ) ??
                  false),
        )
        .map(
          (entry) => VaultTreeNode.file(
            name: entry.relativePath,
            documentId: entry.uri,
          ),
        )
        .toList();
  }

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    _treeUri = preferences.getString(_treeUriPreference);
    _vaultName = preferences.getString(_vaultNamePreference);
    _vaultCanWrite = preferences.getBool(_vaultCanWritePreference) ?? false;
    _initialized = true;
    notifyListeners();

    if (_treeUri != null) {
      await refresh(
        preferredDocumentUri: preferences.getString(_lastDocumentPreference),
      );
    }
  }

  Future<bool> chooseVault() async {
    _errorMessage = null;
    try {
      final selection = await _service.pickVault();
      if (selection == null) return false;

      _treeUri = selection.treeUri;
      _vaultName = selection.displayName;
      _vaultCanWrite = selection.canWrite;
      _selectedDocument = null;
      _entries = const [];
      _tree = const [];
      _tagIndex.clear();
      _backHistory.clear();
      _forwardHistory.clear();
      _vaultGeneration++;
      _indexingTags = false;

      final preferences = await SharedPreferences.getInstance();
      await Future.wait([
        preferences.setString(_treeUriPreference, selection.treeUri),
        preferences.setString(_vaultNamePreference, selection.displayName),
        preferences.setBool(_vaultCanWritePreference, selection.canWrite),
        preferences.remove(_lastDocumentPreference),
      ]);
      notifyListeners();
      await refresh();
      return true;
    } on PlatformException catch (error) {
      _errorMessage = _friendlyError(error);
      notifyListeners();
      return false;
    }
  }

  Future<void> refresh({String? preferredDocumentUri}) async {
    final treeUri = _treeUri;
    if (treeUri == null || _loading) return;

    _loading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _entries = await _service.listDocuments(treeUri);
      _entries = [..._entries]
        ..sort((a, b) => a.relativePath.toLowerCase().compareTo(
              b.relativePath.toLowerCase(),
            ));
      _tree = _buildTree(_entries);

      final markdownFiles = _entries.where((entry) => !entry.isDirectory);
      final currentDocumentUri = _selectedDocument?.id;
      final targetUri = preferredDocumentUri != null &&
              markdownFiles.any((entry) => entry.uri == preferredDocumentUri)
          ? preferredDocumentUri
          : currentDocumentUri != null &&
                  markdownFiles.any((entry) => entry.uri == currentDocumentUri)
              ? currentDocumentUri
              : (markdownFiles.isEmpty ? null : markdownFiles.first.uri);

      if (targetUri != null) {
        await selectDocument(
          targetUri,
          notifyLoading: false,
          recordHistory: false,
        );
      } else {
        _selectedDocument = null;
      }

      unawaited(_indexTags(_vaultGeneration));
    } on PlatformException catch (error) {
      _errorMessage = _friendlyError(error);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> selectDocument(
    String uri, {
    bool notifyLoading = true,
    bool recordHistory = true,
  }) async {
    SafDocumentEntry? entry;
    for (final candidate in _entries) {
      if (candidate.uri == uri) {
        entry = candidate;
        break;
      }
    }
    if (entry == null || entry.isDirectory) return;

    _loadingDocument = true;
    _errorMessage = null;
    if (notifyLoading) notifyListeners();
    try {
      final previousUri = _selectedDocument?.id;
      final markdown = await _service.readDocument(entry.uri);
      final tags = _extractTags(markdown);
      final propertyTags = _extractPropertyTags(markdown);
      _tagIndex[entry.uri] = tags;
      _selectedDocument = VaultDocument(
        id: entry.uri,
        name: entry.name,
        path: entry.relativePath,
        markdown: markdown,
        tags: tags,
        propertyTags: propertyTags,
        canWrite: _vaultCanWrite && entry.canWrite,
      );
      if (recordHistory && previousUri != null && previousUri != entry.uri) {
        _backHistory.add(previousUri);
        _forwardHistory.clear();
      }
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_lastDocumentPreference, entry.uri);
    } on PlatformException catch (error) {
      _errorMessage = _friendlyError(error);
    } finally {
      _loadingDocument = false;
      notifyListeners();
    }
  }

  Future<void> goBack() async {
    if (_backHistory.isEmpty || _loadingDocument) return;
    final target = _backHistory.removeLast();
    final current = _selectedDocument?.id;
    if (current != null) _forwardHistory.add(current);
    await selectDocument(target, recordHistory: false);
  }

  Future<void> goForward() async {
    if (_forwardHistory.isEmpty || _loadingDocument) return;
    final target = _forwardHistory.removeLast();
    final current = _selectedDocument?.id;
    if (current != null) _backHistory.add(current);
    await selectDocument(target, recordHistory: false);
  }

  Future<bool> openWikiLink(String target) async {
    final normalizedTarget = target
        .split('#')
        .first
        .split('^')
        .first
        .trim()
        .replaceAll('\\', '/');
    if (normalizedTarget.isEmpty) return false;

    final targetWithExtension = RegExp(
      r'\.(md|markdown)$',
      caseSensitive: false,
    ).hasMatch(normalizedTarget)
        ? normalizedTarget
        : '$normalizedTarget.md';
    final targetLower = targetWithExtension.toLowerCase();
    SafDocumentEntry? match;

    for (final entry in _entries.where((entry) => !entry.isDirectory)) {
      final path = entry.relativePath.replaceAll('\\', '/').toLowerCase();
      if (path == targetLower) {
        match = entry;
        break;
      }
      if (!normalizedTarget.contains('/') &&
          entry.name.toLowerCase() == targetLower) {
        match ??= entry;
      }
    }

    if (match == null) {
      _errorMessage = 'リンク先「$normalizedTarget」がVault内に見つかりません。';
      notifyListeners();
      return false;
    }
    await selectDocument(match.uri);
    return true;
  }

  void changePanelMode(VaultPanelMode mode) {
    if (_panelMode == mode) return;
    _panelMode = mode;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> addTag(String value) async {
    final normalized = value.trim().replaceFirst(RegExp(r'^#'), '');
    if (!_isValidTag(normalized)) {
      _errorMessage = 'タグには空白を使用できず、数字だけの名前にもできません。';
      notifyListeners();
      return false;
    }
    final document = _selectedDocument;
    if (document == null) return false;
    if (document.propertyTags.any(
      (tag) => tag.toLowerCase() == normalized.toLowerCase(),
    )) {
      return true;
    }
    final tags = {...document.propertyTags, normalized}.toList()
      ..sort((a, b) => a.compareTo(b));
    return _writePropertyTags(tags);
  }

  Future<void> removeTag(String tag) async {
    final document = _selectedDocument;
    if (document == null || !document.propertyTags.contains(tag)) return;
    await _writePropertyTags(
      document.propertyTags.where((candidate) => candidate != tag).toList(),
    );
  }

  Future<bool> _writePropertyTags(List<String> propertyTags) async {
    final document = _selectedDocument;
    if (document == null || !document.canWrite || _saving) return false;
    _saving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final latestMarkdown = await _service.readDocument(document.id);
      final latestPropertyTags = _extractPropertyTags(latestMarkdown);
      final previousByKey = {
        for (final tag in document.propertyTags) tag.toLowerCase(): tag,
      };
      final requestedByKey = {
        for (final tag in propertyTags) tag.toLowerCase(): tag,
      };
      final mergedByKey = {
        for (final tag in latestPropertyTags) tag.toLowerCase(): tag,
      };
      for (final removed
          in previousByKey.keys.toSet().difference(requestedByKey.keys.toSet())) {
        mergedByKey.remove(removed);
      }
      for (final added
          in requestedByKey.keys.toSet().difference(previousByKey.keys.toSet())) {
        mergedByKey[added] = requestedByKey[added]!;
      }
      final mergedPropertyTags = mergedByKey.values.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      final markdown = _replacePropertyTags(
        latestMarkdown,
        mergedPropertyTags,
      );
      await _service.writeDocument(document.id, markdown);
      final allTags = _extractTags(markdown);
      _tagIndex[document.id] = allTags;
      _selectedDocument = VaultDocument(
        id: document.id,
        name: document.name,
        path: document.path,
        markdown: markdown,
        tags: allTags,
        propertyTags: mergedPropertyTags,
        canWrite: document.canWrite,
      );
      return true;
    } on PlatformException catch (error) {
      _errorMessage = _friendlyError(error);
      return false;
    } on FormatException catch (error) {
      _errorMessage = error.message;
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<void> _indexTags(int generation) async {
    if (_indexingTags) return;
    _indexingTags = true;
    notifyListeners();
    final files = _entries.where((entry) => !entry.isDirectory).toList();

    try {
      for (var index = 0; index < files.length; index += 6) {
        if (generation != _vaultGeneration) return;
        final batch = files.skip(index).take(6);
        await Future.wait(
          batch.map((entry) async {
            if (_tagIndex.containsKey(entry.uri)) return;
            try {
              final markdown = await _service.readDocument(entry.uri);
              if (generation == _vaultGeneration) {
                _tagIndex[entry.uri] = _extractTags(markdown);
              }
            } catch (_) {
              // One unreadable note must not prevent the rest of the Vault index.
            }
          }),
        );
        notifyListeners();
      }
    } finally {
      if (generation == _vaultGeneration) {
        _indexingTags = false;
        notifyListeners();
      }
    }
  }

  List<String> _extractTags(String markdown) {
    final tags = <String>{..._extractPropertyTags(markdown)};
    var body = markdown.replaceFirst(
      RegExp(r'^---\s*\n.*?\n---\s*\n', dotAll: true),
      '',
    );
    body = body.replaceAll(RegExp(r'```.*?```', dotAll: true), '');
    body = body.replaceAll(RegExp(r'%%.*?%%', dotAll: true), '');
    body = body.replaceAll(RegExp(r'`[^`\n]*`'), '');
    for (final match in RegExp(
      r'(^|\s)#([A-Za-z0-9_/\-\u0080-\uFFFF]+)',
      multiLine: true,
    ).allMatches(body)) {
      final tag = match.group(2);
      if (tag != null && RegExp(r'[^0-9]').hasMatch(tag)) tags.add(tag);
    }

    return _deduplicateTags(tags);
  }

  List<String> _extractPropertyTags(String markdown) {
    final tags = <String>{};
    final frontMatter = RegExp(
      r'^---\s*\n(.*?)\n---',
      dotAll: true,
    ).firstMatch(markdown)?.group(1);
    if (frontMatter != null) {
      try {
        final yaml = loadYaml(frontMatter);
        if (yaml is YamlMap) {
          final value = yaml['tags'];
          if (value is YamlList) {
            tags.addAll(value.map((tag) => tag.toString().trim()));
          } else if (value is String) {
            tags.addAll(
              value
                  .split(RegExp(r'[,\s]+'))
                  .map((tag) => tag.trim().replaceFirst(RegExp(r'^#'), '')),
            );
          }
        }
      } catch (_) {
        // Invalid YAML must not make an otherwise readable note disappear.
      }
    }

    return _deduplicateTags(tags);
  }

  List<String> _deduplicateTags(Iterable<String> tags) {
    final unique = <String, String>{};
    for (final tag in tags) {
      unique.putIfAbsent(tag.toLowerCase(), () => tag);
    }
    return unique.values.toList()..sort((a, b) => a.compareTo(b));
  }

  bool _isValidTag(String tag) {
    return tag.isNotEmpty &&
        RegExp(r'^[A-Za-z0-9_/\-\u0080-\uFFFF]+$').hasMatch(tag) &&
        RegExp(r'[^0-9]').hasMatch(tag);
  }

  String _replacePropertyTags(String markdown, List<String> tags) {
    final frontMatterMatch = RegExp(
      r'^---\s*\n(.*?)\n---(?=\n|$)',
      dotAll: true,
    ).firstMatch(markdown);
    if (frontMatterMatch == null) {
      if (tags.isEmpty) return markdown;
      final editor = YamlEditor('{}');
      editor.update(['tags'], tags);
      return '---\n${editor.toString()}\n---\n\n$markdown';
    }

    final yamlSource = frontMatterMatch.group(1)!;
    try {
      final parsed = loadYaml(yamlSource);
      final editor = YamlEditor(
        parsed == null || yamlSource.trim().isEmpty ? '{}' : yamlSource,
      );
      final hasTags = parsed is YamlMap && parsed.containsKey('tags');
      if (tags.isEmpty) {
        if (hasTags) editor.remove(['tags']);
      } else {
        editor.update(['tags'], tags);
      }
      final replacement = '---\n${editor.toString()}\n---';
      return markdown.replaceRange(
        frontMatterMatch.start,
        frontMatterMatch.end,
        replacement,
      );
    } catch (_) {
      throw const FormatException(
        'PropertiesのYAMLを解釈できないため、タグを変更できません。',
      );
    }
  }

  List<VaultTreeNode> _buildTree(List<SafDocumentEntry> entries) {
    final root = _MutableTreeNode.folder('');
    for (final entry in entries) {
      final parts = entry.relativePath.split('/');
      var current = root;
      for (var index = 0; index < parts.length; index++) {
        final part = parts[index];
        final isLast = index == parts.length - 1;
        if (isLast && !entry.isDirectory) {
          current.children[part] = _MutableTreeNode.file(part, entry.uri);
        } else {
          current = current.children.putIfAbsent(
            part,
            () => _MutableTreeNode.folder(part),
          );
        }
      }
    }
    return root.toImmutableChildren();
  }

  String _friendlyError(PlatformException error) {
    if (error.code == 'persist_permission_failed') {
      return 'このフォルダへの継続アクセスを許可できませんでした。別のフォルダを選んでください。';
    }
    return 'Vaultを開けませんでした。フォルダが移動されていないか確認してください。';
  }
}

class _MutableTreeNode {
  _MutableTreeNode.folder(this.name)
      : documentUri = null,
        isFolder = true;

  _MutableTreeNode.file(this.name, this.documentUri) : isFolder = false;

  final String name;
  final String? documentUri;
  final bool isFolder;
  final Map<String, _MutableTreeNode> children = {};

  List<VaultTreeNode> toImmutableChildren() {
    final sorted = children.values.toList()
      ..sort((a, b) {
        if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return sorted.map((node) {
      if (node.isFolder) {
        return VaultTreeNode.folder(
          name: node.name,
          children: node.toImmutableChildren(),
        );
      }
      return VaultTreeNode.file(
        name: node.name,
        documentId: node.documentUri!,
      );
    }).toList();
  }
}
