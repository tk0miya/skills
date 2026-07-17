# Ruby レビュー観点

Ruby プロジェクト（`Gemfile` / `*.gemspec` あり）で共通観点に加算する。

## RSpec の書き方

以下の規約に沿って書けているかを確認する。

### 構造（describe / context / example）

- **`describe` でテスト対象を定義**しているか（対象のクラス・メソッドを `describe` で表す）。
- **実行条件（「〜の場合」）を必ず `context` で表現**しているか。
- **各 `context` の実行条件を実現・表現するように、その `context` 内で `before` / `let` を定義**しているか。
- **1 つの `context` につき example は 1 つ**か（1 つの example 内に複数の `expect` を書くのは可）。
- **example の説明には実行結果の期待値（「〜になること」「〜すること」）だけ**を書き、実行条件を含めていないか（条件は `context` 側に置く）。

### context のツリー構造

- **実行条件が対応関係を持つ場合、`context` をツリー構造で表現**しているか。同じ階層には、同じ状態を表現する `context` が並ぶのが理想。
- **組み合わせ条件は `context` をネストして表現**しているか（context が階層構造を持つことを恐れない）。
- **新たな `context` を追加する際は、既存の context ツリー全体を確認**し、ツリーの意味や対応関係が崩れていないか確認しているか。既存の構造と合致しない場合は、context ツリーの適切な場所への移動やリファクタリングを検討する。

### テスト対象（subject）

- **`subject` にテスト対象のコードを定義**しているか（実行する対象の呼び出しを `subject` に置く）。
- **名前付き `subject`（`subject(:name)`）を使っていない**か。
- **example 内にテスト対象のコードを直接書いていない**か（呼び出しは `subject` を通す）。

### 検証（expectation）

- 検証は基本 **`expect(...).to`** で書き、example の説明を明示しているか。`is_expected.to` は**ごくシンプルなケースのみ**許容する。

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
end
```

テスト対象の呼び出しは `subject` に集約し、実行条件は `context` に、期待結果は `it` に分離している。
