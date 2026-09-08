# Ipe Example Files

このレポジトリは，Ipeの公式バイナリに含まれないオリジナルのIpeのテンプレートやスクリプトなどを管理しています。

## 各ディレクトリの説明

### bin
Ipe に関係する.exeファイルが入っています。

### ipelets
Ipe に機能を付け加えたり設定するためのファイルが入っています。
- `goodies.lua`: 標準 Goodies（回転・反転・精密変形・精密ボックス等）に加えて **「Insert rounded rectangle」**（角丸四角形描画、`Alt+B`）、**「Round selected rectangle」**、半径調整機能を統合した拡張 ipelet。
- `matlab_import.lua`: MATLAB で出力したベクター PDF / IPE をスライドや図面に直接インポートし、MATLAB カラーパレット（`color_matlab.isy`）の自動適用、スケーリング（1:1 / スライドフィット / 線画のみ選択ダイアログ）、不要な白背景の除去を行う ipelet。
- `style_switcher.lua`: フォントやプロジェクター用カラーモードを切り替える ipelet。
- `pdfandipeimport.lua`: 汎用 PDF / IPE 挿入 ipelet。
- `handout.lua`: Appendix ページを除外した配布用 PDF をワンクリック出力する ipelet。
- `pagenumbers.lua`: ページ番号自動付与フック。
- `textbox_background.lua`: 選択したテキストボックス（または複数選択・図形群）の周囲に白（または任意色）の背景ボックス（四角または角丸）を自動計算して一括挿入・グルーピングする ipelet（`Alt+W`: 四角背景, `Alt+Shift+W`: 角丸背景, `Alt+Ctrl+W`: 背景除去）。
- `customize.lua`: エディタ設定・自動保存・ショートカット（`Alt+B`, `Alt+W` 等）定義。

### styles
Ipe のスタイルシート (.isy) が入っています。

### templates
Ipe を用いたテンプレート(プレゼンテーション用スライドなど)が入っています。

### examples
MATLAB グラフ連携のサンプルスクリプトやテンプレート (`examples/matlab_plot_example/`) が入っています。

## Ipe の設定（参照先パスの設定）

本リポジトリで管理しているスタイルシート（`styles/`）や ipelet（`ipelets/`）を Ipe に自動認識させるための設定手順です。

### Linux / macOS の設定 (`ipe.conf`)

`~/.config/ipe/ipe.conf`（存在しない場合は新規作成）に以下の設定を記述します。

```ini
IPESTYLES = /path/to/IpeExample/styles:_
IPELETPATH = /path/to/IpeExample/ipelets:_
```

- パス区切りにはコロン `:` を使用します。
- `_`（アンダースコア）は Ipe 標準の組み込みディレクトリを表します。
- `_` の前に本リポジトリのパスを記述することで、リポジトリ内のスタイルシート（`basic.isy` など）が Ipe 標準のスタイルより優先して適用されます。

### Windows の設定（環境変数）

Windows では、「システム環境変数の編集」（または PowerShell 等）からユーザー環境変数を追加・設定します。

- `IPESTYLES`: `C:\path\to\IpeExample\styles;_`
- `IPELETPATH`: `C:\path\to\IpeExample\ipelets;_`

※ パス区切りにはセミコロン `;` を使用し、末尾に `;_` を付加します。

### 既存ドキュメントへのスタイル更新の反映

参照先のスタイルシート（`.isy`）を編集・更新した際、すでに作成済みの `.ipe` ファイルへ最新の定義を反映するには以下のいずれかを実行します。

- GUI: Ipe でファイルを開き、メニューの `Edit` > `Update stylesheets`（ショートカット: `Ctrl+Shift+U` / macOS: `Cmd+Shift+U`）を実行して保存
- CLI: `ipescript` コマンドを使用
  ```sh
  ipescript update-styles <file>.ipe
  ```

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

#### 追加済みフォント一覧と入手先

本リポジトリのスタイルシートで使用しているフォントと、そのダウンロード元・入手先の一覧です。

