classdef SliderScale < handle
    % SliderScale class: holds information on SliderScale input to be displayed to a PTB
    % window
    %
    % Ian Kleckner
    % Interdisciplinary Affective Science Lab (IASLab)
    % 2011/11/02 Start coding
    % 2012/02/22 Allow a picture to be displayed in the scale
    %            Allow text to be disabled
    %            White slider on black background
    % 2012/04/12 Support for stereomode 1 (interleaved)
    % 2012/04/19 Support for stereomode 4 (left/right split)
    %            Draw framing rectangle (if set to do so in DisplaySession)
    % 2019/04/15 Mouse must be UNCLICKED before starting, so as not to
    %            carry over any prior mouse clicks to this rating screen
    %
    % TO DO
    %  Allow the properties to be set easily (what text is displayed where)
    %  Make a copy() function for when it is added to DisplaySession?
    % Labels high above scale ends
    % Allow input for commit or exit
    
    properties
        % Some quantities are CALCULATED and some must be SPECIFIED
        %  Calculated quantites are not set here, so values are []
        %  Use calculatePositionsAndSizes() once any specified quantity is
        %  changed
        %
        % FoS = Fraction of Screen
        
        % How to set up
        %  Pick fontsize
        %  Pick a few FoS values (see !! FoS)
        %    Slider width (0.7)
        %    Slider yPosition (0.6) ?
        %    Heading yPosition (0.1)
        %    Footer yPosition (0.9)
        %    Slider labels yPosition (
        %    Slider lower text half-way between middle and ends yPosition
        
        %------------------------------------------------------------------
        % Screen specifications
        DS          = []; % DisplaySession associated with the scale
        window      = []; % Window handle from parent DisplaySession
        
        % Size and position of screen
        screen_xCenter  = [];
        screen_yCenter  = [];
        screen_width    = [];
        screen_height   = [];
        
        screen_offset_x = [];
        screen_offset_y = [];
        
        % Background color for screen
        color_BackgroundRGB = 255*[0 0 0];
        
        %------------------------------------------------------------------
        % Slider and slider bar
        
        % Scale for slider
        sliderScale_color         = 255*[1 1 1];
        sliderScale_width_FoS     = 0.85;
        sliderScale_width         = [];
        sliderScale_height        = 8;

        sliderScale_yCenter_FoS   = 0.65; % !! FoS
        sliderScale_yCenter       = [];

        % Put scale at bottom center of screen [CALCULATED]        
        sliderScale_left     = [];
        sliderScale_right    = [];
        sliderScale_rect     = [];

        % Slider bar that lies on top of the scale (moved by mouse)
        sliderBar_width    = 20;
        sliderBar_height   = 40;
        sliderBar_color    = 255*[1 1 1 0.5];
        sliderBar_yCenter  = [];

        % Slider bar with committed response
        sliderBarSet_width      = 20;
        sliderBarSet_height     = 40;
        sliderBarSet_color      = 255*[1 1 1 1];
        sliderBarSet_yCenter	= [];
        
        % The desired response after input (0 <--> 1)
        sliderBar_Fraction      = [];
        %------------------------------------------------------------------
        
        %------------------------------------------------------------------
        % Text content
        
        
        % Heading at top center
        textHeading             = 'Heading';
        textHeading_yTop_FoS    = 0.1; % !! FoS
        textHeading_yTop        = [];
        
        % Text above slider at each end
        textLabel_L         = 'Most\nunpleasant\nexperience\n-100';
        textLabel_R         = 'Most\npleasant\nexperience\n+100';
        textLabel_C         = 'Neutral\n\n0';            
        textLabel_R_width    = [];
        textLabel_R_Nlines   = [];
        textLabel_R_height   = [];
        textLabel_R_yTop_FoS = 0.45; % !! FoS    
        %textLabel_R_height_aboveScale  = 50;   % Space between bottom of text box and top of slider scale
        textLabel_L_xLeft    = [];
        textLabel_L_yTop     = [];

        textLabel_R_xLeft    = [];
        textLabel_R_yTop     = [];

        % Footer
        textLabel_Foot           = 'Click to set rating. Press enter to commit.';
        textLabel_Foot_yTop_FoS  = 0.9; % !! FoS
        textLabel_Foot_yTop      = [];

        % Text in the middle of the slider half way between center and left
        % or center and right
        textLabel_LHalf         = 'Disliking';
        textLabel_RHalf         = 'Liking';
        textRHalf_yTop_FoS      = 0.62; % !! FoS
        textRHalf_yTop          = [];
        textLHalf_xLeft         = [];
        textRHalf_xLeft         = [];
        
        % Extra text labels above slider ends
        %{
        textLabel_LHigh     = WrapString('This is my most unpleasant personal experience ever', maxLineLength);
        textLabel_RHigh     = WrapString('This is my most pleasant personal experience ever', maxLineLength);
        
        textLabel_RHigh_charWrap    = [];
        textLabel_RHigh_yTop_FoS    = 0.3;            
        textLabel_RHigh_yTop        = [];
        textLabel_RHigh_xLeft       = [];
        textLabel_RHigh_width       = [];            
        textLabel_LHigh_xLeft       = [];
        textLabel_LHigh_yTop        = [];
        %}
        %------------------------------------------------------------------
        
        %------------------------------------------------------------------
        % Text options
        
        % Display the text on the screen
        DISPLAY_TEXT            = false;
              
        % 0=normal,1=bold,2=italic,4=underline,8=outline,32=condense,64=extend
        FONTSTYLE   = 0;
        FONTNAME    = 'Arial';
        FONTSIZE    = 24;
        FONTCOLOR   = 255*[1 1 1];
        
        % 0=normal,1=bold,2=italic,4=underline,8=outline,32=condense,64=extend
        FONTSTYLE_HEADING   = 1;
        FONTNAME_HEADING    = 'Arial';
        FONTSIZE_HEADING    = 32;
        FONTCOLOR_HEADING   = 255*[0 0 0];        
        
        text_heightPerLine  = [];   % Depends on font size
        vSpacing = 1;               % Vertical spacing (pixels per fontsize)
        %------------------------------------------------------------------
        
        %------------------------------------------------------------------
        % Image options
        
        DISPLAY_IMAGE   = true;
        filename_image   = [];
        
        FULL_BLEED      = true;
        
        
        %------------------------------------------------------------------
        % Keyboard input

        % Linux Return 37
        responseKey_commit = 37;
        
        % Mac Esc 41
        responseKey_abort   = 41;
        
        % Keyboard devicen number (-1 probes ALL devices)
        KbDevice_Number = -1;
        %------------------------------------------------------------------
        
    end
    
    methods
        function obj = SliderScale( DS )
            %% Constructor function (if a PTB Display Session handle already exists)            
            obj.DS      = DS;
            obj.window  = obj.DS.WINDOW;
            
            % Prepare new rectWindow for this window in the border
            [win_offset_x, win_offset_y, win_width, win_height] =  obj.DS.getRectWithinBorder();
            
            % ALTERNATIVE METHOD TO GET THE FULL SCREEN
            % Get screen's rectangle [XLeft, YTop, XRight, YBottom]
            %rectWindow          = obj.DS.rectWindow;
            
            % rectangle [XLeft, YTop, XRight, YBottom]
            rectWindow = [win_offset_x, win_offset_y, win_offset_x + win_width, win_offset_y + win_height];
            
            % Calculate parts of screen from rectangle
            [obj.screen_xCenter, obj.screen_yCenter]  = RectCenter( rectWindow );
            obj.screen_width        = RectWidth(rectWindow);
            obj.screen_height       = RectHeight(rectWindow);
            
            obj.screen_offset_x     = win_offset_x;
            obj.screen_offset_y     = win_offset_y;
            
            % For split-screen stereo, the window is 1/2'ed into Left-Right
            if( obj.DS.stereoMode == 4 )
                % Window is half-width
                obj.screen_xCenter  = obj.screen_xCenter / 2;
                obj.screen_width    = obj.screen_width / 2;
                
                % Make the slider scale smaller to match the smaller window
                fSmaller = 2;
                obj.sliderScale_height = obj.sliderScale_height / fSmaller;
                obj.sliderBar_width    = obj.sliderBar_width / fSmaller;
                obj.sliderBar_height   = obj.sliderBar_height / fSmaller;
                obj.sliderBarSet_width = obj.sliderBarSet_width / fSmaller;
                obj.sliderBarSet_height= obj.sliderBarSet_height / fSmaller;
                
            elseif( obj.DS.stereoMode > 1 )
                error('This stereo mode (%d) is not programmed' ,obj.DS.stereoMode);                
            end
            
            % Update the properties via calculation
            obj.calculatePositionsAndSizes();
            
            % Default Keyboard input (can be set with setResponseKeys)
            if( IsLinux )                
                % Enter is 37
                obj.responseKey_commit = 37;
                obj.responseKey_abort = 38;
                %error('Program keys for LINUX');

            elseif( ismac )
                % You pressed key 40 which is Return
                % You pressed key 41 which is ESCAPE
                % You pressed key 44 which is space
                obj.responseKey_commit = 44;
                obj.responseKey_abort = 41;
                
                %error('Program keys for MAC');

            elseif( IsWin )
                % You pressed key 32 which is space
                % You pressed key 27 which is ESCAPE
                obj.responseKey_commit = 32;
                obj.responseKey_abort = 27;

                %error('Program keys for WINDOWS');
            end
        end
        
        function calculatePositionsAndSizes( obj )
            %% Commit positions and sizes to display elements in case any settings have changed
            %  These are CALCULATED properties
            
            % Calculate text height per line depending on font size
            obj.text_heightPerLine = Screen('TextSize', obj.window) * obj.vSpacing;
            
            %--------------------------------------------------------------
            % Scale for slider
            obj.sliderScale_width         = obj.sliderScale_width_FoS * obj.screen_width;
            obj.sliderScale_yCenter       = obj.screen_offset_y + obj.screen_height * obj.sliderScale_yCenter_FoS;

            % Put scale at bottom center of screen
            obj.sliderScale_left     = obj.screen_xCenter - obj.sliderScale_width/2;
            obj.sliderScale_right    = obj.screen_xCenter + obj.sliderScale_width/2;
            obj.sliderScale_rect     = [ obj.sliderScale_left,  obj.sliderScale_yCenter - obj.sliderScale_height/2, ...
                                         obj.sliderScale_right, obj.sliderScale_yCenter + obj.sliderScale_height/2 ];

            % Slider bar that lies on top of the scale (moved by mouse)
            obj.sliderBar_yCenter	= obj.sliderScale_yCenter;

            % Slider bar with committed response
            obj.sliderBarSet_yCenter	= obj.sliderScale_yCenter;
            %--------------------------------------------------------------
            
            %--------------------------------------------------------------
            % Labels
            
            % Heading at top
            obj.textHeading_yTop    = obj.screen_offset_y + obj.screen_height * obj.textHeading_yTop_FoS;
            
            % Text width as twice as wide as the whitespace between screen
            % edge and
            % slider scale
            obj.textLabel_R_width    = obj.sliderScale_left * 2;

            % Number of lines determine the height of the text
            obj.textLabel_R_Nlines   = length(strfind(char(obj.textLabel_R), '\n'));    
            obj.textLabel_R_height   = obj.textLabel_R_Nlines * obj.text_heightPerLine + obj.sliderBar_height;
            
            % Space between bottom of text box and top of slider scale
            obj.textLabel_L_xLeft           = obj.sliderScale_left;
            obj.textLabel_L_yTop            = obj.screen_offset_y + obj.screen_height * obj.textLabel_R_yTop_FoS;
            
            %obj.textLabel_L_yTop            = obj.sliderScale_rect(RectTop) ...
            %        - obj.textLabel_R_height_aboveScale - obj.textLabel_R_height;

            obj.textLabel_R_xLeft            = obj.sliderScale_right;
            obj.textLabel_R_yTop             = obj.textLabel_L_yTop;

            % Instructions
            %obj.textLabel_Foot_yTop = obj.sliderScale_yCenter + obj.sliderScale_height*8;
            obj.textLabel_Foot_yTop = obj.screen_offset_y + obj.screen_height * obj.textLabel_Foot_yTop_FoS;            

            %obj.textRHalf_yTop      = obj.sliderScale_yCenter + obj.sliderScale_height*4;
            obj.textRHalf_yTop      = obj.screen_offset_y + obj.screen_height * obj.textRHalf_yTop_FoS;            
            
            % These instructions are half way between scale end and center
            obj.textLHalf_xLeft     = obj.screen_xCenter - obj.sliderScale_width/4;
            obj.textRHalf_xLeft     = obj.screen_xCenter + obj.sliderScale_width/4;
            
            % Labels high above scale ends
            %{
            obj.textLabel_RHigh_yTop    = obj.screen_offset_y + obj.screen_height * obj.textLabel_RHigh_yTop_FoS;            
            obj.textLabel_RHigh_width   = obj.textLabel_R_width * 2;
            
            
            obj.textLabel_LHigh_xLeft   = obj.sliderScale_left;
            obj.textLabel_LHigh_yTop    = obj.textLabel_RHigh_yTop;

            obj.textLabel_RHigh_xLeft   = obj.sliderScale_right;
            %}
            %--------------------------------------------------------------
        end
        
        function [response, response_time] = getSliderInput( obj )
            %% Enter loop to get input from mouse on slider
            
            % Set the mouse to the center of the screen before rating
            % begins
            SetMouse(obj.screen_xCenter, obj.screen_yCenter, obj.window);
            
            if( obj.DISPLAY_IMAGE )
                % Load image into texture
                image   = imread( obj.filename_image );
                texture = Screen('MakeTexture', obj.window, image);
            end
            
            % Initialize
            DONE                    = false; 
            ABORT                   = false;
            MOUSE_HAS_BEEN_CLICKED  = false;
            STARTED_TIMING          = false;
            
            % If the monitor is in some kind of stereo mode
            STEREO_VIEW = obj.DS.stereoMode > 0;
            
            % Stereo side is either 0 or 1
            STEREO_SIDE = 0;
            
            [mouse_x, mouse_y, mouse_buttons_on] = GetMouse(obj.window);
            while( mouse_buttons_on(1) )
                WaitSecs(0.01);
                % Just wait until the mouse button has been released
                [mouse_x, mouse_y, mouse_buttons_on] = GetMouse(obj.window);
            end
            
            while ~DONE && ~ABORT
                
                % This will enable drawing to EACH frame in the stereo
                % view, just in case that mode is on
                if( STEREO_VIEW )
                    Screen('SelectStereoDrawBuffer', obj.window, STEREO_SIDE);
                    
                    % Switch to other side for next drawing
                    if( STEREO_SIDE == 0 )
                        STEREO_SIDE = 1;
                    else
                        STEREO_SIDE = 0;
                    end
                end
                    
                % Erase window
                Screen('FillRect', obj.window, obj.color_BackgroundRGB);
                
                % Draw a framing rectangle, if desired
                for fr = 1:obj.DS.NframingRectangles
                    if( obj.DS.DRAW_FRAMING_RECTANGLE(fr) )
                        % Display a rectangular frame on top of the texture                            
                        Screen('FrameRect', obj.DS.WINDOW, obj.DS.frame_Color{fr}, obj.DS.frame_Rect{fr}, obj.DS.frame_Width(fr) );
                    end
                end
                
                %----------------------------------------------------------
                % Draw text
                if( obj.DISPLAY_TEXT )
                    % Text label for heading
                    % Update font specifications for ONLY HEADING
                    Screen('TextFont', obj.window, obj.FONTNAME_HEADING);
                    Screen('TextSize', obj.window, obj.FONTSIZE_HEADING);            
                    Screen('TextStyle',obj.window, obj.FONTSTYLE_HEADING);

                    DrawFormattedText(obj.window, obj.textHeading, 'center', obj.textHeading_yTop, obj.FONTCOLOR_HEADING);               

                    % Update font specifications for ALL REMAINING TEXT
                    Screen('TextFont', obj.window, obj.FONTNAME);
                    Screen('TextSize', obj.window, obj.FONTSIZE);            
                    Screen('TextStyle',obj.window, obj.FONTSTYLE);

                    % Text labels above slider scale
                    DrawFormattedText(obj.window, obj.textLabel_R, obj.textLabel_R_xLeft, obj.textLabel_R_yTop, obj.FONTCOLOR);            
                    DrawFormattedText(obj.window, obj.textLabel_L, obj.textLabel_L_xLeft, obj.textLabel_L_yTop, obj.FONTCOLOR);
                    DrawFormattedText(obj.window, obj.textLabel_C, 'center', obj.textLabel_R_yTop, obj.FONTCOLOR);

                    % Labels high above slider scale
                    %{
                    DrawFormattedText(obj.window, obj.textLabel_LHigh, obj.textLabel_LHigh_xLeft, obj.textLabel_RHigh_yTop, obj.FONTCOLOR);            
                    DrawFormattedText(obj.window, obj.textLabel_RHigh, obj.textLabel_RHigh_xLeft, obj.textLabel_RHigh_yTop, obj.FONTCOLOR);            
                    %}

                    % Labels beneath slider scale
                    DrawFormattedText(obj.window, obj.textLabel_RHalf, obj.textRHalf_xLeft, obj.textRHalf_yTop, obj.FONTCOLOR);
                    DrawFormattedText(obj.window, obj.textLabel_LHalf, obj.textLHalf_xLeft, obj.textRHalf_yTop, obj.FONTCOLOR);

                    % Instructions at bottom
                    DrawFormattedText(obj.window, obj.textLabel_Foot, 'center', obj.textLabel_Foot_yTop, obj.FONTCOLOR);
                end
                
                %----------------------------------------------------------
                % Draw image
                if( obj.DISPLAY_IMAGE )                    
                    quadrant = 0;
                    FULL_BLEED = obj.FULL_BLEED;
                    Screen('DrawTexture', obj.window, texture, [], ...
                            obj.DS.getDestinationRect( image, quadrant, FULL_BLEED) );                    
                end

                %----------------------------------------------------------
                % Draw slider
                
                % Slider slider
                Screen('FillRect', obj.window, obj.sliderScale_color, obj.sliderScale_rect);

                % Get mouse position
                %  x, y = pixel coordinates on monitor
                %  buttons = [LEFT_ON, MIDDLE_ON, RIGHT_ON] boolean array
                [mouse_x, mouse_y, mouse_buttons_on] = GetMouse(obj.window);

                % Constrain the mouse position to lie on slider scale
                if( mouse_x < obj.sliderScale_left )
                    sliderBar_xCenter = obj.sliderScale_left;
                elseif( mouse_x > obj.sliderScale_right )
                    sliderBar_xCenter = obj.sliderScale_right;
                else
                    sliderBar_xCenter = mouse_x;
                end

                % Check if the mouse button is clicked to set the slider position
                %  1 -> LEFT MOUSE BUTTON
                if( mouse_buttons_on(1) )
                    sliderBarSet_xCenter    = sliderBar_xCenter;
                    MOUSE_HAS_BEEN_CLICKED  = true;
                end

                % Draw box for slider bar
                sliderBar_rect = [sliderBar_xCenter - obj.sliderBar_width/2, obj.sliderBar_yCenter - obj.sliderBar_height/2, ...
                                  sliderBar_xCenter + obj.sliderBar_width/2, obj.sliderBar_yCenter + obj.sliderBar_height/2];
                Screen('FillRect', obj.window, obj.sliderBar_color, sliderBar_rect);

                % Draw box for set position of slider bar
                if( MOUSE_HAS_BEEN_CLICKED )
                    sliderBarSet_rect = [sliderBarSet_xCenter - obj.sliderBarSet_width/2, obj.sliderBarSet_yCenter - obj.sliderBarSet_height/2, ...
                                         sliderBarSet_xCenter + obj.sliderBarSet_width/2, obj.sliderBarSet_yCenter + obj.sliderBarSet_height/2];
                    Screen('FillRect', obj.window, obj.sliderBarSet_color, sliderBarSet_rect);
                end

                %----------------------------------------------------------
                % Draw the scene
                
                % If this is in stereo view, then flip only once per both
                % stereo views (i.e., when STEREO_SIDE = 1, and NOT when
                % STEREO_SIDE = 0)
                if( ~STEREO_VIEW || (STEREO_VIEW && STEREO_SIDE == 1) )                    
                    Screen('Flip', obj.window);
                end
                
                if( ~STARTED_TIMING )
                    % Start timing for response_time
                    tic0 = tic();
                    STARTED_TIMING = true;
                end

                % Only allow keyboard input once the mouse has been clicked, thus
                % setting the PP input
                if( MOUSE_HAS_BEEN_CLICKED )
                    
                    % Check state of mouse
                    %  buttons = [LEFT_ON, MIDDLE_ON, RIGHT_ON] boolean array
                    [mouse_x, mouse_y, mouse_buttons_on] = GetMouse(obj.window);
                    
                    % If MIDDLE or RIGHT mouse is clicked, then COMMIT response
                    DONE = mouse_buttons_on(2) || mouse_buttons_on(3);
                    
                    % Also, the keyboard to commit or abort
                    % Check the state of the keyboard.
                    [ keyIsDown, seconds, keyCode ] = KbCheck(obj.KbDevice_Number);

                    if( keyIsDown )            
                        % Check if it is a valid keypress                 
                        DONE = keyCode(obj.responseKey_commit);
                        
                        ABORT = keyCode(obj.responseKey_abort);
                    end
                end
            end
            
            % Log response time
            response_time = toc(tic0);

            if( ~ABORT )
                % Read position of the sliderBar as fraction of the sliderScale
                %  0 <--> 1
                obj.sliderBar_Fraction  = (sliderBarSet_xCenter - obj.sliderScale_left) / obj.sliderScale_width; 
                response                = obj.sliderBar_Fraction;
            else
                response                = -1;
            end
            
            % Clear the texture if needed
            if( obj.DISPLAY_IMAGE )
               Screen('Close', texture);
            end
        end
        
        function setTextHeading(obj, textHeading)
            %% Set the text to appear at the top of the display
            obj.textHeading = textHeading;            
        end
        
        function setDisplaySpecs(obj, FONTNAME, FONTCOLOR_RGBvector, FONTSIZE, FONTSTYLE )
            %% Set the properties of the display
            % FONTSTYLE: 0=normal,1=bold,2=italic,4=underline
            %            8=outline,32=condense,64=extend
            obj.FONTNAME    = FONTNAME;
            obj.FONTCOLOR   = FONTCOLOR_RGBvector;
            obj.FONTSIZE    = FONTSIZE;
            obj.FONTSTYLE   = FONTSTYLE;
            
            % Update the properties via calculation
            obj.calculatePositionsAndSizes();
        end 
        
        function setDisplayText(obj, DISPLAY_TEXT )
            %% Display text if desired (true/false)
            
            obj.DISPLAY_TEXT = DISPLAY_TEXT;
        end
        
        function setDisplayImage(obj, DISPLAY_IMAGE, filename_image, FULL_BLEED )
            %% Display an image if desired (true/false)
            % Also supply the image name
            % FULL_BLEED = true/false - show the image as large as possible
            
            obj.DISPLAY_IMAGE = DISPLAY_IMAGE;
            
            if( nargin >= 3 )
                obj.filename_image = filename_image;                
            end
            
            if( nargin == 4 )
                obj.FULL_BLEED = FULL_BLEED;
            end
            
            if( DISPLAY_IMAGE && isempty(obj.filename_image) )
                error('If you want to show an image then please supply an image filename. See code.');
            end
        end
        
        function setResponseKeys(obj, responseKey_commit, responseKey_abort)
            %% Set response keys for COMMITTING input and ABORTING input
            % Typically, Space or Enter and Escape
            
            obj.responseKey_commit = responseKey_commit;
            obj.responseKey_abort = responseKey_abort;
        end
    end
end