classdef Stage4BADSBIntervalCampaignScriptTest < matlab.unittest.TestCase
    %STAGE4BADSBINTERVALCAMPAIGNSCRIPTTEST Verify the ADS-B campaign coordinator.

    properties
        ProjectRoot
        ScriptPath
    end

    methods (TestMethodSetup)
        function addProjectPath(testCase)
            testFolder = fileparts(mfilename("fullpath"));
            testCase.ProjectRoot = fileparts(testFolder);
            testCase.ScriptPath = fullfile( ...
                testCase.ProjectRoot, ...
                "piCaptureCampaign", ...
                "run_stage4_adsb_interval_campaign.sh");

            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(testCase.ProjectRoot));
        end
    end

    methods (Test)
        function testCampaignScriptExists(testCase)
            testCase.verifyEqual(exist(testCase.ScriptPath, "file"), 2);
        end

        function testCampaignScriptPassesBashSyntax(testCase)
            bashPath = localAssumeBashAvailable(testCase);

            command = localQuoteForCommandPath(bashPath) + " -n " + ...
                localQuoteForCommandPath(testCase.ScriptPath);
            [status, output] = system(command);

            testCase.verifyEqual(status, 0, output);
        end

        function testHelpListsTestingMachineOptions(testCase)
            bashPath = localAssumeBashAvailable(testCase);

            command = localBashCommand(bashPath, testCase.ScriptPath, "--help");
            [status, output] = system(command);
            outputText = string(output);

            testCase.verifyEqual(status, 0, outputText);
            localVerifyContains(testCase, outputText, "--pi-host <host>");
            localVerifyContains(testCase, outputText, "--pi-user <user>");
            localVerifyContains(testCase, outputText, "--pi-workdir <path>");
            localVerifyContains(testCase, outputText, "--pi-logger-script <path>");
            localVerifyContains(testCase, outputText, "--ssh-bin <path>");
            localVerifyContains(testCase, outputText, "--scp-bin <path>");
            localVerifyContains(testCase, outputText, "--adsb-stage-dir <path>");
            localVerifyContains(testCase, outputText, "--session-root <path>");
            localVerifyContains(testCase, outputText, "--remote-wait-timeout <seconds>");
            localVerifyContains(testCase, outputText, "--fetch-poll <seconds>");
            localVerifyContains(testCase, outputText, "--receiver-origin-lla <lat,lon,alt_m>");
            localVerifyContains(testCase, outputText, "default: 300");
            localVerifyContains(testCase, outputText, "default: 1800");
            localVerifyContains(testCase, outputText, "default: 259200");
            localVerifyContains(testCase, outputText, "sudo -n bash start_adsb_gps_loggers.sh --adsb-only");
        end

        function testOperatorReadmeDescribesTestingMachineCoordinator(testCase)
            readmePath = fullfile( ...
                testCase.ProjectRoot, ...
                "piCaptureCampaign", ...
                "README.md");
            readmeText = string(fileread(readmePath));

            localVerifyContains(testCase, readmeText, "testing machine");
            localVerifyContains(testCase, readmeText, "SSHes to the Pi");
            localVerifyContains(testCase, readmeText, "session_manifest.json");
            localVerifyContains(testCase, readmeText, "receiver_origin_lla");
        end

        function testDryRunPlansThreeUniqueWindowsAndPrintsCoordinatorContext(testCase)
            bashPath = localAssumeBashAvailable(testCase);

            arguments = strjoin([ ...
                "--dry-run", ...
                "--campaign-id stage4B_test", ...
                "--campaign-seconds 3700", ...
                "--capture-seconds 300", ...
                "--interval-seconds 1800", ...
                "--receiver-origin-lla 1.25,-2.5,33"], " ");
            command = localBashCommand(bashPath, testCase.ScriptPath, arguments);
            [status, output] = system(command);

            testCase.verifyEqual(status, 0, output);

            tabCharacter = string(char(9));
            outputText = string(output);
            outputLines = splitlines(outputText);
            planLines = outputLines(startsWith(outputLines, "PLAN" + tabCharacter));
            planFields = split(planLines, tabCharacter);
            sessionIDs = planFields(:, 3);

            testCase.verifyNumElements(planLines, 3);
            testCase.verifyNumElements(unique(sessionIDs), 3);
            testCase.verifyTrue(all(contains(sessionIDs, "stage4B_test_w")));
            localVerifyContains(testCase, outputText, "PI_TARGET" + tabCharacter + "pi2@192.168.10.131");
            localVerifyContains(testCase, outputText, "SESSION_ROOT" + tabCharacter);
            localVerifyContains(testCase, outputText, "RECEIVER_ORIGIN_LLA" + tabCharacter + "1.25,-2.5,33");
            localVerifyContains(testCase, outputText, "REMOTE_COMMAND_TEMPLATE" + tabCharacter);
            localVerifyContains(testCase, outputText, "sudo -n bash 'start_adsb_gps_loggers.sh'");
            localVerifyContains(testCase, outputText, "DRY_RUN_PLAN_WINDOWS" + tabCharacter + "3");
        end

        function testInvalidNumericOptionsAndReceiverLLAFail(testCase)
            bashPath = localAssumeBashAvailable(testCase);

            invalidArguments = [ ...
                "--dry-run --capture-seconds 0", ...
                "--dry-run --interval-seconds abc", ...
                "--dry-run --campaign-seconds -1", ...
                "--dry-run --max-windows -2", ...
                "--dry-run --remote-wait-timeout 0", ...
                "--dry-run --fetch-poll 0", ...
                "--dry-run --receiver-origin-lla 1,2", ...
                "--dry-run --receiver-origin-lla 91,0,0"];

            for argumentIdx = 1:numel(invalidArguments)
                command = localBashCommand( ...
                    bashPath, ...
                    testCase.ScriptPath, ...
                    invalidArguments(argumentIdx));
                [status, output] = system(command);

                testCase.verifyNotEqual(status, 0, ...
                    "Expected failure for: " + invalidArguments(argumentIdx));
                localVerifyContains(testCase, string(output), "ERROR");
            end
        end

        function testFailedPreflightDoesNotCreateCampaignOrSessionPackage(testCase)
            bashPath = localAssumeBashAvailable(testCase);

            tempFixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            outputRoot = fullfile(tempFixture.Folder, "campaigns");
            sessionRoot = fullfile(tempFixture.Folder, "captures");
            stageRoot = fullfile(tempFixture.Folder, "adsb_stage");
            campaignFolder = fullfile(outputRoot, "preflight_missing_test");

            arguments = strjoin([ ...
                "--preflight-only", ...
                "--campaign-id preflight_missing_test", ...
                "--ssh-bin missing_stage4b_ssh", ...
                "--scp-bin missing_stage4b_scp", ...
                "--output-root " + localQuoteForCommandPath(outputRoot), ...
                "--session-root " + localQuoteForCommandPath(sessionRoot), ...
                "--adsb-stage-dir " + localQuoteForCommandPath(stageRoot)], " ");
            command = localBashCommand(bashPath, testCase.ScriptPath, arguments);
            [status, output] = system(command);
            outputText = string(output);

            testCase.verifyNotEqual(status, 0);
            localVerifyContains(testCase, outputText, "Preflight result: FAIL");
            testCase.verifyEqual(exist(campaignFolder, "dir"), 0);
            testCase.verifyEqual(numel(dir(fullfile(sessionRoot, "*", "session_manifest.json"))), 0);
        end

        function testFakeSSHAndSCPPackagesADSBOnlySession(testCase)
            bashPath = localAssumeBashAvailable(testCase);

            tempFixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            fakeBin = fullfile(tempFixture.Folder, "fakebin");
            mkdir(fakeBin);

            sshPath = fullfile(fakeBin, "fake_ssh.sh");
            scpPath = fullfile(fakeBin, "fake_scp.sh");
            sshLogPath = fullfile(tempFixture.Folder, "fake_ssh.log");
            scpLogPath = fullfile(tempFixture.Folder, "fake_scp.log");
            localWriteTextFile(sshPath, localFakeSSHScript(sshLogPath));
            localWriteTextFile(scpPath, localFakeSCPScript(scpLogPath));
            localChmodExecutable(testCase, bashPath, [sshPath, scpPath]);

            outputRoot = fullfile(tempFixture.Folder, "campaigns");
            sessionRoot = fullfile(tempFixture.Folder, "captures");
            stageRoot = fullfile(tempFixture.Folder, "adsb_stage");

            arguments = strjoin([ ...
                "--campaign-id fake_campaign", ...
                "--campaign-seconds 1", ...
                "--capture-seconds 1", ...
                "--interval-seconds 1", ...
                "--max-windows 1", ...
                "--pi-host fake-pi", ...
                "--pi-user fakeuser", ...
                "--pi-workdir /remote/work", ...
                "--receiver-origin-lla 1,2,3", ...
                "--remote-wait-timeout 2", ...
                "--fetch-poll 1", ...
                "--ssh-bin " + localQuoteForCommandPath(sshPath), ...
                "--scp-bin " + localQuoteForCommandPath(scpPath), ...
                "--output-root " + localQuoteForCommandPath(outputRoot), ...
                "--session-root " + localQuoteForCommandPath(sessionRoot), ...
                "--adsb-stage-dir " + localQuoteForCommandPath(stageRoot)], " ");
            command = localBashCommand(bashPath, testCase.ScriptPath, arguments);
            [status, output] = system(command);

            testCase.verifyEqual(status, 0, output);

            sessionInfo = dir(fullfile(sessionRoot, "fake_campaign_w*"));
            sessionInfo = sessionInfo([sessionInfo.isdir]);
            testCase.assertNumElements(sessionInfo, 1);

            sessionFolder = fullfile(sessionInfo(1).folder, sessionInfo(1).name);
            manifestPath = fullfile(sessionFolder, "session_manifest.json");
            manifest = jsondecode(fileread(manifestPath));
            adsbFiles = localJsonStringArray(manifest.adsb_files);
            logFiles = localJsonStringArray(manifest.log_files);

            testCase.verifyEqual(string(manifest.capture_type), "adsb_only_holdout");
            testCase.verifyEqual(string(manifest.campaign_id), "fake_campaign");
            testCase.verifyEqual(string(manifest.window_id), "w001");
            testCase.verifyEqual(string(manifest.pi_host), "fake-pi");
            testCase.verifyEqual(string(manifest.pi_user), "fakeuser");
            testCase.verifyEqual(manifest.receiver_origin_lla(:).', [1 2 3]);
            testCase.verifyTrue(isempty(manifest.radar_files));
            testCase.verifyGreaterThanOrEqual(numel(adsbFiles), 1);
            testCase.verifyGreaterThanOrEqual(numel(logFiles), 2);
            testCase.verifyEqual(exist(fullfile(sessionFolder, adsbFiles(1)), "file"), 2);
            testCase.verifyEqual(exist(fullfile(sessionFolder, "logs"), "dir"), 7);
            testCase.verifyEqual(exist(fullfile(outputRoot, "fake_campaign", "campaign_status.tsv"), "file"), 2);

            coordinatorLogInfo = dir(fullfile(sessionFolder, "logs", "stage4B_*_coordinator.log"));
            testCase.assertNumElements(coordinatorLogInfo, 1);
            coordinatorLogText = string(fileread(fullfile( ...
                coordinatorLogInfo(1).folder, ...
                coordinatorLogInfo(1).name)));
            scpLogText = string(fileread(scpLogPath));
            localVerifyContains(testCase, coordinatorLogText, "sudo -n bash 'start_adsb_gps_loggers.sh'");
            localVerifyContains(testCase, coordinatorLogText, "--adsb-only");
            localVerifyContains(testCase, coordinatorLogText, "--adsb-session-id 'fake_campaign_w001_");
            localVerifyContains(testCase, coordinatorLogText, "--adsb-run-seconds '1'");
            localVerifyContains(testCase, scpLogText, ".txt.gz");
            localVerifyContains(testCase, scpLogText, "stage4B_adsb_capture_fake_campaign_w001_");
        end
    end
end

function localVerifyContains(testCase, textValue, expectedText)
%LOCALVERIFYCONTAINS Compatibility wrapper for older matlab.unittest releases.

testCase.verifyTrue(contains(string(textValue), expectedText), ...
    "Expected output to contain: " + expectedText);

end

function bashPath = localAssumeBashAvailable(testCase)
%LOCALASSUMEBASHAVAILABLE Skip shell execution checks when bash is absent.

bashPath = localFindBashExecutable();
testCase.assumeTrue(strlength(bashPath) > 0, ...
    "bash is not available on this host; skipping shell script execution checks.");

end

function bashPath = localFindBashExecutable()
%LOCALFINDBASHEXECUTABLE Find bash on PATH or common Windows Git locations.

bashPath = "";
candidates = [ ...
    "bash", ...
    "C:\Program Files\Git\bin\bash.exe", ...
    "C:\Program Files\Git\usr\bin\bash.exe"];

for candidateIdx = 1:numel(candidates)
    candidate = candidates(candidateIdx);

    if candidate == "bash"
        command = "bash --version";
    else
        if exist(candidate, "file") ~= 2
            continue
        end
        command = localQuoteForCommandPath(candidate) + " --version";
    end

    [status, ~] = system(command);
    if status == 0
        bashPath = candidate;
        return
    end
end

end

function command = localBashCommand(bashPath, scriptPath, arguments)
%LOCALBASHCOMMAND Build a command that invokes the script through bash.

command = localQuoteForCommandPath(bashPath) + " " + localQuoteForCommandPath(scriptPath);
arguments = string(arguments);

if strlength(arguments) > 0
    command = command + " " + arguments;
end

end

function quotedPath = localQuoteForCommandPath(pathValue)
%LOCALQUOTEFORCOMMANDPATH Quote paths for the host shell and bash.

pathValue = replace(string(pathValue), "\", "/");
quotedPath = string(char(34)) + pathValue + string(char(34));

end

function bashPath = localPathForBash(pathValue)
%LOCALPATHFORBASH Normalize a MATLAB path for Git Bash generated scripts.

bashPath = replace(string(pathValue), "\", "/");

end

function quotedValue = localSingleQuoteForBash(pathValue)
%LOCALSINGLEQUOTEFORBASH Quote a literal for generated Bash source.

quotedValue = "'" + replace(localPathForBash(pathValue), "'", "'""'""'") + "'";

end

function localWriteTextFile(pathValue, textValue)
%LOCALWRITETEXTFILE Write a generated test helper script.

fileID = fopen(pathValue, "w");
cleanup = onCleanup(@() fclose(fileID));
assert(fileID > 0, "Could not open helper script for writing.");
fprintf(fileID, "%s", textValue);

end

function localChmodExecutable(testCase, bashPath, pathValues)
%LOCALCHMODEXECUTABLE Mark generated helper scripts executable for Bash.

chmodArgs = strings(1, numel(pathValues));
for pathIdx = 1:numel(pathValues)
    chmodArgs(pathIdx) = localSingleQuoteForBash(pathValues(pathIdx));
end

commandText = "chmod +x " + strjoin(chmodArgs, " ");
command = localQuoteForCommandPath(bashPath) + " -lc " + localQuoteForCommandPath(commandText);
[status, output] = system(command);
testCase.assertEqual(status, 0, output);

end

function scriptText = localFakeSSHScript(logPath)
%LOCALFAKESSHSCRIPT Build a fake ssh executable for shell-level tests.

logLiteral = localSingleQuoteForBash(logPath);
lines = { ...
    '#!/usr/bin/env bash'; ...
    'set -u'; ...
    ['log_path=' char(logLiteral)]; ...
    'cmd="${@: -1}"'; ...
    'printf ''%s\n'' "$cmd" >> "$log_path"'; ...
    'if [[ "$cmd" == *WRAPPER_READY* ]]; then printf WRAPPER_READY; exit 0; fi'; ...
    'if [[ "$cmd" == *ADSB_COMMANDS_READY* ]]; then printf ADSB_COMMANDS_READY; exit 0; fi'; ...
    'if [[ "$cmd" == *SUDO_READY* ]]; then printf SUDO_READY; exit 0; fi'; ...
    'if [[ "$cmd" == *session_glob=* ]]; then'; ...
    '    session="$(printf ''%s'' "$cmd" | sed -n "s/.*adsb_\([^*'']*\).*\.txt\.gz.*/\1/p" | head -n 1)"'; ...
    '    [[ -n "$session" ]] || session=unknown_session'; ...
    '    printf ''/remote/work/0_fake_adsb_%s.txt.gz\n'' "$session"'; ...
    '    exit 0'; ...
    'fi'; ...
    'if [[ "$cmd" == *pgrep* ]]; then printf STOPPED; exit 0; fi'; ...
    'if [[ "$cmd" == *STARTED* ]]; then printf STARTED; exit 0; fi'; ...
    'printf OK'};
scriptText = strjoin(string(lines), newline);

end

function scriptText = localFakeSCPScript(logPath)
%LOCALFAKESCPSCRIPT Build a fake scp executable for shell-level tests.

logLiteral = localSingleQuoteForBash(logPath);
lines = { ...
    '#!/usr/bin/env bash'; ...
    'set -u'; ...
    ['log_path=' char(logLiteral)]; ...
    'src="${@: -2:1}"'; ...
    'dest="${@: -1}"'; ...
    'remote_path="${src#*:}"'; ...
    'base="$(basename "$remote_path")"'; ...
    'mkdir -p "$dest"'; ...
    'printf ''%s\n'' "$src" >> "$log_path"'; ...
    'if [[ "$base" == *.txt.gz ]]; then'; ...
    '    printf ''MSG,3,1,1,ABC123,1,2026/08/18,16:00:00.000,2026/08/18,16:00:00.000,,10000,,,42.0,-71.0,,,0,,0,0\n'' > "$dest/$base"'; ...
    'else'; ...
    '    printf ''remote log for %s\n'' "$remote_path" > "$dest/$base"'; ...
    'fi'};
scriptText = strjoin(string(lines), newline);

end
function values = localJsonStringArray(value)
%LOCALJSONSTRINGARRAY Normalize jsondecode string arrays across releases.

if iscell(value)
    values = string(value(:));
elseif ischar(value) || isstring(value)
    values = string(value(:));
else
    values = strings(0, 1);
end

end
