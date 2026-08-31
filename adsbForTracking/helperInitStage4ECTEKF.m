function filter = helperInitStage4ECTEKF(detection)
%HELPERINITSTAGE4ECTEKF Initialize the Stage 4E CT EKF for native tuning.

filter = helperInitializeStage4EFilter(detection, "ct_ekf");

end
