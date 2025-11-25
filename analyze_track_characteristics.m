%% Analyze track characteristics.m
%  Updated 2025-09-29 Zachary Pranske
%
%  This code takes as input the folder containing aggregated Imaris output
%  table csvs from simple_imaris_crawler.m. It automatically does basic 
%  analysis including compiling surface and track data; filtering tracks by 
%  time criteria; filtering surfaces by track characteristics; aggregating,
%  normalizing, and plotting data; and running mixed model analysis to
%  check for variable interactions. The goal is for this pipeline to be an
%  all-in-one analysis suite for time series data from Imaris (although
%  currently some more complicated analyses such as colocalization event 
%  detection are run as separate scripts).

global basefolder marker sample_rate n_frames first_time_window last_time_window window_open_time window_close_time bin_size_mins;

%% Base parameters for all files in the data set
basefolder = "C:\Users\zpranske\Desktop\Datasets\2024-10-08 registered gad65 tracking redo\surface tracking output";
marker = "scene";
n_frames = 240;               % Total number of frames
sample_rate = 4;              % Frames per minute
bin_size_mins = 5;            % Bin size for binned analysis (in minutes, usually 5 or 10)
first_time_window = [0,3] ;   % Puncta to be analyzed appear between 0-3 minutes of start
last_time_window = [57,60];   % Puncta to be analyzed are tracked until between 57-60 minutes of start
window_open_time = 0;         % Start time for actual parameter measurements (in minutes)
window_close_time = 60;       % End time for actual parameter measurements (in minutes)

%% Choose input and output variables to analyze
outputvariable = 'Euclidean_Distance';
shortest_dist_string = "Shortest_Distance_to_Surfaces_Surfaces=y2-Halo";
fluor_var_string = "Intensity_Mean_Ch2_Corrected";

% Create master table for tracks and surfaces and add variables of interest
T_tracks = table(); T_surfaces = table();
[T_tracks, T_surfaces] = addToTable(T_tracks, T_surfaces, "Position_X", '@mean', 'Unique_TrackID');
[T_tracks, T_surfaces] = addToTable(T_tracks, T_surfaces, "Position_Y", '@mean', 'Unique_TrackID');
[T_tracks, T_surfaces] = addToTable(T_tracks, T_surfaces, shortest_dist_string, '@mean', 'Unique_TrackID');
[T_tracks, T_surfaces] = addToTable(T_tracks, T_surfaces, fluor_var_string, '@mean', 'Unique_TrackID');
[T_tracks, T_surfaces] = addToTable(T_tracks, T_surfaces, "Intensity_Mean_Ch=1_Img=1", '@mean', 'Unique_TrackID');
[T_tracks, T_surfaces] = addToTable(T_tracks, T_surfaces, "Area", '@mean', 'Unique_TrackID');
[T_tracks, T_surfaces] = addToTable(T_tracks, T_surfaces, "Displacement_Length", '@mean', 'Unique_TrackID');
[T_tracks, T_surfaces] = addToTable(T_tracks, T_surfaces, "Displacement_Delta_Length", '@mean', 'Unique_TrackID');
[T_tracks, T_surfaces] = addToTable(T_tracks, T_surfaces, "Speed", '@mean', 'Unique_TrackID');
[T_tracks, T_surfaces] = addToTable(T_tracks, T_surfaces, "Acceleration", '@mean', 'Unique_TrackID');
[T_tracks, T_surfaces] = addToTable(T_tracks, T_surfaces, "Track_Ar1_Mean", '@mean', 'Unique_ID');
[T_tracks, T_surfaces] = addToTable(T_tracks, T_surfaces, "Track_Straightness", '@mean', 'Unique_ID');
outputvariable = matlab.lang.makeValidName(outputvariable);
shortest_distance_var = matlab.lang.makeValidName(shortest_dist_string);
fluor_var = matlab.lang.makeValidName(fluor_var_string);

%% Calculate Euclidean distance from the starting point for each Unique_TrackID
T_surfaces.Euclidean_Distance = zeros(height(T_surfaces), 1);
startPosition_X = zeros(height(T_surfaces), 1);
startPosition_Y = zeros(height(T_surfaces), 1);

