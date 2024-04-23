% Ian Kleckner, PhD, MPH
% ian.kleckner@gmail.com
%
% 2011/02/19 Start coding
% 2012/02/22 Update formatting
% 2019/06/04 Update my affiliation, etc.

function writeSpecificationsHeader( OUTPUTSTREAM, experiment_specs )
    %% Write the header information

    fprintf(OUTPUTSTREAM, 'Ian Kleckner, PhD, MPH');
    fprintf(OUTPUTSTREAM, 'Ian.Kleckner@gmail.com');
    fprintf(OUTPUTSTREAM, '\n%s', experiment_specs.SoftwareTitle);
    fprintf(OUTPUTSTREAM, '\nVersion\t%s', experiment_specs.SoftwareVersion);        
    fprintf(OUTPUTSTREAM, '\n\nTimestamp\t%s', datestr(now));
                
    % All settings from the table are written to a log file
    experiment_specs.dynamicTable.writeLogFile( OUTPUTSTREAM );
    %input('No dynamic table specified. Hit Return to continue');
end