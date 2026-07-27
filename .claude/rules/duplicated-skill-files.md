---
paths:
  - "skills/*/add-required-checks.sh"
---

# スキル間で複製されているファイル

`gh skill install` はスキルを 1 つずつ独立に展開する。そのためスキルをまたぐ symlink は
インストール先で壊れ、リンク先の内容ではなくリンクパスを書いた数十バイトのテキストファイルが
置かれる。実装を共有したいファイルは symlink ではなく、各スキルに実体としてコピーしてある。

**重複を消すために symlink へ戻さないこと。** インストール結果が上記のとおり壊れる。
インストール済みの隣のスキルのファイルを直接参照するのも駄目で、`--scope user` /
`--scope project` で配置先が変わるため、スキル側からパスを解決できない。

## add-required-checks.sh

以下の 3 つは常に同一内容でなければならない。

- `skills/setup-github-workflows/add-required-checks.sh` ← 変更はこれに入れる
- `skills/init-ruby-project/add-required-checks.sh`
- `skills/init-typescript-project/add-required-checks.sh`

1 つだけ直すと実装が乖離する。変更したら、同じコミットの中で残りにも反映する。

```bash
for d in init-ruby-project init-typescript-project; do
  cp skills/setup-github-workflows/add-required-checks.sh "skills/$d/add-required-checks.sh"
done
```

コミット前に 3 つが一致していることを確認する（何も出力されなければ一致）。

```bash
for d in init-ruby-project init-typescript-project; do
  diff "skills/setup-github-workflows/add-required-checks.sh" \
       "skills/$d/add-required-checks.sh"
done
```

## リネーム・移動する場合

名前やパスを変えるときは、以下を 1 つのコミットで揃える。一部だけ変えると「複製である」
という関係がこのルールから辿れなくなり、次に編集する者が乖離に気付けない。

1. 複製すべてを `git mv` で同じ名前に変える
2. このルールの frontmatter `paths` と上のリストのパスを新しい名前に直す。`paths` が
   実ファイルに一致しなくなると、そのファイルを触ってもこのルールが読まれない
3. スキル側を直す。ファイル名は各スキルの `SKILL.md` や `setup.sh` にも書かれているので、
   `.sh` をリネームするだけでは、スキルは存在しないファイルを実行しようとして壊れる
   - `skills/init-ruby-project/SKILL.md` / `skills/init-typescript-project/SKILL.md` の
     `bash {SKILL_DIR}/add-required-checks.sh` の行
   - `skills/setup-github-workflows/setup.sh` の呼び出しとヘッダコメント
   - `skills/setup-github-workflows/SKILL.md`（本文とファイル一覧の表）
   - リネームする `.sh` 自身の `# Usage:` 行。`git mv` は中身を変えないので旧名が残る。
     複製すべてで同時に直す（片方だけ直すと内容が一致しなくなる）

漏れが無いことを確認する（残るのはリネーム後の名前だけになる）。

```bash
git grep -n add-required-checks
```

## 共有するファイルを増やす・やめる場合

増やす場合は同じ方針（実体コピー）で追加し、このルールの `paths` と上記のリストにそのファイルを
足す。やめる場合は該当の記述を消し、共有するファイルが 1 つも残らなくなったらこのルール自体を
消す。
