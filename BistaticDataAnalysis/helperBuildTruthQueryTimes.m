function t_abs_query = helperBuildTruthQueryTimes(part_start_offsets_s, part_dur_s, chunk_dur_s, max_nci_looks)
%HELPERBUILDTRUTHQUERYTIMES Build the full block-center time grid for ADS-B truth.
%
% The static RDM figures represent bounded-NCI CFAR blocks, not only the
% subset of times that produced detections. To overlay ADS-B truth directly
% on those RDMs, truth must be sampled on the same block-center cadence
% used inside processOnePart.
%
% Inputs
%   part_start_offsets_s : [N_parts x 1] absolute start time of each radar part
%   part_dur_s           : scalar part duration in seconds
%   chunk_dur_s          : scalar chunk duration in seconds
%   max_nci_looks        : scalar max looks per CFAR block
%
% Output
%   t_abs_query          : [N_blocks_total x 1] absolute block-center times
%
% See also: processOnePart, alignTruthToRadar.

validateattributes(part_start_offsets_s, {'numeric'}, {'vector', 'real', 'finite'});
validateattributes(part_dur_s,           {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
validateattributes(chunk_dur_s,          {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
validateattributes(max_nci_looks,        {'numeric'}, {'scalar', 'real', 'finite', 'integer', 'positive'});

part_start_offsets_s = part_start_offsets_s(:);

% Match processOnePart's chunk-count logic without needing the raw IQ cube.
N_chunks = max(1, floor(part_dur_s / chunk_dur_s + 1e-9));

t_rel_blocks     = zeros(0, 1);
block_look_count = 0;

for k_chunk = 1 : N_chunks
    first_chunk_in_block = k_chunk - block_look_count;
    block_look_count     = block_look_count + 1;

    block_is_full = (block_look_count == max_nci_looks);
    is_last_chunk = (k_chunk == N_chunks);

    if block_is_full || is_last_chunk
        block_center_s = ((first_chunk_in_block - 1 + k_chunk) / 2) * chunk_dur_s;
        t_rel_blocks(end + 1, 1) = block_center_s; %#ok<AGROW>
        block_look_count = 0;
    end
end

t_abs_query = zeros(0, 1);
for ip = 1 : numel(part_start_offsets_s)
    t_abs_query = [t_abs_query; part_start_offsets_s(ip) + t_rel_blocks]; %#ok<AGROW>
end

t_abs_query = unique(t_abs_query, 'sorted');

end
