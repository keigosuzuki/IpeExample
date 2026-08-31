# MATLAB グラフの Ipe 連携サンプル & テンプレート

MATLAB で出力したグラフ（ベクター PDF）を `pdftoipe` で変換し、Ipe 上で数式ラベルや注釈の編集・スライドへの組み込みを行うサンプルプロジェクトです。

---

## 📁 含まれているファイル

- **`generate_plot.m`**: 減衰振動波形（2次遅れ系応答）を描画し、ベクター PDF `plot_raw.pdf` を出力する MATLAB スクリプト。
- **`plot_raw.pdf`**: MATLAB から出力された生のベクター PDF。
- **`plot_raw.ipe`**: `pdftoipe plot_raw.pdf plot_raw.ipe` により変換された中間 Ipe ファイル。
- **`matlab_graph_standalone.ipe` / `.pdf`**: 
  - MATLAB のグラフパスを取り込み、軸ラベルや凡例、タイトルを Ipe の LaTeX 数式フォント（`font_notosans.isy`）および MATLAB カラーパレット（`color_matlab.isy`）で整えた単体グラフテンプレート。
- **`matlab_graph_slide.ipe` / `.pdf`**:
  - 16:9 スライド（`slide_suzuki_16_9.isy`）上に MATLAB グラフを配置し、数式解説や箇条書き、引き出し線注釈を追加したプレゼンテーション用スライドテンプレート。

---

## 🚀 使い方・ワークフロー

### 1. MATLAB 側でベクター PDF を出力
`exportgraphics` を使用して、解像度に依存しないベクター形式（ContentType: vector）で出力します。

```matlab
% グラフの描画
fig = figure('Visible', 'off');
plot(t, y1, 'LineWidth', 1.8, 'Color', [0.00, 0.45, 0.74]);
...
% ベクターPDFとして保存
exportgraphics(fig, 'plot_raw.pdf', 'ContentType', 'vector');
```

### 2. Ipe 上での簡単インポート（推奨: `matlab_import.lua`）
Ipe のメニューから一発でスライドに挿入できます：
1. Ipe でスライドを開く。
2. **`Ipelets` > `MATLAB Plot Importer` > `Insert MATLAB Plot (Original 1:1 Size)`** を実行。
3. `plot_raw.pdf` を選択するだけで、薄いグリッド・MATLABカラー・目盛り数値・LaTeX数式凡例が自動適用されて中央に挿入されます。

### 3. コマンドラインで変換する場合（手動ワークフロー）
```sh
pdftoipe plot_raw.pdf plot_raw.ipe
ipe matlab_graph_standalone.ipe
# または
ipe matlab_graph_slide.ipe
```

- **グループ解除 (`Ctrl + U`)**: インポートしたグラフは 1 つのグループになっているため、解除してプロット線や軸を個別に編集可能です。
- **数式・ラベルの編集**: テキストオブジェクトをダブルクリックして、`$\zeta = 0.1$` や `時間 $t\ [\mathrm{s}]$` などの LaTeX 数式を直接打ち直せます。
- **配色の統一**: `styles/color_matlab.isy`（`matlab_blue`, `matlab_red`, `matlab_orange` 等）を使うことで、MATLAB の配色と完全一致した注釈や枠線を描くことができます。

### 4. PDF へのコンパイル（コマンドライン）
```sh
# 単一ページのクイック確認
iperender -pdf matlab_graph_slide.ipe output.pdf

# 完全な PDF 出力
ipetoipe -pdf matlab_graph_slide.ipe output.pdf
```
