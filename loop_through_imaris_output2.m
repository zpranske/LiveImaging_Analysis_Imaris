%% Loop Through Imaris Output
%  Contains functions needed by simple_imaris_crawler.m. Do not try to run
%  this file directly: use the main simple_imaris_crawler.m to call these 
%  functions.

%% function loop_through_imaris_output2.m
%  Updated 2025-09-29 Zachary Pranske
%
%  Loop through output files, load up the data for the measure of interest,
%  preprocess the files (append file name into table, handle comma issues,
%  etc.), compile into one large table, and write to output destination.

function T = loop_through_imaris_output2(output_measure, output_marker, input_path, output_path)
    if(~exist(output_path)) mkdir(output_path); end
    addpath(genpath(input_path));
    markerpath = strcat(input_path, filesep, output_marker)
    fnames = dir(markerpath);
    w = warning ('off','all');
    
    T = table();
    % Logic for finding the correct output files for the given measure
    filestring2find = ['_' output_measure '.csv'];
    for i=1:numel(fnames)
        % Ignore Windows hidden files
        % May need to be altered or removed to run on Mac
        found=0;
        if ~(fnames(i).name=="."||fnames(i).name=="..")
            found=1;
        end
        d = dir([input_path '\' fnames(i).name]);
        if found
            s = fnames(i).name;
            % Depending on how you export, each file might be appended with 
            % a "_Statistics" tag. If so, remove before processing further
            appendedstring2find = '_Statistics';
            if (contains(fnames(i).name,appendedstring2find))
                % Remove the _Statistics tag from the end of the filename to get
                % the base filename only
                s=s(1:length(s)-length('_Statistics'));
            end

            tablename = strjoin([s filestring2find],'');
            disp(strjoin(['Reading ' output_measure ' from ' tablename],''))

            subT = preprocessCSV(tablename,fnames(i).name,markerpath,output_path);
            % Append the name of the original image to each table so you 
            % can figure out which puncta/tracks came from which image
            subT = [array2table(repelem([string(s)],1,height(subT))') subT];
            subT = renamevars(subT, "Var1", "File");
            if ismember('ID', subT.Properties.VariableNames)
                subT.Unique_ID = strcat(string(subT.File), "_", string(subT.ID));
            end
            % Check if 'TrackID' exists (live imaging) and create 'File_TrackID' column
            if ismember('TrackID', subT.Properties.VariableNames)
                subT.Unique_TrackID = strcat(string(subT.File), "_", string(subT.TrackID));
            end
            T = [T;subT];
        end;
    end
    
    disp(strcat("Writing all ", output_marker, " ", output_measure))
    writetable(T, strjoin([output_path '\' output_marker ' ' output_measure '.csv'],''));
    disp(strjoin(["Combined table successfully written to " output_path]))
    end
  
%% function preprocessCSV 
%  Updated 6/12/25 ZP
% 
%  This function handles any weird comma issues that can be present if you 
%  filtered a surface with multiple criteria before exporting as a CSV. 
%  You may need to adjust the pattern to properly eliminate errant commas 
%  within the CSV. Honestly I know very little about regex so ChatGPT did 
%  that part for me, don't ask me for help sorry.

function dataTable = preprocessCSV(tablename,folder,markerpath,output_path)
    fileContent = fileread(markerpath + filesep + folder + filesep + tablename);
    
    % Replace commas within double-quoted text with a | symbol
    pattern = '0 , "';
    replacement = ' | ';
    
    % Perform the replacement
    modifiedContent = regexprep(fileContent, pattern, replacement);

    % Step 3: Write the modified content back to a new CSV file
    outputFilePath = 'C:\Users\zpranske\Documents\MATLAB\temp\modified_data.csv'; % Path to save the modified file
    fileID = fopen(outputFilePath, 'w');
    fwrite(fileID, modifiedContent);
    fclose(fileID);
    
    % Step 4: Load the modified CSV into a table
    dataTable = readtable(outputFilePath);
end
