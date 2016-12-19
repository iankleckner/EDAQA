% AUTHORS
%   Ian Kleckner, PhD
%    University of Rochester Medical Center (Rochester, NY, USA)
%    ian.kleckner at gmail.com
%   With Matthew Goodwin, PhD
%    Northeastern University (Boston, MA, USA)
% 
% DESCRIPTION
%   Demo program for loading an EDA file and running the automated quality
%   assessment procedure described in Kleckner et al., Simple, Transparent, 
%   and Flexible Automated Quality Assessment Procedures for Ambulatory
%   Electrodermal Activity Data
%
% INSTRUCTIONS
%	(1) Set variables in the "Input" section just below these comments
%   (2) Run the program
%   (3) View the output folder (out-EDAQA-...)
%
%   This demo shows an example with a Q sensor EDA file. If you have your
%   own file format then you hav to write in your own code to load the
%   data. You can see the section "%% Run automated quality assessment
%   function" to see what variables you need to set for running the QA
%   procedure.
%
%   If you don't have temperature data, then set the temperature variable
%   to an empty matrix, [], and the run_automated_EDAQA function will not
%   use any temperature criteria
%
%   The automated QA procedure is run by a function
%   "run_automated_EDAQA.m". You can see that code too for how it works
%
% CHANGELOG
%   2016/12/18 Start coding for distribution
%
% LICENSE
%   Electrodermal Activity Automated Quality Assessment
%   Copyright (C) 2016  Ian R. Kleckner
% 
%   This program is free software: you can redistribute it and/or modify
%   it under the terms of the GNU General Public License as published by
%   the Free Software Foundation, version 3 of the License.
% 
%   This program is distributed in the hope that it will be useful,
%   but WITHOUT ANY WARRANTY; without even the implied warranty of
%   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%   GNU General Public License for more details.
% 
%   You should have received a copy of the GNU General Public License
%   along with this program.  If not, see <http://www.gnu.org/licenses/>.

%% Initialize
clc;
clear all;

%% Input

% Filename for innput data. This demo shows an example with a Q sensor
% file. If you have your own file format then you hav to write in your own
% code to load the data
filename_Q_Sensor = 'data/8WGY92.csv';

% Despiking filter
QA_filter_window_EDA_sec = 2;

% Rule 1: For determining floor and ceiling of unusable data
QA_EDA_floor = 0.05;
QA_EDA_ceiling = 60;

% Rule 2: For limit on slope
QA_EDA_max_slope_uS_per_sec = 10;

% Rule 3: Min and max temp
QA_temperature_C_min = 30;
QA_temperature_C_max = 40;

% Rule 4: Radius to influence dropping data on adjacent data points (to be safe)
QA_radius_to_spread_invalid_datum_sec = 5;


%% Options

% Plot specs
LINEWIDTH   = 2;
FONTSIZE    = 16;
MARKERSIZE  = 10;
FIGURE_DPI = '-r150';

%% Load EDA file (example using from Q Sensor)

% Options
Nlines_header = 8;

%--------------------------------------------------------------------------
% Open file
FILE = fopen(filename_Q_Sensor, 'r');
fileData_delimited = textscan(FILE, '%s', 'Delimiter', '\n', 'HeaderLines', 0);
fileData_delimited = fileData_delimited{1};
fclose(FILE);

% Get sampling period
line_sampling_rate = fileData_delimited{5};
sampling_period_Q = 1 / sscanf(line_sampling_rate(16:end), '%d');

% Get start time
line_start_time = fileData_delimited{6};
if( strcmpi( line_start_time, 'START TIME: UNSET') )
    time_start_Q_sec = 0;
    date_start_Q = 'Unknown';

else
    date_start_Q    = line_start_time(13:32);
    time_format     = 'yyyy-mm-dd HH:MM:SS';
    time_start_Q_sec= 24*60*60 * datenum(date_start_Q, time_format);
end

%--------------------------------------------------------------------------
% Get the data vs. time
Ndata_points = length(fileData_delimited) - Nlines_header;

data_Acc_Z_g      = NaN*zeros(Ndata_points, 1);
data_Acc_Y_g      = NaN*zeros(Ndata_points, 1);
data_Acc_X_g      = NaN*zeros(Ndata_points, 1);
battery             = NaN*zeros(Ndata_points, 1);
data_temperature_C              = NaN*zeros(Ndata_points, 1);
data_EDA_uS       = NaN*zeros(Ndata_points, 1);
Nsamples_missed_Q   = 0;

