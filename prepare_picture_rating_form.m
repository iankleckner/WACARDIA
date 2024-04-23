% Ian Kleckner
% ian.kleckner@gmail.com
% Interdisciplinary Affective Science Lab (IASLab)
% Northeastern University
%
% Prepares HTML page for image rating
%  Shows images in the same order as the PP saw them in
%  Reads log.txt file
%
% 2012/06/27 Start coding
% 2012/07/04 Use thumbnail pictures so PDF printout of webpage is a reasonable size
%            Note, with full IAPS images, the PDF printout of the webpage is 90 Mb / session
%            but with thumbnail images at 10% original size (~100x80), the PDF is 2 Mb
%            Note: MUST have data folder named AffectiveJudgment-Thumbnail
%
% 2012/07/04 Give unique name to each textarea HTML element
% 2012/07/24 Update/clarify instructions
%
%
%% Instructions for user
%
% (Mode a) This program is called by the AffectiveJudgment_expt.m file
%
% (Mode b) It can also be called by hand like this:
%   prepare_picture_rating_form('output--2012.06.27-11-20--AJ--PP5-S1')
%
% and it will go into the directory output--2012.06.27-11-20--AJ--PP5-S1
% and load the log.txt file
%
% OUTPUT
%  A folder that contains an HTML page with a survey for the pictures that
%  the PP saw in the same order that they saw it in
%
% PP should fill out HTML page, and then reseracher can print the page as a
% PDF file
%
% Use a browser that can print to PDF (e.g., google chrome)
% OR set up a PDF printer (e.g., using PDF995 - see Internet)

function prepare_picture_rating_form( input_directory )
    %% Clear workspace
    
    % Do NOT use these commands since this is a function called by another
    % program
    %clc;
    %clear all;
    %close all;

    % Version of this program (last update)
    version_string = '2012.07.24';
    
    fprintf('\n\nPrepare picture rating form');

    %% Input
    if( nargin > 0 )
        fprintf('\nEntering directory %s...', input_directory);
        foldername_input = input_directory;
        foldername_data_relative = '../..';
    else
        fprintf('\nTrying to run from local directory...');
        foldername_input = '.';
        foldername_data_relative = '..';
    end
    
    filename_input_log = 'log.txt';

    %% Options

    % Width of figures in HTML document
    figure_width_html = 200;

    table_border_size = 1;

    % For the thoughts / feelings text box
    Nrows = 10;
    Ncols = 35;
    
    % Use smaller versions of the IAPS images
    %  Note: MUST have data folder named AffectiveJudgment-Thumbnail
    USE_THUMBNAIL_IMAGES = true;

    %% Initialize

    %------------------
    % Try to open input files
    filename_input_log_full = sprintf('%s/%s', foldername_input, filename_input_log);

    INPUT = fopen(filename_input_log_full, 'r');

    % Read the input file
    %  One line per token
    try
        fileData_delimited = textscan(INPUT, '%s', 'Delimiter', '\n', 'CollectOutput', true);
    catch e
        filename_input_log_full
        rethrow(e);
    end
    tokensInFile = fileData_delimited{1};
    %------------------


    %------------------
    % Extract PP info from input file

    % Get PP Number
    % Find a line that starts with "PPnumber"
    [line_string, line_num] = findTargetStringCellArray( 'PPnumber', tokensInFile );

    % Analyze the line string for the value
    PP_number = sscanf(line_string, 'PPnumber\t%d');

    if( isempty(PP_number) )
        % Find a line that starts with "PPnumber"
        [line_string, line_num] = findTargetStringCellArray( 'PPnumber_in_study', tokensInFile );

        % Analyze the line string for the value
        PP_number = sscanf(line_string, 'PPnumber_in_study\t%d');
    end

    % Get Session Number
    % Find a line that starts with "SessionNumber"
    [line_string, line_num] = findTargetStringCellArray( 'SessionNumber', tokensInFile );

    % Analyze the line string for the value
    session_number = sscanf(line_string, 'SessionNumber\t%d');

    % Title for participant in plots
    PP_title = sprintf('PP%1d/S%01d', PP_number, session_number);
    %------------------

    %------------------
    % Prepare output folders / files
    % String with date
    datestring = datestr(now, 'yyyy.mm.dd-HH-MM');

    % Create output folder
    foldername_output = sprintf('%s/picture_rating_form-PP%02d-S%d', input_directory, PP_number, session_number);

    % Foldername for images in HTML page
    subfoldername_figures = 'figures';

    % Make folder
    mkdir(foldername_output);
    %mkdir(sprintf('%s/%s', foldername_output, subfoldername_figures));

    % Diary on
    diary( sprintf('%s/diary.txt', foldername_output) );

    % Zip code into output directory
    zip( sprintf('%s/code.zip', foldername_output), '*.m');
    %------------------

    % Copy input file from input to output folder
    copyfile(sprintf('%s', filename_input_log_full), sprintf('%s/%s', foldername_output, filename_input_log));

    %% Basic header information

    % HTML page output
    filename_output = sprintf('%s/index.html', foldername_output);

    % Open log file for output
    OUTPUT = fopen(filename_output, 'w');
    
    % HTML header
    fprintf(OUTPUT, '<html>');
    fprintf(OUTPUT, '\n<body>');
    fprintf(OUTPUT, '\n<title>%s-%s</title>', PP_title, 'Picture_Rating_Form');
    fprintf(OUTPUT, '\n<div align="center">');

    fprintf(OUTPUT, '\n\n<h1>Picture Rating Form PP%02d/S%d</h1>', PP_number, session_number);
    fprintf(OUTPUT, '\n\nIan Kleckner');
    fprintf(OUTPUT, '\n<br />');
    fprintf(OUTPUT, '\nProgram Version %s', version_string);
    fprintf(OUTPUT, '\n<br />');
    fprintf(OUTPUT, '\nForm generated on %s', datestr(now, 'yyyy/mm/dd at HH:MM'));
    fprintf(OUTPUT, '\n<br />');
    fprintf(OUTPUT, '\n<br />');
    
    % Instructions written on 2012/07/04
