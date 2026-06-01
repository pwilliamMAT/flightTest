function track_histories = helperTracksLogToHistories(tracks_log, fc)
%HELPERTRACKSLOGTOHISTORIES  Convert per-step tracker snapshots to histories.
%
%  track_histories = helperTracksLogToHistories(tracks_log, fc)
%
%  Input tracks_log is the snapshot layout returned by trackTargets:
%    .time         scalar absolute timestamp [s]
%    .tracks       objectTrack or struct array for that step
%    .n_confirmed  confirmed track count
%
%  Output track_histories is a per-TrackID struct array:
%    .TrackID
%    .t_abs_s
%    .R_excess_m
%    .Rdot_mps
%    .f_D_hz
%    .StateCovDiag

validateattributes(fc, {'numeric'}, {'scalar', 'real', 'finite', 'positive'}, ...
    mfilename, 'fc');

track_histories = struct( ...
    'TrackID',      {}, ...
    't_abs_s',      {}, ...
    'R_excess_m',   {}, ...
    'Rdot_mps',     {}, ...
    'f_D_hz',       {}, ...
    'StateCovDiag', {});

if isempty(tracks_log)
    return
end

alpha = 2 * fc / physconst('LightSpeed');

for s = 1 : numel(tracks_log)
    t_step = tracks_log(s).time;
    trks   = tracks_log(s).tracks;

    for ii = 1 : numel(trks)
        if ~isprop_or_field(trks(ii), 'TrackID') || ~isprop_or_field(trks(ii), 'State')
            continue
        end

        tid   = double(trks(ii).TrackID);
        state = trks(ii).State(:);
        if numel(state) < 2
            continue
        end

        idx = find_track_index(track_histories, tid);
        if isempty(idx)
            idx = numel(track_histories) + 1;
            track_histories(idx).TrackID      = tid;
            track_histories(idx).t_abs_s      = zeros(0, 1);
            track_histories(idx).R_excess_m   = zeros(0, 1);
            track_histories(idx).Rdot_mps     = zeros(0, 1);
            track_histories(idx).f_D_hz       = zeros(0, 1);
            track_histories(idx).StateCovDiag = zeros(0, 0);
        end

        track_histories(idx).t_abs_s(end + 1, 1)    = t_step; %#ok<AGROW>
        track_histories(idx).R_excess_m(end + 1, 1) = state(1); %#ok<AGROW>
        track_histories(idx).Rdot_mps(end + 1, 1)   = state(2); %#ok<AGROW>
        track_histories(idx).f_D_hz(end + 1, 1)     = -alpha * state(2); %#ok<AGROW>

        if isprop_or_field(trks(ii), 'StateCovariance')
            diagP = diag(trks(ii).StateCovariance).';
            if isempty(track_histories(idx).StateCovDiag)
                track_histories(idx).StateCovDiag = zeros(0, numel(diagP));
            end
            track_histories(idx).StateCovDiag(end + 1, 1:numel(diagP)) = diagP; %#ok<AGROW>
        end
    end
end

end

function idx = find_track_index(track_histories, tid)
idx = [];
if isempty(track_histories)
    return
end

track_ids = [track_histories.TrackID];
idx = find(track_ids == tid, 1, 'first');
end

function tf = isprop_or_field(obj, name)
if isstruct(obj)
    tf = isfield(obj, name);
else
    tf = isprop(obj, name);
end
end