% Read each line
fprintf('\n\nReading Q sensor data...');
time_start = tic();
for data_num = 1:Ndata_points
    line_num = data_num + Nlines_header;

    line_string = fileData_delimited{line_num};
    line_data_array = sscanf(line_string, '%f,%f,%f,%f,%f,%f');

    try
        data_Acc_Z_g(data_num)    = line_data_array(1);
        data_Acc_Y_g(data_num)    = line_data_array(2);
        data_Acc_X_g(data_num)    = line_data_array(3);
        %battery(data_num)        = line_data_array(4)
        data_temperature_C(data_num)          = line_data_array(5);
        data_EDA_uS(data_num)   = line_data_array(6);
    catch
        fprintf('\n\tMissing data entry at line %d: %s', line_num, line_string);
        Nsamples_missed_Q = Nsamples_missed_Q + 1;

        data_Acc_Z_g(data_num)    = NaN;
        data_Acc_Y_g(data_num)    = NaN;
        data_Acc_X_g(data_num)    = NaN;
        %battery(data_num)        = NaN;
        data_temperature_C(data_num)          = NaN;
        data_EDA_uS(data_num)   = NaN;
    end
end
fprintf('\n\tDone in %0.1f sec', toc(time_start));

data_time_sec = time_start_Q_sec + cumsum( sampling_period_Q * ones(1,length(data_EDA_uS)) );

% Integrated acceleration: Subtract 1 to remove the effect of gravity
data_Acc_g_total    = abs( sqrt( data_Acc_X_g.^2 + data_Acc_Y_g.^2 + data_Acc_Z_g.^2 ) - 1 );


fprintf('\nLength of data is %0.3f min', (data_time_sec(end)-data_time_sec(1))/60);
fprintf('\nMissed %d samples (%f%%) out of %d potential samples', ...
    Nsamples_missed_Q, 100*Nsamples_missed_Q/Ndata_points, Ndata_points);

%----------------------------------------------------------------------
% Calculate start and end time and write to file
if( ~strcmpi(date_start_Q, 'UNKNOWN') )
    start_time_sec          = datenum(date_start_Q, time_format);
    duration_sec            = data_EDA_uS(end) - data_EDA_uS(1);
    end_time_sec            = start_time_sec + duration_sec;    
    start_date_string       = datestr(start_time_sec);
    end_date_string         = datestr(end_time_sec);        
    start_date_string_YMD   = datestr(start_time_sec, 'yyyy/mm/dd');
    end_date_string_YMD     = datestr(end_time_sec, 'yyyy/mm/dd');
else
    start_time_sec          = NaN;
    duration_sec            = NaN;
    end_time_sec            = NaN;
    start_date_string       = 'Unknown';
    end_date_string         = 'Unknown';
    start_date_string_YMD   = 'Unknown';
    end_date_string_YMD     = 'Unknown';
end    

