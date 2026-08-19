---
name: init-go-project
description: Go プロジェクトの初期セットアップを自動化する
license: Apache-2.0
disable-model-invocation: true
---

# init-go-project

Go プロジェクトの初期セットアップを自動化するスキルです。

## 事前チェック（自動実行）

### 実行環境

以下を実行し、`gh` が認証済みか、Go が 1.24 以降かをチェックする。

```bash
gh auth status
go version
```

1.24 未満の Go には `tool` ディレクティブ（`go get -tool`）が無く、Phase 1 を実行できない。その
場合は Go を更新してから再実行するようユーザーに伝えて中断する（ユーザーの環境を断りなく
書き換えない）。

**ローカルの Go が Phase 0 で決める対象バージョンより古くても構わない。** `GOTOOLCHAIN` の既定値
`auto` が go.mod の指定するツールチェーンを取得するので、1.24.7 の環境で `go 1.26.6` のモジュールを
ビルドし `-race` でテストできる（実測）。「先に Go を最新にする」という前準備は不要。

### カレントディレクトリの状況

このスキルは**カレントディレクトリをプロジェクトディレクトリとして扱う**。ディレクトリの作成も
行わない（新規プロジェクトなら、先にユーザーが空のディレクトリを作ってそこでこのスキルを呼ぶ）。
初期セットアップの一部が済んでいることがあるので、カレントディレクトリを調べてどこまで済んでいるかを
判定する。

```bash
ls -1d .git go.mod 2>/dev/null
find . -path ./.git -prune -o -name '*.go' -print 2>/dev/null | head -3
[[ -e .git ]] && git remote get-url origin 2>/dev/null
[[ -e .git ]] && git rev-parse --verify -q HEAD && git status --porcelain
```

| 判定 | 条件 | 影響 |
|---|---|---|
| go.mod 作成済み | `go.mod` がある | Phase 1 の `go mod init` をスキップし、module path は `go.mod` から読む |
| 雛形あり | `.go` ファイルが 1 つ以上ある | Phase 1 のプレースホルダ生成をスキップ |
| リポジトリ作成済み | カレントディレクトリに `.git` があり、`origin` がある | Phase 3 の `gh repo create` をスキップする |

`origin` を見る前にカレントディレクトリの `.git` を確認するのは、別のリポジトリの配下に作った
ディレクトリで実行したときに、親リポジトリの `origin` を拾って「作成済み」と誤判定しないため
（worktree や submodule では `.git` がファイルなので、ディレクトリかどうかでは判定しない）。

コミットが 1 つ以上あるリポジトリで `git status --porcelain` に未コミットの変更があれば、Phase 3 の
コミットにユーザーの作業を巻き込むことになるので、この時点でユーザーに伝えて、先に片付けるか承知の
うえで進めるかを確認する。履歴がまだ無い場合（手動で `go mod init` を実行した直後など）は、雛形が
まるごと未コミットなのが当たり前なので確認しない。

想定している典型シナリオは次の 4 つ。

- 作ったばかりの空のディレクトリでこのスキルを実行する（go.mod なし・履歴なし・
  リポジトリ未作成）
- GitHub で作ったリポジトリを clone したディレクトリでこのスキルを実行する（履歴あり・
  リポジトリ作成済み）
- 手動で `go mod init` を実行し、そのディレクトリでこのスキルを実行する（go.mod あり・
  履歴なし・リポジトリ未作成）
- ドキュメントだけ、あるいは他言語で書かれた既存プロジェクトに Go を足す（履歴あり・
  リポジトリ作成済み。Go 以外のファイルが既にある）

プロジェクト名は `go.mod` の module path の末尾 → `origin` のリポジトリ名 → カレントディレクトリ名の
順で決める。判定はディレクトリの中身から決まるもので、名前もカレントディレクトリがプロジェクト
ディレクトリである以上そこから決まるので、確認は求めない。判定結果と決定したプロジェクト名は
Phase 0 の質問と一緒に伝える（何をスキップして何の名前で進むかが分かるように）。

## Phase 0: ユーザーへの確認（未確定の項目だけを一度に質問する）

