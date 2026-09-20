class VaultDocument {
  const VaultDocument({
    required this.id,
    required this.name,
    required this.path,
    required this.markdown,
    this.tags = const [],
    this.propertyTags = const [],
    this.canWrite = false,
  });

  final String id;
  final String name;
  final String path;
  final String markdown;
  final List<String> tags;
  final List<String> propertyTags;
  final bool canWrite;

  String get title => name.replaceFirst(RegExp(r'\.(md|markdown)$'), '');

  String get speechText {
    var value = markdown;
    value = value.replaceFirst(
      RegExp(r'^---\s*\n.*?\n---\s*\n', dotAll: true),
      '',
    );
    value = value.replaceAll(RegExp(r'%%.*?%%', dotAll: true), '');
    value = value.replaceAll(RegExp(r'```.*?```', dotAll: true), '');
    value = value.replaceAllMapped(
      RegExp(r'!\[\[(.*?)\]\]'),
      (_) => '',
    );
    value = value.replaceAllMapped(
      RegExp(r'\[\[([^|\]]+)(?:\|([^\]]+))?\]\]'),
      (match) => match.group(2) ?? match.group(1) ?? '',
    );
    value = value.replaceAllMapped(
      RegExp(r'!?\[(.*?)\]\([^)]*\)'),
      (match) => match.group(1) ?? '',
    );
    value = value.replaceAll(RegExp(r'^\s*>\s*\[!.*?\][+-]?\s*', multiLine: true), '');
    value = value.replaceAll(RegExp(r'^\s*>\s?', multiLine: true), '');
    value = value.replaceAll(RegExp(r'^\s*#{1,6}\s+', multiLine: true), '');
    value = value.replaceAll(RegExp(r'^\s*[-*+]\s+\[[ xX]\]\s+', multiLine: true), '');
    value = value.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '');
    value = value.replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '');
    value = value.replaceAll(RegExp(r'(\*\*|__|~~|==|`|\*|_)'), '');
    value = value.replaceAll(RegExp(r'(^|\s)#[^\s#]+'), ' ');
    value = value.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return value.trim();
  }
}

class VaultTreeNode {
  const VaultTreeNode.folder({
    required this.name,
    this.children = const [],
  })  : documentId = null,
        isFolder = true;

  const VaultTreeNode.file({
    required this.name,
    required this.documentId,
  })  : children = const [],
        isFolder = false;

  final String name;
  final String? documentId;
  final bool isFolder;
  final List<VaultTreeNode> children;
}
