function cueProbe(durationText, interfaceAddress)
%CUEPROBE Deployability probe: Java multicast receive + jsondecode + raw-deflate/dictionary
%   decode inside a MATLAB Compiler standalone app.
%     cueProbe 25 192.168.10.41
if nargin < 1, durationText = '25'; end
if nargin < 2, interfaceAddress = '192.168.10.41'; end
duration = str2double(durationText);
fprintf('deployed=%d  java=%s\n', isdeployed, char(java.lang.System.getProperty('java.version')));

% 1. Inflate a bundled cue that was compressed by Python zlib with a preset dictionary.
here = fileparts(mfilename('fullpath'));
compressed = readBytes(fullfile(here, 'cue.deflate'));
dictionary = readBytes(fullfile(here, 'cue.dict'));
reference = fileread(fullfile(here, 'cue.json'));
inflater = java.util.zip.Inflater(true);
inflater.setDictionary(dictionary);
sink = java.io.ByteArrayOutputStream(16384);
stream = java.util.zip.InflaterOutputStream(sink, inflater);
stream.write(compressed);
stream.close();
inflater.end();
text = native2unicode(typecast(sink.toByteArray(), 'uint8').', 'UTF-8');
cue = jsondecode(text);
fprintf('inflate+dictionary: %d -> %d bytes, byte-exact=%d, jsondecode icao=%s\n', ...
    numel(compressed), numel(text), strcmp(text, reference), cue.track.icao);

% 2. Join the live cue multicast group on the data-network interface and decode what arrives.
socket = java.net.MulticastSocket(java.net.InetSocketAddress(31986));
socket.setReceiveBufferSize(8 * 1024 * 1024);
group = java.net.InetSocketAddress(java.net.InetAddress.getByName('239.192.10.1'), 0);
nic = java.net.NetworkInterface.getByInetAddress(java.net.InetAddress.getByName(interfaceAddress));
socket.joinGroup(group, nic);
socket.setSoTimeout(250);
packet = java.net.DatagramPacket(zeros(1, 65535, 'int8'), 65535);
counts = containers.Map();
t0 = tic;
while toc(t0) < duration
    packet.setLength(65535);
    try
        socket.receive(packet);
    catch err
        if contains(err.message, 'SocketTimeoutException'), continue, end
        rethrow(err);
    end
    data = packet.getData();
    message = jsondecode(native2unicode(typecast(data(1:packet.getLength()), 'uint8').', 'UTF-8'));
    key = message.message_type;
    if isKey(counts, key), counts(key) = counts(key) + 1; else, counts(key) = 1; end
end
socket.leaveGroup(group, nic);
socket.close();
keys = counts.keys();
parts = cellfun(@(k) sprintf('%s=%d', k, counts(k)), keys, 'UniformOutput', false);
fprintf('multicast on %s for %gs via %s: %s\n', interfaceAddress, duration, char(nic.getName()), strjoin(parts, ', '));
fprintf('PROBE OK\n');
end

function b = readBytes(f)
fid = fopen(f, 'r');
b = fread(fid, Inf, '*int8').';
fclose(fid);
end
