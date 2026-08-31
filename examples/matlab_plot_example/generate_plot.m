% generate_plot.m
% Sample script to generate vector graphics for Ipe

t = linspace(0, 5, 500);
zeta1 = 0.1;
zeta2 = 0.3;
zeta3 = 0.6;
wn = 4;

y1 = exp(-zeta1*wn*t) .* cos(wn*sqrt(1-zeta1^2)*t);
y2 = exp(-zeta2*wn*t) .* cos(wn*sqrt(1-zeta2^2)*t);
y3 = exp(-zeta3*wn*t) .* cos(wn*sqrt(1-zeta3^2)*t);

fig = figure('Visible', 'off', 'Position', [100, 100, 560, 360]);

plot(t, y1, 'LineWidth', 1.8, 'Color', [0.00, 0.45, 0.74], 'DisplayName', '\zeta = 0.1');
hold on;
plot(t, y2, 'LineWidth', 1.8, 'Color', [0.85, 0.33, 0.10], 'DisplayName', '\zeta = 0.3');
plot(t, y3, 'LineWidth', 1.8, 'Color', [0.93, 0.69, 0.13], 'DisplayName', '\zeta = 0.6');
hold off;

grid on;
set(gca, 'FontSize', 11, 'LineWidth', 1.0, 'GridAlpha', 0.3);
xlabel('Time t [s]');
ylabel('Response y(t)');
title('Damped Oscillation Response');
legend('Location', 'northeast');

% ベクターPDFとして出力
exportgraphics(fig, 'plot_raw.pdf', 'ContentType', 'vector');
disp('Successfully exported plot_raw.pdf');
exit;
