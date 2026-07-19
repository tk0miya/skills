---
name: setup-github-workflows
description: 言語非依存の汎用 GitHub Actions / Dependabot 設定とブランチ保護をセットアップする
license: Apache-2.0
---

# setup-github-workflows

リポジトリに、言語非依存の汎用 GitHub Actions ワークフロー・Dependabot 設定・
ブランチ保護を一括でセットアップするスキルです。

**GitHub リポジトリが既に存在し、`main` がまだ保護されていない状態**で 1 回実行することを
想定しています（このスキルがブランチ保護を追加するため、保護はこの実行より後に有効になる）。

## 前提条件

- 対象リポジトリが GitHub 上に作成済みで、ローカルから push 可能であること
- `main`（デフォルトブランチ）がまだ保護 ruleset を持たないこと
- `gh` CLI が認証済みであること（`gh auth status`）

## 手順

### 1. ファイルを配置

このスキルが配置されているディレクトリ（`skills/setup-github-workflows/`）以下を
プロジェクトの `.github/` にコピーする。

| テンプレート | 配置先 |
|---|---|
| `workflows/workflow-lint.yml` | `.github/workflows/workflow-lint.yml` |
| `workflows/auto-merge.yml` | `.github/workflows/auto-merge.yml` |
| `workflows/dependabot-auto-label.yml` | `.github/workflows/dependabot-auto-label.yml` |
| `dependabot.yml` | `.github/dependabot.yml` |

### 2. commit & push

配置したファイルを commit し、`main` に push する。**ブランチ保護を追加する前に**行う
（保護後は `main` への直接 push ができなくなるため）。

```bash
git add .github
git commit -m "ci: set up GitHub Actions workflows and Dependabot"
git push
```

### 3. GitHub 側のセットアップ

`setup.sh` を実行して、ブランチ保護・ラベル・secret・Dependabot 有効化などを構成する。

```bash
bash {SKILL_DIR}/setup.sh --repo OWNER/NAME
```

owner 固有の値は環境変数で上書きできる:

| 環境変数 | デフォルト |
|---|---|
| `PR_AUTO_MERGER_CLIENT_ID` | `Iv23liInIOSVmvfZicez` |
| `PR_AUTO_MERGER_PRIVATE_KEY_PATH` | `~/Dropbox/Personal/secrets/pull-request-auto-merging-bot.private-key.pem` |

`setup.sh` が構成する内容:

- ベースの branch protection ruleset（`branch-protection`）を作成
  - PR 必須（`pull_request`）、`deletion` / `non_fast_forward` 禁止
  - required status checks: `actionlint` / `zizmor`（`workflow-lint.yml` の出力）
- repo 設定 `allow_auto_merge` / `delete_branch_on_merge` を有効化
- `auto-merge` ラベルを作成
- Dependabot を有効化（`vulnerability-alerts` / `automated-security-fixes`）
- Actions に PR approve 権限を付与
- `PR_AUTO_MERGER_APP_ID`（Variable）と `PR_AUTO_MERGER_PRIVATE_KEY`（Secret、dependabot スコープ含む）を登録

## 各ファイルの役割

| ファイル | 役割 |
|---|---|
| `workflow-lint.yml` | push / pull_request 時に GitHub Actions ワークフローを actionlint と zizmor で lint する |
| `auto-merge.yml` | `auto-merge` ラベルが付いた PR を自動で approve & auto-merge する |
| `dependabot-auto-label.yml` | Dependabot の minor / patch 更新 PR に `auto-merge` ラベルを自動付与する |
| `dependabot.yml` | GitHub Actions の依存を週次で更新する |

## 前提条件チェックリストの出力

実行完了後に以下をチェックリスト形式で出力する（`setup.sh` で自動化されない、事前の手作業）。

- [ ] GitHub App「PR auto merger」が存在し、対象リポジトリにインストールされていること
      （Client ID は `setup.sh` の `PR_AUTO_MERGER_CLIENT_ID` と一致させる）
