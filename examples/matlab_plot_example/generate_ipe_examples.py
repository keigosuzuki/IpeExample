import re
import xml.etree.ElementTree as ET

# Read plot_raw.ipe
with open('examples/matlab_plot_example/plot_raw.ipe', 'r') as f:
    raw = f.read()

paths = re.findall(r'<path[^>]*>[\s\S]*?</path>', raw)

filtered_paths = []
for p in paths:
    if '-1.05 268.481' in p or '369.45 268.481' in p:
        continue
    p_mod = p
    p_mod = re.sub(r'stroke="0\.000000 0\.450974 0\.741165" pen="[^"]*"', 'stroke="matlab_blue" pen="heavier"', p_mod)
    p_mod = re.sub(r'stroke="0\.850967 0\.329407 0\.101959" pen="[^"]*"', 'stroke="matlab_red" pen="heavier"', p_mod)
    p_mod = re.sub(r'stroke="0\.929398 0\.690186 0\.129410" pen="[^"]*"', 'stroke="matlab_orange" pen="heavier"', p_mod)
    p_mod = re.sub(r'stroke="0\.000000 0\.450974 0\.741165"', 'stroke="matlab_blue"', p_mod)
    p_mod = re.sub(r'stroke="0\.850967 0\.329407 0\.101959"', 'stroke="matlab_red"', p_mod)
    p_mod = re.sub(r'stroke="0\.929398 0\.690186 0\.129410"', 'stroke="matlab_orange"', p_mod)
    # Grid lines
    p_mod = re.sub(r'fill="0\.129410 0\.129410 0\.129410"', 'fill="gray" opacity="30%"', p_mod)
    # Box borders
    p_mod = re.sub(r'stroke="0\.129410 0\.129410 0\.129410" pen="[^"]*"', 'stroke="black" pen="normal"', p_mod)
    p_mod = re.sub(r'stroke="0\.129410 0\.129410 0\.129410"', 'stroke="black"', p_mod)
    filtered_paths.append(p_mod)

graph_objects_xml = "\n".join(filtered_paths)

