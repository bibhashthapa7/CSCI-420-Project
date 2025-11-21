
% Main function that reads GPS data, parses coordinates, and generates KML
% file with yellow route lin, red stop markers, and yellow turn markers
function gps_to_kml(gps_file, kml_file)

    % Configure parameters and constants:
    ALTITUDE = 3.0; % fixed altitude for all points (in meters)
    STOP_THRESHOLD = 0.5; % threshold (in knots) below which vehicle is stopped
    LEFT_TURN_THRESHOLD = -30; % heading change threshold (degrees)

    % TODO: remove later
    % for TESTING:
    gps_file = 'gps_data/2025_05_01__145019_gps_file.txt';
        
    % Read and parse GPS data:
    gps_data = read_gps_file(gps_file);

    % TODO: remove later
    disp(gps_data);

    % Extract data arrays
    latitudes = gps_data(:, 1);
    longitudes = gps_data(:, 2);
    speeds = gps_data(:, 3);
    headings = gps_data(:, 4);

    % Detect stops and turns
    stop_indices = detect_stops(speeds, STOP_THRESHOLD);
    turn_indices = detect_left_turns(headings, speeds, LEFT_TURN_THRESHOLD);

end

function gps_data = read_gps_file(filename)
    % Read GPS file and parse GPRMC sentences
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

function point = parse_gprmc(line)
    % Parse GPRMC sentence and return latitude, longitude, speed, heading
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

function decimal = convert_gps_coordinate(coordinate_string, direction)
    % Convert GPS coordinate from DDMM.MMMM format to decimal degrees
    coordinate = str2double(coordinate_string);
    degrees = floor(coordinate / 100);
    minutes = coordinate - (degrees * 100);
    decimal = degrees + minutes / 60.0;
    
    % Apply sign for South or West
    if strcmp(direction, 'S') || strcmp(direction, 'W')
        decimal = -decimal;
    end
end

function indices = detect_stops(speeds, threshold)
    % Detect stops (speed below threshold)
    indices = find(speeds < threshold);
end

function indices = detect_left_turns(headings, speeds, threshold)
    % Detect left turns (heading change < threshold)
    indices = [];
    for i = 2:length(headings)
        % Only check when moving
        if speeds(i) > 1.0
            delta = headings(i) - headings(i-1);
            
            % Normalize to [-180, 180]
            if delta > 180
                delta = delta - 360;
            elseif delta < -180
                delta = delta + 360;
            end
            
            % Detect left turn
            if delta <= threshold
                indices = [indices; i];
            end
        end
    end
end