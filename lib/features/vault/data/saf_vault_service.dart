import 'package:flutter/services.dart';

class SafVaultService {
  static const _channel = MethodChannel('com.sakusaku3939.presc/saf_vault');

  Future<SafVaultSelection?> pickVault() async {
    final result = await _channel.invokeMapMethod<String, dynamic>('pickVault');
    if (result == null) return null;
    return SafVaultSelection(
      treeUri: result['treeUri'] as String,
      displayName: result['displayName'] as String? ?? 'Vault',
      canWrite: result['canWrite'] as bool? ?? false,
    );
  }

  Future<String> getVaultName(String treeUri) async {
    return await _channel.invokeMethod<String>(
          'getVaultName',
          {'treeUri': treeUri},
        ) ??
        'Vault';
  }

  Future<List<SafDocumentEntry>> listDocuments(String treeUri) async {
    final result = await _channel.invokeListMethod<dynamic>(
          'listDocuments',
          {'treeUri': treeUri},
        ) ??
        const [];
    return result
        .cast<Map<dynamic, dynamic>>()
        .map(SafDocumentEntry.fromMap)
        .toList();
  }

  Future<String> readDocument(String uri) async {
    final content =
        await _channel.invokeMethod<String>('readDocument', {'uri': uri}) ?? '';
    return content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  }

  Future<void> writeDocument(String uri, String content) async {
    await _channel.invokeMethod<bool>(
      'writeDocument',
      {'uri': uri, 'content': content},
    );
  }
}

class SafVaultSelection {
  const SafVaultSelection({
    required this.treeUri,
    required this.displayName,
    required this.canWrite,
  });

  final String treeUri;
  final String displayName;
  final bool canWrite;
}

class SafDocumentEntry {
  const SafDocumentEntry({
    required this.uri,
    required this.documentId,
    required this.name,
    required this.relativePath,
    required this.mimeType,
    required this.isDirectory,
    required this.lastModified,
    required this.size,
    required this.canWrite,
  });

  factory SafDocumentEntry.fromMap(Map<dynamic, dynamic> map) {
    return SafDocumentEntry(
      uri: map['uri'] as String,
      documentId: map['documentId'] as String,
      name: map['name'] as String,
      relativePath: map['relativePath'] as String,
      mimeType: map['mimeType'] as String? ?? '',
      isDirectory: map['isDirectory'] as bool? ?? false,
      lastModified: map['lastModified'] as int? ?? 0,
      size: map['size'] as int? ?? 0,
      canWrite: map['canWrite'] as bool? ?? false,
    );
  }

  final String uri;
  final String documentId;
  final String name;
  final String relativePath;
  final String mimeType;
  final bool isDirectory;
  final int lastModified;
  final int size;
  final bool canWrite;
}
