% generate_plot_examples.m
% MATLABExample/PlotTools を使用した Ipe 用プロット出力サンプル

% MATLABExample/PlotTools へのパスを追加
this_dir = fileparts(mfilename('fullpath'));
repo_root = fullfile(this_dir, '..', '..', '..');
addpath(fullfile(repo_root, 'MATLABExample', 'PlotTools'));

t = linspace(0, 5, 500);
zeta_list = [0.1, 0.3, 0.6];
wn = 4;

%% 1. スライド用 単一プロット (slide_single)
fig1 = figure('Visible', 'off');
hold on;
for i = 1:numel(zeta_list)
    z = zeta_list(i);
    y = exp(-z*wn*t) .* cos(wn*sqrt(1-z^2)*t);
    plot(t, y, 'DisplayName', sprintf('$\\zeta = %.1f$', z));
end
hold off;

xlabel('Time $t$ [s]');
ylabel('Response $y(t)$');
title('Step Response ($w_n = 4\,\mathrm{rad/s}$)');
legend('Location', 'northeast');

setup_ipe_plot(fig1, 'slide_single');
export_ipe_plot(fig1, 'plot_slide_single.pdf', 'Batch', true);

%% 2. スライド用 複合マルチプロット (slide_multi: 2x2)
fig2 = figure('Visible', 'off');

% Subplot 1: Response
subplot(2, 2, 1);
plot(t, exp(-0.2*wn*t) .* cos(wn*sqrt(1-0.2^2)*t));
xlabel('Time $t$ [s]'); ylabel('$y(t)$');
title('Displacement');

% Subplot 2: Velocity
subplot(2, 2, 2);
plot(t, -wn*exp(-0.2*wn*t) .* sin(wn*sqrt(1-0.2^2)*t));
xlabel('Time $t$ [s]'); ylabel('$\dot{y}(t)$');
title('Velocity');

% Subplot 3: Phase Portrait
subplot(2, 2, 3);
y_val = exp(-0.2*wn*t) .* cos(wn*sqrt(1-0.2^2)*t);
ydot_val = -wn*exp(-0.2*wn*t) .* sin(wn*sqrt(1-0.2^2)*t);
plot(y_val, ydot_val);
xlabel('$y(t)$'); ylabel('$\dot{y}(t)$');
title('Phase Portrait');

% Subplot 4: Frequency Spectrum
subplot(2, 2, 4);
f_axis = linspace(0, 20, 200);
mag = 1 ./ sqrt((1 - (f_axis/4).^2).^2 + (2*0.2*f_axis/4).^2);
semilogy(f_axis, mag);
xlabel('Frequency $f$ [Hz]'); ylabel('Magnitude $|G(j\omega)|$');
title('Frequency Response');

setup_ipe_plot(fig2, 'slide_multi');
export_ipe_plot(fig2, 'plot_slide_multi.pdf', 'Batch', true);

%% 3. 学会論文用 1段組みプロット (paper_column)
fig3 = figure('Visible', 'off');
hold on;
for i = 1:numel(zeta_list)
    z = zeta_list(i);
    y = exp(-z*wn*t) .* cos(wn*sqrt(1-z^2)*t);
    plot(t, y, 'DisplayName', sprintf('$\\zeta = %.1f$', z));
end
hold off;
xlabel('Time $t$ [s]');
ylabel('Response $y(t)$');
legend('Location', 'northeast');

setup_ipe_plot(fig3, 'paper_column');
export_ipe_plot(fig3, 'plot_paper_column.pdf', 'Batch', true);

fprintf('=== All example plots successfully generated! ===\n');
exit;