%     fprintf(OUTPUT, '\n<h2>Background</h2>');
%     fprintf(OUTPUT, '\nThe pictures for the picture rating task were selected to represent five emotional categories:<br />');
%     fprintf(OUTPUT, '\n(1) Negative, low intensity<br />');
%     fprintf(OUTPUT, '\n(2) Negative, high intensity<br />');
%     fprintf(OUTPUT, '\n(3) Neutral<br />');
%     fprintf(OUTPUT, '\n(4) Positive, low intensity<br />');
%     fprintf(OUTPUT, '\n(5) Positive, high intensity<br />');
%     fprintf(OUTPUT, '\n<br />');
%     fprintf(OUTPUT, '\nHowever, sometimes pictures "cross categories" for some viewers. For example, you may experience a "neutral" picture of a lamp as positive because it reminds you of a funny movie.');
%     fprintf(OUTPUT, '\nWhen we analyze your results, <u>we want to know how you experienced each picture</u>.<br />');    
%     
%     fprintf(OUTPUT, '\n<h2>Instructions</h2>');    
%     fprintf(OUTPUT, '\n(1) Which pictures (if any) are particularly <u>immersive</u> or particularly <u>not immersive</u> for you (i.e., did the picture seem <u>real</u> to you or not)?<br />');
%     fprintf(OUTPUT, '\n<br />');
%     fprintf(OUTPUT, '\n(2) You may also list any thoughts / sensations / feelings you remember having for each picture.<br />');
%     fprintf(OUTPUT, '\n<br />');
%     fprintf(OUTPUT, '\n(3) if any of your ratings are incorrect, then please correct them in the text box');
%     fprintf(OUTPUT, '\n<br />');
%     fprintf(OUTPUT, '\n<br />');
%     fprintf(OUTPUT, '\nAs a reminder, you can skip any or all or parts of this form without penalty.<br />');

    % Instructions written on 2012/07/24
    fprintf(OUTPUT, '\n<b>Thank you for completing the Picture Rating Task</b><br />');
    fprintf(OUTPUT, '\nFor each picture in the Picture Rating Task, we recorded your bodily response, and you submitted your emotional response.<br />');
    fprintf(OUTPUT, '\n<br />');
    fprintf(OUTPUT, '\n<b><u>The goal of this form is to learn more about your mental state as you watched some of the pictures.</u></b><br />');
    fprintf(OUTPUT, '\n<br />');
    fprintf(OUTPUT, '\n<b>(1) Please indicate which pictures were PARTICULARLY immersive.</b><br />');
    fprintf(OUTPUT, '\nFor example, if you felt like you were "there" in the picture, felt emotionally connected to the picture, or you felt some intense bodily response to the picture.<br />');
    fprintf(OUTPUT, '\n<br />');
    fprintf(OUTPUT, '\n<b>(2) Please indicate which pictures were PARTICULARLY not immersive.</b><br />');
    fprintf(OUTPUT, '\nFor example, if you felt disengaged from the Picture Rating Task, or began to think of something unrelated to the picture.<br />');
    fprintf(OUTPUT, '\nThis does not apply to Neutral pictures, since they were selected to be particularly not immersive.<br />');
    fprintf(OUTPUT, '\n<br />');
    fprintf(OUTPUT, '\n<b>(3) Please identify if any pictures did not match their category (listed on the left of each picture).</b><br />');
    fprintf(OUTPUT, '\nFor example, if you felt happy in response to a neutral picture.<br />');
    fprintf(OUTPUT, '\n<br />');
    fprintf(OUTPUT, '\n<b>(4) Please list any thoughts, feelings, and/or sensations to clarify why you felt this way.</b><br />');
    fprintf(OUTPUT, '\n<br />');
    fprintf(OUTPUT, '\n<b>(5) Focus your reponses on a few key pictures (e.g., the 5-10 most immersive pictures and the 5-10 least least immersive pictures).</b><br />');
    fprintf(OUTPUT, '\nPlease complete this form within about 5 minutes.<br />');
    fprintf(OUTPUT, '\nYou should not provide a response for every picture (just leave most of them blank).<br />');
    fprintf(OUTPUT, '\n<br />');
    fprintf(OUTPUT, '\nAs a reminder, you can skip any or all or parts of this form without penalty.<br />');


    fprintf(OUTPUT, '\n<h2>Pictures</h2>');
    fprintf(OUTPUT, '\n<table border="%d" align="center">', table_border_size);
    fprintf(OUTPUT, '\n<tr>');
    fprintf(OUTPUT, '\n<th>Category</th>');
    fprintf(OUTPUT, '\n<th>Picture Number</th>');
    fprintf(OUTPUT, '\n<th>Picture</th>');
    fprintf(OUTPUT, '\n<th>Your Ratings</th>');
    fprintf(OUTPUT, '\n<th>Was this picture PARTICULARLY immersive or not?</th>');
    fprintf(OUTPUT, '\n<th>Did the picture match the category?</th>');
    fprintf(OUTPUT, '\n<th>Why did you feel this way?</th>');
    fprintf(OUTPUT, '\n</tr>');


    %% Read input file

    % Find a line that starts with the target_string
    target_string = 'TrialNum	BlockNum	BlockName	ImageNum	ImageName	ValenceRating(-1_to_+1)	ValenceRT(sec)	ArousalRating(0_to_1)	ArousalRT(sec)';
    [line_string, line_num] = findTargetStringCellArray( target_string, tokensInFile );

    if( isempty(line_num) )
        target_string
        fprintf('\n\n');
       error('The input file is not formatted as expected');
    end

    % Save this line number
    lineNum_hbd_task = line_num;

    % The input file is the proper format, now read the table of results
    KEEP_READING_LINES  = true;
    lineNum             = lineNum_hbd_task+1;
    trialToRead         = 1;

    while( KEEP_READING_LINES )
        % Get the string for that line
        line_string = tokensInFile{lineNum};

        % If this line has no content, then stop reading the file
        if( isempty(line_string) )
            KEEP_READING_LINES = false;
            break;
        end

        % Get the tokens in that string
        line_tokens = textscan(line_string, '%s\t%d\t%s\t%s\t%s\t%f\t%f\t%f\t%f');

        % If this line has no content, then stop reading the file
        if( isempty(line_tokens{1}) )
            KEEP_READING_LINES = false;
            break;
        end

        % Store the data from the line
        aj_trialNumLabel_array{trialToRead}         = line_tokens{1};    
        aj_blockNum_array(trialToRead)              = line_tokens{2};
        aj_blockName_array{trialToRead}             = line_tokens{3};
        aj_imageNum_array{trialToRead}              = line_tokens{4};
        aj_imageName_array{trialToRead}             = line_tokens{5};
        aj_valenceRating_array(trialToRead)         = line_tokens{6};
        aj_valenceResponseTime_array(trialToRead)   = line_tokens{7};
        aj_arousalRating_array(trialToRead)         = line_tokens{8};
        aj_arousalResponseTime_array(trialToRead)   = line_tokens{9};

        % Extract parameters of interest
        blockName   = aj_blockName_array{trialToRead}{1};
        imageNum    = aj_imageNum_array{trialToRead}{1};
        %trialNum    = aj_trialNumLabel_array{trialToRead};
        imageName   = aj_imageName_array{trialToRead}{1};
        
        valenceRating = aj_valenceRating_array(trialToRead);
        arousalRating = aj_arousalRating_array(trialToRead);

        % Prepare table row for the given picture (as long at it's a
        % picture and not a rating screen)
        if( ~strcmpi(imageName, 'ENTIRE_BLOCK') )        

            % Get IAPS image number
            index = findstr(imageName, '/');
            index = index(end);
            IAPS_num_string = imageName(index+1:end);
                        
            if( USE_THUMBNAIL_IMAGES )
                imageName_original = imageName;
                imageName = strrep(imageName, 'AffectiveJudgment', 'AffectiveJudgment-Thumbnail');
                
                if( strcmp(imageName, imageName_original) )
                    fprintf('\n\nERROR: Could not find string AffectiveJudgment in the string "%s" in order to set a thumbnail image', imageName);
                    fprintf('\nPlease set the proper folder names');
                    fprintf('\nExiting...');
                    error('');
                end
            end

            fprintf(OUTPUT, '\n\n<tr  align="center">');
            
            fprintf(OUTPUT, '\n<td align="center">%s</td>', blockName);
            fprintf(OUTPUT, '\n<td align="center">%s <br /><br />%s</td>', imageNum, IAPS_num_string);
            fprintf(OUTPUT, '\n<td align="center"><img src="%s/%s" alt="IMAGE" width="%d"/> </td>', ...
                foldername_data_relative, imageName, figure_width_html);
            
            fprintf(OUTPUT, '\n<td align="center">');
            %fprintf(OUTPUT, '\n<u>Unhappy to Happy (-100 to +100)</u><br />%0.0f%%', 100*valenceRating);
            if( valenceRating > 0 )
                fprintf(OUTPUT, '\n<u>Happiness: (0-100)</u>: %0.0f%%<br />', 100*valenceRating);
                fprintf(OUTPUT, '\n<br />');
                fprintf(OUTPUT, '\n<u>Unhappiness (0-100)</u>: N/A<br />');
            else
                fprintf(OUTPUT, '\n<u>Happiness (0-100)</u>: N/A<br />');
                fprintf(OUTPUT, '\n<br />');
                fprintf(OUTPUT, '\n<u>Unhappiness (0-100)</u>: %0.0f%%<br />', abs(100*valenceRating));   
            end
            
            fprintf(OUTPUT, '\n<br />');
            fprintf(OUTPUT, '\n<u>Excitement (0-100)</u>: %0.0f%%', abs(100*arousalRating));
            fprintf(OUTPUT, '\n</td>');

            fprintf(OUTPUT, '\n<td align="left">');
            fprintf(OUTPUT, '\n<input type="radio" name="group%d" value="Eff">PARTICULARLY immersive<br>', trialToRead);
            fprintf(OUTPUT, '\n<br />');
            fprintf(OUTPUT, '\n<input type="radio" name="group%d" value="InEff">PARTICUARLY NOT immersive<br>', trialToRead);
