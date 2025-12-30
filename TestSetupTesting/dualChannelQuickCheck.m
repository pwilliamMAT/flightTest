% Dual Channel Quick Check
% 1. Setup the reader
bbr = comm.BasebandFileReader('/Users/pwillie822/Documents/Mathworks/FlightTest/n320_dual_capture.bb');
bbr.SamplesPerFrame = 10000; % Read a decent chunk at once

% 2. Read the first frame
% 'data' will now be a [10000 x 2] matrix
data = bbr(); 

% 3. Visualize the channels
figure;
subplot(2,1,1);
plot(real(data(:,1))); title('Channel 1 (Surveillance/Yagi) - Real Part');
subplot(2,1,2);
plot(real(data(:,2))); title('Channel 2 (Reference) - Real Part');

% 4. Release the file
release(bbr);