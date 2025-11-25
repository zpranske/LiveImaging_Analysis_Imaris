%% Simple Imaris Crawler.m
%  Updated 2025-06-12 Zachary Pranske
%
%  Loops through a folder of Imaris outputs, where each file that was
%  analyzed has its own folder containing all the stats for that file. The
%  marker corresponds to the tab in the main Imaris creation pane you used:
%  likely the name of a surface (e.g. "gad65") or the whole scene (in which 
%  case your marker will be "scene"). You should create a
%  folder for this if you don't have one by default. The measure
%  corresponds to the parameter you want to collect -- check in one of the
%  output folders to find a list of measure names. input_path should 
%  be the main folder with your exported data containing folders named 
%  exactly the same as the marker variable (e.g. "gad65" or "scene"). 
%  Note: You need the function file loop_through_imaris_output2.m for this 
%  script to work.

% Add folder containing this script to the path
addpath(genpath('C:\Users\zpranske\Documents\GitHub\Zachs-Random-Code'));

marker = "y2-Halo";
measure = "Track_Ar1_Mean";

input_path = ('C:\Users\zpranske\Desktop\Datasets\2025-07-14 registered y2 (punctate) geph tracking\surface tracking output');
output_path = ([input_path filesep '_combined analysis']);

T = loop_through_imaris_output2(measure, marker, input_path, output_path);

