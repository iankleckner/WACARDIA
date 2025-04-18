function destinationRect = getDestinationRect( window_handle, image_matrix, minBorderPercent, quadrant )
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

    
    minBorderFraction = minBorderPercent / 100;
    
    % Get IMAGE dimensions
    imageDims   = size(image_matrix);
    imageX      = imageDims(2);
    imageY      = imageDims(1);            

    % Get screen dimensions
    windowDims  = Screen('Rect', window_handle);            
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
