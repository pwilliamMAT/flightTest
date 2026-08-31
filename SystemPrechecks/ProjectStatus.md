# Overview of the System Prechecks Folder

#1. Link Budget
#2. RF Budget

This analysis was done as a pre-hardware sanity check for starting the bistatic data analysis data acquisiton project.
We were attempting to use MathWorks tools to generate a motivation for setting up hardware to localize aircraft using HDTV as the signal of opportunity, and convince ourselves that the available tv signals were sufficient for this task, especially relative to bistatic signal SNR.
The two steps I took in order were
1. Link Budget - analyze the existing HDTV tower signals and evaluate our hypothetical power at our intended receiver location and
2. RF Budget - hypothesize the components needed to achieve true hardware to accomplish this.

# Current Understanding
My current understanding of the hardware that we have actually implemented is that it does not necessarily meet the analysis that we did.

# Overall Goal
My current goal is to evaluate the steps that were taken and build more confidence in the analysis that presented the first go/no-go checks.

# Not Doing:
I am not trying to complicate the analysis or make the analysis specifically match the hardware set up at this stage.

# Outputs
1. My intended output is a refined, cleaner, more defensible version of the two sets of analyses that RF, Radar, and Phased Array experts will appreciate as thoughful prechecks. Hopefully there isn't much adjustment to the analysis needed, but if there is, I want to consider doing it.
2. I want to build PPT slides from what was accomplished so that I can sit in a room full of mixed background, but largely highly technical audience, and explain what prechecks I did, how they motivated the hardware implementation, and potentially why the simple models that we have built here don't fully capture the reality of hardware implementation and issues that arrive in the field.
