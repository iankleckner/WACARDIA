
classdef DisplaySession < handle
    %DisplaySession For a sequence of stereo-image presntations, with user input    
    % Ian Kleckner
    % Interdisciplinary Affective Science Lab (IASL)
    % Continuous Flash Suppression (CFS)
    %
    % 2011/02/19 Start coding
    % 2011/02/23 Move getDestinationRect() to separate file
    %            Add StereoImageTimeSeries
    % 2011/03/13 Change all instances of left -> dom, and right -> nondom
    % 2011/05/04 Store input from SITS, if necessary
    % 2011/05/05 Add DELAY mode
    % 2011/05/08 Change pp_response_value from cell {} to array []
    %            Change keyboard input to number pad too
    % 2011/09/25 Update to receive space bar input
    % 2011/10/04 Allow TIMEOUT on INPUT steps using obj.input_timeout
    % 2011/10/05 Add ability to display text using display_text,
    %            textDisplay() -- also used for DatingProfile class
    % 2011/10/12 NAVIGATE_FORWARD
    %            Response key 5% with value 5
    % 2011/10/16 Add multiple framing rectangles
    % 2011/10/17 NAVIGATE_FORWARD_ANYKEY
    %            FULL_BLEED to allow any step to have minimum border around
    %            image by modifying getDestinationRect
    % 2011/10/20 FIX number of framing rectangle bug
    %            setInputKeys used to change INPUT values
    %
    % 2011/10/22 Store and display timing info on 'Flip' commands
    %
    % 2011/10/27 Update flusing textures
    %            rebootScreen
    %
    % 2011/10/28 Flush: kill image matrices too
    % 2011/10/30 Flush: kill ALL SITS at each flush since these are copies
    %            of the ones in the parent workspace
    %
    % 2011/11/01 Combine with updates from other DisplaySession.m files -> output for timing
    %            Updated default keyboard input
    %            Add INPUT_SLIDER type of input with sliderScale_array
    %            Update obj.pp_Nsteps into INPUT logging for SITS
    % 2011/11/15 getRectWithinBorder
    % 2012/02/23 Update addStep() so filename_nondom = [] sets it to same
    %            as filename_dom
    % 2012/03/20 ALLOW_MOUSE_INPUT to proceed with NAVIGATE_FORWARD_ANYKEY
    % 2017/05/26 Mouse input on INPUT steps
    %
    %
    % TODO
    %  - Store the start time for the program ?
    %  - Read input file
    %  - Change strings 'TIMESERIES' to a variable TIMESERIES that equals 'TIMESERIES' (to catch typos)
    
    
    properties (SetAccess = private)
        %% These can only be set via functions (but can be read directly via "."
        
        % ------------- Variables for defining available steps -----------
        % Information about the steps to display
        Nsteps          = 0;    % Number of steps in session        
        step_type       = {};   % String identifying INPUT, NAVIGATE, or TIMESERIES        
        
        % For INPUT or NAVIGATE steps, that each show a single image
        filename_dom   = {};   % Array of image filenames for dom eye
        filename_nondom  = {};
        
        image_dom      = {};   % Array of loaded images (using imread())
        image_nondom     = {};
        
        texture_dom     = {};   % Textures created for Psychophysics Toolbox
        texture_nondom   = {};
        
        responseKeys    = [];
        responseValues  = [];
        responseValues_Mouse = [];
        
        nextKey     = NaN;
        previousKey = NaN;
        
        input_timeout   = [];   % Time allowed for input before proceeding (for INPUT steps only)
        
        ALLOW_MOUSE_INPUT = true;   % Allow mouse click to advance NAVIGATE_FORWARD_ANYKEY step
        
        % For DELAY step
        delay_time      = [];       % Delay time in seconds (only applies for DELAY step)
        
        % For TIMESERIES step type
        SITS        = {}; % Cell array of the StereImageTimeSeries instances        
        
        
        %response_value          = [];   % Value of response key pressed by user
        %response_time           = [];   % Time for response after slide is shown
        
        %query_rotation          = [];
        %query_quadrant          = [];
        %query_contrast_log10    = [];
        
        
        % For displaying TEXT in addition to navigating
        %  TEXT can also be DatingProfile class (both have same function
        %  for drawing text to window called "drawToPTBWindow()"
        display_text    = [];   % Boolean
        textDisplay     = [];   % Instance of the TextDisplay or DatingProfile class
        
        
        % --------- Variables for participant experience through session
        % The participant (pp) may move forward/backward through steps, and so each of
        % these displays are logged with their time of display
        current_step        = 1;    % Current step number
        
        %Nsteps_displayed    = 0;    % Steps are marked once they are displayed
        %steps_displayed     = [];   % Order of each step        
        
        start_tic           = 0;    % Holds the "tic" command upon display of first step
        start_time_flip     = [];   % Holds time of first Screen('Flip') command
        etime_flip          = [];   % Array of elapsed time for each Flip command        
        OUTPUT_DEBUG_TIMING = false; % Write timing to command window

        
        pp_Nsteps                       = 0;    % Number of steps the participant has traversed
        pp_steps_traversed              = [];   % Each element is the step number displayed
        pp_etime                        = [];   % Holds time at which each step was started
        
        pp_response_value               = [];   % Value of response key pressed
        pp_response_time                = [];   % Time for response after slide is shown
        pp_SITS_specs                   = {};   % Cell array of specifications for each instance of SITS
        pp_query_image_rotation         = [];   % Rotation of the query image in a StereoImageTimeSeries
        pp_query_image_quadrant         = [];   % Quadrant
        pp_query_image_contrastlog10    = [];   % Contrast
        
        % --------------- Variables for display ---------------------------
        % Stereo / mono mode (Note: program only works in stereo, now)        
        presentation_mode   = {};   % Cell array of presentation mode (stereo / full)
        is_stereo           = {};   % (Boolean) the current step is stereo mode        
        stereoMode         = 4;    % Stereo-mode from PTB (4=>Split display on single monitor)        
        
        LEFT_DISPLAY        = 0;    % Left display is #0 (for stereo-mode)
        RIGHT_DISPLAY       = 1;    % Right display is #1 (for stereo-mode)
        
        DOM_DISPLAY         = 0;    % The dominant side (0,1)=(left,right)
        NONDOM_DISPLAY      = 1;        
        
        % How the class displays the steps using PTB
        WINDOW          = NaN;      % Window handle for psychophysics toolbox
                                    % Required for creating textures
                                    
        rectWindow          = [];   % Window rectangle (size and position)
        
        % This specifies the percentage of the window width (or height)
        %  used to border each image (must be < 50)
        % Some images need enlargement, and some reduction, to fit the window
        minBorderPercent        = 10;
        
        fullBleedBorderPercent  = 0.1;
        FULL_BLEED              = [];   % (Boolean) array to alter border to minimum values (0.1%)
                                        % for each step, so it shows as large
                                        % as possible
        
        % --------------- Frame rectangle around all images (2011/07/14) --
        % Add multiple framing rectangles [2011/10/16]
        NframingRectangles      = 0;
        
        % These properties are all ARRAYS or CELL ARRAYs
        DRAW_FRAMING_RECTANGLE  = [];            % (true/false) Draw the rectangle
        frame_Color             = {};    % 0-255 [R G B] color triplet
        frame_Width             = [];                % Width of rectangle line in pixels
        frame_Rect              = {};        % RECT = [X_Left, Y_Top, X_Width, Y_Height]
        
        %-------------------------------------------
        % Slider scale type of input with INPUT_SLIDER step type
        % [2011/11/02]
        sliderScale_array = {};
        
    end
        
    methods
        function obj = DisplaySession( WINDOW )
            %% Constructor function (if a PTB WINDOW handle already exists)           
            if( nargin == 1 )
                obj.WINDOW = WINDOW;
            end
            
            KbName('UnifyKeyNames');
            
            if( IsWin )
                % KbDemo
                % 1 of 4.  Testing KbCheck and KbName: press a key to see its number.
                % Press the escape key to proceed to the next demo.
                % You pressed key 97 which is 1
                % You pressed key 98 which is 2
                % You pressed key 99 which is 3
                % You pressed key 100 which is 4
                % You pressed key 101 which is 5
                % You pressed key 102 which is 6
                % You pressed key 103 which is 7
                % You pressed key 104 which is 8
                % You pressed key 105 which is 9
                % You pressed key 96 which is 0
                % 1234567890
                % You pressed key 13 which is Return
                % You pressed key 49 which is 1!
                % You pressed key 50 which is 2@
                % You pressed key 51 which is 3#
                % You pressed key 52 which is 4$
                % You pressed key 53 which is 5%
                % You pressed key 54 which is 6^
                % You pressed key 55 which is 7&
                % You pressed key 56 which is 8*
                % You pressed key 57 which is 9(
                % You pressed key 48 which is 0)
                % You pressed key 27 which is ESCAPE
                
                % Allowable response keys, and their numerical values
                obj.responseKeys = {KbName('1!'), ...
                                KbName('2@'), ...
                                KbName('3#'), ...
                                KbName('4$'),...
                                KbName('5%'),...
                                ...
                                KbName('5'), ... Keypad 5
                                KbName('4'), ... Keypad 4
                                KbName('1'), ... Keypad 1
                                KbName('2'), ... Keypad 2
                                ...
                                KbName('ESCAPE'), ...
                                ...
                                KbName('space')};

                obj.responseValues  = [1, 2, 3, 4, 5, ...
                                   1, 2, 3, 4, ...
                                   -1, ...
                                   0 ];
               
               % For buttons 1, 2, or 3
               obj.responseValues_Mouse = [1 2 3];

                % For navigation
                obj.nextKey     = KbName('RightArrow');
                obj.previousKey = KbName('LeftArrow');
                
            elseif( ismac )
                % >> KbDemo
                % 1 of 4.  Testing KbCheck and KbName: press a key to see its number.
                % Press the escape key to proceed to the next demo.
                % You pressed key 89 which is 1
                % You pressed key 90 which is 2
                % You pressed key 91 which is 3
                % You pressed key 92 which is 4
                % You pressed key 94 which is 6
                % You pressed key 95 which is 7
                % You pressed key 96 which is 8
                % You pressed key 97 which is 9
                % You pressed key 98 which is 0
                % 1234567890
                % You pressed key 88 which is ENTER
                % You pressed key 30 which is 1!
                % You pressed key 31 which is 2@
                % You pressed key 32 which is 3#
                % You pressed key 33 which is 4$
                % You pressed key 34 which is 5%
                % You pressed key 35 which is 6^
                % You pressed key 36 which is 7&
                % You pressed key 37 which is 8*
                % You pressed key 38 which is 9(
                % You pressed key 39 which is 0)
                % You pressed key 80 which is LeftArrow
                % You pressed key 79 which is RightArrow
                % You pressed key 82 which is UpArrow
                % You pressed key 81 which is DownArrow
                % You pressed key 41 which is ESCAPE
                
                % Allowable response keys, and their numerical values
                obj.responseKeys = {KbName('1!'), ...
                                KbName('2@'), ...
                                KbName('3#'), ...
                                KbName('4$'),...
                                KbName('5%'),...
                                ...
                                KbName('5'), ... Keypad 5
                                KbName('4'), ... Keypad 4
                                KbName('1'), ... Keypad 1
                                KbName('2'), ... Keypad 2
                                ...
                                KbName('ESCAPE'), ...
                                ...
                                KbName('space')};

                obj.responseValues  = [1, 2, 3, 4, 5, ...
                                   1, 2, 3, 4, ...
                                   -1, ...
                                   0 ];
                               
               % For buttons 1, 2, or 3
               obj.responseValues_Mouse = [1 2 3];

                % For navigation
                obj.nextKey     = KbName('RightArrow');
                obj.previousKey = KbName('LeftArrow');
                
            elseif( IsLinux )
                % TODO % Read keybidning info from a settings file
                %KbName('UnifyKeyNames');
                % You pressed key 66 which is space

                % Allowable response keys, and their numerical values
                obj.responseKeys = {KbName('1!'), ...
                                KbName('2@'), ...
                                KbName('3#'), ...
                                KbName('4$'),...
                                KbName('5%'),...
                                ...
                                KbName('5'), ... Keypad 5
                                KbName('4'), ... Keypad 4
                                KbName('1'), ... Keypad 1
                                KbName('2'), ... Keypad 2
                                ...
                                KbName('ESCAPE'), ...
                                ...
                                KbName('space')};

                obj.responseValues  = [1, 2, 3, 4, 5, ...
                                   1, 2, 3, 4, ...
                                   -1, ...
                                   0 ];
                               
               % For buttons 1, 2, or 3
               obj.responseValues_Mouse = [1 2 3];

                % For navigation
                obj.nextKey     = KbName('RightArrow');
                obj.previousKey = KbName('LeftArrow');           
            end
        end
        
        function addStep( obj, step_type, presentation_mode, filename_dom, filename_nondom, varargin )
            %% Adds a step to the session            
            % 2011/10/12 NAVIGATE_FORWARD
            % 2011/10/17 NAVIGATE_FORWARD_ANYKEY
            % 2011/11/02 INPUT_SLIDER
            % 2012/02/23 filename_nondom = [] will set it equal to filename_dom
            %
            % addStep( step_type, presentation_mode, DOM_IMAGE, NONDOM_IMAGE, varargin );
            %
            % step_type
            %  (a) NAVIGATE                 -> Navigate through steps forward/backward
            %  (a2)NAVIGATE_FORWARD         -> Only allowed to navigate forward
            %  (a3) NAVIGATE_FORWARD_ANYKEY -> Go to next step with ANY keypres
            %  (b) INPUT         -> Wait for valid input from keyboard (1-4, or Esc)
            %                       then go to next step in display loop
            %                       * Optional argument for input_timeout (sec)
            %  (b2) INPUT_SLIDER             -> Slider scale with clicking mouse pointer
            %  (c) DELAY         -> Show image, then wait a delay
            %                       Specified delay (sec) with additional final argument
            %  (d) EXIT          -> Exit the display loop
            %
            % presentation_mode
            %  STEREO        -> Stereo display (Only option at this point)
            %
            % DOM_IMAGE    -> Specify filename for image on dominant eye
            %
            % NONDOM_IMAGE   -> Specify filename for image on nondominant eye
            %               -> If this is [], then it will be set same as
            %               DOM_IMAGE
            %
            % varargin{1} is delay_time for DELAY step or input_timeout for INPUT step
            
            % Must have valid WINDOW before steps can be added
            % (needed for textures)
            if( isnan(obj.WINDOW) )
                error('Create and set window before loading images. Window is required for textures');
            end
            
            if( ~strcmp(presentation_mode,'STEREO') )
                error('Must use STEREO presentation mode OR program non-stereo mode');
            end
            
            obj.Nsteps  = obj.Nsteps+1;
            s           = obj.Nsteps;
            
            % Set the step type
            obj.step_type{s} = step_type;
            
            if( strcmp(step_type,'DELAY') )
                if( nargin < 6 || ~isnumeric(varargin{1}) )
                    error('Must supply delay_time in seconds for DELAY step ( after filename_nondom in addStep() )');
                else
                    obj.delay_time(s) = varargin{1};
                end
            end
            
            % Assume there is no text to draw at this step, unless
            % specified by another function call (later)
            obj.display_text(s) = false;
            
            % Assume image is NOT full bleed (min window border) unless
            % specified by another function call
            obj.FULL_BLEED(s)   = false;
            
            
            switch step_type
                case {'INPUT', 'NAVIGATE', 'NAVIGATE_FORWARD', 'NAVIGATE_FORWARD_ANYKEY', 'DELAY'}
                       
                    % Load the dom image
                    obj.filename_dom{s}    = filename_dom;
                    obj.image_dom{s}       = imread(filename_dom);
                    obj.texture_dom{s}     = Screen('MakeTexture', obj.WINDOW, obj.image_dom{s});

                    % Get presentation mode
                    % TODO % Parse presentation mode for stereo/mono
                    obj.presentation_mode{s}    = presentation_mode;

                    % Check if this step is stero mode or not
                    obj.is_stereo{s} = strcmpi(presentation_mode,'STEREO');

                    % Only save the nondom image if it is stereo mode
                    if( obj.is_stereo{s} )
                        
                        if( isempty(filename_nondom) )
                            filename_nondom = filename_dom;
                        end
                        
                        % Load the image
                        obj.filename_nondom{s}   = filename_nondom;
                        obj.image_nondom{s}      = imread(filename_nondom);
                        obj.texture_nondom{s}    = Screen('MakeTexture', obj.WINDOW, obj.image_nondom{s});

                    % No image to load for nondom
                    else
                        obj.filename_nondom{s}   = 'NULL';
                        obj.image_nondom{s}      = NaN;
                        obj.texture_nondom{s}    = NaN;
                    end
                    
                    % Set the input_timeout parameter
                    %  If not specified, then value is +Inf (no limit)
                    if( strcmp(step_type, 'INPUT') )
                        if( nargin == 6 )
                            input_timeout = varargin{1};
                            
                            if( isnumeric(input_timeout) )
                                obj.input_timeout(s) = input_timeout;
                            else
                                error('input_timeout for INPUT step must be a numeric value, if specified at all');
                            end
                        else
                            obj.input_timeout(s) = Inf;
                        end
                    end
                    
                case 'INPUT_SLIDER'
                    error('Use addNewSliderScale(sliderScale) instead');
                    
                    
                case 'TIMESERIES'
                    error('Use addTimeSeries(SITS) instead');
                    
                case 'EXIT'
                    % Nothing more to store
                    
                otherwise
                    error('Invalid step type specified');
                    
            end
        end
        
        %{
        function addLinkedTimeSeries( obj, SITS )
            %% Add a linked stereo-image time series to the display session
            % This is NOT a new copy, but a link to the input instance
            obj.Nsteps  = obj.Nsteps+1;
            s           = obj.Nsteps;
            
            % Do NOT copy the % Copy the submitted time series, so it can hold unique values
            % regarding items which are displayed (e.g., random quadrants)
            obj.step_type{s}    = 'TIMESERIES';            
            obj.SITS{s}         = SITS;
            
        end
        %}
        
        
        function addDatingProfileToCurrentStep( obj, datingProfile )
            %% Add a dating profile display to the current step
            %  Draw this to BOTH sides of the display
            % 2011/10/05
            
            s =  obj.Nsteps;
            
            obj.display_text(s) = true;
            obj.textDisplay{s}  = datingProfile;            
        end
        
        function addNewTimeSeries( obj, SITS )
            %% Add a NEW stereo-image time series to the display session
            % This is a copy of the input time series
            obj.Nsteps  = obj.Nsteps+1;
            s           = obj.Nsteps;
            
            % Copy the submitted time series, so it can hold unique values
            % regarding items which are displayed (e.g., random quadrants)
            obj.step_type{s}    = 'TIMESERIES';            
            obj.SITS{s}         = SITS.copy();
        end      

        function addTextDisplayToCurrentStep( obj, textDisplay )
            %% Add a textDisplay to the current step
            %  Draw this to BOTH sides of the display
            % 2011/10/20
            
            s =  obj.Nsteps;            
            obj.display_text(s) = true;
            obj.textDisplay{s}  = textDisplay;            
        end
        
        function addNewSliderScale( obj, sliderScale )
            %% Add a new slider scale step
            
            if( isa(sliderScale, 'SliderScale') )
                % This is a copy of the input sliderScale
                obj.Nsteps  = obj.Nsteps+1;
                s           = obj.Nsteps;

                % Copy the submitted time series, so it can hold unique values
                % regarding items which are displayed (e.g., random quadrants)
                obj.step_type{s}            = 'INPUT_SLIDER';            
                obj.sliderScale_array{s}    = sliderScale;
                
                %warning('\n!Need to copy() the sliderScale instance?');
            end
        end
        
        
        function [WINDOW, windowRect] = createWindow( obj, rect_windowed, stereoMode, varargin )
            %% Create a new PTB window
            % 2011/10/20 Add scrnNum argument
            %
            % rect_windowed = size of the display window
            %  2D coordinates of top-left and bottom-right corner
            %  For full-screen, set this to [], as below
            %
            % scrnNum for specifying the screen number for multiple-monitor
            % system

            % If no arguments are given, use a full-screen non-stereo window
            if( nargin == 0 )
                rect_windowed = [];
                stereoMode = 0;
            end
            
            try
            
                % COPY FROM PTB StereoDemo.m
                % Get the list of Screens and choose the one with the highest screen number.
                % Screen 0 is, by definition, the display with the menu bar. Often when
                % two monitors are connected the one without the menu bar is used as
                % the stimulus display.  Chosing the display with the highest dislay number is
                % a best guess about where you want the stimulus displayed.
                if( nargin == 4 )
                    scrnNum = varargin{1};
                    fprintf('\nUsing specified screen number, %d', scrnNum);
                else
                    scrnNum = max(Screen('Screens'));                    
                end
                
                fprintf('\nCreating window on screen %d', scrnNum);


                %{
                % Windows-Hack: If mode 4 or 5 is requested, we select screen zero
                % as target screen: This will open a window that spans multiple
                % monitors on multi-display setups, which is usually what one wants
                % for this mode.
                if IsWin & (stereoMode==4 | stereoMode==5)
                   scrnNum = 0;
                end
                %}

                % Dual display dual-window stereo requested?
                if stereoMode == 10
                    % Yes. Do we have at least two separate displays for both views?
                    if length(Screen('Screens')) < 2
                        error('Sorry, for stereoMode 10 you''ll need at least 2 separate display screens in non-mirrored mode.');
                    end

                    if ~IsWin
                        % Assign left-eye view (the master window) to main display:
                        scrnNum = 0;
                    else
                        % Assign left-eye view (the master window) to main display:
                        scrnNum = 1;
                    end
                end

                % Open double-buffered onscreen window with the requested
                % stereo mode:
                window_black = BlackIndex(scrnNum);
                window_white = WhiteIndex(scrnNum);
                window_gray  = round(window_black + (window_white - window_black)/2);
                
                window_color = window_black;
                
                % Standard way to open window
                %[WINDOW, windowRect]=Screen('OpenWindow', scrnNum, window_gray, rect_windowed, [], [], stereoMode);            
                
                % Advanced window opening to address memory error
                % [2011/10/29]
                % http://tech.groups.yahoo.com/group/psychtoolbox/message/12001
                PsychImaging('PrepareConfiguration');
                PsychImaging('AddTask','General','UseVirtualFramebuffer');
                [WINDOW, windowRect]=PsychImaging('OpenWindow', scrnNum, window_color, rect_windowed, [], [], stereoMode);
                
                % Save the parameters to the class
                obj.WINDOW = WINDOW;
                %obj.rectWindow = windowRect;
                
                % Save original window rect only if it is not empty
                if( ~isempty(rect_windowed) )
                    obj.rectWindow = rect_windowed;
                
                else
                    % Otherwise save the window rect created
                    obj.rectWindow = windowRect;                    
                end
                
                obj.stereoMode = stereoMode;


                if stereoMode == 10
                    % In dual-window, dual-display mode, we open the slave window on
                    % the secondary screen. Please note that, after opening this window
                    % with the same parameters as the "master-window", we won't touch
                    % it anymore until the end of the experiment. PTB will take care of 
                    % managing this window automatically as appropriate for a stereo
                    % display setup. That is why we are not even interested in the window
                    % handles of this window:
                    if IsWin
                        slaveScreen = 2;
                    else
                        slaveScreen = 1;
                    end
                    Screen('OpenWindow', slaveScreen, BlackIndex(slaveScreen), [], [], [], stereoMode);
                end

                % Set up alpha-blending for smooth (anti-aliased) drawing of dots:
                Screen('BlendFunction', WINDOW, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
                
                
                % Now that the window is set, update textures
                obj.updateTextures();
                
                % For non-stereo mode, only one of the image is seen
                if( stereoMode == 0 )
                    obj.setEyeDominance( 'RIGHT' )
                end
                
            catch
                % Executes in case of an error: Closes onscreen window:
                Screen('CloseAll');
                psychrethrow(psychlasterror);
            end
        end
        
        
        function displayCurrentStep( obj )
            %% Displays the current step
            s = obj.current_step;
            
            OUTPUT_DEBUG = false;
            if( OUTPUT_DEBUG )
                [ST,I] = dbstack;                
                fprintf('\n\nFUNCTION: %s', ST(1).name);
            end
           
            
            if( OUTPUT_DEBUG )         
                fprintf('\n\tStep type: %s', obj.step_type{s});
            end
            
            quadrant = 0;
            
            % Load the image
            switch obj.step_type{s}
                case {'INPUT', 'NAVIGATE', 'NAVIGATE_FORWARD', 'NAVIGATE_FORWARD_ANYKEY', 'DELAY'}
                    
                    % Display the step
                    if( obj.is_stereo{s} )
                        % Draw dom image
                        Screen('SelectStereoDrawBuffer', obj.WINDOW, obj.DOM_DISPLAY);
                        Screen('DrawTexture', obj.WINDOW, obj.texture_dom{s}, [], ...
                            obj.getDestinationRect( obj.image_dom{s}, quadrant, obj.FULL_BLEED(s)) );
                        
                        % Draw a framing rectangle, if desired
                        for fr = 1:obj.NframingRectangles
                            if( obj.DRAW_FRAMING_RECTANGLE(fr) )
                                % Display a rectangular frame on top of the texture                            
                                Screen('FrameRect', obj.WINDOW, obj.frame_Color{fr}, obj.frame_Rect{fr}, obj.frame_Width(fr) );
                            end
                        end

                        % Draw nondom image
                        Screen('SelectStereoDrawBuffer', obj.WINDOW, obj.NONDOM_DISPLAY );                
                        Screen('DrawTexture', obj.WINDOW, obj.texture_nondom{s}, [], ...
                            obj.getDestinationRect( obj.image_nondom{s}, quadrant, obj.FULL_BLEED(s) ));
                                                                        
                        % Draw a framing rectangle, if desired
                        for fr = 1:obj.NframingRectangles
                            if( obj.DRAW_FRAMING_RECTANGLE(fr) )
                                % Display a rectangular frame on top of the texture                            
                                Screen('FrameRect', obj.WINDOW, obj.frame_Color{fr}, obj.frame_Rect{fr}, obj.frame_Width(fr) );
                            end
                        end
                        
                        
                        % Draw text to on top of this as well
                        if( obj.display_text(s) )
                            % Draw to both sides, with no rotation /
                            % quadrant manupulation at this point (must be
                            % coded)
                            destinationRect = [];
                            rotation = [];
                            obj.textDisplay{s}.drawToPTBWindow( obj.WINDOW, ...
                                obj.DOM_DISPLAY, destinationRect, rotation )
                            
                            obj.textDisplay{s}.drawToPTBWindow( obj.WINDOW, ...
                                obj.NONDOM_DISPLAY, destinationRect, rotation )
                            
                        end

                    else
                        % Display full mode (not stereo)
                        % TODO % Display full mode (not stereo) - not sure
                        % how to do this without creating a new Screen :-/
                    end
            end
            
            % Display the image
            switch obj.step_type{s}
                case {'INPUT', 'NAVIGATE', 'NAVIGATE_FORWARD', 'NAVIGATE_FORWARD_ANYKEY'}
                    % Update the display
                    time_flip = Screen('Flip', obj.WINDOW );

                    % Mark the time at which this step was started
                    Nsd                         = obj.pp_Nsteps+1;
                    obj.pp_Nsteps               = Nsd;
                    obj.pp_steps_traversed(Nsd) = s;

                    if( Nsd == 1 )
                        obj.start_tic           = tic;
                        obj.pp_etime(Nsd)       = 0;
                        
                        obj.start_time_flip      = time_flip;
                        obj.etime_flip(Nsd)      = time_flip - obj.start_time_flip;
                    else                        
                        
                        obj.pp_etime(Nsd)       = toc(obj.start_tic);
                        obj.etime_flip(Nsd)      = time_flip - obj.start_time_flip;
                    end
                    
                     if( obj.OUTPUT_DEBUG_TIMING )
                        fprintf('\n\t! Step %d flipped at time %f sec', Nsd, obj.etime_flip(Nsd));
                     end

                                                            
                    % Now wait to store input                    
                    received_input = false;
                    
                    % Log the start time
                    response_time_start = tic;
                    
                    % Wait until all keys are released
                    while KbCheck; end
                    
                    % Wait until mouse is released
                    mouse_buttons_on = true;
                    while( any(mouse_buttons_on) )
                        [mouse_x, mouse_y, mouse_buttons_on] = GetMouse(obj.WINDOW);
                    end
                    
                    while ~received_input
                        
                        % Check to see if the INPUT time is still valid
                        % [2011/10/04]
                        if( strcmpi(obj.step_type{s}, 'INPUT') )
                            time_elapsed = toc(response_time_start);
                            
                            if( time_elapsed > obj.input_timeout(s) )
                                
                                % Exit the INPUT loop and indicate that no
                                % response has been submitted (NaN)
                                obj.pp_response_value(obj.pp_Nsteps)    = NaN;
                                obj.pp_response_time(obj.pp_Nsteps)     = time_elapsed;

                                received_input = true;
                                obj.nextStepDisplay();
                            end
                        end
                        
    
                        % Pause may be helpful for timing
                        %pause(0.01);
                        
                        %--------------------------------------------------
                        % Check the state of the mouse [2012/03/20]
                        %  buttons = [LEFT_ON, MIDDLE_ON, RIGHT_ON] boolean
                        %  array
                        [mouse_x, mouse_y, mouse_buttons_on] = GetMouse(obj.WINDOW);
                        
                        if( obj.ALLOW_MOUSE_INPUT && any(mouse_buttons_on) && ...
                                ( strcmpi(obj.step_type{s}, 'NAVIGATE_FORWARD_ANYKEY') || ...
                                  strcmpi(obj.step_type{s}, 'NAVIGATE_FORWARD') || ...
                                  strcmpi(obj.step_type{s}, 'NAVIGATE') ) )
                            received_input = true;
                            obj.nextStepDisplay();
                        end
                        
                        if( obj.ALLOW_MOUSE_INPUT && any(mouse_buttons_on) )
                            % 1, 2, or 3 e.g.
                            k_mouse_buttons_pressed = find(mouse_buttons_on);

                            % If multiple buttons are pressed
                            % together, go with first button
                            if( length(k_mouse_buttons_pressed) > 1 )
                                k_mouse_buttons_pressed = k_mouse_buttons_pressed(1);
                            end
                            
                            % If any buttons have be pressed, then
                            % log the time and value
                            if(  ~isempty(k_mouse_buttons_pressed) )
                                obj.pp_response_value(obj.pp_Nsteps)    = obj.responseValues_Mouse(k_mouse_buttons_pressed);
                                obj.pp_response_time(obj.pp_Nsteps)     = toc(response_time_start);

                                received_input = true;
                                obj.nextStepDisplay();
                            end
                        end

                        %--------------------------------------------------
                        % Check the state of the keyboard.
                        [ keyIsDown, seconds, keyCode ] = KbCheck;        
                        if( keyIsDown )

                            % NAVIGATE and NAVIGATE_FORWARD steps can move slides forward
                            if( strcmpi(obj.step_type{s}, 'NAVIGATE') || ...
                                strcmpi(obj.step_type{s}, 'NAVIGATE_FORWARD') || ...
                                strcmpi(obj.step_type{s}, 'NAVIGATE_FORWARD_ANYKEY') )
                            
                                % NAVIGATE_FORWARD_ANYKEY does not care
                                % what key is pressed, but the other modes
                                % do
                                if( strcmpi(obj.step_type{s}, 'NAVIGATE_FORWARD_ANYKEY') || ...
                                    keyCode(obj.nextKey) )
                                
                                    % Mark the user proceeds
                                    %  This will be over-written if the
                                    %  navigation repeats this step "s"
                                    %obj.response_value(s)    = 1;
                                    %obj.response_time(s)     = toc(response_time_start);
                                    
                                    received_input = true;
                                    obj.nextStepDisplay();
                                end
                            end
                                
                            % NAVIGATE can go backward
                            if( strcmpi(obj.step_type{s}, 'NAVIGATE') )
                                if( keyCode(obj.previousKey) )
                                    % Mark the user retredes
                                    %  This will be over-written if the
                                    %  navigation repeats this step "s"
                                    %obj.response_value(s)    = -1;
                                    %obj.response_time(s)     = toc(response_time_start);
                                    
                                    received_input = true;
                                    
                                    % Go to prior step, then re-display
                                    %  This re-display ensures the user
                                    %  cannot exit the display loop by
                                    %  going too far backwards
                                    obj.previousStep();
                                    obj.displayCurrentStep();
                                end
                                
                            % If this step is for INPUT, then check for a
                            % valid keypress
                            elseif( strcmpi(obj.step_type{s}, 'INPUT') )
                                
                                %------------------------------------------
                                % Check each valid responseKey
                                for k = 1:length(obj.responseKeys)                                    
                                    if( keyCode(obj.responseKeys{k}) )
                                        % Found a valid key
                                        %  Store the response value
                                        %obj.response_value(s)    = responseValues(k);
                                        %obj.response_time(s)     = toc(response_time_start);
                                        
                                        obj.pp_response_value(obj.pp_Nsteps)    = obj.responseValues(k);
                                        obj.pp_response_time(obj.pp_Nsteps)     = toc(response_time_start);
                                        
                                        received_input = true;
                                        obj.nextStepDisplay();
                                        
                                        % Exit the for loop early
                                        break;
                                    end                                    
                                end
                            end
                        end
                    end
                    
                    % Show the current step, if there 
                    %if( obj.current_step < obj.Nsteps && ~keyCode(escapeKey) )
                    %    obj.displayCurrentStep();
                    %end        
                    
                case 'DELAY'
                    % Update the display
                    Screen('Flip', obj.WINDOW );
                    
                    % Wait some time
                    WaitSecs(obj.delay_time(s));
                    
                    % Proceed to next step
                    obj.nextStepDisplay();
                    
                case 'TIMESERIES'
                    % Mark the time at which this step was started
                    Nsd                         = obj.pp_Nsteps+1;
                    obj.pp_Nsteps               = Nsd;
                    obj.pp_steps_traversed(Nsd) = s;

                    if( Nsd == 1 )
                        obj.start_tic                   = tic;
                        obj.pp_etime(Nsd)    = 0;
                    else
                        obj.pp_etime(Nsd)    = toc(obj.start_tic);
                    end
                    
                    % Call the timeseries display
                    obj.SITS{s}.displayCurrentStep();
                    
                    % Store query image info from the timeseries sequence                    
                    obj.pp_SITS_specs{obj.pp_Nsteps} = obj.SITS{s}.getSpecs();
                    
                    % Store the input from the participant
                    [inputReceived, keyPress_Time, keyPress_Value] = obj.SITS{s}.getInput();
                    if( inputReceived )
                        obj.pp_response_value(obj.pp_Nsteps)   = keyPress_Value;
                        obj.pp_response_time(obj.pp_Nsteps)    = keyPress_Time;                                                
                    end
                                       
                    % Display the next step
                    if( obj.current_step < obj.Nsteps )
                        obj.nextStep();
                        obj.displayCurrentStep();
                    end
                    
                case 'INPUT_SLIDER'
                    % 2011/11/02 - Start coding
                    
                    % Mark the time at which this step was started
                    Nsd                         = obj.pp_Nsteps+1;
                    obj.pp_Nsteps               = Nsd;
                    obj.pp_steps_traversed(Nsd) = s;

                    if( Nsd == 1 )
                        obj.start_tic        = tic;
                        obj.pp_etime(Nsd)    = 0;
                    else
                        obj.pp_etime(Nsd)    = toc(obj.start_tic);
                    end
                    
                    % Initiate the response slider
                    [response, response_time] = obj.sliderScale_array{s}.getSliderInput();
                    %fprintf('\n\tSlider position = %0.2f after %0.2f sec', response, response_time);
                    
                    % Store the input
                    obj.pp_response_value(obj.pp_Nsteps)   = response;
                    obj.pp_response_time(obj.pp_Nsteps)    = response_time;
                    
                    % Display the next step
                    if( obj.current_step < obj.Nsteps )
                        obj.nextStep();
                        obj.displayCurrentStep();
                    end
                    
                case 'EXIT'
                    % Merely exit this function
                    
                otherwise
                    error('Attempted to display an invalid step type');
            end
            
            
        end
        
        function displayStep( obj, step )
            %% Return to first step
            obj.current_step = step;
            obj.displayCurrentStep();            
        end
        
        function flushAllSITSTextures(obj)
            %% Flush ALL SITS textures
            %error('No workie. Seems to try to access old textures that were already closed.');
            % 2011/10/27
            for s = obj.Nsteps:-1:1
                % Check if the SITS exists before trying to flush it
               if( length(obj.SITS) >= s && isa(obj.SITS{s}, 'StereoImageTimeSeries') )
                   obj.SITS{s}.flushAllTextures();
               end
            end
        end
        
        function flushMostRecentSITSTextures(obj)
            %% Flush ONLY the most recent SITS textures
            error('Call SITS.flushAllTextures() instead [2011/10/31]');
            %error('Call each SITS.flushAllTextures() explicitly in your code');
            
            for s = obj.Nsteps:-1:1
                % Check if the SITS exists before trying to flush it
               if( length(obj.SITS) >= s && isa(obj.SITS{s}, 'StereoImageTimeSeries') )
                   obj.SITS{s}.flushAllTextures();
                   return
               end
            end
        end
        
        function flushAllTextures(obj)
            %% Clear ALL the textures that are already loaded         
            % 2011/07/14 Start coding
            % 2011/10/27 Add debugging output
            %            Kill the images too? (large matrices)
            
            OUTPUT_DEBUG = false;
            if( OUTPUT_DEBUG )
                [ST,I] = dbstack;                
                fprintf('\n\nFUNCTION: %s', ST(1).name);
            end
            
            % Check how many windows are open before flushing
            NWindows_PreFlush = obj.getNumberOfWindows();
            
            for s = 1:obj.Nsteps
                if( OUTPUT_DEBUG )
                    fprintf('\n\tChecking step %d', s);
                    fprintf('\n\t\t*Total number of windows: %d', obj.getNumberOfWindows());
                end
                
                % Check if the texture exists, then try to close it
                if( length(obj.texture_dom) >= s )
                    tex = obj.texture_dom{s};

                    if( OUTPUT_DEBUG )
                        fprintf('\n\t\tChecking DOMINANT texture');
                        disp(tex);
                    end                

                    if( obj.isAWindow(tex) )
                        Screen('Close', tex);                                        
                        if( OUTPUT_DEBUG )
                            fprintf('\n\t\tClosed texture!');
                        end
                    else
                        if( OUTPUT_DEBUG )
                            fprintf('\n\t\tNo texture to close!');
                        end
                    end
                    if( OUTPUT_DEBUG )
                        fprintf('\n\t\t*Total number of windows: %d', obj.getNumberOfWindows());
                    end

                    obj.texture_dom{s} = [];
                    obj.image_dom{s} = [];
                end

                %----------------------------------------------------------
                % Nondominant side (same as above)
                if( length(obj.texture_nondom) >= s )
                    tex = obj.texture_nondom{s}; 
                    if( OUTPUT_DEBUG )
                        fprintf('\n\t\tChecking NON-DOMINANT texture');
                        disp(tex);
                    end

                    if( obj.isAWindow(tex) )
                        Screen('Close', tex);                    
                        if( OUTPUT_DEBUG )
                            fprintf('\n\t\tClosed texture!');
                        end
                    else
                        if( OUTPUT_DEBUG )
                            fprintf('\n\t\tNo texture to close!');
                        end
                    end

                    obj.texture_nondom{s} = [];
                    obj.image_nondom{s} = [];
                end
            end    
            
            if( OUTPUT_DEBUG )
                fprintf('\n\t\t*Total number of windows: %d', obj.getNumberOfWindows());
            end
                       
            % 2011/10/30
            obj.flushAllSITSTextures();
            
            %--------------------------------------------------------------
            % Just to make sure, flush remaining textures even if source is
            % not known [2011/11/16]
            %  This code would fail in case an alternate PTB window is open.
            %
            %  This should not be used in many cases, but the code may be
            %  improved by checking what the screen contains (texture vs.
            %  PTB window)
            FLUSH_UNKNOWN_SCREENS = false;
            if( FLUSH_UNKNOWN_SCREENS )
                
                %  Skip screen number 1, since that is the main PTB window
                for s = 2:length( Screen('Windows') )
                    Screen('Close', s);                
                end
            end
            %--------------------------------------------------------------
            
            % Check how many windows are open AFTER flushing
            NWindows_PostFlush = obj.getNumberOfWindows();
            fprintf('\n\t\t** Flushed %d textures from DisplaySession (%d -> %d)', ...
                (NWindows_PreFlush - NWindows_PostFlush), NWindows_PreFlush, NWindows_PostFlush);            
        end
        
        function destinationRect = getDestinationRect( obj, IMAGE, quadrant, FULL_BLEED )
            %% Calculate a destination rectangle to scale image size
            %  to fit in display window with desired minimum border size
            % IMAGE is the image (to get its dimensions)
            % quadrant (1,2,3,4) places image in just one of the quadrants
            %  and any other value uses all four quadrants
            %
            % FULL_BLEED option [2011/10/18]
            %  true     => minimum border percent
            %  false    => border percent set in the class instance
            %
            % destinationRect = [X_Left, Y_Top, X_Width, Y_Height]

            if( FULL_BLEED )
                % Set this to a small value
                minBorderFraction = obj.fullBleedBorderPercent / 100;
            else
                minBorderFraction = obj.minBorderPercent / 100;
            end

            % Get IMAGE dimensions
            imageDims   = size(IMAGE);
            imageX      = imageDims(2);
            imageY      = imageDims(1);            

            % Get screen dimensions
            windowDims  = Screen('Rect', obj.WINDOW);            
            windowX     = windowDims(3);
            windowY     = windowDims(4);

            % Aspect ratio is width / height
            imageAR     = imageX / imageY;
            windowAR    = windowX / windowY;            

            % If the image has larger AR than window, then the X border is
            % the smaller than Y border
            if( imageAR > windowAR )

                % The X border is smaller than the Y border
                borderX     = minBorderFraction * windowX;
                imageSizeX  = windowX - 2*borderX;                

                % Now calculate the Y border, fixing the image aspect ratio
                imageSizeY   = imageSizeX / imageAR;
                borderY      = (windowY - imageSizeY)/2;

            else                
                % The Y border is smaller than the X border
                borderY     = minBorderFraction * windowY;
                imageSizeY  = windowY - 2*borderY;

                % Now calculate the X border, fixing the image aspect ratio
                imageSizeX   = imageSizeY * imageAR;
                borderX      = (windowX - imageSizeX)/2;                                
            end            

            % Place the image in quadrant 1, 2, 3, 4, or all four
            switch quadrant
                % _Quadrants_
                %   II | I
                %  ----|----
                %  III | IV
                %
                case 1
                    destinationRect = [borderX + imageSizeX/2, ...
                                       borderY, ...
                                       borderX + imageSizeX, ...
                                       borderY + imageSizeY/2];

                case 2
                    destinationRect = [borderX, ...
                                       borderY, ...
                                       borderX + imageSizeX/2, ...
                                       borderY + imageSizeY/2];

                case 3
                    destinationRect = [borderX, ...
                                       borderY + imageSizeY/2, ...
                                       borderX + imageSizeX/2, ...
                                       borderY + imageSizeY];

                case 4
                    destinationRect = [borderX + imageSizeX/2, ...
                                       borderY + imageSizeY/2, ...
                                       borderX + imageSizeX, ...
                                       borderY + imageSizeY];

                otherwise
                    % Full
                    % Now stretch the image to allow minimum border
                    destinationRect = [borderX, ...
                                       borderY, ...
                                       borderX + imageSizeX, ...
                                       borderY + imageSizeY];        
            end
        end
        
        function [response_value, response_time] = getLastResponse( obj )
            %% DEPRECATED Return the most recent response
            % Note: pp_steps_traversed is used because the participant may
            % traverse the steps forward or backward (e.g., 1, 2, 3, 2, 3, 4, 5)
            
            error('Function deprecated. Use getRecentResponse( recencyIndex ), where recencyIndex = 1,2,3,...');
            %{
            % These values will be replaced, if an INPUT step was traversed
            response_value  = NaN;
            response_time   = NaN;
                           
            % Find the most recent step traversed that was an INPUT
            %  Work backwards (most recent step)
            for st = length(obj.pp_steps_traversed):-1:1
                
                % Get the step number
                s = obj.pp_steps_traversed(st);

                % Check if it is an INPUT type
                if( strcmpi(obj.step_type{s}, 'INPUT') )
                    % Find the response from the this step
                    response_value  = obj.pp_response_value(st);
                    response_time   = obj.pp_response_time( st );
                    return;
                    
                elseif( strcmpi(obj.step_type{s}, 'TIMESERIES') )
                    if( obj.SITS{s}.ALLOW_INPUT )
                        % Find the response from the this step
                        response_value  = obj.SITS{s}.keyPress_Value;
                        response_time   = obj.SITS{s}.keyPress_Time;
                        return;
                    end                    
                end                    
            end              
            %}
        end
        
        
        function [response_value, response_time] = getRecentResponse( obj, recencyIndex  )
            %% Return the most recent response
            % recencyIndex = 1,2,3,... for first, second, third,... most recent repsonse
            
            % Note: pp_steps_traversed is used because the participant may
            % traverse the steps forward or backward (e.g., 1, 2, 3, 2, 3, 4, 5)
            
            % These values will be replaced, if an INPUT step was traversed
            response_value  = NaN;
            response_time   = NaN;            
            
            recencyIndex_current = 0;
            
            % Find the most recent step traversed that was an INPUT
            %  Work backwards (most recent step)
            for st = length(obj.pp_steps_traversed):-1:1
                
                % Get the step number
                s = obj.pp_steps_traversed(st);

                % Check if it is an INPUT type
                if( strcmpi(obj.step_type{s}, 'INPUT') || ...
                    strcmpi(obj.step_type{s}, 'INPUT_SLIDER')    )
                    recencyIndex_current = recencyIndex_current+1;                    
                    
                    % Check if this is the desired recency index
                    if( recencyIndex == recencyIndex_current )                    
                        % Find the response from the this step
                        response_value  = obj.pp_response_value(st);
                        response_time   = obj.pp_response_time( st );
                        return;
                    end
                    
                elseif( strcmpi(obj.step_type{s}, 'TIMESERIES') )
                    if( obj.SITS{s}.ALLOW_INPUT )
                        recencyIndex_current = recencyIndex_current+1;
                        
                        % Check if this is the desired recency index
                        if( recencyIndex == recencyIndex_current )
                            % Find the response from the this step
                            response_value  = obj.SITS{s}.keyPress_Value;
                            response_time   = obj.SITS{s}.keyPress_Time;
                            return;
                        end
                    end                    
                end                    
            end                
        end
        
        function [win_offset_x, win_offset_y, win_width, win_height] =  getRectWithinBorder( obj )
            %% Get the drawable part of the window with respect to the
            % all the pixels on the PTB window
            
            % Get window dimensions
            %  RECT = [X_Left, Y_Top, X_Right, Y_Bottom]
            winRect     = obj.rectWindow;            
            win_width   = winRect(3) - winRect(1);
            win_height  = winRect(4) - winRect(2);
            
            % Get the minimum border percent to this can fit in the subset
            % of the window
            minBorderPercent = obj.minBorderPercent;
            
            % Crop the window to the proper size
            win_offset_x    = win_width * minBorderPercent/100;
            win_offset_y    = win_height * minBorderPercent/100;
            
            % Trim the size of the window to the subset
            win_width       = win_width - 2*win_offset_x;
            win_height      = win_height - 2*win_offset_y;
        end
            
        
        function state = getLastQueryProperty( obj, property )
            %% Return deisred property of query image for last SITS instance
            % that was traversed by participant
            
            % This value will be replaced, if a TIMSERIES step was traversed
            state = NaN;
            
            % Find the most recent step traversed that was a TIMESERIES
            %  Work backwards (most recent step)
            for st = length(obj.pp_steps_traversed):-1:1
                
                % Get the step number
                s = obj.pp_steps_traversed(st);

                % Check if it is an INPUT type
                if( strcmpi(obj.step_type( s ), 'TIMESERIES') )
                    
                    state = obj.pp_SITS_specs{st}.getQueryImageState( property );
                    %{
                    switch upper(property)
                        case 'ROTATION'     
                            state = obj.pp_query_image_rotation( st );

                        case 'QUADRANT'
                            state = obj.pp_query_image_quadrant( st );

                        case {'CONTRAST', 'CONTRASTLOG10'}
                            state = obj.pp_query_image_contrastlog10( st );

                        otherwise
                            error('Invalid property specified');
                    end
                    %}
                    return;
                end                    
            end     
            
                    
        end
        
        function SITS = getLastSITS( obj )
            %% Return the most recent instance of SteroImageTimeSeries            
            SITS = obj.SITS{end};            
        end
                
        function nextStep( obj )
            %% Advance a step in the session
            if( obj.current_step < obj.Nsteps )
                obj.current_step = obj.current_step+1;
            end            
        end
        
        function nextStepDisplay( obj )
            %% Advance a step in the session, then display if possible
            if( obj.current_step < obj.Nsteps )
                obj.current_step = obj.current_step+1;
                obj.displayCurrentStep();
            end            
        end
        
        function previousStep( obj )
            %% Recede a step in the session
            if( obj.current_step > 1 )
                obj.current_step = obj.current_step-1;
            end            
        end
               
        function previousStepDisplay( obj )
            %% Recede a step in the session, then display if possible
            if( obj.current_step > 1 )
                obj.current_step = obj.current_step-1;
                obj.displayCurrentStep();
            end
        end
        
        function rebootIfMaxWindowsExceeded( obj, MaxNumberOfWindows )
            %% Reboot the screen if needed
            % 2011/10/27
            if( obj.getNumberOfWindows() > MaxNumberOfWindows )
                fprintf('\n\n[%s] Maximum number of windows reached (%d). Rebooting', ...
                    datestr(now), MaxNumberOfWindows );
                
                % Time the reboot
                t0 = tic ();
                obj.rebootWindow();                
                fprintf('\nReboot completed in %0.2f sec', toc(t0));
            end
        end
        
        function rebootWindow( obj )
            %% Kill the screen and open a new one
            % 2011/10/27
            Screen('CloseAll');
            
            % Open a new window with the same specs as the current one
            obj.createWindow( obj.rectWindow, obj.stereoMode );
        end
        
        function setEyeDominance( obj, DOMINANT_EYE )
            %% Set which eye is dominant ('LEFT' or 'RIGHT')
            
            switch( upper(DOMINANT_EYE) )
                case 'LEFT'
                    obj.DOM_DISPLAY     = obj.LEFT_DISPLAY;
                    obj.NONDOM_DISPLAY  = obj.RIGHT_DISPLAY;                    
                                         
                case 'RIGHT'
                    obj.DOM_DISPLAY     = obj.RIGHT_DISPLAY;
                    obj.NONDOM_DISPLAY  = obj.LEFT_DISPLAY;
                    
                otherwise
                    error('Invalid dominant eye specified, use \''LEFT\'' or \''RIGHT\'' only');
            end            
        end
        
        function frNumber = setFramingRectangle( obj, frNumber, DRAW_FRAMING_RECTANGLE, COLOR_RGB, border_percent_X, border_percent_Y, PIXEL_WIDTH )
            %% Set the specifications for the framing rectangle
            % frNumber = the index of the framing rectangle (1,2,3,4,...)
            %   to allow multiple instances of framing rectangles
            %           = NaN or [] => add a new FR
            %           = Number of an existing FR => change properties of
            %           that FR
            % DRAW_FRAMING_RECTANGLE = (true/false) Draw the rectangle
            % COLOR_RGB = 0-255 [R G B] color triplet
            % border_percent_X,Y = Percent of window width/height to make border
            % PIXEL_WIDTH = Width of rectangle line in pixels
            
            % Add a new framing rectangle 
            if( isempty(frNumber) || isnan(frNumber) || frNumber > obj.NframingRectangles )
                % Increase number of framing rectangles
                obj.NframingRectangles  = obj.NframingRectangles+1;
                frNumber                = obj.NframingRectangles;
            end
            
            % To draw or not to draw...
            obj.DRAW_FRAMING_RECTANGLE(frNumber) = DRAW_FRAMING_RECTANGLE;
            
            if( DRAW_FRAMING_RECTANGLE )
                obj.frame_Color{frNumber} = COLOR_RGB;
                obj.frame_Width(frNumber) = PIXEL_WIDTH;
                
                % The rectangle specifies the drawn frame
                %  Using the window dimensions and desired borders
                % RECT = [X_Left, Y_Top, X_Width, Y_Height]                
                windowDims  = Screen('Rect', obj.WINDOW);
                window_Width    = windowDims(3);
                window_Height   = windowDims(4);
                
                border_pixels_X = ceil(border_percent_X * window_Width / 100);
                border_pixels_Y = ceil(border_percent_Y * window_Height / 100);
                obj.frame_Rect{frNumber} = [border_pixels_X, border_pixels_Y, ...
                     window_Width-border_pixels_X, window_Height - border_pixels_Y];
            end
        end
        
        function setFullBleedToCurrentStep( obj, FULL_BLEED )
            %% Specify whether step is drawn as full bleed (with minimum
            % window border percent)
            % Default is FALSE
            %
            % 2011/10/18 Start coding
            
            s =  obj.Nsteps;
            obj.FULL_BLEED(s) = FULL_BLEED;
        end

        function setInputKeys(obj, responseKeys, responseValues )
            %% Set the response KEYS and VALUES as arrays
            % This will be used for INPUT steps and will NOT affect
            % NAVIGATE steps

            % Check these at some point...?
            obj.responseKeys = responseKeys;
            obj.responseValues = responseValues;
        end
        
        function setInputKeys_Mouse(obj, responseValues_Mouse )
            %% Set the response VALUES as arrays for mouse buttons LEFT, MIDDLE, and RIGHT (in that order)
            % This will be used for INPUT steps and will NOT affect
            % NAVIGATE steps

            % Check these at some point...?
            obj.responseValues_Mouse = responseValues_Mouse;
        end
        
        function setMinBorderPercent( obj, minBorderPercent )
            %% Set minimum window border for scaling image display
            obj.minBorderPercent = minBorderPercent;            
        end
        
        function setWindow( obj, WINDOW )
            %% Set the window for Psychophysics toolbox
            obj.WINDOW = WINDOW;
            
            % Now that the window is set, update textures
            obj.updateTextures();
        end
        
        function updateTextures( obj )
            %% Update the textures if there is a window available
            
            if( isnan(obj.WINDOW) )
                error('Set window before setting texture');
            end
            
            % Do not overwrite texture if it exists already
            %  Simply start with the next available slot
            for s = length(obj.texture_dom)+1 : obj.Nsteps
                obj.texture_dom{s} = Screen('MakeTexture', obj.WINDOW, obj.image_dom{s});
                
                % Load the nondom image too, if needed
                if( obj.is_stereo{s} )
                    obj.texture_nondom{s} = Screen('MakeTexture', obj.WINDOW, obj.image_nondom{s});
                else
                    obj.texture_nondom{s} = NaN;
                end
            end
        end        
    end
    
    methods (Static = true)        
        function NumWindows = getNumberOfWindows( )
            %% Return number of windows that are allocated
            % Includes textures, etc.
            % If there are too many open windows, the computer may run out
            % of memory.
            % Use flushAllTextures to remove them (below)
            NumWindows = length( Screen('Windows') );
        end
        
        function IS_A_WINDOW = isAWindow( window_number )
            %% Check whether a screen or texture is valid
            window_array = Screen('Windows');
            
            % Check if any of the active windows correspond to the one
            % in question
            IS_A_WINDOW = ~isempty(window_number) && any( window_number == window_array );
        end
    end
end