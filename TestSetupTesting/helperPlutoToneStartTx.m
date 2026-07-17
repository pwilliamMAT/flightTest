function tx_context = helperPlutoToneStartTx(varargin)
%HELPERPLUTOTONESTARTTX Start repeat Pluto transmission of the precheck waveform.
%
% Plain-language goal:
%   This helper isolates the Pluto support-package dependency and turns the
%   live-transmit setup into one small, catchable step for the wrapper.

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'CenterFrequencyHz', NaN, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'SampleRateHz', NaN, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'Waveform', [], @(x) isnumeric(x) && isvector(x) && ~isempty(x));
addParameter(p, 'Verbose', false, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});
opts = p.Results;

if exist('sdrtx', 'file') ~= 2 && exist('sdrtx', 'builtin') ~= 5
    error('helperPlutoToneStartTx:missingDependency', ...
        ['sdrtx("Pluto") is unavailable in this MATLAB environment. ' ...
         'Install the Communications Toolbox Support Package for Analog ' ...
         'Devices ADALM-PLUTO Radio before running the live precheck.']);
end

try
    tx_factory = str2func('sdrtx');
    tx = tx_factory("Pluto");
catch me_connect
    error('helperPlutoToneStartTx:connectFailed', ...
        'Could not create the Pluto transmitter object: %s', me_connect.message);
end

try
    if isprop(tx, 'CenterFrequency')
        tx.CenterFrequency = double(opts.CenterFrequencyHz);
    end
    if isprop(tx, 'BasebandSampleRate')
        tx.BasebandSampleRate = double(opts.SampleRateHz);
    end

    transmit_repeat = str2func('transmitRepeat');
    transmit_repeat(tx, single(opts.Waveform(:)));
catch me_transmit
    try
        release(tx);
    catch
    end
    error('helperPlutoToneStartTx:transmitFailed', ...
        'Could not start Pluto tone transmission: %s', me_transmit.message);
end

tx_context = struct( ...
    'transmitter', tx, ...
    'center_frequency_hz', double(opts.CenterFrequencyHz), ...
    'sample_rate_hz', double(opts.SampleRateHz), ...
    'waveform_samples', double(numel(opts.Waveform)));

if opts.Verbose
    fprintf('[helperPlutoToneStartTx] Pluto TX started at %.6f MHz.\n', ...
        double(opts.CenterFrequencyHz) / 1e6);
end
end
