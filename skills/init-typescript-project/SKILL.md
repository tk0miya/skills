---
name: init-typescript-project
description: TypeScript プロジェクトの初期セットアップを自動化する
license: Apache-2.0
disable-model-invocation: true
---

# init-typescript-project

TypeScript プロジェクトの初期セットアップを自動化するスキルです。

## 事前チェック（自動実行）

### 実行環境

以下を実行し、`gh` が認証済みか、`node` が利用可能かをチェックする。

```bash
gh auth status
node --version
```

### カレントディレクトリの状況

このスキルは**カレントディレクトリをプロジェクトディレクトリとして扱う**。ディレクトリの作成も `npm init`
による雛形生成も行わない（新規プロジェクトなら、先にユーザーが空のディレクトリを作ってそこでこの
スキルを呼ぶ）。初期セットアップの一部が済んでいることがあるので、カレントディレクトリを調べてどこまで
済んでいるかを判定する。

```bash
ls -1d .git package.json biome.json biome.jsonc 2>/dev/null
[[ -e .git ]] && git remote get-url origin 2>/dev/null
[[ -e .git ]] && git rev-parse --verify -q HEAD && git status --porcelain
```

| 判定 | 条件 | 影響 |
|---|---|---|
| package.json 作成済み | `package.json` がある | Phase 1 の `npm init -y` をスキップし、既存の内容は上書きしない |
| Biome 設定作成済み | `biome.json` か `biome.jsonc` がある | Phase 2 の `npx biome init --jsonc` をスキップ（`biome.json` なら `biome.jsonc` にリネーム） |
| リポジトリ作成済み | カレントディレクトリに `.git` があり、`origin` がある | Phase 3 の `gh repo create` をスキップする |

`origin` を見る前にカレントディレクトリの `.git` を確認するのは、別のリポジトリの配下に作った
ディレクトリで実行したときに、親リポジトリの `origin` を拾って「作成済み」と誤判定しないため
（worktree や submodule では `.git` がファイルなので、ディレクトリかどうかでは判定しない）。

コミットが 1 つ以上あるリポジトリで `git status --porcelain` に未コミットの変更があれば、Phase 3 の
コミットにユーザーの作業を巻き込むことになるので、この時点でユーザーに伝えて、先に片付けるか承知の
うえで進めるかを確認する。履歴がまだ無い場合（手動で `npm init` を実行した直後など）は、雛形が
まるごと未コミットなのが当たり前なので確認しない。

想定している典型シナリオは次の 4 つ。

- 作ったばかりの空のディレクトリでこのスキルを実行する（package.json なし・履歴なし・
  リポジトリ未作成）
- GitHub で作ったリポジトリを clone したディレクトリでこのスキルを実行する（履歴あり・
  リポジトリ作成済み）
- 手動で `npm init` を実行し、そのディレクトリでこのスキルを実行する（package.json あり・
  履歴なし・リポジトリ未作成）
- ドキュメントだけ、あるいは他言語で書かれた既存プロジェクトに TypeScript を足す（履歴あり・
  リポジトリ作成済み。TypeScript 以外のファイルが既にある）

プロジェクト名は `package.json` の `name` → `origin` のリポジトリ名 → カレントディレクトリ名の順で
決める。判定はディレクトリの中身から決まるもので、名前もカレントディレクトリがプロジェクト
ディレクトリである以上そこから決まるので、確認は求めない。判定結果と決定したプロジェクト名は
Phase 0 の質問と一緒に伝える（何をスキップして何の名前で進むかが分かるように）。

## Phase 0: ユーザーへの確認（未確定の項目だけを一度に質問する）

事前チェックで確定しなかった項目だけをまとめて質問し、回答を得てから次のフェーズに進む。

| 項目 | 質問する条件 |
|---|---|
| 対象 Node.js バージョン（例: 24） | 常時 |
| GitHub リポジトリを今すぐ作成するか（yes / no）。yes の場合は visibility（public / private） | リポジトリ作成済みでない場合 |

`package.json` の `engines.node` が設定済みなら、その値を対象 Node.js バージョンの既定値として提示する。
設定済みの値をユーザーの意図と無関係に上書きしないため。

## Phase 1: package.json / 依存関係の整備（自動実行）

「無ければ作る・足りなければ足す」だけを行い、既に書かれている内容は上書きしない。

package.json が無ければ作る:

```bash
npm init -y
```

手動で `npm init` を実行済みのディレクトリは、package.json はあっても `type` や `scripts` などは
未整備。**package.json があることを理由にこのフェーズを飛ばすと `engines.node` も scripts も
入らない。**

package.json に以下が無ければ追記・修正する:
- `"type": "module"` を追加
- `engines.node` に `">={{NODE_VERSION}}"` を設定（Phase 0 で決めた対象バージョン）
- `imports` に以下を設定（subpath imports で `src/` を参照する）:
  ```json
  {
    "#/*": "./src/*"
  }
  ```
- `scripts` に以下を設定（既存のスクリプトは上書きせず、無いものだけ足す）:
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

このフェーズは全項目を実行する。ただし配置先に既にファイルがある場合は、上書きする前に内容を
確認する。`npm init` / `npx biome init --jsonc` が生成したままの内容なら上書きしてよい。
ユーザーが手を入れた形跡がある場合は上書きせず、テンプレートとの差分を提示して残すか
置き換えるかをユーザーに確認する。

### biome.jsonc の生成と設定

設定ファイルは `biome.json` ではなく `biome.jsonc` を使う。なぜその設定にしたのかをコメントで
残せるようにするため。このスキルが行うのはコメントを書ける形式にするまでで、コメント自体は
各プロジェクトで必要に応じて書き足す。

