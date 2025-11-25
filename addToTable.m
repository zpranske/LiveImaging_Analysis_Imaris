%% function addToTable.m
%  Updated 2025-09-29 Zachary Pranske
%
%  Reads raw Imaris output for a particular measure, performs pre-processing, 
%  and adds it to the table. Takes as input an existing T_tracks table 
%  (from the main script), an existing T_surfaces table, the measure to add
%  (e.g. "Area"), the grouping function (e.g. "@mean"), and the grouping 
%  variable ("Unique_Track_ID" for a surface measure, or "Unique_ID" for a 
%  track measure). Outputs a modified T_tracks and T_surfaces table with 
%  the new variable added. Do not try to run this file directly: use the 
%  main script analyze_track_characteristics.m to call these functions.

function [T_tracks, T_surfaces] = addToTable(T_tracks, T_surfaces, measure, func, groupingVariable)
    global basefolder marker sample_rate first_time_window last_time_window window_open_time window_close_time;
    CSVfolder = fullfile(basefolder, '_combined analysis');
    mainVarPath = CSVfolder + filesep + marker + " " + measure + ".csv";

    % Check for file containing first and last time a surface was found for
    % each track. If none found, create new FirstTime_LastTime.csv file
    % This will be used to filter the tracks as specified above
    if(~exist(CSVfolder + filesep + marker + " Track FirstTime_LastTime.csv", "file"))
        disp("No first and last time table found. Generating now...")
        getFirstTimeLastTime(CSVfolder, marker);
    end
    first_last_path = CSVfolder + filesep + marker + " Track FirstTime_LastTime.csv";
    opts = detectImportOptions(first_last_path, 'NumHeaderLines', 0);
    first_last_table = readtable(first_last_path, opts);
    %disp("Read first and last time table from " + first_last_path)

    % Read in the main table (.csv from simple_imaris_crawler.m) for the 
    % variable to be added and check if the stats are for tracks or surfaces
    opts = detectImportOptions(mainVarPath, 'NumHeaderLines', 0);
    T_variable=readtable(mainVarPath,opts);
    variablename = T_variable.Properties.VariableNames{2};
    if ismember('Track', T_variable.Category) % Check if Unique_TrackID is a column header, which means the inputs are surfaces
        type = "tracks"; else type = "surfaces";
    end

    % Filter whole tracks based on whether their start and end times fit in
    % the criteria above as well as anything else you want to filter them
    % by (e.g. remove any that are from a particular file)
    filteredIDs = first_last_table.Unique_TrackID(...
          first_last_table.FirstTime >= (first_time_window(1)*sample_rate)...
        & first_last_table.FirstTime <= (first_time_window(2)*sample_rate)...
        & first_last_table.LastTime  >= (last_time_window(1)*sample_rate) ...
        & first_last_table.LastTime  <= (last_time_window(2)*sample_rate) ...
        & ~contains(first_last_table.Unique_TrackID, 'fZP_0730_Dish5_Fc2nM_GFP-GAD65_Geph-JF646_63x_7z_15s_unwarped'));

    % Now filter the rows of surfaces that will be included in the table 
    % to be analyzed, based on whether they fit into the specified time 
    % window (note that this is different from the track-level filtering 
    % above. You might want to take a track present from 0-60' but only 
    % look at the surfaces in the first 30', for example).
    switch type
        case "surfaces"
            filteredRows = (ismember(T_variable.('Unique_TrackID'), filteredIDs) ...
                & T_variable.Time >= window_open_time*sample_rate ...
                & T_variable.Time <= window_close_time*sample_rate);
        case "tracks"
            filteredRows = ismember(T_variable.('Unique_ID'), filteredIDs);
    end

    % Filter input table to only include the filtered surface rows (which
    % should only contain rows in the correct time window and with the
    % Unique TrackIDs from filteredIDs
    T_variable=T_variable(filteredRows,:);

    % Run the function specified in the input argument (@mean, etc.) after
    % grouping by track ID
    summaryByID = varfun(str2func(func), T_variable, ...
        'InputVariables', variablename, 'GroupingVariables', groupingVariable);
    summaryByID.Properties.VariableNames{'GroupCount'} = 'nSurfaces';
    renamedvariablename = char(matlab.lang.makeValidName(measure));
    T_variable.Properties.VariableNames{2} = renamedvariablename;
    switch type
        case "tracks"
            summaryByID.Properties.VariableNames{3} = renamedvariablename;
        case "surfaces"
            summaryByID.Properties.VariableNames{3} = [func(2:end) ' ' renamedvariablename];
    end
    
    % Add variable to T_Tracks and T_Surfaces
    % Check if T already has nSurfaces added (meaning it's not the first
    % time through the loop)
    addedvariablesuccessfully = false;
    if isempty(T_tracks) || isempty(T_surfaces)
        switch type
            case "tracks"
                if isempty(T_tracks)
                    T_tracks = summaryByID;
                    % Search Unique_ID column to look for the treatment condition 
                    % based on the filename which is contained within the Unique_ID
                    T_tracks.Treatment = ~contains(T_tracks.Unique_ID, 'Fc'); % Assign 0 for 'Fc', 1 otherwise
                    T_tracks = movevars(T_tracks, 'Treatment', 'After', 'Unique_ID');
                end
            case "surfaces"
                if isempty(T_surfaces)
                    T_surfaces = T_variable(:,{'File', 'Unique_TrackID', 'Time', renamedvariablename}); 
                    T_surfaces.Treatment = contains(T_surfaces.Unique_TrackID, 'Fc');
                    T_surfaces.Treatment = double(~T_surfaces.Treatment);
                    T_surfaces = movevars(T_surfaces, 'Treatment', 'After', 'Unique_TrackID');  
                end
                if isempty(T_tracks)
                    T_tracks = summaryByID;
                    % Search Unique_ID column to look for the treatment condition 
                    % based on the filename which is contained within the Unique_ID
                    T_tracks.Treatment = contains(T_tracks.Unique_TrackID, 'Fc');
                    T_tracks.Treatment = double(~T_tracks.Treatment); % Assign 0 for 'Fc', 1 otherwise
                    T_tracks = movevars(T_tracks, 'Treatment', 'After', 'Unique_TrackID');
                end   
        end
        addedvariablesuccessfully = true;
    else
        switch type
             case "tracks"
                % Ensure the height of T and summaryByID are the same
                if height(T_tracks) == height(summaryByID)
                    T_tracks.(renamedvariablename) = summaryByID.(renamedvariablename);
                    addedvariablesuccessfully = true;
                else
                    error('The heights of the table to be appended and the existing T_tracks and T_surfaces tables do not match. Cannot append data.');
                end
            case "surfaces"
                % Ensure the height of T and summaryByID are the same
                if height(T_tracks) == height(summaryByID) && height(T_surfaces) == height(T_variable) 
                    T_tracks.([func(2:end) ' ' renamedvariablename]) = summaryByID.([func(2:end) ' ' renamedvariablename]);
                    T_surfaces.(renamedvariablename) = T_variable.(renamedvariablename);
                    addedvariablesuccessfully = true;
                else
                    error('The heights of the table to be appended and the existing T_tracks and T_surfaces tables do not match. Cannot append data.');
                end
        end
    end
    if addedvariablesuccessfully
        disp(strjoin(["Added ", measure, " (", window_open_time, "-", window_close_time, ...
        " min., present ", first_time_window(1), ":", first_time_window(2),  " - ", ...
        last_time_window(1), ":", last_time_window(2), " min.)"],""))
    end
end