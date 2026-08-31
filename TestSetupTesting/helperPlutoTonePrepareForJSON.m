function value_out = helperPlutoTonePrepareForJSON(value_in)
%HELPERPLUTOTONEPREPAREFORJSON Normalize MATLAB values before jsonencode.

if isstruct(value_in)
    value_out = struct();
    field_names = fieldnames(value_in);
    for idx = 1:numel(field_names)
        field_name = field_names{idx};
        value_out.(field_name) = helperPlutoTonePrepareForJSON(value_in.(field_name));
    end
    return
end

if istable(value_in)
    value_out = helperPlutoTonePrepareForJSON(table2struct(value_in));
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
        value_out{idx} = helperPlutoTonePrepareForJSON(value_in{idx});
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

value_out = value_in;
end