# Standalone template
standalone_template = f"""<?xml version="1.0"?>
<!DOCTYPE ipe SYSTEM "ipe.dtd">
<ipe version="70218" creator="Ipe 7.3.1">
<info created="D:20260901000000" modified="D:20260901000000" tex="luatex"/>
<ipestyle name="basic">
<symbol name="arrow/arc(spx)">
<path stroke="sym-stroke" fill="sym-stroke" pen="sym-pen">
0 0 m
-1 0.333 l
-1 -0.333 l
h
</path>
</symbol>
<arrowsize name="normal" value="10"/>
<arrowsize name="large" value="14"/>
<arrowsize name="small" value="7"/>
<arrowsize name="tiny" value="5"/>
<color name="red" value="1 0 0"/>
<color name="green" value="0 1 0"/>
<color name="blue" value="0 0 1"/>
<color name="yellow" value="1 1 0"/>
<color name="orange" value="1 0.647 0"/>
<color name="gold" value="1 0.843 0"/>
<color name="purple" value="0.627 0.125 0.941"/>
<color name="gray" value="0.745"/>
<color name="white" value="1"/>
<color name="black" value="0"/>
<color name="lightgray" value="0.9"/>
<pen name="normal" value="0.6"/>
<pen name="heavier" value="1.2"/>
<pen name="fat" value="1.8"/>
<pen name="ultrafat" value="2.4"/>
<pen name="ultrathin" value="0.2"/>
<pen name="thin" value="0.4"/>
<textsize name="normal" value="10"/>
<textsize name="large" value="12"/>
<textsize name="Large" value="14"/>
<textsize name="LARGE" value="18"/>
<textsize name="huge" value="20"/>
<textsize name="small" value="8"/>
<textsize name="footnote" value="7"/>
<textsize name="tiny" value="6"/>
<opacity name="10%" value="0.1"/>
<opacity name="30%" value="0.3"/>
<opacity name="50%" value="0.5"/>
<opacity name="75%" value="0.75"/>
<layout paper="410 290" origin="0 0" frame="410 290" crop="yes"/>
</ipestyle>
<ipestyle name="color_matlab">
<color name="matlab_blue" value="0 0.447 0.714"/>
<color name="matlab_red" value="0.850 0.325 0.098"/>
<color name="matlab_orange" value="0.929 0.694 0.125"/>
<color name="matlab_purple" value="0.494 0.184 0.556"/>
<color name="matlab_green" value="0.466 0.674 0.188"/>
<color name="matlab_cyan" value="0.301 0.745 0.933"/>
<color name="matlab_brown" value="0.635 0.078 0.184"/>
</ipestyle>
<ipestyle name="font_notosans">
<preamble>
\\usepackage{{iftex}}
\\ifluatex
    \\usepackage[deluxe,expert,haranoaji]{{luatexja-preset}}
    \\usepackage{{amsmath,amssymb}}
    \\setsansfont{{Noto Sans}}[
        BoldFont=Noto Sans Bold,
        ItalicFont=Noto Sans Italic,
        BoldItalicFont=Noto Sans Bold Italic,
    ]
    \\setsansjfont{{Noto Sans CJK JP}}[
        BoldFont=Noto Sans CJK JP Bold,
    ]
    \\renewcommand{{\\familydefault}}{{\\sfdefault}}
    \\renewcommand{{\\kanjifamilydefault}}{{\\gtdefault}}
\\else\\ifpdftex
    \\usepackage{{amsmath}}
    \\usepackage{{newtxtext}}
    \\usepackage[whole]{{bxcjkjatype}}
    \\renewcommand\\familydefault{{\\sfdefault}}
\\else
\\fi\\fi
</preamble>
</ipestyle>
<page>
<layer name="background"/>
<layer name="grid_and_axes"/>
<layer name="plots"/>
<layer name="labels"/>
<layer name="annotations"/>
<view layers="background grid_and_axes plots labels annotations" active="annotations"/>

<!-- Graph objects from MATLAB -->
<group layer="plots">
{graph_objects_xml}
</group>

<!-- LaTeX Text Labels -->
<text layer="labels" pos="203 262" halign="center" valign="baseline" size="large" stroke="black">減衰振動応答 ($y(t) = e^{{-\\zeta \\omega_n t}} \\cos(\\omega_d t)$)</text>
<text layer="labels" pos="203 12" halign="center" valign="baseline" size="normal" stroke="black">時間 $t\\ [\\mathrm{{s}}]$</text>
<text layer="labels" pos="14 142" halign="center" valign="baseline" size="normal" stroke="black" matrix="0 1 -1 0 156 128">応答 $y(t)$</text>

<!-- X-axis ticks -->
<text layer="labels" pos="40 22" halign="center" valign="baseline" size="small" stroke="black">0</text>
<text layer="labels" pos="105 22" halign="center" valign="baseline" size="small" stroke="black">1</text>
<text layer="labels" pos="170 22" halign="center" valign="baseline" size="small" stroke="black">2</text>
<text layer="labels" pos="235 22" halign="center" valign="baseline" size="small" stroke="black">3</text>
<text layer="labels" pos="300 22" halign="center" valign="baseline" size="small" stroke="black">4</text>
<text layer="labels" pos="365 22" halign="center" valign="baseline" size="small" stroke="black">5</text>

<!-- Y-axis ticks -->
<text layer="labels" pos="34 30" halign="right" valign="center" size="small" stroke="black">-1</text>
<text layer="labels" pos="34 79" halign="right" valign="center" size="small" stroke="black">-0.5</text>
<text layer="labels" pos="34 128" halign="right" valign="center" size="small" stroke="black">0</text>
<text layer="labels" pos="34 177" halign="right" valign="center" size="small" stroke="black">0.5</text>
<text layer="labels" pos="34 226" halign="right" valign="center" size="small" stroke="black">1</text>

<!-- Legend LaTeX Text -->
<text layer="labels" pos="318 233" halign="left" valign="center" size="small" stroke="black">$\\zeta = 0.1$</text>
<text layer="labels" pos="318 220" halign="left" valign="center" size="small" stroke="black">$\\zeta = 0.3$</text>
<text layer="labels" pos="318 207" halign="left" valign="center" size="small" stroke="black">$\\zeta = 0.6$</text>

<!-- Annotations in Ipe -->
<text layer="annotations" pos="140 180" halign="left" valign="baseline" size="small" stroke="matlab_red">減衰比 $\\zeta$ が大きいほど速やかに減衰</text>
<path layer="annotations" stroke="matlab_red" pen="thin" arrow="normal/normal">
135 178 m
95 150 l
</path>

</page>
</ipe>
"""