% Identify unique track IDs and their starting positions
uniqueTrackIDs = unique(T_surfaces.Unique_TrackID);
for j = 1:length(uniqueTrackIDs)
    currentTrackID = uniqueTrackIDs(j);
    trackIndices = strcmp(T_surfaces.Unique_TrackID, currentTrackID);
    
    % Store the starting position for the current Unique_TrackID
    startPosition_X(trackIndices) = T_surfaces(T_surfaces.Unique_TrackID==string(currentTrackID),"Position_X").Position_X(1);
    startPosition_Y(trackIndices) = T_surfaces(T_surfaces.Unique_TrackID==string(currentTrackID),"Position_Y").Position_Y(1);
end

T_surfaces.Euclidean_Distance = sqrt((T_surfaces.Position_X - startPosition_X).^2 + ...
                                      (T_surfaces.Position_Y - startPosition_Y).^2);

%% Make binned time table for repeated measures ANOVA or mixed effect model analysis
T_surfaces.TimeBin = discretize(T_surfaces.Time, (window_close_time-window_open_time)/bin_size_mins);  % n minute bins
T_bins = varfun(@mean, T_surfaces, ...
    'InputVariables', outputvariable, ...
    'GroupingVariables', {'File', 'Unique_TrackID', 'Treatment', 'TimeBin'});

%% Calculate custom track stats (that are not built-in Imaris outputs)
%  Adjust as needed based on the analysis you're doing

for i = 1:height(T_tracks)
    uniqueTrackID = T_tracks.Unique_TrackID(i);
    matchingRows = T_surfaces(strcmp(T_surfaces.Unique_TrackID, uniqueTrackID), :);
    if ~isempty(matchingRows)
        T_tracks.Start_Time(i) = matchingRows.Time(1);
        T_tracks.End_Time(i) = matchingRows.Time(end);
        T_tracks.Duration(i) =  T_tracks.End_Time(i) - T_tracks.Start_Time(i) + 1;
        T_tracks.Initial_Dist(i) = matchingRows.(shortest_distance_var)(1);
        T_tracks.Min_Dist(i) = min(matchingRows.(shortest_distance_var));
        T_tracks.Begins_Coloc(i) = any(matchingRows.(shortest_distance_var)(1:3*sample_rate) < 0.05);
        T_tracks.Ends_Coloc(i) = any(matchingRows.(shortest_distance_var)(height(matchingRows)-(3*sample_rate):height(matchingRows)) < 0.05);
        T_tracks.F_0(i) = mean(matchingRows(matchingRows.Time <= matchingRows.Time(1)+3*sample_rate,:).(fluor_var)); %Mean of first 3 mins
        T_tracks.F_end(i) = mean(matchingRows(matchingRows.Time >= matchingRows.Time(end)-3*sample_rate,:).(fluor_var)); %Mean of last 3 mins
        T_tracks.F_max(i) = max(matchingRows.(fluor_var));
        T_tracks.F_max_time(i) = find(matchingRows.(fluor_var) == max(matchingRows.(fluor_var)), 1);
        T_tracks.isMaintained(i) = sum(matchingRows.(fluor_var) >= 0.8*T_tracks.F_max(i))>=20; %Check if >=40 frames after max intensity timepoint still have >= 80% max fluorescence
        T_tracks.dF_Corrected(i) = T_tracks.F_0(i) - T_tracks.F_end(i);
        T_tracks.dF_FoldChange(i) = T_tracks.F_end(i)/T_tracks.F_0(i);
        T_tracks.dF_max_FoldChange(i) = T_tracks.F_max(i)/T_tracks.F_0(i);
        T_tracks.Net_Disp(i) = matchingRows.Displacement_Length(end);
        T_tracks.Max_Velocity(i) = max(matchingRows.Speed);
        T_tracks.Min_Velocity(i) = min(matchingRows.Speed);
        T_tracks.Euclidean_Distance(i) = matchingRows.Euclidean_Distance(end);
        T_tracks.TdT(i) = sum(matchingRows.Displacement_Delta_Length);
        T_tracks.Window_Disp(i) = sqrt((matchingRows.Position_X(end)-matchingRows.Position_X(1))^2 + (matchingRows.Position_Y(end)-matchingRows.Position_Y(1))^2);
    end
end

%% Filter tracks by variables of interest
%  Example here: filter the top 5% of tracks by mean speed per condition

T_tracks_0 = T_tracks(T_tracks.Treatment==0,:);
T_tracks_1 = T_tracks(T_tracks.Treatment==1,:);
cutoff_0 = prctile(T_tracks_0.("mean Speed"), 95);
cutoff_1 = prctile(T_tracks_1.("mean Speed"), 95);
filteredTracks = T_tracks((T_tracks.Treatment==0 & T_tracks.("mean Speed") >= cutoff_0) | ...
                           (T_tracks.Treatment==1 & T_tracks.("mean Speed") >= cutoff_1), "Unique_TrackID");
