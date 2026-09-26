classdef CueListenerTest < matlab.unittest.TestCase
    %CUELISTENERTEST Cue state, ranking, sequencing and socket receive for CueListener.
    %   The fixture is 16 real datagrams multicast by the cue tasker on the ADS-B
    %   Pi on 2026-09-26: three aircraft, a revision update, heartbeats and one
    %   full snapshot.

    properties (Constant)
        Now = datetime(2026, 9, 26, 0, 52, 0, 'TimeZone', 'UTC')
    end

    properties
        Fixture
    end

    methods (TestClassSetup)
        function addListenerFolder(testCase)
            testFolder = fileparts(mfilename('fullpath'));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fileparts(testFolder)));
            testCase.Fixture = fullfile(testFolder, 'fixtures', 'pi_cue_capture_20260926.jsonl');
        end
    end

    methods (Test)
        function testReplayCountsEveryMessageWithoutGaps(testCase)
            listener = CueListener.replay(testCase.Fixture);
            stats = listener.Stats;

            testCase.verifyEqual(stats.Received, 16);
            testCase.verifyEqual(stats.MessageCounts.track_cue, 8);
            testCase.verifyEqual(stats.MessageCounts.cue_heartbeat, 6);
            testCase.verifyEqual(stats.MessageCounts.cue_snapshot_begin, 1);
            testCase.verifyEqual(stats.MessageCounts.cue_snapshot_end, 1);
            testCase.verifyEqual([stats.SequenceGaps, stats.OutOfOrder, stats.DecodeErrors], [0 0 0]);
            testCase.verifyEqual([stats.SnapshotsComplete, stats.SnapshotsIncomplete], [1 0]);
            testCase.verifyEqual(stats.Duplicates, 0);
            testCase.verifyEqual(listener.LastCompleteSnapshotUtc, ...
                datetime(2026, 9, 26, 0, 51, 37, 269, 'TimeZone', 'UTC'));
            testCase.verifyEqual(listener.status().HeartbeatStatus, "running");
        end

        function testActiveCuesRankAircraftByBestPeakSnr(testCase)
            listener = CueListener.replay(testCase.Fixture);

            cues = activeCues(listener, 'Now', testCase.Now);

            testCase.verifyEqual(cues.ICAO.', ["C06363", "A8D5A0", "4CC530"]);
            testCase.verifyEqual(cues.Revision.', [11 57 20]);
            testCase.verifyEqual(cues.Opportunities.', [3 3 0]);
            testCase.verifyEqual(cues.BestPeakSNR_dB(1), 14.92, AbsTol=0.01);
            testCase.verifyTrue(isnan(cues.BestPeakSNR_dB(3)));
            testCase.verifyGreaterThan(cues.BestWindowEnd(1), cues.BestWindowStart(1));
            testCase.verifyEqual(cues.ReportAge_s(1), 66.408, AbsTol=1e-3);
        end

        function testExpiredPredictionsLeaveTheActiveView(testCase)
            listener = CueListener.replay(testCase.Fixture);
            later = datetime(2026, 9, 26, 1, 5, 0, 'TimeZone', 'UTC');

            testCase.verifyEmpty(activeCues(listener, 'Now', later));
            testCase.verifyEqual(height(activeCues(listener, 'Now', later, 'IncludeExpired', true)), 3);
        end

        function testOpportunityWindowsForOneAircraft(testCase)
            listener = CueListener.replay(testCase.Fixture);

            windows = opportunities(listener, "adsb:C06363");

            testCase.verifyEqual(height(windows), 3);
            testCase.verifyTrue(issorted(windows.PeakSNR_dB, 'descend'));
            testCase.verifyEqual(windows.RfChannel.', [19 20 32]);
            testCase.verifyTrue(all(windows.WindowEnd > windows.WindowStart));
            testCase.verifyEqual(height(opportunities(listener, "adsb:NOSUCH")), 0);
        end

        function testOlderRevisionIsIgnored(testCase)
            listener = CueListener.replay(testCase.Fixture);
            stale = latestCue(listener, "adsb:C06363");
            stale.prediction.revision = 5;
            stale.message_id = '9d7c1b6e-0000-4000-8000-0000000000a5';   % a different datagram

            listener.ingestMessage(stale);

            testCase.verifyEqual(latestCue(listener, "adsb:C06363").prediction.revision, 11);
            testCase.verifyEqual(listener.Stats.StaleRevisionsIgnored, 1);
        end

        function testWithdrawalRemovesTheAircraft(testCase)
            listener = CueListener.replay(testCase.Fixture);
            cue = latestCue(listener, "adsb:A8D5A0");
            withdrawal = struct('schema_version', '1.1.0', ...
                'message_type', 'track_cue_withdrawal', ...
                'source_instance_id', cue.source_instance_id, ...
                'sequence_number', 17, 'track_id', 'adsb:A8D5A0', 'icao', 'A8D5A0', ...
                'withdrawn_prediction_revision', 57, 'reason', 'track_purged');

            listener.ingestMessage(withdrawal);

            testCase.verifyEmpty(latestCue(listener, "adsb:A8D5A0"));
            testCase.verifyTrue(isKey(listener.Withdrawn, 'adsb:A8D5A0'));
            testCase.verifyEqual(height(activeCues(listener, 'Now', testCase.Now)), 2);
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

        function testSnapshotWithALostCueIsIncomplete(testCase)
            partial = [tempname '.jsonl'];
            testCase.addTeardown(@() localDelete(partial));
            lines = readlines(testCase.Fixture, 'EmptyLineRule', 'skip');
            writelines(lines([1:13, 15:16]), partial);   % drop datagram 14, a snapshot cue

            listener = CueListener.replay(partial);

            testCase.verifyEqual(listener.Stats.SnapshotsIncomplete, 1);
            testCase.verifyEqual(listener.Stats.SnapshotsComplete, 0);
            testCase.verifyEqual(listener.Stats.SequenceGaps, 1);
            testCase.verifyTrue(isnat(listener.LastCompleteSnapshotUtc));
        end

        function testRepeatedMessageIdIsDropped(testCase)
            listener = CueListener();
            heartbeat = localHeartbeat("sender-a", 1);
            heartbeat.message_id = '9d7c1b6e-0000-4000-8000-000000000001';

            listener.ingestMessage(heartbeat);
            second = listener.ingestMessage(heartbeat);

            testCase.verifyEmpty(second);
            testCase.verifyEqual(listener.Stats.Duplicates, 1);
            testCase.verifyEqual(listener.Stats.Received, 1);
            testCase.verifyEqual(listener.Stats.OutOfOrder, 0);
        end

        function testUndecodableDatagramIsCounted(testCase)
            listener = CueListener();

            testCase.verifyEmpty(listener.ingest('{not json'));
            testCase.verifyEqual(listener.Stats.DecodeErrors, 1);
        end

        function testSocketReceivesUnicastDatagramsAndLogsThem(testCase)
            logFile = [tempname '.jsonl'];
            testCase.addTeardown(@() localDelete(logFile));
            listener = CueListener('MulticastGroup', "", 'InterfaceAddress', "", 'Port', 0, ...
                'LogFile', logFile);
            start(listener);
            testCase.addTeardown(@() stop(listener));
            lines = readlines(testCase.Fixture, 'EmptyLineRule', 'skip');
            % One cue must go out as one datagram; udpport splits writes at 512 bytes by default.
            sender = udpport("datagram", "IPV4", "OutputDatagramSize", 65507);
            for k = 1:4
                write(sender, unicode2native(char(lines(k)), 'UTF-8'), "uint8", ...
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
            testCase.verifyEqual(double(listener.Tracks.Count), 2);
            testCase.verifyEqual(replayed.Stats.Received, 4);
            testCase.verifyEqual(sort(string(replayed.Tracks.keys())), ...
                sort(string(listener.Tracks.keys())));
        end

        function testReplayAcceptsCueCaptureWrapperLines(testCase)
            wrapped = [tempname '.jsonl'];
            testCase.addTeardown(@() localDelete(wrapped));
            lines = readlines(testCase.Fixture, 'EmptyLineRule', 'skip');
            writelines(compose('{"received_unix_s":1790384000.5,"payload":%s}', lines), wrapped);

            listener = CueListener.replay(wrapped);

            testCase.verifyEqual(listener.Stats.Received, 16);
            testCase.verifyEqual(listener.LastHeartbeatReceivedUtc, ...
                datetime(1790384000.5, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC'));
        end

        function testPlotCueWindowsDrawsOneBarPerWindow(testCase)
            listener = CueListener.replay(testCase.Fixture);
            fig = figure('Visible', 'off');
            testCase.addTeardown(@() close(fig));

            ax = plotCueWindows(listener, 'Now', testCase.Now, 'Axes', axes(fig));

            testCase.verifyNumElements(findobj(ax, 'Tag', 'CueWindow'), 6);
            testCase.verifyEqual(numel(ax.YTick), 3);
        end
    end
end

function msg = localHeartbeat(source, sequence)
msg = struct('message_type', 'cue_heartbeat', 'source_instance_id', char(source), ...
    'sequence_number', sequence, 'status', 'running', 'active_tracks', 0, ...
    'cue_eligible_tracks', 0);
end

function localDelete(path)
if isfile(path)
    delete(path);
end
end
