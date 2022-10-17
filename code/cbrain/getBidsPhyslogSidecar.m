function header = getBidsPhyslogSidecar(physlogfile)

header_file = extractBefore(physlogfile, '.tsv');
json_filename = append(header_file, '.json');
if ~isfile(append(header_file, '.json'))
    msg = 'JSON sidecar not found for BIDS physiological recording!';
    error(msg);
end
header_text = fileread(json_filename);        
header = jsondecode(header_text);
        
end