T_tracks.isFiltered = ismember(T_tracks.Unique_TrackID, filteredTracks.Unique_TrackID);

subT_tracks_filtered = T_tracks(ismember(T_tracks.Unique_TrackID,filteredTracks.Unique_TrackID),:);
subT_surfaces_filtered = T_surfaces(ismember(T_surfaces.Unique_TrackID,filteredTracks.Unique_TrackID),:);
subT_bins_filtered = T_bins(ismember(T_bins.Unique_TrackID,filteredTracks.Unique_TrackID),:);

subT_tracks_others = T_tracks(~ismember(T_tracks.Unique_TrackID,filteredTracks.Unique_TrackID),:);
subT_surfaces_others = T_surfaces(~ismember(T_surfaces.Unique_TrackID,filteredTracks.Unique_TrackID),:);

summaryByCondition_filtered = varfun(@(x) [mean(x) std(x)], subT_surfaces_filtered, ...
    'InputVariables', outputvariable, ...
    'GroupingVariables', {'Treatment','Time'});
summaryByCondition_all = varfun(@(x) [mean(x) std(x)], T_surfaces, ...
    'InputVariables', outputvariable, ...
    'GroupingVariables', {'Treatment','Time'});
summaryByCondition_bins = varfun(@(x) [mean(x) std(x)], T_bins, ...
    'InputVariables', ['mean_' outputvariable], ...
    'GroupingVariables', {'Treatment','TimeBin'});
summaryByCondition_bins_filtered = varfun(@(x) [mean(x) std(x)], subT_bins_filtered, ...
    'InputVariables', ['mean_' outputvariable], ...
    'GroupingVariables', {'Treatment','TimeBin'});
summaryByCondition_filtered_norm = normalizeToBaseline(summaryByCondition_filtered);
summaryByCondition_all_norm = normalizeToBaseline(summaryByCondition_all);
%summaryByCondition_bins_norm = normalizeToBaseline(summaryByCondition_bins);
%summaryByCondition_bins_filtered_norm = normalizeToBaseline(summaryByCondition_bins_filtered);

inputVarByID = [];
if ismember(['mean ' outputvariable], T_tracks.Properties.VariableNames)
    inputVarByID = string(['mean ' outputvariable]);
elseif ismember(['mean_' outputvariable], T_tracks.Properties.VariableNames)
    inputVarByID = string(['mean_' outputvariable]);
elseif ismember(outputvariable, T_tracks.Properties.VariableNames)
    inputVarByID = string(outputvariable);
else
    disp("Unable to find output variable name for summaryByID table")
end

summaryByID_filtered = varfun(@(x) [mean(x)], subT_tracks_filtered, ...
    'InputVariables', inputVarByID, ...
    'GroupingVariables', {'Treatment','Unique_TrackID'});
summaryByID_all = varfun(@(x) [mean(x)], T_tracks, ...
    'InputVariables', inputVarByID, ...
    'GroupingVariables', {'Treatment','Unique_TrackID'});
% summaryByID_bins = varfun(@(x) [mean(x)], T_bins, ...
%     'InputVariables', inputVarByID, ...
%     'GroupingVariables', {'Treatment','Unique_TrackID'});

%% Plot and analyze outcome variable
F=figure(); hold on; 
treatmentList = unique(T_surfaces.Treatment);
for i = 1:length(treatmentList)
    plotFilteredTable(summaryByCondition_bins, treatmentList(i),'bins'); %Third argument is 'bins' or 'all'
end
hold off;

writetable(T_surfaces, basefolder + filesep + marker + " T_surfaces.csv");
writetable(T_tracks, basefolder + filesep + marker + " T_tracks.csv");

% Run mixed model analysis
T_bins.Treatment = categorical(T_bins.Treatment);
T_bins.File = categorical(T_bins.File);
T_bins.Unique_TrackID = categorical(string(T_bins.Unique_TrackID));

% Fit linear mixed-effects model and display the results
 lme = fitlme(T_bins, ...
     ['mean_' outputvariable ' ~ Treatment * TimeBin + (1|File)']);
 disp(lme);

stats = groupedBarChart('Initial_Dist',subT_tracks_filtered,subT_tracks_others,T_tracks);
