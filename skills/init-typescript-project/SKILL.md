---
name: init-typescript-project
description: TypeScript プロジェクトの初期セットアップを自動化する
license: Apache-2.0
disable-model-invocation: true
---

# init-typescript-project

TypeScript プロジェクトの初期セットアップを自動化するスキルです。

## 事前チェック（自動実行）

以下を実行し、`gh` が認証済みか、`node` が利用可能かチェックする。

```bash
gh auth status
node --version
```

## Phase 0: ユーザーへの確認（必須・実行前に全項目を一度に質問する）

以下の項目をまとめて質問し、回答を得てから次のフェーズに進む。

1. プロジェクト名（例: my-awesome-tool）
2. 対象 Node.js バージョン（例: 24）
3. GitHub リポジトリを今すぐ作成するか（yes / no）
   - yes の場合: リポジトリの visibility（public / private）

## Phase 1: 雛形生成（自動実行）

```bash
mkdir {PROJECT_NAME}
cd {PROJECT_NAME}
npm init -y
```

生成された `package.json` に以下を追記・修正する:
- `"type": "module"` を追加
- `imports` に以下を設定（subpath imports で `src/` を参照する）:
  ```json
  {
    "#/*": "./src/*"
  }
  ```
- `scripts` に以下を設定:
  ```json
  {
    "test": "vitest run --passWithNoTests",
    "typecheck": "tsc --noEmit",
    "lint": "biome check .",
    "lint:fix": "biome check --write .",
    "ci": "npm run lint && npm run typecheck && npm test"
  }
  ```

```bash
npm install -D typescript @biomejs/biome vitest @types/node
mkdir -p src test
```

続けてエントリポイントのプレースホルダを作成する。`tsconfig.json` の `include` は `src` だけを
見るため、`src/` が空のままだと `tsc --noEmit` が TS18003（No inputs were found in config file）で
失敗し、CI と pre-commit hook のどちらも通らなくなる。

```bash
cat > src/index.ts <<'EOF'
// Entry point. Replace this placeholder with the project's implementation.
EOF
```

## Phase 2: 設定ファイルの配置（自動実行）

### biome.json の生成と設定

```bash
npx biome init
```

生成された `biome.json` に以下の設定を加筆・修正する:
- `vcs`: `{ "enabled": true, "clientKind": "git", "useIgnoreFile": true }`
- `files.includes`: `["**", "!!**/dist"]`
- `formatter`: `{ "indentStyle": "space", "indentWidth": 2, "lineWidth": 120 }`
- `javascript.formatter`: `{ "quoteStyle": "double" }`
- `assist.actions.source.organizeImports`: `"on"`

### テンプレートファイルのコピー

このスキルが配置されているディレクトリ（`skills/init-typescript-project/`）以下のテンプレートファイルをプロジェクトにコピーし、以下のプレースホルダーを Phase 0 の回答で置換する。

#### 置換ルール

| プレースホルダー | 置換値 |
|---|---|
| `{{NODE_VERSION}}` | Phase 0 で入力した対象 Node.js バージョン |

#### 配置先

| テンプレート | 配置先 |
|---|---|
| `tsconfig.json.tmpl` | `tsconfig.json` |
| `vitest.config.ts.tmpl` | `vitest.config.ts` |
| `gitignore.tmpl` | `.gitignore` |
| `npmrc.tmpl` | `.npmrc` |
| `vscode/settings.json` | `.vscode/settings.json` |
| `vscode/extensions.json` | `.vscode/extensions.json` |
| `workflows/ci.yml` | `.github/workflows/ci.yml` |
| `workflows/biome-migrate.yml` | `.github/workflows/biome-migrate.yml` |
| `dependabot.yml` | `.github/dependabot.yml` |

### Claude Code hooks のセットアップ

まず `setup-dev-workflow-hooks` スキルを実行して汎用の開発ワークフロー hooks をセットアップする。
続けて、このスキルの以下のファイルを配置して TypeScript 向けの hooks をセットアップする。

| テンプレート | 配置先 |
|---|---|
| `hooks/pre-commit-check.sh` | `.claude/hooks/pre-commit-check.sh` |

`.claude/settings.json` には `claude-settings.json` の hooks 定義をマージする（`setup-dev-workflow-hooks`
が先に書き込んでいるので、既存の hooks や `permissions` は保持する）。

配置後、以下を実行してスクリプトに実行権限を付与する:

```bash
chmod +x .claude/hooks/*.sh
```

#### 各 hook の役割

| ファイル | タイミング | 役割 |
|---|---|---|
| `pre-commit-check.sh` | PreToolUse | `git commit` 前に `npm run ci`（lint / typecheck / test）を実行し、失敗したらコミットを止める |

この hook は、Phase 1 で `package.json` に定義した `ci` スクリプトを前提にしている。hook だけを
別に配ると規約がずれて動かないので、このスキルが同じ Phase でまとめて配る。

`ci` は `.github/workflows/ci.yml` が実行するものと同一なので、コミットが通れば CI も通る。なお
`ci` の lint は検査のみで自動修正しないため、フォーマット差分で止まった場合は `npm run lint:fix`
を実行してからコミットし直す。

## Phase 3: GitHub 操作（GitHub リポジトリ作成を選んだ場合のみ）

### 1. 初回コミット

`gh repo create --push` はコミットが 1 つも無いと失敗するため、ここまでに生成した
ファイルをすべてコミットする。

このコミットには package.json・tsconfig・Biome・GitHub Actions・エディタ設定などが同居するが、
雛形を実運用可能な状態にするまでが一続きの作業なので、意図的に 1 コミットにまとめている。
セルフレビューがコミット粒度の分割を指摘した場合は、その指摘だけ採用せずにコミットする
（粒度以外の指摘には通常どおり対応する）。

```bash
set -e
[[ -d .git ]] || git init
git add -A
git diff --cached --quiet || git commit -m "Initial commit"
[[ "$(git symbolic-ref -q --short HEAD)" == "main" ]] || git branch -m main   # ワークフローが main 固定
```

### 2. リポジトリ作成

```bash
gh repo create {PROJECT_NAME} --{VISIBILITY} --source=. --push
```

### 3. TypeScript の CI を required status checks に登録

`ci.yml` のジョブ `test` を required status checks に足す。

```bash
bash {SKILL_DIR}/add-required-checks.sh \
  --repo "$(gh repo view --json nameWithOwner -q .nameWithOwner)" \
  --add-check "test"
```

### 4. 言語非依存の GitHub セットアップ

`setup-github-workflows` スキルを実行する。`auto-merge` ラベル・`PR_AUTO_MERGER_*` /
`REPO_HOUSEKEEPER_*` の登録と、`actionlint` / `zizmor` の required 追加は同スキルが行う。
失敗した場合は同スキルの前提条件を確認して再実行する。

## Phase 4: 手動対応チェックリストの出力

実行完了後に以下をチェックリスト形式で出力する。

- [ ] GitHub: Dependabot malware alerts を有効化（Settings > Security）
- [ ] VSCode: biomejs.biome 拡張機能をインストール
