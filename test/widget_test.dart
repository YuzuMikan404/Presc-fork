import 'package:flutter_test/flutter_test.dart';
import 'package:presc/features/vault/data/models/vault_document.dart';

void main() {
  test('Markdown is projected into readable playback text', () {
    const document = VaultDocument(
      id: 'content://note',
      name: 'sample.md',
      path: 'sample.md',
      markdown: '''---
tags:
  - speech
---
# 見出し

> [!NOTE] メモ
> **重要な本文**と[[別のノート|表示名]]です。

- [x] 完了 #speech
''',
    );

    expect(document.speechText, contains('見出し'));
    expect(document.speechText, contains('重要な本文と表示名です。'));
    expect(document.speechText, contains('完了'));
    expect(document.speechText, isNot(contains('tags:')));
    expect(document.speechText, isNot(contains('#speech')));
  });
}
