function log_iq_n320(varargin)
% Headless IQ logger using a saved Wireless Testbench radio setup.
% R2025b, N320/N321 compatible.
%
% Example run (no GUI):
% matlab -batch "log_iq_n320('radio','My USRP N320','cf',540e6,'sr',6.144e6,'lo',200e3,'gain',30,'dur',10,'file','n320_540_5Msps_10s_headless.bb')"
fprintf('Starting Capture Setup...\n')
% -------- simple name-value parsing (no InputParser to avoid conflicts) ----
args = struct('radio',"", 'cf',540e6, 'sr',5e6, 'lo',0, 'gain',30, ...
              'dur',120, 'ant',"RX1", 'file',"");
for k = 1:2:numel(varargin)
    key = varargin{k};
    val = varargin{k+1};
    if isfield(args,key)
        args.(key) = val;
    else
        error("Unknown argument '%s'.", key);
    end
end
if args.radio == ""    % choose first saved config if not provided
    cfgs = radioConfigurations; % from Wireless Testbench
    assert(~isempty(cfgs),"No saved radio configurations found. Use Radio Setup wizard.");
    args.radio = string(cfgs(1).Name);
end
if args.file == ""
    args.file = sprintf("wt_%s_%.0fMHz_%.0fksps_%s.bb", ...
        args.radio, args.cf/1e6, args.sr/1e3, datestr(now,'yyyymmdd_HHMM'));
end
 
% -------- create WT basebandReceiver from the saved setup -------------------
% This uses the Wireless Testbench API exactly like the documentation example.
% No GUI interaction required.
bbrx = basebandReceiver(args.radio);                          % WT object
bbrx.CenterFrequency = args.cf;
bbrx.SampleRate      = args.sr;
bbrx.RadioGain       = args.gain;
 
% Antenna selection (list programmatically; pick by name or first available)
antList = hCaptureAntennas(args.radio);                       % WT helper
if isempty(antList)
    warning("No antennas reported by WT helper; using default.");
else
    % If user passed "RX1", try to match it; otherwise use the first.
    matchIdx = find(strcmpi(antList, args.ant), 1);
    if isempty(matchIdx), matchIdx = 1; end
    bbrx.Antennas = antList(matchIdx);
end
 
% Optional LO offset: WT handles RF+DSP tuning under the hood, like UHD notes.
% We can apply an offset by adjusting CenterFrequency and then retuning digitally.
% A simple way is to shift CF by args.lo and later compensate numerically if needed.
% For most capture use-cases, set a small offset (e.g., +200 kHz) to move DC away.
if args.lo ~= 0
    bbrx.CenterFrequency = args.cf + args.lo;
end
 
% -------- estimate file size (complex int16 I/Q → 4 bytes/sample) ----------
bytesPerSample = 4;
estBytes = bbrx.SampleRate * args.dur * bytesPerSample;
fprintf('Planned: %.2f s @ %.3f MSps → ~%.2f GB to %s\n', ...
    args.dur, bbrx.SampleRate/1e6, estBytes/(1024^3), args.file);
 
% -------- baseband file writer with metadata -------------------------------
meta = struct('Label','WT_Yagi_540MHz_logging', ...
              'RadioName',args.radio, 'Antenna',char(bbrx.Antennas), ...
              'RadioGain',bbrx.RadioGain, 'LOOffset',args.lo, ...
              'MATLABRelease',version('-release'));
bbw = comm.BasebandFileWriter(args.file, ...
        'SampleRate',      bbrx.SampleRate, ...
        'CenterFrequency', args.cf, ...
        'Metadata',        meta);
 
% -------- streaming capture loop (frame-by-frame) --------------------------
% WT provides a blocking capture() for fixed durations. For headless logging
% and disk streaming, we will loop capture in shorter segments to avoid memory spikes.
seg = seconds(1);                                      % 1-second chunks
nSeg = ceil(args.dur / seconds(seg));
for i = 1:nSeg
    % capture returns a complex frame sampled at bbrx.SampleRate
    if i == 1
        fprintf('Collection Started')
    end
    data = capture(bbrx, seg);                         % WT capture
    % If we shifted CF by args.lo earlier, you may optionally re-center the data
    % digitally here (frequency shift by -args.lo) before writing.
    % For now, write raw captured data:
    bbw(data);
end
 
% -------- clean up ---------------------------------------------------------
release(bbw);
fprintf('Done: %s\n', args.file);