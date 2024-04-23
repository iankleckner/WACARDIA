
function [line_string, line_num] = findTargetStringCellArray( target_string, tokensInFile )

    
    Nchars_target_string = length(target_string);

    for line_num = 1:length(tokensInFile)
        % Get the string for that line
        line_string = tokensInFile{line_num};

        if( length(line_string) >= Nchars_target_string && ...
            strcmp(line_string(1:Nchars_target_string), target_string) )

            % Found the target, exit early
            return;
        end
    end
    
    % No result is found, so return empty results
    line_string = [];    
    line_num = [];
end
