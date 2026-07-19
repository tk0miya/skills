---
name: setup-dev-workflow-hooks
description: 開発ワークフロー向け Claude Code hooks をセットアップする
license: Apache-2.0
---

# setup-dev-workflow-hooks

プロジェクトの `.claude/` ディレクトリに開発ワークフロー向け hooks の設定ファイルとスクリプトを配置するスキルです。

既に `.claude/settings.json` が存在する場合は、hooks の内容をマージする。

## 実行内容（自動実行）

このスキルが配置されているディレクトリ（`skills/setup-dev-workflow-hooks/`）以下のファイルをプロジェクトにコピーする。

### 配置先

| テンプレート | 配置先 |
|---|---|
| `hooks/self-review.sh` | `.claude/hooks/self-review.sh` |

`.claude/settings.json` が既に存在する場合は、`claude-settings.json` の hooks 定義をマージする。
存在しない場合は `claude-settings.json` を `.claude/settings.json` としてコピーする。

配置後、以下を実行してスクリプトに実行権限を付与する:

```bash
chmod +x .claude/hooks/self-review.sh
```

### 各 hook の役割

| ファイル | タイミング | 役割 |
|---|---|---|
| `self-review.sh` | PreToolUse | `git commit` の前にコードレビューを起動する。`self-review` スキルがあればそれを、無ければバンドルスキルの `code-review` にフォールバックする。レビュー済みの変更セットはコミットを通す（無限ブロックを防ぐ） |
