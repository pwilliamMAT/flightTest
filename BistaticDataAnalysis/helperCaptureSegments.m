function segment_durations_s = helperCaptureSegments(total_duration_s, max_segment_s)
%HELPERCAPTURESEGMENTS  Split a capture duration into exact sub-segments.
%
%  segment_durations_s = helperCaptureSegments(total_duration_s)
%  segment_durations_s = helperCaptureSegments(total_duration_s, max_segment_s)
%
%  The default max segment is 1 second so sub-second captures remain exact
%  while longer captures are streamed in manageable chunks.

if nargin < 2 || isempty(max_segment_s)
    max_segment_s = 1.0;
end

validateattributes(total_duration_s, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'}, mfilename, 'total_duration_s');
validateattributes(max_segment_s, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'}, mfilename, 'max_segment_s');

whole_segments = floor(total_duration_s / max_segment_s);
remainder_s    = total_duration_s - whole_segments * max_segment_s;

segment_durations_s = repmat(max_segment_s, whole_segments, 1);
if remainder_s > eps(max(total_duration_s, 1))
    segment_durations_s(end + 1, 1) = remainder_s; %#ok<AGROW>
end

if isempty(segment_durations_s)
    segment_durations_s = total_duration_s;
end

end
