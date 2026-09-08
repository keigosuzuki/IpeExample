import os
import re

def clean_ipe_paths(ipe_xml_str):
    paths = re.findall(r'<path[^>]*>[\s\S]*?</path>', ipe_xml_str)
    filtered = []
    for p in paths:
        # Filter full-page background rectangle if any
        if 'fill="1.000000 1.000000 1.000000"' in p and ('359' in p or '483' in p or '217' in p):
            continue
        p_mod = p
        # Map RGB colors to symbolic color names
        p_mod = re.sub(r'stroke="0\.000000 0\.44[67]\d* 0\.74\d*" pen="[^"]*"', 'stroke="matlab_blue" pen="heavier"', p_mod)
        p_mod = re.sub(r'stroke="0\.000000 0\.44[67]\d* 0\.74\d*"', 'stroke="matlab_blue" pen="heavier"', p_mod)
        p_mod = re.sub(r'stroke="0\.85\d* 0\.32\d* 0\.09[89]\d*" pen="[^"]*"', 'stroke="matlab_red" pen="heavier"', p_mod)
        p_mod = re.sub(r'stroke="0\.85\d* 0\.32\d* 0\.09[89]\d*"', 'stroke="matlab_red" pen="heavier"', p_mod)
        p_mod = re.sub(r'stroke="0\.92\d* 0\.69\d* 0\.12\d*" pen="[^"]*"', 'stroke="matlab_orange" pen="heavier"', p_mod)
        p_mod = re.sub(r'stroke="0\.92\d* 0\.69\d* 0\.12\d*"', 'stroke="matlab_orange" pen="heavier"', p_mod)
        p_mod = re.sub(r'stroke="0\.49\d* 0\.18\d* 0\.55\d*" pen="[^"]*"', 'stroke="matlab_purple" pen="heavier"', p_mod)
        p_mod = re.sub(r'stroke="0\.49\d* 0\.18\d* 0\.55\d*"', 'stroke="matlab_purple" pen="heavier"', p_mod)
        # Grid lines to subtle gray
        p_mod = re.sub(r'fill="0\.129410 0\.129410 0\.129410"', 'fill="0.88 0.88 0.88"', p_mod)
        # Box borders
        p_mod = re.sub(r'stroke="0\.129410 0\.129410 0\.129410" pen="[^"]*"', 'stroke="black" pen="normal"', p_mod)
        p_mod = re.sub(r'stroke="0\.129410 0\.129410 0\.129410"', 'stroke="black"', p_mod)
        filtered.append(p_mod)
    return "\n".join(filtered)

# Read raw converted ipe files
with open('plot_slide_single.ipe', 'r') as f:
    single_raw = f.read()

single_paths = clean_ipe_paths(single_raw)

# Read style sheets
def read_style(name):
    with open(f'../../styles/{name}.isy', 'r') as f:
        content = f.read()
    # Strip <?xml ...> and <!DOCTYPE ...>
    content = re.sub(r'<\?xml[^>]*\?>', '', content)
    content = re.sub(r'<!DOCTYPE[^>]*>', '', content)
    return content.strip()

basic_style = read_style('basic')
color_matlab_style = read_style('color_matlab')
color_cud_style = read_style('color_cud')
font_notosans_style = read_style('font_notosans')
slide_4_3_style = read_style('slide_suzuki_4_3')

# Create Slide Example IPE
slide_ipe = f"""<?xml version="1.0"?>
<!DOCTYPE ipe SYSTEM "ipe.dtd">
<ipe version="70218" creator="Ipe 7.3.1">
<info created="D:20260908160000" modified="D:20260908160000" tex="luatex"/>
{slide_4_3_style}
{basic_style}
{font_notosans_style}
{color_cud_style}
{color_matlab_style}
<page title="Damped Oscillation Step Response">
<layer name="alpha"/>
<layer name="graph"/>
<view layers="alpha graph" active="graph"/>
<text layer="alpha" pos="30 290" stroke="black" type="minipage" width="340" height="20" size="small" valign="top">
\\begin{{itemize}}
\\item MATLAB \\texttt{{setup\\_ipe\\_plot(fig, 'slide\\_single')}} による一発整形
\\item \\textbf{{True-Size LaTeX Fonts}} (10pt normal) \\&amp; \\textbf{{MATLAB Symbolic Colors}}
\\end{{itemize}}
</text>
<group layer="graph" matrix="1 0 0 1 20 -20">
{single_paths}
<text stroke="black" pos="180 25" transformations="translations" size="small" halign="center" valign="baseline">Time $t$ [s]</text>
<text stroke="black" pos="25 150" matrix="0 1 -1 0 25 150" transformations="rigid" size="small" halign="center" valign="baseline">Response $y(t)$</text>
<text stroke="black" pos="180 265" transformations="translations" size="normal" halign="center" valign="baseline">\\textbf{{Step Response ($w_n = 4\\,\\mathrm{{rad/s}}$)}}</text>
<text stroke="black" pos="285 242" transformations="translations" size="script" valign="baseline">$\\zeta = 0.1$</text>
<text stroke="black" pos="285 228" transformations="translations" size="script" valign="baseline">$\\zeta = 0.3$</text>
<text stroke="black" pos="285 214" transformations="translations" size="script" valign="baseline">$\\zeta = 0.6$</text>
</group>
</page>
</ipe>
"""

with open('matlab_graph_slide.ipe', 'w') as f:
    f.write(slide_ipe)

print("Generated matlab_graph_slide.ipe")
