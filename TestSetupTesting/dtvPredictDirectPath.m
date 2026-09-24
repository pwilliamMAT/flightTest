function P = dtvPredictDirectPath(varargin)
%DTVPREDICTDIRECTPATH Predict direct-path DTV power at the receive site.
%   Reads the local DTV transmitter table and, for every UHF channel the N320
%   can tune (>= 450 MHz), predicts the received channel power at an
%   isotropic antenna with the Longley-Rice terrain model (propagationModel,
%   txsite/rxsite, sigstrength). The table's EIRP is used as transmitter
%   power into an isotropic antenna, and the transmitter height above ground
%   is the table altitude (above mean sea level) minus the terrain elevation
%   at the site. Transmit antenna patterns (directional "DA" entries) are not
%   modelled. Channel-sharing stations (same channel, same site) are merged.
%
%   The receive antenna gain is applied separately (see localYagiGain), so the
%   same prediction can be compared with REF and SURV for any pointing.
%
% Example:
%   P = dtvPredictDirectPath();
%   disp(P(:, {'rf_channel','call_signs','site_name','bearing_deg','distance_km','P_iso_dBm'}))
%
% See also: propagationModel, sigstrength, txsite, rxsite, dtvAbsoluteLevelCheck.
p = inputParser;
addParameter(p, 'TableFile', fullfile(fileparts(mfilename('fullpath')), 'siteData', '20_DTV_direct_path_input.csv'));
addParameter(p, 'RxLatitude', 42.29917940712679);
addParameter(p, 'RxLongitude', -71.34964782414613);
addParameter(p, 'RxAntennaHeight_m', 10);
addParameter(p, 'MinFrequency_Hz', 450e6);
parse(p, varargin{:}); o = p.Results;

T = readtable(o.TableFile, 'TextType', 'string');
T = T(T.center_frequency_mhz * 1e6 >= o.MinFrequency_Hz, :);

% Merge channel-sharing entries (same channel and site): one physical emission.
[g, keyCh, keySite] = findgroups(T.rf_channel, T.site_name);
calls = splitapply(@(c) strjoin(c, ' / '), T.call_sign, g);
first = splitapply(@(i) i(1), (1:height(T)).', g);
P = T(first, :);
P.call_signs = calls;
P.rf_channel = keyCh; P.site_name = keySite;

pm = propagationModel("longley-rice");
rx = rxsite('Latitude', o.RxLatitude, 'Longitude', o.RxLongitude, 'AntennaHeight', o.RxAntennaHeight_m);
n = height(P);
[P.bearing_deg, P.distance_km, P.tx_ground_m, P.tx_agl_m, P.P_iso_dBm, P.P_fspl_iso_dBm] = deal(nan(n, 1));
for k = 1:n
    probe = txsite('Latitude', P.tx_latitude_deg(k), 'Longitude', P.tx_longitude_deg(k));
    ground = elevation(probe);
    agl = max(P.tx_altitude_m(k) - ground, 10);
    tx = txsite('Latitude', P.tx_latitude_deg(k), 'Longitude', P.tx_longitude_deg(k), ...
        'AntennaHeight', agl, 'TransmitterFrequency', P.center_frequency_mhz(k) * 1e6, ...
        'TransmitterPower', P.eirp_kw(k) * 1e3);
    P.bearing_deg(k) = angle(rx, tx);                       % degrees, counter-clockwise from east
    P.bearing_deg(k) = mod(90 - P.bearing_deg(k), 360);     % -> degrees true (clockwise from north)
    P.distance_km(k) = distance(rx, tx) / 1e3;
    P.tx_ground_m(k) = ground; P.tx_agl_m(k) = agl;
    P.P_iso_dBm(k) = sigstrength(rx, tx, pm);
    fsplDb = fspl(distance(rx, tx), physconst('LightSpeed') / (P.center_frequency_mhz(k) * 1e6));
    P.P_fspl_iso_dBm(k) = 10*log10(P.eirp_kw(k) * 1e6) - fsplDb;   % EIRP in dBm minus free-space loss
end
P = sortrows(P, 'center_frequency_mhz');
end
