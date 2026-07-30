classdef SignalProcessingConfig
    % SignalProcessingConfig  Configuration for passive radar SNR measurement.
    %   Encapsulates test parameters for helperMeasureSNR. All properties
    %   have sensible defaults matching the baseline test configuration.
    %
    %   cfg = SignalProcessingConfig(fs) creates a config with the given
    %   sample rate and default values for all other parameters.
    %
    %   cfg = SignalProcessingConfig(fs, Name=Value) overrides defaults
    %   with the specified name-value pairs.

    properties
        % Attenuation levels to test (dB below surveillance power)
        Attenuation (1,:) double = 0:10:50

        % Sample rate (Hz)
        Fs (1,1) double

        % Carrier frequency (Hz)
        Fc (1,1) double = 500e6

        % Minimum target range (m)
        MinRange (1,1) double = 0

        % Maximum target range (m)
        MaxRange (1,1) double = 50e3

        % Minimum target speed (m/s)
        MinSpeed (1,1) double = 20

        % Maximum target speed (m/s)
        MaxSpeed (1,1) double = 200

        % Number of CFAR guard cells
        NGuard (1,1) double = 4

        % Number of CFAR training cells
        NTrain (1,1) double = 5

        % Number of Monte Carlo runs per attenuation level
        NRuns (1,1) double = 10

        % Random number generator seed
        RngSeed (1,1) double = 2
    end

    methods
        function obj = SignalProcessingConfig(fs, nvPairs)
            % SignalProcessingConfig  Construct config with required Fs.
            %   cfg = SignalProcessingConfig(fs)
            %   cfg = SignalProcessingConfig(fs, Name=Value)
            arguments
                fs (1,1) double
                nvPairs.Attenuation (1,:) double
                nvPairs.Fc (1,1) double
                nvPairs.MinRange (1,1) double
                nvPairs.MaxRange (1,1) double
                nvPairs.MinSpeed (1,1) double
                nvPairs.MaxSpeed (1,1) double
                nvPairs.NGuard (1,1) double
                nvPairs.NTrain (1,1) double
                nvPairs.NRuns (1,1) double
                nvPairs.RngSeed (1,1) double
            end
            obj.Fs = fs;
            fields = fieldnames(nvPairs);
            for i = 1:numel(fields)
                obj.(fields{i}) = nvPairs.(fields{i});
            end
        end
    end
end