| スタイルシート | 欧文フォント | 和文フォント | 入手方法 / ダウンロード元 |
|---|---|---|---|
| [`font_notosans.isy`](file:///home/keigo-suzuki/Documents/Repositories/IpeExample/styles/font_notosans.isy) | Noto Sans Regular | Source Han Sans JP (源ノ角ゴシック) | <ul><li>欧文: [Google Fonts: Noto Sans](https://fonts.google.com/specimen/Noto+Sans)</li><li>和文: [GitHub: adobe-fonts/source-han-sans](https://github.com/adobe-fonts/source-han-sans) (または [Google Fonts: Noto Sans JP](https://fonts.google.com/specimen/Noto+Sans+JP))</li></ul> |
| [`font_plexsans.isy`](file:///home/keigo-suzuki/Documents/Repositories/IpeExample/styles/font_plexsans.isy) | IBM Plex Sans | IBM Plex Sans JP | <ul><li>欧文: [Google Fonts: IBM Plex Sans](https://fonts.google.com/specimen/IBM+Plex+Sans) / [GitHub: IBM/plex](https://github.com/IBM/plex)</li><li>和文: [Google Fonts: IBM Plex Sans JP](https://fonts.google.com/specimen/IBM+Plex+Sans+JP)</li></ul> |
| [`font_meiryo_segoe.isy`](file:///home/keigo-suzuki/Documents/Repositories/IpeExample/styles/font_meiryo_segoe.isy) | Segoe UI | Meiryo (メイリオ) | Windows 標準搭載フォント（Windows 以外の環境ではライセンスを持つ Windows PC からコピー） |
| [`font_times.isy`](file:///home/keigo-suzuki/Documents/Repositories/IpeExample/styles/font_times.isy) | Times / Helvetica | 原ノ味フォント (Harano Aji) | TeX Live 標準同梱（追加インストール不要） |

#### OS別フォント追加手順

ダウンロードしたフォントファイル（`.otf`, `.ttf`, `.ttc`）は、各 OS のフォントディレクトリに配置してシステムおよび LuaTeX から参照できるようにします。

##### Linux
1. フォントファイルをユーザーフォントディレクトリに配置します。
   ```sh
   mkdir -p ~/.local/share/fonts
   cp <フォントファイル> ~/.local/share/fonts/
   ```
2. フォントキャッシュを更新します。
   ```sh
   fc-cache -fv ~/.local/share/fonts
   ```
3. フォントが認識されているか確認します。
   ```sh
   fc-list | grep -i "<フォント名>"
   ```

##### macOS
- GUI: フォントファイルをダブルクリックして「フォントをインストール」をクリックするか、「Font Book」アプリを開いてフォントファイルをドラッグ＆ドロップします。
- 手動 / CLI: フォントファイルを `~/Library/Fonts/` にコピーします。
  ```sh
  cp <フォントファイル> ~/Library/Fonts/
  fc-cache -f ~/Library/Fonts
  ```
- 確認: ターミナルで `fc-list | grep -i "<フォント名>"` または「Font Book」アプリで検索して確認します。

##### Windows
- GUI: フォントファイルを右クリックし、「すべてのユーザーに対してインストール」（または「インストール」）を選択します。
- 設定アプリ: 「設定」 > 「個人用設定」 > 「フォント」を開き、フォントファイルをドラッグ＆ドロップしてインストールします。

#### OS付属フォント（Segoe UI / Meiryo / Hiragino 等）の移行について

Segoe UI や Meiryo、ヒラギノなどの商用・OS 付属フォントは再配布が禁止されているため、Web 上から直接ダウンロードすることはできません。別 OS（Linux 等）で使用する場合は、**自身が正当なライセンスを保持する環境から個人利用の範囲でコピー**して使用してください。

- Windows からのフォント抽出: `C:\Windows\Fonts\` 以下（例: `segoeui*.ttf`, `meiryo*.ttc`）
- macOS からのフォント抽出: `/System/Library/Fonts/` および `/Library/Fonts/` 以下（例: `ヒラギノ角ゴシック*.ttc`）

フォントをコピーした後は、上記の OS 別手順に従ってフォントディレクトリへ配置・登録してください。`.isy` 内の `\setsansfont` / `\setsansjfont` に指定する名称は、`fc-list` で出力される family 名と一致させる必要があります。

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
