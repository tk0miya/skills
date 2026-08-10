---
name: init-ruby-project
description: Ruby プロジェクトの初期セットアップを自動化する
license: Apache-2.0
disable-model-invocation: true
---

# init-ruby-project

Ruby プロジェクトの初期セットアップを自動化するスキルです。

## 事前チェック（自動実行）

### 実行環境

以下を実行し、`gh` が認証済みか、Bundler が 4.0.13 以降かをチェックする。

```bash
gh auth status
bundle --version
```

4.0.13 未満の Bundler は Phase 1 で付与する `cooldown`（公開直後の gem を一定期間使わない
供給チェーン対策）を**黙って無視する**ため、cooldown の効かないプロジェクトができあがる。
その場合は `gem install bundler` で更新してから再実行するようユーザーに伝えて中断する
（ユーザーの環境を断りなく書き換えない）。

### カレントディレクトリの状況

このスキルは**カレントディレクトリをプロジェクトディレクトリとして扱う**。ディレクトリの作成も
`bundle gem` による雛形生成も行わない（gem を作るなら、先にユーザーが `bundle gem` を実行して
そのディレクトリでこのスキルを呼ぶ）。初期セットアップの一部が済んでいることがあるので、
カレントディレクトリを調べてどこまで済んでいるかを判定する。

```bash
ls -1d .git Gemfile *.gemspec 2>/dev/null
[[ -e .git ]] && git remote get-url origin 2>/dev/null
[[ -e .git ]] && git rev-parse --verify -q HEAD && git status --porcelain
```

| 判定 | 条件 | 影響 |
|---|---|---|
| gem のプロジェクト | `*.gemspec` がある | 以降の各フェーズで gem 用の分岐を選ぶ |
| リポジトリ作成済み | カレントディレクトリに `.git` があり、`origin` がある | Phase 3 の `gh repo create` をスキップする |

`origin` を見る前にカレントディレクトリの `.git` を確認するのは、別のリポジトリの配下に作った
ディレクトリで実行したときに、親リポジトリの `origin` を拾って「作成済み」と誤判定しないため
（worktree や submodule では `.git` がファイルなので、ディレクトリかどうかでは判定しない）。

コミットが 1 つ以上あるリポジトリで `git status --porcelain` に未コミットの変更があれば、Phase 3 の
コミットにユーザーの作業を巻き込むことになるので、この時点でユーザーに伝えて、先に片付けるか承知の
うえで進めるかを確認する。履歴がまだ無い場合（手動で `bundle gem` を実行した直後など）は、雛形が
まるごと未コミットなのが当たり前なので確認しない。

想定している典型シナリオは次の 4 つ。

- 手動で `bundle gem` を実行し、そのディレクトリでこのスキルを実行する（gem・履歴なし・
  リポジトリ未作成）
- GitHub で作ったリポジトリを clone したディレクトリでこのスキルを実行する（gem ではない・
  履歴あり・リポジトリ作成済み）
- 作ったばかりの空のディレクトリでこのスキルを実行する（gem ではない・履歴なし・
  リポジトリ未作成）
- ドキュメントだけ、あるいは他言語で書かれた既存プロジェクトに Ruby を足す（gem ではない・
  履歴あり・リポジトリ作成済み。Ruby 以外のファイルが既にある）

プロジェクト名は `*.gemspec` のベース名 → `origin` のリポジトリ名 → カレントディレクトリ名の順で
決める。判定はディレクトリの中身から決まるもので、名前もカレントディレクトリがプロジェクト
ディレクトリである以上そこから決まるので、確認は求めない。判定結果と決定したプロジェクト名は
Phase 0 の質問と一緒に伝える（何をスキップして何の名前で進むかが分かるように）。

## Phase 0: ユーザーへの確認（未確定の項目だけを一度に質問する）

事前チェックで確定しなかった項目だけをまとめて質問し、回答を得てから次のフェーズに進む。

| 項目 | 質問する条件 |
|---|---|
| 対象 Ruby バージョン（例: 3.3） | 常時 |
| サポートする Ruby バージョン一覧（例: 3.2, 3.3, 3.4） | gem のプロジェクトの場合 |
| GitHub リポジトリを今すぐ作成するか（yes / no）。yes の場合は visibility（public / private） | リポジトリ作成済みでない場合 |

gemspec の `required_ruby_version` や `.rubocop.yml` の `TargetRubyVersion` が設定済みなら、その値を
対象 Ruby バージョンの既定値として提示する。設定済みの値をユーザーの意図と無関係に上書きしないため。

## Phase 1: Gemfile / gemspec の整備（自動実行）

「無ければ作る・足りなければ足す」だけを行い、既に書かれている内容は上書きしない。

