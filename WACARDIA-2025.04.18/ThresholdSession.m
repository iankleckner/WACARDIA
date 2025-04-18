classdef ThresholdSession < handle
    % ThresholdSession class: Holds info on session for physhophysical intensity threshold
    %  Subclass of "handle" imbues that each use of "ThresholdSession"
    %  creates only a new POINTER to the instance, which can be modified in
    %  any context
    %
    % Ian Kleckner
    % Interdisciplinary Affective Science Lab (IASL)
    % Contrast adjustment program
    %
    % 2011/02/09 Start coding        
    % 2011/02/27 Add response time
    % 2011/09/14 Determine convergence, Add getLagMean() function
    % 2011/09/26 Fix getFractionCorrect (it had erroneously used obj.Nt
    %              instead of the actual number of responses)
    %            Copy CONVERGENCE_MODE in copy() function
    %
    % 2011/10/23 Update usage for intuition (remove addTrial())
    %            (Why would I add a trial w/o a response??)
    % 2011/10/24 More updates for proper plotting / output
    % 2011/10/27 Prevent plotting null data
    % 2011/11/09 Update pThreshold for 4AFC and 2AFC to 62.5% and 75% resp.
    
    properties (SetAccess = private)
        name                = 'NoName';     % Name of session
        
        Nt                  = 0;    % Total number of trials
        intensity_log10     = [];   % Observed intensity for each trial t
        
        response            = [];   % Affirmative responses for each trial t (1 or 0)
                                    
        response_time       = [];   % Time required for response
        
        % For forced-choice selection, where an actual answer is known
        %  ahead of time, and user tries to select it
        response_value_FC   = [];   % Response entered by user (in forced choice)
        actual_value_FC     = [];   % Actual value (in forced choice)
        
        stepsize_log10          = [];   % Step size to arrive at current trial                                    
        stepsize_log10_default  = 1;    % Fixed step size for altering intensity
        
        STEP_MODE           = '';  % Mode for evolving the trial intensities
        
        q                   = [];   % Quest data structure
        
        
        % Mode for determining convergence
        %  QUEST_STD - Standard deviation from QUEST must be <= some value
        %  NUM_TRIALS - Total number of trials must be reached
        %  NEVER - Never converges
        %  LAG_MEAN (not yet programmed)
        %  LAT_STD (not yet programmed)
        CONVERGENCE_MODE = 'QUEST_STD';

        % QUEST standard deviation that constitutes convergence (<=
        % this value)
        convergence_QUEST_STD = 0.1;

        % Total trials that constitute convergence (>= this value)
        convergence_NUM_TRIALS = 50;
        
    end
    
    methods
        function obj = ThresholdSession( testMode_string, initial_intensity_log10, stepsize_log10_default )
            %% Constructor function
            %
            % testMode_string -> Type of test being performed
            %       2AFC    2 alternative forced-choice
            %       4AFC    4 alternative forced-choice
            %       YESNO   Yes or No (e.g., can you see the image?)
            
            
            obj.stepsize_log10_default  = stepsize_log10_default;                        
            obj.Nt = 0;            
            
            % QUEST setup
            % Guess the threshold for log10 of image contrast (-2)
            tGuess      = initial_intensity_log10;
            
            % Guess standard deviation in log units
            %  QUEST recommends overestimating this (2-4 is reasonable)
            tGuessSd    = 2;

            % grain is the quantization (step size) of the internal table. E.g. 0.01
            grain      = 0.01;

            % tRange is the intensity difference between the largest and smallest
            % intensity that the internal table can store. E.g. 5.
            % This interval will be centered on the initial guess tGuess
            % i.e., tGuess+(-range/2:grain:range/2).
            tRange      = 5;
            
            % beta controls the steepness of the psychometric function. Typically 3.5
            beta        = 3.5;
            
            % delta is the fraction of trials on which the observer presses blindly. Typically 0.01.
            delta       = 0.01;
            
            % Some parameters depend on the nature of the test performed
            %
            % Copied from QuestCreate.m
            % pThreshold is your threshold criterion expressed as probability of
            %   response==1. An intensity offset is introduced into the psychometric
            %   function so that threshold (i.e. the midpoint of the table) yields pThreshold.
            %
            %   For yes/no, pThreshold = 0.5
            %   For two-alternative forced-choice, pThreshold = 0.75 (or 0.82?)
            %   (?) For four-alternative forced-choice, pThreshold = 0.72 ?
            %
            % http://webvision.med.utah.edu/book/part-viii-gabac-receptors/
            % psychophysics-of-vision/
            %
            %  The FORCED CHOICE PROCEDURE involves forcing the subject to 
            %  choose from alternative choices, one of which contains the stimulus.
            %  A two-alternative forced choice (2AFC) describes a subject
            %  choosing between two alternatives. Choosing from four
            %  alternatives and six alternatives are called 4AFC and 6AFC,
            %  respectively. The percentage correct for the various stimuli
            %  intensities can be used to construct a psychometric function 
            %  to determine threshold. As there is already a 50% chance of a 
            %  correct response with 2AFC, threshold is commonly considered 
            %  as 75% (See Fig. 14).
            %
            % gamma is the fraction of trials that will generate response 1 when intensity==-inf.
            %   I.e., this is the Probability of success simply by chance
            %   For yes/no, gamma = 0
            %   For two-alternative forced-choice, gamma = 0.5
            %   For four-alternative forced-choice, gamma = 0.25
            
            switch( testMode_string )
                case '2AFC'
                    %error('Not sure what pThreshold is for 2AFC. 0.75 or 0.82?');                    
                    pThreshold  = 0.75;
                    gamma       = 0.5;
                    
                case '4AFC'
                    %pThreshold  = 0.72;
                    pThreshold  = 0.625;
                    gamma       = 0.25;
                    
                case {'YESNO', 'YES_NO'}
                    pThreshold  = 0.5;
                    gamma       = 0;
                    
                otherwise
                    error('%s: invalid test mode. See code.', testMode_string);
            end
            
            % Create the QUEST object with these parameters
            obj.q = QuestCreate(tGuess, tGuessSd, pThreshold, beta, delta, gamma, grain, tRange);
            
            % This adds a few ms per call to QuestUpdate, but otherwise the pdf will
            % underflow after about 1000 trials (QuestDemo.m)            
            obj.q.normalizePdf = 1;            
        end
        
        
        function addResponse( obj, intensity_log10, response, response_time, response_value_FC, actual_value_FC )
            %% Log the response from the participant for the current trial   
            % Optional: response_value_FC, actual_value_FC
            
            % Add the trial
            obj.Nt  = obj.Nt+1;
            t       = obj.Nt;
            
            % Log the results
            obj.intensity_log10(t)  = intensity_log10;
            obj.response(t)         = response;
            obj.response_time(t)    = response_time;
            
            if( ~isempty( response_value_FC) )
                obj.response_value_FC(t)= response_value_FC;
            end
            
            if( ~isempty( actual_value_FC) )
                obj.actual_value_FC(t)  = actual_value_FC;
            end
                        
            % Update QUEST with this response
            obj.q = QuestUpdate(obj.q, intensity_log10, response); 
        end
        
        function addTrial( obj, intensity_log10 )
            %% Add a trial to the list (not responded yet)
            
            error('addTrial is deprecated. Use addResponse instead');
            %{
                        
            % If the prior response has not yet been submitted
            if( isnan( obj.response(obj.Nt) ) )
                error('Must submit response to current trial before adding a new trial');                
            end
            
            % If prior response has been logged, then add new trial
            t = obj.Nt+1;
            obj.intensity_log10(t)  = intensity_log10;
            
            % Response is unknown at this point
            obj.response(t)         = NaN;
            
             % Update the total number of trials
            obj.Nt = obj.Nt + 1;            
            %}
        end
        
        function TS_copy = copy(obj)
            %% Copy the threshold session
            TS_copy = ThresholdSession( obj.intensity_log10(1), obj.stepsize_log10(1), [], [] );
            
            TS_copy.name                    = obj.name;
            TS_copy.Nt                      = obj.Nt;
            TS_copy.intensity_log10         = obj.intensity_log10;
            TS_copy.response                = obj.response;
            TS_copy.response_time           = obj.response_time;
            TS_copy.response_value_FC       = obj.response_value_FC;
            TS_copy.actual_value_FC         = obj.actual_value_FC;
            TS_copy.stepsize_log10          = obj.stepsize_log10;
            TS_copy.stepsize_log10_default  = obj.stepsize_log10_default;
            TS_copy.STEP_MODE               = obj.STEP_MODE;
            TS_copy.q                       = obj.q;
            
            TS_copy.CONVERGENCE_MODE        = obj.CONVERGENCE_MODE;
            TS_copy.convergence_QUEST_STD   = obj.convergence_QUEST_STD;
            TS_copy.convergence_NUM_TRIALS  = obj.convergence_NUM_TRIALS;
            
        end
        
        function intensity_log10 = getIntensity_for_PrCorrect( obj, PrCorrect )
            %% Return intensity such that PMF predicts a certain
            % probability of being correct

            % Method: Using the psychometric function
            %  Find the X-value closest to desired PrCorrect without exceeding that value

            % PMF plots Pr(Correct) as a function of intensity_log10
            [X_intensity_log10, Y_PrCorrect] = obj.plot_QUEST_PMF([],[]);
            
            % Obtain maximum (last) contrast such that Pr(Visible) <= desired value
            index = find(Y_PrCorrect <= PrCorrect, 1, 'last' );
            intensity_log10 = X_intensity_log10(index);
        end
        
        function intensity_log10 = getCurrentIntensity( obj )
            %% Return the current intensity (whether responded to or not)            
            intensity_log10 = obj.intensity_log10(obj.Nt);
        end
        
        function [mu, s] = getLagStats( obj, Nlag_Array )
            %% Return mean and standard deviation of the last Nlag intensities
            % 2011/09/14
            
            error('Make sure this code uses proper number of responses, instead of obj.Nt');
            
            % Initialize
            mu  = zeros(length(Nlag_Array),1);
            s   = zeros(length(Nlag_Array),1);
          
            % If Nlag is an array, then recursively compute each element
            for nl = 1:length(Nlag_Array)
                Nlag = Nlag_Array(nl);
                
                % If there are not enough trials yet
                if( Nlag > obj.Nt )
                    warning('Not enough trials to compute %d-lag mean. Returning %d-lag mean (max-lag)', Nlag, obj.Nt);
                    mu(nl)  = NaN;  
                    s(nl)   = NaN;     

                else
                    mu(nl)  = mean( obj.intensity_log10(end-Nlag+1:end) );
                    s(nl)   = std( obj.intensity_log10(end-Nlag+1:end) );
                end
            end
        end 
        
        
        function mu = getMean( obj )
            %% Return mean of the intensities
            mu = mean( obj.intensity_log10 );            
        end 
        
        function next_intensity_log10 = getNextIntensity( obj )
            %% Return guess for next intensity
            
            % Get the total number of trials so far
            t = obj.Nt;
            
            % If there is only one response that has not yet been submitted
            if( t == 1 && isnan(obj.response(obj.Nt)) )
                error('Cannot compute next intensity without at least one response');                
            end
            
            % If there are prior trials
            last_response           = obj.response(t);
            last_intensity_log10    = obj.intensity_log10(t);
            
            switch upper(obj.STEP_MODE)
                case 'STAIRCASE_FIXED'
                    % Alter intensity by fixed step size for each trial
                    
                    if( last_response )
                        % If the last response was true, reduce intensity
                        next_intensity_log10 = last_intensity_log10 - obj.stepsize_log10_default;                        
                    else
                        % Increase intensity
                        next_intensity_log10 = last_intensity_log10 + obj.stepsize_log10_default;                        
                    end
                    
                case 'STAIRCASE_ADAPTIVE'
                    % Intensity alteration determined by standard deviation
                    %  Smaller steps are made as intensity approaches threshold
                    
                    if( isnan(obj.getStd()) || obj.getStd() == 0 )
                        stepsize = obj.stepsize_log10_default;
                    else
                        stepsize = obj.getStd() / 2;
                    end
                    
                    if( last_response )
                        % If the last response was true, reduce intensity                        
                        next_intensity_log10 = last_intensity_log10 - stepsize;                        
                    else
                        % Increase intensity
                        next_intensity_log10 = last_intensity_log10 + stepsize;                        
                    end                    
                    
                case 'QUEST'
                    % Obtain the best guess for threshold from QUEST
                    next_intensity_log10 = QuestQuantile(obj.q);
                    
                case 'QUEST_JITTER'
                    % Add random jitter from Gaussian distribution to
                    % perturb the best guess from QUEST
                    %  Jitter magnitude scales with deviation in intensity values
                    next_intensity_log10 = normrnd(QuestQuantile(obj.q), QuestSd(obj.q));                                        
            end                
            
        end
        
        function fcorrect = getFractionCorrect( obj )
            %% Return the fraction of answers which are 1
            % 2011/09/26 Do not use obj.Nt, since this is sometimes ONE
            % MORE than the actual number of responses
            
            %{
            % Deprecate this code [2011/10/27]
            correct_responses   = obj.response_value_FC == obj.actual_value_FC;            
            Ncorrect            = sum( correct_responses );            
            Nresponses          = length(correct_responses);            
            fcorrect            = Ncorrect / Nresponses;
            %}
            
            % response = 1 if correct and 0 otherwise
            % Nt is total number of trials
            fcorrect = sum(obj.response) / obj.Nt;            
        end
        
        function s = getStd( obj )
            %% Return standard deviation of the intensities
            s = std( obj.intensity_log10 );            
        end
        
        function IS_CONVERGED = isConverged( obj )
            %% The set of trials has converged to a threshold
            % 2011/09/14
            
            OUTPUT_DEBUG            = true;
            if( OUTPUT_DEBUG )
                fprintf('\nThresholdSession.isConverged()');
            end
            
            switch upper(obj.CONVERGENCE_MODE)
                case 'QUEST_STD'
                    % Use standard deviation of QUEST calculation
                    IS_CONVERGED = QuestSd(obj.q) < obj.convergence_QUEST_STD;
                    
                case 'LAG_MEAN'
                    % Code this section if desired
                    %{
                    error('This has not been coded');
                    
                    [lagMean_Array, lagStd_Array] = obj.getLagStats( Nlag_Array );                    

                    if( OUTPUT_DEBUG )
                        hf = figure;
                        ha = axes('Parent', hf);
                        hold(ha, 'all');
                        plot(ha, Nlag_Array, lagStd_Array, 'or');
                        plot(ha, Nlag_Array, lagMean_Array, 'sk');
                    end
                    %}
                    
                    IS_CONVERGED = false;
                    
                case 'LAG_STD'
                    % The lag standard deviation is less than some 
                    % Code this section if desired
                    %{
                    error('This has not been coded');
                    Nlag_Array      = 1:5;
                    [lagMean_Array, lagStd_Array] = obj.getLagStats( Nlag_Array );
                    
                    IS_CONVERGED = std( lagStd_Array ) < convergenceQuantity;
                    %}
                    IS_CONVERGED = false;
                    
                case 'NUM_TRIALS'
                    % Total number of trials
                    IS_CONVERGED = obj.Nt >= obj.convergence_NUM_TRIALS;
                    
                    if( OUTPUT_DEBUG )
                        fprintf('\nNumTrials = %0.0f, TrialLimit = %0.0f', ...
                            obj.Nt, obj.convergence_NUM_TRIALS);
                    end
                    
                case 'NEVER'
                    % Never converges
                    IS_CONVERGED = false;
                    
                otherwise
                    error('Invalid CONVERGENCE_MODE specified');
            end            
        end
        
        
        
        function [X_intensity_log10, Y_dPdX] = plot_QUEST_PDF( obj, haxes, LineSpec )
            %% Plot the QUEST probability density function
                       
            % Do not plot if there are no data
            if( obj.Nt == 0 )
                X_intensity_log10 = NaN;
                Y_dPdX = NaN;
                return
            end
            
            % Use X offset by QuestMean so X-axis displays contrast (not
            % contrast minus threshold)
            X_Offset = QuestMean( obj.q );
            
            X_intensity_log10 = obj.q.x + X_Offset;
            Y_dPdX = obj.q.pdf;
            
            if( ~isempty(haxes) )
                plot(haxes, X_intensity_log10, Y_dPdX, LineSpec);

                % Set title, etc.
                title(haxes, sprintf('Threshold probability density'), 'FontWeight', 'Bold');
                ylabel(haxes, 'dPr / dX');
                xlabel(haxes, 'Log_{10}( Contrast )');    
            end

        end
        
        function [X_intensity_log10, Y_PrCorrect] = plot_QUEST_PMF( obj, haxes, LineSpec )
            %% Plot the fixed Weibull function that QUEST uses
            
            % Do not plot if there are no data
            if( obj.Nt == 0 )
                X_intensity_log10 = NaN;
                Y_PrCorrect = NaN;
                return
            end
            
            %X_Offset = obj.q.tGuess;
            X_Offset = QuestMean( obj.q );

            X_intensity_log10 = obj.q.x2 + X_Offset;
            Y_PrCorrect = obj.q.p2;
            
            if( ~isempty(haxes) )
                plot(haxes, X_intensity_log10, Y_PrCorrect, LineSpec);

                TITLE = 'Psychometic function (Weibull)';
                title(haxes, TITLE, 'FontWeight', 'Bold');

                ylabel(haxes, 'Pr( Correct )');
                xlabel(haxes, 'Log_{10}( Contrast )');

                set(haxes, 'YLim', [0, 1.1]);
            end
        end
        
        function plot_Responses(obj, haxes, PlotSpecs)
            %% Display the ACTUAL CALIBRATION responses in a plot
            %
            % haxes = handle to axes for plotting
            % PlotSpecs can be a cell array of {'MarkerSize', 2, 'LineWidth', 3} etc.
            
            % Do not plot if there are no data
            if( obj.Nt == 0 )
                return
            end
            
            if( isempty(PlotSpecs) )
                PlotSpecs = {};
            end
            
            % X data points
            X = 1:obj.Nt;

            % Show the CORRECT responses as circle
            hold(haxes,'off');    
            stem(haxes, X(obj.response(1:end-1)==1), ...
                          obj.intensity_log10(obj.response(1:end-1)==1), 'ok', PlotSpecs{:});

            % Show INCORRECT responses as X
            hold(haxes,'on');
            stem(haxes, X(obj.response(1:end-1)==0), ...
                                   obj.intensity_log10(obj.response(1:end-1)==0), 'xk', PlotSpecs{:});

            % Show unanswered response as square
            stem(haxes, obj.Nt, obj.intensity_log10(end), 'sk', PlotSpecs{:});
                
            xlabel(haxes, 'Trial number');
            ylabel(haxes, 'Log_{10}( Contrast )');
            
            title(haxes, sprintf('Participant Responses\nMean = %0.1f, Std = %0.1f', ...
                obj.getMean(), obj.getStd()), 'FontWeight', 'Bold');

            % Set x axis maximum to an integer multiple of 10
            set(haxes, 'XLim', [0, ceil(obj.Nt/10)*10]);
            legend(haxes, {'Correct', 'Incorrect', 'Unanswered'}, 'Location', 'Best')
            
        end
        
        function setConvergenceMode( obj, CONVERGENCE_MODE, convergenceQuantity )
            %% Specify the criteria for convergence
            
            % Mode for determining convergence
            %  QUEST_STD - Standard deviation from QUEST must be <= some value
            %  NUM_TRIALS - Total number of trials must be reached
            %  NEVER - Never converges
            %  LAG_MEAN (not yet programmed)
            %  LAT_STD (not yet programmed)
            
            switch upper(CONVERGENCE_MODE)
                case 'QUEST_STD'
                    % Use standard deviation of QUEST calculation
                    obj.CONVERGENCE_MODE        = CONVERGENCE_MODE;
                    obj.convergence_QUEST_STD 	= convergenceQuantity;
                    
                case 'LAG_MEAN'
                    error('This has not been coded');
                    
                case 'LAG_STD'
                    error('This has not been coded');
                    
                case 'NUM_TRIALS'
                    % Total number of trials
                    obj.CONVERGENCE_MODE        = CONVERGENCE_MODE;
                    obj.convergence_NUM_TRIALS 	= convergenceQuantity;
                    
                case 'NEVER'
                    % Never converges
                    obj.CONVERGENCE_MODE        = CONVERGENCE_MODE;
                    
                otherwise
                    error('Invalid CONVERGENCE_MODE specified');
            end
        end
        
        function setStepMode( obj, mode )
            %% Set the mode for evolving trial intensities
            %  STAIRCASE_FIXED
            %  STAIRCASE_ADAPTIVE
            %  QUEST
            %  QUEST_JITTER
            
            obj.STEP_MODE = mode;            
        end
    end
    
end

