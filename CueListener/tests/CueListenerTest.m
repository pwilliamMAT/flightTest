classdef CueListenerTest < matlab.unittest.TestCase
    %CUELISTENERTEST Cue state, ranking, framing and socket receive for CueListener.
    %   The fixture is 20 consecutive real datagrams (sequence 172-191) multicast by
    %   the cue tasker on the ADS-B Pi at 2026-09-26 15:32 UTC, CT schema 2.0.0,
    %   compressed with dictionary 1, stored as the exact wire bytes (datagram_b64).
    %   They hold five aircraft, a complete snapshot, revision updates and heartbeats.

    properties (Constant)
        Now = datetime(2026, 9, 26, 15, 33, 30, 'TimeZone', 'UTC')
    end

    properties
        Fixture
        Lines
    end

    methods (TestClassSetup)
        function addListenerFolder(testCase)
            testFolder = fileparts(mfilename('fullpath'));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fileparts(testFolder)));
            testCase.Fixture = fullfile(testFolder, 'fixtures', 'pi_cue_capture_20260926T1532Z.jsonl');
            testCase.Lines = readlines(testCase.Fixture, 'EmptyLineRule', 'skip');
        end
    end

    methods (Test)
        function testReplayDecodesEveryCompressedDatagramWithoutGaps(testCase)
            listener = CueListener.replay(testCase.Fixture);
            stats = listener.Stats;

            testCase.verifyEqual([stats.Received, stats.CompressedDatagrams, stats.FrameErrors], [20 20 0]);
            testCase.verifyEqual(stats.MessageCounts.track_cue, 13);
            testCase.verifyEqual(stats.MessageCounts.cue_heartbeat, 5);
            testCase.verifyEqual([stats.SequenceGaps, stats.OutOfOrder, stats.DecodeErrors], [0 0 0]);
            testCase.verifyEqual([stats.SnapshotsComplete, stats.SnapshotsIncomplete], [1 0]);
            testCase.verifyEqual(listener.LastCompleteSnapshotUtc, ...
                datetime(1790436764.983, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC'), ...
                AbsTol=milliseconds(1));
            testCase.verifyEqual(listener.status().HeartbeatStatus, "running");
        end

        function testActiveCuesRankAircraftByBestPeakSnr(testCase)
            listener = CueListener.replay(testCase.Fixture);

            cues = activeCues(listener, 'Now', testCase.Now);

            testCase.verifyEqual(height(cues), 5);
            testCase.verifyEqual(cues.ICAO(1:2).', ["AA5DC5", "A07EEE"]);
            testCase.verifyEqual(cues.ICAO(5), "AB048D");                  % no usable opportunity
            testCase.verifyEqual(cues.Revision(1), 55);                   % newest of r53..r55
            testCase.verifyEqual(cues.Opportunities.', [8 8 8 8 0]);
            testCase.verifyEqual(cues.BestPeakSNR_dB(1), 8.5, AbsTol=1e-9);
            testCase.verifyTrue(isnan(cues.BestPeakSNR_dB(5)));
            testCase.verifyEqual(cues.ReportAge_s(1), 29.237, AbsTol=1e-3);  % from last_report_utc_ms
            testCase.verifyGreaterThan(cues.BestWindowEnd(1), cues.BestWindowStart(1));
        end

        function testExpiredPredictionsLeaveTheActiveView(testCase)
            listener = CueListener.replay(testCase.Fixture);
            later = datetime(2026, 9, 26, 15, 50, 0, 'TimeZone', 'UTC');

            testCase.verifyEmpty(activeCues(listener, 'Now', later));
            testCase.verifyEqual(height(activeCues(listener, 'Now', later, 'IncludeExpired', true)), 5);
        end

        function testOpportunityWindowsForOneAircraft(testCase)
            listener = CueListener.replay(testCase.Fixture);

            windows = opportunities(listener, "adsb:AA5DC5");

            testCase.verifyEqual(height(windows), 8);
            testCase.verifyTrue(issorted(windows.PeakSNR_dB, 'descend'));
            testCase.verifyEqual(sort(windows.RfChannel).', [19 20 32 32 33 34 35 35]);
            testCase.verifyTrue(all(windows.WindowEnd > windows.WindowStart));
            testCase.verifyEqual(windows.Emitter(1), "WUTF-TV ch19");     % call sign from the DTV table
            testCase.verifyEqual(height(opportunities(listener, "adsb:NOSUCH")), 0);
        end

        function testOlderRevisionIsIgnored(testCase)
            listener = CueListener.replay(testCase.Fixture);
            stale = latestCue(listener, "adsb:AA5DC5");
            stale.prediction.revision = 5;
            stale.message_id = '9d7c1b6e-0000-4000-8000-0000000000a5';   % a different datagram

            listener.ingestMessage(stale);

            testCase.verifyEqual(latestCue(listener, "adsb:AA5DC5").prediction.revision, 55);
            testCase.verifyEqual(listener.Stats.StaleRevisionsIgnored, 1);
        end

        function testWithdrawalRemovesTheAircraft(testCase)
            listener = CueListener.replay(testCase.Fixture);
            cue = latestCue(listener, "adsb:A07EEE");
            withdrawal = struct('schema_version', '2.0.0', ...
                'message_type', 'track_cue_withdrawal', ...
                'message_id', '9d7c1b6e-0000-4000-8000-0000000000b1', ...
                'source_instance_id', cue.source_instance_id, ...
                'sequence_number', 192, 'track_id', 'adsb:A07EEE', 'icao', 'A07EEE', ...
                'withdrawn_prediction_revision', 41, 'reason', 'track_purged');

            listener.ingestMessage(withdrawal);

            testCase.verifyEmpty(latestCue(listener, "adsb:A07EEE"));
            testCase.verifyTrue(isKey(listener.Withdrawn, 'adsb:A07EEE'));
            testCase.verifyEqual(height(activeCues(listener, 'Now', testCase.Now)), 4);
        end

        function testSequenceGapsAndSenderRestartsAreCounted(testCase)
            listener = CueListener();
            for sequence = [1 2 5]
                listener.ingestMessage(localHeartbeat("sender-a", sequence));
            end
            listener.ingestMessage(localHeartbeat("sender-b", 1));
            listener.ingestMessage(localHeartbeat("sender-b", 2));

            testCase.verifyEqual(listener.Stats.SequenceGaps, 2);
            testCase.verifyEqual(listener.Stats.SourceRestarts, 1);
            testCase.verifyEqual(listener.SourceInstanceId, "sender-b");
        end

        function testRepeatedMessageIdIsDropped(testCase)
            listener = CueListener();
            heartbeat = localHeartbeat("sender-a", 1);
            heartbeat.message_id = '9d7c1b6e-0000-4000-8000-000000000001';

            listener.ingestMessage(heartbeat);
            second = listener.ingestMessage(heartbeat);

            testCase.verifyEmpty(second);
            testCase.verifyEqual([listener.Stats.Duplicates, listener.Stats.Received], [1 1]);
        end

        function testSnapshotWithALostCueIsIncomplete(testCase)
            partial = [tempname '.jsonl'];
            testCase.addTeardown(@() localDelete(partial));
            writelines(testCase.Lines([1:11, 13:20]), partial);   % drop datagram 183, a snapshot cue

            listener = CueListener.replay(partial);

            testCase.verifyEqual([listener.Stats.SnapshotsComplete, listener.Stats.SnapshotsIncomplete], [0 1]);
            testCase.verifyEqual(listener.Stats.SequenceGaps, 1);
            testCase.verifyTrue(isnat(listener.LastCompleteSnapshotUtc));
        end

        function testOlderSchemaVersionIsDropped(testCase)
            listener = CueListener();
            old = localHeartbeat("sender-a", 1);
            old.schema_version = '1.1.0';

            testCase.verifyEmpty(listener.ingestMessage(old));
            testCase.verifyEqual([listener.Stats.UnsupportedVersion, listener.Stats.Received], [1 0]);
        end

        function testPlainAndCompressedFramingDecodeToTheSameMessage(testCase)
            listener = CueListener();
            record = jsondecode(testCase.Lines(1));
            compressed = matlab.net.base64decode(record.datagram_b64);

            text = listener.decodeDatagram(compressed);
            plain = listener.decodeDatagram(unicode2native(text, 'UTF-8'));

            testCase.verifyEqual(compressed(1:2), uint8([220 1]));        % 0xDC, dictionary 1
            testCase.verifyEqual(plain, text);
            testCase.verifyEqual(jsondecode(text).schema_version, '2.0.0');
            testCase.verifyEqual([listener.Stats.CompressedDatagrams, listener.Stats.PlainDatagrams], [1 1]);
        end

        function testUnknownFramesAndDictionariesAreCountedAndDropped(testCase)
            listener = CueListener();

            testCase.verifyEmpty(listener.ingestDatagram(uint8([0 1 2])));
            testCase.verifyEmpty(listener.ingestDatagram(uint8([220 9 1 2 3])));

            testCase.verifyEqual(listener.Stats.FrameErrors, 2);
            testCase.verifySubstring(listener.Stats.LastFrameError, "dictionary id 9");
            testCase.verifyEmpty(listener.ingest('{not json'));
            testCase.verifyEqual(listener.Stats.DecodeErrors, 1);
        end

        function testDictionaryChecksumMismatchIsRejected(testCase)
            folder = tempname;
            mkdir(folder);
            testCase.addTeardown(@() rmdir(folder, 's'));
            fid = fopen(fullfile(folder, 'cue-dictionary-1.bin'), 'w');
            fwrite(fid, uint8('not the released dictionary'));
            fclose(fid);
            writelines(repmat('0', 1, 64) + "  cue-dictionary-1.bin", ...
                fullfile(folder, 'cue-dictionary-1.sha256'));

            testCase.verifyError(@() CueListener('DictionaryDir', folder), ...
                'CueListener:DictionaryChecksum');
        end

        function testSocketReceivesCompressedDatagramsAndLogsThem(testCase)
            logFile = [tempname '.jsonl'];
            testCase.addTeardown(@() localDelete(logFile));
            listener = CueListener('MulticastGroup', "", 'InterfaceAddress', "", 'Port', 0, ...
                'LogFile', logFile);
            start(listener);
            testCase.addTeardown(@() stop(listener));
            % One cue must go out as one datagram; udpport splits writes at 512 bytes by default.
            sender = udpport("datagram", "IPV4", "OutputDatagramSize", 65507);
            for k = 1:4
                record = jsondecode(testCase.Lines(k));
                write(sender, matlab.net.base64decode(record.datagram_b64), "uint8", ...
                    "127.0.0.1", listener.LocalPort);
            end

            received = {};
            deadline = tic;
            while numel(received) < 4 && toc(deadline) < 5
                received = [received, poll(listener)]; %#ok<AGROW>
                pause(0.05);
            end
            stop(listener);
            replayed = CueListener.replay(logFile);

            testCase.verifyEqual(numel(received), 4);
            testCase.verifyEqual(listener.Stats.CompressedDatagrams, 4);
            testCase.verifyEqual(replayed.Stats.Received, 4);
            testCase.verifyEqual(sort(string(replayed.Tracks.keys())), ...
                sort(string(listener.Tracks.keys())));
        end

        function testReplayAcceptsDecodedPayloadLines(testCase)
            decoded = [tempname '.jsonl'];
            testCase.addTeardown(@() localDelete(decoded));
            listener = CueListener();
            out = strings(numel(testCase.Lines), 1);
            for k = 1:numel(testCase.Lines)
                record = jsondecode(testCase.Lines(k));
                out(k) = sprintf('{"received_unix_s":%.3f,"payload":%s}', record.received_unix_s, ...
                    listener.decodeDatagram(matlab.net.base64decode(record.datagram_b64)));
            end
            writelines(out, decoded);

            replayed = CueListener.replay(decoded);

            testCase.verifyEqual(replayed.Stats.Received, 20);
            testCase.verifyEqual(replayed.Stats.CompressedDatagrams, 0);
            testCase.verifyEqual(double(replayed.Tracks.Count), 5);
        end

        function testPlotCueWindowsDrawsOneBarPerWindow(testCase)
            listener = CueListener.replay(testCase.Fixture);
            fig = figure('Visible', 'off');
            testCase.addTeardown(@() close(fig));

            ax = plotCueWindows(listener, 'Now', testCase.Now, 'Axes', axes(fig));

            testCase.verifyNumElements(findobj(ax, 'Tag', 'CueWindow'), 32);
            testCase.verifyEqual(numel(ax.YTick), 5);
        end
    end
end

function msg = localHeartbeat(source, sequence)
msg = struct('schema_version', '2.0.0', 'message_type', 'cue_heartbeat', ...
    'source_instance_id', char(source), 'sequence_number', sequence, 'status', 'running', ...
    'active_tracks', 0, 'cue_eligible_tracks', 0);
end

function localDelete(path)
if isfile(path)
    delete(path);
end
end
