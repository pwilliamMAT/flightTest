function B = runBoundaryLoopTests(varargin)
%RUNBOUNDARYLOOPTESTS Single-carrier loop tests at DTV channel boundaries.
%   For each boundary frequency, places one Pluto CW carrier TargetOffset_Hz
%   above the boundary (in the gap between the lower channel's roll-off and
%   the upper channel's pilot at +309 kHz), records it on both N320 channels
%   with plutoCwLoopTest, and scores it with plutoCwLoopAnalyze.
%
%   The N320 is tuned N320BelowBoundary_Hz below the boundary so the carrier
%   is well away from DC. The Pluto LO sits PlutoToneOffset_Hz below the
%   carrier. The nominal carrier is pre-corrected by PlutoPpm (measured
%   crystal offset) so the actual carrier lands on the target.
%
%   Stops at the first capture failure: after a mid-capture failure the N320
%   may need a reboot before it streams again.
%
% The default boundaries are the gaps between adjacent on-air channels. Other
% boundaries on the 6 MHz raster also work. Avoid 470 and 482 MHz (channels 14
% and 16 carry land-mobile radio in the Boston area) and 608 MHz (channel 37 is
% reserved for radio astronomy).
%
% Example:
%   B = runBoundaryLoopTests('Boundaries_Hz', [506 512 518 524 584 590 596 602]*1e6);
%   B = runBoundaryLoopTests('Boundaries_Hz', [476 488 494 500 530:6:578]*1e6);
%
% See also: plutoCwLoopTest, plutoCwLoopAnalyze, SiteGeometry.md.
p = inputParser;
addParameter(p, 'Boundaries_Hz', [506 512 518 524 584 590 596 602] * 1e6);
addParameter(p, 'TargetOffset_Hz', 50e3);
addParameter(p, 'N320BelowBoundary_Hz', 1e6);
addParameter(p, 'PlutoToneOffset_Hz', 500e3);
addParameter(p, 'PlutoFs_Hz', 2e6);
addParameter(p, 'PlutoPpm', -17.4);
addParameter(p, 'PlutoTxGain_dB', 0);
addParameter(p, 'Amplitude', 0.78);
addParameter(p, 'Gain', [10 0]);                   % N320 RadioGain [SURV REF]; see the overload note in SiteGeometry.md
addParameter(p, 'OutputRoot', fullfile(fileparts(fileparts(mfilename('fullpath'))), 'captures', 'plutoCwLoopTests'));
addParameter(p, 'SessionID', string(datetime('now', 'Format', 'yyyyMMdd''T''HHmmss')));
parse(p, varargin{:}); o = p.Results;

outDir = fullfile(o.OutputRoot, o.SessionID);
if ~isfolder(outDir), mkdir(outDir); end
B = struct('boundary_hz', {}, 'target_hz', {}, 'status', {}, 'S', {}, 'file', {});
for k = 1:numel(o.Boundaries_Hz)
    bnd = o.Boundaries_Hz(k);
    target = bnd + o.TargetOffset_Hz;
    nominal = round(target / (1 + o.PlutoPpm * 1e-6));        % pre-correct the crystal offset
    fprintf('\n=== %s boundary %.3f MHz: target %.4f MHz (Pluto nominal %.4f)\n', ...
        string(datetime('now', 'Format', 'HH:mm:ss')), bnd/1e6, target/1e6, nominal/1e6);
    H = plutoCwLoopTest('N320Center_Hz', bnd - o.N320BelowBoundary_Hz, ...
        'PlutoLO_Hz', nominal - o.PlutoToneOffset_Hz, 'ToneOffset_Hz', o.PlutoToneOffset_Hz, ...
        'PlutoFs_Hz', o.PlutoFs_Hz, 'PlutoTxGain_dB', o.PlutoTxGain_dB, 'Amplitude', o.Amplitude, 'Gain', o.Gain);
    file = fullfile(outDir, sprintf('cwloop_%07.3fMHz.mat', bnd/1e6));
    save(file, 'H', '-v7.3');
    B(k).boundary_hz = bnd; B(k).target_hz = target; B(k).status = H.status; B(k).file = file;
    if H.status ~= "captured"
        fprintf('Capture failed at %.3f MHz (%s). Stopping; check the link and reboot the N320 before continuing.\n', bnd/1e6, H.error);
        B(k).S = [];
        break
    end
    S = plutoCwLoopAnalyze(H); B(k).S = S;
    fprintf('    carrier %.4f MHz | REF %+.1f dB (%.1f dBFS, C %.1f dB) | SURV %+.1f dB, R %.2f vs %.2f off -> %s\n', ...
        S.carrier_rf_hz/1e6, S.onoff_dB(2), S.tone_dBFS(2), S.coupling_dB(2), S.onoff_dB(1), ...
        S.weak_phase_R_on, S.weak_phase_R_off, string(S.weak_detected));
end
save(fullfile(outDir, 'boundary_summary.mat'), 'B', 'o');
end