事前チェックで確定しなかった項目だけをまとめて質問し、回答を得てから次のフェーズに進む。

| 項目 | 質問する条件 |
|---|---|
| 対象 Go バージョン（パッチ版まで。例: 1.26.6） | 常時 |
| module path（例: `github.com/tk0miya/{PROJECT_NAME}`） | `go.mod` が無い場合 |
| GitHub リポジトリを今すぐ作成するか（yes / no）。yes の場合は visibility（public / private） | リポジトリ作成済みでない場合 |

対象 Go バージョンの既定値は次の順で決めて提示する。

1. `go.mod` に `go` ディレクティブがあればその値（設定済みの値をユーザーの意図と無関係に
   上書きしないため）
2. 最新の stable リリース。`curl -fsS 'https://go.dev/dl/?mode=json' | jq -r '[.[] | select(.stable)][0].version'`
3. 取得できなければ `go env GOVERSION`。ただし**これはローカルのツールチェーンであって最新とは
   限らない**ので、そう添えて提示する（開発コンテナの egress proxy が `go.dev` を 403 で塞ぐ
   ことがある）

**1.24 未満は選べない**（`tool` ディレクティブが使えるのは 1.24 以降）。1 で読み取った値が 1.24 未満
だった場合は既定にせず、2 の値を提示して理由を添える。

module path の既定値は `origin` の URL から、`origin` が無ければ `gh api user -q .login` と
プロジェクト名から `github.com/{OWNER}/{PROJECT_NAME}` を組み立てる。

## Phase 1: go.mod と開発ツールの整備（自動実行）

「無ければ作る・足りなければ足す」だけを行い、既に書かれている内容は上書きしない。

```bash
go mod init {{MODULE_PATH}}      # go.mod が無い場合だけ
go mod edit -go={{GO_VERSION}}
go get -tool github.com/golangci/golangci-lint/v2/cmd/golangci-lint
go get -tool mvdan.cc/gofumpt
go get -tool golang.org/x/vuln/cmd/govulncheck
go mod tidy
```

手動で `go mod init` を実行済みのディレクトリは、go.mod はあっても `go` ディレクティブはローカルの
Go のもので、`tool` ディレクティブも無い。**go.mod があることを理由にこのフェーズを飛ばすと、
ツールも入らず `go` の行も上がらない。**

`go get -tool` は 1 回の実行につき 1 パスしか受け取らないので、3 回に分けてある。末尾の
`go mod tidy` は省けない（`go get -tool` は go.sum を tidy にしないので、`make lint` の
`go mod tidy -diff` が落ちる）。先回りして足した依存もここで落ちるので、使うコードができるまで
ライブラリは足さない。

### `go` ディレクティブはパッチ版まで書く

`1.26` ではなく `1.26.6` と書く。`actions/setup-go` は `go-version-file: go.mod` の値を
`GOTOOLCHAIN=local` で使うので、**この 1 行が CI のビルドに使うツールチェーンを決める**。

これは利便性の話ではなく、脆弱性対応の経路の話である。`govulncheck` は、コードがビルドされる
ツールチェーンに対する標準ライブラリの勧告を報告する。つまり標準ライブラリの脆弱性は**この行を
上げて直す**ものであり、Dependabot の `gomod` は requirement を更新するだけで `go` ディレクティブは
触らないので、誰も自動では直さない。CI の `vulncheck` ジョブが `Standard library` を出して赤くなるのが
その合図になる。

### `go` の行が上書きされていないか確認する

`go get -tool` は、ツールが要求する Go より `go` の行が低いと**その行を黙って上げる**（実測: `go 1.22`
のモジュールで `go: upgraded go 1.22 => 1.25.0`）。失敗はしないので気付きにくいが、この場合 Phase 0 で
決めた値はもう入っていない。

```bash
grep '^go ' go.mod
```

Phase 0 で決めた値のままなら何もしない。上がっていた場合、上がった先はツールが要求する下限なので
下げてはいけない。Phase 0 の 2 と同じ方法で最新の stable を調べてそれを書き（`go mod edit -go=`。
`1.25.0` のようにパッチが 0 のままでは、パッチ版まで書く意味が無い）、決めた値が使えなかったことと
理由をユーザーに伝える。

