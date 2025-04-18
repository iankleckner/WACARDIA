classdef FolderWithFiles < handle
    % FolderWithFiles class: holds information on folders and the files and
    % subfolders that they contain
    %
    % Recursively browses directories
    % Ignores key files
    % List all other files and directories
    %
    % Ian Kleckner
    % Interdisciplinary Affective Science Lab
    % Northeastern University
    % 2011/11/10
    %
    % TO DO
    
    
    properties
        % Absolute filepath to this folder
        foldername_absolute = '';
        
        % Name of current folder (relative)
        foldername      = '';
        
        
        % Names of files in this folder (relative)
        filename_array  = {};
        
        % Number of files
        Nfiles          = 0;
        
        % Ignore these filesnames when reading from the folder
        %  Case INSENSITIVE
        filenames_to_ignore = {'.', '..', 'THUMBS.DB', '.DS_STORE', '._.DS_Store'};
        
        % Ignore files that start with the following character
        firstcharacters_to_ignore = {'.'};
        
        
        % Array of sub-folders which contain files
        %  Note these are instances of this class
        folderWithFiles_array   = {};
        
        % Number of sub-folders
        Nfolders                = 0;
        
        % Parent that created this instance (may not exist)
        parentFolderWithFiles   = [];
    end
    
    methods
        function obj = FolderWithFiles( foldername_absolute, varargin )
            %% Default constructor
            % Optional argument for parent folder
            
            % Check if the folder exists
            if( exist(foldername_absolute, 'dir') )            
                % Save it
                obj.foldername_absolute = foldername_absolute;
                
                % Get relative folder name
                % Find position of slashes
                k_slashes = strfind(foldername_absolute, '/');
                
                % Get name from last slash to end
                if( ~isempty(k_slashes) )
                    obj.foldername = foldername_absolute(k_slashes(end)+1:end);
                else
                    obj.foldername = foldername_absolute;
                end
                
                % Read in optional argument for parent folder
                if( nargin == 2 )
                    if( isa(varargin{1}, 'FolderWithFiles') )
                        obj.parentFolderWithFiles = varargin{1};
                    else
                        varargin{1}
                        error('Additional argument must be a FolderWithFiles instance');                        
                    end
                end
                
                % Update the names of the files and folders in this folder
                obj.update();
            else
                error('Folder does not exist: %s', foldername_absolute)
            end
        end      
        
        function filename_absolute = getFilenameAbsolute( obj, filenumber )
            %% Get the absolute filename from the filenumber
            
            if( filenumber < 1 || filenumber > obj.Nfiles )
                error('Invalid filenumber specified: %d', filenumber);
            end
            
            % Set the filename
            filename_absolute = sprintf('%s/%s', obj.foldername_absolute, obj.filename_array{filenumber});
            
        end
        
        function update( obj )
            %% Recursively browse the folders and files within this path
            
            % Options
            OUTPUT_DEBUG = false;
            
            % Browse the current directory
            filedir = dir( obj.foldername_absolute );
    
            % Read through each file or folder
            for f = 1:length(filedir)
                % Remove any potential double-slashes
                name_relative = strrep( filedir(f).name, '//', '/' );
                
                % Absolute name of the file or folder
                name_absolute = sprintf('%s/%s', obj.foldername_absolute, name_relative);
                                
                % Check if it is any one of the offending filenames
                IGNORE_THIS_FILE = false;                   
                
                % This file should be ignored if it is on the offensive
                % list
                for fignore = 1:length(obj.filenames_to_ignore)                    
                    if( strcmpi(name_relative, obj.filenames_to_ignore{fignore}) )                                                    
                        IGNORE_THIS_FILE = true;
                    end
                end
                
                % This file should be ignored if its first character is
                % on the "first character is offensive" list                
                for cignore = 1:length(obj.firstcharacters_to_ignore)
                    if( name_relative(1) == obj.firstcharacters_to_ignore{cignore} )
                        IGNORE_THIS_FILE = true;
                    end
                end

                if( ~IGNORE_THIS_FILE )                
                    % Check if it is a directory
                    if( exist(name_absolute, 'dir') )

                        if( OUTPUT_DEBUG )
                            fprintf('\nFound directory: %s', name_absolute);
                        end

                        % Create a new instance of this class
                        %  Which will recursively browse directories
                        obj.Nfolders = obj.Nfolders + 1;
                        obj.folderWithFiles_array{obj.Nfolders} = FolderWithFiles( name_absolute, obj );                    

                    % If this is a file
                    elseif( exist(name_absolute, 'file') )

                        if( OUTPUT_DEBUG )
                            fprintf('\nFound file: %s', name_absolute);
                        end
                        
                        % Add the file to the list
                        obj.Nfiles = obj.Nfiles + 1;
                        obj.filename_array{obj.Nfiles} = name_relative;
                    end                    
                end                
            end            
        end
    end
end