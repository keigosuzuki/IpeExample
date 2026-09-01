# Ipe Example Files

このレポジトリは，Ipeの公式バイナリに含まれないオリジナルのIpeのテンプレートやスクリプトなどを管理しています。

## 各ディレクトリの説明

## bin
Ipe に関係する.exeファイルが入っています。

### ipelets
Ipe に機能を付け加えたり設定するためのファイルが入っています。
- `matlab_import.lua`: MATLAB で出力したベクター PDF / IPE をスライドや図面に直接インポートし、MATLAB カラーパレット（`color_matlab.isy`）の自動適用、スケーリング、不要な白背景の除去を行う ipelet。
- `style_switcher.lua`: フォントやプロジェクター用カラーモードを切り替える ipelet。
- `pdfandipeimport.lua`: 汎用 PDF / IPE 挿入 ipelet。

### styles
Ipe のスタイルシート (.isy) が入っています。

### templates
Ipe を用いたテンプレート(プレゼンテーション用スライドなど)が入っています。

### examples
MATLAB グラフ連携のサンプルスクリプトやテンプレート (`examples/matlab_plot_example/`) が入っています。

## カラーパレット・フォントの追加方法

`styles/` 以下のスタイルシートは、1つのドキュメントに複数アタッチしてカスケードさせる前提で作られています(例: `color_jaxa.isy` + `font_notosans.isy` + `slide_suzuki_4_3.isy`)。新しいカラーパレットやフォントを追加するときも、既存の構造や色を上書きするのではなく、単体で組み合わせられる小さなファイルとして追加してください。

### カラーパレットを追加する

1. `styles/color_<名前>.isy` というファイルを作る(例: `color_cud.isy`, `color_jaxa.isy`)。
2. 中身は `<color name="..." value="R G B"/>` を並べるだけ。

    ```xml
    <ipestyle name="color_<名前>">
    <color name="foo_red" value="0.8 0.1 0.1"/>
    <color name="foo_blue" value="0.1 0.3 0.8"/>
    </ipestyle>
    ```
3. `<ipestyle name="...">` の name はファイル名(拡張子を除いた部分)と一致させること。Ipe はこの name でスタイルシートを検索します。

状況によって特定の色だけ差し替えたい場合(例: 投影時は `black` をグレーにしたい)は、既存の色を丸ごと定義し直すのではなく、対象の色だけを再定義する小さな差分ファイルを作り、本体のカラーパレットより**後に**読み込ませます。`color_mode_projector.isy` がこのパターンの実例です。Ipe はスタイルシートを複数アタッチでき、後から読み込んだものが同名の色・フォントなどを上書きします。

### フォントを追加する

1. `styles/font_<名前>.isy` を作り、`<preamble>` 内で LuaTeX / pdfTeX を分岐させます(このリポジトリの実テンプレートは `info tex="luatex"` 固定なので LuaTeX 側が本番、pdfTeX 側は簡易フォールバックです)。

    ```xml
    <ipestyle name="font_<名前>">
    <preamble>

    \usepackage{iftex}

    \ifluatex
        \usepackage[deluxe,expert,haranoaji]{luatexja-preset}
        \setsansfont{<欧文フォント名>}[
            BoldFont=<欧文フォント名 Bold>,
            ItalicFont=<欧文フォント名 Italic>,
            BoldItalicFont=<欧文フォント名 Bold Italic>,
        ]
        \setsansjfont{<和文フォント名>}[
            BoldFont=<和文フォント名 Bold>,
        ]
        \renewcommand{\familydefault}{\sfdefault}
        \renewcommand{\kanjifamilydefault}{\gtdefault}

    \else\ifpdftex
        \usepackage{amsmath}
        \usepackage{newtxtext}
        \usepackage[whole]{bxcjkjatype}
        \renewcommand\familydefault{\sfdefault}

    \else
    \fi\fi

    </preamble>
    </ipestyle>
    ```