%             fprintf(OUTPUT, '\n<br />');
%             fprintf(OUTPUT, '\n<input type="radio" name="group%d" value="NA">No response<br>', trialToRead);
            fprintf(OUTPUT, '\n</td>');
            
            fprintf(OUTPUT, '\n<td align="left">');
            fprintf(OUTPUT, '\n<input type="radio" name="group_match%d" value="Match">Picture matched category<br>', trialToRead);
            fprintf(OUTPUT, '\n<br />');
            fprintf(OUTPUT, '\n<input type="radio" name="group_match%d" value="NoMatch">Picture did NOT match category<br>', trialToRead);
            fprintf(OUTPUT, '\n</td>');
            
            fprintf(OUTPUT, '\n<td align="center"><textarea name="textarea%d" cols="%d" rows="%d">Why did you feel this way? (list emotions / sensations / thoughts)\n%s\n</textarea><br></td>', ...
                trialToRead, Ncols, Nrows, char('-'*ones(1,Ncols)));
            
            fprintf(OUTPUT, '\n</tr>');
        end

        % Read the next line and trial
        lineNum     = lineNum + 1;
        trialToRead = trialToRead+1;
    end

    % The table is complete
    fprintf(OUTPUT, '\n</table>');

    %% Complete program

    % Close the file
    fprintf(OUTPUT, '\n</div>');
    fprintf(OUTPUT, '\n</body>');
    fprintf(OUTPUT, '\n</html>');
    fclose(OUTPUT);

    %web(filename_output);

    % Save MATLAB variables
    %save( sprintf('%s/matlab_variables.mat', foldername_output));

    fprintf('\n\nDone!\n');

    % Turn off the diary
    diary('off');
end