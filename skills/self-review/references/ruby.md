# Ruby レビュー観点

Ruby プロジェクト（`Gemfile` / `*.gemspec` あり）で共通観点に加算する。

## 属性へのアクセス

クラスを定義する際、以下を確認する。

- **属性へのアクセスは `attr_reader` / `attr_writer` / `attr_accessor` で定義したアクセサを介す**ことを原則としているか。とくに属性を参照する際は、インスタンス変数（`@foo`）を直接読まず `attr_reader` 経由で参照しているか。
- **インスタンス変数への直接アクセスは最低限に留めて**いるか。直接アクセスが許容されるのは、`#initialize` での初期化、メモ化（`@foo ||= ...`）、状態更新メソッドでの代入など、アクセサでは表現できない箇所に限る。

### 望ましい形

```ruby
class User
  attr_reader :name, :email

  def initialize(name, email)
    @name = name    # #initialize での初期化は直接代入でよい
    @email = email
  end

  def greeting
    "Hello, #{name}"    # 参照は attr_reader 経由（@name ではなく name）
  end

  def display_name
    @display_name ||= name.upcase    # メモ化は直接アクセスでよい
  end
end
```

参照は `attr_reader` 経由で行い、インスタンス変数への直接アクセスは初期化・メモ化・状態更新に限定している。

## コメント

共通観点（`common.md`）に加えて、以下を確認する。

- **`attr_reader` や `Data` クラスの属性には、型コメント（`#:`）の後ろに属性の説明を書いて**いるか。1 行形式のため、端的な記述を求める。

```ruby
attr_reader :message #: String -- ユーザーに通知するメッセージ本文
```

## RSpec の書き方

以下の規約に沿って書けているかを確認する。

### 構造（describe / context / example）

- **`describe` でテスト対象を定義**しているか（対象のクラス・メソッドを `describe` で表す）。
- **`describe` は 2 階層までで表現**しているか。`describe` はクラス・メソッドや対象の機能といったテスト対象を表すために使う箇所であり、機能の側面（「〜の場合」「〜のとき」といった条件や観点）を `describe` で表現していないか。側面の表現は `context` や example で行う。
- **実行条件（「〜の場合」）を必ず `context` で表現**しているか。
- **各 `context` の実行条件を実現・表現するように、その `context` 内で `before` / `let` を定義**しているか。
- **1 つの `context` につき example は 1 つ**か（1 つの example 内に複数の `expect` を書くのは可）。同じ実行条件の下で複数の値を検証したい場合は、**example を分割せず 1 つの example にまとめ、その中に複数の `expect` を並べる**。「検証ごとに example を分ける」形になっていないか確認する。
- **example の説明には実行結果の期待値（「〜になること」「〜すること」）だけ**を書き、実行条件を含めていないか（条件は `context` 側に置く）。ただし後述の `is_expected.to` ワンライナー集約に該当する場合は、説明を省略してよい。

### context のツリー構造

- **実行条件が対応関係を持つ場合、`context` をツリー構造で表現**しているか。同じ階層には、同じ状態を表現する `context` が並ぶのが理想。
- **テスト対象が意味的な分岐（振る舞いが変わる条件）を持つ場合、分岐に対応する `context` が欠けていないか（ツリーの非対称）を、網羅性の観点として確認**しているか（例：`未ログインの場合` があるのに `ログイン済みの場合` が無い、等）。対比の軸にするのは**外部から観測できる振る舞いの分岐**であり、実装の内部構造をそのまま写すことではない。
- **組み合わせ条件は `context` をネストして表現**しているか（context が階層構造を持つことを恐れない）。
- **新たな `context` を追加する際は、既存の context ツリー全体を確認**し、ツリーの意味や対応関係が崩れていないか確認しているか。既存の構造と合致しない場合は、context ツリーの適切な場所への移動やリファクタリングを検討する。
- **既存の spec と重複するテストを追加していない**か。新しく足す example / `context` が、既存のテストで既に検証済みの内容と重複していないか、既存 spec 全体を見て確認する。重複があれば追加せず、既存のテストに集約する（同じ実行条件・同じ期待結果のテストが 2 か所に存在しないようにする）。
- **散在・重複した `context` を統合できない**か確認しているか。同じ分岐軸・同じ状態を表す `context` が別々の場所に散在していないか、共通の `let` / `before` を共有する `context` を 1 つの親 `context` にまとめられないか、という具体基準で整理する。