2. **数式フォントを忘れないこと。** `\dfrac` や `\int` などは `amsmath` が無いと未定義エラーになります。`notomath`(Noto Sans)や `unicode-math` + 専用数式フォント(IBM Plex Sans の `plex-otf` など)があれば読み込んでください。専用の数式フォントが無いフォント(Times, Segoe UI/Meiryo など)は、`\usepackage{amsmath}` を明示的に読み込むだけで構いません(既定の Latin Modern Math になり本文とは字形が揃いませんが、それ自体は許容しています)。
3. `plex-otf` のように `luatexja` を内包しないパッケージで和文フォントを併用する場合は、`\usepackage[no-math,deluxe]{luatexja-preset}` を別途読み込んで `\setsansjfont` を有効にしてください(`no-math` を付けて数式フォント側と競合しないようにします)。
4. ウェイト違いなど状況に応じて切り替えたいものは、カラーパレットと同様に「後から読み込んで一部だけ上書きする」差分ファイルとして追加可能です。

#### システムに目的のフォントが無い場合

Noto Sans や Source Han Sans、IBM Plex は TeX Live やシステムに標準で入っていることが多いですが、Segoe UI や Meiryo、Hiragino のような OS 付属フォントは別途用意する必要があります。これらは商用フォントで自由に再配布できないため、**自分が正当にライセンスを持つ環境から個人利用の範囲でコピーする**必要があります(インターネット上から拾ってくることはしないでください)。

1. ライセンス済みの Windows/macOS 環境(実機・VM・デュアルブートなど)からフォントファイルを取り出す。
    - Windows: `C:\Windows\Fonts\` 以下(例: `segoeui.ttf`, `meiryo.ttc`)
    - macOS: `/System/Library/Fonts/` および `/Library/Fonts/` 以下(例: `Helvetica Neue.ttc`, `ヒラギノ角ゴシック W3.ttc`)
2. 取り出したファイルを Linux 側のユーザーフォントディレクトリにコピーし、フォントキャッシュを更新する。

    ```sh
    mkdir -p ~/.local/share/fonts
    cp <コピーしたフォントファイル> ~/.local/share/fonts/
    fc-cache -f ~/.local/share/fonts
    ```
3. 認識されたか確認する。

    ```sh
    fc-list | grep -i "<フォント名>"
    ```
4. `.isy` の `\setsansfont`/`\setsansjfont` に指定した名前が `fc-list` の family 名と一致しているか確認してから、実際に Ipe(または `iperender`)でコンパイルして確かめてください。太字・斜体が別ファイルのフォントは `BoldFont=`/`ItalicFont=` に family 名をそのまま指定して問題ありません。

### Style Switcher ipelet への登録

新しいフォント・カラーモードを Ipe の Ipelets メニューから切り替えられるようにする場合は、`ipelets/style_switcher.lua` を編集します。

1. `FONT_GROUP`(フォントの場合)または該当する `*_GROUP` に、新しいスタイルシート名(拡張子なし)を追加する。
2. `ALL_MANAGED` にも同じ名前を追加する。
3. `setFont`(または対応する関数)に選択肢を追加し、読み込む `.isy` ファイル名を指定する。
4. `methods` テーブルにメニュー項目を追加する。

### 動作確認

追加したら、最低限以下を確認してください。

- Ipe で実際に開いて `Ipelets > Style Switcher` から切り替え、太字・斜体・和文・数式・`\good`/`\bad` アイコンなどが崩れずに表示されること。
- コマンドラインで素早く確認したい場合は `iperender -pdf <file>.ipe <file>.pdf` で単体レンダリングできます(複数ページのテンプレートを丸ごと書き出す場合は `iperender` ではなく `ipetoipe -pdf` を使ってください。`iperender` は 1 ページのみの書き出しです)。

## Ipe について

Ipeはpdfなどベクター形式の図を作成できるフリーのドローソフトです。([公式サイト](http://ipe.otfried.org/) / [Wikipedia](https://ja.wikipedia.org/wiki/Ipe) / [Facebook](https://www.facebook.com/drawing.editor.Ipe7/))

### 特徴
- CAD的な操作で美しいベクターの図が作成できる
- LaTeXの数式や表などを挿入できLaTeXとの親和性が高い
- ベクターの図 (.pdf) だけでなくスライドやポスターも作成可能
- Windows / macOS / Linux で利用可能
- フリーソフト (GNU General Public Licence)

### インストール方法
1. [Ipe official page](http://ipe.otfried.org/)から最新版を自分のOS (Windows/macOS/Linux) に合わせてダウンロード
2. PC内の好きな場所に置く (例:WindowsならCドライブ直下やProgram Filesの中など)
