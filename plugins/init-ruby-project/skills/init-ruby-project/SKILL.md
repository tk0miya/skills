---
name: init-ruby-project
description: Ruby プロジェクトの初期セットアップを自動化する
disable-model-invocation: true
---

# init-ruby-project

Ruby プロジェクトの初期セットアップを自動化するスキルです。

## 事前チェック（自動実行）

以下を実行し、gh コマンドが利用可能かチェックする。失敗した場合はエラーメッセージを表示して処理を中断する。

```bash
gh auth status
```

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

- gemspec の `required_ruby_version` を `">= {RUBY_VERSION}"` に更新する
- Gemfile の `group :development` に以下を追加する:
  ```ruby
  gem "rake"
  gem "rbs"
  gem "rbs-inline"
  gem "rspec"
  gem "rubocop"
  gem "rubocop-numbered-params"
  gem "rubocop-rake"
  gem "rubocop-rspec"
  gem "steep"
  ```
- `bundle install` を実行
- `bundle lock --add-platform x86_64-linux aarch64-linux` を実行

### gem を作らない場合

```bash
mkdir {PROJECT_NAME} && cd {PROJECT_NAME}
bundle init
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
| `workflows/ci-gem.yml` | `.github/workflows/ci.yml` | gem を作る場合 |
| `dependabot.yml` | `.github/dependabot.yml` | 常時 |
| `workflows/rbs_collection.yml` | `.github/workflows/rbs_collection.yml` | 常時 |
| `workflows/auto-merge.yml` | `.github/workflows/auto-merge.yml` | 常時 |
| `workflows/dependabot-auto-label.yml` | `.github/workflows/dependabot-auto-label.yml` | 常時 |
| `workflows/release.yml` | `.github/workflows/release.yml` | gem を作る場合のみ |
| `workflows/actionlint.yml` | `.github/workflows/actionlint.yml` | 常時 |

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

`.gitignore` の先頭に以下のコメントを挿入し、末尾に以下を追記する:

先頭に挿入:
```
# NOTE: Entries are sorted in ASCII order.
```

ASCII 順を維持した適切な箇所に追記:
```
/.claude/settings.local.json
/.gem_rbs_collection/
```

`setup-ruby-hooks` スキルを実行して Claude Code hooks をセットアップする。

`setup-dev-workflow-hooks` スキルを実行して開発ワークフロー向け hooks をセットアップする。

## Phase 3: GitHub 操作（GitHub リポジトリ作成を選んだ場合のみ）

このスキルが配置されているディレクトリ（`skills/init-ruby-project/`）の `setup-github.sh` を実行する。

### gem を作らない場合

```bash
bash {SKILL_DIR}/setup-github.sh --project-name {PROJECT_NAME} --visibility {VISIBILITY}
```

### gem を作る場合

`--ruby-versions` に Phase 0 で入力したサポートバージョン一覧をスペース区切りで渡す。

```bash
bash {SKILL_DIR}/setup-github.sh --project-name {PROJECT_NAME} --visibility {VISIBILITY} --ruby-versions "{RUBY_VERSIONS_SPACE_SEPARATED}"
```

例: `"3.2 3.3 3.4"` を渡すと `required_status_checks` に `"Ruby 3.2"`・`"Ruby 3.3"`・`"Ruby 3.4"` が設定される。

## Phase 4: 手動対応チェックリストの出力

実行完了後に以下をチェックリスト形式で出力する。

### 共通

- [ ] GitHub: Dependabot malware alerts を有効化（Settings > Security）

### gem を作る場合のみ

- [ ] RubyGems.org: Trusted Publishing を設定
  - 登録項目: gem 名・GitHub owner・リポジトリ名・workflow ファイル名（`release.yml`）
