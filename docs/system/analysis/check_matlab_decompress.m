%CHECK_MATLAB_DECOMPRESS Can a MATLAB consumer decode compressed cue datagrams in memory?
%   MATLAB has no in-memory gunzip, but its JVM's java.util.zip does both gzip and raw
%   deflate with a preset dictionary. This script takes a real track_cue from the evidence
%   capture, compresses it both ways, decodes it again, checks the result is byte-exact,
%   and times each decode against jsondecode alone.
%
%   Verified 2026-09-26 on R2026a (Java 1.8) with payloads produced by Python's gzip and
%   zlib (the ADSB cue tasker side): both decoded byte-exact, gzip 0.37 ms, deflate with
%   dictionary 0.16 ms, jsondecode 0.30 ms per 8 kB track_cue.
%
%   Note: MATLAB passes arrays to Java by copy, so stream.read(buf) or inflate(buf) into a
%   MATLAB buffer leaves it empty. Write the compressed bytes INTO a java.util.zip
%   InflaterOutputStream and take the result from ByteArrayOutputStream.toByteArray(): plain
%   Java 8, no MATLAB-bundled libraries, and it works in compiled apps (see deployability/).
%
%   See also analyze_cue_traffic.py, Cue_Traffic_Encoding.md.

here = fileparts(mfilename('fullpath'));
lines = readlines(fullfile(here, '..', 'evidence', 'cue_traffic_20260926T1234Z.jsonl'), ...
    'EmptyLineRule', 'skip');
cue = lines(find(contains(lines, '"message_type":"track_cue"'), 1));
cueBytes = unicode2native(char(cue), 'UTF-8');
dictionaryLines = readlines(fullfile(here, '..', 'evidence', 'cue_traffic_20260926T0050Z.jsonl'), ...
    'EmptyLineRule', 'skip');
dictionary = unicode2native(char(strjoin(dictionaryLines, '')), 'UTF-8');
dictionary = dictionary(max(1, end - 32767):end);

% Encode (what the sender would do), done here with Java so the script is self-contained.
bytesOut = java.io.ByteArrayOutputStream();
gzipOut = java.util.zip.GZIPOutputStream(bytesOut);
gzipOut.write(cueBytes);
gzipOut.close();
gz = bytesOut.toByteArray();

deflater = java.util.zip.Deflater(9, true);        % raw deflate, no zlib header
deflater.setDictionary(dictionary);
bytesOut = java.io.ByteArrayOutputStream();
deflateOut = java.util.zip.DeflaterOutputStream(bytesOut, deflater);
deflateOut.write(cueBytes);
deflateOut.close();
deflater.end();
df = bytesOut.toByteArray();

% Decode (what a MATLAB consumer would do).
repeats = 200;
tic
for k = 1:repeats
    % Java's GZIPOutputStream writes a minimal 10-byte header and an 8-byte trailer around
    % raw deflate data, so the body inflates like the dictionary case below.
    gzText = inflateRaw(gz(11:end - 8), []);
end
gzipMs = 1e3 * toc / repeats;

tic
for k = 1:repeats
    dfText = inflateRaw(df, dictionary);
end
deflateMs = 1e3 * toc / repeats;

tic
for k = 1:repeats
    decoded = jsondecode(char(cue)); %#ok<NASGU>
end
jsonMs = 1e3 * toc / repeats;

fprintf('track_cue %d B | gzip %d B, decode ok=%d, %.2f ms | deflate+dictionary %d B, decode ok=%d, %.2f ms | jsondecode %.2f ms\n', ...
    numel(cueBytes), numel(gz), strcmp(gzText, char(cue)), gzipMs, ...
    numel(df), strcmp(dfText, char(cue)), deflateMs, jsonMs);

function text = inflateRaw(compressed, dictionary)
% Raw deflate (RFC 1951) decode with an optional preset dictionary, java.util.zip only.
inflater = java.util.zip.Inflater(true);
if ~isempty(dictionary)
    inflater.setDictionary(dictionary);   % raw streams take the dictionary before any input
end
sink = java.io.ByteArrayOutputStream(16384);
stream = java.util.zip.InflaterOutputStream(sink, inflater);
stream.write(compressed);
stream.close();
inflater.end();
text = native2unicode(typecast(sink.toByteArray(), 'uint8').', 'UTF-8');
end
