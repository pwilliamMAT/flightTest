function seed_fixture = helperSyntheticDescribeSeedFixture(seed_source_path)
%HELPERSYNTHETICDESCRIBESEEDFIXTURE Summarize the seed fixture provenance.
%
% Plain language:
% The readiness gate needs to record which illuminator seed drove the
% synthetic session. This helper reads lightweight metadata from the seed
% `.bb` file when available and falls back to the file name when the seed
% is not a packaged baseband capture.

validateattributes(seed_source_path, {'char', 'string'}, {'scalartext'}, mfilename, 'seed_source_path');

seed_path = char(string(seed_source_path));
if strlength(string(seed_path)) == 0
    seed_fixture = localDefaultSeedFixture();
    return
end

seed_fixture = localDefaultSeedFixture();
seed_fixture.path = seed_path;
seed_fixture.file_name = string(localFileNameOnly(seed_path));
seed_fixture.id = string(localFileStem(seed_path));
seed_fixture.exists = exist(seed_path, 'file') == 2;

if ~seed_fixture.exists
    return
end

try
    reader = comm.BasebandFileReader(seed_path, 'SamplesPerFrame', 1);
    cleanup_reader = onCleanup(@() release(reader)); %#ok<NASGU>
    metadata = reader.Metadata;

    seed_fixture.readable = true;
    seed_fixture.sample_rate_hz = double(reader.SampleRate);
    seed_fixture.center_frequency_hz = double(reader.CenterFrequency);
    seed_fixture.session_id = string(localMetadataString(metadata, 'SessionID', seed_fixture.id));
    seed_fixture.signal_mode = string(localMetadataString(metadata, 'SignalMode', ""));
    seed_fixture.data_origin = string(localMetadataString(metadata, 'DataOrigin', ""));
    seed_fixture.label = string(localMetadataString(metadata, 'Label', ""));
    seed_fixture.id = seed_fixture.session_id;
    seed_fixture.kind = localResolveSeedFixtureKind(seed_fixture.signal_mode, seed_fixture.data_origin);
catch
    % Keep the file-based fallback summary when metadata readback fails.
end
end

function seed_fixture = localDefaultSeedFixture()
seed_fixture = struct( ...
    'id', "", ...
    'path', "", ...
    'file_name', "", ...
    'exists', false, ...
    'readable', false, ...
    'kind', "not_applicable", ...
    'label', "", ...
    'session_id', "", ...
    'signal_mode', "", ...
    'data_origin', "", ...
    'sample_rate_hz', NaN, ...
    'center_frequency_hz', NaN);
end

function value = localMetadataString(metadata, field_name, default_value)
value = char(string(default_value));
if ~isstruct(metadata) || ~isfield(metadata, field_name) || isempty(metadata.(field_name))
    return
end

value = char(string(metadata.(field_name)));
end

function kind = localResolveSeedFixtureKind(signal_mode, data_origin)
signal_mode = char(string(signal_mode));
data_origin = char(string(data_origin));

if strcmpi(signal_mode, 'probe_seed_v1')
    kind = "probe_seed";
elseif strcmpi(data_origin, 'synthetic')
    kind = "synthetic_seed";
else
    kind = "field_seed";
end
end

function file_name = localFileNameOnly(file_path)
[~, file_name, extension] = fileparts(file_path);
file_name = [file_name extension];
end

function file_stem = localFileStem(file_path)
[~, file_stem] = fileparts(file_path);
end