手動で `bundle gem` を実行した直後のディレクトリは、雛形はあっても gemspec も Gemfile も未整備。
**雛形があることを理由にこのフェーズを飛ばすと `required_ruby_version` も cooldown も入らない。**

### gemspec の整備（gem のプロジェクトの場合のみ）

1. `required_ruby_version` を `">= {RUBY_VERSION}"` に更新する。

   この gem が動作を保証する Ruby バージョンの宣言なので、Phase 0 で決めた対象バージョン（最小
   サポートバージョン。`.rubocop.yml` の `TargetRubyVersion` と同じ値）を書く。Bundler がこの値を
   依存解決の制約に使うため、`bundle install` より前に直す（雛形の既定値は対象と無関係な固定値なので、
   そのままでは対象より緩いレンジを満たす古い依存で `Gemfile.lock` が固定される）。

2. `spec.metadata["rubygems_mfa_required"] = "true"` を追記する。gem の公開に MFA を必須にする設定で、
   RubyGems のアカウントが乗っ取られても不正なバージョンを公開されないようにする（cooldown と同じ
   供給チェーン対策）。

3. `spec.files` の除外リスト（`f.start_with?(*%w[...])`）に開発用ファイルを追加する。
   `bundle gem` が生成する除外リストは雛形時点のファイルしか対象にしておらず、そのままでは
   このスキルが配置する設定ファイルがすべてリリース物に含まれてしまう。

   既存の `%w[...]` の末尾に `.claude/` `.vscode/` `.rubocop.yml` `Rakefile` `Steepfile`
   `rbs_collection` を追記する。除外リストの初期値は bundler のバージョンと `bundle gem` の
   オプション・対話の回答によって変わるので、**元からある要素は消さず、既に入っているものは
   重複させない**（linter に rubocop を選んだ場合は `.rubocop.yml` が初期値に入っている）。
   前置一致なので `rbs_collection` の 1 要素で `rbs_collection.yaml` と
   `rbs_collection.lock.yaml` の両方を拾える。

   追記後はたとえば次のようになる（初期値は bundler 4.x で `--ci=github --test=rspec` の例）:

   ```ruby
     spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
       ls.readlines("\x0", chomp: true).reject do |f|
         (f == gemspec) ||
           f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/
                             .claude/ .vscode/ .rubocop.yml Rakefile Steepfile
                             rbs_collection])
       end
     end
   ```

   `sig/` の型定義は利用者に配布したいので除外しない。

4. 実体のない雛形コメントを削除する。

   - `# Uncomment to register a new dependency of your gem` と、続く
     `# spec.add_dependency "example-gem", "~> 1.0"`
   - `# For more information and examples about making a new gem, check out our`
     `# guide at: https://bundler.io/guides/creating_gem.html`

### Gemfile の調整

- Gemfile が無ければ `bundle init` で作る
- `source "https://rubygems.org"` 行に cooldown を付与する:
  ```ruby
  source "https://rubygems.org", cooldown: 7
  ```
- `group :development` に以下を追加する（グループが無ければ作る。既に書かれている gem は
  重複させない）:
  ```ruby
  group :development do
    gem "rake"
    gem "rbs"
    gem "rbs-inline"
    gem "rspec"
    gem "rubocop"
    gem "rubocop-numbered-params"
    gem "rubocop-rake"
    gem "rubocop-rbs_inline"
    gem "rubocop-rspec"
    gem "steep"
  end
  ```
- `bundle install` を実行
- `bundle lock --add-platform x86_64-linux aarch64-linux` を実行

### 雛形の後始末（gem のプロジェクトの場合のみ）

雛形が生成したものだけを消す。手つかずかどうかは中身を読めば分かるので、削除の前に必ず確認し、
ユーザーが書いたテストや CHANGELOG のエントリは残す。

- `bundle gem` の example（`it "does something useful"` と `it "has a version number"`）だけで
  構成された `spec/` 以下の `*_spec.rb` を削除する。他の example を含むファイルと
  `spec/spec_helper.rb` は残す
  - 生成される example は 2 つとも残す価値がない。`it "does something useful"` は意図的に失敗するため CI が最初から赤で、Phase 3 で登録する required status checks を満たせず PR をマージできない。`it "has a version number"` は、コードに宣言的に書かれた定数をそのまま検証する価値の薄いテスト
  - example が 0 件でも `rake ci` は成功する
- `CHANGELOG.md` の日付付き `## [0.1.0]` セクションが `- Initial release` だけなら、見出しごと削除して
  `## [Unreleased]` だけを残す。他のエントリが書かれていれば触らない
  - まだ 1 度もリリースしていないのに、日付付きの 0.1.0 がリリース済みに見え、この CHANGELOG を読んだ人やツールが誤解する。初回リリース時に `## [Unreleased]` を 0.1.0 のセクションとして確定させればよい

