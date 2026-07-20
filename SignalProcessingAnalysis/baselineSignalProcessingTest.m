% This analysis injects low power targets into real collected HDTV data by
% attenuating, delaying, and doppler shifting the reference channel and
% adding it to the surveillance channel. Attenuation is done using the
% signal power in the surveillance channel as a reference.
% 
% We can roughly assume that the surveillance channel signal power is the
% direct path power and inject attenuated targets to measure our signal
% processing pipeline's ability to detect targets at different power levels
% using the direct path power as a reference.
%
% So if we estimate that targets at the max range of interest would be 50
% dB lower than the direct path, we can inject signals 50 dB lower than the
% surveillance channel signal power and see how good we are at detecting
% those targets.
% 
% We can perform range-Doppler processing and measure the SNR of the
% processed data. If the desired output is 90% Pd and 1e-6 FAR, the
% required SNR is ~13 dB:

pd = 0.9;
far = 1e-6;
requiredSnr = shnidman(pd,far);
disp(['Required SNR: ',num2str(requiredSnr)])

% So we need a signal processing approach that will give us 13 dB SNR at
% the required attenuation level.
%
% This approach may give us over-confidence because we are assuming the
% reference channel is a perfect estimate of the true direct path signal, I
% don't know how much extra SNR that gives us over reality.

%% Load real data

% Load the real data file
fname = 'n320_hdtv_capture_20260708T135521_part1';
reader   = comm.BasebandFileReader(fname,'SamplesPerFrame',inf);
raw_data = reader();
fs = reader.SampleRate;
surv  = double(raw_data(:, 1));
ref  = double(raw_data(:, 2));

%% Baseline test

% Use Wiener filter with 1000 taps and perform RD processing on data
% arranged into a cube.
wTaps = 1000;
fc = 500e6;
maxUnambigSpeed = 200;
filterFcn = @(tsurv,tref)helperWienerHopfFilter(tsurv,tref,wTaps);
rdFcn = @(tsurv,tref)helperRangeDopplerCube(tsurv,tref,fs,fc,maxUnambigSpeed);
testFcn = @(tsurv,tref)baselineProcessing(tsurv,tref,filterFcn,rdFcn);

% Measure the SNR of the test function with targets injected at the given
% attenuation level from the signal level.
testAtten = 0:10:50;
minRange = 0;
maxRange = 50e3;
minSpeed = 20;
maxSpeed = 200;
nGuard = 4;
nTrain = 5;
nRuns = 10;
rNum = 2;
measuredSnr = helperMeasureSNR(surv,ref,testAtten,fs,fc,minRange,maxRange,minSpeed,maxSpeed,nGuard,nTrain,nRuns,rNum,testFcn);
helperPlotSnr(testAtten,measuredSnr,requiredSnr,'Baseline Signal Processing');

%% Other tests to perform
% 
% There are many modifications to our signal processing algorithm that we
% could test to see if SNR improves. Here is a subset of tests we should
% run:
%
% It would be interesting to run the baseline test with and without
% amplifier on reference channel, this should confirm amplifier improves
% SNR. It is possible that without an amplifier also on the surveillance
% channel that the impact will be limited, the surveillance channel noise
% could be limiting our SNR right now.
%
% We should test the effect of increasing the number of Wiener
% coefficients, baseline above uses 1000, we should test increasing at some
% fixed signal power level and see the SNR trend.
%
% Test the other two DSI suppression algorithms from
% https://www.mathworks.com/help/phased/ug/direct-signal-interference-dsi-suppression-in-passive-radar.html.
% Particularly the BLMS algorithm appears to work very well from this
% article. We should test the signal processing algorithms as we vary their
% parameters.
%
% Cube vs. Doppler filters. Right now we arbitrarily rearrange the signal
% into a cube and perform RD processing similar to pulsed radar, but using
% banks of doppler shifted reference signal may yield better results, at
% the expense of computational burde. See helperDopplerFilterBank, we could
% replace helperRangeDopplerCube in our processing algorithm.

