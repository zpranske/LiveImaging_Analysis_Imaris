%% kmeans_cluster.m
%  Updated 2025-09-29 Zachary Pranske
%  
%  Performs k-means clustering of tracks from T_tracks based on variables 
%  as defined below. Assumes you have already run
%  analyze_track_characteristics.m and a T_tracks table already exists
% (will NOT work unless you run that script first).

basefolder = "C:\Users\zpranske\Desktop\Datasets\2025-07-14 registered y2 (punctate) geph tracking\surface tracking output";
marker = "gfp-geph";
shortest_distance_var = "Shortest_Distance_to_Surfaces_Surfaces_y2_Halo";
T = T_tracks;

% Calculate the required mean values for clustering
totalDistance = T.TdT;
meanDisplacementLength = T.("Euclidean_Distance");
meanSpeed = T.("mean Speed");
maxSpeed = T.Max_Velocity;
meanAcceleration = T.("mean Acceleration");
straightness = T.Track_Straightness;
Ar1 = T.Track_Ar1_Mean;
meanArea = T.("mean Area");
initialShortestDistance = T.Initial_Dist;
minShortestDistance = T.Min_Dist;
meanShortestDistance = T.(["mean " + shortest_distance_var]);
meanIntensityCh1 = T.("mean Intensity_Mean_Ch_1_Img_1");
meanIntensityCh2 = T.("mean Intensity_Mean_Ch2_Corrected");
F0 = T.F_0;
dF_FoldChange = T.dF_FoldChange;

% Create a table with the mean values
meanValues = table(totalDistance, meanDisplacementLength, meanSpeed, maxSpeed, meanAcceleration, straightness, Ar1, ...
    meanArea, initialShortestDistance, minShortestDistance, meanShortestDistance, meanIntensityCh1, meanIntensityCh2, F0, dF_FoldChange);

% Prepare data for k-means clustering
dataForClustering = meanValues{:, {'totalDistance', 'meanDisplacementLength', 'meanSpeed', 'maxSpeed', 'meanAcceleration',...
    'straightness', 'Ar1', 'meanArea', 'initialShortestDistance', 'minShortestDistance', 'meanShortestDistance', ...
    'meanIntensityCh1', 'meanIntensityCh2', 'F0', 'dF_FoldChange'}};
dataZ = zscore(dataForClustering); 

% Perform k-means clustering
numClusters = 3; % Specify the number of clusters
[idx, C] = kmeans(dataZ, numClusters);

% Add cluster indices to the meanValues table
T.Cluster = idx;

% Perform PCA for dimensionality reduction
[coeff, score, latent, tsquared, explained] = pca(dataZ);

T.Dim1 = score(:,1); T.Dim2 = score(:,2); T.Dim3 = score(:,3); T.Dim4 = score(:,4);
T.Dim5 = score(:,5); T.Dim6 = score(:,6); T.Dim7 = score(:,7); T.Dim8 = score(:,8);
T.Dim9 = score(:,9); T.Dim10 = score(:,10); T.Dim11 = score(:,11); T.Dim12 = score(:,12);
T.Dim13 = score(:,13); T.Dim14 = score(:,14); T.Dim15 = score(:,15);

%% Create 2D scatter plot of two principal components
figure;
gscatter(T.Dim1, T.Dim2, T.isFiltered);
xlabel('Principal Component 1');
ylabel('Principal Component 2');
title('Tracks in Reduced Dimensionality Space');
legend('Group 1', 'Group 2');
grid on;

%% Plot histogram of a given PC by Treatment condition
figure;
hold on;
treatments = unique(T.isFiltered); %unique(T.Treatment);
colors = lines(numel(treatments)); % Generate distinct colors for each treatment

% Get the default bin width for the first treatment
defaultBinWidth = []; % Initialize variable for default bin width
if ~isempty(T.Dim1(T.Treatment == treatments(1)))
    defaultBinWidth = range(T.Dim1(T.Treatment == treatments(1))) / 20; % Default bin width calculation
end

for i = 1:numel(treatments)
    histogram(T.Dim1(T.Treatment == treatments(i)), 'FaceColor', colors(i,:), 'DisplayName', num2str(treatments(i)), 'Normalization', 'probability', 'BinWidth', defaultBinWidth);
end

xlabel('Principal Component 1');
ylabel('Probability');
title('Histogram of Principal Component 1 by Treatment Condition');
legend('show');
grid on;

%% Create a 3D scatter plot of three principal components
figure;
scatter3(T.Dim1, T.Dim2, T.Dim3, 36, T.isFiltered, 'filled');
xlabel('Principal Component 1');
ylabel('Principal Component 2');
zlabel('Principal Component 3');
title('3D Plot of Tracks in Reduced Dimensionality Space');
grid on;