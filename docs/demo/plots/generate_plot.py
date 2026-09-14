#!/usr/bin/env python3
"""
generate_plot.py
Python (matplotlib) を使用した Ipe 連携用プロット出力スクリプト

ベストプラクティス:
- pdf.fonttype = 42 (TrueType) により、テキストをパス化せず文字として PDF に出力
- mm 単位での明示的な Figure サイズ指定
- 適切なフォントサイズ設定
"""

import numpy as np
import matplotlib.pyplot as plt

# --- Ipe 向け ベストプラクティス設定 ---
plt.rcParams['pdf.fonttype'] = 42   # TrueType フォントを埋め込み (文字として保持)
plt.rcParams['ps.fonttype'] = 42
plt.rcParams['axes.unicode_minus'] = False  # ASCIIハイフンを使用して文字化け防止
plt.rcParams['font.sans-serif'] = ['DejaVu Sans', 'Arial']
plt.rcParams['font.family'] = 'sans-serif'
plt.rcParams['mathtext.fontset'] = 'dejavusans'  # Unicode準拠の数式フォント (文字化け防止)

MM_TO_INCH = 1.0 / 25.4

# 共通データ生成
t = np.linspace(0, 5, 500)
wn = 4.0
zeta_list = [0.1, 0.3, 0.6]

# =====================================================================
# 1. スライド用 単一プロット (140 mm x 105 mm)
# =====================================================================
fig1, ax1 = plt.subplots(figsize=(140 * MM_TO_INCH, 105 * MM_TO_INCH))

for z in zeta_list:
    y = np.exp(-z * wn * t) * np.cos(wn * np.sqrt(1 - z**2) * t)
    ax1.plot(t, y, label=f'$\\zeta = {z:.1f}$')

ax1.set_xlabel('Time $t$ [s]', fontsize=13)
ax1.set_ylabel('Response $y(t)$', fontsize=13)
ax1.set_title('Step Response ($\\omega_n = 4\\,\\mathrm{rad/s}$)', fontsize=14)
ax1.legend(loc='upper right', fontsize=11)
ax1.grid(True, linestyle=':', alpha=0.6)
ax1.tick_params(labelsize=11)

fig1.tight_layout()
fig1.savefig('python_plot_single.pdf', bbox_inches='tight')
plt.close(fig1)

# =====================================================================
# 2. スライド用 複合マルチプロット 2x2 (200 mm x 125 mm)
# =====================================================================
fig2, axs = plt.subplots(2, 2, figsize=(200 * MM_TO_INCH, 125 * MM_TO_INCH))

zeta = 0.2
y_val = np.exp(-zeta * wn * t) * np.cos(wn * np.sqrt(1 - zeta**2) * t)
ydot_val = -wn * np.exp(-zeta * wn * t) * np.sin(wn * np.sqrt(1 - zeta**2) * t)

# (1) 変位
axs[0, 0].plot(t, y_val, color='#1f77b4')
axs[0, 0].set_xlabel('Time $t$ [s]', fontsize=10)
axs[0, 0].set_ylabel('Displacement $y(t)$', fontsize=10)
axs[0, 0].grid(True, linestyle=':', alpha=0.6)
axs[0, 0].tick_params(labelsize=9)

# (2) 速度
axs[0, 1].plot(t, ydot_val, color='#ff7f0e')
axs[0, 1].set_xlabel('Time $t$ [s]', fontsize=10)
axs[0, 1].set_ylabel('Velocity $\\dot{y}(t)$', fontsize=10)
axs[0, 1].grid(True, linestyle=':', alpha=0.6)
axs[0, 1].tick_params(labelsize=9)

# (3) 位相平面
axs[1, 0].plot(y_val, ydot_val, color='#2ca02c')
axs[1, 0].set_xlabel('Displacement $y(t)$', fontsize=10)
axs[1, 0].set_ylabel('Velocity $\\dot{y}(t)$', fontsize=10)
axs[1, 0].grid(True, linestyle=':', alpha=0.6)
axs[1, 0].tick_params(labelsize=9)

# (4) 周波数応答
f_axis = np.linspace(0.01, 20, 200)
w = 2 * np.pi * f_axis
mag = 1.0 / np.sqrt((1 - (f_axis / 4)**2)**2 + (2 * zeta * f_axis / 4)**2)
axs[1, 1].semilogy(f_axis, mag, color='#d62728')
axs[1, 1].set_xlabel('Frequency $f$ [Hz]', fontsize=10)
axs[1, 1].set_ylabel('Magnitude $|G(j\\omega)|$', fontsize=10)
axs[1, 1].grid(True, linestyle=':', alpha=0.6)
axs[1, 1].tick_params(labelsize=9)

fig2.tight_layout()
fig2.savefig('python_plot_multi.pdf', bbox_inches='tight')
plt.close(fig2)

print('=== Successfully generated python_plot_single.pdf and python_plot_multi.pdf ===')
