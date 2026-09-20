import 'package:flutter/material.dart';
import 'package:presc/features/playback/ui/pages/playback_page.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/color_constants.dart';
import '../providers/vault_prototype_provider.dart';
import '../widgets/markdown_reading_view.dart';
import '../widgets/vault_drawer.dart';

class VaultHomePage extends StatefulWidget {
  const VaultHomePage({super.key});

  @override
  State<VaultHomePage> createState() => _VaultHomePageState();
}

class _VaultHomePageState extends State<VaultHomePage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Consumer<VaultProvider>(
      builder: (context, model, child) {
        if (!model.initialized) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!model.hasVault) return _setupScreen(context, model);

        final document = model.selectedDocument;
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: Colors.white,
          drawer: const VaultDrawer(),
          appBar: AppBar(
            toolbarHeight: 64,
            leading: IconButton(
              tooltip: 'ファイルを開く',
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              icon: const Icon(Icons.menu),
            ),
            titleSpacing: 4,
            title: document == null
                ? Text(
                    model.vaultName,
                    style: const TextStyle(
                      color: Color(0xFF202020),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF202020),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        document.path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
            actions: [
              IconButton(
                tooltip: '前のノートに戻る',
                onPressed: model.canGoBack ? model.goBack : null,
                icon: const Icon(Icons.arrow_back),
              ),
              IconButton(
                tooltip: '次のノートに進む',
                onPressed: model.canGoForward ? model.goForward : null,
                icon: const Icon(Icons.arrow_forward),
              ),
              IconButton(
                tooltip: '再読み込み',
                onPressed: model.loading ? null : model.refresh,
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: Stack(
            children: [
              if (document == null)
                _emptyVault(context, model)
              else
                MarkdownReadingView(
                  key: ValueKey(document.id),
                  markdown: document.markdown,
                  tags: document.tags,
                  editableTags: document.propertyTags,
                  onAddTag: document.canWrite && !model.saving
                      ? () => _showAddTagDialog(context, model)
                      : null,
                  onRemoveTag: document.canWrite && !model.saving
                      ? model.removeTag
                      : null,
                  onOpenWikiLink: model.openWikiLink,
                ),
              if (model.loadingDocument)
                Container(
                  color: Colors.white.withValues(alpha: 0.78),
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(),
                ),
              if (model.saving)
                const Positioned(
                  top: 8,
                  right: 12,
                  child: Chip(
                    avatar: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    label: Text('保存中'),
                  ),
                ),
              if (model.errorMessage != null)
                _errorBanner(context, model),
            ],
          ),
          floatingActionButton: document == null
              ? null
              : SafeArea(
                  child: FloatingActionButton.extended(
                    tooltip: '読み上げを開始',
                    backgroundColor: ColorConstants.mainColor,
                    foregroundColor: Colors.white,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PlaybackPage(
                            title: document.title,
                            content: document.speechText,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('読み上げ'),
                  ),
                ),
        );
      },
    );
  }

  Widget _setupScreen(
    BuildContext context,
    VaultProvider model,
  ) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFEEE8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.folder_open,
                      size: 42,
                      color: ColorConstants.mainColor,
                    ),
                  ),
                  const SizedBox(height: 26),
                  const Text(
                    'Markdownフォルダを開く',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF222222),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '普段使っているObsidian Vault、またはMarkdownファイルをまとめたフォルダを選んでください。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[700],
                      height: 1.65,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 26),
                  _privacyNote(),
                  if (model.errorMessage != null) ...[
                    const SizedBox(height: 18),
                    Text(
                      model.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: ColorConstants.mainColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: model.loading ? null : model.chooseVault,
                      icon: model.loading
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.folder_open),
                      label: Text(model.loading ? '読み込み中…' : 'フォルダを選択'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _privacyNote() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 21, color: Color(0xFF52616B)),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'ファイルはコピーやアップロードをせず、選んだフォルダから直接読み込みます。',
              style: TextStyle(
                color: Color(0xFF52616B),
                height: 1.5,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyVault(BuildContext context, VaultProvider model) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.note_alt_outlined, size: 54, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              model.loading ? 'Markdownを探しています…' : 'Markdownファイルがありません',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            if (!model.loading) ...[
              const SizedBox(height: 8),
              Text(
                '別のフォルダを選ぶか、このフォルダに .md ファイルを追加してください。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], height: 1.5),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: model.chooseVault,
                icon: const Icon(Icons.folder_open),
                label: const Text('別のフォルダを選ぶ'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _errorBanner(
    BuildContext context,
    VaultProvider model,
  ) {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: Material(
        color: const Color(0xFF3B3030),
        borderRadius: BorderRadius.circular(12),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  model.errorMessage!,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              IconButton(
                tooltip: '閉じる',
                onPressed: model.clearError,
                icon: const Icon(Icons.close, color: Colors.white, size: 19),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddTagDialog(
    BuildContext context,
    VaultProvider model,
  ) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('タグを追加'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              prefixText: '#',
              hintText: 'project/mobile',
              helperText: 'ネストする場合は / を使います',
            ),
            onSubmitted: (text) => Navigator.pop(dialogContext, text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('追加'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (value != null && value.trim().isNotEmpty) {
      await model.addTag(value);
    }
  }
}
