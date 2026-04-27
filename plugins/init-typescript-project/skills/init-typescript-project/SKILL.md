---
name: init-typescript-project
description: TypeScript プロジェクトの初期セットアップを自動化する
disable-model-invocation: true
---

# init-typescript-project

TypeScript プロジェクトの初期セットアップを自動化するスキルです。

## 事前チェック（自動実行）

以下を実行し、必要なコマンドが利用可能かチェックする。失敗した場合はエラーメッセージを表示して処理を中断する。

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
| `vscode/settings.json` | `.vscode/settings.json` |
| `vscode/extensions.json` | `.vscode/extensions.json` |
| `workflows/ci.yml` | `.github/workflows/ci.yml` |
| `workflows/auto-merge.yml` | `.github/workflows/auto-merge.yml` |
| `workflows/dependabot-auto-label.yml` | `.github/workflows/dependabot-auto-label.yml` |
| `workflows/actionlint.yml` | `.github/workflows/actionlint.yml` |
| `dependabot.yml` | `.github/dependabot.yml` |

設定ファイルの配置後、`setup-dev-workflow-hooks` スキルを実行して開発ワークフロー向け hooks をセットアップする。

## Phase 3: GitHub 操作（GitHub リポジトリ作成を選んだ場合のみ）

このスキルが配置されているディレクトリ（`skills/init-typescript-project/`）の `setup-github.sh` を実行する。

```bash
bash {SKILL_DIR}/setup-github.sh --project-name {PROJECT_NAME} --visibility {VISIBILITY}
```

## Phase 4: 手動対応チェックリストの出力

実行完了後に以下をチェックリスト形式で出力する。

- [ ] GitHub: Dependabot malware alerts を有効化（Settings > Security）
- [ ] VSCode: biomejs.biome 拡張機能をインストール