with open('examples/matlab_plot_example/matlab_graph_standalone.ipe', 'w') as f:
    f.write(standalone_template)

# Read slide_suzuki_16_9.isy, color_jaxa.isy, color_matlab.isy, font_notosans.isy content
with open('styles/slide_suzuki_16_9.isy') as f:
    slide_isy = f.read()
with open('styles/color_jaxa.isy') as f:
    jaxa_isy = f.read()
with open('styles/color_matlab.isy') as f:
    matlab_isy = f.read()
with open('styles/font_notosans.isy') as f:
    notosans_isy = f.read()

slide_template = f"""<?xml version="1.0"?>
<!DOCTYPE ipe SYSTEM "ipe.dtd">
<ipe version="70218" creator="Ipe 7.3.1">
<info created="D:20260901000000" modified="D:20260901000000" tex="luatex"/>
<preamble>\\renewcommand{{\\today}}{{2026/09/01}}</preamble>
<ipestyle name="basic">
<symbol name="arrow/arc(spx)">
<path stroke="sym-stroke" fill="sym-stroke" pen="sym-pen">
0 0 m
-1 0.333 l
-1 -0.333 l
h
</path>
</symbol>
<arrowsize name="normal" value="10"/>
<arrowsize name="large" value="14"/>
<arrowsize name="small" value="7"/>
<arrowsize name="tiny" value="5"/>
<color name="red" value="1 0 0"/>
<color name="green" value="0 1 0"/>
<color name="blue" value="0 0 1"/>
<color name="yellow" value="1 1 0"/>
<color name="orange" value="1 0.647 0"/>
<color name="gold" value="1 0.843 0"/>
<color name="purple" value="0.627 0.125 0.941"/>
<color name="gray" value="0.745"/>
<color name="white" value="1"/>
<color name="black" value="0"/>
<color name="lightgray" value="0.9"/>
<pen name="normal" value="0.6"/>
<pen name="heavier" value="1.2"/>
<pen name="fat" value="1.8"/>
<pen name="ultrafat" value="2.4"/>
<pen name="ultrathin" value="0.2"/>
<pen name="thin" value="0.4"/>
<textsize name="normal" value="10"/>
<textsize name="large" value="12"/>
<textsize name="Large" value="14"/>
<textsize name="LARGE" value="18"/>
<textsize name="huge" value="20"/>
<textsize name="small" value="8"/>
<textsize name="footnote" value="7"/>
<textsize name="tiny" value="6"/>
<opacity name="10%" value="0.1"/>
<opacity name="30%" value="0.3"/>
<opacity name="50%" value="0.5"/>
<opacity name="75%" value="0.75"/>
</ipestyle>
{matlab_isy}
{jaxa_isy}
{slide_isy}
{notosans_isy}
<page>
<layer name="BACKGROUND"/>
<layer name="graph_layer"/>
<layer name="text_layer"/>
<view layers="BACKGROUND graph_layer text_layer" active="text_layer"/>

<use layer="BACKGROUND" name="Background"/>
<text layer="BACKGROUND" pos="0 232" stroke="white" size="LARGE">MATLABグラフのIpe連携テンプレート</text>

<!-- Embedded MATLAB Graph Group (Scaled & Positioned on Slide) -->
<group layer="graph_layer" matrix="0.6 0 0 0.6 0 25">
{graph_objects_xml}
<text pos="203 262" halign="center" valign="baseline" size="large" stroke="black">減衰振動応答 ($y(t)$)</text>
<text pos="203 12" halign="center" valign="baseline" size="normal" stroke="black">時間 $t\\ [\\mathrm{{s}}]$</text>
<text pos="12 142" halign="center" valign="baseline" size="normal" stroke="black" matrix="0 1 -1 0 154 130">応答 $y(t)$</text>

<text pos="40 22" halign="center" valign="baseline" size="small" stroke="black">0</text>
<text pos="105 22" halign="center" valign="baseline" size="small" stroke="black">1</text>
<text pos="170 22" halign="center" valign="baseline" size="small" stroke="black">2</text>
<text pos="235 22" halign="center" valign="baseline" size="small" stroke="black">3</text>
<text pos="300 22" halign="center" valign="baseline" size="small" stroke="black">4</text>
<text pos="365 22" halign="center" valign="baseline" size="small" stroke="black">5</text>

<text pos="34 30" halign="right" valign="center" size="small" stroke="black">-1</text>
<text pos="34 79" halign="right" valign="center" size="small" stroke="black">-0.5</text>
<text pos="34 128" halign="right" valign="center" size="small" stroke="black">0</text>
<text pos="34 177" halign="right" valign="center" size="small" stroke="black">0.5</text>
<text pos="34 226" halign="right" valign="center" size="small" stroke="black">1</text>

<text pos="318 233" halign="left" valign="center" size="small" stroke="black">$\\zeta = 0.1$</text>
<text pos="318 220" halign="left" valign="center" size="small" stroke="black">$\\zeta = 0.3$</text>
<text pos="318 207" halign="left" valign="center" size="small" stroke="black">$\\zeta = 0.6$</text>
</group>

<!-- Explanation & Annotations on Slide -->
<text layer="text_layer" pos="240 185" size="large" stroke="jaxa_blue">\\textbf{{2次遅れ系の減衰特性}}</text>

<text layer="text_layer" pos="240 155" size="normal" stroke="black">伝達関数モデル:</text>
<text layer="text_layer" pos="250 135" size="normal" stroke="black">$G(s) = \\dfrac{{\\omega_n^2}}{{s^2 + 2\\zeta\\omega_n s + \\omega_n^2}}$</text>

<text layer="text_layer" pos="240 95" size="normal" stroke="black">減衰比 $\\zeta$ の比較:</text>
<text layer="text_layer" pos="250 75" size="normal" stroke="matlab_blue">$\\bullet$ $\\zeta = 0.1$: 減衰が小さく振動的</text>
<text layer="text_layer" pos="250 55" size="normal" stroke="matlab_red">$\\bullet$ $\\zeta = 0.3$: 適度な減衰特性</text>
<text layer="text_layer" pos="250 35" size="normal" stroke="matlab_orange">$\\bullet$ $\\zeta = 0.6$: 速やかに整定</text>

<path layer="text_layer" stroke="matlab_blue" pen="thin" arrow="normal/normal">
245 78 m
120 110 l
</path>

</page>
</ipe>
"""

with open('examples/matlab_plot_example/matlab_graph_slide.ipe', 'w') as f:
    f.write(slide_template)

ET.parse('examples/matlab_plot_example/matlab_graph_standalone.ipe')
ET.parse('examples/matlab_plot_example/matlab_graph_slide.ipe')
print("XML validation passed!")
