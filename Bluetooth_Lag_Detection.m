% Jacob Chung
% University of Maryland Baltimore School of Nursing
% jacobjchung@gmail.com
%
% Measuring the lag in the Shimmer ECG device using an Arduino
%
% Requirements
%  PsychToolbox
%  MATLAB Support Package for Arduino Hardware
%
% 2024/7/21 Start coding
% 2024/9/10 Initial version of program complete

function Bluetooth_Lag_Detection (experiment_specs)

    % Read Arduino variables
    comPort_Arduino = sprintf('COM%d', experiment_specs.COM_Arduino);
    pin = sprintf('D%d', experiment_specs.Arduino_output_pin);
    
    % Read Shimmer variables
    comPort_ECG =  sprintf('%d', experiment_specs.COM_ECG);
    sampling_rate_ECG_Hz = experiment_specs.Sampling_rate_ECG_Lag_Hz;

    % Read the number of signals to send to collect
    nSignalSwitches = ceil(experiment_specs.Number_of_Arduino_switches/2);

    % Duration of each signal
    signal_duration_sec = 0.5;

    % Read the estimate for the amount of voltage that the Arduino outputs (depends
    % on the way the circuit is wired)
    approximate_voltage_mV = experiment_specs.Approximate_Voltage_mV;

    % Directory to save output
    currentDirectory = experiment_specs.currentDirectory;
    
    % Define the arduino as 'a'
    clear a;
    a = arduino(comPort_Arduino, 'Uno');

    % This is how much time between checking the Shimmer for data (smaller
    % numbers increase temporal precision but risk an error if there are no
    % data available)
    sampling_period_check_Shimmer_sec = 0.050;

    % The width of the window of data in seconds for the live graph
    window_width = 20;
    
    % Reset sampling bufer for first heartbeat
    sampling_buffer_first_HB_sec = 0.1;
    
    % Outputs additional information about the program
    OUTPUT_DEBUG_INFORMATION = true;

    % Performs some bookkeeping actions only after the first loop
    FIRST_READ_HAS_OCCURRED = false;
    
    % Whether to calculate the lag from the time measurement after the command
    % to send the arduino signal (false) or the average time measurement before
    % and after the command (true). We recommend keeping this false (If
    % this is true, it would overestimate the Bluetooth lag)
    ARDUINO_SIGNAL_TIME_FROM_AVERAGE = false;

    % Whether to calculate the confidence intervals assuming the
    % distribution of lag times is normally distributed, or empirically
    NORMALLY_DISTRIBUTED = false;
    
    % Whether or not to show the graph while the program runs
    SHOW_REALTIME_PLOT = true;
    
    % Keeps track of when to send arduino signals
    JUST_DELIVERED_SIGNAL = false;
    ARDUINO_OFF = true;
    
    % Sets up Psychtoolbox keyboard inputs for shift and escape keys
    KbName('UnifyKeyNames');
    key_shift                       = KbName('LeftShift');
    key_esc                         = KbName('ESCAPE');
    KbDevice_Number                 = -1;
    
    % assign user friendly macros for setenabledsensors
    SensorMacros = SetEnabledSensorsMacrosClass;
    
    % Connect to Shimmer at specified COM port
    fprintf('\n\n----------------------------------------------------');
    fprintf('\nAttempting to connect to ECG Shimmer, this may take 10 sec...\n');
    shimmer = ShimmerHandleClass(comPort_ECG);
    
    if (shimmer.connect)
        fprintf('\nSuccessfully connected to ECG Shimmer!\n');
    
        % Select sampling rate
        shimmer.setsamplingrate(sampling_rate_ECG_Hz);
    
        % Select internal expansion board; select 'ECG' to enable both SENSOR_EXG1 and SENSOR_EXG2
        shimmer.setinternalboard('ECG');
    
        % Disable other sensors
        shimmer.disableallsensors;
    
        % Enable SENSOR_EXG1 and SENSOR_EXG2
        shimmer.setenabledsensors(SensorMacros.ECG,1);
    
        % Align the shimmer RTC with the computer
        shimmer.setrealtimeclock();
    
    else
        error('Cannot connect to ECG Shimmer');
    end
    
    % Initialize arrays and variables
    X_time_total_sec = [];
    Y_ECG_total = [];
    X_signal_time_sec = [];
    Y_binary_signal = [];
    X_ECG_switch_points_secs = [];
    X_signal_switch_points_secs = [];
    pre_signal_points_secs = [];
    arduino_command_latency = [];
    lag_times = [];
    t = 0;
    Nswitches = 0;
    initial_GetSecs_offset_sec = 0;

    % Create files to store output

    % Clear the command window
    clc;

    cd(currentDirectory);

    % Create an output directory to save results to files
    output_dir = sprintf('out-%s-%s',datestr(now, 'yyyy.mm.dd-HHMM'), 'Lag_Detection');
    mkdir(output_dir);

    % Backup code into this directory
    %copyCode( output_dir )        
    zip( sprintf('%s/code', output_dir),{'*.m','*.fig'});

    % Start saving contents of command window to log file
    diary( sprintf('%s/diary.txt', output_dir) );
    
    fprintf('\n\n** Press any key to start the program\n\n');
    
    % Release all keys
    while KbCheck; end
    
    % Press any key
    keyIsDown = false;
    while( ~keyIsDown )
        % Check the state of the keyboard.
        [ keyIsDown, seconds, keyCode ] = KbCheck(KbDevice_Number);
    end
    
    % Wait until all keyboard keys are released
    fprintf('\nWaiting for keyboard keys to be released...');
    while KbCheck; end
    fprintf('done');
    
    shimmer.start;
    
    % Timers to calculate when to gather data from the Shimmer and send the
    % next arduino signal
    tic_at_last_sample = tic;
    tic_at_last_signal = tic;
    
    while(t < nSignalSwitches)
    
        JUST_DELIVERED_SIGNAL = false;
    
        % Set the output to 1 or 0 ever time the defined signal duration period
        % passes
        if( toc(tic_at_last_signal) >= signal_duration_sec * 2 && FIRST_READ_HAS_OCCURRED)
    
            % Checks time before and after sending the signal to 1) calculate
            % the average for an accurate time measurement and 2) to properly
            % display the line gragh
            X_signal_time_sec(end + 1) = GetSecs();
    
            % Sends voltage to the Shimmer
            writeDigitalPin(a, pin, 1);
    
            X_signal_time_sec(end + 1) = GetSecs();
    
            if(OUTPUT_DEBUG_INFORMATION)
                % fprintf('\nArduino signal delivered at %f', X_signal_time_sec(end) - initial_GetSecs_offset_sec);
            end
    
            tic_at_last_signal = tic;
    
            % Adds values for the y-axis of the line graph of the signal output
            Y_binary_signal(end + 1) = 0;
            Y_binary_signal(end + 1) = approximate_voltage_mV;
    
            JUST_DELIVERED_SIGNAL = true;
    
            ARDUINO_OFF = false;
    
            t = t + 1;
        elseif (toc(tic_at_last_signal) > signal_duration_sec && ~JUST_DELIVERED_SIGNAL && ~ARDUINO_OFF && FIRST_READ_HAS_OCCURRED)
    
            % Checks time before and after ending the signal to 1) calculate
            % the average for an accurate time measurement and 2) to properly
            % display the line gragh
            X_signal_time_sec(end + 1) = GetSecs();
    
            % Stops sending voltage to the Shimmer
            writeDigitalPin(a, pin, 0);
    
            X_signal_time_sec(end + 1) = GetSecs();
    
            if(OUTPUT_DEBUG_INFORMATION)
                % fprintf('\nArduino signal ended at %f', X_signal_time_sec(end) - initial_GetSecs_offset_sec);
            end
    
            % Adds values for the y-axis of the line graph of the signal output
            Y_binary_signal(end + 1) = approximate_voltage_mV;
            Y_binary_signal(end + 1) = 0;
    
            ARDUINO_OFF = true;
        end
    
        if( toc(tic_at_last_sample) >= sampling_period_check_Shimmer_sec + sampling_buffer_first_HB_sec )
            time_current_packet_arrival_pre_GetSecs = GetSecs();
    
            % Read the latest data from shimmer data buffer, signalFormatArray defines the format of the data and signalUnitArray the unit
            [newData, signalNameArray, signalFormatArray, signalUnitArray] = shimmer.getdata('c');
    
            time_current_packet_arrival_post_GetSecs = GetSecs();
    
            % Updated 2019/04/15
            NnewData = size(newData,1);
    
            if( NnewData >= 2 )
                if( ~FIRST_READ_HAS_OCCURRED  )
                    k_ECG_Signal_HBD = find(strcmp('ECG LA-RA', signalNameArray));
    
                    k_time = find(strcmp('Time Stamp', signalNameArray));
    
                    % Align the time measurements for the Arduino signals and
                    % the Shimmer ECG data by determining coincident times from
                    % Psychtoolbox and from the Shimmer output times
                    most_recent_ECG_timestamp_sec = newData(end, k_time) / 1e3;
                    first_ECG_timestep_sec = newData(1, k_time) / 1e3;
                    GetSecs_timestamp_sec = (time_current_packet_arrival_pre_GetSecs + time_current_packet_arrival_post_GetSecs) / 2;
                    initial_GetSecs_offset_sec = GetSecs_timestamp_sec - (most_recent_ECG_timestamp_sec - first_ECG_timestep_sec);
    
                    FIRST_READ_HAS_OCCURRED = true;

                    if (OUTPUT_DEBUG_INFORMATION)
                        fprintf('\n\nFirst read has occured');
                        fprintf('\nFirst timestamp from Shimmer at %f seconds', first_ECG_timestep_sec);
                        fprintf('\nMost recent timestamp from Shimmer at %f seconds\n', most_recent_ECG_timestamp_sec);
                    else
                        fprintf('\nData is being collected (see Live Graph)\n');
                    end
    
                    % Reset sampling buffer
                    sampling_buffer_first_HB_sec = 0;

                    figure;
                end
    
                % Parse the data
                try
    
                    X_time_current_packet_sec               = newData(:, k_time) / 1e3;
                    X_time_total_sec(end+1 : end+NnewData)  = newData(:, k_time) / 1e3;
                    Y_ECG_total(end+1 : end+NnewData)       = newData(:, k_ECG_Signal_HBD);
    
                catch err
                    % Output debugging information
                    fprintf('\n\n----------------------------\n')
                    warning('Error starting up');
                    err
                    fprintf('\n')
                    newData
                    size(newData);
                    NnewData
                    k_time
                    k_ECG_Signal_HBD
                    fprintf('\n\n----------------------------')
                    fprintf('\n----------------------------\n\n')
    
                    % Skip the rest of the while loop
    
                    fprintf('\n** Error while loading data.');
                    fprintf('\n\n** Ending the program (electrodes are not playing nicely)');
    
                    break;
                end
    
                if(OUTPUT_DEBUG_INFORMATION)
                    % fprintf('\nData from %f sec: %f', X_time_total_sec(end) - X_time_total_sec(1), Y_ECG_total(end));
                end
    
                % Calculates consecutive differences in ECG values to determine
                % times when the Shimmer detects the change in voltage
                Y_ECG_voltage_diff = diff(Y_ECG_total);
                temp_X_secs = X_time_total_sec(2:end) - first_ECG_timestep_sec;
                X_ECG_switch_points_secs = temp_X_secs(abs(Y_ECG_voltage_diff) > 0.4 * approximate_voltage_mV);
    
                % Filters out double-counted values based on the expected
                % signal duration
                detected_time_between_switches = diff(X_ECG_switch_points_secs);
                X_ECG_switch_points_secs = X_ECG_switch_points_secs(detected_time_between_switches > 0.5 * signal_duration_sec);
    
                if(ARDUINO_SIGNAL_TIME_FROM_AVERAGE)
                    % Truncate the last element if the array length is odd
                    if mod(length(X_signal_time_sec), 2) ~= 0
                        X_signal_switch_points_secs = X_signal_time_sec(1:end-1) - initial_GetSecs_offset_sec;
                    end
    
                    % Reshape the array into a 2-row matrix
                    reshaped_array = reshape(X_signal_switch_points_secs, 2, []);
    
                    % Calculate the mean of each pair of elements
                    X_signal_switch_points_secs = mean(reshaped_array);
                elseif(length(X_signal_time_sec) > 2) % To make sure that we've already sent at least one arduino signal

                    % Every other element contains the start of the switch
                    % point; the odd elements are the starts, and the even
                    % elements are the ends
                    pre_signal_points_secs = X_signal_time_sec(1:2:end) - initial_GetSecs_offset_sec;
                    X_signal_switch_points_secs = X_signal_time_sec(2:2:end) - initial_GetSecs_offset_sec;
                    arduino_command_latency =  X_signal_switch_points_secs() - pre_signal_points_secs(1:length(X_signal_switch_points_secs));
                end
    
                % Find the minimum size between the two arrays (in case the
                % Arduino has switched but the ECG hasn't detected yet)
                min_length = min(length(X_ECG_switch_points_secs), length(X_signal_switch_points_secs));
    
                % Truncate both arrays to the minimum size
                X_ECG_switch_points_secs = X_ECG_switch_points_secs(1:min_length);
                X_signal_switch_points_secs = X_signal_switch_points_secs(1:min_length);
    
                % Perform the subtraction
                lag_times = X_ECG_switch_points_secs - X_signal_switch_points_secs;
    
                if( size(lag_times) ~= Nswitches)
                    fprintf('Signal change detected, lag time is %f seconds', lag_times(end));
                end
    
                Nswitches = size(lag_times);
    
                % Plot data from ECG and arduino signal
                if( SHOW_REALTIME_PLOT )
                    hold('off');
                    plot(X_time_total_sec - first_ECG_timestep_sec, Y_ECG_total, '-k', X_signal_time_sec - initial_GetSecs_offset_sec, Y_binary_signal, '-r');
                    grid('on');
                    title('Hold Shift + Esc to stop the program');
                    ylabel('ECG LL-RA (mV)');
                    xlabel('Time (sec)');

                    new_x = X_time_total_sec(end) - first_ECG_timestep_sec;
                    % Adjusts the width of the graph display
                    if new_x > window_width 
                        xlim([new_x - window_width, new_x]);
                    else
                        xlim([0, window_width]);
                    end

                    % Update the plot
                    drawnow()
                end
    
                % End the program if Shift and Esc are pressed
                [ keyIsDown, ~, keyCode ] = KbCheck;
    
                if( keyIsDown && keyCode(key_esc) && keyCode(key_shift) )
                    fprintf('\n** Researcher pushed stop key. Ending program.\n\n');
    
                    % Break out of the while loop
                    break;
                end
    
                time_of_total_recording_sec = X_time_total_sec(end) - X_time_total_sec(1);
    
            end
    
            tic_at_last_sample = tic;
        end
    end

    if(OUTPUT_DEBUG_INFORMATION)
        % Output data about the actual and detected times when the signal switches
        fprintf('\n\nDetected signal switch points (msec): ');
        fprintf('%d ', X_ECG_switch_points_secs * 1e3);

        fprintf('\nActual signal switch points (msec): ');
        fprintf('%d ', X_signal_switch_points_secs * 1e3);

        fprintf('\nLag times (msec): ');
        fprintf('%d ', lag_times * 1e3);

        % Output data about the latency in the arduino signal
        fprintf('\nArduino latencies (msec): ');
        fprintf('%d ', arduino_command_latency * 1e3);

        fprintf('\nAverage arduino latency: %f msec', mean(arduino_command_latency) * 1e3);
        fprintf('\nStandard deviation in arduino latencies: %f msec', std(arduino_command_latency) * 1e3);

        figure;
        histogram(arduino_command_latency(2:end) * 1e3, 'BinWidth', 1);
        title('Histogram of Arduino Latency');
        xlabel('Latency Times (msec)')
        ylabel('Frequency');
    end

    writeDigitalPin(a, pin, 0);
    
    lag_times_msec = lag_times(lag_times > 0) * 1e3;
    
    % Display histogram
    figure;
    histogram(lag_times_msec, 'BinWidth', 1);
    title(sprintf('Histogram of Lag Times (%d Signal Switches)', nSignalSwitches));
    xlabel('Lag Times, (Time of ECG Detection) - (Time After Arduino Signal is Sent), in msec');
    ylabel('Frequency');

    % Calculate statistics
    mean_value = mean(lag_times_msec);
    std_value = std(lag_times_msec);

    if (NORMALLY_DISTRIBUTED)
        % 95% confidence interval normally distributed
        z_critical99 = 2.58;
        ci_lower99 = mean_value - z_critical99 * std_value;
        ci_upper99 = mean_value + z_critical99 * std_value;

        % 95% confidence interval normally distributed
        z_critical95 = 1.96;
        ci_lower95 = mean_value - z_critical95 * std_value;
        ci_upper95 = mean_value + z_critical95 * std_value;

        % 90% confidence interval normally distributed
        z_critical90 = 1.64;
        ci_lower90 = mean_value - z_critical90 * std_value;
        ci_upper90 = mean_value + z_critical90 * std_value;
    else
        % 99% confidence interval empirically
        ci_lower99 = prctile(lag_times_msec, 1);
        ci_upper99 = prctile(lag_times_msec, 99);

        % 95% confidence interval empirically
        ci_lower95 = prctile(lag_times_msec, 2.5);
        ci_upper95 = prctile(lag_times_msec, 97.5);

        % 90% confidence interval empirically
        ci_lower90 = prctile(lag_times_msec, 5);
        ci_upper90 = prctile(lag_times_msec, 95);
    end
    
    % Display statistics
    fprintf('\n\nSTATISTICAL OUTPUT\n')
    fprintf('Number of Signal Switches: %d\n]n', nSignalSwitches)
    fprintf('Average Lag ***USE THIS NUMBER IN HBD PROGRAM***: %.1f msec\n', mean_value);
    fprintf(['HOW TO INTERPRET Average Lag: \nLess than 20 ms: Excellent\n' ...
        '20 to 50 ms: Good\n50 to 100 ms: Acceptable\n100 to 150 ms: Concerning,' ...
        'probably acceptable\nGreater than 150 ms: Unacceptable\n\n'])

    % Warns users if average lag is too high
    if(ci_lower95 > 50 || mean_value > 100)
        fprintf(['\nWARNING: An interval of over 50 ms is concerning, and more than 100 ms ' ...
            'is unacceptable. If the lag is significantly more than 100 ms, it may be due to ' ...
            'high levels of noise. Fix the experimental setup and run the program again\n']);
    end

    %fprintf('Standard Deviation: %.5f msec\n', std_value);
    fprintf('99%% Confidence Interval: [%.1f msec, %.1f msec], Range: ±%.1f\n', ci_lower99, ci_upper99, (ci_upper99 - ci_lower99)/2);
    fprintf('95%% Confidence Interval: [%.1f msec, %.1f msec], Range: ±%.1f\n', ci_lower95, ci_upper95, (ci_upper95 - ci_lower95)/2);
    fprintf('90%% Confidence Interval: [%.1f msec, %.1f msec], Range: ±%.1f\n', ci_lower90, ci_upper90, (ci_upper90 - ci_lower90)/2);
    fprintf(['HOW TO INTERPRET Confidence Interval: \nLess than ±10 ms: Excellent\n' ...
        '±10 to ±25 ms: Good\n±25 to ±50 ms: Acceptable\nGreater than ±50 ms: Unacceptable\n'])

    fprintf('99%% confidence intervals should recorded in publications\n\n');

    % Warn users if the range is too high
    if((ci_upper99 - ci_upper99) > 100)
        fprintf(['\nWARNING: A range of over 100 ms is too much variability to consistently' ...
            'and precisely deliver audio tones on time. Check histogram for outliers skewing' ...
            'the data. Reduce possible sources of signal noise (e.g., WiFi).\n'])
    end
    
    fprintf('\n\nProgram Complete.\n\n');
    
    % Close the connections
    shimmer.stop;
    clear a;
    
    shimmer.disconnect;

    % Close the diary
    diary('off');    
end
