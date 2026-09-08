# MATLAB Plot to Ipe Integration Example

MATLAB で出力したベクタープロット（PDF）を、スタイル崩れなく Ipe スライドや論文に直接インポートして仕上げるワークフローの作例集です。

---

## 1. ワークフロー概要

```mermaid
flowchart LR
    A["1. MATLAB 解析・プロット<br/>setup_ipe_plot(fig, 'slide_multi')<br/>export_ipe_plot(fig, 'out.pdf')"] --> B["2. Ipe でのインポート<br/>Ipelets > Insert MATLAB Plot<br/>(スライド中央へ自動配置)"]
    B --> C["3. Ipe 上での微調整・仕上げ<br/>(注釈矢印・数式・ハイライト追加)"]
```

---

## 2. MATLAB 側の設定 (`MATLABExample/PlotTools`)

[MATLABExample/PlotTools/setup_ipe_plot.m](../../../MATLABExample/PlotTools/setup_ipe_plot.m) および [export_ipe_plot.m](../../../MATLABExample/PlotTools/export_ipe_plot.m) を使用します。

### プリセット一覧

| プリセット名 | 用途 | 物理寸法 (mm) | 基準フォント |
| :--- | :--- | :--- | :--- |
| **`'slide_single'`** | スライド用 単一プロット | $140 \times 105$ | 13 pt |
| **`'slide_multi'`** | スライド用 複合マルチプロット (2x1, 2x2, 3x3 等) | $200 \times 125$ | 10 pt |
| **`'paper_column'`** | 学会論文 1段組幅 (RSJ等) | $84 \times 65$ | 8.5 pt |
| **`'paper_full'`** | 学会論文 2段ぶち抜き幅 | $174 \times 75$ | 9 pt |
| **`'paper_multi'`** | 学会論文 複合サブプロット | $174 \times 110$ | 8.5 pt |

### スクリプト例

```matlab
% 1. 通常通りプロットを作成
fig = figure();
subplot(2, 2, 1); plot(t, y); xlabel('Time $t$ [s]'); ylabel('Response $y(t)$');
...

% 2. Ipe用プリセットを一括適用
setup_ipe_plot(fig, 'slide_multi');

% 3. 透明背景のベクターPDFとしてエクスポート
export_ipe_plot(fig, 'my_plot.pdf');
```

---

## 3. Ipe 側でのインポート (`IpeExample/ipelets`)

1. Ipe でスライドまたは原稿を開く。
2. メニューから **`Ipelets -> Insert MATLAB Plot`** を選択。
3. エクスポートした PDF を選択すると、ダイアログが表示され：
   - **配置モード**: `Auto-Fit to Slide Frame` / `Original 1:1 Size`
   - **カラーパレット自動適用**: `color_matlab.isy`（`matlab_blue`, `matlab_red` 等）
4. スライド中央に適切なフォントサイズ（True-Size LaTeX）と線画スタイルで一発配置されます。
5. `Ctrl+U` (Ungroup) で個別の曲線やテキストを自由に編集・装飾できます。

---

## 4. サンプルファイル

- `generate_plot_examples.m`: MATLAB 側でのプロット出力スクリプト（3種プリセットの作例）
- `plot_slide_single.pdf` / `plot_slide_multi.pdf` / `plot_paper_column.pdf`: 生成されたベクター PDF
- `matlab_graph_slide.ipe` / `matlab_graph_slide.pdf`: Ipe スライドに統合した完成作例
