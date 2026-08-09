---
name: self-review
description: これからコミットする変更をセルフレビューする。
license: Apache-2.0
context: fork
agent: Explore
---

# self-review

これからコミットする変更をセルフレビューし、結果を呼び出し元に報告する。

## 手順

### 1. レビュー観点を組み立てる

同梱の観点ファイルを読み込む（パスはこのスキルのディレクトリからの相対）。

- **常に** `references/common.md` を読む。
- 判定材料に該当する観点ファイルがあれば追加で読む（複数該当すれば全て加算）。

| 判定材料 | 追加で読む観点 |
|---|---|
| `Gemfile` または `*.gemspec` がある | `references/ruby.md` |
| `skills/**/*.md` を変更している | `references/skill-review.md` |
| `README*` / `CHANGELOG*` などのドキュメントを変更している | `references/docs.md` |
| `CLAUDE.md` を変更している | `references/claude-md.md` |
| `.claude/rules/**` を変更している | `references/rules.md` |

### 2. 変更をレビューする

`git status --porcelain -uall` と `git diff HEAD`（必要に応じて `git diff --staged`）で、最後のコミット以降の未コミット変更を確認する。未追跡ファイルは `git diff HEAD` に現れないので内容を直接読む（`-uall` を付けないと未追跡ディレクトリが 1 行に畳まれ、配下のファイルが分からない）。**未コミットの変更が無ければ、その旨を報告して終了する。**

未コミットの変更があれば、まず CLAUDE.md を読んでプロジェクトの規約と慣習を把握し、組み立てた観点でその変更をレビューする。

git worktree で作業している場合（作業ディレクトリが `.claude/worktrees/` 配下）は、git コマンドは `cd <path> && git` ではなく `git -C <worktree-path>` を使う。また可能な限り `&&` でコマンドを連結せず、1 コマンドずつ実行する。

### 3. 呼び出し元に報告する

レビュー結果に応じて次を返す。

- **指摘がある場合**：指摘内容（と必要なら修正案）を返す。
- **指摘がない場合**：`references/commit.md` の方針に従って、どうコミット・整理し、この後どう PR を作成・更新するのが良いかを、呼び出し元が同ファイルを読まずに実行できる粒度で伝える。
