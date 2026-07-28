---
name: init-ruby-project
description: Ruby プロジェクトの初期セットアップを自動化する
license: Apache-2.0
disable-model-invocation: true
---

# init-ruby-project

Ruby プロジェクトの初期セットアップを自動化するスキルです。

## 事前チェック（自動実行）

以下を実行し、`gh` が認証済みか、Bundler が 4.0.13 以降かをチェックする。

```bash
gh auth status
bundle --version
```

4.0.13 未満の Bundler は Phase 1 で付与する `cooldown`（公開直後の gem を一定期間使わない
供給チェーン対策）を**黙って無視する**ため、cooldown の効かないプロジェクトができあがる。
その場合は `gem install bundler` で更新してから再実行するようユーザーに伝えて中断する
（ユーザーの環境を断りなく書き換えない）。

## Phase 0: ユーザーへの確認（必須・実行前に全項目を一度に質問する）

以下の項目をまとめて質問し、回答を得てから次のフェーズに進む。

1. プロジェクト名（例: my-awesome-gem）
2. 対象 Ruby バージョン（例: 3.3）
3. gem を作るか（yes / no）
   - yes の場合: サポートする Ruby バージョン一覧（例: 3.2, 3.3, 3.4）
4. GitHub リポジトリを今すぐ作成するか（yes / no）
   - yes の場合: リポジトリの visibility（public / private）

## Phase 1: 雛形生成（自動実行）

### gem を作る場合

```bash
bundle gem {PROJECT_NAME} --ci=github --test=rspec
```

- gemspec を整える（後述の「gemspec の整備」に従う）
- `bundle gem` が生成した spec ファイル（`spec/` 以下の `*_spec.rb`。`spec/spec_helper.rb` は残す）を削除する
  - 生成される example は 2 つとも残す価値がない。`it "does something useful"` は意図的に失敗するため CI が最初から赤で、Phase 3 で登録する required status checks を満たせず PR をマージできない。`it "has a version number"` は、コードに宣言的に書かれた定数をそのまま検証する価値の薄いテスト
  - example が 0 件でも `rake ci` は成功する
- Gemfile の `source "https://rubygems.org"` 行に cooldown を付与する:
  ```ruby
  source "https://rubygems.org", cooldown: 7
  ```
- Gemfile の `group :development` に以下を追加する:
  ```ruby
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
  ```
- `bundle install` を実行
- `bundle lock --add-platform x86_64-linux aarch64-linux` を実行

#### gemspec の整備

`bundle gem` が生成した gemspec に対して以下を行う。

1. `required_ruby_version` を `">= {RUBY_VERSION}"` に更新する。

2. `spec.files` の除外リスト（`f.start_with?(*%w[...])`）に開発用ファイルを追加する。
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

3. 実体のない雛形コメントを削除する。

   - `# Uncomment to register a new dependency of your gem` と、続く
     `# spec.add_dependency "example-gem", "~> 1.0"`
   - `# For more information and examples about making a new gem, check out our`
     `# guide at: https://bundler.io/guides/creating_gem.html`

### gem を作らない場合

```bash
mkdir {PROJECT_NAME} && cd {PROJECT_NAME}
bundle init
```

- Gemfile の `source "https://rubygems.org"` 行に cooldown を付与する:
  ```ruby
  source "https://rubygems.org", cooldown: 7
  ```
- Gemfile に以下を追加する:
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

## Phase 2: 設定ファイルの配置（自動実行）

このスキルが配置されているディレクトリ（`skills/init-ruby-project/`）以下のテンプレートファイルを
プロジェクトにコピーし、以下のプレースホルダーを Phase 0 の回答で置換する。

### 置換ルール

| プレースホルダー | 置換値 |
|---|---|
| `{{PROJECT_NAME_SNAKE}}` | プロジェクト名のハイフンをアンダースコアに変換したもの（例: `my-awesome-gem` → `my_awesome_gem`） |
| `{{RUBY_VERSION}}` | Phase 0 で入力した対象 Ruby バージョン（最小バージョン） |
| `{{RUBY_VERSIONS}}` | Phase 0 で入力したサポートバージョン一覧を JSON 配列形式に変換したもの（例: `["3.2", "3.3", "3.4"]`）。gem を作る場合のみ使用 |

### 配置先

