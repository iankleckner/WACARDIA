classdef PortIO < handle
    % PortIO class: for triggering ports with MATLAB DataAcquisition
    % Toolbox
    %
    % Ian Kleckner
    % Interdisciplinary Affective Science Lab (IASLab)
    % 2011/02/27 Start coding
    % 2012/03/12 Try to send/receive triggers via different lines on same
    % port (doesn't work)
    %
    % TO DO
    %
    % LIMITATIONS
    %  2012/03/12 - Can't seem to send and receive triggers on the same
    %   port at the same time  (e.g., 4 lines output, and 4 lines input)
    %   This may be acknowledged in putvalue.m
    %
    % From putvalue.m
    %    If OBJ is a digital I/O object which contains lines from a port-
    %    configurable device then all lines will be written to even if they 
    %    are not contained by the device object.  This is an inherent 
    %    restriction of a port-configurable device.
    %
    % EXAMPLES OF USING PORTIO.M
    %     
    % % Example 1 Load the file with the list of triggers
    % portIO_out = PortIO('parallel', 'LPT1', 0:7, 'out');
    % portIO_out.readTriggersFromFile('triggerlist.txt');
    % portIO_out.findAndSendTrigger( 'HB--Tone' );    
    % 
    % % Example 2 To watch a port for a change
    % portIO_in = PortIO('parallel', 'LPT1', 0:7, 'in');
    % portIO_in.waitForPortChange();
    
    properties
        % Get into on installed adaptors
        %hwinfo = daqhwinfo();
        %hwinfo('parallel')                
        
        % Values used to instantiate the port (these may be over-written)
        adaptor         = 'parallel';
        portID          = 'LPT1';
        hwline_array    = 0:7;
        directionString = 'out';

        % Create a digital input/output object
        dio
        % Use "get(dio)" to get information on the object
        
        % Add a line group - one for input and one for output
        % A line group consists of a mapping between hardware line IDs and MATLAB indices 
        hwlines;
        
        % Set a default value for the port
        defaultValue            = 0;
        
        % Triggers for sending
        Ntriggers               = 0;    % Total number of triggers        
        triggerName_array       = {};   % Name of each trigger        
        triggerValue_array      = [];   % Value of each trigger (0-255)        
        triggerDuration_array   = [];   % Duration of each trigger (sec)
        
        % For computers that don't have data acquisition toolbox, this code
        % can still be run
        SEND_TRIGGERS           = true;
        
    end
    
    methods
        function obj = PortIO( adaptor, portID, hwline_array, directionString )
            %% Constructor function           
            %
            %'adaptor' - The hardware driver adaptor name. The supported
            %adaptors are advantech, mcc, nidaq, and parallel.
            %
            % ID - The hardware device identifier (e..g, LPT1)
            %
            % line_array - the lines to open
            %
            % Both can be set to [] to yield 'parallel' and 'LPT1'
            %
            % hwline_array - parallel port has 8 lines for read/write,
            % specify the numbers to use (e.g., all 8 -> hwline_array = 0:7)
            %
            % directionString - 'in' or 'out' for reading or writing via
            % the port, respectively
            %
            
            % Only send triggers if the matlab toolbox is installed
            
            % Check if computer has data acquisition toolbox
            v           = ver();
            toolboxName = 'Data Acquisition Toolbox';
            
            if( any(strcmp(toolboxName, {v.Name})) )
                obj.SEND_TRIGGERS = true;                
            else
                obj.SEND_TRIGGERS = false;     
                
                input('Data Acquisition Toolbox is not installed.\nTriggers will not be sent.\nPress Enter to continue.');
            end
            
            %--------------------------------------------------------------
            % Default values
            if( isempty(adaptor) )
                adaptor = 'parallel';
            end
            
            if( isempty(portID) )
                portID = 'LPT1';
            end
            
            if( isempty( hwline_array ) )
                hwline_array = 0:7;
            end
            %--------------------------------------------------------------
            
            % Save the values to the structure
            obj.adaptor         = adaptor;
            obj.portID          = portID;
            obj.hwline_array    = hwline_array;
            obj.directionString = directionString;
            
            % Complete the initialization
            obj.initialize();            
        end
        
        function addTrigger( obj, triggerName, triggerValue, triggerDuration )
            %% Add a new trigger to the list
            
            % Count up the new trigger
            obj.Ntriggers                   = obj.Ntriggers + 1;
            Nt                              = obj.Ntriggers;            
            
            % Add it to the list
            obj.triggerName_array{Nt}       = triggerName;
            obj.triggerValue_array(Nt)      = triggerValue;
            obj.triggerDuration_array(Nt)   = triggerDuration;            
        end
        
        function checkAllValues(obj)
            %% Check all values of the port -- for debugging
            
            for value = 0:255                
                fprintf('\nWriting %03d', value);
                
                if( obj.SEND_TRIGGERS )                
                    putvalue(obj.dio, value);
                    pause(0.1);

                    putvalue(obj.dio, 0);                
                    pause(0.1);
                end
            end
            
        end
        
        function findAndSendTrigger( obj, triggerName )
            %% Find and send trigger based on the name
            
            % If the trigger has been found yet
            FOUND_TRIGGER = false;
            
            % Look through the array until desired event is found
            %  Then send the trigger
            for t = 1:obj.Ntriggers
                
                if( strcmp( triggerName, obj.triggerName_array{t} ) )                    
                    % The trigger was found
                    FOUND_TRIGGER = true;                    
                    
                    fprintf('\n\t* Sending trigger "%s": Value %d for %0.3f sec', ...
                        obj.triggerName_array{t}, obj.triggerValue_array(t), obj.triggerDuration_array(t));
                                        
                    % Set value...
                    obj.putValue(obj.triggerValue_array(t));

                    % ...for the duration
                    pause(obj.triggerDuration_array(t));

                    % Set value to default
                    obj.putValue(obj.defaultValue);
                    
                    % Exit for loop early
                    break;
                end
            end
            
            if( ~FOUND_TRIGGER )
                error('Event %s could not be found', triggerName);
            end
        end
        
        function initialize( obj )
            %% Initialize the port
            %  This will be called with the constructor
            %  But it can also be called any time to re-initialize the port
            
            if( obj.SEND_TRIGGERS )
                % Create a digital input/output object
                obj.dio = digitalio( obj.adaptor, obj.portID);            

                % Add a line group - one for input and one for output
                % A line group consists of a mapping between hardware line IDs and MATLAB indices 
                obj.hwlines = addline(obj.dio, obj.hwline_array, obj.directionString);

                % If this is an output line, then set the default value
                if( strcmp(obj.directionString, 'out') )
                    
                    % Set the default value to zero on each line
                    obj.defaultValue = zeros(1,length(obj.hwline_array));
                                        
                    % Put the value on the lines
                    obj.putValue( obj.defaultValue )
                end            
            end
        end
        
        function value = getValue( obj )
            %% Check the value from the port 
            
            if( obj.SEND_TRIGGERS )
                value = getvalue(obj.dio);        
            end
        end
        
        
        function putValue( obj, value )
            %% Put a value to the port
            %
            % value can be a base10 number (e.g., 0, 1, 2, 3, ..., 255)
            % or a binary array, one digit per line (e.g., [0 0 0 0 0 1 0 0])
            
            if( obj.SEND_TRIGGERS )            
                
                % Create a binary vector to represent the number with one
                % digit for each of the hardware lines that are open
                if( length(value) == 1 )
                    %putvalue(obj.dio, value);                    
                    value = dec2binvec(value, length(obj.hwlines));
                end
                
                putvalue(obj.dio.Line(1:length(value)), value);
            end
            
        end
        
        function readTriggersFromFile( obj, filename )
            %% Read the list of triggers from a pre-formatted text file
            %
            % File format example:
            %
            % TriggerName   TriggerValue    TriggerDuration
            % startStim-01  1               0.05
            % startStim-02  2               0.05
            % startBlock    20              0.05
            %
            
            % Open the file
            FILE = fopen(filename);

            fileData_delimited = textscan(FILE, '%s\t%d\t%f', ...
                'Headerlines', 1, 'CollectOutput', true);
            
            % Count number of new triggers
            Ntriggers_new = length( fileData_delimited{1} );
            
            % Add these to the existing triggers
            Nt_old                          = obj.Ntriggers;
            obj.Ntriggers                   = Nt_old + Ntriggers_new;
            Nt                              = obj.Ntriggers;
                        
            % Add it to the list of existing triggers
            %  Each 1,2,3 refers to the column in the data 1,2,or 3
            for t = Nt_old+1:Nt
                obj.triggerName_array{t}       = fileData_delimited{1}{t};
                obj.triggerValue_array(t)      = fileData_delimited{2}(t);
                obj.triggerDuration_array(t)   = fileData_delimited{3}(t);     
            end
            
            % Close the file
            fclose(FILE);
        end
        
        function [newValue, waitingTime] = waitForPortChange(obj)
            %% Wait for change in port
            %
            % This is useful for interfacing with hardware that may change
            % the value of the port
            
            OUTPUT_DEBUG = false;
            if( OUTPUT_DEBUG )
                [ST,I] = dbstack;                
                fprintf('\n\nFUNCTION: %s', ST(1).name);
            end
            
            if( ~obj.SEND_TRIGGERS )
                warning('Port cannot be read because Data Acquisition Toolbox is not installed. Function exiting...');
                newValue = NaN;
                waitingTime = NaN;
                return
            end
            
            % Read value of the lines
            linevalue_array = getvalue( obj.dio );
            last_value      = binvec2dec(linevalue_array);
            
            if( OUTPUT_DEBUG )
                fprintf('\n\nInitial Value: %d at %s', last_value, datestr(now));
            end
            
            % Start checking as fast as possible
            KEEP_GOING = true;
            startTic    = tic();
            
            while KEEP_GOING

                % Read value of the lines to confirm change
                linevalue_array = getvalue(obj.dio);
                current_value   = binvec2dec(linevalue_array);

                if( current_value ~= last_value )    
                    if( OUTPUT_DEBUG )
                        fprintf('\n\nNew Value: %d at %s', current_value, datestr(now));
                    end
                    
                    % Save the results
                    newValue = current_value;
                    waitingTime = toc(startTic);
                    
                    % Exit the loop
                    KEEP_GOING = false;
                end

                last_value = current_value;
            end
        end
    end
end