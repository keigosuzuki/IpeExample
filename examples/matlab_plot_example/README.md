# MATLAB Plot to Ipe Integration Example

MATLAB で出力したベクタープロット（PDF）を、スタイル崩れなく Ipe スライド（4:3 / 16:9）に直接インポートして仕上げるワークフローの公式作例です。

---

## 1. ワークフロー概要

```mermaid
flowchart LR
    A["1. MATLAB 解析・プロット<br/>setup_ipe_plot(fig, 'slide_multi')<br/>export_ipe_plot(fig, 'out.pdf')"] --> B["2. Ipe でのインポート<br/>Ipelets > Insert MATLAB Plot<br/>(スライド中央へ自動配置)"]
    B --> C["3. Ipe 上での微調整・仕上げ<br/>(True-Size LaTeX & MATLABカラー)"]
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

### スクリプト実行方法

```bash
# プロットPDFを生成
matlab -batch "run('generate_plot.m')"
```

---

## 3. 作例ファイル構成（一本化）

| ファイル | 役割・内容 |
| :--- | :--- |
| **`generate_plot.m`** | 単一プロット（`slide_single`）および複合プロット（`slide_multi`）を出力する統合MATLABスクリプト |
| **`plot_slide_single.pdf`** | 単一ステップ応答プロット（ベクターPDF） |
| **`plot_slide_multi.pdf`** | 複合2x2マルチプロット（変位・速度・位相平面・周波数応答）（ベクターPDF） |
| **`matlab_graph_slide.ipe`** | スライドテンプレート（4:3）に統合した2ページ構成の完成Ipeドキュメント<br/>・Page 1: 単一プロット作例<br/>・Page 2: 複合マルチプロット作例 |
| **`matlab_graph_slide.pdf`** | LuaTeX コンパイル済みの完成スライドPDF |
