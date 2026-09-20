# Presc Markdown Vault 設計

## 目標

Android 端末上の Obsidian Vault または Markdown フォルダを、ファイルのコピーやアプリ内DBへの取り込みを行わずに直接参照する。閲覧後は、既存 Presc の読み上げ画面へ本文を渡す。

## 画面構成

- 初回起動ではフォルダ選択だけを提示する。
- 閲覧画面は原稿を主役にし、ファイルとタグは左ドロワーに格納する。
- ファイルはフォルダ階層、タグは `parent/child` の階層で表示する。
- `[[Wiki Link]]` で移動したノートは「戻る／進む」で辿り直せる。
- 読み上げボタンから既存の `PlaybackPage` を開く。

## データアクセス

Android の Storage Access Framework（`ACTION_OPEN_DOCUMENT_TREE`）を使用する。選択された Tree URI の永続アクセス権を保存し、次回起動でも同じ Vault を開く。

- 一覧取得、本文読込、Properties のタグ更新は `content://` URI に対して行う。
- Markdown本文を別領域へコピーしない。
- `.obsidian` はアプリ用設定なので一覧と索引から除外する。
- ファイルプロバイダーが書込を許可しない場合は閲覧専用にする。
- タグ保存直前に元ファイルを再読込し、Obsidian等による直近の本文変更を上書きしないよう差分をマージする。

## Markdown / Obsidian 互換

GFM を基礎に、見出し、強調、取り消し線、リスト、タスクリスト、表、引用、コード、リンク、画像URLを表示する。追加で次を変換する。

- `[[Note]]` / `[[Note|Label]]`: Vault 内の Markdown ファイルへ移動
- `==Highlight==`: ハイライト表示
- `> [!NOTE]`: callout 風の引用表示
- `![[asset]]`: 現段階では添付名のプレースホルダー表示
- YAML frontmatter: Properties として分離し、`tags` を読込・更新

## 現段階の制約

- SAF 配下の相対画像と Obsidian 添付ファイルの実画像表示は未実装。
- 見出しアンカー、ブロック参照、ノート埋め込みはリンク先ノートを開くところまで。
- Markdown本文のソース編集、作成、移動、削除は未実装。Properties のタグだけを書き換える。
