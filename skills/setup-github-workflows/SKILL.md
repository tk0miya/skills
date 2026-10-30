---
name: setup-github-workflows
description: 言語非依存の汎用 GitHub Actions / Dependabot 設定・ブランチ保護・プロジェクト共通の GitHub App 認証情報をセットアップする。リポジトリを作成して push した直後に実行する
license: Apache-2.0
---

# setup-github-workflows

## 前提条件

GitHub 側:

- 対象リポジトリが GitHub 上に作成済みで、PR を出せること
- 既定ブランチが `main` であること（`workflow-lint.yml` の `push:` が `main` 固定）
- `gh` CLI が認証済みであること（`gh auth status`）

ローカル側:

- `jq` が利用可能であること
- `gh actions-lock` 拡張がインストール済みであること
  （無ければ `gh extension install github/gh-actions-lock`）
- `setup.sh` 冒頭の `PR_AUTO_MERGER_PRIVATE_KEY_PATH` と `REPO_HOUSEKEEPER_PRIVATE_KEY_PATH`
  の鍵が読めて空でないこと

## ステップ 1: ファイルを配置

まず対象リポジトリの visibility を確認する。

```bash
gh repo view --json visibility -q .visibility
```

このスキルが配置されているディレクトリ（以下 `{SKILL_DIR}`）以下を
プロジェクトの `.github/` にコピーする。

| テンプレート | 配置先 |
|---|---|
| `workflows/workflow-lint.yml` | `.github/workflows/workflow-lint.yml` |
| `workflows/auto-merge.yml` | `.github/workflows/auto-merge.yml`（**private の場合は配置しない**） |
| `workflows/dependabot-auto-label.yml` | `.github/workflows/dependabot-auto-label.yml` |
| `dependabot.yml` | `.github/dependabot.yml`（既存が無い場合。ある場合は下記） |

private リポジトリでは auto-merge（`gh pr merge --auto`）が実行できないため、
`auto-merge.yml` は配置しない。`dependabot-auto-label.yml` はそのまま配置し、
Dependabot の minor/patch PR に `auto-merge` ラベルを付与するところまでに留める
（マージは人手で行う）。

`.github/dependabot.yml` が既に存在する場合（別の ecosystem が置かれている場合など）は
上書きせず、`github-actions` の `package-ecosystem` エントリが無ければ、テンプレートの当該
エントリ（`updates` 配下の 1 ブロック）を既存の `updates` の末尾に追記する。

## ステップ 2: actions.lock を生成

`gh actions-lock` で、ステップ 1 で置いた workflow が使うアクション（推移的な依存も含む）を
lock ファイル `.github/workflows/actions.lock` に固定する。`init-*` スキルが言語ごとの workflow と
一緒に `actions.lock` を作っていれば、そこにステップ 1 の workflow の分が追記される。
`gh actions-lock` は `.github/workflows/` の全 workflow を対象にするので、まだ lock されていない
既存の workflow も取り込まれる。既存の workflow が原因で失敗した場合は、PR を作らずにユーザーに
判断を仰ぐ。

```bash
gh actions-lock --no-narrow
```

`--no-narrow` は必須。付けないと `uses: actions/checkout@<SHA> # v7.0.1` が
`uses: actions/checkout@v7.0.1` のようにタグ表記へ書き換えられ、zizmor の `unpinned-uses`
（`uses:` を commit SHA で書くことを求める）に引っかかる。`--no-narrow` を付ければ workflow
ファイルには手を付けず、SHA（とバージョンのコメント）を書いたまま `actions.lock` だけが作られる。

## ステップ 3: PR を作る

ステップ 1・2 で置いたファイルを commit して PR を作る。パスを配置したファイルに絞るのは、無関係な
作業中の変更を巻き込まないため（上の表を変えたらここも合わせる）。

```bash
set -euo pipefail
git switch -c ci/setup-github-workflows
git add .github/dependabot.yml \
  .github/workflows/actions.lock \
  .github/workflows/workflow-lint.yml \
  .github/workflows/dependabot-auto-label.yml
# public の場合のみ
git add .github/workflows/auto-merge.yml
git commit -m "ci: set up GitHub Actions workflows and Dependabot"
git push -u origin ci/setup-github-workflows
gh pr create --fill
```

## ステップ 4: ユーザーにレビューとマージを依頼する

PR の URL を伝えてレビューとマージを依頼し、`AskUserQuestion` でマージが済んだかを聞く。
`gh` のポーリングでは待たない。

## ステップ 5: GitHub 側のセットアップ

`setup.sh` を実行して、ブランチ保護・ラベル・secret・Dependabot 有効化などを構成する。
ステップ 3 のチェックアウトで実行する（`setup.sh` はそこにいる場合だけ、`--repo` の指定が
今いるリポジトリと一致することを確認できる）。

```bash
bash {SKILL_DIR}/setup.sh --repo "$(gh repo view --json nameWithOwner -q .nameWithOwner)"
```

`setup.sh` が構成する内容:

- ブランチ保護 ruleset（`main`）に `actionlint` / `zizmor` を required status checks として
  登録（`add-required-checks.sh` 経由。無ければ ruleset ごと作成する）
  - PR 必須（`pull_request`）、`deletion` / `non_fast_forward` 禁止
- repo 設定 `allow_auto_merge` / `delete_branch_on_merge` を有効化
- `auto-merge` ラベルを作成
- Dependabot を有効化（`vulnerability-alerts` / `automated-security-fixes`）
- Actions に PR approve 権限を付与
- `PR_AUTO_MERGER_*` の Variable / Secret を登録
- `REPO_HOUSEKEEPER_*` の Variable / Secret を登録

最後に `main` に戻る。

```bash
git switch main && git pull --ff-only
```

## 各ファイルの役割

| ファイル | 役割 |
|---|---|
| `workflow-lint.yml` | push / pull_request 時に GitHub Actions ワークフローを actionlint と zizmor で lint する |
| `auto-merge.yml` | `auto-merge` ラベルが付いた PR を自動で approve & auto-merge する |
| `dependabot-auto-label.yml` | Dependabot の minor / patch 更新 PR に `auto-merge` ラベルを自動付与する |
| `dependabot.yml` | GitHub Actions の依存を週次で更新する |
| `actions.lock` | テンプレートではなくステップ 2 で生成する。workflow が使うアクションを推移的な依存まで commit SHA で固定する |
| `setup.sh` | プロジェクト共通の GitHub 側設定（ブランチ保護・ラベル・secret など） |
| `add-required-checks.sh` | ruleset を作成 / required status checks を追記する |

## 前提条件チェックリストの出力

実行完了後に以下をチェックリスト形式で出力する（`setup.sh` で自動化されない、事前の手作業）。
Client ID は `setup.sh` 冒頭の定数と一致していること。

- [ ] GitHub App「PR auto merger」が対象リポジトリにインストールされていること
- [ ] GitHub App「repo housekeeper」が対象リポジトリにインストールされていること