| テンプレート | 配置先 | 条件 |
|---|---|---|
| `.rspec` | `.rspec` | 常時 |
| `spec/spec_helper.rb` | `spec/spec_helper.rb` | gem を作らない場合 |
| `rubocop.yml` | `.rubocop.yml` | 常時 |
| `Steepfile` | `Steepfile` | 常時 |
| `Rakefile` | `Rakefile` | 常時（gem の場合は既存ファイルに `ci` タスクを追記） |
| `workflows/ci.yml` | `.github/workflows/ci.yml` | gem を作らない場合 |
| `workflows/ci-gem.yml` | `.github/workflows/ci.yml` | gem を作る場合（`bundle gem --ci=github` が生成した `.github/workflows/main.yml` は削除する） |
| `dependabot.yml` | `.github/dependabot.yml` | 常時 |
| `workflows/rbs_collection.yml` | `.github/workflows/rbs_collection.yml` | 常時 |
| `workflows/release.yml` | `.github/workflows/release.yml` | gem を作る場合のみ |

また、以下のテンプレートも配置する:

| テンプレート | 配置先 | 条件 |
|---|---|---|
| `vscode/settings.json` | `.vscode/settings.json` | 常時 |
| `vscode/extensions.json` | `.vscode/extensions.json` | 常時 |

設定ファイルの配置後、以下を実行する:

```bash
bundle exec rbs collection init
bundle exec rbs collection install
```

`bundle gem` が生成する `sig/` は手書きのスタブなので、rbs-inline で生成し直す
（gem を作らない場合は `lib/` が無いのでスキップする）:

```bash
bundle exec rake rbs:generate
```

`.gitignore` の先頭に以下のコメントを挿入し、末尾に以下を追記する（gem を作らない場合は
`.gitignore` が生成されていないので、この内容で新規作成する）:

先頭に挿入:
```
# NOTE: Entries are sorted in ASCII order.
```

ASCII 順を維持した適切な箇所に追記:
```
/.claude/settings.local.json
/.gem_rbs_collection/
```

### Claude Code hooks のセットアップ

`setup-dev-workflow-hooks` スキルを実行して汎用の開発ワークフロー hooks と permissions をセットアップする。
続けて `setup-ruby-hooks` スキルを実行して Ruby 向けの Claude Code hooks をセットアップする。

## Phase 3: GitHub 操作（GitHub リポジトリ作成を選んだ場合のみ）

### 1. 初回コミット

`gh repo create --push` はコミットが 1 つも無いと失敗するため、ここまでに生成した
ファイルをすべてコミットする。

このコミットには gemspec・RuboCop・RBS/Steep・GitHub Actions・エディタ設定などが同居するが、
雛形を実運用可能な状態にするまでが一続きの作業なので、意図的に 1 コミットにまとめている。
セルフレビューがコミット粒度の分割を指摘した場合は、その指摘だけ採用せずにコミットする
（粒度以外の指摘には通常どおり対応する）。

コミットする前に、`bundle gem` が残した TODO プレースホルダーを埋める（gem を作る場合のみ）。

リポジトリはまだ無いので、URL は `gh api user -q .login` とプロジェクト名から組み立てる。

- `homepage` と `metadata["source_code_uri"]`: `https://github.com/{OWNER}/{PROJECT_NAME}`
  （TODO のままだと RubyGems が URI として検証して `gem build` が落ちる）
- `metadata["changelog_uri"]`: `https://github.com/{OWNER}/{PROJECT_NAME}/blob/main/CHANGELOG.md`
- `metadata["allowed_push_host"]`: `https://rubygems.org`
- `summary` / `description` と `README.md`: ユーザーに確認する

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

### 3. Ruby の CI を required status checks に登録

`ci.yml` のジョブを required status checks に足す。gem を作ったかどうかで渡す context が
変わるので、**どちらか一方**を実行する。

```bash
# gem を作らない場合（ci.yml のジョブ ID は test）
bash {SKILL_DIR}/add-required-checks.sh \
  --repo "$(gh repo view --json nameWithOwner -q .nameWithOwner)" \
  --add-check "test"
```

```bash
# gem を作る場合（ci.yml は name: Ruby ${{ matrix.ruby-version }}）
# Phase 0 で入力したサポートバージョンごとに --add-check を並べる
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

### gem を作る場合のみ

- [ ] RubyGems.org: Trusted Publishing を設定
  - 登録項目: gem 名・GitHub owner・リポジトリ名・workflow ファイル名（`release.yml`）
