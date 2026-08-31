function filter = helperInitStage4ECVEKF(detection)
%HELPERINITSTAGE4ECVEKF Initialize the Stage 4E CV EKF for native tuning.

filter = helperInitializeStage4EFilter(detection, "cv_ekf");

end
