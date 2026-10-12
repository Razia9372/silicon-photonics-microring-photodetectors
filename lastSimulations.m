%% ========================================================
%  Ring Resonator + Ge Photodetector — Intra-Cavity Config
%  Platform: SOI, lambda_0 = 1550 nm
%  Model: Transfer Matrix Method (TMM) + Enhancement Factor
%% ========================================================

clear; close all; clc;

%% --- BLOCK 1: PHYSICAL PARAMETERS ---

% Physical constants
c   = 3e8;                  % speed of light [m/s]
h   = 6.626e-34;            % Planck constant [J*s]
q   = 1.602e-19;            % electron charge [C]

% Ring resonator parameters
lambda_0 = 1550e-9;         % target wavelength [m]
n_eff    = 2.4;             % effective index TE mode in SOI at 1550 nm
n_g      = 3.8;             % group index in SOI at 1550 nm
R_ring   = 10e-6;           % ring radius [m] — base value: 10 um
L        = 2*pi*R_ring;     % ring circumference [m]

% Find resonance order and actual resonance wavelength
m          = round(n_eff * L / lambda_0);   % nearest resonance order
lambda_res = n_eff * L / m;                 % actual resonance wavelength [m]

% Internal loss per round trip (field attenuation)
alpha_loss = 3;                             % propagation loss [dB/cm]
alpha_m    = alpha_loss * 100 * log(10)/20; % field loss coefficient [1/m]
a          = exp(-alpha_m * L);             % round-trip field attenuation

% Ge detector parameters
W        = 5e-6;            % Ge absorber length along ring [m]
alpha_ge = 4600;            % Ge absorption coefficient at 1550 nm [1/m]
a_ge     = exp(-alpha_ge * W);              % field transmission through Ge
a_tot    = a * a_ge;                        % total round-trip field attenuation

% Bus-ring coupling coefficients
kappa_sq = 0.05;            % power coupling coefficient — base value (5%)
kappa    = sqrt(kappa_sq);  % field coupling coefficient
t        = sqrt(1-kappa_sq);% field transmission coefficient

% Input optical power
P_in     = 1e-3;            % [W] = 1 mW

% Base responsivity of Ge (wavelength-dependent)
EQE      = 0.8;             % external quantum efficiency
R0       = @(lam) EQE * (q*lam./(h*c)) .* (1 - exp(-alpha_ge*W));

% Diagnostic output
fprintf('--- Simulation Parameters ---\n');
fprintf('Resonance order      = %d\n', m);
fprintf('Actual resonance     = %.4f nm\n', lambda_res*1e9);
fprintf('Round-trip loss a    = %.4f\n', a_tot);
fprintf('R0 at lambda_res     = %.3f A/W\n', R0(lambda_res));

%% --- BLOCK 2: WAVELENGTH GRID ---

FSR         = lambda_res^2 / (n_g * L);     % Free Spectral Range [m]
lambda_span = 4 * FSR;
lambda      = linspace(lambda_res - lambda_span/2, ...
                       lambda_res + lambda_span/2, 10000);  % [m]

%% --- BLOCK 3: TMM — ENHANCEMENT FACTOR ---

% Round-trip phase as function of wavelength
phi = 2*pi * n_eff * L ./ lambda;          % [rad]

% Enhancement Factor — intra-cavity power / input power
EF = kappa_sq ./ abs(1 - a_tot .* t .* exp(1j*phi)).^2;

% Through port transmission
T_through = abs(t - a_tot .* exp(1j*phi)).^2 ./ ...
            abs(1 - a_tot .* t .* exp(1j*phi)).^2;

% Q factor and max enhancement
EF_max   = max(EF);
Q_approx = (pi * sqrt(a_tot*t)) / (1 - a_tot*t) * (n_g * L / lambda_res);

fprintf('FSR                  = %.3f nm\n', FSR*1e9);
fprintf('Q factor (approx)    = %.0f\n', Q_approx);
fprintf('Max Enhancement      = %.1f x\n', EF_max);

%% --- BLOCK 4: PHOTOCURRENT ---

% Effective responsivity with ring enhancement
R_eff = R0(lambda) .* EF;                  % [A/W]

% Photocurrent
I_ph  = R0(lambda) .* P_in .* EF;          % [A]

%% --- BLOCK 5: PLOTS ---

col_through = [0.2 0.4 0.8];
col_ef      = [0.9 0.5 0.1];
col_iph     = [0.1 0.6 0.3];
col_r0      = [0.6 0.1 0.6];

lam_nm = lambda * 1e9;

% --- Figure 1: Through port + Enhancement Factor ---
figure('Position', [100 100 900 400]);

subplot(1,2,1);
plot(lam_nm, T_through, 'Color', col_through, 'LineWidth', 1.5);
xlabel('Wavelength (nm)'); ylabel('Transmission');
title('Through Port (TMM)');
grid on; xlim([lam_nm(1) lam_nm(end)]);
ylim([0 1]);

