function channel_mapping = helperBuildChannelMapping(antenna_ports, channel_roles, gain_db)
%HELPERBUILDCHANNELMAPPING Preserve the operator-declared stored-channel map.
%
% The stored index is meaningful only in the order explicitly supplied by the
% operator. This helper validates that order and never swaps roles based on
% received power, a header value, or any other inferred signal property.

antenna_ports = reshape(string(antenna_ports), 1, []);
channel_roles = lower(reshape(string(channel_roles), 1, []));
gain_db = double(gain_db(:).');

if numel(antenna_ports) ~= 2 || any(strlength(antenna_ports) == 0)
    error('helperBuildChannelMapping:invalidAntennaPorts', ...
        'AntennaPorts must contain exactly two nonempty values in stored order.');
end

if numel(channel_roles) ~= 2 || ...
        ~isequal(sort(channel_roles), sort(["reference", "surveillance"]))
    error('helperBuildChannelMapping:invalidChannelRoles', ...
        'ChannelRoles must contain one surveillance and one reference role.');
end

if isscalar(gain_db)
    gain_db = repmat(gain_db, 1, 2);
end

if numel(gain_db) ~= 2 || any(~isfinite(gain_db))
    error('helperBuildChannelMapping:invalidGain', ...
        'Gain must be one finite value or two finite values in stored order.');
end

channel_mapping = repmat(struct( ...
    'stored_channel_index', NaN, ...
    'n320_port', "", ...
    'semantic_role', "", ...
    'gain_db', NaN), 1, 2);

for channel_index = 1:2
    channel_mapping(channel_index).stored_channel_index = channel_index;
    channel_mapping(channel_index).n320_port = antenna_ports(channel_index);
    channel_mapping(channel_index).semantic_role = channel_roles(channel_index);
    channel_mapping(channel_index).gain_db = gain_db(channel_index);
end
end
