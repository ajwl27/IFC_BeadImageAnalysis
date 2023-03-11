fileList = dir('*.tif'); %We will work with all images in the open folder
 
%Send each frame to have the beads detected and their centroid coordinates stored as .csv
for n = 1:length(fileList) 
    s = string(n) + " of " + string(length(fileList));
    disp(s)
    detect_label_save(fileList(n).name)
end
 
 
function detect_label_save (imname)
    namesplit = split(imname,".");
 
    %Set up output filename
    outfile = "data_" + namesplit(1) + ".mat"; 
    if ~isfile(outfile)
 
 
        img = imread(imname); %Open the image
        im=rgb2gray(img); %Convert to grayscale

        %Blur the images to reduce detection noise
        im=imgaussfilt(im,9);
        im=imgaussfilt(im,9);

        % Threshold image - adaptive threshold
        %beads-  0.55
        BW = imbinarize(im, 'adaptive', 'Sensitivity', 0.550000, 'ForegroundPolarity', 'dark');

        % Close mask with octagon
        radius = 6;
        se = strel('octagon', radius);
        BW = imdilate(BW,se);
        BW = imclose(BW, se);
        
 
        % Open mask with disk
        radius = 12;
        decomposition = 0;
        se = strel('disk', radius, decomposition);
        BW = imopen(BW, se);
 
        % Remove small objects
        %For beads – 2500 works well
        minsize = 2500;
        BW = bwareaopen(~BW, minsize);
        BW = imclearborder(BW);
        BW = imfill(BW,'holes');

        D = -bwdist(~BW);
        D(~BW) = -Inf;
        L = watershed(D); %Perform watershed detection

 	%Propose detection regions
        stats = regionprops('table',L, D, 'Centroid', 'Area', 'PixelIDxList');
 
 




        if height(stats) > 1 %ignore images with 0 or only 1 bead
            
            maxsize = 8000;
            stats = stats((stats.Area>minsize)&(stats.Area<maxsize),:); %filter out detections outside threshold values
            
            centers = stats.Centroid; %Make an array of the remaining centroid coordinates
            
            %Print file name
            disp(imname)
 
            %Show the user the image to be labelled
            figure
            imshow(img);
            movegui("east");
            hold on
 
            %Label each bead centroid on the image with a number
            for i = 1:size(centers,1)
                text(centers(i,1),centers(i,2),string(i),'Color','red','FontSize',11, 'FontWeight','bold')
            end
 
            pair = ""; %Pair will hold comma-separated bead indices
 
            x1 = []; x2 = []; y1 = []; y2 = []; %instantiate coordinate arrays
 
            counter = 1; %Set a counter to keep track of the number of pairs
 
            %Ask the user to tell us the first pair
            prompt = 'Input bead pair numbers, separated by a comma. Type q when done to load the next image\n'; 
            pair = input(prompt,'s');
 
            while strcmp(pair,"q")==0 %Keep logging pairs until 'q' is entered
 
                pair = split(pair,",");%Work out the indices of the two beads we're looking at
 
                bead_1 = cell2mat(pair(1)); %Matlab weirdness
                bead_2 = cell2mat(pair(2));
 
                %Find the x and y coordinates of the enetered bead indices
                x1(counter) = centers(str2double(bead_1),1);
                y1(counter) = centers(str2double(bead_1),2);
 
                x2(counter) = centers(str2double(bead_2),1);
                y2(counter) = centers(str2double(bead_2),2);
 
                %Calculate euclidean distance between beads
                dist(counter)=pdist([x1(counter),y1(counter);x2(counter),y2(counter)]);
 
                %Calculate delta x and delta y for working out the angle
                dx = abs(x1(counter)-x2(counter));
                dy = abs(y1(counter)-y2(counter));
 
                %Find the angle in degrees between beads (set 0 to vertical)
                angle(counter)= 90- atand(dy/dx);
 
                %Plot and label the line for ease of keeping track
                line([x1(counter),x2(counter)],[y1(counter),y2(counter)])
                label = "Length: "+string(dist(counter)) +"\newlineAngle: " + string(angle(counter));
                text(((x1(counter)+x2(counter))/2),((y1(counter)+y2(counter))/2),label,'Color','blue','FontSize',6);
 
                %Add one to the counter after finishing a pair; ask for the
                %next pair
                counter = counter+1;
                prompt = 'Input bead pair numbers, separated by a comma. Type q when done to load the next image\n';
                pair = input(prompt,'s');
            end
 
            %We're going to save a .mat file with all the bead coordinates,
            %distances and angles we just worked out. Filename will be
            %data_(original image filename).mat
            if counter >1
                dataframe.x1 = x1;
                dataframe.x2 = x2;
                dataframe.y1 = y1;
                dataframe.y2 = y2;
                dataframe.dist = dist;
                dataframe.angle = angle;
                save(outfile,"dataframe");
            end
 
            %Get rid of variables we used on this loop
            clearvars -except fileList
 
            %Close the image
            close all
        end
    end
end
