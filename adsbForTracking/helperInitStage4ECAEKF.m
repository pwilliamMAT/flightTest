function filter = helperInitStage4ECAEKF(detection)
%HELPERINITSTAGE4ECAEKF Initialize the Stage 4E CA EKF for native tuning.

filter = helperInitializeStage4EFilter(detection, "ca_ekf");

end