### テスト対象（subject）

- **`subject` にテスト対象のコードを定義**しているか（実行する対象の呼び出しを `subject` に置く）。
- **名前付き `subject`（`subject(:name)`）を使っていない**か。
- **example 内にテスト対象のコードを直接書いていない**か（呼び出しは `subject` を通す）。

### 検証（expectation）

- 検証は基本 **`expect(...).to`** で書き、example の説明で期待結果を明示しているか。
- ただし **`expect` 文が 1 行で収まり、なおかつ example の説明が検証内容の単なる言い換えになる場合は、`is_expected.to` のワンライナーに集約**しているか。説明と検証内容が重複するため、`it { is_expected.to ... }` の形にまとめる。
- **ワンライナー（`it { is_expected.to ... }`）は、その `context` の検証が 1 つだけの場合にのみ使う**か。複数の値を検証したいがためにワンライナーを複数行並べ、1 つの `context` に複数 example を作っていないか（その場合は前述の「1 context につき example は 1 つ」に従う）。

```ruby
# 悪い例：同じ実行条件なのに検証ごとに example を分けている
context "when the user is registered" do
  it { is_expected.to be_persisted }
  it { expect(subject.name).to eq("Alice") }
  it { expect(subject.role).to eq(:member) }
end

# 良い例：1 つの example にまとめ、複数の expect を並べる
context "when the user is registered" do
  it "registers the user with the given attributes" do
    expect(subject).to be_persisted
    expect(subject.name).to eq("Alice")
    expect(subject.role).to eq(:member)
  end
end
```

### マッチャー

- **`include` マッチャーは必要な場合のみ使っている**か。`include` は目的の値が入っていることのみを確認し、その他の要素・計算結果は検証しない。そのため本来検証すべき値の誤りを見逃し、誤ったテストになることがある。
- `include` が適切なのは、**指定した値だけに着目したい場合**や、**コンテナ側に検証対象外のノイズとなる値が含まれる場合**などに限られる。それ以外で結果全体を検証できるなら、`eq` / `match` / `contain_exactly` など全体を比較するマッチャーを使えていないかを確認する。

```ruby
# コンテナ全体を検証できるなら eq / match で比較する
it { is_expected.to eq([1, 2, 3]) }

# ノイズを含む・特定の値だけに着目するなど、include が適切な場合のみ使う
it { is_expected.to include(:required_key) }
```

### 望ましい形

```ruby
RSpec.describe Calculator do
  describe "#divide" do
    subject { calculator.divide(dividend, divisor) }

    let(:calculator) { Calculator.new }
    let(:dividend) { 10 }

    context "when the divisor is non-zero" do
      let(:divisor) { 2 }

      it "returns the quotient" do
        expect(subject).to eq(5)
      end
    end

    context "when the divisor is zero" do
      let(:divisor) { 0 }

      it "raises ZeroDivisionError" do
        expect { subject }.to raise_error(ZeroDivisionError)
      end
    end
  end

  describe "#positive?" do
    subject { calculator.positive?(value) }

    let(:calculator) { Calculator.new }

    context "when the value is greater than zero" do
      let(:value) { 1 }

      it { is_expected.to be_truthy }
    end
  end
end
```

テスト対象の呼び出しは `subject` に集約し、実行条件は `context` に、期待結果は `it` に分離している。`#positive?` の example のように、`expect` 文が 1 行で収まり説明が検証内容の言い換えにしかならない場合は、`it { is_expected.to ... }` のワンライナーに集約する。
