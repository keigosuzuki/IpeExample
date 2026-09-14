# Vector Plot to Ipe Integration Example (MATLAB / Python)

MATLAB や Python (matplotlib) で出力したベクタープロット（PDF）を、スタイル崩れなく Ipe スライド（4:3 / 16:9）や論文原稿に直接インポートして仕上げるワークフローの作例です。

---

## 1. ワークフロー概要

```mermaid
flowchart LR
    A["1. MATLAB / Python 解析・プロット<br/>(ベクターPDF出力)"] --> B["2. Ipe でのインポート<br/>Ipelets > Insert Vector Plot<br/>(スライド中央へ自動配置)"]
    B --> C["3. Ipe 上での微調整・仕上げ<br/>(True-Size LaTeX & カラー調整)"]
```

---

## 2. 各ツールの出力ベストプラクティス

### A. MATLAB の場合 (`MATLABExample/PlotTools`)

[MATLABExample/PlotTools/setup_ipe_plot.m](../../../MATLABExample/PlotTools/setup_ipe_plot.m) および [export_ipe_plot.m](../../../MATLABExample/PlotTools/export_ipe_plot.m) を使用します。

| プリセット名 | 用途 | 物理寸法 (mm) | 基準フォント |
| :--- | :--- | :--- | :--- |
| **`'slide_single'`** | スライド用 単一プロット | $140 \times 105$ | 13 pt |
| **`'slide_multi'`** | スライド用 複合マルチプロット (2x1, 2x2 等) | $200 \times 125$ | 10 pt |
| **`'paper_column'`** | 学会論文 1段組幅 | $84 \times 65$ | 8.5 pt |
| **`'paper_full'`** | 学会論文 2段ぶち抜き幅 | $174 \times 75$ | 9 pt |
| **`'paper_multi'`** | 学会論文 複合サブプロット | $174 \times 110$ | 8.5 pt |

```matlab
% スクリプト実行例
setup_ipe_plot(fig, 'slide_single');
export_ipe_plot(fig, 'plot_slide_single.pdf');
```

---

### B. Python (matplotlib) の場合

テキストをアウトライン（パス）化せず、文字データとして PDF に出力するために `pdf.fonttype = 42` (TrueType) を設定します。

```python
import matplotlib.pyplot as plt

# --- Ipe 連携向け必須設定 ---
plt.rcParams['pdf.fonttype'] = 42
plt.rcParams['ps.fonttype'] = 42
plt.rcParams['axes.unicode_minus'] = False  # マイナス記号の文字化け防止
plt.rcParams['mathtext.fontset'] = 'dejavusans'  # Unicode準拠の数式フォント (文字化け防止)

# スライド向け寸法指定 (mm -> inch)
MM_TO_INCH = 1.0 / 25.4
fig, ax = plt.subplots(figsize=(140 * MM_TO_INCH, 105 * MM_TO_INCH))

# プロット作成
ax.plot(t, y, label=r'$\zeta = 0.2$')
ax.set_xlabel('Time $t$ [s]', fontsize=13)
ax.set_ylabel('Response $y(t)$', fontsize=13)

fig.tight_layout()
fig.savefig('python_plot_single.pdf', bbox_inches='tight')
```

---

## 3. 作例ファイル一覧

| ファイル | 役割・内容 |
| :--- | :--- |
| **`generate_plot.m`** | MATLAB プロット出力スクリプト（単一・複合2x2） |
| **`generate_plot.py`** | Python (matplotlib) プロット出力スクリプト（単一・複合2x2） |
| **`plot_slide_single.pdf`** / **`python_plot_single.pdf`** | 単一プロット出力例（ベクターPDF） |
| **`plot_slide_multi.pdf`** / **`python_plot_multi.pdf`** | 複合2x2マルチプロット出力例（ベクターPDF） |
| **`matlab_graph_slide.ipe`** / **`matlab_graph_slide.pdf`** | スライドテンプレート（4:3）にインポート・統合した完成作例 |