`biome.json` も `biome.jsonc` も無ければ作る:

```bash
npx biome init --jsonc
```

`biome.json` が既にある場合は、設定ファイルの形式をプロジェクト間でそろえるため、既存の
プロジェクトでも `biome.jsonc` にリネームする:

```bash
[[ -e biome.json ]] && mv biome.json biome.jsonc
```

リネーム後、`biome.json` を名指ししている箇所（`.vscode/settings.json` の `biome.configurationPath`、
`package.json` の scripts や CI の `--config-path` など）が無いか確認し、あれば `biome.jsonc` に直す。

`biome.jsonc`（既に設定がある場合はその内容）に以下の設定が無ければ加筆・修正する:
- `vcs`: `{ "enabled": true, "clientKind": "git", "useIgnoreFile": true }`
- `files.includes`: `["**", "!!**/dist"]`
- `formatter`: `{ "indentStyle": "space", "indentWidth": 2, "lineWidth": 120 }`
- `javascript.formatter`: `{ "quoteStyle": "double" }`
- `linter.domains`: `{ "types": "all" }`（型推論が必要なルールを有効化する）
- `assist.actions.source.organizeImports`: `"on"`

### テンプレートファイルのコピー

このスキルが配置されているディレクトリ（`skills/init-typescript-project/`）以下のテンプレートファイルを
プロジェクトにコピーし、以下のプレースホルダーを Phase 0 の回答で置換する。

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

他言語のプロジェクトに TypeScript を足す場合は、`.github` の 2 つが既存の設定とぶつかる。

- `.github/workflows/ci.yml` が既にあり TypeScript のものでなければ、上書きせず `typescript.yml` として
  配置する（既存の CI を消さない）
- `.github/dependabot.yml` が既にあれば、ファイルごと置き換えず、テンプレートの npm エントリを
  `updates` に足す（置き換えると他のエコシステムの更新が止まり、素の npm エントリを書くと
  `cooldown` が入らない）

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

## Phase 3: GitHub 操作

リポジトリを作らない選択をした場合、実行するのは `.git` があるプロジェクトでの 1 だけ
（生成物を未コミットのまま残さない。`.git` が無ければ何もしない）。それ以外は全項目を実行し、
リポジトリ作成済みなら 2 をスキップする。

### 1. コミット

ここまでに生成したファイルをすべてコミットする（新規作成の場合、`gh repo create --push` は
コミットが 1 つも無いと失敗する）。

リポジトリ作成済みの場合は、ここからユーザーの既存リポジトリに push し、3・4 で ruleset・
ラベルを変更することになる。何を変更するかをまとめて提示して、進めてよいかを確認する。

このコミットには package.json・tsconfig・Biome・GitHub Actions・エディタ設定などが同居するが、
雛形を実運用可能な状態にするまでが一続きの作業なので、意図的に 1 コミットにまとめている。
セルフレビューがコミット粒度の分割を指摘した場合は、その指摘だけ採用せずにコミットする
（粒度以外の指摘には通常どおり対応する）。

分岐するのは**コミットが 1 つでもあるか**（`git rev-parse --verify -q HEAD`）。手動で `npm init` を
実行しただけのディレクトリは履歴が無く、`git status` には雛形がまるごと並ぶ。この場合はブランチも
初回コミットもこのスキルが作るので、既存ファイルごと 1 つ目のコミットに含めてよい:

```bash
set -e
[[ -e .git ]] || git init
git add -A
git diff --cached --quiet || git commit -m "Initial commit"
[[ "$(git symbolic-ref -q --short HEAD)" == "main" ]] || git branch -m main   # ワークフローが main 固定
```

コミットが既にある場合は、ユーザーの履歴とブランチを尊重して次のようにする。

- ブランチはリネームしない。既定ブランチが `main` でない場合は、配置したワークフローが `main`
  固定であることをユーザーに伝えて判断を仰ぐ
- 既定ブランチが保護されていて直接 push できないリポジトリでは、コミットの**前に**作業ブランチを
  切っておく（コミットしてから気付いた場合は、作業ブランチを切ったうえで既定ブランチを
  `git reset --hard @{u}` でリモートに戻す）
- コミットメッセージは `Initial commit` ではなく、内容を表すもの（例: `Set up the TypeScript project
  tooling`）にする

まず `git add -A` が何を巻き込むかを確認する:

```bash
git status --porcelain
```

事前チェックの時点で見つけていた変更（ユーザーの作業）が残っていたら、コミットせずにどうするかを
ユーザーに確認する。このスキルの変更だけであることを確認できたらコミットする:

```bash
set -e
git add -A
git diff --cached --quiet || git commit -m "Set up the TypeScript project tooling"
```

リポジトリ作成済みの場合は、続けて `git push` する（新規作成の場合は 2 の
`gh repo create --push` が push する）。作業ブランチにコミットした場合は PR を作成する。

### 2. リポジトリ作成

リポジトリ作成済みの場合はスキップする。

```bash
gh repo create {PROJECT_NAME} --{VISIBILITY} --source=. --push
```

### 3. TypeScript の CI を required status checks に登録

配置した TypeScript のワークフローのジョブ `test` を required status checks に足す。スクリプトは
足りない設定だけを足すので、リポジトリ作成済みで既に ruleset がある場合もそのまま実行してよい。

context はワークフローのファイル名ではなくジョブ名なので、`typescript.yml` として配置した場合も
下のとおり。ただし既存の他言語の CI が同じ context を報告している場合は、TypeScript 側のジョブに
`name: TypeScript` を付けて区別してから、その名前で登録する。

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
