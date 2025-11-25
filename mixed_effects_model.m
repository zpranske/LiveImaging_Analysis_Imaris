%% mixed_effects_model.m
%  Updated 2025-09-29 Zachary Pranske
%  
%  Runs linear mixed effect model analysis for a variable of interest. Must
%  be a time-dependent variable with surface measures (e.g. will work for
%  Speed, but not Track Straightness). Assumes you have already run
%  analyze_track_characteristics.m and a binned time table  already exists
%  (will NOT work unless you run that script first).  

T = T_bins_combined;

% Prepare data for mixed model analysis
T.Treatment = categorical(T.Treatment);
T.File = categorical(T.File);
%T.Unique_CellID = categorical(string(T.Unique_CellID));
outputvariable = 'mean_Euclidean_Distance';

% Fit linear mixed-effects model and display the results
lme = fitlme(T, ...
    [outputvariable ' ~ TimeBin * Existing + (1|File)']);
disp(lme);