subplot(1,2,2);
plot(lam_nm, EF, 'Color', col_ef, 'LineWidth', 1.5);
xlabel('Wavelength (nm)'); ylabel('Enhancement Factor');
title('Intra-Cavity Enhancement Factor EF(\lambda)');
grid on; xlim([lam_nm(1) lam_nm(end)]);
yline(EF_max, '--k', sprintf('Max = %.1fx', EF_max), ...
      'LabelHorizontalAlignment', 'left');

sgtitle('Ring Resonator — TMM Model');

% --- Figure 2: Responsivity and Photocurrent ---
figure('Position', [100 550 900 400]);

subplot(1,2,1);
plot(lam_nm, R0(lambda), 'Color', col_r0, 'LineWidth', 1.5, ...
     'DisplayName', 'R_0 (no ring)');
hold on;
plot(lam_nm, R_eff, 'Color', col_iph, 'LineWidth', 1.5, ...
     'DisplayName', 'R_{eff} (with ring)');
hold off;
xlabel('Wavelength (nm)'); ylabel('Responsivity (A/W)');
title('Responsivity: bare vs ring-enhanced');
legend('Location', 'northeast'); grid on;
xlim([lam_nm(1) lam_nm(end)]);

subplot(1,2,2);
plot(lam_nm, I_ph*1e6, 'Color', col_iph, 'LineWidth', 2);
xlabel('Wavelength (nm)'); ylabel('Photocurrent (\muA)');
title('Ge Photodetector — Photocurrent vs Wavelength');
grid on; xlim([lam_nm(1) lam_nm(end)]);

sgtitle('Intra-Cavity Ge Photodetector Response');

%% --- BLOCK 6: PARAMETRIC ANALYSIS ---

figure('Position', [1020 100 1200 900]);

% --- 6a: Coupling coefficient variation (gap effect) ---
subplot(3,1,1);
kappa_vals = [0.01, 0.05, 0.10, 0.20];
colors_p   = lines(length(kappa_vals));
hold on;
for i = 1:length(kappa_vals)
    t_i   = sqrt(1 - kappa_vals(i));
    EF_i  = kappa_vals(i) ./ abs(1 - a_tot.*t_i.*exp(1j*phi)).^2;
    Iph_i = R0(lambda) .* P_in .* EF_i;
    plot(lam_nm, Iph_i*1e6, 'Color', colors_p(i,:), 'LineWidth', 1.5, ...
         'DisplayName', sprintf('\\kappa^2 = %.0f%%', kappa_vals(i)*100));
end
hold off;
xlabel('Wavelength (nm)'); ylabel('I_{ph} (\muA)');
title('Effect of Coupling Coefficient \kappa^2 (gap variation)');
legend('Location', 'northeast'); grid on;
xlim([lam_nm(1) lam_nm(end)]);

% --- 6b: Internal loss variation ---
subplot(3,1,2);
alpha_vals = [1, 3, 5, 10];            % dB/cm
hold on;
for i = 1:length(alpha_vals)
    am_i  = alpha_vals(i) * 100 * log(10)/20;
    a_i   = exp(-am_i*L) * a_ge;
    EF_i  = kappa_sq ./ abs(1 - a_i.*t.*exp(1j*phi)).^2;
    Iph_i = R0(lambda) .* P_in .* EF_i;
    plot(lam_nm, Iph_i*1e6, 'Color', colors_p(i,:), 'LineWidth', 1.5, ...
         'DisplayName', sprintf('\\alpha = %d dB/cm', alpha_vals(i)));
end
hold off;
xlabel('Wavelength (nm)'); ylabel('I_{ph} (\muA)');
title('Effect of Internal Loss \alpha');
legend('Location', 'northeast'); grid on;
xlim([lam_nm(1) lam_nm(end)]);

% --- 6c: Ring radius variation ---
subplot(3,1,3);
R_vals = [5, 10, 20, 40] * 1e-6;       % um -> m
hold on;
for i = 1:length(R_vals)
    L_i    = 2*pi*R_vals(i);
    m_i    = round(n_eff*L_i/lambda_0);
    lr_i   = n_eff*L_i/m_i;
    FSR_i  = lr_i^2 / (n_g*L_i);
    lam_i  = linspace(lr_i - 3*FSR_i, lr_i + 3*FSR_i, 10000);
    am_i   = alpha_loss * 100 * log(10)/20;
    a_i    = exp(-am_i*L_i) * a_ge;
    phi_i  = 2*pi*n_eff*L_i./lam_i;
    EF_i   = kappa_sq ./ abs(1 - a_i.*t.*exp(1j*phi_i)).^2;
    Iph_i  = R0(lam_i) .* P_in .* EF_i;
    plot(lam_i*1e9, Iph_i*1e6, 'Color', colors_p(i,:), 'LineWidth', 1.5, ...
         'DisplayName', sprintf('R = %d \\mum', R_vals(i)*1e6));
end
hold off;
xlabel('Wavelength (nm)'); ylabel('I_{ph} (\muA)');
title('Effect of Ring Radius R (FSR variation)');
legend('Location', 'northeast'); grid on;

sgtitle('Parametric Analysis — Intra-Cavity Photocurrent Response');