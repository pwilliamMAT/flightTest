function geometry = helperDeriveTxRxGeometry(txLLA, rxLLA)
%HELPERDERIVETXRXGEOMETRY Shared Tx/Rx geometry in the Rx-centred ENU frame.
%
%   geometry = helperDeriveTxRxGeometry(txLLA, rxLLA)
%
%   Inputs are [lat_deg, lon_deg, alt_m_MSL] for the transmitter and
%   receiver. The returned struct contains:
%     .spheroid               WGS-84 ellipsoid in metres
%     .tx_enu_m               [txE, txN, txU] transmitter ENU location [m]
%     .baseline_3d_m          Full Tx-Rx separation including altitude [m]
%     .baseline_horizontal_m  Horizontal ENU separation [m]
%     .theta_rad              Horizontal bearing from Rx to Tx [rad]
%     .rotation_matrix        2x2 ENU rotation for horizontal ellipse plots
%     .midpoint_horizontal_m  [midE, midN] midpoint in the ENU plane [m]
%
%   The numeric truth model should use baseline_3d_m. The plotting code may
%   still use the horizontal midpoint/orientation as a small-angle ENU
%   approximation when drawing fixed-altitude ellipses.

validateattributes(txLLA, {'numeric'}, {'numel', 3, 'real', 'finite'}, ...
    mfilename, 'txLLA');
validateattributes(rxLLA, {'numeric'}, {'numel', 3, 'real', 'finite'}, ...
    mfilename, 'rxLLA');

spheroid = wgs84Ellipsoid('meter');
[txE, txN, txU] = geodetic2enu( ...
    txLLA(1), txLLA(2), txLLA(3), ...
    rxLLA(1), rxLLA(2), rxLLA(3), spheroid);

theta = atan2(txN, txE);

geometry = struct( ...
    'spheroid', spheroid, ...
    'tx_enu_m', [txE, txN, txU], ...
    'baseline_3d_m', norm([txE, txN, txU]), ...
    'baseline_horizontal_m', hypot(txE, txN), ...
    'theta_rad', theta, ...
    'rotation_matrix', [cos(theta), -sin(theta); sin(theta), cos(theta)], ...
    'midpoint_horizontal_m', [txE / 2, txN / 2]);

end