function [rd,range,doppler] = baselineProcessing(surv,ref,filterFcn,rdFcn)
    % Baseline processing applies a DSI suppression function and then does
    % range-Doppler processing on the filtered output.
    
    % DSI suppression
    survFiltered = filterFcn(surv,ref);

    % Range-Doppler processing
    [rd,range,doppler] = rdFcn(survFiltered,ref);
end

function [survest,h] = helperWienerHopfFilter(surv,ref,M)
    % Get filter taps
    h = helperWienerHopfTaps(surv,ref,M);
    
    % Remove the filtered reference from surveillance
    survest = helperFilterSurv(surv,ref,h);
end

function survest = helperFilterSurv(surv,ref,h)
    % Remove the filtered reference from surveillance
    survest = surv - filter(h,1,ref);
end

function h = helperWienerHopfTaps(surv,ref,M)
    % Compute autocorrelation and cross-correlation with conjugates
    rxx = xcorr(ref, M-1, 'biased');
    rsx = xcorr(surv, ref, M-1, 'biased');
    
    % Extract centered values (zero lag at index M)
    Rxx = toeplitz(rxx(M:end));
    rsx_vec = conj(rsx(M:end));
    
    % Solve Wiener-Hopf equation
    h = conj(Rxx \ rsx_vec);
end

function [rd,range,speed] = helperDopplerFilterBank(surv,ref,fs,fc,nLags,maxSpeed,nDop)
    % Use a Doppler filter bank to do matched filtering

    % Measure number of samples
    nSamples = length(ref);

    % Calculate range
    range = (-nLags:nLags)/fs*physconst("LightSpeed");

    % Measure time
    t = ((1:nSamples)/fs)';

    % Get doppler frequencies
    speed = linspace(-maxSpeed,maxSpeed,nDop);
    fDoppler = speed2dop(speed,freq2wavelen(fc));
    
    % Initialize range-Doppler
    rd = zeros(2*nLags+1,nDop);
    
    for iSpeed = 1:nDop
        fShift = fDoppler(iSpeed);
        fSig = exp(1i*2*pi*fShift*t);
        refShift = ref.*fSig;
        rd(:,iSpeed) = xcorr(surv,refShift,nLags);
    end
end

function [resp,range,speed] = helperRangeDopplerCube(surv,ref,fs,fc,maxSpeed)
    % Get the matrix dimensions based on the desired max unambiguous speed
    prf = speed2dop(maxSpeed,freq2wavelen(fc))*2;
    pri = 1/prf;
    nSamplePerPulse = round(pri*fs);

    % Rearrange data into columns
    ns = length(surv);
    nCol = floor(ns/nSamplePerPulse);
    if mod(nCol,2) == 0
        % use odd column number
        nCol = nCol - 1;
    end
    ns = nCol*nSamplePerPulse;
    surv = surv(1:ns);
    ref = ref(1:ns);
    survMat = reshape(surv,[nSamplePerPulse nCol]);
    refMat = reshape(ref,[nSamplePerPulse nCol]);
    
    % Get the Doppler freq shifts and speeds
    prf = 1/(nSamplePerPulse/fs);
    dopFreqs = -prf/2:prf/(nCol-1):prf/2;
    speed = dop2speed(dopFreqs,freq2wavelen(fc));
    
    % Get the bistatic ranges
    rangeRes = physconst('LightSpeed')/fs;
    range = ((-nSamplePerPulse+1):(nSamplePerPulse-1))*rangeRes;
    
    % Cross correlate each surveillance with reference
    resp = zeros(length(range),nCol);
    for iCol = 1:nCol
        resp(:,iCol) = xcorr(survMat(:,iCol),refMat(:,iCol));
    end
    
    % FFT slow time for Doppler shift
    resp = abs(fftshift(fft(resp,[],2),2));
end

function helperPlotSnr(testAtten,measuredSnr,requiredSNR,tstr)
    % Plot the results of the SNR test.
    ax = axes(figure);
    hold(ax,"on");
    plot(ax,testAtten,measuredSnr,DisplayName='Measured SNR');
    yline(ax,requiredSNR,DisplayName='Required SNR for desired Pd',LineStyle='--');
    title(ax,tstr);
    xlabel(ax,'Target Attenuation (dB Down From Mean Surveillance Power)');
    ylabel(ax,'Measured SNR (dB)');
    legend(ax);
end