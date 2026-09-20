import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/color_constants.dart';

class MarkdownReadingView extends StatelessWidget {
  const MarkdownReadingView({
    super.key,
    required this.markdown,
    required this.tags,
    this.editableTags = const [],
    this.onAddTag,
    this.onRemoveTag,
    this.onOpenWikiLink,
  });

  final String markdown;
  final List<String> tags;
  final List<String> editableTags;
  final VoidCallback? onAddTag;
  final ValueChanged<String>? onRemoveTag;
  final Future<bool> Function(String target)? onOpenWikiLink;

  @override
  Widget build(BuildContext context) {
    final content = _prepareObsidianMarkdown(_withoutFrontMatter(markdown));

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
      children: [
        if (_hasFrontMatter(markdown) || tags.isNotEmpty || onAddTag != null)
          _properties(context),
        MarkdownBody(
          data: content,
          selectable: true,
          extensionSet: md.ExtensionSet.gitHubFlavored,
          inlineSyntaxes: [_HighlightSyntax()],
          builders: {'mark': _HighlightBuilder()},
          styleSheet: _styleSheet(context),
          checkboxBuilder: (checked) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Icon(
              checked ? Icons.check_box : Icons.check_box_outline_blank,
              size: 20,
              color: checked ? ColorConstants.mainColor : Colors.grey[500],
            ),
          ),
          onTapLink: (text, href, title) {
            unawaited(_openLink(context, href));
          },
        ),
      ],
    );
  }

  MarkdownStyleSheet _styleSheet(BuildContext context) {
    const bodyColor = Color(0xFF424242);
    const borderColor = Color(0xFFE1E1E1);
    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: const TextStyle(color: bodyColor, fontSize: 16, height: 1.75),
      a: const TextStyle(
        color: ColorConstants.mainColor,
        decoration: TextDecoration.underline,
        decorationColor: ColorConstants.mainColor,
      ),
      h1: const TextStyle(
        color: Color(0xFF202020),
        fontSize: 30,
        height: 1.35,
        fontWeight: FontWeight.w700,
      ),
      h2: const TextStyle(
        color: Color(0xFF252525),
        fontSize: 24,
        height: 1.4,
        fontWeight: FontWeight.w700,
      ),
      h3: const TextStyle(
        color: Color(0xFF2A2A2A),
        fontSize: 20,
        height: 1.45,
        fontWeight: FontWeight.w600,
      ),
      h1Padding: const EdgeInsets.only(top: 10, bottom: 8),
      h2Padding: const EdgeInsets.only(top: 18, bottom: 5),
      h3Padding: const EdgeInsets.only(top: 14, bottom: 3),
      blockSpacing: 14,
      listIndent: 24,
      listBullet: const TextStyle(color: bodyColor, fontSize: 16),
      blockquote: const TextStyle(
        color: Color(0xFF48545B),
        fontSize: 15,
        height: 1.65,
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      blockquoteDecoration: BoxDecoration(
        color: const Color(0xFFFFF2ED),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: ColorConstants.mainColor, width: 4),
        ),
      ),
      code: const TextStyle(
        color: Color(0xFF7B3120),
        backgroundColor: Color(0xFFF3F1F0),
        fontFamily: 'monospace',
        fontSize: 14,
      ),
      codeblockPadding: const EdgeInsets.all(14),
      codeblockDecoration: BoxDecoration(
        color: const Color(0xFFF5F4F3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      tableHead: const TextStyle(
        color: Color(0xFF2F2F2F),
        fontWeight: FontWeight.w700,
      ),
      tableBody: const TextStyle(color: bodyColor, height: 1.45),
      tableBorder: TableBorder.all(color: borderColor),
      tableCellsPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      horizontalRuleDecoration: const BoxDecoration(
        border: Border(top: BorderSide(color: borderColor)),
      ),
    );
  }

  Widget _properties(BuildContext context) {
    final date = RegExp(
      r'^date:\s*(.+)$',
      multiLine: true,
    ).firstMatch(markdown)?.group(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, size: 17, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                'Properties',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (tags.isNotEmpty || onAddTag != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final tag in tags)
                  InputChip(
                    visualDensity: VisualDensity.compact,
                    side: BorderSide.none,
                    backgroundColor: const Color(0xFFFFE7DE),
                    label: Text(
                      '#$tag',
                      style: const TextStyle(
                        color: Color(0xFFB54826),
                        fontSize: 12,
                      ),
                    ),
                    deleteIcon: editableTags.contains(tag) && onRemoveTag != null
                        ? const Icon(Icons.close, size: 15)
                        : null,
                    onDeleted: editableTags.contains(tag) && onRemoveTag != null
                        ? () => onRemoveTag!(tag)
                        : null,
                  ),
                if (onAddTag != null)
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.add, size: 16),
                    label: const Text('タグ'),
                    onPressed: onAddTag,
                  ),
              ],
            ),
          ],
          if (date != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'date',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(date, style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openLink(BuildContext context, String? href) async {
    if (href == null || href.isEmpty) return;
    final uri = Uri.tryParse(href);
    if (uri == null) return;

    if (uri.scheme == 'presc-wiki') {
      final target = Uri.decodeComponent(uri.path);
      await onOpenWikiLink?.call(target);
      return;
    }

    final relativePath = uri.path.toLowerCase();
    final lastSegment = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    if (uri.scheme.isEmpty &&
        !href.startsWith('#') &&
        (relativePath.endsWith('.md') ||
            relativePath.endsWith('.markdown') ||
            !lastSegment.contains('.'))) {
      await onOpenWikiLink?.call(Uri.decodeComponent(href));
      return;
    }

    if (uri.scheme == 'http' ||
        uri.scheme == 'https' ||
        uri.scheme == 'mailto') {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('リンクを開けませんでした。')),
        );
      }
    }
  }

  String _prepareObsidianMarkdown(String source) {
    final output = <String>[];
    var insideFence = false;

    for (var line in source.split('\n')) {
      if (line.trimLeft().startsWith('```') ||
          line.trimLeft().startsWith('~~~')) {
        insideFence = !insideFence;
        output.add(line);
        continue;
      }
      if (insideFence) {
        output.add(line);
        continue;
      }

      final callout = RegExp(
        r'^>\s*\[!([^\]]+)\][+-]?\s*(.*)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (callout != null) {
        final type = callout.group(1)!.toLowerCase();
        final customTitle = callout.group(2)!.trim();
        line = '> **${_calloutIcon(type)} ${customTitle.isEmpty ? _calloutTitle(type) : customTitle}**';
      }

      line = line.replaceAllMapped(
        RegExp(r'!\[\[([^\]]+)\]\]'),
        (match) => '*🖼 ${match.group(1)!.split('|').last}*',
      );
      line = line.replaceAllMapped(
        RegExp(r'\[\[([^\]]+)\]\]'),
        (match) {
          final raw = match.group(1)!;
          final divider = raw.indexOf('|');
          final target = divider == -1 ? raw : raw.substring(0, divider);
          final label = divider == -1 ? raw : raw.substring(divider + 1);
          return '[$label](presc-wiki:${Uri.encodeComponent(target)})';
        },
      );
      output.add(line);
    }
    return output.join('\n');
  }

  String _withoutFrontMatter(String source) {
    return source.replaceFirst(
      RegExp(r'^---\s*\n.*?\n---\s*\n?', dotAll: true),
      '',
    );
  }

  bool _hasFrontMatter(String source) => source.startsWith('---\n');

  String _calloutIcon(String type) {
    if (type == 'warning' || type == 'caution' || type == 'danger') return '⚠';
    if (type == 'tip' || type == 'hint') return '💡';
    if (type == 'todo' || type == 'check') return '☑';
    return 'ⓘ';
  }

  String _calloutTitle(String type) {
    if (type == 'warning' || type == 'caution') return '注意';
    if (type == 'danger' || type == 'error') return '警告';
    if (type == 'tip' || type == 'hint') return 'ヒント';
    if (type == 'todo') return 'To-do';
    return 'ノート';
  }
}

class _HighlightSyntax extends md.InlineSyntax {
  _HighlightSyntax() : super(r'==(.+?)==');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('mark', match.group(1)!));
    return true;
  }
}

class _HighlightBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFE49A),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(element.textContent, style: preferredStyle),
      ),
    );
  }
}
