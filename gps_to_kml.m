% Main function that reads GPS data, parses coordinates, and generates KML
% file with yellow route line, red stop markers, and yellow turn markers
% 
% Authors: 
%   - Bibhash Thapa (bt2394)
%   - Emile Racquet (er8033)
%
% Example run: gps_to_kml('2025_05_01__145019_gps_file.txt')
%   Input: gps_data/2025_05_01__145019_gps_file.txt
%   Output: kml_data/2025_05_01__145019_gps_file.kml
function gps_to_kml(gps_filename)

    % Configure parameters and constants:
    ALTITUDE = 3.0; % fixed altitude for all points (in meters)
    STOP_THRESHOLD = 0.5; % threshold (in knots) below which vehicle is stopped
    LEFT_TURN_THRESHOLD = -30; % heading change threshold (degrees)

    % Build full paths
    gps_file = fullfile('gps_data', gps_filename);
    
    % Create kml output filename
    [~, name, ~] = fileparts(gps_filename);
    kml_file = fullfile('kml_data', [name '.kml']);
    
    % Create kml_data directory if it doesn't exist
    if ~exist('kml_data', 'dir')
        mkdir('kml_data');
    end
        
    % Read and parse GPS data:
    gps_data = read_gps_file(gps_file);

    % Extract data arrays
    latitudes = gps_data(:, 1);
    longitudes = gps_data(:, 2);
    speeds = gps_data(:, 3);
    headings = gps_data(:, 4);

    % Detect stops and turns
    stop_indices = detect_stops(speeds, STOP_THRESHOLD);
    turn_indices = detect_left_turns(headings, speeds, LEFT_TURN_THRESHOLD);

    % Write KML file
    write_kml(kml_file, latitudes, longitudes, stop_indices, turn_indices, ALTITUDE);
    
    fprintf('Generated: %s\n', kml_file);
end

% Read GPS file and parse GPRMC sentences
function gps_data = read_gps_file(filename)
    fid = fopen(filename, 'r');
    gps_data = [];

    while ~feof(fid)
        line = fgetl(fid);
        if ischar(line) && strncmp(line, '$GPRMC', 6)
            point = parse_gprmc(line);
            if ~isempty(point)
                gps_data = [gps_data; point]; 
            end
        end
    end
    fclose(fid);
end

% Parse GPRMC sentence and return latitude, longitude, speed, heading
function point = parse_gprmc(line)
    point = [];
    parts = strsplit(line, ',');

    % Check for valid fix (if field 3 = 'A')
    if length(parts) < 9 || ~strcmp(parts{3}, 'A')
        return;
    end

    % Parse coordinates
    latitude = convert_gps_coordinate(parts{4}, parts{5});
    longitude = convert_gps_coordinate(parts{6}, parts{7});
    
    % Parse speed and heading
    speed = str2double(parts{8});
    heading = str2double(parts{9});
    
    % Return as row vector
    point = [latitude, longitude, speed, heading];
end

% Convert GPS coordinate from DDMM.MMMM format to decimal degrees
function decimal = convert_gps_coordinate(coordinate_string, direction)
    coordinate = str2double(coordinate_string);
    degrees = floor(coordinate / 100);
    minutes = coordinate - (degrees * 100);
    decimal = degrees + minutes / 60.0;
    
    % Apply sign for South or West
    if strcmp(direction, 'S') || strcmp(direction, 'W')
        decimal = -decimal;
    end
end

% Detect stops (speed below threshold)
function indices = detect_stops(speeds, threshold)
    indices = find(speeds < threshold);
end

% Detect left turns (heading change < threshold)
function indices = detect_left_turns(headings, speeds, threshold)
    indices = [];
    WINDOW_SIZE = 5; % Look at last 5 points
    
    for i = WINDOW_SIZE+1:length(headings)
        % Check if moving
        if speeds(i) > 0.5
            % Calculate total heading change over window
            total_delta = 0;
            for j = (i-WINDOW_SIZE+1):i
                delta = headings(j) - headings(j-1);
                
                % Normalize
                if delta > 180
                    delta = delta - 360;
                elseif delta < -180
                    delta = delta + 360;
                end
                
                total_delta = total_delta + delta;
            end
            
            % Detect significant left turn
            if total_delta <= threshold
                % Avoid duplicates
                if isempty(indices) || (i - indices(end)) > WINDOW_SIZE
                    indices = [indices; i];
                end
            end
        end
    end
end

% Write KML file
function write_kml(filename, lat, lon, stops, turns, alt)
    fid = fopen(filename,'w');
    if fid < 0, error("Cannot write KML."); end
    
    % Header
    fprintf(fid,'<?xml version="1.0" encoding="UTF-8"?>\n');
    fprintf(fid,'<kml xmlns="http://www.opengis.net/kml/2.2">\n');
    fprintf(fid,'<Document>\n');
    
    % Styles
    fprintf(fid,'<Style id="route">\n');
    fprintf(fid,'  <LineStyle><color>ff00ffff</color><width>4</width></LineStyle>\n');
    fprintf(fid,'</Style>\n');
    fprintf(fid,'<Style id="stop">\n');
    fprintf(fid,'  <IconStyle><color>ff0000ff</color>\n');
    fprintf(fid,'  <Icon><href>http://maps.google.com/mapfiles/kml/paddle/red-circle.png</href></Icon>\n');
    fprintf(fid,'  </IconStyle>\n</Style>\n');
    fprintf(fid,'<Style id="turn">\n');
    fprintf(fid,'  <IconStyle><color>ff00ffff</color>\n');
    fprintf(fid,'  <Icon><href>http://maps.google.com/mapfiles/kml/paddle/ylw-circle.png</href></Icon>\n');
    fprintf(fid,'  </IconStyle>\n</Style>\n');
    
    % Route line
    fprintf(fid,'<Placemark><styleUrl>#route</styleUrl>\n');
    fprintf(fid,'<LineString><tessellate>1</tessellate><coordinates>\n');
    for i = 1:length(lat)
        fprintf(fid,'%f,%f,%f\n', lon(i), lat(i), alt);
    end
    fprintf(fid,'</coordinates></LineString></Placemark>\n');
    
    % Stop markers
    for i = stops(:)'
        if i >= 1 && i <= numel(lat)
            fprintf(fid,'<Placemark><styleUrl>#stop</styleUrl>\n');
            fprintf(fid,'<Point><coordinates>%f,%f,%f</coordinates></Point>\n',...
                lon(i), lat(i), alt);
            fprintf(fid,'</Placemark>\n');
        end
    end
    
    % Left turn markers
    for i = turns(:)'
        if i >= 1 && i <= numel(lat)
            fprintf(fid,'<Placemark><styleUrl>#turn</styleUrl>\n');
            fprintf(fid,'<Point><coordinates>%f,%f,%f</coordinates></Point>\n',...
                lon(i), lat(i), alt);
            fprintf(fid,'</Placemark>\n');
        end
    end
    
    fprintf(fid,'</Document></kml>\n');
    fclose(fid);
end