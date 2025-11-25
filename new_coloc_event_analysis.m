%% New coloc event analysis.m
%  Updated 2025-09-29 Zachary Pranske
%
%  Analyzes new colocalization events by identifying when previously non-
%  colocalized puncta become colocalized and calculates statistics for the
%  time windows before and after the new colocalization events. Takes as 
%  input the table T_surfaces that is automatically exported and 
%  saved after running analyze_track_characteristics.m (will NOT work 
%  unless you run that script first).

basefolder = "C:\Users\zpranske\Desktop\Datasets\2025-07-14 registered y2 (punctate) geph tracking\surface tracking output";
marker = "gfp-geph";
othermarker = "y2-halo";
before_after_var = "Euclidean_Distance"; %Variable you want to look at before/after new coloc events
shortest_distance_var = "Shortest_Distance_to_Surfaces_Surfaces_y2_Halo"; %Variable you want to look at before/after new coloc events
other_shortest_distance_var = "Shortest_Distance_to_Surfaces_Surfaces_GFP_Geph"; %Variable you want to look at before/after new coloc events
preexisting = 'both'; % Only consider events where the other marker newly appeared ('no'),
                      % was pre-existing ('yes') or both ('both')

% Read in tables. Uses the full table of the other marker (in case puncta that we are
% colocalizing with are not persistently tracked -- quite common). If this
% table does not exist, go to analyze_track_characteristics, change your
% start and end points to include all tracks, and write the full tables
% (don't forget to change the part where it writes tables to file).
T=readtable(basefolder + filesep + marker + " T_surfaces.csv",'Delimiter',',');
T_other=readtable(basefolder + filesep + othermarker + " T_surfaces_full.csv",'Delimiter',',');

window = 240;    % How many frames to measure before and after new coloc event
min_sustain_frames = 40;  % how long it must stay colocalized to be considered "real" 
n_frames = 240; % Total number of frames in an image

colocEvents = table();
trackIDs = unique(T.Unique_TrackID);

for i = 1:length(trackIDs)
    trackID = trackIDs{i};
    T_track = T(strcmp(T.Unique_TrackID, trackID), :);
    T_track = sortrows(T_track, 'Time');

    times = T_track.Time;
    distance = T_track.(shortest_distance_var);

    % Previous distance
    dist_prev = [NaN; distance(1:end-1)];

    % Initial candidates: where >0 → 0
    new_coloc_idx = find(dist_prev > 0 & distance <= 0);
    new_coloc_times = T_track.Time(new_coloc_idx,:);

    for j = 1:length(new_coloc_times)
        timepoint = new_coloc_times(j); % Row number corresponding to frame of putative new coloc event
        
        % Check that next N frames stay at zero (or at least n% of them do)
        sustain_end_idx = timepoint + min_sustain_frames - 1;
        windowrows = T_track(T_track.Time > timepoint & T_track.Time <= sustain_end_idx,:);
        n_rows_coloc = sum(table2array(T_track(T_track.Time > timepoint & T_track.Time <= sustain_end_idx, shortest_distance_var))<=0);
        sustained = n_rows_coloc / height(windowrows) >= .95;
         
        % Find sustained coloc events that occur not too close to end of video
        if  sustained & timepoint >= 3 & timepoint <= (n_frames - min_sustain_frames) 
            before_times = timepoint - window : timepoint - 1;
            after_times  = timepoint + 1 : timepoint + window;

            before_rows = ismember(T_track.Time, before_times);
            coloc_row   = ismember(T_track.Time, timepoint);
            after_rows  = ismember(T_track.Time, after_times);

            var_before = mean(T_track.(before_after_var)(before_rows), 'omitnan');
            var_after  = mean(T_track.(before_after_var)(after_rows), 'omitnan');

            % Find first nonzero values for position (first time point
            % within the window prior to coloc in which the particle was
            % tracked)
            pos_coloc_x = T_track.Position_X(coloc_row);
            pos_coloc_y = T_track.Position_Y(coloc_row);  
            pos_orig_x = T_track(before_rows,:).Position_X(find(T_track.Position_X(before_rows), 1, 'first'));
            pos_orig_y = T_track(before_rows,:).Position_Y(find(T_track.Position_Y(before_rows), 1, 'first')); 
            before_positions_rel = struct('X', [], 'Y', []);
            before_positions_abs.X = T_track.Position_X(before_rows);
            before_positions_abs.Y = T_track.Position_Y(before_rows);
            before_positions_rel.X = T_track.Position_X(before_rows)-pos_coloc_x;
            before_positions_rel.Y = T_track.Position_Y(before_rows)-pos_coloc_y;
            after_positions_rel = struct('X', [], 'Y', []);
            after_positions_abs.X = T_track.Position_X(after_rows);
            after_positions_abs.Y = T_track.Position_Y(after_rows);
            after_positions_rel.X = T_track.Position_X(after_rows)-pos_coloc_x;
            after_positions_rel.Y = T_track.Position_Y(after_rows)-pos_coloc_y;
            
            % Filter T_other_coloctime to include only rows in which T_other_coloctime.Position_X is within 1 of pos_coloc_x
            T_other_coloctime = T_other(T_other.Time==timepoint,:);
            T_other_coloctime = T_other_coloctime(abs(T_other_coloctime.Position_X - pos_coloc_x) <= 1, :);
            T_other_coloctime = T_other_coloctime(abs(T_other_coloctime.Position_Y - pos_coloc_y) <= 1, :);
            T_other_coloctime = T_other_coloctime(T_other_coloctime.(other_shortest_distance_var)<=0,:);
            if(height(T_other_coloctime)>0)
                other_marker_coloc = T_other_coloctime.Unique_TrackID(1);
                T_other_track = T_other(strcmp(T_other.Unique_TrackID,other_marker_coloc),:);
                other_track_times = T_other_track.Time;
                other_track_originate_time = min(other_track_times);
                if (other_track_originate_time < timepoint-10)
                    other_marker_preexisting = 1;
                else
                    other_marker_preexisting = 0;
                end
            else
                other_marker_coloc = "";
                other_marker_preexisting = 0;
            end
                    
            % Calculate Cartesian distance traveled between the two timepoints
            euc_distance_coloc = T_track.Euclidean_Distance(coloc_row);
            netdist_traveled = sqrt((pos_coloc_x - pos_orig_x)^2 + (pos_coloc_y - pos_orig_y)^2);
            avg_dist = mean(sqrt((pos_coloc_x - before_positions_abs.X).^2 + (pos_coloc_y - before_positions_abs.Y).^2));
            totaldist_traveled = sum(T_track.Displacement_Delta_Length);

            treatment = unique(T_track.Treatment);

            newRow = table({trackID}, treatment, timepoint, other_marker_coloc, other_marker_preexisting, var_before, var_after, ...
                 before_positions_rel, after_positions_rel, pos_orig_x - pos_coloc_x, pos_orig_y - pos_coloc_y, netdist_traveled, avg_dist, totaldist_traveled, euc_distance_coloc, ...
                'VariableNames', {'Unique_TrackID', 'Treatment', 'Coloc_Timepoint', 'Coloc_Puncta_ID', 'Coloc_Puncta_Preexisting' ...
                char(before_after_var + '_Before'), char(before_after_var + '_After'), ...
                'Before_Pos', 'After_Pos', 'Delta_X', 'Delta_Y', 'Net_Distance_Traveled_Window', 'Avg_Dist', 'Total_Distance_Traveled', 'Euclidean_Dist_Coloc'});

            colocEvents = [colocEvents; newRow];
        end
    end
end

% If a track has multiple new coloc events entries, keep only the first occurrence
% (This will mostly only happen if you set a threshold of less than 100% of
% frames to remain colocalized in the 10 min. window, as it will call it a new coloc
% event when the other puncta "reappears")
[~, unique_idx] = unique(colocEvents.Unique_TrackID, 'first');
colocEvents = colocEvents(unique_idx, :);

switch preexisting
    case 'no'
        colocEvents = colocEvents(colocEvents.Coloc_Puncta_Preexisting==0,:);
    case 'yes'
        colocEvents = colocEvents(colocEvents.Coloc_Puncta_Preexisting==1,:);
end

writetable(colocEvents, basefolder + filesep + marker + " New coloc events_raw.csv");

%% Create figure with two subplots for each condition
unique_treatments = unique(colocEvents.Treatment);
n_treatments = length(unique_treatments);

figure;
y_limits = []; % Initialize y_limits to store y-axis limits for each treatment
for k = 1:length(unique_treatments)
    treatment = unique_treatments(k);
    subplot(1, n_treatments, k);
    
    % Filter colocEvents for the current treatment
    treatment_data = colocEvents(colocEvents.Treatment==treatment, :);
    
    % Prepare data for stacked plotting
    if k==1
        before_values = beforeafterfc(:,1); %treatment_data.(char(before_after_var + '_Before'));
        after_values = beforeafterfc(:,2); %treatment_data.(char(before_after_var + '_After'));
    else
        before_values = beforeafter4d(:,1); %treatment_data.(char(before_after_var + '_Before'));
        after_values = beforeafter4d(:,2); %treatment_data.(char(before_after_var + '_After'));
    end
    
    % Create x positions for before and after values
    x_before = 1;
    x_after = 2;
    
    % Plot the before and after values as stacked points
    plot(x_before, before_values, 'ko-', 'DisplayName', 'Before', 'LineWidth', 1.25); hold on;
    plot(x_after, after_values, 'ko-', 'DisplayName', 'After', 'LineWidth', 1.25);
    
    % Connect the before and after points
    for m = 1:height(before_values)
        plot([x_before, x_after], [before_values(m), after_values(m)], 'k-', 'LineWidth', 1);
    end
    
    % Calculate and plot mean change
    mean_before = mean(before_values, 'omitnan');
    mean_after = mean(after_values, 'omitnan');
    switch k
        case 1
            plot([x_before, x_after], [mean_before, mean_after], '-', 'LineWidth', 2.5, 'DisplayName', 'Mean Change', 'Color', [85, 160, 251] / 255);
        case 2 
            plot([x_before, x_after], [mean_before, mean_after], '-', 'LineWidth', 2.5, 'DisplayName', 'Mean Change','Color', [255, 160, 64] / 255);
    end
    
    % Customize the plot
    switch k
        case 1
            title('Control', 'FontWeight', 'bold');
        case 2
            title('Sema4D', 'FontWeight', 'bold');
    end
        % Set x-axis labels for before and after values without overriding
    xticks([1 2]); % Set x-ticks for before and after
    xticklabels({'Before', 'After'}); % Set x-tick labels
    ylabel(char(before_after_var), 'FontWeight', 'bold');
    xlim([.5 2.5]);
    ax = gca; % Get current axes
    ax.LineWidth = 2; % Set axis line thickness to 1.5 (slightly thicker than default)
    grid off; box off;
    set(gcf, 'Color', 'w');
    ax = findall(gcf, 'Type', 'Axes'); % Find all axes in the current figure
    for k = 1:length(ax)
        ax(k).FontName = 'Arial';
        ax(k).FontSize = 13;
        ax(k).FontWeight = 'bold';
        ax(k).LineWidth = 1.75;
    end
    %y_limits = [y_limits; ylim]; 
end

% Set the same y-axis limits for all subplots
for k = 1:n_treatments
    subplot(1, n_treatments, k);
    ylim([0; 4]);
end

%% Bar graph plotting Distance Traveled by treatment condition
figure;
outcomevar = 'Euclidean_Dist_Coloc';
bar_data = varfun(@mean, colocEvents, 'InputVariables', outcomevar, ...
    'GroupingVariables', 'Treatment');

% Calculate standard error of the mean (SEM)
sem_data = varfun(@(x) std(x, 'omitnan') / sqrt(sum(~isnan(x))), colocEvents, ...
    'InputVariables', outcomevar, 'GroupingVariables', 'Treatment');

% Create bar plot
bar_handle = bar(bar_data.Treatment, bar_data.(['mean_' outcomevar]), 'FaceColor', [0.2 0.6 0.8]);
hold on;

% Add error bars
errorbar(bar_data.Treatment, bar_data.(['mean_' outcomevar]), sem_data.(['Fun_' outcomevar]), 'k', 'linestyle', 'none', 'LineWidth', 1.5);

xlabel('Treatment Condition');
ylabel(['Mean ' outcomevar]);
title(['Mean ' outcomevar ' by Treatment Condition']);
grid on;

%% Plot before and after locations for each coloc event by treatment
unique_treatments = unique(colocEvents.Treatment);
n_treatments = length(unique_treatments);

figure;
for k = 1:n_treatments
    treatment = unique_treatments(k);
    subplot(1, n_treatments, k);
    hold on;

    % Filter colocEvents for the current treatment
    treatment_data = colocEvents(colocEvents.Treatment == treatment, :);

    for timepoint = 1:height(treatment_data)
        % Plot before and after locations
        plot(0, 0, 'ro', 'MarkerSize', 8, 'DisplayName', 'Before', 'LineWidth', 1);
        plot(mean(treatment_data.Before_Pos(timepoint).X(1:3)), mean(treatment_data.Before_Pos(timepoint).Y(1:3)), 'bo', 'MarkerSize', 8, 'DisplayName', 'After', 'LineWidth', 1);
        before_x = [treatment_data(timepoint,:).Before_Pos.X; 0];
        before_y = [treatment_data(timepoint,:).Before_Pos.Y; 0];

        % Connect points in different rows with a line
        cmap = parula(length(before_x)); % Using parula colormap

        for j = 1:length(before_x)
            if j > 3
                % Plot a line segment with color based on its position in the sequence
                plot([mean(before_x(j-3:j-1)), mean(before_x(j-2:j))], ...
                     [mean(before_y(j-3:j-1)), mean(before_y(j-2:j))], 'Color', cmap(j, :), 'LineWidth', 1.5);
            end
        end
    end

    xlabel('X Position'); 
    ylabel('Y Position');
    xlim([-3 3]); ylim([-3 3]);
    title(['Before and After Locations of Colocalization Events - ' char(string(treatment))]);
    legend('After', 'Before', 'Location', 'Best');
    gca.LineWidth = 2; % Set axis line thickness to 1.5 (slightly thicker than default)
    grid off; box off; legend off;
    set(gcf, 'Color', 'w');
    ax = findall(gcf, 'Type', 'Axes'); % Find all axes in the current figure
    for k = 1:length(ax)
        ax(k).FontName = 'Arial';
        ax(k).FontSize = 13;
        ax(k).FontWeight = 'bold';
        ax(k).LineWidth = 1.75;
    end

    switch k
        case 1
            title('Control', 'FontWeight', 'bold');
        case 2
            title('Sema4D', 'FontWeight', 'bold');
    end
end
