classdef IAPS < handle
    % Set IAPS: Holds a set of data related to a set of IAPS images
    %
    % Lang, P.J., Bradley, M.M., & Cuthbert, B.N. (2008). International
    % affective picture system(IAPS): Affective ratings of pictures and
    % instruction manual. Technical Report A-8. University of Florida, Gainesville, FL.
    %
    % Ian Kleckner
    % Interdisciplinary Affective Science Lab (IASL)
    % Conceptual Priming project with Ajay Satpute
    %
    % 2011/09/25 Start coding
    % 2011/10/15 Update getSpecsStructureOnImage() to take IAPS_ID, not
    %            index in array
    % 2012/04/09 Add image via specs structure
    
    
    properties (SetAccess = private)
        filename_TechReport     = '';   % Filename for the technical report
        
        % Tech report contains information for each file
        % Each of VALENCE, AROUSAL, and DOMINANCE range from 1-9
        desc        = {};   % Description of the image
        num         = [];   % Image number
        valmn       = [];   % VALENCE mean for the image
        valsd       = [];   % VALENCE standard deviaion
        aromn       = [];   % AROUSAL mean
        arosd       = [];   % AROUSAL standard deviation
        dom1mn      = [];   % DOMINANCE (type 1) mean
        dom1sd      = [];   % DOMINANCE (type 1) standard deviation
        dom2mn      = [];   % DOMINANCE (type 2) mean
        dom2sd      = [];   % DOMINANCE (type 2) standard deviation
        set         = [];   % Set number
        
        Nimages     = 0;
        
        basedirImages   = '';   % Base directory for loading image files
        filename    = {};   % Name of file
        %file        = {};   % Handle for file
        
        fileExtension = 'jpg';
        
        % An instance of the Set class can permit random sampling with or
        % without replacement (see Set.m)
        samplingSet = Set();
        
    end
    
    methods
        function obj = IAPS()
            %% Default constructor
            
            % Consider loading the tech report, or adding images
        end
        
        function addImage( obj, desc, num, valmn, valsd, aromn, arosd, dom1mn, dom1sd, dom2mn, dom2sd, set, varargin )
            %% Add an image to the IAPS set
            %  This is useful for making a new instance of IAPS with a
            %  subset of images (e.g., only VALENCE < 2)
            %
            % varargin{1}  will disable resetting random sampling
            
            % Store Nimages for easy access, then save it below
            Nimages = obj.Nimages+1;
            
            obj.desc{Nimages}   = desc;
            obj.num(Nimages)    = num;
            obj.valmn(Nimages)  = valmn;
            obj.valsd(Nimages)  = valsd;
            obj.aromn(Nimages)  = aromn;
            obj.arosd(Nimages)  = arosd;
            obj.dom1mn(Nimages) = dom1mn;
            obj.dom1sd(Nimages) = dom1sd;
            obj.dom2mn(Nimages) = dom2mn;
            obj.dom2sd(Nimages) = dom2sd;
            obj.set(Nimages)    = set;
            
            % Save the updated number of images
            obj.Nimages = Nimages;
            
            % Generate the filename
            obj.filename{Nimages} = generateFilename(obj, num);
            
            if( nargin <= 12 )                
                % Reset the sampling set for randomly picking images
                obj.resetSamplingSet();            
            else
                %varargin{1}
            end
        end
        
        function addImage_specs_structure( obj, specs_structure )
            %% Add an image using specifications structure as formatted
            % below
            
            obj.addImage( ...
                specs_structure.desc, specs_structure.num, ...
                specs_structure.valmn, specs_structure.valsd, ...
                specs_structure.aromn, specs_structure.arosd, ...
                specs_structure.dom1mn, specs_structure.dom1sd, ...
                specs_structure.dom2mn, specs_structure.dom2sd, ...
                specs_structure.set, 'DO_NOT_RESET_SAMPLING_SET');            
        end
        
        function filenameString = generateFilename(obj, imageNumber)
            %% Generate image filename from desired number
            %  Note: some image filenames have no decimal "6250.jpg"
            %  and some do "6250.1.jpg"            
            
            if( floor(imageNumber) == imageNumber )
                % Contains no decimal point
                filenameString = sprintf('%s/%0.0f.%s', obj.basedirImages, imageNumber, obj.fileExtension);
                
            else
                % Contains a decimal point (assume only one)
                filenameString = sprintf('%s/%0.1f.%s', obj.basedirImages, imageNumber, obj.fileExtension);
            end
        end        
        
        function specs_structure = getSpecsStructureOnImage( obj, samplingModeString, varargin )
            %% Return specifications on the given index in this instances's array of images
            % samplingModeString -> 'INDEX' with varargin{1} specifies the
            % IAPS ID
            % samplingModeString -> 'RANDOM_NO_REPLACEMENT'
            % samplingModeString -> 'RANDOM'
            %
            % Example: getSpecsStructureOnImage( 'INDEX', 3200 )
            
            OUTPUT_DEBUG = false;
            if( OUTPUT_DEBUG )
                [ST,I] = dbstack;                
                fprintf('\n\nFUNCTION: %s', ST(1).name);
            end
            
            switch samplingModeString                
                case 'INDEX'
                    % Find the array index corresponding to that IAPS ID
                    IAPS_ID     = varargin{1};
                    imageIndex  = find( IAPS_ID == obj.num );
                    
                    if( isempty(imageIndex) )
                        error('Could not find IAPS ID %f', IAPS_ID);
                    end
                    
                    if( length(imageIndex) > 1 )
                        fprintf('\nWARNING! More than one index for IAPS ID %0.1f', IAPS_ID);
                        imageIndex
                        
                        % Only use the first index
                        imageIndex = imageIndex(1);
                        fprintf('\nWARNING! Using FIRST index only: %d', imageIndex);
                    end
                    
                    if( OUTPUT_DEBUG )
                        fprintf('\nIAPS_ID [%0.1f]\t-> index [%d]', IAPS_ID, imageIndex);
                    end
                    
                case 'RANDOM'
                    imageIndex = obj.samplingSet.getElementRandom();
                    
                case {'RANDOM_NO_REPLACEMENT', 'RANDOMNOREPLACEMENT'}
                    imageIndex = obj.samplingSet.getElementRandomNoReplacement();
                    
                otherwise
                    error('Invalid samplingModeString specified');
            end
            
            % Build a structure with properties from the IAPS class
            specs_structure.desc    = obj.desc{imageIndex};
            specs_structure.num     = obj.num(imageIndex);
            specs_structure.valmn   = obj.valmn(imageIndex);
            specs_structure.valsd   = obj.valsd(imageIndex);
            specs_structure.aromn   = obj.aromn(imageIndex);
            specs_structure.arosd   = obj.arosd(imageIndex);
            specs_structure.dom1mn  = obj.dom1mn(imageIndex);
            specs_structure.dom1sd  = obj.dom1sd(imageIndex);
            specs_structure.dom2mn  = obj.dom2mn(imageIndex);
            specs_structure.dom2sd  = obj.dom2sd(imageIndex);
            specs_structure.set     = obj.set(imageIndex);
            specs_structure.filename= obj.filename{imageIndex};
        end
        
        function [specs_string, specs_string_header] = getSpecsStringOnImage( obj, iaps_number )
            %% Return a string with the specifications
            %  iaps_number = NaN or [] => return header information only
            
            specs_string_header = sprintf('%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s', ...
                'Description', 'Number', 'Valence_Mean', 'Valence_Std', ...
                'Arousal_Mean', 'Arousal_Std', 'Dominance1_Mean', 'Dominance1_Std', ...
                'Dominance2_Mean', 'Dominance2_Std', 'SetNumber', 'Filename');
            
            specs_string = 'NA';
            
            % In case the user just wants the header inforation, then
            % return early
            if( isnan(iaps_number) || isempty(iaps_number) )
                return
            end
            
            % Find the index for that IAPS number
            for iImage = 1:obj.Nimages
                if( obj.num(iImage) == iaps_number )
            
                    specs_string = sprintf('%s\t%0.1f\t%0.3f\t%0.3f\t%0.3f\t%0.3f\t%0.3f\t%0.3f\t%0.3f\t%0.3f\t%0.3f\t%s', ...
                        obj.desc{iImage}, obj.num(iImage), obj.valmn(iImage), obj.valsd(iImage), ...
                        obj.aromn(iImage), obj.arosd(iImage), obj.dom1mn(iImage), obj.dom1sd(iImage), ...
                        obj.dom2mn(iImage), obj.dom2sd(iImage), obj.set(iImage), obj.filename{iImage});
                    
                    % Exit the function early (all done!)
                    return
                end
            end
            
            % If the for loop finished, it means the image could not be
            % found
            error('Could not find image number %f', iaps_number);
        end
        
        function subset_iaps = getSubset( obj, criteriaString )
            %% Get image with some specifications (e.g., VALENCE > 2)
            %  Eventually, perform multi-modal selection criteria   
            %  criteriaString is valid MATLAB code that will be executed as
            %  to yield a boolean result for each image
            %
            %  It may use any of the object properties directly "valmn" or
            %  "aromn" for example
            %
            %  Ex: 'valmn < 2'
            %  Ex: 'valmn > 3 && aromn < 2'
            %  Ex: strcmp(desc, 'Snake')
            
            OUTPUT_DEBUG = true;
            if( OUTPUT_DEBUG )
                [ST,I] = dbstack;                
                fprintf('\n\nFUNCTION: %s', ST(1).name);
            end
            
            %  Return a Set of these image filenames, that can be selected
            %  from using Set functions (random, w/ or w/o replacement)
            subset_iaps = IAPS();
            subset_iaps.setbasedirImages( obj.basedirImages )
            
            % Backup the criteria given by the user
            criteriaString_original = criteriaString;
            
            % Convert string command to proper code for rapid execution
            criteriaString = strrep(criteriaString, 'desc', 'obj.desc{iImage}');
            criteriaString = strrep(criteriaString, 'num', 'obj.num(iImage)');

            criteriaString = strrep(criteriaString, 'valmn', 'obj.valmn(iImage)');
            criteriaString = strrep(criteriaString, 'valsd', 'obj.valsd(iImage)');

            criteriaString = strrep(criteriaString, 'aromn', 'obj.aromn(iImage)');
            criteriaString = strrep(criteriaString, 'arosd', 'obj.arosd(iImage)');

            criteriaString = strrep(criteriaString, 'dom1mn', 'obj.dom1mn(iImage)');
            criteriaString = strrep(criteriaString, 'dom1sd', 'obj.dom1sd(iImage)');

            criteriaString = strrep(criteriaString, 'dom2mn', 'obj.dom2mn(iImage)');
            criteriaString = strrep(criteriaString, 'dom2sd', 'obj.dom2sd(iImage)');

            criteriaString = strrep(criteriaString, 'set', 'obj.set(iImage)');
            
            if( OUTPUT_DEBUG )
                fprintf('\nSelection criteria: %s', criteriaString);
            end
            
            % Iterate through each image
            for iImage = 1:obj.Nimages
                % If it meets the criteria, then add it to the set
                imageMeetsCriteria = eval(criteriaString);
                
                if( imageMeetsCriteria )
                    if( OUTPUT_DEBUG )
                        fprintf('\nImage meets criteria: %s [%d]', obj.desc{iImage}, obj.num(iImage));
                    end
                    subset_iaps.addImage( obj.desc{iImage}, obj.num(iImage), ...
                        obj.valmn(iImage), obj.valsd(iImage), obj.aromn(iImage), obj.arosd(iImage),...
                        obj.dom1mn(iImage), obj.dom1sd(iImage), obj.dom2mn(iImage), obj.dom2sd(iImage), ...
                        obj.set(iImage), 'DO_NOT_RESET_SAMPLING_SET' );
                end
                
                % Reset the random sampling
                subset_iaps.resetSamplingSet();
            end
            
            if( subset_iaps.Nimages == 0 )
                error('IAPS subset contains no images. Consider loosening the critera, "%s"', ...
                    criteriaString_original);
            end
            
            if( OUTPUT_DEBUG )
                fprintf('\nDone!\n');
            end
        end
        
        function loadTechReport( obj, filename_TechReport, basedirImages )
            %% Load the tech report file
            %  This is not as robust as it could be
            %  Skips a specific number of lines in the header
            %  Assumes that each line is an image
            %  Blank lines are not permitted
            
            OUTPUT_DEBUG = false;
            if( OUTPUT_DEBUG )
                [ST,I] = dbstack;                
                fprintf('\n\nFUNCTION: %s', ST(1).name);
            end
            
            % Save the properties
            obj.filename_TechReport = filename_TechReport;
            obj.basedirImages       = basedirImages;
            
            % Number of lines to skip before actual content begins
            Nlines_header = 7;
            
            % Read lines from script file
            try
                FILE    = fopen(filename_TechReport, 'r');
            catch
                error('Could not open file %s', filename_TechReport);
            end
            
            % Start timing execution of function
            fprintf('Loading technical report file "%s"...', filename_TechReport);
            t0 = tic;
            
            % Read all of the lines of the file into one variable
            lines   = textscan(FILE, '%s', 'delimiter', '\n');
            fclose(FILE);
            
            % Determine total number of lines in file
            Nlines  = length(lines{1});
            
            % Determine the total number of images described in the file
            Nimages     = Nlines - Nlines_header;
            
            % Save this to the class
            obj.Nimages = Nimages;
            
            % Initialze arrays to store each parameter
            obj.desc    = cell(Nimages, 1);
            obj.num     = NaN*zeros(Nimages,1);
            obj.valmn   = NaN*zeros(Nimages,1);
            obj.valsd   = NaN*zeros(Nimages,1);
            obj.aromn   = NaN*zeros(Nimages,1);
            obj.arosd   = NaN*zeros(Nimages,1);
            obj.dom1mn  = NaN*zeros(Nimages,1);
            obj.dom1sd  = NaN*zeros(Nimages,1);
            obj.dom2mn  = NaN*zeros(Nimages,1);
            obj.dom2sd  = NaN*zeros(Nimages,1);
            obj.set     = NaN*zeros(Nimages,1);
            obj.filename= cell(Nimages,1);
            
            % Read each line from the variable containing the file's data
            iImage = 0;
            for l = Nlines_header+1:Nlines
                % Update the image number counter
                iImage = iImage + 1;
                
                % Get the line string
                line = lines{1}(l);
                line = line{1};
                
                if( OUTPUT_DEBUG )
                    fprintf('\nLine %d: %s', l, line);
                end
                
                % If there is something to read
                if( ~isempty(line) )
                    
                    tokens  = textscan(char(line), '%s');
                    Ntokens = size(tokens{1},1);
                    
                    % Description and number are always available
                    obj.desc{iImage} = char( tokens{1}(1) );                    
                    obj.num(iImage) = str2double( char(tokens{1}(2)) );
                    
                    % The following properties may be either a number or 
                    % the string "." which means the value is not known
                    % and will therefore be set as NaN                    
                    %  An in-class function make this code more efficient                        
                    obj.valmn(iImage)   = IAPS.str2double_orNaN( char( tokens{1}(3) ) );
                    obj.valsd(iImage)   = IAPS.str2double_orNaN( char( tokens{1}(4) ) );
                    obj.aromn(iImage)   = IAPS.str2double_orNaN( char( tokens{1}(5) ) );
                    obj.arosd(iImage)   = IAPS.str2double_orNaN( char( tokens{1}(6) ) );
                    obj.dom1mn(iImage)  = IAPS.str2double_orNaN( char( tokens{1}(7) ) );
                    obj.dom1sd(iImage)  = IAPS.str2double_orNaN( char( tokens{1}(8) ) );
                    obj.dom2mn(iImage)  = IAPS.str2double_orNaN( char( tokens{1}(9) ) );
                    obj.dom2sd(iImage)  = IAPS.str2double_orNaN( char( tokens{1}(10) ) );
                    
                    % Set is converted special because it ends the line
                    % with "\" or "}"
                    set_plusOneChar = char( tokens{1}(11) );                    
                    obj.set(iImage) = IAPS.str2double_orNaN( set_plusOneChar(1:end-1) );
                    
                    % Set image filename
                    obj.filename{iImage} = obj.generateFilename( obj.num(iImage) );
                    
                else
                    error('File cannot have blank lines, please remove them');
                end
            end
            
            if( OUTPUT_DEBUG )
                obj.desc
                obj.num
                obj.valmn
                obj.valsd
                obj.aromn
                obj.arosd
                obj.dom1mn
                obj.dom1sd
                obj.dom2mn
                obj.dom2sd
                obj.set
                obj.filename
            end
            
            fprintf('\nDone loading file (%d images, %0.2f sec)\n', Nimages, toc(t0));
        end
        
        function resetSamplingSet( obj )
            %% Reset the Set instance for drawing IAPS images
            
            % Create a new Set
            obj.samplingSet = Set();
            
            % Add each IAPS image to the set
            for iImage = 1:obj.Nimages
                obj.samplingSet.addElement( iImage );
            end
        end
        
        function setbasedirImages( obj, basedirImages )
            %% Set basedirImages
            obj.basedirImages = basedirImages; 
        end
    end
    
    methods ( Static = true )
        % Can be accessed via IAPS.FUNCTION_NAME
        
       function valueNum = str2double_orNaN( str )
            %% Convert string to double unless it is a specific character
            %  in which case it is NaN
            %  Here, specific character is "."
            %  2011/09/25 Wrote code
            
            if( strcmp(str, '.') )
                valueNum = NaN;
            else
                valueNum = str2double( str );
            end
        end 
    end
end