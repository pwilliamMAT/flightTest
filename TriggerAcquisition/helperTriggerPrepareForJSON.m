function value_out = helperTriggerPrepareForJSON(value_in)
%HELPERTRIGGERPREPAREFORJSON Normalize MATLAB values before jsonencode.

if isstruct(value_in)
    if ~isscalar(value_in)
        value_out = arrayfun(@helperTriggerPrepareForJSON, value_in, 'UniformOutput', false);
        return
    end

    value_out = struct();
    field_names = fieldnames(value_in);
    for idx = 1:numel(field_names)
        field_name = field_names{idx};
        value_out.(field_name) = helperTriggerPrepareForJSON(value_in.(field_name));
    end
    return
end

if istable(value_in)
    value_out = helperTriggerPrepareForJSON(table2struct(value_in));
    return
end

if isstring(value_in)
    if isscalar(value_in)
        value_out = char(value_in);
    else
        value_out = cellstr(value_in(:));
    end
    return
end

if iscell(value_in)
    value_out = cell(size(value_in));
    for idx = 1:numel(value_in)
        value_out{idx} = helperTriggerPrepareForJSON(value_in{idx});
    end
    return
end

if isdatetime(value_in)
    value_out = char(string(value_in));
    return
end

if isduration(value_in)
    value_out = seconds(value_in);
    return
end

if isnumeric(value_in) && isscalar(value_in) && ~isfinite(value_in)
    value_out = [];
    return
end

value_out = value_in;

end