### プレースホルダのパッケージを 1 つ置く

`.go` ファイルが 1 つも無い場合、`{{PROJECT_NAME}}.go` を作る。

```go
// Package {{PACKAGE_NAME}} is where this module's implementation starts. Replace
// this placeholder with the project's own packages.
package {{PACKAGE_NAME}}
```

パッケージが 1 つも無いモジュールは `golangci-lint` に解析対象が無く、`go build ./...` も
`matched no packages` の警告だけを出して終わる。つまり `make check` と CI が「何も検査していないのに
緑」になる。

コマンドを作るのかライブラリを作るのかはこの時点では決まらないので、**どちらにでも育てられる形で
1 パッケージだけ置く**。コマンドにするときは `cmd/{{PROJECT_NAME}}/main.go` を足して Makefile の
`build` を書き換える（その手順は Makefile のコメントに書いてある）。

`{{PACKAGE_NAME}}` は `{{PROJECT_NAME}}` そのままではない。**Go のパッケージ名は識別子なので、`-` や
`.` を含められず、数字から始められない。** `{{PROJECT_NAME}}` から英数字以外を除いて小文字にした
ものを使う（`go-skill-check` → `goskillcheck`）。除いた結果が数字から始まる場合（`2fa-tool` →
`2fatool`）はパッケージ名にできないので、その 1 件だけユーザーに確認する。ファイル名は
`{{PROJECT_NAME}}.go` のままでよい。ここを機械的に置換すると構文エラーになる。

## Phase 2: 設定ファイルの配置（自動実行）

このフェーズは全項目を実行する。ただし配置先に既にファイルがある場合は、上書きする前に内容を
確認する。ユーザーが手を入れた形跡がある場合は上書きせず、テンプレートとの差分を提示して残すか
置き換えるかをユーザーに確認する。

### テンプレートファイルのコピー

このスキルが配置されているディレクトリ（`skills/init-go-project/`、以下 `{SKILL_DIR}`）以下の
テンプレートファイルをプロジェクトにコピーする。

#### 置換ルール

| プレースホルダー | 置換値 |
|---|---|
| `{{PROJECT_NAME}}` | 事前チェックで決めたプロジェクト名 |

`{{GO_VERSION}}` / `{{MODULE_PATH}}` / `{{PACKAGE_NAME}}` は Phase 1 で直接使うだけで、テンプレートには
現れない。CI は Go のバージョンを `go-version-file: go.mod` から読むので、バージョンを書く場所が
go.mod 以外に無い。

#### 配置先

| テンプレート | 配置先 |
|---|---|
| `Makefile.tmpl` | `Makefile` |
| `golangci.yml` | `.golangci.yml` |
| `gitignore.tmpl` | `.gitignore` |
| `workflows/go.yml` | `.github/workflows/go.yml` |
| `workflows/go-tools.yml` | `.github/workflows/go-tools.yml` |
| `dependabot.yml` | `.github/dependabot.yml` |

他言語のプロジェクトに Go を足す場合、ワークフローのファイル名は言語固有なのでぶつからないが、
`.github/dependabot.yml` は既存の設定とぶつかる。

- `.github/dependabot.yml` が既にあれば、ファイルごと置き換えず、テンプレートの `gomod` エントリを
  `updates` に足す（置き換えると他のエコシステムの更新が止まり、素の `gomod` エントリを書くと
  `cooldown` が入らない）

ジョブ名の衝突については Phase 3 の 3 を参照。

#### 配置したファイルについて

`make lint` は検査のみで自動修正しないので、整形差分で止まった場合は `make fmt` を実行してから
コミットし直す。初回の `make lint` は linter のビルドを含むので 1 分強かかる（以降は 1 秒程度）。

`go-tools.yml` は `REPO_HOUSEKEEPER_*` の認証情報を使う。登録するのは Phase 3 の 4 で実行する
`setup-github-workflows` なので、それが済むまでは手で実行しても失敗する。

