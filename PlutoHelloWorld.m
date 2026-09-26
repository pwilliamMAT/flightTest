% Create radio rx object
rx = sdrrx('Pluto');

% Disp internal dev config
info(rx)

% Capture small buffer
data = rx();
disp("Successfully received" +length(data) + " samples.")

% releas hw
release(rx);
