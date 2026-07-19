---
name: setup-ruby-hooks
description: Ruby プロジェクトに Claude Code hooks をセットアップする
license: Apache-2.0
---

# setup-ruby-hooks

Ruby プロジェクトの `.claude/` ディレクトリに hooks の設定ファイルとスクリプトを配置するスキルです。

## 実行内容（自動実行）

このスキルが配置されているディレクトリ（`skills/setup-ruby-hooks/`）以下のファイルをプロジェクトにコピーする。

### 配置先

| テンプレート | 配置先 |
|---|---|
| `claude-settings.json` | `.claude/settings.json` |
| `hooks/protect-sig-files.sh` | `.claude/hooks/protect-sig-files.sh` |
| `hooks/pre-commit-check.sh` | `.claude/hooks/pre-commit-check.sh` |
| `hooks/rbs-inline.sh` | `.claude/hooks/rbs-inline.sh` |
| `hooks/claude-code-web-session-start.sh` | `.claude/hooks/claude-code-web-session-start.sh` |

配置後、以下を実行してスクリプトに実行権限を付与する:

```bash
chmod +x .claude/hooks/*.sh
```

### 各 hook の役割

| ファイル | タイミング | 役割 |
|---|---|---|
| `protect-sig-files.sh` | PreToolUse | `sig/` への直接編集と手動 rbs-inline 実行を禁止する |
| `pre-commit-check.sh` | PreToolUse | `git commit` 前に rbs-inline と rake を実行する |
| `rbs-inline.sh` | PostToolUse | `lib/*.rb` 編集後に自動で `.rbs` ファイルを生成する |
| `claude-code-web-session-start.sh` | SessionStart | Claude Code on the web での Bundler + Ruby 3.3 互換性問題を回避する |