## Phase 2: 設定ファイルの配置（自動実行）

このフェーズは全項目を実行する。ただし配置先に既にファイルがある場合は、上書きする前に内容を
確認する。`bundle gem` / `bundle init` が生成したままの内容なら上書きしてよい。
ユーザーが手を入れた形跡がある場合は上書きせず、テンプレートとの差分を提示して残すか置き換えるかを
ユーザーに確認する。

このスキルが配置されているディレクトリ（`skills/init-ruby-project/`）以下のテンプレートファイルを
プロジェクトにコピーし、以下のプレースホルダーを Phase 0 の回答と事前チェックの判定結果で置換する。

### 置換ルール

| プレースホルダー | 置換値 |
|---|---|
| `{{PROJECT_NAME_SNAKE}}` | プロジェクト名のハイフンをアンダースコアに変換したもの（例: `my-awesome-gem` → `my_awesome_gem`） |
| `{{RUBY_VERSION}}` | Phase 0 で入力した対象 Ruby バージョン（最小バージョン） |
| `{{RUBY_VERSIONS}}` | Phase 0 で入力したサポートバージョン一覧を JSON 配列形式に変換したもの（例: `["3.2", "3.3", "3.4"]`）。gem のプロジェクトの場合のみ使用 |

### 配置先

| テンプレート | 配置先 | 条件 |
|---|---|---|
| `.rspec` | `.rspec` | 常時 |
| `spec/spec_helper.rb` | `spec/spec_helper.rb` | `spec/spec_helper.rb` が無い場合（`.rspec` が `--require spec_helper` するので、無いと rspec が起動できない） |
| `rubocop.yml` | `.rubocop.yml` | 常時 |
| `Steepfile` | `Steepfile` | 常時 |
| `Rakefile` | `Rakefile` | 常時（`bundle gem` が生成した Rakefile は上書きしてよい。ユーザーが書いた Rakefile がある場合は、残す・置き換えるではなくテンプレートのタスクをマージする。CI が `rake ci` を、Phase 2 が `rake rbs:regenerate` を呼ぶので、タスクが無いと CI が赤のままになる） |
| `workflows/ci.yml` | `.github/workflows/ci.yml` | gem のプロジェクトでない場合 |
| `workflows/ci-gem.yml` | `.github/workflows/ci.yml` | gem のプロジェクトの場合（`bundle gem --ci=github` が生成した `.github/workflows/main.yml` があれば削除する） |
| `dependabot.yml` | `.github/dependabot.yml` | 常時 |
| `workflows/rbs_collection.yml` | `.github/workflows/rbs_collection.yml` | 常時 |
| `workflows/release.yml` | `.github/workflows/release.yml` | gem のプロジェクトの場合のみ |

また、以下のテンプレートも配置する:

| テンプレート | 配置先 | 条件 |
|---|---|---|
| `vscode/settings.json` | `.vscode/settings.json` | 常時 |
| `vscode/extensions.json` | `.vscode/extensions.json` | 常時 |

gem のプロジェクトでない場合は、配置した `Rakefile` から次の 1 行を削除する。

```ruby
require "bundler/gem_tasks"
```

これが定義する `build` / `release` タスクは gem を公開するためのもので（`release.yml` が使う
`rubygems/release-gem` が前提にしている）、gem 以外では使わない。しかも読み込み時に gemspec を
解決するので、gemspec が無いと Rakefile がその行で例外を投げ、`rake ci` も動かず CI が最初から
赤になる。

他言語のプロジェクトに Ruby を足す場合は、`.github` の 2 つが既存の設定とぶつかる。

- `.github/workflows/ci.yml` が既にあり Ruby のものでなければ、上書きせず `ruby.yml` として配置する
  （既存の CI を消さない）
- `.github/dependabot.yml` が既にあれば、ファイルごと置き換えず、テンプレートの bundler エントリを
  `updates` に足す（置き換えると他のエコシステムの更新が止まり、素の bundler エントリを書くと
  cooldown が入らない）

設定ファイルの配置後、以下を実行する（`rbs_collection.yaml` が既にある場合は `init` をスキップする）:

```bash
bundle exec rbs collection init
bundle exec rbs collection install
```

`bundle gem` が生成する `sig/` は手書きのスタブなので、rbs-inline で生成し直す
（`lib/` に Ruby のソースが無い場合は生成するものが無いのでスキップする）:

```bash
bundle exec rake rbs:regenerate
```

`.gitignore` の先頭に以下のコメントを挿入し、末尾に以下を追記する
（`.gitignore` が無い場合はこの内容で新規作成する）:

