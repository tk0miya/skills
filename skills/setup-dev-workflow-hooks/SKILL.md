---
name: setup-dev-workflow-hooks
description: 開発ワークフロー向け Claude Code hooks をセットアップする
license: Apache-2.0
---

# setup-dev-workflow-hooks

プロジェクトの `.claude/` ディレクトリに開発ワークフロー向け hooks と permissions の設定ファイルとスクリプトを配置するスキルです。

既に `.claude/settings.json` が存在する場合は、hooks と permissions の内容をマージする。

## 実行内容（自動実行）

このスキルが配置されているディレクトリ（`skills/setup-dev-workflow-hooks/`）以下のファイルをプロジェクトにコピーする。

### 配置先

| テンプレート | 配置先 |
|---|---|
| `hooks/self-review.sh` | `.claude/hooks/self-review.sh` |

`.claude/settings.json` が既に存在する場合は、`claude-settings.json` の hooks 定義と `permissions.allow` をマージする（`permissions.allow` は重複を除いて既存の配列に追記する）。
存在しない場合は `claude-settings.json` を `.claude/settings.json` としてコピーする。

配置後、以下を実行してスクリプトに実行権限を付与する:

```bash
chmod +x .claude/hooks/self-review.sh
```

### 各 hook の役割

| ファイル | タイミング | 役割 |
|---|---|---|
| `self-review.sh` | PreToolUse | `git commit` の前にコードレビューを起動する。`self-review` スキルがあればそれを、無ければバンドルスキルの `code-review` にフォールバックする。レビュー済みの変更セットはコミットを通す（無限ブロックを防ぐ） |

### pre-commit check との実行順序

プロジェクトに `.claude/hooks/pre-commit-check.sh`（`setup-ruby-hooks` などが配置する）がある場合、そのチェックが通ったあとにセルフレビューが動く。チェックで差し戻される変更をレビューしても無駄になるため。

PreToolUse hooks は settings.json の並び順に関係なく並列実行されるので、順序は `pre-commit-check.sh` が変更セット単位で `.git/` に記録する結果で決まる。

| 記録 | 書き込む側 | 意味 |
|---|---|---|
| `.git/pre-commit-check-passed` | `pre-commit-check.sh` | この変更セットはチェックを通った → セルフレビューを要求する |
| `.git/pre-commit-check-failed` | `pre-commit-check.sh` | この変更セットはチェックで落ちた → 通るまでセルフレビューを保留する |
| `.git/self-review-check-deferred` | `self-review.sh` | この変更セットで結果待ちを 1 回消費した → 失敗が記録されていなければ次の試行では待たない |

結果がまだ出ていない初回のコミット試行では、いったんコミットを拒否して「同じコミットをもう一度実行する」よう伝える（並列実行のため、この時点ではチェックの結果を読めない）。この待ちは変更セットごとに 1 回までで、結果を記録しない `pre-commit-check.sh` を使っているプロジェクトでもコミットが詰まることはない。

`pre-commit-check.sh` が無いプロジェクトでは、従来どおりチェックを待たずにレビューを要求する。

### permissions の役割

| ルール | 役割 |
|---|---|
| `RemoteTrigger` | Claude Code on the web でセルフチェックイン（「send later」）を毎回確認せず自動許可する |
