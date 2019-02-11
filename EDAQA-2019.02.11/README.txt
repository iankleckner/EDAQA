Electrodermal Activity Automated Quality Assessment Program

---------------------------------------------------------
AUTHORS

Ian Kleckner, PhD
University of Rochester Medical Center (Rochester, NY, USA)
ian.kleckner at gmail.com

With Matthew Goodwin, PhD
Northeastern University (Boston, MA, USA)

---------------------------------------------------------
CHANGELOG

2016/12/18 Start the README file
2019/02/11 Update code to output FILTERED EDA data and option for NO filtering

---------------------------------------------------------
LIST OF FILES

data\8WGY92.csv - Example EDA file from the Q Sensor
data\129TRD.csv - Example EDA file from the Q Sensor

demo_EDAQA_single_input_file - This file is set up to run automated EDA QA on an example file

demo_EDAQA_scan_dirs_for_input_files.m - This file is set up to scan directories looking for data files. Also the output is more sophisticated with an HTML page to view the figures.

README.txt - This file

LICENSE.txt - The GNU GPL3 license, which applies to this software

run_automated_EDAQA.m - This function implements the actual rules for the EDA QA

subdir.m - Supporting function

writePlot.m - Supporting function


---------------------------------------------------------
INSTRUCTIONS

1. Start MATLAB
2. Open demo_EDAQA_scan_dirs_for_input_files.m OR demo_EDAQA_single_input_file.m
3. Edit the file's Input section at the top as desired
4. Run the program
5. View the output (some images and a text data file, see Console for file names)
6. For advanced features/edits, read the code and comments in demo_EDAQA.m and in run_automated_EDAQA.m