k_slashes = strfind(filename_Q_Sensor, '/');
if( isempty(k_slashes) )
    k_slashes = strfind(filename_Q_Sensor, '\');
end 

%% Run automated quality assessment function

[EDA_datum_valid, data_EDA_uS_filtered] = run_automated_EDAQA( ...
    data_EDA_uS, data_time_sec, data_temperature_C, ...
    QA_filter_window_EDA_sec, ...
    QA_EDA_floor, QA_EDA_ceiling, ...
    QA_EDA_max_slope_uS_per_sec, ...
    QA_temperature_C_min, QA_temperature_C_max, ...
    QA_radius_to_spread_invalid_datum_sec );

EDA_datum_invalid = ~EDA_datum_valid;

%% Output

datestring = datestr(now, 'yyyy.mm.dd-HH-MM');

% Create output folder
foldername_output = sprintf('out-EDAQA-%s', datestring);
mkdir(foldername_output);

%--------------------------------------------------------------------------
% Write results to file where invalid EDA is replaced with NaN
k_slashes = strfind(filename_Q_Sensor, '/');
if( isempty(k_slashes) )
    k_slashes = strfind(filename_Q_Sensor, '\');
end
filename_Q_Sensor_short = filename_Q_Sensor(k_slashes(end)+1 : end);

filename_out = sprintf('%s/%s--EDAQA.csv', foldername_output, strrep(filename_Q_Sensor_short, '.csv', ''));

% Censor out invalid data points with a NaN value
data_EDA_uS_censored = data_EDA_uS;
data_EDA_uS_censored(EDA_datum_invalid) = NaN;

column_labels = {'Time(sec)', 'EDA(uS)', 'EDA_Valid(1Yes_0No)', 'EDA_w_NaN_from_QA(uS)', 'Temp(C)'};
data_matrix = [data_time_sec', data_EDA_uS, EDA_datum_valid, data_EDA_uS_censored, data_temperature_C]; 

header_text = sprintf('%s,', column_labels{:});
header_text(end) = '';

% Write to file
dlmwrite(filename_out, header_text, '');
dlmwrite(filename_out, data_matrix, '-append', 'delimiter', ',');

fprintf('\nWrote %s', filename_out);

%--------------------------------------------------------------------------
% Fraction of valid data
QA_invalid_data_fraction = mean( EDA_datum_invalid );  

% For plots to follow, filter out invalid data by making it NaN
DATUM_INVALID_IS_NAN_FOR_PLOT = NaN * ones(length(data_EDA_uS_filtered), 1);
DATUM_INVALID_IS_NAN_FOR_PLOT( EDA_datum_invalid == false ) = 1;

%----------------------------------------------------------------------
% Plot QA results on top of raw and filtered results

hold('off');
subplot(1,1,1);
plot(data_time_sec - data_time_sec(1), data_EDA_uS, 'Color', [.4 .4 .4]);

hold('all');
plot(data_time_sec - data_time_sec(1), data_EDA_uS_filtered, '-r', 'LineWidth', 2);

% Plot filtered data
hold('all');
plot(data_time_sec - data_time_sec(1), data_EDA_uS_filtered, '-g', 'LineWidth', 1);

% Plot valid data
plot(data_time_sec - data_time_sec(1), data_EDA_uS_filtered .* DATUM_INVALID_IS_NAN_FOR_PLOT, '-b', 'LineWidth', 2);

title(sprintf('%s (%0.0f%% Invalid)', filename_Q_Sensor, 100*QA_invalid_data_fraction));
xlabel('Time (sec)');
ylabel('EDA (uS)');    
legend({'Raw Data', 'Filtered Data', 'Filtered for QA', 'Valid Data'});

filename_figure = sprintf('%s/out-EDAQA-1-raw+filter+QA+valid.png', foldername_output);
set(gca, 'LineWidth', LINEWIDTH, 'FontSize', FONTSIZE);
print(gcf, '-dpng', FIGURE_DPI, filename_figure);
fprintf('\nWrote %s', filename_figure);

%----------------------------------------------------------------------
% Plot valid EDA data
hold('off');
plot(data_time_sec - data_time_sec(1), data_EDA_uS_filtered .* DATUM_INVALID_IS_NAN_FOR_PLOT, '-b', 'LineWidth', 1);

title(sprintf('%s (%0.0f%% Invalid)', filename_Q_Sensor, 100*QA_invalid_data_fraction));

% Set proper X limits to the available data
if( ~isempty(EDA_datum_invalid) && ...
         sum(EDA_datum_invalid==0) ~= 0 && ...
         sum(EDA_datum_invalid==1) ~= 0 )
    xlim( sampling_period_Q * [ find(EDA_datum_invalid==0, 1, 'first'), find(EDA_datum_invalid==0, 1, 'last')] );
end

xlabel('Time (sec)');
ylabel('EDA (uS)');    
legend({'Valid Data'});

filename_figure = sprintf('%s/out-EDAQA-2-valid.png', foldername_output);
set(gca, 'LineWidth', LINEWIDTH, 'FontSize', FONTSIZE);
print(gcf, '-dpng', FIGURE_DPI, filename_figure);
fprintf('\nWrote %s', filename_figure);

%----------------------------------------------------------------------
% Plot temperature

% Plot raw data
hold('off');
plot(data_time_sec - data_time_sec(1), data_temperature_C, '-', 'Color', [.4 .4 .4]);

% Plot valid data
hold('all');
plot(data_time_sec - data_time_sec(1), data_temperature_C .* DATUM_INVALID_IS_NAN_FOR_PLOT, '-b', 'LineWidth', 2);

title(sprintf('%s (%0.0f%% Invalid)', filename_Q_Sensor, 100*QA_invalid_data_fraction));
xlabel('Time (sec)');
ylabel('Temperature (^oC)');    
legend({'Raw Data', 'Valid Data'}, 'Location', 'South');

filename_figure = sprintf('%s/out-EDAQA-3-temperature.png', foldername_output);
set(gca, 'LineWidth', LINEWIDTH, 'FontSize', FONTSIZE);
print(gcf, '-dpng', FIGURE_DPI, filename_figure);
fprintf('\nWrote %s', filename_figure);

%----------------------------------------------------------------------
% Plot acceleration    

% Plot raw data
hold('off');
plot(data_time_sec - data_time_sec(1), data_Acc_g_total, '-', 'Color', [.4 .4 .4]);

% Plot valid data
hold('all');
plot(data_time_sec - data_time_sec(1), data_Acc_g_total .* DATUM_INVALID_IS_NAN_FOR_PLOT, '-b', 'LineWidth', 2);

set(gca, 'LineWidth', LINEWIDTH, 'FontSize', FONTSIZE);
legend({'Raw Data', 'Valid Data'}, 'Location', 'North');
ylabel('Acceleration (g)');    

title(sprintf('%s (%0.0f%% Invalid)', filename_Q_Sensor, 100*QA_invalid_data_fraction));
ylabel('Acceleration (g)');    
xlabel('Time (sec)');

filename_figure = sprintf('%s/out-EDAQA-4-acceleration.png', foldername_output);
set(gca, 'LineWidth', LINEWIDTH, 'FontSize', FONTSIZE);
print(gcf, '-dpng', FIGURE_DPI, filename_figure);
fprintf('\nWrote %s', filename_figure);

%% All done
fprintf('\n\nAll done!\n');
