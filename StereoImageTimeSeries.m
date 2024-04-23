classdef StereoImageTimeSeries < handle
    %StereoImageTimeSeries for a time-dependent sequence of images
    % Ian Kleckner
    % Interdisciplinary Affective Science Lab (IASL)
    % Continuous Flash Suppression (CFS)
    %
    % 2011/02/23 Start coding
    % 2011/03/13 Change all instances of left -> dom, and right -> nondom
    % 2011/05/04 Enable contrast ramp on top of SITS display
    % 2011/06/02 Allow for ANY_KEY input
    % 2011/09/26 Allow for NO input
    %            Allow for TEXT steps via class TextDisplay
    % 2011/10/12 Update to check for dating profile
    % 2011/10/16 Draw MULTIPLE framing rectangles
    %
    % 2011/10/17 FULL_BLEED to allow any step to have minimum border around
    %            image by modifying DisplaySession.getDestinationRect
    %
    % 2011/10/27 Update flusing textures
    % 2011/10/28 Flush: kill image matrices too
    % 2011/10/30 Flush: kill displayed_image too
    % 2011/11/10 Add setContrastOfCurrentStep
    % 2011/11/16 Add MondrianDisplay support with flag MONDRIAN_DISPLAY
    %               Adding, Displaying, Flushing
    % 2012/03/19 Update Set.element -> Set.element_array
    %
    % TODO
    %
    
        
    properties
        % Note: new properties must be copied in copy()
        Nsteps         = 0;
        current_step   = 1;
        
        % Information about the steps to display
        filename_dom   = {};   % Array of image filenames for dom eye
        filename_nondom  = {};
        
        image_dom      = {};   % Array of loaded images (using imread())
        image_nondom     = {};
        
        texture_dom    = {};   % Textures created for Psychophysics Toolbox
        texture_nondom   = {};
        
        source_mode_dom    = {};   % Mode for which image should be displayed (FIXED, or RANDOM from a POOL)
        source_mode_nondom   = {};
        
        % Display style
        random_style_dom   = {};   % Draw from POOL, display in QUADRANT, display INVERTED, etc.
        random_style_nondom  = {};
        
        % Information about what was actually displayed at each step
        displayed_image_dom    = {};   % Image ACTUALLY displayed (because some are random)
        displayed_image_nondom   = {};
        
        displayed_texture_dom  = {};   % Texture ACTUALLY displayed (becase some are random)
        displayed_texture_nondom = {};
        
        displayed_rotation_dom = {};   % Rotation angle actually displayed (for rotation)
        displayed_rotation_nondom= {};       
        
        displayed_quadrant_dom     = {};   % Destination quadrant actually displayed (for quadrants)
        displayed_quadrant_nondom    = {};
        
        % For returning query of a particular step, side and property
        %  This is used to compare particpant guess for quadrant to actual
        %  quadrant displayed on some step# on either nondom or dom side
        query_step          = NaN;
        query_image         = [];
        query_side          = '';
        query_contrast      = 0;   % Contrast_log10 used for query image        
        
        % Timing elements
        time_zero       = NaN;  % Starting time for display of the first step (via Flip)
        time_zero_tic   = NaN;  % Starting time (via tic())
        start_time      = [];   % Time to start displaying each image        
          
        % Should the SITS be allowed to be interrupted with a keypress
        ALLOW_INPUT     = true;
        INPUT_MODE      = 'DISPLAY_SESSION';    % Get input keys/values from DISPLAY_SESSION
                                                % or from ANY_KEY
        keyPress_Time   = NaN;
        keyPress_String = '';
        keyPress_Value  = NaN;
        
        
        % Contrast ramping overlay
        %  This permits a subset of frames for contrast ramping for the
        %  given step
        %
        %  (1) Store all sub-textures for the step upon loading in addStep()
        %  (2) Display all sub-textures for the step in DisplayStep()
        
        CONTRAST_RAMP       = false;     % (Bool) allow contrast ramping of the SITS series
        contrastUpdateRate  = 60;       % Rate at which contrast should be updated
        
        contrastRamp_dom    = [];       % A piecewise line describing contrast ramp
        contrastRamp_nondom = [];
        
        textureRampMatrix_dom       = {}; % A 2D cell array (stepNum, frameNum)
        textureRampMatrix_nondom    = {};
        
                
        % The display session which instantiates this class type
        %  This is used to access WINDOW handle, and other display
        %  properties
        DS   = NaN;
        
        FULL_BLEED          = [];   % (Boolean) array to alter border to minimum values (0.1%)
                                    % for each step, so it shows as large
                                    % as possible
        
        % Exra output for debugging
        OUTPUT_DEBUG = false;
                
    end
    
    methods
        function obj = StereoImageTimeSeries( DS )
            %% Constructor function (if a PTB Display Session handle already exists)            
            obj.DS = DS;
        end
        
        
        function addImage( obj, start_time, source_mode_dom, filename_dom, source_mode_nondom, filename_nondom )
            %% Adds a step to the series            
            % addImage( START_TIME, SOURCE_MODE_DOMINANT,  DOMINANT_IMAGE_NAME,  SOURCE_MODE_NONDOMINANT,  NONDOMINANT_IMAGE_NAME );
            %
            % START_TIME              -> Time to start displaying image (sec)
            %
            % SOURCE_MODE must be specified for both DOMINANT and NONDOMINANT images
            %  (a) FIXED             -> Display image as fixed orientation and quadrant
            %  (b) RANDOM_POOL       -> Select random image from pool
            %  (c) RANDOM_QUADRANT   -> Randomly select quadrant for display (1,2,3,4)
            %  (d) RANDOM_ROTATION_2 -> Randomly select rotation angle (0, 180)
            %  (e) RANDOM_ROTATION_4 -> Randomly select rotation angle (0, 90, 180, 270)                        
            %  (f) UNCHANGED         -> Display whatever was in the prior step
            %
            % IMAGE_NAME specified for both DOMINANT and NONDOMINANT images
            %  IMAGE             -> Specify image filename

            OUTPUT_DEBUG = obj.OUTPUT_DEBUG;            
            if( OUTPUT_DEBUG )
                [ST,I] = dbstack;                
                fprintf('\n\nFUNCTION: %s', ST(1).name);
            end
            
            s                   = obj.Nsteps+1;
            obj.Nsteps          = obj.Nsteps+1;

            % Get starting time
            obj.start_time(s) = start_time;

            % Check source mode
            obj.source_mode_dom{s}     = source_mode_dom;
            obj.source_mode_nondom{s}    = source_mode_nondom;
            
            % Full bleed default to FALSE
            %  Set otherwise using setFullBleedToCurrentStep
            obj.FULL_BLEED(s) = false;

            % Iterate throuch each side
            for side = {'dom', 'nondom'}
                % Convert from cell to string
                side_name = side{1};

                % Check source mode for input
                eval(sprintf('source_mode = source_mode_%s;', side_name));
                
                if( OUTPUT_DEBUG )
                    fprintf('\nSITS addImage: Loading for side "%s" with source mode %s', side_name, source_mode);
                end

                switch source_mode
                    case {  'FIXED', ...
                            'RANDOM_QUADRANT', ...
                            'RANDOM_ROTATION_2', ...
                            'RANDOM_ROTATION_4' }
                        % Load the single image and create a texture
                        %  eval() command allows for efficient coding of each side (dom/nondom)
                        eval(sprintf('obj.filename_%s{s}= filename_%s;', side_name, side_name));
                        try
                            eval(sprintf('obj.image_%s{s}   = imread(filename_%s);', side_name, side_name));
                        catch ERROR
                            fprintf('\nError trying to read %s or %s\n\n', filename_dom, filename_nondom);
                            rethrow(ERROR);
                        end
                        
                        eval(sprintf('obj.texture_%s{s} = Screen(\''MakeTexture\'', obj.DS.WINDOW, obj.image_%s{s});', side_name, side_name));
                        
                        if( OUTPUT_DEBUG )
                            eval(sprintf('filename = filename_%s;', side_name));
                            fprintf('\n\tLoaded file %s', filename);
                        end

                    case 'RANDOM_POOL'
                        
                        % Initialize a set to store the textures
                        image_set   = Set;
                        texture_set = Set;
                        
                        % Save the filename
                        eval(sprintf('obj.filename_%s{s}= filename_%s;', side_name, side_name));
                        
                        % Get the filenames in the desired directory
                        eval(sprintf('directory = filename_%s;', side_name));
                                                
                        if( OUTPUT_DEBUG )
                            fprintf('\n\tReading from base directory:\t%s', pwd);
                            fprintf('\n\tReading target directory:\t%s', directory);                            
                        end     
                        
                        % Read the directory
                        filedir = dir(directory);                        
                        
                        if( OUTPUT_DEBUG )                            
                            fprintf('\n\tContents of target directory below');
                            filedir
                            fprintf('\n\tLength = %d',length(filedir));
                            %filedir(1).name
                            %filedir(2).name
                            %filedir(3).name
                        end    
                        
                        % Read through each file starting with index 3
                        %  Note: indices 1 and 2 are "." and ".."
                        for f = 3:length(filedir)
                            
                            % Remove any potential double-slashes
                            file = sprintf('%s/%s', directory, filedir(f).name);                            
                            file = strrep( file, '//', '/' );
                            
                            if( ~isempty( strfind(file, 'Thumbs.db')) )
                                continue;
                            end
                            
                            if( OUTPUT_DEBUG )
                                fprintf('\n\t\t(%03d) Trying to read file: %s...', f, file);
                            end
                            
                            try
                                % Load each image and create each texture
                                try
                                    image   = imread( file );
                                catch ERROR
                                    fprintf('\nError trying to read %s\n\n', file);
                                    rethrow ERROR
                                end
                                                                
                                if( OUTPUT_DEBUG )
                                    fprintf('OK!');
                                end
                                
                            catch
                                error('addImage() RANDOM_POOL: Error trying to load image file: %s', file);                                
                            end
                            
                            % Make texture with loaded image
                            texture = Screen('MakeTexture', obj.DS.WINDOW, image);
                            
                            % Add texture to texture set
                            image_set.addElement(image);
                            texture_set.addElement(texture);
                        end
                        
                        % Store the entire image set and texture set
                        eval(sprintf('obj.image_%s{s} = image_set;', side_name));
                        eval(sprintf('obj.texture_%s{s} = texture_set;', side_name));
                        
                    case 'UNCHANGED'
                        if( s > 1 )
                            % Copy contents from prior step
                            eval(sprintf('obj.filename_%s{s}= obj.filename_%s{s-1};', side_name, side_name));
                            try
                                eval(sprintf('obj.image_%s{s}   = imread(obj.filename_%s{s});', side_name, side_name));
                            catch ERORR
                                fprintf('\nError trying to read %s or %s\n\n', filename_dom, filename_nondom);
                                rethrow ERROR
                            end
                            
                            % Copy the texture from the prior step
                            %  Do NOT make a new texture (this will not
                            %  copy the contrast)
                            eval(sprintf('obj.texture_%s{s} = obj.texture_%s{s-1};', side_name, side_name, side_name, side_name));                        
                            
                            %eval(sprintf('obj.texture_%s{s} = Screen(\''MakeTexture\'', obj.DS.WINDOW, obj.image_%s{s});', side_name, side_name));                        
                        else
                            error('Cannot specify UNCHANGED image at first step');
                        end
                        
                    case {'TEXT', 'MONDRIAN_DISPLAY'}
                        % TEXT and MONDRIAN_DISPLAY instances have been
                        % programmed similarly for more efficient coding
                        
                        % Load the specs
                        %  This just renames the input parameter for clarity
                        object = eval( sprintf('filename_%s;', side_name));
                        
                        % Indicate that there is no file
                        NO_FILE_STRING = 'No file used, see obj.texture_{dom,nomdom} instead';
                        eval(sprintf('obj.filename_%s{s}= NO_FILE_STRING;', side_name));
                        
                        % Save a text description of the object depending
                        % on its class type
                        if( isa(object, 'TextDisplay') )                            
                            text_description = object.text;
                            
                        elseif( isa(object, 'MondrianDisplay') )
                            text_description = 'MondrianDisplay instance';
                        else
                            object
                            error('Invalid object type. See code for options');
                        end
                        
                        % Save the text used to the image_{dom, nodom} parameter
                        eval(sprintf('obj.image_%s{s} = text_description;', side_name));
                        
                        % And save the object as a texture
                        eval(sprintf('obj.texture_%s{s} = object;', side_name));
                        
                        % => To display the object, one must call
                        % obj.texture_{dom,nondom}.drawToPTBWindow( obj.DS.WINDOW )
                    
                    otherwise
                        source_mode
                        error('Invalid source mode specified for time series');
                end
                
                if( OUTPUT_DEBUG )
                    fprintf('\nDone!\n');
                end
            end

        end
        
        function SITS_copy = copy( obj )
            %% Create a new class instance with all properties, except it
            %  is as if the SITS has not yet been started
            SITS_copy = StereoImageTimeSeries( obj.DS );
            
            % Copy each element which should not be default value            
            SITS_copy.Nsteps            = obj.Nsteps;
            
            SITS_copy.filename_dom     = obj.filename_dom;
            SITS_copy.filename_nondom    = obj.filename_nondom;
            
            SITS_copy.image_dom        = obj.image_dom;
            SITS_copy.image_nondom       = obj.image_nondom;
            
            SITS_copy.texture_dom      = obj.texture_dom;
            SITS_copy.texture_nondom     = obj.texture_nondom;
            
            SITS_copy.source_mode_dom  = obj.source_mode_dom;
            SITS_copy.source_mode_nondom = obj.source_mode_nondom;
            
            SITS_copy.random_style_dom  = obj.random_style_dom;
            SITS_copy.random_style_nondom  = obj.random_style_nondom;
            
            SITS_copy.query_step        = obj.query_step;
            SITS_copy.query_image       = obj.query_image;
            SITS_copy.query_side        = obj.query_side;            
            SITS_copy.query_contrast    = obj.query_contrast;   
            
            SITS_copy.time_zero        = obj.time_zero;
            SITS_copy.time_zero_tic        = obj.time_zero_tic;
            SITS_copy.start_time        = obj.start_time;
            
            SITS_copy.ALLOW_INPUT        = obj.ALLOW_INPUT;
            SITS_copy.INPUT_MODE        = obj.INPUT_MODE;
            %SITS_copy.keyPress_Time        = obj.keyPress_Time;
            %SITS_copy.keyPress_String        = obj.keyPress_String;
            
            
            SITS_copy.CONTRAST_RAMP             = obj.CONTRAST_RAMP;            
            SITS_copy.contrastUpdateRate        = obj.contrastUpdateRate;
            SITS_copy.contrastRamp_dom          = obj.contrastRamp_dom;
            SITS_copy.contrastRamp_nondom       = obj.contrastRamp_nondom;
            SITS_copy.textureRampMatrix_dom     = obj.textureRampMatrix_dom;
            SITS_copy.textureRampMatrix_nondom  = obj.textureRampMatrix_nondom;
                        
            SITS_copy.DS                = obj.DS;            
            SITS_copy.OUTPUT_DEBUG      = obj.OUTPUT_DEBUG;
            
            SITS_copy.FULL_BLEED                = obj.FULL_BLEED;
        end
        
        function displayCurrentStep( obj )
            %% Displays the current step
            OUTPUT_DEBUG = obj.OUTPUT_DEBUG;
            
            if( OUTPUT_DEBUG )
                [ST,I] = dbstack;                
                fprintf('\n\nFUNCTION: %s', ST(1).name);
            end
            
            s = obj.current_step;            
            
            % Iterate throuch each side
            %  Get rotation and quadrant information
            for side = 0:1
                % Convert from cell to string
                if( side == 0 )
                    side_name       = 'dom';
                    display_side  = obj.DS.DOM_DISPLAY;
                else
                    side_name = 'nondom';
                    display_side  = obj.DS.NONDOM_DISPLAY;
                end

                % Check source mode for input
                eval(sprintf('source_mode = obj.source_mode_%s{s};', side_name));                    

                switch source_mode
                    case 'FIXED'
                        eval(sprintf('image_%s      = obj.image_%s{s};', side_name, side_name));
                        eval(sprintf('texture_%s    = obj.texture_%s{s};', side_name, side_name));
                        eval(sprintf('rotation_%s   = 0;', side_name));
                        eval(sprintf('quadrant_%s   = 0;', side_name));

                    case 'RANDOM_POOL'
                        % TODO % It is likely better to make a random pool
                        % by generating a Set() outside the SITS instance,
                        % and just specifying each image as its own step
                        %
                        % Select random image from pool
                        % Select the image randomly (w/o replacement) and
                        % select the texture via the same random index
                        eval(sprintf('[image_%s, index] = obj.image_%s{s}.getElementRandomNoReplacement();', side_name, side_name));
                        eval(sprintf('texture_%s = obj.texture_%s{s}.element_array{index};', side_name, side_name));
                        eval(sprintf('rotation_%s   = 0;', side_name));
                        eval(sprintf('quadrant_%s   = 0;', side_name));
                        
                        % Debugging output
                        %obj.image_dom{s}
                        %obj.texture_dom{s}
                        %index
                        %texture                        
                        %input '\nHit return';
                        %obj.image_dom{s}.random_index
                        %fprintf('\nSITS RANDOM_POOL index = %d', index);
                        
                    case 'RANDOM_QUADRANT'
                        % Select a random quadrant for display
                        eval(sprintf('image_%s      = obj.image_%s{s};', side_name, side_name));
                        eval(sprintf('texture_%s    = obj.texture_%s{s};', side_name, side_name));
                        eval(sprintf('rotation_%s   = 0;', side_name));
                        eval(sprintf('quadrant_%s   = randi(4,1);', side_name));

                    case 'RANDOM_ROTATION_2'
                        % Randomly select orientation (up/down)
                        eval(sprintf('image_%s      = obj.image_%s{s};', side_name, side_name));
                        eval(sprintf('texture_%s    = obj.texture_%s{s};', side_name, side_name));
                        eval(sprintf('rotation_%s   = 180 * (randi(2,1)-1);', side_name));
                        eval(sprintf('quadrant_%s   = 0;', side_name));

                    case 'RANDOM_ROTATION_4'
                        % Randomly select orientation (up/down/left/right)
                        eval(sprintf('image_%s      = obj.image_%s{s};', side_name, side_name));
                        eval(sprintf('texture_%s    = obj.texture_%s{s};', side_name, side_name));
                        eval(sprintf('rotation_%s   = 90 * (randi(4,1)-1);', side_name));
                        eval(sprintf('quadrant_%s   = 0;', side_name));                        
                        
                    case 'UNCHANGED'
                        % Acquire contents of window at prior step
                        if( s > 1 )
                            %eval(sprintf('image = obj.displayed_image_%s{ s-1 };',side_name));
                            %eval(sprintf('texture = obj.displayed_texture_%s{ s-1 };',side_name));
                            eval(sprintf('image_%s      = obj.image_%s{s};', side_name, side_name));
                            eval(sprintf('texture_%s    = obj.texture_%s{s};', side_name, side_name));
                            
                            % Acquire contents of window at prior step
                            eval(sprintf('rotation_%s = obj.displayed_rotation_%s{ s-1 };',side_name, side_name));
                            eval(sprintf('quadrant_%s = obj.displayed_quadrant_%s{ s-1 };',side_name, side_name));
                            
                        else                            
                            error('Cannot specify UNCHANGED image at first step');
                        end
                        
                    case {'TEXT', 'MONDRIAN_DISPLAY'}
                        % The object instance is stored in the
                        % parameter obj.image_{dom,nondom}
                        
                        % => To display the object, one must call
                        % obj.texture_{dom,nondom}.drawToPTBWindow( obj.DS.WINDOW )
                        
                        % Store the other settings
                        eval(sprintf('image_%s      = obj.image_%s{s};', side_name, side_name));
                        eval(sprintf('texture_%s    = obj.texture_%s{s};', side_name, side_name));
                        eval(sprintf('rotation_%s   = 0;', side_name));
                        eval(sprintf('quadrant_%s   = 0;', side_name)); 
                        
                    otherwise
                        error('Invalid source mode specified to display time series');                        
                end
                
                % Store the displayed image and texture
                % (in case a future "unchanged" needs to access it)
                eval(sprintf('obj.displayed_image_%s{s} = image_%s;',side_name, side_name));
                eval(sprintf('obj.displayed_texture_%s{s} = texture_%s;',side_name, side_name));
                eval(sprintf('obj.displayed_quadrant_%s{s} = quadrant_%s;',side_name, side_name));
                eval(sprintf('obj.displayed_rotation_%s{s} = rotation_%s;',side_name, side_name));
                                
                % Now the rotation and quadrant has been determined
                % Unless there is a contrast ramp to show, just prepare the
                % single frame
                if( ~obj.CONTRAST_RAMP )           
                    
                    eval(sprintf('texture   = texture_%s;', side_name));
                    eval(sprintf('image     = image_%s;', side_name));
                    eval(sprintf('quadrant  = quadrant_%s;', side_name));
                    eval(sprintf('rotation  = rotation_%s;', side_name));                    
                                    
                    if( OUTPUT_DEBUG )
                        fprintf('\nStep %d, side %d (%s), texture %d', s, side, side_name, texture);
                    end
                    
                    % Draw image for current side if possible                
                    if( ~isempty(image) )
                        
                        Screen('SelectStereoDrawBuffer', obj.DS.WINDOW, display_side);
                        
                        % If text or Mondrian display should be displayed
                        if( isa(texture, 'TextDisplay') || isa(texture, 'MondrianDisplay') )
                            texture.drawToPTBWindow(obj.DS.WINDOW, display_side, ...
                                obj.DS.getDestinationRect( image, quadrant, obj.FULL_BLEED(s) ), rotation );
                            
                        else
                            Screen('DrawTexture', obj.DS.WINDOW, texture, [], ...
                                obj.DS.getDestinationRect( image, quadrant, obj.FULL_BLEED(s) ), rotation);
                        end
                        
                        %{
                        % Draw a framing rectangle, if desired
                        if( obj.DS.DRAW_FRAMING_RECTANGLE )
                            % Display a rectangular frame on top of the texture                            
                            Screen('FrameRect', obj.DS.WINDOW, obj.DS.frame_Color, obj.DS.frame_Rect, obj.DS.frame_Width);
                        end
                        %}
                        
                        % Draw a framing rectangle, if desired
                        for fr = 1:obj.DS.NframingRectangles
                            if( obj.DS.DRAW_FRAMING_RECTANGLE(fr) )
                                % Display a rectangular frame on top of the texture                            
                                Screen('FrameRect', obj.DS.WINDOW, obj.DS.frame_Color{fr}, obj.DS.frame_Rect{fr}, obj.DS.frame_Width(fr) );
                            end
                        end
                    end
                end
            end                          
            if( OUTPUT_DEBUG )
                fprintf('\nFinished double-buffering both sides on step %d, Ready to draw...', s);
            end
            
            % Update the display
            if( obj.CONTRAST_RAMP )                
                % Determine number of frames considering the step duration
                if( s == obj.Nsteps )
                    % The last step only has one frame to show (zero duration)
                    stepDuration    = 0;
                    Nframes         = 1;
                else
                    % Other steps have nonzero durations
                    stepDuration    = obj.start_time(s+1) - obj.start_time(s);
                    Nframes         = ceil(stepDuration * obj.contrastUpdateRate);
                end
                f               = 0;
                RECEIVED_INPUT  = false;
                
                if( OUTPUT_DEBUG )
                    fprintf('\nShowing movie for step %d, with duration %0.1f sec and %0.1f frames', ...
                        s, stepDuration, Nframes);
                end
                
                while ~RECEIVED_INPUT && f < Nframes    
                    f = f+1;
                    %fprintf('\n\tFrame %d', f);

                    % Current time for contrast calculation
                    time = obj.start_time(s) + (f-1) / obj.contrastUpdateRate;

                    % DOMINANT image
                    % image was already set from above
                    texture = obj.textureRampMatrix_dom{s,f};
                    Screen('SelectStereoDrawBuffer', obj.DS.WINDOW, obj.DS.DOM_DISPLAY);
                    Screen('DrawTexture', obj.DS.WINDOW, texture, [], ...
                        obj.DS.getDestinationRect( image_dom, quadrant_dom, obj.FULL_BLEED(s) ) );
                    
                    %{
                    % Draw a framing rectangle, if desired
                    if( obj.DS.DRAW_FRAMING_RECTANGLE )
                        % Display a rectangular frame on top of the texture                            
                        Screen('FrameRect', obj.DS.WINDOW, obj.DS.frame_Color, obj.DS.frame_Rect, obj.DS.frame_Width);
                    end
                        %}
                    
                    % Draw a framing rectangle, if desired
                    for fr = 1:obj.DS.NframingRectangles
                        if( obj.DS.DRAW_FRAMING_RECTANGLE(fr) )
                            % Display a rectangular frame on top of the texture                            
                            Screen('FrameRect', obj.DS.WINDOW, obj.DS.frame_Color{fr}, obj.DS.frame_Rect{fr}, obj.DS.frame_Width(fr) );
                        end
                    end

                    % NON-DOMINANT image
                    % image was already set from above
                    texture = obj.textureRampMatrix_nondom{s,f};                        
                    Screen('SelectStereoDrawBuffer', obj.DS.WINDOW, obj.DS.NONDOM_DISPLAY);
                    Screen('DrawTexture', obj.DS.WINDOW, texture, [], ...
                        obj.DS.getDestinationRect( image_nondom, quadrant_nondom, obj.FULL_BLEED(s) ) );
                    
                    %{
                    % Draw a framing rectangle, if desired
                    if( obj.DS.DRAW_FRAMING_RECTANGLE )
                        % Display a rectangular frame on top of the texture                            
                        Screen('FrameRect', obj.DS.WINDOW, obj.DS.frame_Color, obj.DS.frame_Rect, obj.DS.frame_Width);
                    end
                        %}
                    
                    % Draw a framing rectangle, if desired
                    for fr = 1:obj.DS.NframingRectangles
                        if( obj.DS.DRAW_FRAMING_RECTANGLE(fr) )
                            % Display a rectangular frame on top of the texture                            
                            Screen('FrameRect', obj.DS.WINDOW, obj.DS.frame_Color{fr}, obj.DS.frame_Rect{fr}, obj.DS.frame_Width(fr) );
                        end
                    end


                    if( s == 1 )
                        % Need to play movie for first step
                        obj.time_zero_tic   = tic();
                        obj.time_zero       = Screen('Flip', obj.DS.WINDOW );
                    else
                        Screen('Flip', obj.DS.WINDOW, obj.time_zero + time);
                    end                    

                    if( obj.ALLOW_INPUT && s > 1 )
                        % Check the state of the keyboard.
                        [ keyIsDown, seconds, keyCode ] = KbCheck;
                        if( keyIsDown )
                            obj.keyPress_String     = KbName(keyCode);
                            obj.keyPress_Time       = toc(obj.time_zero_tic);
                            
                            switch upper(obj.INPUT_MODE)
                                case 'ANY_KEY'
                                    
                                    % Any key value assigned to zero
                                    obj.keyPress_Value = 0;
                                    
                                    % Reset the sequence in case it should be displayed again
                                    obj.current_step = 1;
                                    return
                                    
                                case 'DISPLAY_SESSION'
                            
                                    % Check each valid responseKey
                                    for k = 1:length(obj.DS.responseKeys)                                    
                                        if( keyCode(obj.DS.responseKeys{k}) )
                                            % Found a valid key
                                            %  Store the response value
                                            %obj.response_value(s)    = responseValues(k);
                                            %obj.response_time(s)     = toc(response_time_start);

                                            obj.keyPress_Value = obj.DS.responseValues(k);

                                            if( OUTPUT_DEBUG )
                                                fprintf('\nYou pressed %s at time %f', obj.keyPress_String, obj.keyPress_Time);
                                            end

                                            % Reset the sequence in case it should be displayed again
                                            obj.current_step = 1;
                                            return
                                        end               
                                    end
                                    
                                otherwise
                                    error('Invalid INPUT_MODE found. Check code');
                            end                            
                        end
                    end
                end
                
            else                
                % No movie to display, just single frame instead
                if( OUTPUT_DEBUG )
                    fprintf('\tNo movie: ');                 
                end
                if( s == 1 )             
                    obj.time_zero_tic   = tic();
                    obj.time_zero       = Screen('Flip', obj.DS.WINDOW );  
                else                    
                    % Subsequent steps are displayed at desired time
                    Screen('Flip', obj.DS.WINDOW, obj.time_zero + obj.start_time(s) );
                end
                
                if( obj.ALLOW_INPUT && s > 1 )
                    % Check the state of the keyboard.
                    [ keyIsDown, seconds, keyCode ] = KbCheck;
                    if( keyIsDown )
                        obj.keyPress_String     = KbName(keyCode);
                        obj.keyPress_Time       = toc(obj.time_zero_tic);

                        switch upper(obj.INPUT_MODE)
                            case 'ANY_KEY'

                                % Any key value assigned to zero
                                obj.keyPress_Value = 0;

                                % Reset the sequence in case it should be displayed again
                                obj.current_step = 1;
                                return

                            case 'DISPLAY_SESSION'

                                % Check each valid responseKey
                                for k = 1:length(obj.DS.responseKeys)                                    
                                    if( keyCode(obj.DS.responseKeys{k}) )
                                        % Found a valid key
                                        %  Store the response value
                                        %obj.response_value(s)    = responseValues(k);
                                        %obj.response_time(s)     = toc(response_time_start);

                                        obj.keyPress_Value = obj.DS.responseValues(k);

                                        if( OUTPUT_DEBUG )
                                            fprintf('\nYou pressed %s at time %f', obj.keyPress_String, obj.keyPress_Time);
                                        end

                                        % Reset the sequence in case it should be displayed again
                                        obj.current_step = 1;
                                        return
                                    end               
                                end

                            otherwise
                                error('Invalid INPUT_MODE found. Check code');
                        end                            
                    end
                end
            end
            
            if( OUTPUT_DEBUG )
                fprintf('\nDrew step %d', s)
            end
                
            if( s < obj.Nsteps )
                % Increment to next step, and update again
                obj.current_step = s+1;
                obj.displayCurrentStep()
            else
                % Reset the sequence in case it should be displayed again
                obj.current_step = 1;
            end         
   
        end
        
        function flushAllTextures(obj)
            %% Clear the textures that are already loaded
            % in texture_dom/nondom and in ContrastRamp
            % 2011/06/?? Remove contrastRamp textures (textureRampMatrix_dom/nondom)
            % 2011/07/14 Remove texture_dom textures
            % 2011/09/27 Remove TextDisplay instances
            % 2011/10/27 Add debugging output
            
            OUTPUT_DEBUG = false;
            if( OUTPUT_DEBUG )
                [ST,I] = dbstack;                
                fprintf('\n\nFUNCTION: %s', ST(1).name);
            end
            
            % Check how many windows are open before flushing
            NWindows_PreFlush = obj.DS.getNumberOfWindows();
            
            % Maximum number of textures in a given step
            NMaxFrames = size(obj.textureRampMatrix_dom,2);            
            
            for s = 1:obj.Nsteps                
                if( OUTPUT_DEBUG )
                    fprintf('\n\tChecking step %d', s);
                    fprintf('\n\t\t*Total number of windows: %d', obj.DS.getNumberOfWindows());
                end
                
                % Check standard textures
                % Check if the texture exists, then try to close it
                tex = obj.texture_dom{s};            
                
                if( OUTPUT_DEBUG )
                    fprintf('\n\t\tChecking DOMINANT texture');
                    disp(tex);
                end
                
                if( ~isempty(tex) )  
                    
                    % Some textures are actually SETS of textures
                    %  E.g., RANDOM_POOL mode
                    if( isa(tex,'Set') )
                        % Iterate through each element of the set
                        for t = 1:tex.Nelements
                            % Remove each element
                            tex_element = tex.element_array{t};
                            if( obj.DS.isAWindow(tex_element) )
                                Screen('Close', tex_element);
                                % Close image matrix as well
                                %obj.image_dom{s}.element_array{t} = [];
                                if( OUTPUT_DEBUG )
                                    fprintf('\n\t\tClosed texture element and image matrix!');
                                end
                            end
                        end
                        
                    elseif( isa(tex,'TextDisplay') || ... 
                        isa(tex,'DatingProfile') )                        
                        if( OUTPUT_DEBUG )
                            fprintf('\n\t\tSet to null!');
                        end
                        
                    elseif( isa(tex,'MondrianDisplay') )
                        tex.flushAllTextures();
                        if( OUTPUT_DEBUG )
                            fprintf('\n\t\tFlushed MondrianDisplay textures!');
                        end
                        
                    else
                        if( obj.DS.isAWindow(tex) )
                            Screen('Close', tex);
                            if( OUTPUT_DEBUG )
                                fprintf('\n\t\tClosed texture!');
                            end
                        end
                    end
                    
                    % Set it to null
                    obj.texture_dom{s} = [];
                    obj.image_dom{s} = [];
                    obj.displayed_image_dom{s} = [];
                else
                    if( OUTPUT_DEBUG )
                        fprintf('\n\t\tNo texture to close!');
                    end
                end
                
                if( OUTPUT_DEBUG )
                    fprintf('\n\t\t*Total number of windows: %d', obj.DS.getNumberOfWindows());
                end

                %----------------------------------------------------------
                % Nondominant side (same as above)
                tex = obj.texture_nondom{s};  
                
                if( OUTPUT_DEBUG )
                    fprintf('\n\t\tChecking NON-DOMINANT texture');
                    disp(tex);
                end
                if( ~isempty(tex) )
                    if( isa(tex,'Set') )
                        % Iterate through each element of the set
                        for t = 1:tex.Nelements
                            % Remove each element
                            tex_element = tex.element_array{t};
                            
                            if( obj.DS.isAWindow(tex_element) )
                                Screen('Close', tex_element);
                                
                                % Close image from set as well
                                %obj.image_nondom{s}.element_array{t} = [];
                                if( OUTPUT_DEBUG )
                                    fprintf('\n\t\tClosed texture element!');
                                end                                
                            end
                        end
                        
                    elseif( isa(tex,'TextDisplay') || isa(tex,'DatingProfile') )                                               
                        if( OUTPUT_DEBUG )
                            fprintf('\n\t\tSet to null!');
                        end
                        
                    elseif( isa(tex,'MondrianDisplay') )
                        tex.flushAllTextures();
                        if( OUTPUT_DEBUG )
                            fprintf('\n\t\tFlushed MondrianDisplay textures!');
                        end
                        
                    else
                        if( obj.DS.isAWindow(tex) )
                            Screen('Close', tex);
                            if( OUTPUT_DEBUG )
                                fprintf('\n\t\tClosed texture!');
                            end
                        end
                    end
                    
                    % Clear it
                    obj.texture_nondom{s} = [];
                    obj.image_nondom{s} = [];
                    obj.displayed_image_nondom{s} = [];
                    
                else
                    % Texture is []
                    if( OUTPUT_DEBUG )
                        fprintf('\n\t\tNo texture to close!');
                    end
                end
                
                if( OUTPUT_DEBUG )
                    fprintf('\n\t\t*Total number of windows: %d', obj.DS.getNumberOfWindows());
                end
                
                %----------------------------------------------------------
                % Check contrast ramp textures
                if( OUTPUT_DEBUG )
                    fprintf('\n\t\tChecking CONTRAST RAMP textures (%d frames total)', NMaxFrames);                    
                end
                
                for f = 1:NMaxFrames
                    if( OUTPUT_DEBUG )
                        fprintf('\n\t\tChecking frame %d', f);
                    end
                    
                    % Check if the texture exists, then try to close it
                    tex = obj.textureRampMatrix_dom{s,f};      
                    if( OUTPUT_DEBUG )
                        fprintf('\n\t\tChecking DOMINANT texture');
                        disp(tex);
                    end
                    if( obj.DS.isAWindow(tex) )
                        Screen('Close', tex);
                        obj.textureRampMatrix_dom{s,f} = [];
                        if( OUTPUT_DEBUG )
                            fprintf('\n\t\tClosed texture!');
                        end
                    else
                        if( OUTPUT_DEBUG )
                            fprintf('\n\t\tNo texture to close!');
                        end
                    end
                    if( OUTPUT_DEBUG )
                        fprintf('\n\t\t*Total number of windows: %d', obj.DS.getNumberOfWindows());
                    end
                    
                    %------------------------------------------------------
                    % Nondominant ramps (same as above)
                    tex = obj.textureRampMatrix_nondom{s,f};  
                    if( OUTPUT_DEBUG )
                        fprintf('\n\t\tChecking NON-DOMINANT texture');
                        disp(tex);
                    end
                    if( obj.DS.isAWindow(tex) )
                        Screen('Close', tex);
                        obj.textureRampMatrix_nondom{s,f} = [];
                        if( OUTPUT_DEBUG )
                            fprintf('\n\t\tClosed texture!');
                        end
                    else
                        if( OUTPUT_DEBUG )
                            fprintf('\n\t\tNo texture to close!');
                        end
                    end
                    
                    if( OUTPUT_DEBUG )
                        fprintf('\n\t\t*Total number of windows: %d', obj.DS.getNumberOfWindows());
                    end
                end
            end
            
            % Check how many windows are open AFTER flushing
            NWindows_PostFlush = obj.DS.getNumberOfWindows();
            if( 0 )
                fprintf('\n\t\t** Flushed %d textures from StereoImageTimeSeries (%d -> %d)', ...
                    (NWindows_PreFlush - NWindows_PostFlush), NWindows_PreFlush, NWindows_PostFlush);            
            end
        end
        
        function [inputReceived, keyPress_Time, keyPress_Value] = getInput( obj )
            %% Get the input time and string
            
            % Check for valid input from the user
            if( ~obj.ALLOW_INPUT || isnan(obj.keyPress_Time) )
                inputReceived       = false;
                keyPress_Time       = NaN;
                keyPress_Value      = NaN;
                
            else
                % There is valid input
                inputReceived       = true;
                keyPress_Time       = obj.keyPress_Time;
                keyPress_Value      = obj.keyPress_Value;
            end
        end
        
        function state = getQueryImageState( obj, property )
            %% Get the user's result for the property / slide combination
            % Must first set the query image
            %
            % See: setQueryImage
            
            if( isnan(obj.query_step) )
                error('Must set query image via setQueryImage(side) before trying to access its state');
            end
            
            % This can only be shown if the step has been displayed
            %  Note: the side doesn't matter here (yet)
            if( obj.query_step > length(obj.displayed_rotation_dom) )
                error('Desired query step has not been displayed yet');
            end
            
            % Make sure the request property is valid
            if( strcmpi(property, 'QUADRANT') || strcmpi(property, 'ROTATION') )                
                % Obtain the state based on variable name
                eval(sprintf('state = obj.displayed_%s_%s{%d};', ...
                    lower(property), ...
                    lower(obj.query_side), ...
                    obj.query_step));
                                
            elseif( strcmpi(property, 'CONTRAST') || strcmpi(property, 'CONTRASTLOG10') )                
                state = obj.query_contrast;
                
            else
                error('Invalid property. Use QUADRANT or ROTATION or CONTRAST');
            end       
        end
        
        function SITS_specs = getSpecs( obj )
            %% Return a SITS instance which only has the specifications
            % without the images and textues (to save memory)               
            SITS_specs = StereoImageTimeSeries( obj.DS );
            
            % Copy each element which should not be default value            
            SITS_specs.Nsteps            = obj.Nsteps;
            SITS_specs.filename_dom     = obj.filename_dom;
            SITS_specs.filename_nondom    = obj.filename_nondom;
            %SITS_specs.image_dom        = obj.image_dom;
            %SITS_specs.image_nondom       = obj.image_nondom;
            %SITS_specs.texture_dom      = obj.texture_dom;
            %SITS_specs.texture_nondom     = obj.texture_nondom;
            SITS_specs.source_mode_dom  = obj.source_mode_dom;
            SITS_specs.source_mode_nondom = obj.source_mode_nondom;
            SITS_specs.start_time        = obj.start_time;
            SITS_specs.DS                = obj.DS;
            SITS_specs.query_step        = obj.query_step;
            SITS_specs.query_side        = obj.query_side;
            SITS_specs.query_image       = obj.query_image;
            SITS_specs.query_contrast    = obj.query_contrast;  
            
            % Also copy the info on WHAT was displayed (if anything)
            %  Note: this is not copied in the copy() function because that
            %  is designed to make a copy as if it were not yet displayed
            SITS_specs.random_style_dom             = obj.random_style_dom;
            SITS_specs.random_style_nondom          = obj.random_style_nondom;
            %SITS_specs.displayed_image_dom          = obj.displayed_image_dom;
            %SITS_specs.displayed_image_nondom       = obj.displayed_image_nondom;
            %SITS_specs.displayed_texture_dom        = obj.displayed_texture_dom;
            %SITS_specs.displayed_texture_nondom     = obj.displayed_texture_nondom;
            SITS_specs.displayed_rotation_dom       = obj.displayed_rotation_dom;
            SITS_specs.displayed_rotation_nondom    = obj.displayed_rotation_nondom;
            SITS_specs.displayed_quadrant_dom       = obj.displayed_quadrant_dom;
            SITS_specs.displayed_quadrant_nondom    = obj.displayed_quadrant_nondom;
            
        end
        
        function setAllowInput(obj, ALLOW_INPUT, INPUT_MODE)
            %% (Boolean) Allow input to interrupt CFS display
            % INPUT_MODE = DISPLAY_SESSION or ANY_KEY
            % 2011/09/26 Updated for NO INPUT
            
            obj.ALLOW_INPUT = ALLOW_INPUT;
            
            if( ALLOW_INPUT )
                switch upper(INPUT_MODE)
                    case {'DISPLAYSESSION', 'DISPLAY_SESSION'}
                        obj.INPUT_MODE = 'DISPLAY_SESSION';

                    case {'ANY', 'ANYKEY', 'ANY_KEY'}
                        obj.INPUT_MODE = 'ANY_KEY';

                    otherwise
                        error('Invalid INPUT_MODE specified (see code)');                    
                end
            else
                obj.INPUT_MODE = 'NONE';
            end
        end
        
        function setContrastOfCurrentStep( obj, contrast_log10, side_string )
            %% Set the contrast for image at prior step
            % contrast_log10
            % side is DOMINANT or NONDOMINANT
            % 2011/11/10
            
            % Check that a valid side has been submitted
            %  Format the side name properly
            switch upper(side_string)
                case {'DOMINANT', 'DOM'}
                    side = 'dom';
                    
                case {'NONDOMINANT', 'NONDOM'}
                    side = 'nondom';
                    
                otherwise
                    error('Invalid side. Use either DOMINANT or NONDOMINANT');            
            end
            
            % Get the image from this step
            image_in    = eval(sprintf('obj.image_%s{%d}', side, obj.Nsteps));
            
            % Input image tones spans the full range (0 to 1)
            in_low      = 0;
            in_high     = 1;
            
            % Output image tones are in the range centered around 0.5 (gray)
            %  Lower contrast is more gray (closer to 0.5)
            out_low     = 0.5 - 0.5*( 10^contrast_log10 );
            out_high    = 0.5 + 0.5*( 10^contrast_log10 );

            % Apply image adjustment
            image_out = imadjust(image_in, [in_low in_high], [out_low out_high]);
            
            % Set this to the appropriate step
            eval(sprintf('obj.image_%s{%d}   = image_out;', side, obj.Nsteps));
            
            % Make a new texture
            eval(sprintf('obj.texture_%s{%d} = Screen(\''MakeTexture\'', obj.DS.WINDOW, obj.image_%s{%d});', ...
                side, obj.Nsteps, side, obj.Nsteps));      
        end
        
        function setContrastRamp( obj, CONTRAST_RAMP, contrastUpdateRate, ...
                contrastRamp_dom, contrastRamp_nondom )
            %% Set parameters for the contrast ramp            
            
            % (Bool) allow contrast ramping of the SITS series
            obj.CONTRAST_RAMP       = CONTRAST_RAMP;
            if( ~CONTRAST_RAMP )
                obj.contrastUpdateRate  = NaN;
                obj.contrastRamp_dom    = [];
                obj.contrastRamp_nondom = [];
                return
            end
            
            % Make sure argument is proper class before setting variable
            if( isa(contrastRamp_dom, 'PiecewiseLine') && ...
                isa(contrastRamp_nondom, 'PiecewiseLine') )
                obj.contrastRamp_dom    = contrastRamp_dom;
                obj.contrastRamp_nondom = contrastRamp_nondom;
            else
                error('Contrast ramp must be PiecewiseLine instance');
            end
            
            obj.contrastUpdateRate  = contrastUpdateRate;
            
            % Re-calculate all the movies at each step
            obj.updateContrastRamp();
        end
        
        function setFullBleedToCurrentStep( obj, FULL_BLEED )
            %% Specify whether step is drawn as full bleed (with minimum
            % window border percent)
            % Default is FALSE
            %
            % 2011/10/18 Start coding
            
            error('Must check that this code works properly [IK, 2011/10/18]');
            
            s =  obj.Nsteps;
            obj.FULL_BLEED(s) = FULL_BLEED;
        end
        
        function setOutputDebug( obj, OUTPUT_DEBUG )
            %% Sets output debugging flag
            obj.OUTPUT_DEBUG = OUTPUT_DEBUG;
            
        end
        
        function setQueryImage( obj, side )
            %% Sets this step number as the one to be queried for properties
            %  Specify the image on side 'DOMINANT' or 'NOMDOMINANT'
            %  Usage: put this line after the addImage() line
            %  corresponding to the query image
            %
            % See: getQueryImageState
            % TODO % Cannot query image on a RANDOM_POOL (not important)
            
            % Check that a valid side has been submitted
            %  Format the side name properly
            switch upper(side)
                case {'DOMINANT', 'DOM'}
                    side = 'dom';
                    
                case {'NONDOMINANT', 'NONDOM'}
                    side = 'nondom';
                    
                otherwise
                    error('Invalid side. Use either DOMINANT or NONDOMINANT');            
            end
            
            % Make sure there is a step to be added
            if( obj.Nsteps == 0  )
                error('Must add an image before setting it as the query image');
            end
            
            % Check if there is a random pool style display
            eval(sprintf('source_mode = obj.source_mode_%s{obj.Nsteps};', lower(side)));
            if( strcmpi(source_mode,'RANDOM_POOL') )
                error('Cannot query an image from a random pool, since there are multiple source images.');
            end

            % Save the source image for manipulate later (e.g., via contrast)            
            eval(sprintf('obj.query_image = obj.image_%s{obj.Nsteps};', lower(side)));
            obj.query_step      = obj.Nsteps;
            obj.query_side      = lower(side);
        end              
        
        function setQueryImageContrast( obj, contrast_log10 )
            %% Set the contrast for the query image using the unaltered source
            % Must first set the query image
            %
            % See: setQueryImage
            
            if( isempty(obj.query_image) )
                error('Must set query image via setQueryImage(side) before trying to set its contrast');
            end
            
            % Input image tones spans the full range (0 to 1)
            in_low      = 0;
            in_high     = 1;
            
            % Output image tones are in the range centered around 0.5 (gray)
            %  Lower contrast is more gray (closer to 0.5)
            out_low     = 0.5 - 0.5*( 10^contrast_log10 );
            out_high    = 0.5 + 0.5*( 10^contrast_log10 );

            % Apply image adjustment
            image_out = imadjust(obj.query_image, [in_low in_high], [out_low out_high]);
            
            % Set this to the appropriate step
            eval(sprintf('obj.image_%s{%d}   = image_out;', obj.query_side, obj.query_step));
            
            % Make a new texture
            eval(sprintf('obj.texture_%s{%d} = Screen(\''MakeTexture\'', obj.DS.WINDOW, obj.image_%s{%d});', ...
                obj.query_side, obj.query_step, obj.query_side, obj.query_step));
            
            % Log the contrast used
            obj.query_contrast = contrast_log10;
            
            
            % If the next step is UNCHANGED, then this image must be copied
            % there too (2011/05/08)            
            for s = obj.query_step+1:obj.Nsteps
                % Now "mode_nextStep" holds the display mode for next step
                % on the same side
                eval( sprintf('mode_nextStep = obj.source_mode_%s{s};', obj.query_side) );
               
                % If the next step is UNCHANGED...
                if( strcmpi(mode_nextStep, 'UNCHANGED') )
                    % ... then changing THIS step will affect it
                    eval(sprintf('obj.filename_%s{s}= obj.filename_%s{s-1};',   obj.query_side, obj.query_side));
                    eval(sprintf('obj.image_%s{s}   = obj.image_%s{%d};',       obj.query_side, obj.query_side, obj.query_step ));
                    eval(sprintf('obj.texture_%s{s} = obj.texture_%s{%d};',     obj.query_side, obj.query_side, obj.query_step));                        
                
                else
                    return
                end
            end            
        end
        
        function updateContrastRamp(obj)
            %% Update the loaded images using the contrast ramp
            % Goal: take each texture at each step and create an array of
            % textures (frames) for the step
            %  I.e., extrapolate each step into 2D series of frames duration of step  
            
            OUTPUT_DEBUG = obj.OUTPUT_DEBUG;
            
            % Source textures (already loaded)
            %texture_dom    = {};
            %texture_nondom   = {};
            
            % Start time for each step
            %start_time      = [];
            
            % A piecewise line describing contrast ramp at any time
            %contrastRamp_dom    = [];
            %contrastRamp_nondom = [];
            
            % Rate at which contrast should be updated
            %contrastUpdateRate  = 1/60;
            
            % Input image tones spans the full range (0 to 1)
            in_low      = 0;
            in_high     = 1;

            % Destination movies (texture arrays) for each step
            %  A 2D cell array (stepNum, frameNum)
            obj.textureRampMatrix_dom       = {};
            obj.textureRampMatrix_nondom    = {};
                        
            % Iterate through each step
            for s = 1:obj.Nsteps
                % Determine duration of movie
                % Total number of frames for the step
                if( s == obj.Nsteps )
                    stepDuration    = 0;
                    Nframes         = 1;
                else
                    stepDuration    = obj.start_time(s+1) - obj.start_time(s);
                    Nframes         = ceil(stepDuration * obj.contrastUpdateRate);
                end                
                
                if( OUTPUT_DEBUG )
                    fprintf('\nMaking movie for step %d, with duration %0.1f sec and %0.1f frames\n\t', ...
                        s, stepDuration, Nframes);
                end
                                
                % Make movie for this step
                updateInterval = 10;
                for f = 1:Nframes
                    if( mod(f,updateInterval)==0 )
                        %fprintf('\n%d / %d', f, Nframes);
                        fprintf('X');
                    end

                    % Current time
                    time = obj.start_time(s) + (f-1) / obj.contrastUpdateRate;

                    % DOMINANT IMAGE
                    currentContrast = obj.contrastRamp_dom.getY(time);
                    
                    % Output image tones are in the range centered around 0.5 (gray)
                    %  Lower contrast is more gray (closer to 0.5)
                    out_low     = 0.5 - 0.5*( 10^currentContrast );
                    out_high    = 0.5 + 0.5*( 10^currentContrast );

                    % Apply image adjustment
                    image_out = imadjust(obj.image_dom{s}, [in_low in_high], [out_low out_high]);    
                    obj.textureRampMatrix_dom{s,f} = Screen('MakeTexture', obj.DS.WINDOW, image_out);
                    if( OUTPUT_DEBUG )
                        fprintf('\n\tAdded texture to step %d, frame %d, side DOM - %d', s, f, obj.textureRampMatrix_dom{s,f});
                    end
                                        
                    % NOMDOMINANT IMAGE
                    currentContrast = obj.contrastRamp_nondom.getY(time);

                    % Output image tones are in the range centered around 0.5 (gray)
                    %  Lower contrast is more gray (closer to 0.5)
                    out_low     = 0.5 - 0.5*( 10^currentContrast );
                    out_high    = 0.5 + 0.5*( 10^currentContrast );

                    % Apply image adjustment
                    image_out = imadjust(obj.image_nondom{s}, [in_low in_high], [out_low out_high]);    
                    obj.textureRampMatrix_nondom{s,f} = Screen('MakeTexture', obj.DS.WINDOW, image_out);
                    if( OUTPUT_DEBUG )
                        fprintf('\n\tAdded texture to step %d, frame %d, side NONDOM - %d', s, f, obj.textureRampMatrix_nondom{s,f});
                    end
                end
            end
            
            %obj.textureRampMatrix_dom
            %obj.textureRampMatrix_nondom
        end        
    end
end
