%% function groupedBarChart.m
%  Updated 2025-09-29 Zachary Pranske
%
%  Make grouped bar chart for filtered tracks and all other tracks. Takes
%  as input the variable to group by, a sub-table containing the tracks
%  that are filtered, a sub-table containing all other tracks, and the main
%  T_tracks table. Do not try to run this file directly: use the main 
%  script analyze_track_characteristics.m to call these functions.

function [stats] = groupedBarChart(outputvariable,subT_tracks_filtered,subT_tracks_others,T_tracks)

    if ismember(outputvariable, subT_tracks_filtered.Properties.VariableNames)
        data2plot = outputvariable;
    else
        data2plot = ['mean ' outputvariable];
    end
    
    mean_filtered = varfun(@mean, subT_tracks_filtered, 'InputVariables', data2plot, 'GroupingVariables', 'Treatment');
    std_filtered = varfun(@std, subT_tracks_filtered, 'InputVariables', data2plot, 'GroupingVariables', 'Treatment');
    n_filtered = varfun(@length, subT_tracks_filtered, 'InputVariables', data2plot, 'GroupingVariables', 'Treatment');
    
    mean_others = varfun(@mean, subT_tracks_others, 'InputVariables', data2plot, 'GroupingVariables', 'Treatment');
    std_others = varfun(@std, subT_tracks_others, 'InputVariables', data2plot, 'GroupingVariables', 'Treatment');
    n_others = varfun(@length, subT_tracks_others, 'InputVariables', data2plot, 'GroupingVariables', 'Treatment');
    
    mean_all = varfun(@mean, T_tracks, 'InputVariables', data2plot, 'GroupingVariables', 'Treatment');
    std_all = varfun(@std, T_tracks, 'InputVariables', data2plot, 'GroupingVariables', 'Treatment');
    n_all = varfun(@length, T_tracks, 'InputVariables', data2plot, 'GroupingVariables', 'Treatment');
    
    % Combine means, standard deviations, and counts into a single table for plotting
    mean_combined = outerjoin(mean_filtered(:, {'Treatment', ['mean_' data2plot]}), ...
        mean_others(:, {'Treatment', ['mean_' data2plot]}), ...
        'Keys', 'Treatment', 'MergeKeys', true, ...
        'RightVariables', ['mean_' data2plot]);
    mean_combined = outerjoin(mean_combined, ...
        mean_all(:, {'Treatment', ['mean_' data2plot]}), ...
        'Keys', 'Treatment', 'MergeKeys', true, ...
        'RightVariables', ['mean_' data2plot]);
    
    std_combined = outerjoin(std_filtered(:, {'Treatment', ['std_' data2plot]}), ...
        std_others(:, {'Treatment', ['std_' data2plot]}), ...
        'Keys', 'Treatment', 'MergeKeys', true, ...
        'RightVariables', ['std_' data2plot]);
    std_combined = outerjoin(std_combined, ...
        std_all(:, {'Treatment', ['std_' data2plot]}), ...
        'Keys', 'Treatment', 'MergeKeys', true, ...
        'RightVariables', ['std_' data2plot]);
    
    n_combined = outerjoin(n_filtered(:, {'Treatment', ['length_' data2plot]}), ...
        n_others(:, {'Treatment', ['length_' data2plot]}), ...
        'Keys', 'Treatment', 'MergeKeys', true, ...
        'RightVariables', ['length_' data2plot]);
    n_combined = outerjoin(n_combined, ...
        n_all(:, {'Treatment', ['length_' data2plot]}), ...
        'Keys', 'Treatment', 'MergeKeys', true, ...
        'RightVariables', ['length_' data2plot]);
    
    % Calculate SEM
    sem_combined = std_combined{:, 2:end} ./ sqrt(n_combined{:, 2:end});
    
    % Rename columns for clarity
    mean_combined.Properties.VariableNames = {'Treatment', 'Mean_Filtered', 'Mean_Others', 'Mean_All'};
    sem_combined_table = array2table(sem_combined, 'VariableNames', {'SEM_Filtered', 'SEM_Others', 'SEM_All'});
    
    % Prepare data for bar chart
    bar_data = table2array(mean_combined(:, 2:end));
    bar_labels = mean_combined.Treatment;
    
    % Create grouped bar chart with error bars
    figure;
    bar(bar_data, 'grouped');
    hold on;
    ngroups = size(bar_data, 1);
    nbars = size(bar_data, 2);
    x = 1:ngroups; % the x locations for the groups
    for i = 1:nbars
        for j=1:ngroups
            errorbar(x(j)+(i-2)*.22, bar_data(j, i), sem_combined(j, i), 'k', 'linestyle', 'none'); % Adjust x location for error bars
        end
    end
    %set(gca, 'XTickLabel', bar_labels');
    xlabel('Treatment');
    ylabel(data2plot);
    title(['Grouped Bar Chart of ' data2plot]);
    legend({'Filtered', 'Others', 'All'}, 'Location', 'Best');
    grid on;
    hold off;
    
    stats = [mean_others(mean_others.Treatment==0,:).(['mean_' outputvariable]) std_others(std_others.Treatment==0,:).(['std_' outputvariable]) ...
            n_others(n_others.Treatment==0,:).('GroupCount') ...
            mean_others(mean_others.Treatment==1,:).(['mean_' outputvariable]) std_others(std_others.Treatment==1,:).(['std_' outputvariable]) ...
            n_others(n_others.Treatment==1,:).('GroupCount'); ...
            mean_filtered(mean_filtered.Treatment==0,:).(['mean_' outputvariable]) std_filtered(std_filtered.Treatment==0,:).(['std_' outputvariable]) ...
            n_filtered(n_filtered.Treatment==0,:).('GroupCount') ...  
            mean_filtered(mean_filtered.Treatment==1,:).(['mean_' outputvariable]) std_filtered(std_filtered.Treatment==1,:).(['std_' outputvariable]) ...
            n_filtered(n_filtered.Treatment==1,:).('GroupCount')]; 
end