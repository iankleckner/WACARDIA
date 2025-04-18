classdef Set < handle
    % Set class: Holds a set of data which can be accessed via various
    % algorithms (e.g., random sampling without replacement)
    %  Subclass of "handle" makes each new instance of "Set" as a new POINTER
    % to the instance, which can be modified in any context
    %   Initially made to store textures of images
    %
    % Ian Kleckner
    % Interdisciplinary Affective Science Lab (IASL)
    % Continuous Flash Suppression (CFS)
    %
    % 2011/03/15 Start coding    
    % 2011/09/26 PREVENT_REPEAT_SAMPLE Prohibit the last element sampled to be the first element
    %            sampled upon reset of the random array (e.g., to prevent
    %            two of the same Mondrian images shown in a row during CFS)
    % 2011/11/16 addArray(), and PREVENT_REPEAT_SAMPLE is true
    % 2012/03/19 Add subSet_array, change element to element_array
    %
    % TO DO
    %  Make addArray() more efficient (see below)
    
    
    properties (SetAccess = private)
        name = 'NoName';     % Name of Set
        
        element_array       = {};   % Elements in the set
        Nelements           = 0;    % Total number of elements
        
        subSet_array        = {};    % Set within this Set
        Nsubsets            = 0; 
        
        irandom             = 1;        % Current index in random_index array
        random_index        = [];       % Array of indices which have been accessed already
        
        PREVENT_REPEAT_SAMPLE = true;  % Prevent a repeat sampling of the same element
                                       % upon resetting the random sampling
                                       % (e.g., to prevent two of the same
                                       % Mondrian images shown in a row during CFS)
    end
    
    methods
        function obj = Set( name )
            %% Constructor
            if( nargin == 1 )
                obj.name = name;
            end
        end
        
        function addArray( obj, array )
            %% Add a sequence of elements from an array (either cell or not)
            %  E.g., set.addNumberSequence(4:8);
            %
            % Note: this code is VERY inefficient since it calls a function
            % for each element
            
            % Add each number in the array
            for a = 1:length(array)
                
                % Use cell reference if it is a cell
                if( iscell(array) )
                    obj.addElement( array{a} );
                    
                % Use array reference if it is not a cell
                else
                    obj.addElement( array(a) );
                end
            end
        end
        
        function addElement( obj, e )
            %% Add an element to the set
            obj.Nelements = obj.Nelements+1;
            obj.element_array{ obj.Nelements } = e;
            
            % Since a new element is added, must reset the random sampling
            % with replacement
            obj.resetRandomSample();
        end
        
        function addSubSet(obj, set )
            %% Add subset to this set
            
            if( ~isa(set, 'Set') )
                set
                error('This object is NOT an instance of the Set class');                
            end
            
            % Increase total number of subsets
            obj.Nsubsets = obj.Nsubsets + 1;
           
            % Add the set
            obj.subSet_array{obj.Nsubsets} = set;            
        end
        
        function copiedSet = copy( obj )
            %% Create a new instance of the set
            
            % Create a new instance
            copiedSet = Set( obj.name );
            
            % Copy each property            
            copiedSet.element_array     = obj.element_array;
            copiedSet.Nelements         = obj.Nelements;
        
            copiedSet.subSet_array      = obj.subSet_array;
            copiedSet.Nsubsets          = obj.Nsubsets;

            copiedSet.irandom           = obj.irandom;
            copiedSet.random_index      = obj.random_index;

            copiedSet.PREVENT_REPEAT_SAMPLE = obj.PREVENT_REPEAT_SAMPLE;
        end
        
        function subSet_array = divideSetRandomly( obj, Ndivisions )
            %% Divide set into pieces
            
            if( Ndivisions ~= 2 )
                error('Only programed for dividing into two');
            end
            
            % Create the two sets
            %subSet_array{1} = Set( sprintf('%s-Part_%d_of_%d', obj.name, 1, 2) );
            %subSet_array{2} = Set( sprintf('%s-Part_%d_of_%d', obj.name, 2, 2) );
            
            subSet_array{1} = Set( obj.name );
            subSet_array{2} = Set( obj.name );
                        
            % Randomly divide sample the current set            
            for eIndex = 1:obj.Nelements
                
                % Get random index WITHOUT replacement
                index   = obj.random_index( eIndex );
                e       = obj.element_array{ index };
                
                % Assign this index to the proper subset
                if( eIndex <= obj.Nelements / 2 )
                    subSet_array{1}.addElement(e);
                else
                    subSet_array{2}.addElement(e);
                end
            end
        end
        
        function e = getElement( obj, index )
            %% Return element from given index
            e = obj.element_array{ index };            
        end
        
        function [e, index] = getElementRandom( obj )
            %% Get an element randomly (with replacement)
            % i.e., pick any element randomly (no contraints)
            index = randi(obj.Nelements,1);
            
            % Access random element via random index
            e = obj.element_array{ index };
        end
        
        function [e, index] = getElementRandomNoReplacement( obj )
            %% Get an element randomly (without replacement)
            % i.e., randomly pick each element once, before picking any
            % element a second time
            index   = obj.random_index(obj.irandom);
            e       = obj.element_array{ index };            
            
            % If all elements have been sampled, then reset
            if( obj.irandom == obj.Nelements )
                obj.resetRandomSample();
                
            else
                % Increment the index for the next random sampling
                obj.irandom = obj.irandom+1;
            end
        end
        
        function [e, index] = getElementRandomNoReplacementCircularReset( obj )
            %% Get an element randomly (without replacement)
            % i.e., randomly pick each element once, before picking any
            % element a second time
            %
            % Once all elements are sampled, then start again from #1
            %  E.g., 1, 2, 3, 1, 2, 3, 1, 2, 3, ...
            index   = obj.random_index(obj.irandom);
            e       = obj.element_array{ index };            
            
            % If all elements have been sampled, then circular reset to the
            % first element in this randomized list
            if( obj.irandom == obj.Nelements )
                obj.irandom = 1;
                
            else
                % Increment the index for the next random sampling
                obj.irandom = obj.irandom+1;
            end
        end
        
        function subSet = getSubSet( obj, index )
            %% Return subSet from given index
            subSet = obj.subSet_array{ index };
            
        end
        
        function resetRandomSample( obj )
            %% Reset the array itemizing accessed indices
            % 2011/09/26 updated for PREVENT_REPEAT_SAMPLE
            
            % Make sure that the last sampled element is not the first
            % sampled element in the newly randomized order            
            %  Also requires that at least one element has been shown already
            %  and that there is more than one element in total
            if( obj.PREVENT_REPEAT_SAMPLE && ...
                obj.irandom > 1 && obj.Nelements > 1 )
            
                % Check the last index shown
                %  If the entire list was traversed
                if( obj.irandom == obj.Nelements )
                    % Then the last index shown was the last one in the
                    % list
                    last_index_shown = obj.random_index(obj.irandom);
                else
                    % Otherwise, the most recent item has not been shown,
                    % and hence the last index shown is one previous
                    last_index_shown = obj.random_index(obj.irandom-1);
                end
                
                % Reset the random sample, while making sure the new first
                % element does not equal the last element shown                
                
                % The next line ensure the while() loop is executed at
                % least once
                next_index_shown = last_index_shown;
                
                while( next_index_shown == last_index_shown )
                    obj.random_index    = randperm(obj.Nelements);
                    obj.irandom         = 1;
                    next_index_shown    = obj.random_index(obj.irandom);
                end
                
            else
                % No constraint on the order of the random sampling
                % copared to before it was reset
                obj.random_index    = randperm(obj.Nelements);
                obj.irandom         = 1;
            end            
        end
        
        function setPreventRepeatSample( obj, PREVENT_REPEAT_SAMPLE )
            %% Set this variable
            obj.PREVENT_REPEAT_SAMPLE = PREVENT_REPEAT_SAMPLE;
        end
    end
    
    methods (Static = true)
       
        function blockNumber = getBlockNumber( participantNumber, Nblocks )
            %% Get a block number for a given participant number and the total number of blocks
       
            % Counter-balance order of blocks for the PP
            %  PPnumber ranges 1, 2, 3, 4, 5, 6, ...
            %  block_order_index ranges 1 ... Nblock_order_options (then
            %  repeat)
            quotient      = floor( participantNumber / Nblocks );
            blockNumber   = participantNumber - Nblocks*quotient;

            if( blockNumber == 0 )
                blockNumber = Nblocks;
            end
        end
        
    end
end