各ファイルが何をするか、なぜそう書いてあるかは、ファイル自身のコメントにある。

### Claude Code hooks のセットアップ

まず `setup-dev-workflow-hooks` スキルを実行して汎用の開発ワークフロー hooks をセットアップする。
続けて、このスキルの以下のファイルを配置して Go 向けの hooks をセットアップする。

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
| `pre-commit-check.sh` | PreToolUse | `git commit` 前に `make check`（lint / test）を実行し、失敗したらコミットを止める |

この hook は、同じ Phase で配る Makefile の `check` ターゲットを前提にしている。hook だけを別に配ると
規約がずれて動かないので、このスキルが同じ Phase でまとめて配る。

## Phase 3: GitHub 操作

リポジトリを作らない選択をした場合、実行するのは `.git` があるプロジェクトでの 1 だけ
（生成物を未コミットのまま残さない。`.git` が無ければ何もしない）。それ以外は全項目を実行し、
リポジトリ作成済みなら 2 をスキップする。

### 1. コミット

ここまでに生成したファイルをすべてコミットする（新規作成の場合、`gh repo create --push` は
コミットが 1 つも無いと失敗する）。

リポジトリ作成済みの場合は、ここからユーザーの既存リポジトリに push し、3・4 で ruleset・
ラベルを変更することになる。何を変更するかをまとめて提示して、進めてよいかを確認する。

このコミットには go.mod・Makefile・golangci-lint・GitHub Actions・hooks などが同居するが、
雛形を実運用可能な状態にするまでが一続きの作業なので、意図的に 1 コミットにまとめている。
セルフレビューがコミット粒度の分割を指摘した場合は、その指摘だけ採用せずにコミットする
（粒度以外の指摘には通常どおり対応する）。

分岐するのは**コミットが 1 つでもあるか**（`git rev-parse --verify -q HEAD`）。手動で `go mod init` を
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
- コミットメッセージは `Initial commit` ではなく、内容を表すもの（例: `Set up the Go project
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
git diff --cached --quiet || git commit -m "Set up the Go project tooling"
```

リポジトリ作成済みの場合は、続けて `git push` する（新規作成の場合は 2 の
`gh repo create --push` が push する）。作業ブランチにコミットした場合は PR を作成する。

### 2. リポジトリ作成

リポジトリ作成済みの場合はスキップする。

```bash
gh repo create {PROJECT_NAME} --{VISIBILITY} --source=. --push
```

### 3. Go の CI を required status checks に登録

配置した Go のワークフローの 4 つのジョブを required status checks に足す。スクリプトは足りない設定
だけを足すので、リポジトリ作成済みで既に ruleset がある場合もそのまま実行してよい。

```bash
bash {SKILL_DIR}/add-required-checks.sh \
  --repo "$(gh repo view --json nameWithOwner -q .nameWithOwner)" \
  --add-check "build" --add-check "test" --add-check "lint" --add-check "vulncheck"
```

context はワークフローのファイル名ではなくジョブ名（`name:` があればそれ、無ければジョブ id）なので、
`build` / `test` / `lint` は他言語の CI とぶつかりやすい（`init-typescript-project` の `ci.yml` も
`test` を報告する）。既存の CI が同じ context を報告している場合は、Go 側のジョブに
`name: Go build` のように付けて区別してから、その名前で登録する。

**`go-tools.yml` のジョブは足さない。** スケジュール実行だけで PR には何も報告しないので、必須に
すると context が永久に報告されず、すべての PR が pending のまま止まる。

### 4. 言語非依存の GitHub セットアップ

`setup-github-workflows` スキルを実行する。`auto-merge` ラベル・`PR_AUTO_MERGER_*` /
`REPO_HOUSEKEEPER_*` の登録と、`actionlint` / `zizmor` の required 追加は同スキルが行う。
失敗した場合は同スキルの前提条件を確認して再実行する。

## Phase 4: 手動対応チェックリストの出力

実行完了後に以下をチェックリスト形式で出力する。

- [ ] GitHub: Dependabot malware alerts を有効化（Settings > Security）