先頭に挿入（既にある `.gitignore` が ASCII 順に並んでいない場合は、事実と食い違うので挿入せず、
並べ替えてよいかユーザーに確認する）:
```
# NOTE: Entries are sorted in ASCII order.
```

ASCII 順を維持した適切な箇所に追記（既に入っている行は重複させない）:
```
/.claude/settings.local.json
/.gem_rbs_collection/
```

### Claude Code hooks のセットアップ

`setup-dev-workflow-hooks` スキルを実行して汎用の開発ワークフロー hooks をセットアップする。
続けて `setup-ruby-hooks` スキルを実行して Ruby 向けの Claude Code hooks をセットアップする。

## Phase 3: GitHub 操作

リポジトリを作らない選択をした場合、実行するのは `.git` があるプロジェクトでの 1 だけ
（生成物を未コミットのまま残さない。`.git` が無ければ何もしない）。それ以外は全項目を実行し、
リポジトリ作成済みなら 2 をスキップする。

### 1. コミット

ここまでに生成したファイルをすべてコミットする（新規作成の場合、`gh repo create --push` は
コミットが 1 つも無いと失敗する）。

リポジトリ作成済みの場合は、ここからユーザーの既存リポジトリに push し、3・4 で ruleset・
ラベル・secrets を変更することになる。何を変更するかをまとめて提示して、進めてよいかを確認する。

このコミットには gemspec・RuboCop・RBS/Steep・GitHub Actions・エディタ設定などが同居するが、
雛形を実運用可能な状態にするまでが一続きの作業なので、意図的に 1 コミットにまとめている。
セルフレビューがコミット粒度の分割を指摘した場合は、その指摘だけ採用せずにコミットする
（粒度以外の指摘には通常どおり対応する）。

gemspec の `summary` / `homepage` など、および `bundle gem` の README に残る TODO は、gem の中身が
決まってから書くものなのでこの時点では埋めない。セルフレビューが雛形の TODO の残骸を指摘した場合も、
その指摘だけ採用しない。

分岐するのは**コミットが 1 つでもあるか**（`git rev-parse --verify -q HEAD`）。手動で `bundle gem` を
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
- コミットメッセージは `Initial commit` ではなく、内容を表すもの（例: `Set up the Ruby project
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
git diff --cached --quiet || git commit -m "Set up the Ruby project tooling"
```

リポジトリ作成済みの場合は、続けて `git push` する（新規作成の場合は 2 の
`gh repo create --push` が push する）。作業ブランチにコミットした場合は PR を作成する。

### 2. リポジトリ作成

リポジトリ作成済みの場合はスキップする。

```bash
gh repo create {PROJECT_NAME} --{VISIBILITY} --source=. --push
```

### 3. Ruby の CI を required status checks に登録

配置した Ruby のワークフローのジョブを required status checks に足す。gem のプロジェクトかどうかで
渡す context が変わるので、**どちらか一方**を実行する。スクリプトは足りない設定だけを足すので、
リポジトリ作成済みで既に ruleset がある場合もそのまま実行してよい。

context はワークフローのファイル名ではなくジョブ名なので、`ruby.yml` として配置した場合も下の
とおり。ただし既存の他言語の CI が同じ context を報告している場合は、Ruby 側のジョブに
`name: Ruby` を付けて区別してから、その名前で登録する。

```bash
# gem のプロジェクトでない場合（ci.yml のジョブ ID は test）
bash {SKILL_DIR}/add-required-checks.sh \
  --repo "$(gh repo view --json nameWithOwner -q .nameWithOwner)" \
  --add-check "test"
```

```bash
# gem のプロジェクトの場合（ci.yml は name: Ruby ${{ matrix.ruby-version }}）
# サポートバージョンごとに --add-check を並べる
bash {SKILL_DIR}/add-required-checks.sh \
  --repo "$(gh repo view --json nameWithOwner -q .nameWithOwner)" \
  --add-check "Ruby 3.2" --add-check "Ruby 3.3" --add-check "Ruby 3.4"
```

### 4. 言語非依存の GitHub セットアップ

`setup-github-workflows` スキルを実行する。`auto-merge` ラベル・`PR_AUTO_MERGER_*` /
`REPO_HOUSEKEEPER_*` の登録と、`actionlint` / `zizmor` の required 追加は同スキルが行う。
失敗した場合は同スキルの前提条件を確認して再実行する。

## Phase 4: 手動対応チェックリストの出力

実行完了後に以下をチェックリスト形式で出力する。

### 共通

- [ ] GitHub: Dependabot malware alerts を有効化（Settings > Security）

### gem のプロジェクトの場合のみ

- [ ] RubyGems.org: Trusted Publishing を設定
  - 登録項目: gem 名・GitHub owner・リポジトリ名・workflow ファイル名（`release.yml`）
