function filter = helperInitStage4EWarmUKF(detection)
%HELPERINITSTAGE4EWARMUKF Initialize the frozen-warm Stage 4E UKF.

filter = helperInitializeStage4EFilter(detection, "warm_ukf");

end
