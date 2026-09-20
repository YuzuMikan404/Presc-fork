import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/color_constants.dart';
import '../../data/models/vault_document.dart';
import '../providers/vault_prototype_provider.dart';

class VaultDrawer extends StatefulWidget {
  const VaultDrawer({super.key});

  @override
  State<VaultDrawer> createState() => _VaultDrawerState();
}

class _VaultDrawerState extends State<VaultDrawer> {
  final Set<String> _expandedFolders = {};
  final Set<String> _expandedTags = {};
  bool _seededExpandedFolders = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seededExpandedFolders) return;
    _seededExpandedFolders = true;
    _expandSelected(context.read<VaultProvider>());
  }

  void _expandSelected(VaultProvider model) {
    final path = model.selectedDocument?.path;
    if (path == null) return;
    final parts = path.split('/');
    var current = '';
    for (final part in parts.take(parts.length - 1)) {
      current = current.isEmpty ? part : '$current/$part';
      _expandedFolders.add(current);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.sizeOf(context).width > 430
          ? 380
          : MediaQuery.sizeOf(context).width * 0.88,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          children: [
            _header(context),
            _vaultSelector(context),
            _modeSelector(context),
            Expanded(
              child: Consumer<VaultProvider>(
                builder: (context, model, child) {
                  return model.panelMode == VaultPanelMode.files
                      ? _fileTree(context, model)
                      : _tagList(context, model);
                },
              ),
            ),
            _footer(context),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.only(left: 18, right: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Image.asset('assets/images/logo.png', width: 112),
          const Spacer(),
          IconButton(
            tooltip: '閉じる',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _vaultSelector(BuildContext context) {
    return Consumer<VaultProvider>(
      builder: (context, model, child) {
        return Container(
          margin: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.folder_open, color: ColorConstants.mainColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '現在のVault',
                      style: TextStyle(color: Colors.black54, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      model.vaultName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: model.loading
                    ? null
                    : () async {
                        final changed = await model.chooseVault();
                        if (changed && context.mounted) {
                          setState(() {
                            _expandedFolders.clear();
                            _expandSelected(model);
                          });
                        }
                      },
                child: const Text('変更'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _modeSelector(BuildContext context) {
    return Consumer<VaultProvider>(
      builder: (context, model, child) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Row(
            children: [
              Expanded(
                child: _modeButton(
                  context,
                  icon: Icons.account_tree_outlined,
                  label: 'ファイル',
                  selected: model.panelMode == VaultPanelMode.files,
                  onPressed: () =>
                      model.changePanelMode(VaultPanelMode.files),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _modeButton(
                  context,
                  icon: Icons.tag,
                  label: 'タグ',
                  selected: model.panelMode == VaultPanelMode.tags,
                  onPressed: () => model.changePanelMode(VaultPanelMode.tags),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _modeButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: selected ? const Color(0xFFFFE8E0) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? ColorConstants.mainColor : Colors.grey[700],
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color:
                      selected ? const Color(0xFFB34523) : Colors.grey[800],
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fileTree(BuildContext context, VaultProvider model) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 7),
          child: Row(
            children: [
              Text(
                'ファイル',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '再読み込み',
                onPressed: model.loading ? null : model.refresh,
                icon: const Icon(Icons.refresh, size: 19),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'すべて折りたたむ',
                onPressed: () => setState(_expandedFolders.clear),
                icon: const Icon(Icons.unfold_less, size: 19),
              ),
            ],
          ),
        ),
        if (model.loading)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (model.tree.isEmpty)
          Padding(
            padding: const EdgeInsets.all(28),
            child: Text(
              'このフォルダにはMarkdownファイルがありません',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          )
        else
          for (final node in model.tree)
            _treeNode(
              context,
              model,
              node,
              depth: 0,
              nodePath: node.name,
            ),
      ],
    );
  }

  Widget _treeNode(
    BuildContext context,
    VaultProvider model,
    VaultTreeNode node, {
    required int depth,
    required String nodePath,
  }) {
    if (node.isFolder) {
      final expanded = _expandedFolders.contains(nodePath);
      return Column(
        children: [
          _treeRow(
            depth: depth,
            icon: Icons.folder_outlined,
            leading: expanded ? Icons.expand_more : Icons.chevron_right,
            label: node.name,
            onTap: () {
              setState(() {
                if (expanded) {
                  _expandedFolders.remove(nodePath);
                } else {
                  _expandedFolders.add(nodePath);
                }
              });
            },
          ),
          if (expanded)
            for (final child in node.children)
              _treeNode(
                context,
                model,
                child,
                depth: depth + 1,
                nodePath: '$nodePath/${child.name}',
              ),
        ],
      );
    }

    final selected = model.selectedDocument?.id == node.documentId;
    return _treeRow(
      depth: depth,
      icon: Icons.description_outlined,
      label: node.name,
      selected: selected,
      onTap: () {
        Navigator.pop(context);
        model.selectDocument(node.documentId!);
      },
    );
  }

  Widget _treeRow({
    required int depth,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    IconData? leading,
    bool selected = false,
  }) {
    return Material(
      color: selected ? const Color(0xFFFFE8E0) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: EdgeInsets.only(left: 8.0 + depth * 22, right: 8),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: leading == null
                    ? null
                    : Icon(leading, size: 19, color: Colors.grey[600]),
              ),
              Icon(
                icon,
                size: 19,
                color: selected ? ColorConstants.mainColor : Colors.grey[600],
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? const Color(0xFFB34523) : null,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tagList(BuildContext context, VaultProvider model) {
    final roots = _buildTagTree(model.tagCounts);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
          child: Text(
            'Vault内のタグ',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (model.indexingTags)
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 0, 8, 10),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (!model.indexingTags && roots.isEmpty)
          Padding(
            padding: const EdgeInsets.all(28),
            child: Text(
              'タグはまだ見つかっていません',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        for (final root in roots) _tagNode(context, model, root, depth: 0),
      ],
    );
  }

  Widget _tagNode(
    BuildContext context,
    VaultProvider model,
    _TagTreeNode node, {
    required int depth,
  }) {
    final expanded = _expandedTags.contains(node.fullPath);
    final hasChildren = node.children.isNotEmpty;
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _showTaggedDocuments(context, model, node.fullPath),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: EdgeInsets.only(left: 4.0 + depth * 20, right: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: hasChildren
                        ? IconButton(
                            tooltip: expanded ? '折りたたむ' : '展開',
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              setState(() {
                                if (expanded) {
                                  _expandedTags.remove(node.fullPath);
                                } else {
                                  _expandedTags.add(node.fullPath);
                                }
                              });
                            },
                            icon: Icon(
                              expanded ? Icons.expand_more : Icons.chevron_right,
                              size: 19,
                            ),
                          )
                        : null,
                  ),
                  const Icon(Icons.tag, size: 18, color: Color(0xFF696969)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      node.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${node.totalCount}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded)
          for (final child in node.sortedChildren)
            _tagNode(context, model, child, depth: depth + 1),
      ],
    );
  }

  List<_TagTreeNode> _buildTagTree(Map<String, int> counts) {
    final roots = <String, _TagTreeNode>{};
    for (final entry in counts.entries) {
      final parts = entry.key.split('/').where((part) => part.isNotEmpty).toList();
      if (parts.isEmpty) continue;
      var path = '';
      Map<String, _TagTreeNode> level = roots;
      _TagTreeNode? current;
      for (final part in parts) {
        final candidatePath = path.isEmpty ? part : '$path/$part';
        current = level.putIfAbsent(
          part.toLowerCase(),
          () => _TagTreeNode(part, candidatePath),
        );
        path = current.fullPath;
        level = current.children;
      }
      current?.directCount += entry.value;
    }
    final sorted = roots.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return sorted;
  }

  Future<void> _showTaggedDocuments(
    BuildContext context,
    VaultProvider model,
    String tag,
  ) async {
    final documents = model.documentsForTag(tag);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                child: Text(
                  '#$tag',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: documents.length,
                  itemBuilder: (context, index) {
                    final document = documents[index];
                    return ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(document.name),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        Navigator.pop(context);
                        model.selectDocument(document.documentId!);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _footer(BuildContext context) {
    return Consumer<VaultProvider>(
      builder: (context, model, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey[200]!)),
          ),
          child: Row(
            children: [
              Icon(
                model.vaultCanWrite
                    ? Icons.sync_alt_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  model.vaultCanWrite ? 'Vaultを直接参照・編集' : '読み取り専用で参照',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TagTreeNode {
  _TagTreeNode(this.name, this.fullPath);

  final String name;
  final String fullPath;
  final Map<String, _TagTreeNode> children = {};
  int directCount = 0;

  int get totalCount => directCount +
      children.values.fold(0, (total, child) => total + child.totalCount);

  List<_TagTreeNode> get sortedChildren {
    return children.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }
}
