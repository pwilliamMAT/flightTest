function artifacts = helperTriggerWriteArtifacts(session_result, context, log_dir, varargin)
%HELPERTRIGGERWRITEARTIFACTS Write the trigger-session review artifacts.
%
% Plain-language goal:
%   Every run, including no-trigger and shadow runs, should leave behind
%   enough evidence to explain what the wrapper saw, what it would have
%   done, and why it did or did not call the local radar capture path.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'session_result', @isstruct);
addRequired(p, 'context', @isstruct);
addRequired(p, 'log_dir', @(x) ischar(x) || isstring(x));
addParameter(p, 'Verbose', false, @islogical);
parse(p, session_result, context, log_dir, varargin{:});
opts = p.Results;

log_dir = string(log_dir);
if exist(log_dir, 'dir') ~= 7
    mkdir(log_dir);
end

summary_path = fullfile(log_dir, 'trigger_summary.txt');
decisions_path = fullfile(log_dir, 'trigger_decisions.csv');
context_path = fullfile(log_dir, 'trigger_context.mat');

localWriteTextFile(summary_path, localBuildSummaryText(session_result, context));

decision_log = table();
if isfield(context, 'decision_log') && istable(context.decision_log)
    decision_log = context.decision_log;
end
writetable(decision_log, decisions_path);

save(context_path, 'session_result', 'context', '-v7.3');

artifacts = struct( ...
    'trigger_summary_txt', string(summary_path), ...
    'trigger_decisions_csv', string(decisions_path), ...
    'trigger_context_mat', string(context_path), ...
    'trigger_summary_rel', "logs/trigger_summary.txt", ...
    'trigger_decisions_rel', "logs/trigger_decisions.csv", ...
    'trigger_context_rel', "logs/trigger_context.mat");

if opts.Verbose
    fprintf('[helperTriggerWriteArtifacts] Summary .... %s\n', char(artifacts.trigger_summary_txt));
    fprintf('[helperTriggerWriteArtifacts] Decisions .. %s\n', char(artifacts.trigger_decisions_csv));
    fprintf('[helperTriggerWriteArtifacts] Context .... %s\n', char(artifacts.trigger_context_mat));
end

end

function summary_text = localBuildSummaryText(session_result, context)
lines = strings(0, 1);
lines(end + 1) = "ADS-B Triggered Capture Session Summary";
lines(end + 1) = "======================================";
lines(end + 1) = "Session ID:\t" + string(session_result.session_id);
lines(end + 1) = "Mode:\t" + string(session_result.mode);
lines(end + 1) = "Opportunity:\t" + string(session_result.opportunity_policy);
lines(end + 1) = "Final Status:\t" + string(session_result.final_status);
lines(end + 1) = "Watch Start:\t" + string(session_result.watch_started_utc);
lines(end + 1) = "Watch Stop:\t" + string(session_result.watch_stopped_utc);
lines(end + 1) = "Trigger Fired:\t" + string(session_result.trigger_fired);
lines(end + 1) = "Trigger Reason:\t" + string(session_result.trigger_reason);
lines(end + 1) = "Proxy Mode:\t" + string(session_result.proxy_label);

if isfield(session_result, 'capture_info') && isstruct(session_result.capture_info)
    lines(end + 1) = "Capture Status:\t" + string(localStructField(session_result.capture_info, 'status', "not_run"));
    lines(end + 1) = "Capture File:\t" + string(localStructField(session_result.capture_info, 'capture_file_path', ""));
end

if isfield(context, 'coordinator_status') && isstruct(context.coordinator_status)
    lines(end + 1) = "Coordinator Status:\t" + string(localStructField(context.coordinator_status, 'status', "unknown"));
    lines(end + 1) = "Coordinator Message:\t" + string(localStructField(context.coordinator_status, 'message', ""));
end

if isfield(context, 'decision_log') && istable(context.decision_log)
    lines(end + 1) = "Decision Rows:\t" + string(height(context.decision_log));
end

if isfield(context, 'preview_map') && isstruct(context.preview_map)
    preview_path = string(localStructField(context.preview_map, 'image_path', ""));
    if strlength(preview_path) > 0
        lines(end + 1) = "Preview Map:\t" + preview_path;
    end

    qualified_area_km2 = localStructField(context.preview_map, 'qualified_area_km2', NaN);
    if isfinite(double(qualified_area_km2))
        lines(end + 1) = "Preview Qualified Area:\t" + string(qualified_area_km2) + " km^2";
    end
end

candidate_table = table();
if isfield(session_result, 'candidate_table') && istable(session_result.candidate_table)
    candidate_table = session_result.candidate_table;
end

if isempty(candidate_table)
    lines(end + 1) = "";
    lines(end + 1) = "No candidate aircraft were available at finalization.";
else
    top_count = min(height(candidate_table), 3);
    candidate_lines = strings(2 .* top_count + 2, 1);
    candidate_lines(1) = "";
    candidate_lines(2) = "Top Candidates:";

    line_idx = 2;
    for idx = 1:top_count
        line_idx = line_idx + 1;
        candidate_lines(line_idx) = sprintf([ ...
            '#%d %s %s\ttrigger=%.3f\tgeometry=%.3f\trf=%.3f\toffset=%.1f s\t' ...
            'range=%.1f km\taz=%.1f deg'], ...
            idx, ...
            char(candidate_table.hex(idx)), ...
            char(candidate_table.callsign(idx)), ...
            candidate_table.trigger_score(idx), ...
            candidate_table.geometry_score(idx), ...
            candidate_table.rf_proxy_score(idx), ...
            candidate_table.predicted_start_offset_s(idx), ...
            candidate_table.receiver_range_m(idx) ./ 1e3, ...
            candidate_table.azimuth_deg(idx));
        line_idx = line_idx + 1;
        candidate_lines(line_idx) = "  rationale: " + string(candidate_table.rationale(idx));
    end

    lines = [lines(:); candidate_lines(1:line_idx, 1)];
end

summary_text = strjoin(lines, newline);
end

function value = localStructField(source_struct, field_name, default_value)
value = default_value;
if isstruct(source_struct) && isfield(source_struct, field_name)
    value = source_struct.(field_name);
end
end

function localWriteTextFile(output_path, content)
file_id = -1;
try
    file_id = fopen(output_path, 'w');
    if file_id == -1
        error('helperTriggerWriteArtifacts:fileOpenFailed', ...
            'Could not open %s for writing.', output_path);
    end
    fprintf(file_id, '%s', content);
    fclose(file_id);
catch me_write
    if file_id ~= -1
        fclose(file_id);
    end
    error('helperTriggerWriteArtifacts:writeFailed', ...
        'Could not write %s: %s', output_path, me_write.message);
end
end
